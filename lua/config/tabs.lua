-- :TabSort orders tab pages by the full path of each tab's current file.
-- Unnamed tabs go last. The tab you were in stays current.

local M = {}

local function tab_number(tab)
	return vim.api.nvim_tabpage_get_number(tab)
end

function M.sort()
	local current = vim.api.nvim_get_current_tabpage()
	local items = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local win = vim.api.nvim_tabpage_get_win(tab)
		local buf = vim.api.nvim_win_get_buf(win)
		items[#items + 1] = {
			tab = tab,
			nr = tab_number(tab),
			name = vim.api.nvim_buf_get_name(buf),
		}
	end

	table.sort(items, function(a, b)
		if a.name ~= b.name then
			if a.name == '' then
				return false
			end
			if b.name == '' then
				return true
			end
			return a.name < b.name
		end
		return a.nr < b.nr
	end)

	-- Positions 1..i-1 are already correct, so the next tab is at i or to the right.
	-- :tabmove N places the current tab after tab page N. Zero makes it first.
	for i, item in ipairs(items) do
		if tab_number(item.tab) ~= i then
			vim.api.nvim_set_current_tabpage(item.tab)
			vim.cmd.tabmove(i - 1)
		end
	end

	if vim.api.nvim_tabpage_is_valid(current) then
		vim.api.nvim_set_current_tabpage(current)
	end
end

function M.setup()
	vim.api.nvim_create_user_command('TabSort', M.sort, {
		desc = 'Sort tabs by the current file path',
	})
end

return M
