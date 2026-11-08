-- Shared colorscheme loader. The reasons for the split are in colors/README.md.
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
	-- highlights.lua copies this onto MatchParen after ColorScheme.
	-- Only a scheme that stored it, and is still the active name, may use it.
	if paints.MatchParen then
		vim.g.scheme_paren = paints.MatchParen[which]
	else
		vim.g.scheme_paren = nil
	end
end

-- Classic groups and captures. Schemes pass this to M.apply.
M.links = {
	Character = 'String',
	Number = 'Constant',
	Boolean = 'Constant',
	Float = 'Constant',
	Conditional = 'Keyword',
	Repeat = 'Keyword',
	Label = 'Keyword',
	Exception = 'Keyword',
	Statement = 'Keyword',
	Include = 'PreProc',
	Define = 'PreProc',
	Macro = 'PreProc',
	PreCondit = 'PreProc',
	StorageClass = 'Type',
	Structure = 'Type',
	Typedef = 'Type',
	SpecialChar = 'Special',
	Tag = 'Special',
	Debug = 'Special',
	SpecialComment = 'Special',
	VisualNOS = 'Visual',
	CurSearch = 'IncSearch',
	NormalFloat = 'Pmenu',
	NormalNC = 'Normal',
	Conceal = 'Comment',
	Added = 'DiffAdd',
	Changed = 'DiffChange',
	Removed = 'DiffDelete',
	DiagnosticError = 'Error',
	DiagnosticWarn = 'WarningMsg',
	DiagnosticInfo = 'Directory',
	DiagnosticHint = 'Comment',
	DiagnosticOk = 'String',
	PmenuKind = 'Pmenu',
	PmenuExtra = 'Pmenu',
	PmenuMatch = 'Pmenu',
	['@variable'] = 'Identifier',
	['@variable.builtin'] = 'Special',
	['@variable.parameter'] = 'Identifier',
	['@constant'] = 'Constant',
	['@constant.builtin'] = 'Constant',
	['@constant.macro'] = 'Macro',
	['@module'] = 'Include',
	['@string'] = 'String',
	['@string.escape'] = 'SpecialChar',
	['@string.special'] = 'SpecialChar',
	['@character'] = 'Character',
	['@number'] = 'Number',
	['@boolean'] = 'Boolean',
	['@float'] = 'Float',
	['@function'] = 'Function',
	['@function.builtin'] = 'Function',
	['@function.call'] = 'Function',
	['@function.method'] = 'Function',
	['@function.method.call'] = 'Function',
	['@constructor'] = 'Type',
	['@keyword'] = 'Keyword',
	['@keyword.function'] = 'Keyword',
	['@keyword.operator'] = 'Operator',
	['@keyword.return'] = 'Keyword',
	['@keyword.conditional'] = 'Conditional',
	['@keyword.repeat'] = 'Repeat',
	['@keyword.exception'] = 'Exception',
	['@keyword.import'] = 'Include',
	['@operator'] = 'Operator',
	['@punctuation'] = 'Delimiter',
	['@punctuation.bracket'] = 'Delimiter',
	['@punctuation.delimiter'] = 'Delimiter',
	['@punctuation.special'] = 'Special',
	['@type'] = 'Type',
	['@type.builtin'] = 'Type',
	['@attribute'] = 'PreProc',
	['@property'] = 'Identifier',
	['@comment'] = 'Comment',
	['@comment.todo'] = 'Todo',
	['@comment.error'] = 'Error',
	['@comment.note'] = 'SpecialComment',
	['@markup.heading'] = 'Title',
	['@markup.link'] = 'Underlined',
	['@markup.raw'] = 'String',
	['@markup.underline'] = 'Underlined',
	['@tag'] = 'Tag',
	['@tag.attribute'] = 'Type',
	['@tag.delimiter'] = 'Delimiter',
	['@diff.plus'] = 'DiffAdd',
	['@diff.minus'] = 'DiffDelete',
	['@diff.delta'] = 'DiffChange',
	-- after/syntax/markdown.vim
	markdownFoldMarker = 'Special',
}

return M
