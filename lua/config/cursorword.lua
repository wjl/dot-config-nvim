-- Underline every occurrence of the word under the cursor.

local M = {}
local timer = vim.uv.new_timer()

function M.highlights()
	vim.api.nvim_set_hl(0, 'CursorWord', { underline = true })
end

function M.clear()
	local id = vim.w.cursorword_id
	if id then
		pcall(vim.fn.matchdelete, id)
		vim.w.cursorword_id = nil
	end
end

function M.show()
	M.clear()
	local buf = vim.api.nvim_get_current_buf()
	local buftype = vim.bo[buf].buftype
	if buftype == 'terminal' or buftype == 'prompt' or buftype == 'nofile' then
		return
	end
	local word = vim.fn.expand('<cword>')
	if word == '' or #word > 1000 then
		return
	end
	local pattern = '\\<' .. vim.fn.escape(word, [[~"\.^$[]*]]) .. '\\>'
	vim.w.cursorword_id = vim.fn.matchadd('CursorWord', pattern, -100)
end

local function schedule()
	M.clear()
	timer:stop()
	timer:start(50, 0, vim.schedule_wrap(function()
		if vim.fn.mode() ~= 'c' then
			M.show()
		end
	end))
end

function M.setup()
	M.highlights()
	local group = vim.api.nvim_create_augroup('config_cursorword', { clear = true })
	vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
		group = group,
		callback = schedule,
	})
	vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter', 'InsertLeave' }, {
		group = group,
		callback = function()
			M.show()
		end,
	})
end

return M
