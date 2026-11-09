local M = {}

function M.setup()
	-- Ex mode is not useful. Q formats instead.
	vim.keymap.set({ 'n', 'v' }, 'Q', 'gq')

	-- Up and Down move by screen row on wrapped lines, and keep the column
	-- you were in across shorter lines, as Neovim already does by file line.
	-- With a count (5<Down>) they move by file line. In insert mode the
	-- completion menu keeps them while it is open.
	local function row(key, g)
		return function()
			return vim.v.count > 0 and key or g
		end
	end
	vim.keymap.set({ 'n', 'x' }, '<Up>', row('<Up>', 'gk'), { expr = true })
	vim.keymap.set({ 'n', 'x' }, '<Down>', row('<Down>', 'gj'), { expr = true })
	vim.keymap.set('i', '<Up>', function()
		return vim.fn.pumvisible() == 1 and '<Up>' or '<Cmd>normal! gk<CR>'
	end, { expr = true })
	vim.keymap.set('i', '<Down>', function()
		return vim.fn.pumvisible() == 1 and '<Down>' or '<Cmd>normal! gj<CR>'
	end, { expr = true })

	vim.keymap.set('n', '<Space>', 'za')
	vim.keymap.set('n', '<CR>', 'zx')

	-- Neovim's own <C-L> (clear search highlighting, update diffs, redraw),
	-- then center the cursor line.
	vim.keymap.set('n', '<C-L>', '<Cmd>nohlsearch|diffupdate|normal! <C-L>zz<CR>')

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
