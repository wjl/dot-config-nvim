local M = {}

function M.setup()
	-- Ex mode is not useful. Q formats instead.
	vim.keymap.set({ 'n', 'v' }, 'Q', 'gq')

	vim.keymap.set('n', '<Space>', 'za')
	vim.keymap.set('n', '<CR>', 'zx')

	-- While the completion menu is open, Up and Down move through the
	-- matches and Left and Right walk directories. Otherwise the arrows
	-- keep their normal command-line meaning.
	-- An expr map already translates <Key> names. vim.keycode() hands it
	-- the raw bytes, and those show up as <80>ku on the command line.
	local function wild(in_menu, otherwise)
		return function()
			return vim.fn.wildmenumode() == 1 and in_menu or otherwise
		end
	end
	vim.keymap.set('c', '<Up>', wild('<Left>', '<Up>'), { expr = true })
	vim.keymap.set('c', '<Down>', wild('<Right>', '<Down>'), { expr = true })
	vim.keymap.set('c', '<Left>', wild('<Up>', '<Left>'), { expr = true })
	vim.keymap.set('c', '<Right>', wild('<Down>', '<Right>'), { expr = true })

	vim.keymap.set('n', 'gS', function()
		local ids = vim.fn.synstack(vim.fn.line('.'), vim.fn.col('.'))
		local names = {}
		for _, id in ipairs(ids) do
			names[#names + 1] = vim.fn.synIDattr(id, 'name')
		end
		vim.api.nvim_echo({ { vim.inspect(names) } }, false, {})
	end)
end

return M
