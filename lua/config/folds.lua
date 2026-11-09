local M = {}

local foldscan = require('config.foldscan')

-- Marker level, exactly as foldmethod=marker. The number is the level of
-- this line. The carried value is the level of the next line.
-- A digit of 0 does not count. foldnestmax does not apply here.
local function marker_levels(lines, foldmarker)
	local comma = foldmarker:find(',', 1, true)
	local start_m = comma and foldmarker:sub(1, comma - 1) or '{{{'
	local end_m = comma and foldmarker:sub(comma + 1) or '}}}'
	if start_m == '' or end_m == '' then
		return {}, {}
	end

	local levels, starts = {}, {}
	local lvl_next = 0
	for i, line in ipairs(lines) do
		local lvl = lvl_next
		local start_lvl = lvl
		local opened = false
		local s = 1
		while true do
			local a = line:find(start_m, s, true)
			local b = line:find(end_m, s, true)
			if not a and not b then
				break
			end
			if a and (not b or a <= b) then
				local after = a + #start_m
				local digits = line:match('^(%d+)', after)
				local n = digits and tonumber(digits) or nil
				if n and n > 0 then
					lvl = n
					lvl_next = n
					opened = true
				elseif not digits then
					lvl = lvl + 1
					lvl_next = lvl_next + 1
					opened = true
				end
				s = after
			else
				local after = b + #end_m
				local digits = line:match('^(%d+)', after)
				local n = digits and tonumber(digits) or nil
				if n and n > 0 then
					lvl = n
					lvl_next = math.min(n - 1, start_lvl)
				elseif not digits then
					lvl_next = lvl_next - 1
				end
				s = after
			end
		end
		if lvl_next < 0 then
			lvl_next = 0
		end
		levels[i] = lvl
		starts[i] = opened or nil
	end
	return levels, starts
end

local api = vim.api

-- Per buffer: the foldexpr answer for every line, built once per change.
-- 'foldmarker' and 'filetype' changes clear it (see setup).
local cache = {}

-- A buffer this long is rescanned after a pause instead of on every
-- change, so typing never waits for the scan. Until the rescan the old
-- answers stand, and then the windows' folds are recomputed.
local BIG = 20000
local PAUSE = 300
local timers = {}

-- '0', '1', ... and '>1', '>2', ... are shared, not rebuilt per line.
local plain, start = {}, {}
local function answer(level, starts)
	local t = starts and start or plain
	local s = t[level]
	if not s then
		s = (starts and '>' or '') .. level
		t[level] = s
	end
	return s
end

local function scan(bufnr)
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local marker, marker_starts = marker_levels(lines, vim.wo.foldmarker)
	local ok, struct, struct_starts = pcall(foldscan.levels, lines, vim.bo[bufnr].filetype)
	if not ok or not struct then
		struct, struct_starts = {}, {}
	end
	struct_starts = struct_starts or {}
	-- Marker level plus structural level. A line where either kind of
	-- fold starts gets ">", so two folds of the same level side by side
	-- stay two folds. Filetypes without a scanner fold on markers alone.
	local expr = {}
	for i = 1, #lines do
		local level = (marker[i] or 0) + (struct[i] or 0)
		expr[i] = answer(level, level > 0 and (marker_starts[i] or struct_starts[i]))
	end
	local hit = { tick = api.nvim_buf_get_changedtick(bufnr), expr = expr }
	cache[bufnr] = hit
	return hit
end

local function rescan_later(bufnr)
	local timer = timers[bufnr]
	if not timer then
		timer = vim.uv.new_timer()
		timers[bufnr] = timer
	end
	timer:stop()
	timer:start(PAUSE, 0, function()
		vim.schedule(function()
			if not api.nvim_buf_is_loaded(bufnr) then
				return
			end
			scan(bufnr)
			local count = api.nvim_buf_line_count(bufnr)
			for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
				if vim.wo[win].foldmethod == 'expr' then
					vim._foldupdate(win, 0, count)
				end
			end
		end)
	end)
end

-- The folds around line row (structure and markers alike), innermost
-- first, as { first, last } pairs, read from the foldexpr answers.
function M.folds(bufnr, row)
	local hit = cache[bufnr]
	if not hit or hit.tick ~= api.nvim_buf_get_changedtick(bufnr) then
		hit = scan(bufnr)
	end
	local expr = hit.expr
	local n = #expr
	local level, starts = {}, {}
	for i = 1, n do
		local e = expr[i]
		starts[i] = e:sub(1, 1) == '>'
		level[i] = tonumber(starts[i] and e:sub(2) or e) or 0
	end
	local function at(i)
		return level[i] or 0
	end
	local ranges = {}
	for k = at(row), 1, -1 do
		-- A level-k fold starts where the level rises to k from below, or
		-- where a new level-k fold starts right after a sibling.
		local first = row
		while first > 1 and not (starts[first] and at(first) == k) and at(first - 1) >= k do
			first = first - 1
		end
		local last = row
		while last < n and at(last + 1) >= k and not (starts[last + 1] and at(last + 1) == k) do
			last = last + 1
		end
		ranges[#ranges + 1] = { first, last }
	end
	return ranges
end

function M.level()
	local bufnr = api.nvim_get_current_buf()
	local hit = cache[bufnr]
	if not hit then
		hit = scan(bufnr)
	elseif hit.tick ~= api.nvim_buf_get_changedtick(bufnr) then
		if vim._foldupdate and api.nvim_buf_line_count(bufnr) > BIG then
			hit.tick = api.nvim_buf_get_changedtick(bufnr)
			rescan_later(bufnr)
		else
			hit = scan(bufnr)
		end
	end
	return hit.expr[vim.v.lnum] or '0'
end

local function char_at(text, index)
	return vim.fn.strcharpart(text, index, 1)
end

local function last_chars(text, count)
	local n = vim.fn.strchars(text)
	if n <= count then
		return text
	end
	return vim.fn.strcharpart(text, n - count, count)
end

local function trim_width(text, width)
	if width <= 0 then
		return ''
	end
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	local parts = {}
	local used = 0
	local n = vim.fn.strchars(text)
	for i = 0, n - 1 do
		local ch = char_at(text, i)
		local w = vim.fn.strdisplaywidth(ch)
		if used + w > width then
			break
		end
		parts[#parts + 1] = ch
		used = used + w
	end
	return table.concat(parts)
end

local function expand_tabs(text)
	local spec = vim.opt.listchars:get().tab or '┊ '
	local leader = char_at(spec, 0)
	if leader == '' then
		leader = '┊'
	end
	local parts = {}
	local n = vim.fn.strchars(text)
	for i = 0, n - 1 do
		local ch = char_at(text, i)
		if ch ~= '\t' then
			parts[#parts + 1] = ch
		else
			local column = vim.fn.strdisplaywidth(table.concat(parts))
			local width = vim.fn.strdisplaywidth('\t', column)
			parts[#parts + 1] = leader .. string.rep(' ', math.max(0, width - 1))
		end
	end
	return table.concat(parts)
end

local function nonblank(line, forward)
	if vim.fn.getline(line):match('^%s*$') == nil then
		return line
	end
	local other = forward and vim.fn.nextnonblank(line + 1) or vim.fn.prevnonblank(line - 1)
	if other == 0 then
		return line
	end
	return other
end

function M.text()
	local start_line = nonblank(vim.v.foldstart, true)
	local end_line = nonblank(vim.v.foldend, false)
	local start_text = expand_tabs((vim.fn.getline(start_line):gsub('%s+$', '')))
	local end_text = vim.fn.getline(end_line):gsub('^%s*', ''):gsub('%s+$', '')
	end_text = ' ⋯ ' .. last_chars(end_text, 10) .. ' '

	local fold_lines = 1 + vim.v.foldend - vim.v.foldstart
	local total = math.max(1, vim.fn.line('$'))
	local fold_info = string.format(' +%d (%.1f%%)', fold_lines, 100 * fold_lines / total)

	local win = vim.api.nvim_get_current_win()
	local info = vim.fn.getwininfo(win)[1]
	local textoff = info and info.textoff or 0
	local editor_width = vim.api.nvim_win_get_width(win) - textoff

	local end_width = vim.fn.strdisplaywidth(end_text)
	local info_width = vim.fn.strdisplaywidth(fold_info)
	start_text = trim_width(start_text, editor_width - end_width - info_width - 2)

	local filler = editor_width - vim.fn.strdisplaywidth(start_text) - end_width - info_width
	local expander = ''
	if filler > 0 then
		expander = string.rep('·', filler):gsub('··', '· ')
	end

	return start_text .. end_text .. expander .. fold_info
end

function M.setup()
	_G.Config.foldlevel = M.level
	_G.Config.foldtext = M.text
	vim.opt.foldtext = 'v:lua.Config.foldtext()'
	local group = vim.api.nvim_create_augroup('config_folds', { clear = true })
	vim.api.nvim_create_autocmd({ 'BufUnload', 'FileType' }, {
		group = group,
		callback = function(ev)
			cache[ev.buf] = nil
			if ev.event == 'BufUnload' and timers[ev.buf] then
				timers[ev.buf]:stop()
				timers[ev.buf]:close()
				timers[ev.buf] = nil
			end
		end,
	})
	vim.api.nvim_create_autocmd('OptionSet', {
		group = group,
		pattern = 'foldmarker',
		callback = function()
			cache = {}
		end,
	})
end

return M
