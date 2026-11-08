-- POSIX sh, bash, and zsh: if/elif/else/fi, while/until/for/select ...
-- do/done, case/esac, { } groups and function bodies, and heredocs.
--
-- A keyword counts only where a command can start, so `echo done` is not
-- the end of a loop. Quotes and $( ) nest the way the shell nests them,
-- across lines too, so "$(echo "x")" and a quoted awk program are skipped
-- correctly. ${...}, $((...)), $'...', and comments are skipped.

local u = require('config.foldscan.util')
local add, quoted_end = u.add, u.quoted_end

-- Characters that end a plain word.
local word_end = '[%s;&|()<>\'"`$]'

-- Index just past the } that matches the { at i, or the end of the line.
local function skip_braces(line, i)
	local level = 0
	local j = i
	while j <= #line do
		local b = line:byte(j)
		if b == 123 then
			level = level + 1
		elseif b == 125 then
			level = level - 1
			if level == 0 then
				return j + 1
			end
		elseif b == 92 then
			j = j + 1
		end
		j = j + 1
	end
	return #line + 1
end

local function scan(lines)
	local ranges = {}
	local stack = {}
	local want_do = 0
	local ctx = {} -- open quotes and $( ), across lines
	local heredocs = {} -- waiting to start after this line
	local here = nil -- the heredoc being read
	local cmd = true -- the next word is in command position
	local after_function = false -- the next word is a function name
	local brace_ok = false -- a { here opens a function body
	local continued = false

	local function push(ln, brace)
		stack[#stack + 1] = { ln, brace }
	end

	local function pop(ln)
		local top = table.remove(stack)
		if top then
			add(ranges, top[1], ln)
		end
	end

	local function keyword(word, ln)
		if word == 'if' then
			push(ln)
		elseif word == 'then' or word == '!' or word == 'time' then
			cmd = true
			return
		elseif word == 'elif' or word == 'else' then
			pop(ln)
			push(ln)
		elseif word == 'fi' or word == 'done' or word == 'esac' then
			pop(ln)
			cmd = false
			return
		elseif word == 'while' or word == 'until' then
			push(ln)
			want_do = want_do + 1
		elseif word == 'for' or word == 'select' then
			push(ln)
			want_do = want_do + 1
			cmd = false
			return
		elseif word == 'do' then
			if want_do > 0 then
				want_do = want_do - 1
			else
				push(ln)
			end
		elseif word == 'case' then
			push(ln)
			cmd = false
			return
		elseif word == 'function' then
			after_function = true
			cmd = false
			return
		else
			cmd = false
			return
		end
		cmd = true
	end

	for ln, line in ipairs(lines) do
		if here then
			local text = here.strip and line:gsub('^\t+', '') or line
			if text == here.word then
				add(ranges, here.start, ln)
				here = table.remove(heredocs, 1)
			end
			goto next_line
		end

		do
			local n = #line
			local i = 1
			local top = ctx[#ctx]
			if not continued and (not top or top.kind == 'cmd') then
				cmd = true
			end
			continued = false

			while i <= n do
				top = ctx[#ctx]
				local kind = top and top.kind
				if kind == 'sq' then
					local e = line:find("'", i, true)
					if not e then
						break
					end
					i = e + 1
					ctx[#ctx] = nil
					cmd = false
				elseif kind == 'bq' then
					local e = quoted_end(line, i - 1, '`')
					if not e then
						break
					end
					i = e
					ctx[#ctx] = nil
					cmd = false
				elseif kind == 'dq' then
					local k = line:find('[\\"`$]', i)
					if not k then
						break
					end
					local b = line:byte(k)
					if b == 92 then
						i = k + 2
					elseif b == 34 then
						i = k + 1
						ctx[#ctx] = nil
						cmd = false
					elseif b == 96 then
						i = k + 1
						ctx[#ctx + 1] = { kind = 'bq' }
					else -- $
						local d = line:byte(k + 1)
						if d == 40 and line:byte(k + 2) == 40 then
							local e = line:find('))', k + 3, true)
							i = e and e + 2 or n + 1
						elseif d == 40 then
							i = k + 2
							ctx[#ctx + 1] = { kind = 'cmd', depth = 0 }
							cmd = true
						elseif d == 123 then
							i = skip_braces(line, k + 1)
						else
							i = k + 1
						end
					end
				else
					-- Code: the top level, or inside $( ).
					i = line:find('[^ \t\r\f\v]', i)
					if not i then
						break
					end
					local c = line:byte(i)
					if c == 35 then -- # at the start of a word
						break
					elseif c == 39 then -- '
						local e = line:find("'", i + 1, true)
						if e then
							i = e + 1
						else
							ctx[#ctx + 1] = { kind = 'sq' }
							i = n + 1
						end
						cmd = false
					elseif c == 34 then -- "
						ctx[#ctx + 1] = { kind = 'dq' }
						i = i + 1
					elseif c == 96 then -- `
						ctx[#ctx + 1] = { kind = 'bq' }
						i = i + 1
					elseif c == 36 then -- $
						local d = line:byte(i + 1)
						if d == 39 then -- $'...'
							i = quoted_end(line, i + 1, "'") or n + 1
						elseif d == 123 then -- ${...}
							i = skip_braces(line, i + 1)
						elseif d == 40 and line:byte(i + 2) == 40 then -- $(( ))
							local e = line:find('))', i + 3, true)
							i = e and e + 2 or n + 1
						elseif d == 40 then -- $( )
							ctx[#ctx + 1] = { kind = 'cmd', depth = 0 }
							i = i + 2
							cmd = true
							goto continue
						elseif d and line:find('^[%w_]', i + 1) then -- $name
							local _, e = line:find('^[%w_]*', i + 1)
							i = e + 1
						elseif d and line:find('^[?#@$!*%-]', i + 1) then -- $? $# ...
							i = i + 2
						else -- $"..." and a lone $: the quote is read next
							i = i + 1
						end
						cmd = false
					elseif c == 92 then -- \
						if i == n then
							continued = true
							break
						end
						i = i + 2
						cmd = false
					elseif c == 60 and line:byte(i + 1) == 60 and line:byte(i + 2) == 60 then -- <<< here-string
						i = i + 3
					elseif c == 60 and line:byte(i + 1) == 60 then -- << heredoc
						local dash, rest = line:match('^<<(%-?)%s*(.*)$', i)
						local word = rest:match('^[\'"]([^\'"]+)[\'"]') or rest:match('^\\?([%w_%-%.]+)')
						if word then
							heredocs[#heredocs + 1] = { word = word, strip = dash == '-', start = ln }
							local _, e = line:find('^<<%-?%s*[\'"\\]?[%w_%-%.]+[\'"]?', i)
							i = (e or i + 1) + 1
						else
							i = i + 2
						end
					elseif c == 40 and line:byte(i + 1) == 40 then -- (( arithmetic ))
						local e = line:find('))', i + 2, true)
						i = e and e + 2 or n + 1
						cmd = false
					elseif c == 40 then -- (
						if kind == 'cmd' then
							top.depth = top.depth + 1
						end
						-- x=( ... ) is an array, not a subshell.
						cmd = line:byte(i - 1) ~= 61
						i = i + 1
					elseif c == 41 then -- )
						i = i + 1
						if kind == 'cmd' then
							if top.depth == 0 then
								ctx[#ctx] = nil
								cmd = false
								goto continue
							end
							top.depth = top.depth - 1
						end
						cmd = true
					elseif c == 59 or c == 38 or c == 124 then -- ; & |
						i = i + 1
						cmd = true
					elseif c == 60 or c == 62 then -- < >
						i = i + 1
					else
						local j = i
						while j <= n do
							local b = line:byte(j)
							if b == 92 then
								j = j + 2
							elseif line:find('^' .. word_end, j) then
								break
							else
								j = j + 1
							end
						end
						local word = line:sub(i, j - 1)
						-- { and } are reserved words only when they stand alone.
						local alone
						if word == '{' then
							alone = j > n or line:find('^%s', j) ~= nil
						else
							alone = j > n or line:find('^[%s;&|)]', j) ~= nil
						end
						i = j
						local named = after_function
						after_function = false
						if word == '{' and alone and (cmd or brace_ok) then
							push(ln, true)
							cmd = true
							brace_ok = false
						elseif named then
							-- `function name {`: the { after the name opens the body.
							brace_ok = true
							cmd = false
						elseif word:find('^}+$') and alone and (cmd or (stack[#stack] and stack[#stack][2])) then
							-- zsh also closes `{ cmd }` without a ;, and `}}` closes two.
							for _ = 1, #word do
								if not (stack[#stack] and stack[#stack][2]) and not cmd then
									break
								end
								pop(ln)
							end
							cmd = false
						elseif cmd then
							keyword(word, ln)
							if word ~= 'function' then
								brace_ok = false
							end
						else
							brace_ok = false
						end
					end
				end
				::continue::
			end
			if #heredocs > 0 and not here then
				here = table.remove(heredocs, 1)
			end
		end
		::next_line::
	end
	ranges.unclosed = #stack + #ctx + (here and 1 or 0)
	ranges.open = {}
	for k, v in ipairs(stack) do
		ranges.open[k] = v[1]
	end
	return ranges
end

return { sh = scan, bash = scan, zsh = scan, ksh = scan }
