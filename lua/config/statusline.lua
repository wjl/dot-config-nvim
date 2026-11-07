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

function M.tabline()
	local ok, text = pcall(function()
		local tabs = vim.api.nvim_list_tabpages()
		local current = vim.api.nvim_get_current_tabpage()
		local chunks = {}
		for i, tab in ipairs(tabs) do
			local win = vim.api.nvim_tabpage_get_win(tab)
			local buf = vim.api.nvim_win_get_buf(win)
			local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
			if name == '' then
				name = '[No Name]'
			end
			local flags = ''
			if not vim.bo[buf].modifiable then
				flags = ' [-]'
			elseif vim.bo[buf].modified then
				flags = ' [+]'
			end
			local selected = tab == current
			local nr = vim.api.nvim_tabpage_get_number(tab)
			local next_selected = tabs[i + 1] == current
			local last = i == #tabs
			chunks[#chunks + 1] = (selected and '%#StlTabSel#' or '%#StlTab#')
			chunks[#chunks + 1] = '%' .. nr .. 'T ' .. nr .. ' ' .. stl_escape(name) .. flags .. ' %T'
			if selected and last then
				chunks[#chunks + 1] = '%#StlTabSepSel#'
			elseif selected then
				chunks[#chunks + 1] = '%#StlTabSepSelNext#'
			elseif next_selected then
				chunks[#chunks + 1] = '%#StlTabSepNext#'
			elseif last then
				chunks[#chunks + 1] = '%#StlTabSep#'
			else
				chunks[#chunks + 1] = '%#StlTabSub#'
			end
		end
		chunks[#chunks + 1] = '%#StlMiddle#'
		return table.concat(chunks)
	end)
	if not ok then
		return ''
	end
	return text
end

function M.setup()
	M.highlights()
	vim.o.statusline = '%{%v:lua.require("config.statusline").render()%}'
	vim.o.tabline = '%{%v:lua.require("config.statusline").tabline()%}'
	vim.api.nvim_create_autocmd({ 'FocusGained', 'DirChanged', 'BufWritePost' }, {
		group = vim.api.nvim_create_augroup('config_statusline', { clear = true }),
		callback = function()
			M.invalidate_branch()
		end,
	})
end

return M
