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

function M.setup()
	vim.keymap.set('n', '-', up, { silent = true })
	vim.api.nvim_create_autocmd('FileType', {
		pattern = 'netrw',
		callback = function(event)
			-- netrw's own "-" would win over the global map.
			vim.keymap.set('n', '-', up, { buffer = event.buf, silent = true })
		end,
	})
end

return M
