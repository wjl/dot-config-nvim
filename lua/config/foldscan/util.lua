-- Small helpers the scanners share.

local M = {}

-- A fold range { first, last }. A block on one line is not a fold.
function M.add(ranges, first, last)
	if last > first then
		ranges[#ranges + 1] = { first, last }
	end
end

function M.copy(list)
	local out = {}
	for i, v in ipairs(list) do
		out[i] = v
	end
	return out
end

-- Index just past a quoted string whose opening quote is at i, or nil if
-- the string runs off the end of the line. A backslash skips the next byte.
function M.quoted_end(line, i, quote)
	local pattern = '[\\' .. quote .. ']'
	local j = i + 1
	while true do
		local k = line:find(pattern, j)
		if not k then
			return nil
		end
		if line:byte(k) == 92 then
			j = k + 2
		else
			return k + 1
		end
	end
end

-- Width of the leading white space. A tab goes to the next multiple of
-- `tab`.
function M.indent_width(line, tab)
	tab = tab or 8
	local w = 0
	for i = 1, #line do
		local c = line:byte(i)
		if c == 32 then
			w = w + 1
		elseif c == 9 then
			w = w - w % tab + tab
		else
			break
		end
	end
	return w
end

return M
