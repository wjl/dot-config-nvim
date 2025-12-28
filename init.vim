" NeoVim Configuration
" by Wesley J. Landaker
"
" Version 2.1.0
"
" This work is marked with CC0 1.0. To view a copy of this license, visit
" https://creativecommons.org/publicdomain/zero/1.0/

"---------------
"--- Plugins {{{
"---------------

" TODO: window title: TBD

" Activate vim-plug plugins.
call plug#begin()

" Very good default light and dark color schemes.
Plug 'NLKNguyen/papercolor-theme'

" Huge selection of alternate color schemes.
Plug 'flazz/vim-colorschemes'

" Lightweight statusline configurator.
Plug 'itchyny/lightline.vim'

" Underline the word under the cursor.
Plug 'itchyny/vim-cursorword'

" Indentation based motions like ai aI ii iI.
Plug 'michaeljsmith/vim-indent-object'

" Better netrw browsing behavior.
Plug 'tpope/vim-vinegar'

" Commenting and uncommenting code with gc.
Plug 'tpope/vim-commentary'

" Extended character info for ga.
Plug 'tpope/vim-characterize'

" Clean Git integration.
Plug 'tpope/vim-fugitive'

" Allow both syntax and markers folds to work simultaneously.
Plug 'Jorengarenar/vim-syntaxMarkerFold'

" Transparent editing of gpg-encrypted files.
Plug 'jamessan/vim-gnupg'

call plug#end()

"}}}----------------
"--- Reading Files {{{
"---------------------

" Disable modelines because they are super terrible idea.
set nomodeline

" Default to unix line endings, but support others.
set fileformats=unix,dos,mac

" Always read all files as UTF-8.
set fileencodings=

" Automatically reload unmodified files that have changed externally.
set autoread

" Search path for finding files (:find, gf, ...).
set path=
set path+=. " relative to the current file.
set path+=  " in the current directory.

" The current directory follows the current file.
" We use an autocommand instead of autochdir because:
" * Setting autochdir has been found to be unreliable.
" * Using autochdir apparently can break some plugins.
augroup vimrc_autochdir
	autocmd!
	autocmd BufEnter * silent! lcd %:p:h
augroup end

" Never ignore filename case.
set nofileignorecase

"}}}------------------
"--- Writing Files {{{
"---------------------

" Always add an end-of-line when writing files.
set fixendofline

"}}}----------
"--- Views {{{
"-------------

" Don't store current directory.
set viewoptions-=curdir

"}}}-------------
"--- Sessions {{{
"----------------

" Use session-relative paths.
set sessionoptions-=curdir
set sessionoptions+=sesdir

" Include all tabs as part of the session.
set sessionoptions+=tabpages

" Don't include hidden buffers.
set sessionoptions-=buffers

" Save terminal windows.
set sessionoptions+=terminal

"}}}-------------------
"--- Text Searching {{{
"----------------------

" Ignore case in searches unless there are caps in the pattern.
set ignorecase
set smartcase

"}}}--------------
"--- Scrolling {{{
"-----------------

" Scroll a bit ahead of the cursor vertically.
set scrolloff=5

" Scroll a bit ahead of the cursor horizontally
set sidescrolloff=10

" Scroll horizontally one column at a time.
set sidescroll=1

"}}}---------------
"--- Navigation {{{
"-----------------

" Make cursor navigation less strict.
set virtualedit=
set virtualedit+=insert  " insertion mode
set virtualedit+=block   " block mode
set virtualedit+=onemore " normal mode, but only one past the line end

"}}}------------------
"--- Line Wrapping {{{
"---------------------

" Navigate to the next/previous line when using horizontal arrow keys.
set whichwrap+=<,> " normal and visual mode
set whichwrap+=[,] " insert and replace mode

" Word wrap by default.
set wrap

" Use a nice character to indicate wrapped lines.
let &showbreak = "↪ "

" Break lines nicely at word boundaries.
set linebreak

" Indent continuation lines to match the start of the line.
set breakindent

" Highlight the column after textwidth.
set colorcolumn+=+1

"}}}-------------------
"--- Line Numbering {{{
"----------------------

" Show line numbers using the minimum space necessary.
set number
set numberwidth=1

"}}}-------------------------
"--- Interactive Feedback {{{
"----------------------------

" Always report the number of lines changed
set report=0

" Use a flash instead of a beep.
set visualbell

" Add more matching pairs.
set matchpairs+=<:>
set matchpairs+=«:»

"}}}-----------------------
"--- Display Characters {{{
"--------------------------

" Show nonprintable characters in hexadecimal.
set display+=uhex

" Use list mode with nice characters.
set list
set listchars=
set listchars+=tab:┊\ 
set listchars+=precedes:←,extends:→
set listchars+=lead:·,trail:·,nbsp:⎵

"}}}------------------------
"--- Cursor Highlighting {{{
"---------------------------

" Enable cursor line highlighting, but only the line number.
set cursorline
set cursorlineopt=number

" Set the window title.
set title

"}}}-------------------
"--- Spell Checking {{{
"----------------------

" Set default spellcheck languages.
set spelllang=
set spelllang+=en " English

" Check CamelCase as two separate words.
set spelloptions+=camel

"}}}------------------
"--- Multiple Tabs {{{
"---------------------

" Always show the tabline.
set showtabline=2

" Make buffer switching respect tabs.
set switchbuf=usetab,newtab

"}}}------------------
"--- Split Windows {{{
"---------------------

" Always put window splits below or to the right.
set splitbelow
set splitright

"}}}----------
"--- Mouse {{{
"-------------

" Use the mouse for all modes.
set mouse=a

" Right click should give a popup menu.
set mousemodel=popup

"}}}--------------
"--- Selection {{{
"-----------------

" Use a sensible selection mode.
set selection=exclusive

"}}}---------------
"--- Formatting {{{
"------------------

" Use the indent of the second line of a paragraph when formatting.
set formatoptions+=2

"" Ex mode is completely unnecessary; use Q for formatting instead.
nnoremap Q gq
vnoremap Q gq

"}}}------------
"--- Editing {{{
"---------------

" Make tilde (change case) work like a normal operator.
set tildeop

" Don't show mode in command line, we've put it in the status line.
set noshowmode

"}}}--------------
"--- Indenting {{{
"-----------------

" Set the tab width.
set tabstop=4

" Make shift width always match the tab width.
set shiftwidth=0

" Round indenting when shifting.
set shiftround

" Never expand tabs into spaces.
set noexpandtab

" Don't stupidly try to treat multiple spaces as if they were tabs.
set nosmarttab

" Automatically indent after a newline by copying previous indent.
set autoindent
set copyindent

" Reset indenting even when other filetypes try to change things.
augroup F
	au!
	autocmd FileType * setlocal noexpandtab
	autocmd FileType * setlocal tabstop=4
	autocmd FileType * setlocal shiftwidth=4
augroup END

"}}}------------
"--- Folding {{{
"---------------

"" Start with all folds open.
set foldlevelstart=999

" Set default fold method.
set foldmethod=syntax

" Set a default fold column width.
set foldcolumn=2

" Clear fold ignore for general use.
set foldignore=

" Blank out the fold fill character.
set fillchars+=fold:\ 

" Define a shortcuts to easily control folds.
nnoremap <space> za
nnoremap <enter> zx

" Define an extremely nice custom foldtext method.
let &foldtext=expand("<SID>") .. "foldtext()"
function! <SID>foldtext() " {{{

	" Use the first non-blank line for our starting display text.
	let start_text = getline(v:foldstart)
	if getline(v:foldstart) =~ '^\s*$'
		let line = nextnonblank(v:foldstart + 1)
		if line != 0
			let start_text = getline(line)
		endif
	endif

	" Strip trailing whitespace from the text.
	let start_text = substitute(start_text, '\s*$', "", "")

	" We can't use tabs in the fold text, so visualize tabs explicitly.
	let chars = split(start_text, '\zs')
	let start_text = ""
	for char in chars
		if char != "\t"
			" Just append non-tab characters.
			let start_text = start_text .. char
		else
			" Expand tab characters into an appropriate visual form.
			" 	* FIXME: This hard-codes the tab characters.
			" 	  It would be better to extract this from listchars.
			let column = strdisplaywidth(start_text)
			let width = strdisplaywidth("\t", column)
			let tabtext = "┊" . repeat(" ", width - 1)
			let start_text = start_text .. tabtext
		endif
	endfor

	" Use the last non-blank line for our ending display text.
	let end_text = getline(v:foldend)
	if getline(v:foldend) =~ '^\s*$'
		let line = prevnonblank(v:foldend - 1)
		if line != 0
			let end_text = getline(line)
		endif
	endif

	" Strip leading and trailing whitespace from the end text.
	let end_text = substitute(end_text, '^\s*', "", "")
	let end_text = substitute(end_text, '\s*$', "", "")

	" Truncate end text somewhat arbitrarily.
	" The goal is to just provide a little context.
	let end_text = " ⋯ " .. end_text[-10:-1] .. " "

	" Compute fold size information.
	let fold_lines   = 1 + v:foldend - v:foldstart
	let fold_percent = 100.0 * fold_lines / line("$")

	" Compute fold information field.
	let fold_info = printf(" +%d (%.1f%%)", fold_lines, fold_percent)

	" Compute the width of the editor area.
	let editor_width = winwidth(0) - getwininfo(win_getid())[0].textoff

	" Truncate our text to make enough room for the fold info.
	let max_width = editor_width - strwidth(fold_info) - strwidth(end_text) - 2
	let start_text = start_text[0:max_width]
	"while strwidth(start_text) > max_width
	"	let start_text = start_text[:-2]
	"endwhile

	" Compute expander text.
	let expander = repeat("·", editor_width - strwidth(start_text) - strwidth(end_text) - strwidth(fold_info))
	let expander = substitute(expander, "··", "· ", "g")

	" Build the final display text.
	let fold_text = start_text .. end_text .. expander .. fold_info
	return fold_text
endf " }}}

"}}}-----------------------
"--- Command Completion {{{
"--------------------------

" Complete any unambiguous part, then use the menu.
set wildmode=longest:full

" Set a wildmenu activation that can be used in mappings.
set wildcharm=<c-z>

" Make the arrow keys in wildmenu behave logically.
cnoremap <expr> <up>    wildmenumode() ? "\<left>"  : "\<up>"
cnoremap <expr> <down>  wildmenumode() ? "\<right>" : "\<down>"
cnoremap <expr> <left>  wildmenumode() ? "\<up>"    : "\<left>"
cnoremap <expr> <right> wildmenumode() ? "\<down>"  : "\<right>"

"}}}------------
"--- Colorscheme {{{
"-------------------

" Set a good default colorscheme.
set background=dark
try
	colorscheme PaperColor
catch
	colorscheme default
endtry

" Show syntax highlighting groups for word under cursor
nnoremap gS :call <SID>get_syntax_groups()<CR>
function! <SID>get_syntax_groups()
	if !exists("*synstack")
		return
	endif
	echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
endf

"}}}--------------
"--- Lightline {{{
"-----------------

" Customize lightline configuration.
let g:lightline = {}

" Set the color scheme.
let g:lightline.colorscheme = "one"

" Use nice separators.
let g:lightline.separator    = {"left": "", "right": "" }
let g:lightline.subseparator = {"left": "", "right": "" }

" Ensure line numbers use virtual column.
" * Can remove if/when bug #623 is fixed.
let g:lightline.component = {
\ 	"lineinfo": "%3l:%-2v"
\ }

" Note the position for shrinking the status line.
let g:lightline.component = {}
let g:lightline.component.fileformat = "%<%{&ff}"

" Display Git branch using Fugitive.
let g:lightline.component_function = {
\ 	"gitbranch": "FugitiveHead"
\ }

" Select status line components.
let g:lightline.active = {
\ 	"left": [
\ 		[ "mode", "paste", ],
\ 		[ "readonly", "filename", "modified" ],
\ 		[ "gitbranch" ]
\ 	],
\ 	"right": [
\ 			[ "lineinfo" ],
\ 			[ "percent" ],
\ 			[ "fileformat", "filetype" ]
\ 	]
\ }

"}}}--------
"--- GUI {{{
"-----------

if has("gui") "{{{
	" Use a reasonable Nerd Font when using the GUI.
	let &guifont="MesloLGS NF"

endif "}}}

"}}}----------
"--- Netrw {{{
"-------------

" Use standard time and date format.
let g:netrw_timefmt="%F %T"

" Use the browsing directory as the current directory.
let g:netrw_keepdir=0

"}}}------------
"--- The End ---
"---------------
