-- Config files.
--
-- INI and its relatives (systemd units, gitconfig, .desktop): each
-- [section] folds until the next one.
--
-- TOML: each [table] or [[array]] folds until the next header that is not
-- inside it, so [a.b] nests in [a]. Multi-line arrays, inline tables, and
-- strings fold too.
--
-- A section ends on its last line that is not blank and not a comment,
-- because a comment just above a header usually belongs to that header.

local u = require('config.foldscan.util')
local add, quoted_end = u.add, u.quoted_end

local function scan_ini(lines)
	local ranges = {}
	local first = nil
	local last = 0
	for ln, line in ipairs(lines) do
		if line:find('^%s*%[[^%]]*%]') then
			if first then
				add(ranges, first, last)
			end
			first, last = ln, ln
		elseif not line:find('^%s*$') and not line:find('^%s*[;#]') then
			last = ln
		end
	end
	if first then
		add(ranges, first, last)
	end
	return ranges
end

-- The dotted key of a TOML header, as a list of parts.
local function toml_path(text)
	local parts = {}
	local i = 1
	while true do
		i = text:find('[^ \t]', i)
		if not i then
			break
		end
		local c = text:byte(i)
		local part, e
		if c == 34 then
			e = quoted_end(text, i, '"') or #text + 1
			part = text:sub(i + 1, e - 2)
		elseif c == 39 then
			local k = text:find("'", i + 1, true) or #text
			part = text:sub(i + 1, k - 1)
			e = k + 1
		else
			local _, k = text:find('^[%w_%-]*', i)
			part = text:sub(i, k)
			e = k + 1
		end
		parts[#parts + 1] = part
		local dot = text:find('[^ \t]', e)
		if not dot or text:byte(dot) ~= 46 then
			break
		end
		i = dot + 1
	end
	return parts
end

-- a is a proper prefix of b.
local function inside(a, b)
	if #a >= #b then
		return false
	end
	for k = 1, #a do
		if a[k] ~= b[k] then
			return false
		end
	end
	return true
end

local function scan_toml(lines)
	local ranges = {}
	local open = {} -- open headers: { path, first }
	local brackets = {} -- open [ and { in a value
	local last = 0
	local mstr = nil -- an open """ or '''
	local mstr_start = nil

	for ln, line in ipairs(lines) do
		local i = 1
		if mstr then
			local e
			if mstr == '"""' then
				local j = 1
				while true do
					local k = line:find('[\\"]', j)
					if not k then
						break
					end
					if line:byte(k) == 92 then
						j = k + 2
					elseif line:sub(k, k + 2) == '"""' then
						e = k + 3
						break
					else
						j = k + 1
					end
				end
			else
				local k = line:find("'''", 1, true)
				e = k and k + 3
			end
			last = ln
			if not e then
				goto next_line
			end
			add(ranges, mstr_start, ln)
			mstr = nil
			i = e
		elseif #brackets == 0 then
			local inner = line:match('^%s*%[%[(.-)%]%]') or line:match('^%s*%[([^%[].-)%]')
			if inner then
				local path = toml_path(inner)
				while #open > 0 and not inside(open[#open].path, path) do
					add(ranges, table.remove(open).first, last)
				end
				open[#open + 1] = { path = path, first = ln }
				last = ln
				goto next_line
			end
		end

		while true do
			i = line:find('[^ \t\r]', i)
			if not i then
				break
			end
			local c = line:byte(i)
			if c == 35 then -- # a comment does not extend the section
				break
			end
			last = ln
			if c == 34 or c == 39 then
				local q = string.char(c)
				if line:sub(i, i + 2) == q:rep(3) then
					local close = q:rep(3)
					local k = line:find(close, i + 3, true)
					if k then
						i = k + 3
					else
						mstr, mstr_start = close, ln
						break
					end
				elseif c == 34 then
					i = quoted_end(line, i, '"') or #line + 1
				else
					i = (line:find("'", i + 1, true) or #line) + 1
				end
			elseif c == 91 or c == 123 then
				brackets[#brackets + 1] = ln
				i = i + 1
			elseif c == 93 or c == 125 then
				local first = table.remove(brackets)
				if first then
					add(ranges, first, ln)
				end
				i = i + 1
			else
				i = i + 1
			end
		end
		::next_line::
	end
	while #open > 0 do
		add(ranges, table.remove(open).first, last)
	end
	ranges.unclosed = #brackets + (mstr and 1 or 0)
	return ranges
end

return {
	toml = scan_toml,
	dosini = scan_ini,
	confini = scan_ini,
	systemd = scan_ini,
	gitconfig = scan_ini,
	desktop = scan_ini,
}
