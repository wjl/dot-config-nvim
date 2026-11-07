-- Shared colorscheme loader.
--
-- A scheme paints five tiers. Neovim picks gui colors when 'termguicolors'
-- is on, otherwise the cterm indexes. 't_Co' below 8 gets attributes only.
-- 't_Co' below 16 cannot show the bright ANSI colors, so that tier stays
-- inside 0–7. Asking for 8 there is SGR 38, which is "default", not a color.

local M = {}

function M.tier()
	local tco = tonumber(vim.fn.eval('&t_Co')) or 256
	if tco < 8 then
		return 'mono'
	end
	if vim.o.termguicolors then
		return 'gui'
	end
	if tco < 16 then
		return 'ansi8'
	end
	if tco < 256 then
		return 'ansi'
	end
	return 'c256'
end

-- fg and bg are { hex, ansi index, 256 index, 8-color index } or nil.
-- The 8-color index is optional. Below 8 it defaults to the ansi index.
-- attr is a string of b (bold), i (italic), u (underline), c (undercurl), r (reverse).
-- mono_attr replaces attr on the monochrome tier, so a colored selection can
-- become reverse there without also reversing the color tiers.
-- low overrides the 8-color tier for one group: { fg = n, bg = n }.
-- false clears that field. A shared color cannot be both a safe foreground
-- and a safe background once bright colors are gone.
function M.face(fg, bg, attr, mono_attr, low)
	attr = attr or ''
	low = low or {}
	local function paint(spec)
		local out = {}
		if spec:find('b', 1, true) then out.bold = true end
		if spec:find('i', 1, true) then out.italic = true end
		if spec:find('u', 1, true) then out.underline = true end
		if spec:find('r', 1, true) then out.reverse = true end
		if spec:find('c', 1, true) then out.undercurl = true end
		return out
	end

	local function low_index(spec, key)
		if low[key] ~= nil then
			if low[key] == false then
				return nil
			end
			return low[key]
		end
		if not spec then
			return nil
		end
		if spec[4] ~= nil then
			return spec[4]
		end
		if spec[2] < 8 then
			return spec[2]
		end
		return nil
	end

	local gui = paint(attr)
	local ansi = paint(attr:gsub('c', 'u'))
	local c256 = paint(attr:gsub('c', 'u'))
	local mono = paint((mono_attr or attr):gsub('c', 'u'))
	local ansi8 = paint(attr:gsub('c', 'u'))
	ansi.undercurl = nil
	c256.undercurl = nil
	mono.undercurl = nil
	ansi8.undercurl = nil
	if fg then
		gui.fg = fg[1]
		ansi.ctermfg = fg[2]
		c256.ctermfg = fg[3]
		if gui.undercurl then
			gui.sp = fg[1]
		end
	end
	if bg then
		gui.bg = bg[1]
		ansi.ctermbg = bg[2]
		c256.ctermbg = bg[3]
	end
	local fg8 = low_index(fg, 'fg')
	local bg8 = low_index(bg, 'bg')
	if fg8 then
		ansi8.ctermfg = fg8
	end
	if bg8 then
		ansi8.ctermbg = bg8
	end
	return { gui = gui, ansi = ansi, c256 = c256, mono = mono, ansi8 = ansi8 }
end

function M.apply(name, paints, links)
	vim.cmd('highlight clear')
	if vim.fn.exists('syntax_on') == 1 then
		vim.cmd('syntax reset')
	end

	local which = M.tier()
	for group, face in pairs(paints) do
		vim.api.nvim_set_hl(0, group, face[which] or {})
	end
	for group, target in pairs(links) do
		vim.api.nvim_set_hl(0, group, { link = target })
	end

	vim.g.colors_name = name
	if paints.MatchParen then
		vim.g.folio_paren = paints.MatchParen[which]
	end
end

return M
