local o = vim.opt

-- Modelines can execute editor commands from a file.
o.modeline = false

-- Read every file as UTF-8. Do not guess latin1.
o.fileencodings = {}
o.fileformats = { 'unix', 'dos', 'mac' }

-- A terminal that advertises a light background would flip a dark scheme.
o.background = 'dark'

-- 'autochdir' has been unreliable and breaks plugins that care about cwd.
-- The BufEnter hook in autocmds.lua does the same job.

o.viewoptions:remove('curdir')
o.sessionoptions:remove({ 'buffers', 'curdir' })
o.sessionoptions:append('sesdir')

o.ignorecase = true
o.smartcase = true

o.scrolloff = 5
o.sidescrolloff = 10

-- onemore pairs with selection=exclusive: the cursor can sit one past the
-- last character, which is how that character becomes part of a selection.
o.virtualedit = { 'insert', 'block', 'onemore' }
-- '<' is a flag here, not a key name. The option API treats it as a key.
vim.cmd('set whichwrap+=<,>,[,]')

o.showbreak = '↪ '
o.linebreak = true
o.breakindent = true
o.colorcolumn:append('+1')

o.number = true
o.numberwidth = 1

o.report = 0

o.matchpairs:append({ '<:>', '«:»' })

o.display:append('uhex')
o.list = true
o.listchars = {
	tab = '┊ ',
	precedes = '←',
	extends = '→',
	lead = '·',
	trail = '·',
	nbsp = '⎵',
}

-- Highlight the number only. A highlighted line reads as a second cursor.
o.cursorline = true
o.cursorlineopt = 'number'
o.title = true

-- 'spell' stays off. camel matters once a toggle turns spell on.
o.spelloptions:append('camel')

o.showtabline = 2
-- One file per tab. Reuse a tab that already shows the buffer. Otherwise
-- open a new tab. This applies to quickfix jumps, :stag, and :sbuffer.
-- It does not stop :split.
o.switchbuf = { 'usetab', 'newtab' }

o.splitbelow = true
o.splitright = true

o.mouse = 'a'
-- Right click opens the menu where the pointer is, without moving the cursor.
o.mousemodel = 'popup'

o.selection = 'exclusive'

o.formatoptions:append('2')
o.tildeop = true
o.showmode = false

o.tabstop = 4
o.shiftwidth = 0
o.shiftround = true
o.smarttab = false
o.copyindent = true

o.foldlevelstart = 999
o.foldmethod = 'syntax'
o.foldcolumn = '2'
o.foldignore = ''
o.fillchars:append({ fold = ' ' })

o.wildmode = 'longest:full'
vim.cmd('set wildcharm=<C-z>')

if vim.fn.has('gui') == 1 then
	o.guifont = 'MesloLGS NF'
end
