local M = {}

-- Hard tabs, always. Nothing gets to turn on spaces: no filetype plugin
-- (YAML, Python, and markdown all try), no indent script, no
-- .editorconfig, and no :set typed by hand. Tab inserts a tab; type two
-- spaces if you want two spaces.
--
-- Each of these makes Tab or >> insert spaces when set:
--   expandtab       Tab and indent become spaces
--   softtabstop     Tab inserts a mix of spaces and tabs
--   varsofttabstop  the same, per column
--   shiftwidth      >> and autoindent use spaces when it is not 'tabstop';
--                   0 makes it follow 'tabstop'
local locked = { expandtab = false, softtabstop = 0, varsofttabstop = '', shiftwidth = 0 }

local function hard_tabs(buf)
	local bo = vim.bo[buf]
	for name, value in pairs(locked) do
		if bo[name] ~= value then
			bo[name] = value
		end
	end
end

function M.setup()
	local group = vim.api.nvim_create_augroup('config', { clear = true })

	for name, value in pairs(locked) do
		vim.go[name] = value
	end

	-- .editorconfig still sets charset, trailing whitespace, and the final
	-- newline. Its indent properties are ignored.
	local ok, editorconfig = pcall(require, 'editorconfig')
	if ok and type(editorconfig.properties) == 'table' then
		editorconfig.properties.indent_style = nil
		editorconfig.properties.indent_size = nil
		editorconfig.properties.tab_width = nil
	end

	-- A filetype plugin runs inside the FileType event, so it does not
	-- trigger OptionSet. Reset after it, and once more after anything else
	-- queued in the same event. tabstop goes back to 4 here too; a :set
	-- tabstop by hand afterwards only changes how wide a tab looks.
	vim.api.nvim_create_autocmd('FileType', {
		group = group,
		callback = function(ev)
			vim.bo[ev.buf].tabstop = 4
			hard_tabs(ev.buf)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(ev.buf) then
					hard_tabs(ev.buf)
				end
			end)
		end,
	})

	-- Anything that sets these outside an event, or later: put them back.
	vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'BufWinEnter', 'BufEnter', 'InsertEnter' }, {
		group = group,
		callback = function(ev)
			hard_tabs(ev.buf)
		end,
	})
	vim.api.nvim_create_autocmd('OptionSet', {
		group = group,
		pattern = vim.tbl_keys(locked),
		callback = function(ev)
			local name = ev.match
			if vim.v.option_type ~= 'local' then
				vim.go[name] = locked[name]
			end
			hard_tabs(vim.api.nvim_get_current_buf())
			if name == 'expandtab' and (vim.v.option_new == true or vim.v.option_new == 1) then
				vim.notify('expandtab is locked off: Tab inserts a tab', vim.log.levels.WARN)
			end
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
