-- Vimscript, legacy and Vim9: function/def, if, for, while, try, augroup,
-- class/interface/enum, and heredocs (`let x =<< END`, `lua << EOF`).
-- Commands may be abbreviated the way Vim allows, so `fu` and `endf` count.

local u = require('config.foldscan.util')
local add = u.add

-- { full name, shortest abbreviation, what it does }. Order matters:
-- `endfo` must be tried as endfor before endfunction sees `endf`.
local commands = {
	{ 'endfor', 5, 'close' },
	{ 'endfunction', 4, 'close' },
	{ 'endwhile', 4, 'close' },
	{ 'endtry', 4, 'close' },
	{ 'enddef', 4, 'close' },
	{ 'endclass', 8, 'close' },
	{ 'endinterface', 12, 'close' },
	{ 'endenum', 7, 'close' },
	{ 'endif', 2, 'close' },
	{ 'elseif', 5, 'beside' },
	{ 'else', 2, 'beside' },
	{ 'catch', 3, 'beside' },
	{ 'finally', 4, 'beside' },
	{ 'function', 2, 'open' },
	{ 'def', 3, 'open' },
	{ 'if', 2, 'open' },
	{ 'for', 3, 'open' },
	{ 'while', 2, 'open' },
	{ 'try', 3, 'open' },
	{ 'class', 5, 'open' },
	{ 'interface', 9, 'open' },
	{ 'enum', 4, 'open' },
}

local cache = {}
local function command(word)
	local hit = cache[word]
	if hit ~= nil then
		return hit
	end
	hit = false
	for _, c in ipairs(commands) do
		if #word >= c[2] and #word <= #c[1] and c[1]:sub(1, #word) == word then
			hit = c[3]
			break
		end
	end
	cache[word] = hit
	return hit
end

-- Commands that take a heredoc after <<.
local script_cmds = {
	lua = true,
	py = true,
	python = true,
	py3 = true,
	python3 = true,
	pyx = true,
	pythonx = true,
	perl = true,
	pe = true,
	ruby = true,
	rub = true,
	tcl = true,
	mz = true,
	mzscheme = true,
}

-- Commands whose `=<<` starts a heredoc.
local let_cmds = { let = true, var = true, const = true, cons = true, final = true }

local modifiers = { export = true, abstract = true, legacy = true, vim9cmd = true, static = true, public = true }

local function scan(lines)
	local ranges = {}
	local stack = {}
	local here = nil

	local function pop(ln)
		local first = table.remove(stack)
		if first then
			add(ranges, first, ln)
		end
	end

	for ln, line in ipairs(lines) do
		if here then
			local text = here.trim and vim.trim(line) or line
			if text == here.word then
				add(ranges, here.start, ln)
				here = nil
			end
			goto next_line
		end

		do
			local body = line:gsub('^[%s:]+', '')
			local c = body:byte(1)
			-- blank, a comment, or a continued line
			if not c or c == 34 or c == 92 or (c == 35 and body:find('^#[%s{]')) or body == '#' then
				goto next_line
			end

			local word, rest = body:match('^(%a+%d?)!?(.*)$')
			-- A keymap file's table starts here. The rest is data, not commands.
			if word == 'loadkeymap' or word == 'loadk' then
				break
			end
			while word and modifiers[word] do
				word, rest = rest:match('^%s+(%a+)!?(.*)$')
			end
			if not word then
				goto next_line
			end

			-- `let x =<< trim END` and `lua << EOF`
			local marker
			local after = let_cmds[word] and body:match('=<<(.*)$')
			if not after and script_cmds[word] then
				after = rest:match('^%s*<<(.*)$')
				if after then
					marker = { word = '.', trim = false, script = true }
				end
			end
			if after then
				marker = marker or {}
				for tok in after:gmatch('%S+') do
					if tok == 'trim' then
						marker.trim = true
					elseif tok ~= 'eval' then
						marker.word = tok
						break
					end
				end
				-- A :let end marker cannot start with a lower case letter.
				if not marker.word or (not marker.script and marker.word:find('^%l')) then
					marker = nil
				end
			end
			if marker then
				marker.start = ln
				here = marker
				goto next_line
			end

			local what = command(word)
			if what == 'open' then
				-- `if x | return | endif` opens and closes on one line.
				if not body:find('|%s*en%a*%s*$') then
					stack[#stack + 1] = ln
				end
			elseif what == 'beside' then
				pop(ln)
				-- `elseif x | return 1 | endif` closes on the same line.
				if not body:find('|%s*en%a*%s*$') then
					stack[#stack + 1] = ln
				end
			elseif what == 'close' then
				pop(ln)
			elseif #word >= 3 and ('augroup'):sub(1, #word) == word then
				if not body:find('^%a+!') then
					local name = rest:match('^%s*(%S+)')
					if name and name:upper() == 'END' then
						pop(ln)
					elseif name then
						stack[#stack + 1] = ln
					end
				end
			end
		end
		::next_line::
	end
	ranges.unclosed = #stack + (here and 1 or 0)
	ranges.open = stack
	return ranges
end

return { vim = scan }
