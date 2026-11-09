-- "-" opens the directory of the current file and lands on that file.
-- In a directory listing, "-" goes up and lands on the directory just left.

local M = {}

local function seek(name)
	if name == nil or name == '' then
		return
	end
	local pattern = '^\\%(| \\)*' .. vim.fn.escape(name, '.*[]~\\') .. '[/*|@=]\\=\\%($\\|\\t\\)'
	vim.fn.search(pattern, 'wc')
end

local function up()
	if vim.bo.filetype == 'netrw' then
		local dir = vim.b.netrw_curdir or vim.fn.expand('%:p')
		local base = vim.fn.fnamemodify(dir, ':t')
		local parent = vim.fn.fnamemodify(dir, ':h')
		vim.cmd.edit(vim.fn.fnameescape(parent))
		seek(base)
		return
	end

	local path = vim.api.nvim_buf_get_name(0)
	if path == '' or vim.bo.buftype == 'terminal' then
		vim.cmd.edit('.')
		return
	end

	local name = vim.fn.expand('%:t')
	vim.cmd.edit(vim.fn.fnameescape(vim.fn.expand('%:p:h')))
	seek(name)
end

-- In netrw: open the file under the cursor in a tab, and stay here.
function M.background()
	local word = vim.fn['netrw#Call']('NetrwGetWord')
	if word == '' or word:sub(-1) == '/' then
		return
	end
	require('config.tabs').background((vim.b.netrw_curdir or vim.fn.getcwd()) .. '/' .. word)
end

function M.setup()
	vim.keymap.set('n', '-', up, { silent = true })
	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'netrw',
		callback = function(event)
			-- netrw's own "-" would win over the global map.
			vim.keymap.set('n', '-', up, { buffer = event.buf, silent = true })
			-- t (netrw's own) opens in a new tab and goes there. T and the
			-- middle mouse button open in a new tab and stay here. netrw's
			-- Tb and Th would make T wait for a second key, so they go.
			for _, key in ipairs({ 'Tb', 'Th' }) do
				pcall(vim.keymap.del, 'n', key, { buffer = event.buf })
			end
			vim.keymap.set('n', 'T', M.background, { buffer = event.buf, desc = 'Open in a tab, stay here' })
			vim.keymap.set('n', '<MiddleMouse>', '<LeftMouse><Cmd>lua require("config.files").background()<CR>', { buffer = event.buf })
		end,
	})
end

return M
