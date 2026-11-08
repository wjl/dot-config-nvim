-- Python: a block is a logical line ending in ':' and every deeper line
-- after it. Decorators above a def or class are part of its fold. elif,
-- else, except, finally, and case each fold beside the one before.

local u = require('config.foldscan.util')
local add, quoted_end, indent_width = u.add, u.quoted_end, u.indent_width

local function scan(lines)
	local ranges = {}
	local stack = {} -- open blocks: { indent, first }
	local prev_last = 0 -- last line of the previous logical line
	local deco = nil -- { indent, first } of a run of decorators

	local triple = nil -- an open ''' or """
	local depth = 0 -- open brackets
	local logical = nil -- the logical line being read

	local function finish(l)
		while #stack > 0 and l.indent <= stack[#stack].indent do
			local b = table.remove(stack)
			add(ranges, b.first, prev_last)
		end
		if l.at then
			if not (deco and deco.indent == l.indent) then
				deco = { indent = l.indent, first = l.first }
			end
		else
			if l.colon then
				local first = l.first
				if deco and deco.indent == l.indent then
					first = deco.first
				end
				stack[#stack + 1] = { indent = l.indent, first = first }
			end
			deco = nil
		end
		prev_last = l.last
	end

	for ln, line in ipairs(lines) do
		local i = 1
		if not logical then
			local s = line:find('[^ \t\r\f\v]')
			if not s or line:byte(s) == 35 then -- blank, or only a comment
				goto next_line
			end
			logical = { first = ln, indent = indent_width(line), at = line:byte(s) == 64 }
			i = s
		end
		do
			local last_sig = nil -- the last character that is not a comment or space
			if triple then
				local e = line:find(triple, 1, true)
				if not e then
					goto next_line
				end
				i = e + 3
				triple = nil
				last_sig = 0
			end
			while true do
				i = line:find('[^ \t\r\f\v]', i)
				if not i then
					break
				end
				local c = line:byte(i)
				if c == 35 then -- #
					break
				elseif c == 34 or c == 39 then
					local q = string.char(c)
					local q3 = q:rep(3)
					if line:sub(i, i + 2) == q3 then
						local j = i + 3
						local e
						while true do
							local k = line:find('[\\' .. q .. ']', j)
							if not k then
								break
							end
							if line:byte(k) == 92 then
								j = k + 2
							elseif line:sub(k, k + 2) == q3 then
								e = k + 3
								break
							else
								j = k + 1
							end
						end
						if not e then
							triple = q3
							break
						end
						i = e
					else
						i = quoted_end(line, i, q) or #line + 1
					end
					last_sig = c
				else
					if c == 40 or c == 91 or c == 123 then
						depth = depth + 1
					elseif c == 41 or c == 93 or c == 125 then
						depth = math.max(0, depth - 1)
					end
					last_sig = c
					i = i + 1
				end
			end
			if triple or depth > 0 then
				goto next_line
			end
			-- A backslash at the very end joins the next line.
			if last_sig == 92 then
				goto next_line
			end
			logical.last = ln
			logical.colon = last_sig == 58
			finish(logical)
			logical = nil
		end
		::next_line::
	end
	if logical then
		logical.last = #lines
		finish(logical)
	end
	ranges.unclosed = (triple and 1 or 0) + depth
	while #stack > 0 do
		local b = table.remove(stack)
		add(ranges, b.first, prev_last)
	end
	return ranges
end

return { python = scan }
