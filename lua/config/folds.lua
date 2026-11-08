local M = {}

local foldscan = require('config.foldscan')

-- Marker level, exactly as foldmethod=marker. The number is the level of
-- this line. The carried value is the level of the next line.
-- A digit of 0 does not count. foldnestmax does not apply here.
local function marker_levels(lines, foldmarker)
	local comma = foldmarker:find(',', 1, true)
	local start_m = comma and foldmarker:sub(1, comma - 1) or '{{{'
	local end_m = comma and foldmarker:sub(comma + 1) or '}}}'
	if start_m == '' or end_m == '' then
		return {}, {}
	end

	local levels, starts = {}, {}
	local lvl_next = 0
	for i, line in ipairs(lines) do
		local lvl = lvl_next
		local start_lvl = lvl
		local opened = false
		local s = 1
		while true do
			local a = line:find(start_m, s, true)
			local b = line:find(end_m, s, true)
			if not a and not b then
				break
			end
			if a and (not b or a <= b) then
				local after = a + #start_m
				local digits = line:match('^(%d+)', after)
				local n = digits and tonumber(digits) or nil
				if n and n > 0 then
					lvl = n
					lvl_next = n
					opened = true
				elseif not digits then
					lvl = lvl + 1
					lvl_next = lvl_next + 1
					opened = true
				end
				s = after
			else
				local after = b + #end_m
				local digits = line:match('^(%d+)', after)
				local n = digits and tonumber(digits) or nil
				if n and n > 0 then
					lvl = n
					lvl_next = math.min(n - 1, start_lvl)
				elseif not digits then
					lvl_next = lvl_next - 1
				end
				s = after
			end
		end
		if lvl_next < 0 then
			lvl_next = 0
		end
		levels[i] = lvl
		starts[i] = opened or nil
	end
	return levels, starts
end

local cache = {}

-- Marker levels and structural levels for the whole buffer, kept until
-- the buffer or 'foldmarker' changes.
local function buffer_levels(bufnr)
	local tick = vim.api.nvim_buf_get_changedtick(bufnr)
	local foldmarker = vim.wo.foldmarker
	local ft = vim.bo[bufnr].filetype
	local hit = cache[bufnr]
	if hit and hit.tick == tick and hit.foldmarker == foldmarker and hit.ft == ft then
		return hit
	end
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local marker, marker_starts = marker_levels(lines, foldmarker)
	local ok, struct, struct_starts = pcall(foldscan.levels, lines, ft)
	if not ok then
		struct, struct_starts = nil, nil
	end
	hit = {
		tick = tick,
		foldmarker = foldmarker,
		ft = ft,
		marker = marker,
		marker_starts = marker_starts,
		struct = struct or {},
		struct_starts = struct_starts or {},
	}
	cache[bufnr] = hit
	return hit
end

-- Marker level plus structural level. A line where either kind of fold
-- starts gets ">", so two folds of the same level side by side stay two
-- folds. Filetypes without a scanner fold on markers alone.
function M.level()
	local lnum = vim.v.lnum
	local hit = buffer_levels(vim.api.nvim_get_current_buf())
	local level = (hit.marker[lnum] or 0) + (hit.struct[lnum] or 0)
	if level > 0 and (hit.marker_starts[lnum] or hit.struct_starts[lnum]) then
		return '>' .. level
	end
	return tostring(level)
end

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
	vim.api.nvim_create_autocmd('BufUnload', {
		group = vim.api.nvim_create_augroup('config_folds', { clear = true }),
		callback = function(ev)
			cache[ev.buf] = nil
		end,
	})
end

return M
