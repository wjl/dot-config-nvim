-- Lua: function, if, do, while, for, repeat, and a table that spans lines.
-- elseif and else fold beside the branch before. while and for open at
-- the keyword, so their own do does not open a second fold.

local u = require('config.foldscan.util')
local add, quoted_end = u.add, u.quoted_end

-- Index just past a long bracket [==[ ... ]==] that opens at i. If it runs
-- past this line, nil and the closing text.
local function long_bracket(line, i)
	local eq = line:match('^%[(=*)%[', i)
	if not eq then
		return nil
	end
	local close = ']' .. eq .. ']'
	local e = line:find(close, i + #eq + 2, true)
	if e then
		return e + #close
	end
	return nil, close
end

local function scan(lines)
	local ranges = {}
	local stack = {}
	local want_do = 0
	local long_close = nil

	local function pop(ln)
		local first = table.remove(stack)
		if first then
			add(ranges, first, ln)
		end
	end

	for ln, line in ipairs(lines) do
		local i = 1
		if long_close then
			local e = line:find(long_close, 1, true)
			if not e then
				goto next_line
			end
			i = e + #long_close
			long_close = nil
		end
		while true do
			i = line:find('[^ \t\r\f\v]', i)
			if not i then
				break
			end
			local c = line:byte(i)
			if c == 45 and line:byte(i + 1) == 45 then -- --
				local e, close = long_bracket(line, i + 2)
				if e then
					i = e
				elseif close then
					long_close = close
					break
				else
					break
				end
			elseif c == 91 then -- [
				local e, close = long_bracket(line, i)
				if e then
					i = e
				elseif close then
					long_close = close
					break
				else
					i = i + 1
				end
			elseif c == 34 or c == 39 then
				i = quoted_end(line, i, string.char(c)) or #line + 1
			elseif c == 95 or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) then
				local _, e = line:find('^[%w_]*', i)
				local word = line:sub(i, e)
				-- A name after . or : is a field, never a keyword.
				local before = line:sub(1, i - 1):match('(%S)%s*$')
				i = e + 1
				if before ~= '.' and before ~= ':' then
					if word == 'function' or word == 'if' or word == 'repeat' then
						stack[#stack + 1] = ln
					elseif word == 'while' or word == 'for' then
						stack[#stack + 1] = ln
						want_do = want_do + 1
					elseif word == 'do' then
						if want_do > 0 then
							want_do = want_do - 1
						else
							stack[#stack + 1] = ln
						end
					elseif word == 'elseif' or word == 'else' then
						pop(ln)
						stack[#stack + 1] = ln
					elseif word == 'end' or word == 'until' then
						pop(ln)
					end
				end
			elseif c == 123 then
				stack[#stack + 1] = ln
				i = i + 1
			elseif c == 125 then
				pop(ln)
				i = i + 1
			elseif c >= 48 and c <= 57 then
				local _, e = line:find('^[%w_.]*', i)
				i = e + 1
				if line:sub(e, e):find('[eEpP]') and line:sub(i, i):find('[+-]') then
					i = i + 1
				end
			else
				i = i + 1
			end
		end
		::next_line::
	end
	ranges.unclosed = #stack + (long_close and 1 or 0)
	return ranges
end

return { lua = scan }
