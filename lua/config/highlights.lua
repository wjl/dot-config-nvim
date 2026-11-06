local M = {}

local function matchparen()
	-- Underline and foreground only. A filled background looks like a cursor.
	vim.api.nvim_set_hl(0, 'MatchParen', {
		underline = true,
		fg = '#ffd700',
		ctermfg = 11,
		cterm = { underline = true },
	})
end

function M.apply()
	matchparen()
	require('config.statusline').highlights()
	require('config.cursorword').highlights()
end

function M.setup()
	vim.api.nvim_create_autocmd('ColorScheme', {
		group = vim.api.nvim_create_augroup('config_highlights', { clear = true }),
		callback = M.apply,
	})
	vim.cmd.colorscheme('slate')
end

return M
