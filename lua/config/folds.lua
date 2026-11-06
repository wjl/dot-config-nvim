local M = {}

local function char_at(text, index)
	return vim.fn.strcharpart(text, index, 1)
end

local function last_chars(text, count)
	local n = vim.fn.strchars(text)
	if n <= count then
		return text
	end
	return vim.fn.strcharpart(text, n - count, count)
end

local function trim_width(text, width)
	if width <= 0 then
		return ''
	end
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	local parts = {}
	local used = 0
	local n = vim.fn.strchars(text)
	for i = 0, n - 1 do
		local ch = char_at(text, i)
		local w = vim.fn.strdisplaywidth(ch)
		if used + w > width then
			break
		end
		parts[#parts + 1] = ch
		used = used + w
	end
	return table.concat(parts)
end

local function expand_tabs(text)
	local spec = vim.opt.listchars:get().tab or '┊ '
	local leader = char_at(spec, 0)
	if leader == '' then
		leader = '┊'
	end
	local parts = {}
	local n = vim.fn.strchars(text)
	for i = 0, n - 1 do
		local ch = char_at(text, i)
		if ch ~= '\t' then
			parts[#parts + 1] = ch
		else
			local column = vim.fn.strdisplaywidth(table.concat(parts))
			local width = vim.fn.strdisplaywidth('\t', column)
			parts[#parts + 1] = leader .. string.rep(' ', math.max(0, width - 1))
		end
	end
	return table.concat(parts)
end

local function nonblank(line, forward)
	if vim.fn.getline(line):match('^%s*$') == nil then
		return line
	end
	local other = forward and vim.fn.nextnonblank(line + 1) or vim.fn.prevnonblank(line - 1)
	if other == 0 then
		return line
	end
	return other
end

function M.text()
	local start_line = nonblank(vim.v.foldstart, true)
	local end_line = nonblank(vim.v.foldend, false)
	local start_text = expand_tabs((vim.fn.getline(start_line):gsub('%s+$', '')))
	local end_text = vim.fn.getline(end_line):gsub('^%s*', ''):gsub('%s+$', '')
	end_text = ' ⋯ ' .. last_chars(end_text, 10) .. ' '

	local fold_lines = 1 + vim.v.foldend - vim.v.foldstart
	local total = math.max(1, vim.fn.line('$'))
	local fold_info = string.format(' +%d (%.1f%%)', fold_lines, 100 * fold_lines / total)

	local win = vim.api.nvim_get_current_win()
	local info = vim.fn.getwininfo(win)[1]
	local textoff = info and info.textoff or 0
	local editor_width = vim.api.nvim_win_get_width(win) - textoff

	local end_width = vim.fn.strdisplaywidth(end_text)
	local info_width = vim.fn.strdisplaywidth(fold_info)
	start_text = trim_width(start_text, editor_width - end_width - info_width - 2)

	local filler = editor_width - vim.fn.strdisplaywidth(start_text) - end_width - info_width
	local expander = ''
	if filler > 0 then
		expander = string.rep('·', filler):gsub('··', '· ')
	end

	return start_text .. end_text .. expander .. fold_info
end

function M.setup()
	vim.opt.foldtext = 'v:lua.require("config.folds").text()'
end

return M
