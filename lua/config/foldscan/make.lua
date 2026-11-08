-- GNU make: a rule and its recipe, ifeq/ifneq/ifdef/ifndef ... else ...
-- endif, define ... endef, and an assignment continued with backslashes.
--
-- A recipe is the run of tab-started lines after a rule. Blank lines and
-- comments inside it do not end it, and are not counted as its last line.

local u = require('config.foldscan.util')
local add = u.add

local conditionals = { ifeq = true, ifneq = true, ifdef = true, ifndef = true }

-- Is this logical line a rule (target: prerequisites)? Variable
-- references are removed first, so $(x:a=b) does not look like a rule.
local function is_rule(line)
	local s = line:gsub('%$%b()', ''):gsub('%$%b{}', '')
	local colon = s:find(':', 1, true)
	local eq = s:find('=', 1, true)
	if not colon or (eq and eq < colon) then
		return false
	end
	-- :=  ::=  :::=
	return not s:find('^:+=', colon)
end

local function scan(lines)
	local ranges = {}
	local stack = {}
	local rule = nil -- { first, last }
	local define = nil
	local cont = nil -- { first, recipe } while a line ends in a backslash

	local function end_rule()
		if rule then
			add(ranges, rule[1], rule[2])
			rule = nil
		end
	end

	local function pop(ln)
		local first = table.remove(stack)
		if first then
			add(ranges, first, ln)
		end
	end

	for ln, line in ipairs(lines) do
		if define then
			if line:find('^%s*endef%f[%W]') or line:find('^%s*endef$') then
				add(ranges, define, ln)
				define = nil
			end
			goto next_line
		end

		if cont then
			if not line:find('\\$') then
				if cont.recipe then
					rule[2] = ln
				elseif rule and rule[1] == cont.first then
					rule[2] = ln
				else
					add(ranges, cont.first, ln)
				end
				cont = nil
			end
			goto next_line
		end

		if line:byte(1) == 9 and rule then -- a recipe line
			rule[2] = ln
			if line:find('\\$') then
				cont = { first = ln, recipe = true }
			end
			goto next_line
		end

		if line:find('^%s*$') or line:find('^%s*#') then
			goto next_line
		end

		do
			local word = line:match('^%s*([%a-]+)')
			local word2 = line:match('^%s*override%s+([%a-]+)') or line:match('^%s*export%s+([%a-]+)')
			if conditionals[word] then
				end_rule()
				stack[#stack + 1] = ln
			elseif word == 'else' then
				end_rule()
				pop(ln)
				stack[#stack + 1] = ln
			elseif word == 'endif' then
				end_rule()
				pop(ln)
			elseif word == 'define' or word2 == 'define' then
				end_rule()
				define = ln
			else
				end_rule()
				if is_rule(line) then
					rule = { ln, ln }
				end
				if line:find('\\$') then
					cont = { first = ln }
				end
			end
		end
		::next_line::
	end
	end_rule()
	ranges.unclosed = #stack + (define and 1 or 0)
	return ranges
end

return { make = scan }
