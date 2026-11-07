-- folio: one scheme, two pages. :set background=light|dark reloads it.
-- The light page is a warm grey, darker than white. The dark page is the
-- same hues on a warm near-black. Color marks a role, not a decoration.

local scheme = require('config.colorscheme')

-- The fourth number is the 8-color index. Bright ANSI colors are not
-- colors there: 8 is sent as SGR 38, which means "default".
local function C(hex, ansi, c256, ansi8)
	return { hex, ansi, c256, ansi8 }
end

local function face(fg, bg, attr, mono_attr, low)
	return scheme.face(fg, bg, attr, mono_attr, low)
end

local function light()
	local text = C('#2c2926', 0, 235)
	local page = C('#e7e5df', 7, 254)
	-- Yellow text on a white page disappears. Amber roles use red here.
	local muted = C('#5c574e', 8, 240, 4)
	local faint = C('#a39e94', 8, 246, 4)
	local linenr = C('#7a746a', 8, 243, 4)
	local keyword = C('#1d4f78', 4, 24)
	local fn = C('#1a6070', 6, 23)
	local kind = C('#6b4578', 5, 96)
	local str = C('#246240', 2, 28)
	local constant = C('#9a3e36', 1, 131)
	local preproc = C('#8a5a12', 3, 94, 1)
	local special = C('#8a3d5c', 5, 132)
	local paren = C('#8a5a12', 3, 136, 1)
	local searchfg = C('#2c2618', 0, 235)
	local sheet = C('#f4f1ea', 15, 255, 6)
	local wash = C('#d9d5cb', 7, 252, 6)
	local visual = C('#cfcabf', 8, 251, 4)
	local search = C('#d7af00', 3, 178)
	local current = C('#d78700', 11, 172, 1)
	local sel = C('#1d4f78', 4, 24)
	local add = C('#afd7af', 2, 151)
	local delete = C('#ffd7d7', 1, 224)
	local change = C('#d7d7af', 3, 187)
	local difftext = C('#d7d787', 3, 186)

	vim.g.folio_variant = 'light'
	for i, hex in ipairs({
		'#2c2926', '#9a3e36', '#246240', '#8a5a12',
		'#1d4f78', '#6b4578', '#1a6070', '#e7e5df',
		'#5c574e', '#b55248', '#3d8a58', '#b4842a',
		'#3d78a8', '#8a6a96', '#3d8494', '#f4f1ea',
	}) do
		vim.g['terminal_color_' .. (i - 1)] = hex
	end

	return {
		Normal = face(text, page),
		Comment = face(muted, nil, 'i'),
		Constant = face(constant),
		String = face(str),
		Identifier = face(text),
		Function = face(fn),
		Keyword = face(keyword, nil, 'b'),
		Operator = face(text),
		PreProc = face(preproc),
		Type = face(kind),
		Special = face(special),
		Delimiter = face(text),
		Underlined = face(keyword, nil, 'u'),
		Error = face(constant, nil, 'b'),
		Todo = face(preproc, nil, 'b'),
		LineNr = face(linenr, page),
		-- No fill on the cursor line. A yellow or cyan band hides syntax.
		CursorLine = face(nil, wash, nil, nil, { bg = false }),
		CursorLineNr = face(text, page, 'b'),
		SignColumn = face(linenr, page),
		FoldColumn = face(linenr, page),
		ColorColumn = face(nil, wash, nil, nil, { bg = false }),
		Visual = face(text, visual, nil, 'r'),
		Search = face(searchfg, search, nil, 'r'),
		IncSearch = face(searchfg, current, 'b', 'br'),
		MatchParen = face(paren, nil, 'u'),
		Pmenu = face(text, sheet),
		-- sheet is the popup background. Selected text has to be white on blue.
		PmenuSel = face(sheet, sel, nil, 'r', { fg = 7 }),
		PmenuSbar = face(nil, wash),
		PmenuThumb = face(nil, visual),
		WildMenu = face(sheet, sel, nil, 'r', { fg = 7 }),
		Folded = face(muted, wash, 'i', nil, { fg = 0 }),
		DiffAdd = face(text, add, nil, 'b'),
		DiffDelete = face(text, delete, nil, 'r'),
		DiffChange = face(text, change, nil, 'i'),
		DiffText = face(searchfg, difftext, nil, 'br'),
		SpellBad = face(constant, nil, 'c'),
		SpellCap = face(keyword, nil, 'c'),
		SpellRare = face(special, nil, 'c'),
		SpellLocal = face(kind, nil, 'c'),
		ErrorMsg = face(constant, nil, 'b'),
		WarningMsg = face(preproc),
		MoreMsg = face(str),
		Question = face(fn),
		ModeMsg = face(text, nil, 'b'),
		Title = face(keyword, nil, 'b'),
		Directory = face(keyword),
		NonText = face(faint),
		SpecialKey = face(faint),
		Whitespace = face(faint),
		EndOfBuffer = face(faint),
		QuickFixLine = face(text, visual, nil, 'r'),
		WinSeparator = face(faint, page),
		VertSplit = face(faint, page),
		DiagnosticUnderlineError = face(constant, nil, 'u'),
		DiagnosticUnderlineWarn = face(preproc, nil, 'u'),
		DiagnosticUnderlineInfo = face(keyword, nil, 'u'),
		DiagnosticUnderlineHint = face(muted, nil, 'u'),
		DiagnosticUnderlineOk = face(str, nil, 'u'),
		['@markup.strong'] = face(nil, nil, 'b'),
		['@markup.italic'] = face(nil, nil, 'i'),
	}
end

local function dark()
	local text = C('#e6e2d8', 7, 254)
	local page = C('#221f1c', 0, 234)
	-- There is no gray. Comments are yellow, and the faint marks are cyan.
	local muted = C('#a39e94', 8, 247, 3)
	local faint = C('#6a645a', 8, 241, 6)
	local linenr = C('#8a8478', 8, 244, 6)
	local keyword = C('#8eb8d8', 12, 110, 4)
	local fn = C('#8ec4c8', 14, 116, 6)
	local kind = C('#d4b4d8', 13, 182, 5)
	local str = C('#9dccaa', 10, 151, 2)
	local constant = C('#e8a89e', 9, 181, 1)
	local preproc = C('#e2b86a', 11, 179, 3)
	local special = C('#e8a8c0', 13, 175, 5)
	local paren = C('#e2b86a', 11, 179, 3)
	local searchfg = C('#221f1c', 0, 235)
	local sheet = C('#2c2924', 8, 235, 4)
	local wash = C('#3a342c', 8, 236, 4)
	local search = C('#875f00', 3, 94)
	local current = C('#af8700', 11, 136, 1)
	local sel = C('#005f87', 12, 24, 4)
	local selfg = C('#f3ead2', 15, 231, 0)
	local add = C('#005f00', 2, 22)
	local delete = C('#5f0000', 1, 52)
	local change = C('#5f5f00', 3, 58)
	local difftext = C('#875f00', 11, 94, 1)

	vim.g.folio_variant = 'dark'
	for i, hex in ipairs({
		'#221f1c', '#e8a89e', '#9dccaa', '#e2b86a',
		'#8eb8d8', '#d4b4d8', '#8ec4c8', '#e6e2d8',
		'#6a645a', '#f0c4bc', '#c4e4cc', '#f0d49a',
		'#c4dff0', '#ead4ec', '#c4e4e6', '#f7f4ee',
	}) do
		vim.g['terminal_color_' .. (i - 1)] = hex
	end

	return {
		Normal = face(text, page),
		Comment = face(muted, nil, 'i'),
		Constant = face(constant),
		String = face(str),
		Identifier = face(text),
		Function = face(fn),
		Keyword = face(keyword, nil, 'b'),
		Operator = face(text),
		PreProc = face(preproc),
		Type = face(kind),
		Special = face(special),
		Delimiter = face(text),
		Underlined = face(keyword, nil, 'u'),
		Error = face(constant, nil, 'b'),
		Todo = face(preproc, nil, 'b'),
		LineNr = face(linenr, page),
		CursorLine = face(nil, wash, nil, nil, { bg = false }),
		CursorLineNr = face(text, page, 'b'),
		SignColumn = face(linenr, page),
		FoldColumn = face(linenr, page),
		ColorColumn = face(nil, wash, nil, nil, { bg = false }),
		Visual = face(text, wash, nil, 'r'),
		Search = face(selfg, search, nil, 'r'),
		IncSearch = face(searchfg, current, 'b', 'br'),
		MatchParen = face(paren, nil, 'u'),
		Pmenu = face(text, sheet),
		PmenuSel = face(selfg, sel, nil, 'r'),
		PmenuSbar = face(nil, wash),
		PmenuThumb = face(nil, search),
		WildMenu = face(selfg, sel, nil, 'r'),
		Folded = face(muted, sheet, 'i'),
		DiffAdd = face(text, add, nil, 'b'),
		DiffDelete = face(text, delete, nil, 'r'),
		-- White on yellow is the low-contrast pair. Black on yellow stays readable.
		DiffChange = face(text, change, nil, 'i', { fg = 0 }),
		DiffText = face(selfg, difftext, nil, 'br'),
		SpellBad = face(constant, nil, 'c'),
		SpellCap = face(keyword, nil, 'c'),
		SpellRare = face(special, nil, 'c'),
		SpellLocal = face(kind, nil, 'c'),
		ErrorMsg = face(constant, nil, 'b'),
		WarningMsg = face(preproc),
		MoreMsg = face(str),
		Question = face(fn),
		ModeMsg = face(text, nil, 'b'),
		Title = face(keyword, nil, 'b'),
		Directory = face(keyword),
		NonText = face(faint),
		SpecialKey = face(faint),
		Whitespace = face(faint),
		EndOfBuffer = face(faint),
		QuickFixLine = face(text, wash, nil, 'r'),
		WinSeparator = face(faint, page),
		VertSplit = face(faint, page),
		DiagnosticUnderlineError = face(constant, nil, 'u'),
		DiagnosticUnderlineWarn = face(preproc, nil, 'u'),
		DiagnosticUnderlineInfo = face(keyword, nil, 'u'),
		DiagnosticUnderlineHint = face(muted, nil, 'u'),
		DiagnosticUnderlineOk = face(str, nil, 'u'),
		['@markup.strong'] = face(nil, nil, 'b'),
		['@markup.italic'] = face(nil, nil, 'i'),
	}
end

local paints = vim.o.background == 'light' and light() or dark()
scheme.apply('folio', paints, scheme.links)
