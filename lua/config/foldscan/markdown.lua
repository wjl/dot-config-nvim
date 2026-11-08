-- Markdown. *.txt files are markdown too (options.lua).
--
-- A heading's section runs to the next heading of the same or higher rank,
-- so ## sections nest inside # sections. Setext headings (a line over ===
-- or ---) count. A fenced code block folds, and inside it the folds of its
-- language apply. Front matter, multi-line HTML comments, a list of two or
-- more items, and a list item that has sub-items fold too. A list item
-- without sub-items does not.

local u = require('config.foldscan.util')
local add, indent_width = u.add, u.indent_width

-- Fence info words that are not a filetype name.
local fence_alias = {
	sh = 'sh',
	shell = 'sh',
	bash = 'bash',
	zsh = 'zsh',
	ksh = 'ksh',
	js = 'javascript',
	mjs = 'javascript',
	cjs = 'javascript',
	jsx = 'javascriptreact',
	ts = 'typescript',
	tsx = 'typescriptreact',
	py = 'python',
	python3 = 'python',
	rs = 'rust',
	golang = 'go',
	h = 'c',
	['c++'] = 'cpp',
	cc = 'cpp',
	cxx = 'cpp',
	hpp = 'cpp',
	vimscript = 'vim',
	viml = 'vim',
	makefile = 'make',
	mk = 'make',
	ini = 'dosini',
	md = 'markdown',
	txt = 'markdown',
}

local function fence_filetype(info)
	local word = info:match('^%s*{?%s*%.?([%w_+#.-]+)')
	if not word then
		return nil
	end
	word = word:lower()
	return fence_alias[word] or word
end

local function is_rule(line)
	return line:find('^ ? ? ?%-[ \t]*%-[ \t]*%-[%- \t]*$')
		or line:find('^ ? ? ?%*[ \t]*%*[ \t]*%*[%* \t]*$')
		or line:find('^ ? ? ?_[ \t]*_[ \t]*_[_ \t]*$')
end

local function scan(lines)
	local foldscan = require('config.foldscan')
	local ranges = {}
	local headings = {} -- open sections: { level, first }
	local items = {} -- open list items: { indent, first, child }
	local last = 0 -- last line that is not blank
	local prev_blank = true
	local i = 1
	local n = #lines

	local list = nil -- { first, count } of the outermost list

	local function close_items(indent)
		while #items > 0 and indent <= items[#items].indent do
			local it = table.remove(items)
			if it.child then
				add(ranges, it.first, last)
			end
		end
	end

	local function end_list()
		if list and list.count >= 2 then
			add(ranges, list.first, last)
		end
		list = nil
	end

	-- Front matter: --- ... --- (YAML) or +++ ... +++ (TOML) on line 1.
	local first = lines[1] or ''
	if first:find('^%-%-%-%s*$') or first:find('^%+%+%+%s*$') then
		local close = first:sub(1, 1) == '+' and '^%+%+%+%s*$' or '^%-%-%-%s*$'
		for j = 2, n do
			if lines[j]:find(close) or (close ~= '^%+%+%+%s*$' and lines[j]:find('^%.%.%.%s*$')) then
				add(ranges, 1, j)
				last = j
				i = j + 1
				break
			end
		end
	end

	while i <= n do
		local line = lines[i]

		if line:find('^%s*$') then
			prev_blank = true
			i = i + 1
			goto continue
		end

		do
			-- A fenced code block.
			local fence_indent, fence, info = line:match('^(%s*)(```+)([^`]*)$')
			if not fence then
				fence_indent, fence, info = line:match('^(%s*)(~~~+)(.*)$')
			end
			if fence then
				close_items(indent_width(fence_indent, 4))
				if #items == 0 then
					end_list()
				end
				local closing = '^%s*' .. fence:sub(1, 1):rep(#fence) .. fence:sub(1, 1) .. '*%s*$'
				local j = i + 1
				while j <= n and not lines[j]:find(closing) do
					j = j + 1
				end
				local close_line = math.min(j, n)
				add(ranges, i, close_line)
				local ft = fence_filetype(info)
				if ft and ft ~= 'markdown' and ft ~= 'text' and foldscan.supports(ft) then
					local inner = {}
					for k = i + 1, (j <= n and j - 1 or n) do
						inner[#inner + 1] = lines[k]
					end
					local ok, sub = pcall(foldscan.ranges, inner, ft)
					if ok and sub then
						for _, r in ipairs(sub) do
							ranges[#ranges + 1] = { r[1] + i, r[2] + i }
						end
					end
				end
				last = close_line
				prev_blank = false
				i = close_line + 1
				goto continue
			end

			-- A multi-line HTML comment.
			if line:find('^%s*<!%-%-') and not line:find('-->', 1, true) then
				local j = i + 1
				while j <= n and not lines[j]:find('-->', 1, true) do
					j = j + 1
				end
				local close_line = math.min(j, n)
				add(ranges, i, close_line)
				last = close_line
				prev_blank = false
				i = close_line + 1
				goto continue
			end

			-- A heading.
			local hashes = line:match('^ ? ? ?(#+)%s') or line:match('^ ? ? ?(#+)$')
			local level = hashes and #hashes <= 6 and #hashes or nil
			local height = 1
			if not level and prev_blank and i < n and not line:find('^%s*[-*+]%s') and not line:find('^%s*>') and not is_rule(line) then
				local under = lines[i + 1]
				if under:find('^ ? ? ?=+%s*$') then
					level, height = 1, 2
				elseif under:find('^ ? ? ?%-+%s*$') then
					level, height = 2, 2
				end
			end
			if level then
				close_items(-1)
				end_list()
				while #headings > 0 and headings[#headings].level >= level do
					add(ranges, table.remove(headings).first, last)
				end
				headings[#headings + 1] = { level = level, first = i }
				last = i + height - 1
				prev_blank = false
				i = i + height
				goto continue
			end

			-- Anything else is content. A list item with deeper items folds.
			local indent = indent_width(line, 4)
			close_items(indent)
			local item = not is_rule(line)
				and (line:find('^%s*[-*+]%s') or line:find('^%s*[-*+]$') or line:find('^%s*%d+[.)]%s') or line:find('^%s*%d+[.)]$'))
			if #items == 0 then
				if not item then
					end_list()
				elseif list then
					list.count = list.count + 1
				else
					list = { first = i, count = 1 }
				end
			end
			if item then
				if #items > 0 then
					items[#items].child = true
				end
				items[#items + 1] = { indent = indent, first = i, child = false }
			end
			last = i
			prev_blank = false
			i = i + 1
		end
		::continue::
	end
	close_items(-1)
	end_list()
	while #headings > 0 do
		add(ranges, table.remove(headings).first, last)
	end
	return ranges
end

return { markdown = scan, text = scan }
