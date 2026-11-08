-- Brace languages: C, C++, Go, Rust, JavaScript, TypeScript, JSON.
--
-- A { ... } block that spans lines is a fold. The fold starts on the line
-- where its statement began, so a function whose { is on the next line
-- folds from its signature, and `} else {` starts a new fold beside the
-- old one. Block comments that span lines fold too.
--
-- Options per language:
--   pp        C preprocessor: #if branches, multi-line #define, #include runs
--   cppraw    C++ raw strings R"x( ... )x"
--   go        `raw strings`
--   rust      raw strings r#"..."#, lifetimes 'a, strings that span lines
--   nested    /* /* */ */ nests
--   js        `template ${strings}` and /regex/ literals
--   brackets  a [ ... ] that spans lines folds too
--   asi       a newline after a value ends the statement (Go, JavaScript)

local u = require('config.foldscan.util')
local add, copy, quoted_end = u.add, u.copy, u.quoted_end

-- A statement that starts with one of these and reaches a ':' is over.
-- The block after `public:` or `case 1:` is not part of it.
local colon_resets = { public = true, private = true, protected = true, case = true, default = true }

-- After these words, a / starts a regex in JavaScript.
local regex_words = {
	['return'] = true,
	typeof = true,
	case = true,
	['do'] = true,
	['else'] = true,
	['in'] = true,
	of = true,
	new = true,
	delete = true,
	void = true,
	throw = true,
	yield = true,
	await = true,
	instanceof = true,
}

-- Go declarations that take a ( ... ) group.
local go_groups = { import = true, const = true, var = true, type = true }

local raw_prefixes = { R = true, LR = true, uR = true, UR = true, u8R = true }

-- Index just past a Rust char literal at i, or nil if the ' starts a
-- lifetime instead.
local function rust_char(line, i)
	for _, p in ipairs({ "^'\\u{[%x_]*}'", "^'\\x%x%x'", "^'\\.'", "^'[^'\\]'", "^'[\192-\244][\128-\191]+'" }) do
		local _, e = line:find(p, i)
		if e then
			return e + 1
		end
	end
	return nil
end

local function scan(lines, o)
	local ranges = {}
	local stack = {} -- open blocks: { first, paren, stmt, kw, bracket }
	local paren = 0 -- open ( and [ inside the current block
	local stmt, stmt_kw = nil, nil
	local frames = {} -- open #if blocks
	local mode = nil -- 'comment', 'close', 'str', or 'tpl' while one is open
	local mode_start = nil
	local depth = 0 -- comment nesting
	local close = nil -- closing text in 'close' mode
	local quote = nil -- closing quote in 'str' mode
	local tpl = {} -- braces open inside each ${ of a template
	local operand = false -- the last token was a value, so / divides
	local directive = nil
	local includes = nil

	local function open(ln)
		stack[#stack + 1] = { first = stmt or ln, paren = paren }
		paren = 0
		stmt, stmt_kw = nil, nil
	end

	local function close_block(ln)
		local top = table.remove(stack)
		if top then
			add(ranges, top.first, ln)
			paren = top.paren
			if top.bracket then
				stmt, stmt_kw = top.stmt, top.kw
				return
			end
		end
		stmt, stmt_kw = nil, nil
	end

	-- A [ ... ] fold keeps the statement it is inside.
	-- A [ ... ] fold (and Go's `import (`) keeps the statement it is
	-- inside. Each item in it starts a statement of its own.
	local function open_bracket(ln, round)
		stack[#stack + 1] = { first = stmt or ln, paren = paren, stmt = stmt or ln, kw = stmt_kw, bracket = true, round = round }
		paren = 0
		stmt, stmt_kw = nil, nil
	end

	local function flush_includes()
		if includes then
			add(ranges, includes[1], includes[2])
			includes = nil
		end
	end

	local function preprocessor(ln, name, line)
		if name == 'include' or name == 'import' then
			if includes then
				includes[2] = ln
			else
				includes = { ln, ln }
			end
			return
		end
		flush_includes()
		if name == 'if' or name == 'ifdef' or name == 'ifndef' then
			frames[#frames + 1] = { start = ln, snap = copy(stack), paren = paren, stmt = stmt, kw = stmt_kw }
		elseif name == 'elif' or name == 'else' or name == 'elifdef' or name == 'elifndef' then
			local f = frames[#frames]
			if f then
				-- Each branch starts from the braces open at #if. After
				-- #endif, the first branch's braces win, so a function
				-- whose header differs per branch still gets one fold.
				if not f.first then
					f.first = { stack = copy(stack), paren = paren, stmt = stmt, kw = stmt_kw }
				end
				add(ranges, f.start, ln - 1)
				f.start = ln
				stack, paren, stmt, stmt_kw = copy(f.snap), f.paren, f.stmt, f.kw
			end
		elseif name == 'endif' then
			local f = table.remove(frames)
			if f then
				add(ranges, f.start, ln)
				if f.first then
					stack, paren, stmt, stmt_kw = f.first.stack, f.first.paren, f.first.stmt, f.first.kw
				end
			end
		end
		if line:sub(-1) == '\\' then
			directive = ln
		end
	end

	for ln, line in ipairs(lines) do
		local i = 1

		if directive then
			if line:sub(-1) ~= '\\' then
				add(ranges, directive, ln)
				directive = nil
			end
			goto next_line
		end
		if o.pp and not mode then
			local name = line:match('^%s*#%s*(%a*)')
			if name then
				preprocessor(ln, name, line)
				goto next_line
			end
			if includes and not line:find('^%s*$') then
				flush_includes()
			end
		end

		while true do
			if mode == 'comment' then
				local e = line:find('*/', i, true)
				local s = o.nested and line:find('/*', i, true)
				if s and (not e or s < e) then
					depth = depth + 1
					i = s + 2
				elseif e then
					i = e + 2
					depth = depth - 1
					if depth == 0 then
						mode = nil
						add(ranges, mode_start, ln)
					end
				else
					break
				end
			elseif mode == 'close' then
				local e = line:find(close, i, true)
				if not e then
					break
				end
				i = e + #close
				mode = nil
				operand = true
			elseif mode == 'str' then
				local e = quoted_end(line, i - 1, quote)
				if not e then
					break
				end
				i = e
				mode = nil
				operand = true
			elseif mode == 'tpl' then
				local k = line:find('[\\`$]', i)
				while k and line:byte(k) == 36 and line:byte(k + 1) ~= 123 do
					k = line:find('[\\`$]', k + 1)
				end
				if not k then
					break
				end
				local c = line:byte(k)
				if c == 92 then
					i = k + 2
				elseif c == 96 then
					i = k + 1
					mode = nil
					operand = true
				else
					tpl[#tpl + 1] = 0
					i = k + 2
					mode = nil
					operand = false
				end
			else
				i = line:find('[^ \t\r\f\v]', i)
				if not i then
					break
				end
				local c = line:byte(i)
				if c == 47 and line:byte(i + 1) == 42 then -- /*
					mode, mode_start, depth = 'comment', ln, 1
					i = i + 2
				elseif c == 47 and line:byte(i + 1) == 47 then -- //
					break
				elseif c == 47 and o.js and not operand then -- /regex/
					local j = i + 1
					local class = false
					while true do
						local d = line:byte(j)
						if not d then
							break
						end
						if d == 92 then
							j = j + 2
						elseif d == 91 then
							class = true
							j = j + 1
						elseif d == 93 then
							class = false
							j = j + 1
						elseif d == 47 and not class then
							j = j + 1
							break
						else
							j = j + 1
						end
					end
					local _, e = line:find('^%a*', j)
					i = e + 1
					operand = true
				elseif c == 34 then -- "
					stmt = stmt or ln
					local e = quoted_end(line, i, '"')
					if e then
						i = e
						operand = true
					elseif o.rust then
						mode, quote = 'str', '"'
						break
					else
						break
					end
				elseif c == 39 then -- '
					stmt = stmt or ln
					if o.rust then
						local e = rust_char(line, i)
						if e then
							i = e
							operand = true
						else
							local _, e2 = line:find("^'[%a_][%w_]*", i)
							i = (e2 or i) + 1
						end
					else
						local e = quoted_end(line, i, "'")
						if not e then
							break
						end
						i = e
						operand = true
					end
				elseif c == 96 and (o.js or o.go) then -- `
					stmt = stmt or ln
					if o.js then
						mode = 'tpl'
						i = i + 1
					else
						local e = line:find('`', i + 1, true)
						if e then
							i = e + 1
							operand = true
						else
							mode, close = 'close', '`'
							break
						end
					end
				elseif c >= 48 and c <= 57 or (c == 46 and line:find('^%d', i + 1)) then
					-- A number, including 1'000 and 1e+5.
					stmt = stmt or ln
					local j = i
					while true do
						local _, e = line:find("^[%w_.']*", j)
						j = e + 1
						if line:sub(e, e):find('[eEpP]') and line:sub(j, j):find('[+-]') then
							j = j + 1
						else
							break
						end
					end
					i = j
					operand = true
				elseif c == 95 or c == 36 or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) then
					local _, e = line:find('^[%w_$]*', i)
					local word = line:sub(i, e)
					i = e + 1
					if not stmt then
						stmt, stmt_kw = ln, word
					end
					operand = not (o.js and regex_words[word])
					local nxt = line:byte(i)
					if o.cppraw and nxt == 34 and raw_prefixes[word] then
						local delim = line:match('^"([^%s()\\]*)%(', i)
						if delim then
							local cl = ')' .. delim .. '"'
							local e2 = line:find(cl, i + #delim + 2, true)
							if not e2 then
								mode, close = 'close', cl
								break
							end
							i = e2 + #cl
						end
					elseif o.rust and (nxt == 34 or nxt == 35) and (word == 'r' or word == 'br' or word == 'cr') then
						local hashes = line:match('^(#*)"', i)
						if hashes then
							local cl = '"' .. hashes
							local e2 = line:find(cl, i + #hashes + 1, true)
							if not e2 then
								mode, close = 'close', cl
								break
							end
							i = e2 + #cl
						end
					end
				elseif c == 123 then -- {
					if #tpl > 0 then
						tpl[#tpl] = tpl[#tpl] + 1
					end
					open(ln)
					i = i + 1
					operand = false
				elseif c == 125 then -- }
					if #tpl > 0 and tpl[#tpl] == 0 then
						tpl[#tpl] = nil
						mode = 'tpl'
					else
						if #tpl > 0 then
							tpl[#tpl] = tpl[#tpl] - 1
						end
						close_block(ln)
						operand = false
					end
					i = i + 1
				elseif o.brackets and c == 91 then
					open_bracket(ln)
					i = i + 1
					operand = false
				elseif o.brackets and c == 93 then
					close_block(ln)
					i = i + 1
					operand = true
				elseif c == 40 and o.go and paren == 0 and go_groups[stmt_kw] then -- import (
					open_bracket(ln, true)
					i = i + 1
					operand = false
				elseif c == 40 or c == 91 then -- ( [
					stmt = stmt or ln
					paren = paren + 1
					i = i + 1
					operand = false
				elseif c == 41 and paren == 0 and stack[#stack] and stack[#stack].round then
					close_block(ln)
					i = i + 1
					operand = true
				elseif c == 41 or c == 93 then -- ) ]
					paren = math.max(0, paren - 1)
					i = i + 1
					operand = true
				elseif c == 59 then -- ;
					stmt, stmt_kw = nil, nil
					i = i + 1
					operand = false
				elseif c == 44 then -- ,
					if paren == 0 then
						stmt, stmt_kw = nil, nil
					end
					i = i + 1
					operand = false
				elseif c == 58 then -- :
					if line:byte(i + 1) == 58 then
						stmt = stmt or ln
						i = i + 2
					else
						if colon_resets[stmt_kw] then
							stmt, stmt_kw = nil, nil
						end
						i = i + 1
					end
					operand = false
				else
					stmt = stmt or ln
					i = i + 1
					operand = false
				end
			end
		end
		-- Go and JavaScript end a statement at a newline after a value.
		if o.asi and not mode and operand and paren == 0 then
			stmt, stmt_kw = nil, nil
		end
		::next_line::
	end
	flush_includes()
	ranges.unclosed = #stack + #frames + (mode and 1 or 0)
	return ranges
end

local function with(o)
	return function(lines)
		return scan(lines, o)
	end
end

local js = { js = true, brackets = true, asi = true }
local json = { brackets = true }

return {
	c = with({ pp = true }),
	cpp = with({ pp = true, cppraw = true }),
	go = with({ go = true, asi = true }),
	rust = with({ rust = true, nested = true, brackets = true }),
	javascript = with(js),
	javascriptreact = with(js),
	typescript = with(js),
	typescriptreact = with(js),
	json = with(json),
	jsonc = with(json),
	json5 = with(json),
}
