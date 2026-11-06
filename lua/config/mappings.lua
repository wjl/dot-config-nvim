local M = {}

local function wild(in_menu, otherwise)
	local menu_key = vim.keycode(in_menu)
	local plain_key = vim.keycode(otherwise)
	return function()
		return vim.fn.wildmenumode() == 1 and menu_key or plain_key
	end
end

function M.setup()
	-- Ex mode is not useful. Q formats instead.
	vim.keymap.set({ 'n', 'v' }, 'Q', 'gq')

	vim.keymap.set('n', '<Space>', 'za')
	vim.keymap.set('n', '<CR>', 'zx')

	-- Arrows follow the menu, which is horizontal, not the history.
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
