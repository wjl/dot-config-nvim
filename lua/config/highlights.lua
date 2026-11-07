local M = {}

local function matchparen()
	-- Underline and foreground only. A filled background looks like a cursor.
	-- folio stores the mate color for the page that just loaded.
	local paren = vim.g.folio_paren
	if vim.g.colors_name == 'folio' and type(paren) == 'table' then
		vim.api.nvim_set_hl(0, 'MatchParen', paren)
		return
	end
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
	-- 'termguicolors' does not reload a scheme on its own. 'background' does.
	-- nested so the ColorScheme autocmd still runs: the reload clears
	-- highlights, and that autocmd puts the status line and text links back.
	vim.api.nvim_create_autocmd('OptionSet', {
		group = vim.api.nvim_create_augroup('config_termguicolors', { clear = true }),
		pattern = 'termguicolors',
		nested = true,
		callback = function()
			if vim.g.colors_name == 'folio' then
				vim.cmd.colorscheme('folio')
			end
		end,
	})
	vim.cmd.colorscheme('folio')
end

return M
