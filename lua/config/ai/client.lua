-- Streaming chat completions over curl, OpenAI style.
--
-- The API key and the request body reach curl on its standard input as a
-- config file (curl -K -), so neither shows up in the process list.

local settings = require('config.ai.settings')

local M = {}

-- "openrouter/deepseek/x" -> provider table, "openrouter", "deepseek/x"
function M.resolve(spec)
	local name, model = (spec or ''):match('^([^/]+)/(.+)$')
	if not name then
		return nil, ('not a provider/model name: %s'):format(spec or '')
	end
	local provider = settings.providers[name]
	if not provider then
		return nil, ('no provider named %s in lua/config/ai/settings.lua'):format(name)
	end
	return provider, name, model
end

local function key(provider, name)
	local value = vim.env[provider.key_env or '']
	if not value or value == '' then
		return nil, ('%s is not set (the key for %s)'):format(provider.key_env or '?', name)
	end
	return value
end

-- A curl config line. Inside double quotes curl reads \\ \" \n \r \t.
local function quote(text)
	return '"' .. text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
end

local function curl(args, config, on_line, on_exit)
	-- Give up on a connection after 20 s, on a response that sends nothing
	-- for 120 s (providers send keep-alive comments while a model thinks),
	-- and on anything still going after 10 minutes.
	local base = { 'curl', '-sS', '-N', '--connect-timeout', '20', '--speed-limit', '1', '--speed-time', '120', '--max-time', '600', '-K', '-' }
	local ok, job = pcall(vim.system, vim.list_extend(base, args), {
		stdin = config,
		stdout = function(_, data)
			if data then
				on_line(data)
			end
		end,
	}, function(res)
		vim.schedule(function()
			on_exit(res)
		end)
	end)
	if not ok then
		vim.schedule(function()
			on_exit({ code = -1, stderr = 'cannot run curl: ' .. tostring(job) })
		end)
		return nil
	end
	return job
end

-- Start a streamed chat request. Callbacks run on the main loop:
--   on_text(chunk)        answer text as it arrives
--   on_thinking(chunk)    reasoning text, for models that stream it
--   on_done(err, info)    err is nil on success; info.model is what served it
-- Returns a handle with :cancel().
function M.chat(spec, messages, cb)
	local provider, name, model = M.resolve(spec)
	if not provider then
		vim.schedule(function()
			cb.on_done(name)
		end)
		return { cancel = function() end }
	end
	local secret, err = key(provider, name)
	if not secret then
		vim.schedule(function()
			cb.on_done(err)
		end)
		return { cancel = function() end }
	end

	local body = vim.json.encode({ model = model, stream = true, messages = messages })
	local config = table.concat({
		'url = ' .. quote(provider.base_url:gsub('/$', '') .. '/chat/completions'),
		'header = ' .. quote('Authorization: Bearer ' .. secret),
		'header = "Content-Type: application/json"',
		'data-binary = ' .. quote(body),
		'',
	}, '\n')

	local pending, other, served = '', {}, nil
	local cancelled = false
	local function line(l)
		local data = l:match('^data:%s?(.*)$')
		if not data then
			if l ~= '' and not l:match('^:') then
				other[#other + 1] = l
			end
			return
		end
		if data == '[DONE]' then
			return
		end
		local ok, msg = pcall(vim.json.decode, data)
		if not ok or type(msg) ~= 'table' then
			return
		end
		if msg.error then
			other[#other + 1] = data
			return
		end
		served = msg.model or served
		local choice = msg.choices and msg.choices[1]
		local delta = choice and choice.delta
		if type(delta) == 'table' then
			if type(delta.reasoning) == 'string' and delta.reasoning ~= '' and cb.on_thinking then
				vim.schedule(function()
					cb.on_thinking(delta.reasoning)
				end)
			end
			if type(delta.content) == 'string' and delta.content ~= '' then
				vim.schedule(function()
					cb.on_text(delta.content)
				end)
			end
		end
	end

	local job = curl({}, config, function(data)
		pending = pending .. data
		while true do
			local nl = pending:find('\n', 1, true)
			if not nl then
				break
			end
			line((pending:sub(1, nl - 1):gsub('\r$', '')))
			pending = pending:sub(nl + 1)
		end
	end, function(res)
		if cancelled then
			return
		end
		if pending ~= '' then
			line(pending)
		end
		local msg
		if res.code == 28 then
			msg = 'timed out (no answer from the provider)'
		elseif res.code ~= 0 then
			msg = vim.trim(res.stderr or '') ~= '' and vim.trim(res.stderr) or ('curl exited with ' .. res.code)
		elseif #other > 0 then
			local text = table.concat(other, '\n')
			local ok, decoded = pcall(vim.json.decode, text)
			if ok and type(decoded) == 'table' and type(decoded.error) == 'table' then
				msg = decoded.error.message or text
				-- OpenRouter puts the upstream provider's own message here.
				local meta = decoded.error.metadata
				if type(meta) == 'table' and meta.raw then
					msg = msg .. ': ' .. tostring(meta.raw):sub(1, 300)
				end
			else
				msg = text
			end
		end
		-- Callbacks queued by on_text run first: vim.schedule keeps order.
		vim.schedule(function()
			cb.on_done(msg, { model = served })
		end)
	end)

	return {
		cancel = function()
			cancelled = true
			if job then
				pcall(job.kill, job, 15)
			end
		end,
	}
end

-- The provider's model list, fetched once per session. on_done(ids, models)
-- where models[id] is the provider's record (context_length and so on).
local model_cache = {}
function M.models(name, on_done)
	if model_cache[name] then
		return on_done(model_cache[name].ids, model_cache[name].by_id)
	end
	local provider = settings.providers[name]
	local secret = provider and key(provider, name)
	if not secret then
		return on_done({}, {})
	end
	local out = {}
	curl({}, table.concat({
		'url = ' .. quote(provider.base_url:gsub('/$', '') .. '/models'),
		'header = ' .. quote('Authorization: Bearer ' .. secret),
		'',
	}, '\n'), function(data)
		out[#out + 1] = data
	end, function(res)
		local ids, by_id = {}, {}
		local ok, decoded = pcall(vim.json.decode, table.concat(out))
		if res.code == 0 and ok and type(decoded) == 'table' and type(decoded.data) == 'table' then
			for _, m in ipairs(decoded.data) do
				if type(m.id) == 'string' then
					-- Gemini's OpenAI endpoint lists "models/gemini-…".
					local id = m.id:gsub('^models/', '')
					ids[#ids + 1] = id
					by_id[id] = m
				end
			end
			table.sort(ids)
			model_cache[name] = { ids = ids, by_id = by_id }
		end
		on_done(ids, by_id)
	end)
end

-- The provider's model records if already fetched; otherwise start the
-- fetch for next time and return nil.
function M.cached(name)
	if model_cache[name] then
		return model_cache[name].by_id
	end
	M.models(name, function() end)
	return nil
end

-- The same, waiting for the answer (for command-line completion).
function M.models_sync(name, timeout)
	local result
	M.models(name, function(ids, by_id)
		result = { ids, by_id }
	end)
	vim.wait(timeout or 5000, function()
		return result ~= nil
	end, 20)
	if result then
		return result[1], result[2]
	end
	return {}, {}
end

return M
