local o = vim.opt

-- Modelines can execute editor commands from a file.
o.modeline = false

-- Read every file as UTF-8. Do not guess latin1, and do not hide a byte
-- order mark: one shows as <feff> and goes away when deleted.
o.fileencodings = {}

-- Start on the dark page. :set background=light switches folio.
-- A terminal that advertises a light background does not override this.
o.background = 'dark'

-- 'autochdir' has been unreliable and breaks plugins that care about cwd.
-- The BufEnter hook in autocmds.lua does the same job.

o.viewoptions:remove('curdir')
o.sessionoptions:remove({ 'buffers', 'curdir' })
o.sessionoptions:append('sesdir')

o.ignorecase = true
o.smartcase = true
-- Completion keeps the case you typed: the + Theorem gives theorem.
o.infercase = true

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
-- A wrapped list item lines up under the item's text, not under the "-"
-- or "1." ('formatlistpat' finds the marker).
o.breakindentopt = 'list:-1'
-- Ctrl-E / Ctrl-Y and the mouse wheel scroll a wrapped line by screen
-- row instead of jumping over all of it.
o.smoothscroll = true
-- One line per wheel notch (Neovim's default is 3). Sideways stays 6.
o.mousescroll = { 'ver:1', 'hor:6' }
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

-- 'spell' stays off; :set spell turns it on. French, German, Swedish, and
-- Spanish are vendored in spell/ (see spell/README.md); English ships with
-- Neovim. :setlocal spelllang=fr picks the language for one buffer.
o.spelloptions:append('camel')

o.showtabline = 2
-- One file per tab. Reuse a tab that already shows the buffer. Otherwise
-- open a new tab. This applies to quickfix jumps, :stag, and :sbuffer.
-- It does not stop :split.
o.switchbuf = { 'usetab', 'newtab' }

o.splitbelow = true
o.splitright = true
-- Opening or closing a split leaves the text where it is on screen.
o.splitkeep = 'screen'

o.mouse = 'a'
-- Right click moves the cursor to the pointer (unless it is inside the
-- selection) and opens the menu there. The menu is set up in files.lua.
o.mousemodel = 'popup_setpos'

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
o.foldmethod = 'expr'
o.foldexpr = 'v:lua.Config.foldlevel()'
-- One column: - where an open fold starts, + on a closed fold, and │ on
-- every line inside a fold. foldinner keeps nested folds from showing
-- their level as digits, which ran into the line numbers.
o.foldcolumn = '1'
o.foldignore = ''
o.fillchars:append({ fold = ' ', foldinner = '│' })

-- Plain text is markdown: headings, lists, and fenced code are highlighted
-- and fold. A filename Neovim knows (CMakeLists.txt, requirements.txt) and
-- Neovim's own help files keep their own filetype.
vim.filetype.add({
	extension = {
		txt = 'markdown',
		-- Neovim knows *.c++ but not these.
		['h++'] = 'cpp',
		vhdlpp = 'vhdl',
	},
})

-- Command-line completion. The menu opens by itself as you type (the
-- CmdlineChanged autocmd in autocmds.lua), without filling anything in.
-- Then Tab fills in what all the matches share, and Tab again steps
-- through them. fuzzy: :b gut finds gutter.lua. It does not apply to file
-- names, so :e takes paths as usual; :find (files.lua) matches fuzzily.
o.wildmode = 'noselect:lastused,longest:full,full'
o.wildoptions:append('fuzzy')

-- Insert-mode completion. The menu opens by itself from words in open
-- buffers once typing pauses for autocompletedelay, and inserts nothing
-- until you pick: Ctrl-N / Ctrl-P or Down / Up to choose, Enter to take
-- it, Ctrl-E to close it. Tab still inserts a tab. :set noautocomplete
-- turns it off; Ctrl-N / Ctrl-P keep these settings either way.
o.autocomplete = true
o.autocompletedelay = 500
o.complete = { '.^5', 'w^5', 'b^5', 'u^5' }
o.completeopt = { 'menuone', 'noselect', 'popup', 'fuzzy' }
vim.cmd('set wildcharm=<C-z>')

if vim.fn.has('gui') == 1 then
	o.guifont = 'MesloLGS NF'
end
