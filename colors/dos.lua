-- dos: white on the Borland blue. One look. :set background reloads it
-- and the colors stay.
--
-- Truecolor and 256-color are white on #0000AA (index 19 is #0000af).
-- 16-color stays on black. A blue page is sky blue on Konsole, so the
-- page would wash out. Keywords are yellow, strings and types are bright
-- blue, comments are cyan. 8-color is white on black, with yellow
-- keywords, blue strings, and cyan comments.

local scheme = require('config.colorscheme')

local function C(hex, ansi, c256, ansi8)
	return { hex, ansi, c256, ansi8 }
end

local function face(fg, bg, attr, mono_attr, low)
	return scheme.face(fg, bg, attr, mono_attr, low)
end

local function paint()
	local text = C('#ffffff', 15, 231, 7)
	local page = C('#0000aa', 0, 19, 0)
	local kw = C('#ffff5f', 11, 227, 3)
	local cmt = C('#5fffff', 6, 87, 6)
	local str = C('#afffaf', 12, 157, 4)
	local fn = C('#ffffff', 15, 231, 7)
	local kind = C('#ffd7ff', 12, 225, 4)
	local const = C('#ffd7af', 11, 223, 3)
	local pre = C('#ffd75f', 12, 221, 4)
	local spec = C('#ffafff', 6, 219, 6)
	local linenr = C('#e4e4e4', 6, 254, 6)
	local faint = C('#afafd7', 6, 146, 6)
	local err = C('#ffafaf', 11, 217, 3)
	-- One step lighter than the navy. 16-color and 8-color use the page
	-- color itself, so the column does not turn into a stripe.
	local wash = C('#0000d7', 0, 20, 0)
	local black = C('#000000', 0, 16, 0)
	local bar = C('#5fd7d7', 12, 80, 7)
	local paper = C('#e4e4e4', 7, 254, 6)
	local seek = C('#ffff5f', 11, 227, 3)
	local hit = C('#ffffff', 15, 231, 7)
	local picked = C('#5fd7d7', 12, 80, 7)
	local add = C('#5fff5f', 10, 83, 2)
	local change = C('#ffd75f', 11, 221, 6)
	local difftext = C('#ffffff', 15, 231, 7)
	-- Dark red holds white in truecolor and 256. At 16 and 8 colors a
	-- deletion is black on white.
	local del_fg = C('#ffffff', 0, 231, 0)
	local del_bg = C('#af0000', 15, 124, 7)
	local track = C('#5f5fff', 6, 63, 4)
	local thumb = C('#ffffff', 15, 231, 7)

	for i, hex in ipairs({
		'#000000', '#aa0000', '#00aa00', '#aaaa00',
		'#0000aa', '#aa00aa', '#00aaaa', '#aaaaaa',
		'#555555', '#ff5555', '#55ff55', '#ffff55',
		'#5555ff', '#ff55ff', '#55ffff', '#ffffff',
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
		PreProc = face(pre, nil, 'b'),
		Type = face(kind),
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
		Visual = face(black, bar, nil, 'r'),
		Search = face(black, seek, nil, 'r'),
		IncSearch = face(black, hit, 'b', 'br'),
		MatchParen = face(kw, nil, 'u'),
		Pmenu = face(black, paper),
		PmenuSel = face(black, picked, nil, 'r'),
		PmenuSbar = face(nil, track),
		PmenuThumb = face(nil, thumb),
		WildMenu = face(black, picked, nil, 'r'),
		Folded = face(cmt, nil, 'i'),
		DiffAdd = face(black, add, nil, 'b'),
		DiffDelete = face(del_fg, del_bg, nil, 'r'),
		DiffChange = face(black, change, nil, 'i'),
		DiffText = face(black, difftext, 'b', 'br'),
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
		QuickFixLine = face(black, bar, nil, 'r'),
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

scheme.apply('dos', paint(), scheme.links)
