-- brimstone: warm gold on a muted brick. One look. :set background
-- reloads it and the colors stay.
--
-- Truecolor is #f8e6b4 on #4e2824. Comments are gray, not a second gold.
-- 256-color has no dark brown, so that tier is the same gold on deep red
-- (index 52). 16-color stays on black. ANSI red is too bright on Konsole
-- to be a page. The body is yellow, keywords are white, comments are
-- orange. 8-color is white on black, and every other role is yellow.

local scheme = require('config.colorscheme')

local function C(hex, ansi, c256, ansi8)
	return { hex, ansi, c256, ansi8 }
end

local function face(fg, bg, attr, mono_attr, low)
	return scheme.face(fg, bg, attr, mono_attr, low)
end

local function paint()
	local text = C('#f8e6b4', 11, 223, 7)
	local page = C('#4e2824', 0, 52, 0)
	local kw = C('#ffffd7', 15, 230, 3)
	local cmt = C('#c6c6c6', 3, 251, 3)
	local str = C('#d7d7af', 7, 187, 3)
	local fn = C('#ffd787', 11, 222, 7)
	local kind = C('#ffd7d7', 15, 224, 3)
	local const = C('#ffaf87', 7, 216, 3)
	local pre = C('#ffd75f', 3, 221, 3)
	local spec = C('#ffafd7', 15, 218, 3)
	local linenr = C('#c6c6c6', 3, 251, 3)
	local faint = C('#afafaf', 3, 145, 3)
	local err = C('#ffafaf', 15, 217, 3)
	-- The old brick, one step lighter than the page. 16-color and 8-color
	-- use the page color itself, so the column does not turn into a stripe.
	local wash = C('#5c302c', 0, 88, 0)
	local ink = C('#3a2018', 0, 16, 0)
	local bar = C('#ffd787', 11, 222, 7)
	local paper = C('#f3d7a4', 7, 223, 7)
	local picked = C('#ffd787', 11, 222, 7)
	local seek = C('#ffffd7', 11, 230, 3)
	local hit = C('#ffd75f', 15, 221, 7)
	local add = C('#d7d7af', 10, 187, 3)
	local change = C('#f0c878', 3, 179, 7)
	local difftext = C('#ffffd7', 15, 230, 7)
	local del_fg = C('#f8e6b4', 0, 16, 0)
	local del_bg = C('#2a1410', 15, 217, 7)
	local track = C('#5c302c', 3, 88, 3)
	local thumb = C('#ffffd7', 11, 230, 7)

	for i, hex in ipairs({
		'#2a1410', '#a85048', '#7d8a55', '#c4a060',
		'#6a5048', '#a87870', '#6e8a78', '#c6c6c6',
		'#4e2824', '#e08070', '#d7d7af', '#f8e6b4',
		'#8a7068', '#ffd7d7', '#afafd7', '#ffffd7',
	}) do
		vim.g['terminal_color_' .. (i - 1)] = hex
	end

	return {
		Normal = face(text, page),
		Comment = face(cmt, nil, 'i'),
		Constant = face(const),
		String = face(str),
		Identifier = face(text),
		Function = face(fn, nil, 'b'),
		Keyword = face(kw, nil, 'b'),
		Operator = face(text),
		PreProc = face(pre),
		Type = face(kind, nil, 'b'),
		Special = face(spec, nil, 'b'),
		Delimiter = face(text),
		Underlined = face(kw, nil, 'u'),
		Error = face(err, nil, 'bu'),
		Todo = face(kw, nil, 'b'),
		LineNr = face(linenr, page),
		CursorLine = face(nil, wash),
		CursorLineNr = face(text, page, 'b'),
		SignColumn = face(linenr, page),
		FoldColumn = face(linenr, page),
		ColorColumn = face(nil, wash),
		Visual = face(ink, bar, nil, 'r'),
		Search = face(ink, seek, nil, 'r'),
		IncSearch = face(ink, hit, 'b', 'br'),
		MatchParen = face(kw, nil, 'u'),
		Pmenu = face(ink, paper),
		PmenuSel = face(ink, picked, nil, 'r'),
		PmenuSbar = face(nil, track),
		PmenuThumb = face(nil, thumb),
		WildMenu = face(ink, picked, nil, 'r'),
		Folded = face(cmt, nil, 'i'),
		DiffAdd = face(ink, add, nil, 'b'),
		DiffDelete = face(del_fg, del_bg, nil, 'r'),
		DiffChange = face(ink, change, nil, 'i'),
		DiffText = face(ink, difftext, 'b', 'br'),
		SpellBad = face(err, nil, 'c'),
		SpellCap = face(kw, nil, 'c'),
		SpellRare = face(spec, nil, 'c'),
		SpellLocal = face(kind, nil, 'c'),
		ErrorMsg = face(err, nil, 'bu'),
		WarningMsg = face(kw),
		MoreMsg = face(str),
		Question = face(fn),
		ModeMsg = face(text, nil, 'b'),
		Title = face(kw, nil, 'b'),
		Directory = face(kw),
		NonText = face(faint),
		SpecialKey = face(faint),
		Whitespace = face(faint),
		EndOfBuffer = face(faint),
		QuickFixLine = face(ink, bar, nil, 'r'),
		WinSeparator = face(faint, page),
		VertSplit = face(faint, page),
		DiagnosticUnderlineError = face(err, nil, 'u'),
		DiagnosticUnderlineWarn = face(kw, nil, 'u'),
		DiagnosticUnderlineInfo = face(cmt, nil, 'u'),
		DiagnosticUnderlineHint = face(faint, nil, 'u'),
		DiagnosticUnderlineOk = face(str, nil, 'u'),
		['@markup.strong'] = face(nil, nil, 'b'),
		['@markup.italic'] = face(nil, nil, 'i'),
	}
end

scheme.apply('brimstone', paint(), scheme.links)
