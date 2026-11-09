-- One tab per file, like most editors.
--
-- Opening a file that already has a tab goes to that tab instead: :tabe,
-- :e, netrw, :b, gf, and so on. A tab opened just for the duplicate closes;
-- a tab that was switched to it (:e, or "-" then Enter in netrw) goes
-- back to the file it had, or closes when that was not a file (netrw).
--
-- Only a tab's own file counts: a window that shares its tab with others
-- (:split, :vsplit, :diffsplit) can show anything. Help, quickfix,
-- terminals, and other special buffers are never touched. Closing a tab
-- always works; its file stays loaded in the background as a hidden
-- buffer, and :b brings it back.
--
-- When a file's tab is reused, it moves to where a new tab would have
-- opened, right after the tab you came from. :TabSort is still manual.
--
-- In netrw, t opens a file in a new tab and goes there (netrw's own); T and
-- the middle mouse button open it in a tab and stay in netrw. Several in a
-- row line up after each other.
--
-- `nvim a b c` opens a tab per file, as -p does, with no 10 or 50 limit.
--
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

local api = vim.api

local function is_file(buf)
	return buf > 0
		and api.nvim_buf_is_valid(buf)
		and vim.bo[buf].buftype == ''
		and api.nvim_buf_get_name(buf) ~= ''
		and vim.bo[buf].filetype ~= 'netrw'
end

-- Ordinary windows of a tab; floating windows do not count.
local function windows(tab)
	local wins = {}
	for _, w in ipairs(api.nvim_tabpage_list_wins(tab)) do
		if api.nvim_win_get_config(w).relative == '' then
			wins[#wins + 1] = w
		end
	end
	return wins
end

-- A window in a tab other than skip that shows buf on its own.
local function home(buf, skip)
	for _, tab in ipairs(api.nvim_list_tabpages()) do
		if tab ~= skip then
			local wins = windows(tab)
			if #wins == 1 and api.nvim_win_get_buf(wins[1]) == buf then
				return wins[1]
			end
		end
	end
end

local function shown(buf)
	return #vim.fn.win_findbuf(buf) > 0
end

local function number(tab)
	return api.nvim_tabpage_get_number(tab)
end

-- Put tab right after tab number `after` (0: first), and stay where you
-- were. :tabmove N puts the current tab after the tab that is number N
-- now, from either side.
local function place(tab, after)
	if number(tab) == after + 1 then
		return
	end
	local cur = api.nvim_get_current_tabpage()
	api.nvim_set_current_tabpage(tab)
	vim.cmd('tabmove ' .. after)
	if cur ~= tab and api.nvim_tabpage_is_valid(cur) then
		api.nvim_set_current_tabpage(cur)
	end
end

local function dedupe(win)
	if not api.nvim_win_is_valid(win) then
		return
	end
	local buf = api.nvim_win_get_buf(win)
	local tab = api.nvim_win_get_tabpage(win)
	if not is_file(buf) or #windows(tab) ~= 1 or vim.wo[win].diff then
		return
	end
	local other = home(buf, tab)
	if not other then
		return
	end

	-- Put back what this tab showed before, if that was a file that is now
	-- in no window. Otherwise this tab was only ever for the duplicate.
	local prev = api.nvim_win_call(win, function()
		return vim.fn.bufnr('#')
	end)
	-- The file's tab moves to where a new tab would have opened: right
	-- after the tab you came from, so it is not 100 tabs away.
	local after
	if prev ~= buf and is_file(prev) and api.nvim_buf_is_loaded(prev) and not shown(prev) then
		api.nvim_win_set_buf(win, prev)
		after = number(tab)
	elseif #api.nvim_list_tabpages() > 1 then
		-- Tabs left of this one keep their numbers when it closes.
		after = number(tab) - 1
		api.nvim_win_close(win, false)
	end
	if api.nvim_win_is_valid(other) then
		local other_tab = api.nvim_win_get_tabpage(other)
		if after then
			place(other_tab, after)
		end
		api.nvim_set_current_tabpage(other_tab)
		api.nvim_set_current_win(other)
	end
end

local function find(path)
	for _, b in ipairs(api.nvim_list_bufs()) do
		if api.nvim_buf_get_name(b) == path then
			return b
		end
	end
end

-- Open path in a tab without leaving this one. Several in a row line up
-- after each other, as background tabs in a browser do. A file that has
-- a tab already gets that tab moved here instead.
function M.background(path)
	path = vim.fn.fnamemodify(path, ':p')
	local here = api.nvim_get_current_tabpage()
	local ok, last = pcall(api.nvim_tabpage_get_var, here, 'background_last')
	local after = number(here)
	if ok and api.nvim_tabpage_is_valid(last) and number(last) > after then
		after = number(last)
	end

	local buf = find(path)
	local win = buf and home(buf, nil)
	local tab
	if win then
		tab = api.nvim_win_get_tabpage(win)
		if tab == here then
			return
		end
		place(tab, after)
	else
		vim.cmd(after .. 'tabedit ' .. vim.fn.fnameescape(path))
		tab = api.nvim_get_current_tabpage()
		api.nvim_set_current_tabpage(here)
	end
	api.nvim_tabpage_set_var(here, 'background_last', tab)
	vim.api.nvim_echo({ { ('"%s" in tab %d'):format(vim.fn.fnamemodify(path, ':~:.'), number(tab)) } }, false, {})
end

function M.setup()
	vim.api.nvim_create_user_command('TabSort', M.sort, {
		desc = 'Sort tabs by the current file path',
	})

	-- -p and :tab all stop at 'tabpagemax' (default 50).
	vim.o.tabpagemax = 10000

	local group = api.nvim_create_augroup('config.tabs', { clear = true })
	-- After the command that opened the file has finished.
	api.nvim_create_autocmd('BufWinEnter', {
		group = group,
		callback = function()
			local win = api.nvim_get_current_win()
			vim.schedule(function()
				dedupe(win)
			end)
		end,
	})

	-- nvim a b c: a tab each, unless -o, -O, -p, or -d already arranged them.
	api.nvim_create_autocmd('VimEnter', {
		group = group,
		callback = function()
			if vim.fn.argc() > 1 and #api.nvim_list_tabpages() == 1 and #windows(0) == 1 and not vim.wo.diff then
				vim.cmd('silent tab all')
				vim.cmd('tabfirst')
			end
		end,
	})
end

return M
