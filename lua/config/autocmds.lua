local M = {}

function M.setup()
	local group = vim.api.nvim_create_augroup('config', { clear = true })

	-- Filetype plugins turn expandtab and shiftwidth back on. Put them back.
	-- shiftwidth 0 follows tabstop.
	vim.api.nvim_create_autocmd('FileType', {
		group = group,
		callback = function()
			vim.bo.expandtab = false
			vim.bo.tabstop = 4
			vim.bo.shiftwidth = 0
		end,
	})

	vim.api.nvim_create_autocmd('BufEnter', {
		group = group,
		callback = function()
			vim.cmd('silent! lcd %:p:h')
		end,
	})
end

return M
