-- Status line and tab line in the shape lightline's "one" theme used.
-- Mode color on both ends, filename in the middle band, branch beside it.

local M = {}

local MODES = {
	n = { 'NORMAL', 'Normal' },
	i = { 'INSERT', 'Insert' },
	R = { 'REPLACE', 'Replace' },
	v = { 'VISUAL', 'Visual' },
	V = { 'V-LINE', 'Visual' },
	['\22'] = { 'V-BLOCK', 'Visual' },
	c = { 'COMMAND', 'Normal' },
	s = { 'SELECT', 'Visual' },
	S = { 'S-LINE', 'Visual' },
	['\19'] = { 'S-BLOCK', 'Visual' },
	t = { 'TERMINAL', 'Insert' },
}

-- gui hex, 256-color index, 16-color index
local INK = {
	bg = { '#282c34', 235, 0 },
	fg = { '#abb2bf', 145, 7 },
	green = { '#98c379', 76, 2 },
	blue = { '#61afef', 75, 4 },
	purple = { '#c678dd', 176, 5 },
	red = { '#e06c75', 168, 1 },
	gray2 = { '#2c323d', 235, 0 },
	gray3 = { '#3e4452', 240, 8 },
}

local MODE_BG = {
	Normal = 'green',
	Insert = 'blue',
	Replace = 'red',
	Visual = 'purple',
}

local branch_cache = {}
local branch_generation = 0

local function cterm_index(spec, co)
	if co >= 256 then
		return spec[2]
	end
	local n = spec[3]
	-- 8 is bright black. An 8-color terminal has no such color, and the
	-- raised band has to stay off both the black middle and the mode chip.
	if co < 16 and n >= 8 then
		return 6
	end
	return n
end

local function hl(group, fg, bg, bold)
	local co = tonumber(vim.fn.eval('&t_Co')) or 256
	if co < 8 then
		vim.api.nvim_set_hl(0, group, {
			bold = bold or nil,
			reverse = bold or nil,
		})
		return
	end
	local fg_n = cterm_index(fg, co)
	local bg_n = cterm_index(bg, co)
	vim.api.nvim_set_hl(0, group, {
		fg = fg[1],
		bg = bg[1],
		ctermfg = fg_n,
		ctermbg = bg_n,
		bold = bold or nil,
	})
end

function M.highlights()
	for name, key in pairs(MODE_BG) do
		hl('StlMode' .. name, INK.bg, INK[key], true)
		hl('StlToFile' .. name, INK[key], INK.gray3, false)
		hl('StlFromFile' .. name, INK[key], INK.gray3, false)
	end
	hl('StlSecond', INK.fg, INK.gray3, false)
	hl('StlMiddle', INK.fg, INK.gray2, false)
	hl('StlToMid', INK.gray3, INK.gray2, false)
	hl('StlFromMid', INK.gray3, INK.gray2, false)
	hl('StlInactive', INK.fg, INK.gray2, false)
	hl('StlTab', INK.fg, INK.gray3, false)
	hl('StlTabSel', INK.bg, INK.purple, true)
	hl('StlTabSub', INK.bg, INK.gray3, false)
	hl('StlTabSep', INK.gray3, INK.gray2, false)
	hl('StlTabSepSel', INK.purple, INK.gray2, false)
	hl('StlTabSepSelNext', INK.purple, INK.gray3, false)
	hl('StlTabSepNext', INK.gray3, INK.purple, false)
end

local function mode_parts()
	local mode = vim.api.nvim_get_mode().mode
	local parts = MODES[mode]
	if parts then
		return parts[1], parts[2]
	end
	local first = mode:sub(1, 1)
	parts = MODES[first]
	if parts then
		return parts[1], parts[2]
	end
	return 'NORMAL', 'Normal'
end

local function stl_escape(text)
	return (text:gsub('%%', '%%%%'))
end

local function refresh_branch(cwd)
	local generation = branch_generation
	branch_cache[cwd] = false
	vim.system({ 'git', '-C', cwd, 'rev-parse', '--abbrev-ref', 'HEAD' }, { text = true }, function(obj)
		local name = ''
		if obj.code == 0 then
			name = (obj.stdout or ''):gsub('%s+$', '')
			if name == 'HEAD' then
				name = ''
			end
		end
		vim.schedule(function()
			if generation ~= branch_generation then
				return
			end
			if name == '' and obj.code == 0 then
				vim.system({ 'git', '-C', cwd, 'rev-parse', '--short', 'HEAD' }, { text = true }, function(hash)
					local short = hash.code == 0 and (hash.stdout or ''):gsub('%s+$', '') or ''
					vim.schedule(function()
						if generation ~= branch_generation then
							return
						end
						branch_cache[cwd] = short
						vim.cmd.redrawstatus()
					end)
				end)
				return
			end
			branch_cache[cwd] = name
			vim.cmd.redrawstatus()
		end)
	end)
end

local function branch(win)
	local cwd = vim.fn.getcwd(win)
	local cached = branch_cache[cwd]
	if cached == nil then
		refresh_branch(cwd)
		return ''
	end
	if cached == false then
		return ''
	end
	return cached
end

function M.invalidate_branch()
	branch_generation = branch_generation + 1
	branch_cache = {}
	vim.cmd.redrawstatus()
end

local function join_sub(parts)
	if #parts == 0 then
		return ''
	end
	return ' ' .. table.concat(parts, '  ') .. ' '
end

local function file_parts(buf)
	local bo = vim.bo[buf]
	local parts = {}
	if bo.readonly then
		parts[#parts + 1] = '[RO]'
	end
	local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
	if name == '' then
		name = '[No Name]'
	end
	parts[#parts + 1] = stl_escape(name)
	if not bo.modifiable then
		parts[#parts + 1] = '[-]'
	elseif bo.modified then
		parts[#parts + 1] = '[+]'
	end
	return parts
end

function M.render()
	local ok, text = pcall(function()
		local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
		local buf = vim.api.nvim_win_get_buf(win)
		local active = win == vim.api.nvim_get_current_win()
		if not active then
			local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
			if name == '' then
				name = '[No Name]'
			end
			return '%#StlInactive#' .. join_sub({ stl_escape(name) }) .. '%=' .. ' %3l:%-2v '
		end

		local label, tone = mode_parts()
		if vim.o.paste then
			label = label .. '  PASTE'
		end
		local chunks = {
			'%#StlMode' .. tone .. '# ' .. label .. ' ',
			'%#StlToFile' .. tone .. '#',
			'%#StlSecond#' .. join_sub(file_parts(buf)),
			'%#StlToMid#',
		}
		local git = branch(win)
		if git ~= '' then
			chunks[#chunks + 1] = '%#StlMiddle# ' .. stl_escape(git) .. ' '
		end
		local ft = vim.bo[buf].filetype
		if ft == '' then
			ft = 'no ft'
		end
		local ff = vim.bo[buf].fileformat
		chunks[#chunks + 1] = '%#StlMiddle#%='
		chunks[#chunks + 1] = '%<' .. join_sub({ ff, ft })
		chunks[#chunks + 1] = '%#StlFromMid#'
		chunks[#chunks + 1] = '%#StlSecond# %3p%% '
		chunks[#chunks + 1] = '%#StlFromFile' .. tone .. '#'
		chunks[#chunks + 1] = '%#StlMode' .. tone .. '# %3l:%-2v '
		return table.concat(chunks)
	end)
	if not ok then
		return '%#StatusLine# statusline error '
	end
	return text
end

-- Which tabs the tab line shows. `first` is the leftmost tab shown.
-- Moving to another tab (or opening or closing one) brings the current tab
-- into view with a neighbor on each side; the mouse wheel over the tab
-- line scrolls it without changing tabs, until the next tab change.
local view = { first = 1, follow = true }

-- Tab titles: the file name, or as many parent directories as it takes to
-- tell it apart from the other tabs' files: Makefile, or x/Makefile and
-- y/Makefile.
local function titles(paths)
	local parts, depth = {}, {}
	for i, path in ipairs(paths) do
		parts[i] = vim.split(path, '/', { plain = true, trimempty = true })
		depth[i] = 1
	end
	local function suffix(i)
		local p = parts[i]
		return table.concat(p, '/', math.max(1, #p - depth[i] + 1))
	end
	local changed = true
	while changed do
		changed = false
		local seen = {}
		for i in ipairs(paths) do
			if paths[i] ~= '' then
				local key = suffix(i)
				seen[key] = seen[key] or {}
				table.insert(seen[key], i)
			end
		end
		for _, group in pairs(seen) do
			if #group > 1 then
				for _, i in ipairs(group) do
					-- The same file in two tabs cannot be told apart; stop there.
					if depth[i] < #parts[i] and paths[i] ~= paths[group[1] == i and group[2] or group[1]] then
						depth[i] = depth[i] + 1
						changed = true
					end
				end
			end
		end
	end
	local out = {}
	for i in ipairs(paths) do
		out[i] = paths[i] == '' and '' or suffix(i)
	end
	return out
end

local function tab_items()
	local items = {}
	local current = vim.api.nvim_get_current_tabpage()
	local tabs = vim.api.nvim_list_tabpages()
	local bufs, paths = {}, {}
	for i, tab in ipairs(tabs) do
		bufs[i] = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tab))
		local name = vim.api.nvim_buf_get_name(bufs[i])
		paths[i] = name ~= '' and vim.fs.normalize(vim.fn.fnamemodify(name, ':p')):gsub('/$', '') or ''
	end
	local names = titles(paths)
	for i, tab in ipairs(tabs) do
		local buf = bufs[i]
		local name = names[i]
		if name == '' then
			name = '[No Name]'
		end
		local flags = ''
		if not vim.bo[buf].modifiable then
			flags = ' [-]'
		elseif vim.bo[buf].modified then
			flags = ' [+]'
		end
		local text = ' ' .. i .. ' ' .. name .. flags .. ' '
		items[i] = { nr = i, text = text, width = vim.fn.strdisplaywidth(text), selected = tab == current }
		if tab == current then
			items.current = i
		end
	end
	return items
end

-- How many tabs are hidden at each end: "‹3 " at the left, " 5›" at the right.
local function left_marker(n)
	return n > 0 and ('‹' .. n .. ' ') or ''
end
local function right_marker(n)
	return n > 0 and (' ' .. n .. '›') or ''
end

-- Columns the tabs first..last take, plus the markers for hidden tabs.
local function span(items, first, last)
	local w = vim.fn.strdisplaywidth(left_marker(first - 1)) + vim.fn.strdisplaywidth(right_marker(#items - last))
	for i = first, last do
		w = w + items[i].width
	end
	return w
end

local function choose_first(items, width)
	local n = #items
	local first = math.max(1, math.min(view.first, n))
	if view.follow and items.current then
		local cur = items.current
		local lo, hi = math.max(1, cur - 1), math.min(n, cur + 1)
		-- The current tab and both neighbors when they fit; otherwise the
		-- current tab with whatever of the next one fits.
		if span(items, lo, hi) > width then
			lo, hi = cur, cur
		end
		if first > lo then
			first = lo
		end
		while first < lo and span(items, first, hi) > width do
			first = first + 1
		end
	end
	-- No empty space at the right while tabs are hidden on the left.
	while first > 1 and span(items, first - 1, n) <= width do
		first = first - 1
	end
	return first
end

function M.tabline()
	local ok, text = pcall(function()
		local items = tab_items()
		local n = #items
		local width = vim.o.columns
		local first = choose_first(items, width)
		view.first = first

		local chunks = {}
		local used = 0
		local left = left_marker(first - 1)
		if left ~= '' then
			chunks[#chunks + 1] = '%#StlTabSub#' .. left
			used = used + vim.fn.strdisplaywidth(left)
		end
		local last = first - 1
		for i = first, n do
			local item = items[i]
			local right = right_marker(n - i)
			local room = width - used - vim.fn.strdisplaywidth(right)
			if item.width > room and i > first then
				-- Cut the last one that does not fit; the marker says how many follow.
				local cut = vim.fn.strcharpart(item.text, 0, math.max(0, width - used - vim.fn.strdisplaywidth(right_marker(n - i + 1))))
				if cut ~= '' then
					chunks[#chunks + 1] = (item.selected and '%#StlTabSel#' or '%#StlTab#') .. '%' .. item.nr .. 'T' .. stl_escape(cut) .. '%T'
				end
				break
			end
			chunks[#chunks + 1] = (item.selected and '%#StlTabSel#' or '%#StlTab#') .. '%' .. item.nr .. 'T' .. stl_escape(item.text) .. '%T'
			chunks[#chunks + 1] = '%#StlTabSub#'
			used = used + item.width
			last = i
		end
		chunks[#chunks + 1] = '%#StlMiddle#%='
		if n - last > 0 then
			chunks[#chunks + 1] = '%#StlTabSub#' .. right_marker(n - last)
		end
		return table.concat(chunks)
	end)
	if not ok then
		return ''
	end
	return text
end

-- Mouse wheel over the tab line: scroll it. Anywhere else: the usual.
local function wheel(key, step)
	return function()
		if vim.fn.getmousepos().screenrow == 1 and vim.o.showtabline > 0 and (vim.o.showtabline == 2 or #vim.api.nvim_list_tabpages() > 1) then
			local n = #vim.api.nvim_list_tabpages()
			view.first = math.max(1, math.min(n, view.first + step))
			view.follow = false
			vim.cmd('redrawtabline')
			return ''
		end
		return key
	end
end

function M.setup()
	M.highlights()
	vim.o.statusline = '%{%v:lua.require("config.statusline").render()%}'
	vim.o.tabline = '%{%v:lua.require("config.statusline").tabline()%}'
	vim.api.nvim_create_autocmd({ 'TabEnter', 'TabNew', 'TabClosed', 'VimResized' }, {
		group = vim.api.nvim_create_augroup('config_tabline', { clear = true }),
		callback = function()
			view.follow = true
		end,
	})
	for _, mode in ipairs({ 'n', 'i', 'v', 't' }) do
		vim.keymap.set(mode, '<ScrollWheelUp>', wheel('<ScrollWheelUp>', -1), { expr = true })
		vim.keymap.set(mode, '<ScrollWheelDown>', wheel('<ScrollWheelDown>', 1), { expr = true })
	end
	vim.api.nvim_create_autocmd({ 'FocusGained', 'DirChanged', 'BufWritePost' }, {
		group = vim.api.nvim_create_augroup('config_statusline', { clear = true }),
		callback = function()
			M.invalidate_branch()
		end,
	})
end

return M
