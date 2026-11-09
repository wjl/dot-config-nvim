# Current state

The audit below was taken against Neovim 0.12.6 on 2026-11-06, from `nvim --clean`, while the live file was still `init.vim`. The editor now runs `init.lua`. Where this file says the live config is `init.vim`, that was true on the day of the audit. The bugs and the default comparisons stay, because they are why the port looks the way it does.

What you run now:

| Path | What it does |
| --- | --- |
| `init.lua` | Sets the options that plugins read, then loads the modules below |
| `lua/config/options.lua` | The settings that are real choices |
| `lua/config/highlights.lua` | MatchParen, the status line, and the cursor word. Startup scheme is `folio` |
| `lua/config/folds.lua` | Fold text, and the `expr` fold level |
| `lua/config/foldscan/` | Structural folds without a parser. One scanner per language family; see the phase 4 table in `plan.md` |
| `after/ftplugin/markdown.lua` | Markdown uses the classic syntax, so code fences are colored in their language |
| `after/syntax/markdown.vim` | `{{{` / `}}}` are highlighted, and a `_` inside a word is not an error. `*.txt` is markdown |
| `lua/config/autocmds.lua` | The hard-tab lock, and BufEnter `lcd` |
| `lua/config/mappings.lua` | `Q`, Space, Enter, `<C-L>`, Up/Down by screen row, wildmenu arrows, `gS` |
| `lua/config/files.lua` | `-` |
| `lua/config/cursorword.lua` | Underline the word under the cursor |
| `lua/config/statusline.lua` | Status line and tab line |
| `lua/config/tabs.lua` | One tab per file, a tab per file argument, `:TabSort` |
| `lua/config/ai/` | `:AI` one-shot and `:AIModel`; see `docs/ai.md` |
| `lua/config/gutter.lua` | Signs for changes against the git index; `]c` / `[c` |
| `lua/config/gpg.lua` | Edit `*.gpg` / `*.pgp` / `*.asc`; `:GpgInfo`, `:GpgEncryption`. Replaces vim-gnupg |

`init.vim` and vim-plug are gone. Neovim 0.12 refuses to start with `E5422` if `init.lua` and `init.vim` both exist. Do not put `init.vim` back beside `init.lua`.

`~/.local/share/nvim/plugged/` held the vim-plug clones, including the leftover `papercolor-theme` and `vim-colorschemes` directories. That tree was removed once vim-plug was gone. It is outside this repo, and a new machine does not recreate it.

## Layout at the time of the audit

| Path | What it does |
| --- | --- |
| `init.vim` | Everything except the rows below |
| `ftdetect/c++.vim` | `*.c++` and `*.h++` are C++ |
| `ftdetect/vhdl.vim` | `*.vhdlpp` is VHDL |
| `ftdetect/txt.vim` | `*.txt` forces `foldmethod=marker` |
| `after/ftplugin/cpp/commentstring.vim` | C++ comments are `//` |
| `after/ftplugin/dart/commentstring.vim` | Dart comments are `//` |
| `after/ftplugin/python/noexpandtab.vim` | Redundant. The FileType autocmd already forces `noexpandtab` for every filetype |

## Plugins

| Plugin | What it actually does here | Verdict |
| --- | --- | --- |
| lightline | Status line. Colorscheme `one`, powerline separators, mode / filename / fugitive branch / position / format / type. The `lineinfo` override is wiped by the next assignment, so the virtual-column tweak never applies. | Keep the look. Replace the plugin with our own status line, unless we decide to vendor it. |
| vim-cursorword | Underlines other occurrences of the word under the cursor, after a 50ms timer. Highlight is underline only. | Keep the behavior. About forty lines. No plugin. |
| vim-indent-object | Text objects `ai` `ii` `aI` `iI`: same-indent block, inner or including the line above, and with or without the line below. | Unused. Drop unless you want those objects back. |
| vim-vinegar | `-` in a file opens netrw on that file's directory and puts the cursor on the file. `-` again goes up. Also hides the netrw banner, sorts with `'suffixes'`, and adds `.` (put the path on the command line), `y.` (yank the path), and `~` (go home). Netrw's own `-` already goes up one directory. The part that is not built in is `-` from a normal buffer, seeking the file, and the banner. | Keep `-` and "land on the file you came from". Implement that ourselves. Leave dotfiles visible. |
| vim-commentary | `gc` / `gcc` to toggle comments via `'commentstring'`. | Neovim 0.10+ has this built in, and 0.12 maps `gc` and `gcc` in `vim._core.defaults`. Drop the plugin. Keep the commentstring overrides where the runtime default is wrong. |
| vim-characterize | `ga` prints the Unicode name, the digraph, and the HTML entity. The plugin is 2.1MB because it vendors the Unicode database. Built-in `ga` already prints decimal, hex, and octal. | Drop unless you still want the Unicode name on `ga`. |
| vim-fugitive | Not used for any Git command. The only call site is `FugitiveHead` in the status line. | Drop. A branch name is `git rev-parse --abbrev-ref HEAD`. A change gutter is a separate feature and is not what Fugitive is. |
| vim-syntaxMarkerFold | With `foldmethod=syntax`, it injects syntax regions so `{{{` / `}}}` also fold. Markers match only after a comment leader from `'comments'`. Numbered markers (`{{{1`) only go to level 5. It does nothing useful when syntax highlighting is off, and treesitter turns syntax highlighting off when it starts successfully. `zf` / `zd` do not work. | The goal stays: marker folds and structural folds at the same time. Replace this. Use real marker rules (a marker counts anywhere on the line, any level), which is what `:help fold-marker` does. |
| vim-gnupg | On `*.gpg` / `*.pgp` / `*.asc`: decrypt into the buffer, remember recipients or symmetric mode, encrypt again on write. See the GPG section below. | Keep the behavior. The plugin is the wrong long-term tool. Spec and replace it. Do not drop it until the replacement has been tried on a real file. |
| nvim-treesitter | Installed, but no `parser/*.so` exists anywhere under the data directory. Neovim 0.12 already embeds parsers. This plugin's job on a fresh install is to download and compile grammars. | Remove. Do not auto-install parsers. |

## Treesitter, as it runs today

The Lua block calls `vim.treesitter.start()` for `c`, `cpp`, `python`, `make`, and `sh`.

Checked with this Neovim:

| Filetype | What happens |
| --- | --- |
| c | The built-in parser loads. The built-in query `/usr/share/nvim/runtime/queries/c/highlights.scm` does not parse. Lines 209 and 225 contain `""%{b} %{d} %{Y}""` and `""%{H}:%{M}""`, and `vim.treesitter.start()` throws. Opening a C file hits that error from the FileType autocmd. Same failure with `nvim --clean`, so this is the shipped query, not a plugin override. |
| python, lua, vim, markdown | `start()` succeeds. On success it disables the legacy syntax highlighter. Groups become `@captures`. `slate` does not define those, so highlighting falls back to whatever the capture links to. Syntax folds die because syntax is off. |
| cpp, make, bash (what `sh` uses) | `start()` fails with "Parser could not be created". The autocmd still errors. |

So treesitter is not a theme. On C it is an error on every open. On Python it actively turns off the highlighter the colorscheme knows how to paint. No parser files are being fetched, which is good, but the plug entry still implies that `:TSUpdate` is how languages get installed. We will not do that.

## The parenthesis cursor

`()` matching is the built-in `matchparen` plugin, not treesitter. It highlights both ends with `MatchParen`. The default is `g:matchparen_disable_cursor_hl = 0`, so it also paints the bracket under the cursor. The help text says that highlight takes over the cursor style. What you see matches that, and it gets worse once treesitter extmarks are on the same cells: the cursor is drawn on the mate, `l` then moves from the real cursor (the `)`), and you land past it.

First change to try, before any rewrite of matching:

```vim
let g:matchparen_disable_cursor_hl = 1
```

That paints only the other bracket. If the cursor still teleports, we stop using `matchparen` and highlight the mate with an extmark that does not cover the cursor cell and does not use reverse. `MatchParen` in the new theme has to be a background color, not reverse, for the same reason.

`'showmatch'` is already off. That is a different feature (a brief cursor jump) and it is not the bug.

## GPG plugin, precisely

`jamessan/vim-gnupg` (GPL-2):

- Triggers on `*.gpg`, `*.pgp`, `*.asc`.
- Decrypts on read. On write, encrypts to the recipients it found on the original file, or with symmetric encryption if that is how the file was made. Cipher shows up in the gpg status output and is reused when gpg recognizes it.
- New files prompt for recipients, unless `g:GPGPreferSymmetric` is set (it is not).
- Buffer-local: `noswapfile`, `noundofile`, `buftype=acwrite`.
- It does not turn off `'backup'` or `'writebackup'`. `'writebackup'` is on by default.
- It runs `set viminfo=` globally on the first encrypted buffer. Neovim accepts that as `'shada'` and the value stays empty for the rest of the session. It never restores the old value.
- Temp files come from `tempname()`. Here that is `/tmp/nvim.wjl/`, mode `0700`. The directory is private, but it lives on the shared `/tmp` filesystem, and plaintext can pass through a shell temp file because `g:GPGUsePipes` defaults to off.
- Default gpg command includes `--trust-model always`.

The behavior you described (same recipients, or the same symmetric passphrase, plaintext only while editing) is what the plugin is aiming at. The shada wipe, the trust-model flag, and the temp-file path are why it should be replaced by a small module we can read, not treated as a black box. The repo header is CC0. Vendoring this plugin would put GPL-2 code in the tree. A thin wrapper we write can stay with the rest of the config.

Replaced by `lua/config/gpg.lua` in phase 5. See `docs/plan.md`.

## Lightline bug

`g:lightline.component` is assigned twice. The second assignment replaces the table, so `lineinfo` goes back to the plugin default. The `fileformat` field is the one that actually sticks. The status line still looks right because the layout tables are separate.

## Indent bug

`shiftwidth=0` means "follow `tabstop`". The FileType autocmd then sets `shiftwidth=4` for every filetype, which freezes it at 4 even if a buffer changes `tabstop`. Global `noexpandtab` is already the default. The autocmd's `noexpandtab` and `tabstop=4` are the part that matters, because filetype plugins fight them. Python's extra `noexpandtab` file does not.

## Settings that only restate the default

Drop these in the Lua port. They do not change behavior on 0.12.

| Setting | Note |
| --- | --- |
| `autoread` | Already on |
| `nofileignorecase` | Already off |
| `fixendofline` | Already on |
| `sidescroll=1` | Already 1 |
| `wrap` | Already on |
| `spelllang=en` | Already `en`, and `'spell'` is off, so this does nothing today |
| `sessionoptions+=tabpages` | Already in the default list |
| `sessionoptions+=terminal` | Already in the default list |
| `noexpandtab` (the global one) | Already the default. The FileType autocmd stays |
| `autoindent` | Already on |
| `visualbell` | `'belloff'` is `all`, so the bell never fires, visual or otherwise. The flash you asked for does not happen. Drop `visualbell` and keep the silence |
| `set path=` / `+=.` / `+=` | The comment wants the file's directory and the working directory. The value that actually lands is `path=.` only. The default is `.,,`. With the BufEnter `lcd`, those are usually the same directory. Use the default |

`background=dark` is the default, but a terminal can override it from `COLORFGBG`. One explicit line stays, as a guard for a dark scheme, with a comment that says why.

## Settings that are real choices

These stay. They are not defaults.

| Area | Choice |
| --- | --- |
| Files | `nomodeline`. `fileformats` adds `mac`. `fileencodings` empty, so files are UTF-8 only |
| Windows | `splitbelow`, `splitright`. `showtabline=2`. `switchbuf=usetab,newtab` |
| Cursor | `scrolloff=5`, `sidescrolloff=10`. `virtualedit=insert,block,onemore`. `whichwrap` includes the arrow keys in normal, visual, insert, and replace. `cursorline` with `cursorlineopt=number` |
| Search | `ignorecase` and `smartcase` |
| Display | `number`, `numberwidth=1`, `list` with the custom `listchars`, `showbreak=↪`, `linebreak`, `breakindent`, `colorcolumn=+1`, `display+=uhex`, `title`, `noshowmode` |
| Folds | `foldlevelstart=999`, `foldmethod=syntax`, `foldcolumn=2`, `foldignore` empty, custom foldtext, `<Space>` toggles a fold, `<Enter>` is `zx` |
| Edit | `tildeop`. `copyindent`. `nosmarttab`. `shiftround`. `tabstop=4`. `selection=exclusive`. `formatoptions+=2`. `Q` is `gq`. `report=0` |
| Mouse | `mouse=a` (default is `nvi`). `mousemodel=popup` (default is `popup_setpos`, which moves the cursor before the menu) |
| Match | `matchpairs` also includes `<>` and `«»` |
| Complete | `wildmode=longest:full`. `wildcharm=<C-z>`. Arrow keys are rotated while the wildmenu is open |
| Sessions | `sessionoptions` drops `buffers` and `curdir`, adds `sesdir`. `viewoptions` drops `curdir` |
| Other | `spelloptions+=camel` (only matters once spell is on). BufEnter `lcd` to the file's directory. GUI font `MesloLGS NF`. netrw time format and `netrw_keepdir=0`. `gS` prints the syntax stack |

Two of these are easy to forget and worth a conscious yes:

- `selection=exclusive` means the character under the cursor is not part of a characterwise visual selection.
- `switchbuf=newtab` means a buffer jump that does not already have a window opens a new tab.

## Defaults worth deciding on, not silently changing

| Default today | Why it is on the list |
| --- | --- |
| `noundofile` | Persistent undo is the one I would turn on. Undo files go to `~/.local/state/nvim/undo//`. GPG buffers must stay excluded |
| `nosmoothscroll` | You already wrap and break at words. `smoothscroll` scrolls a wrapped line by screen row |
| `updatetime=4000` | Fine until something uses `CursorHold`. The cursor-word timer does not |
| `clipboard` empty | Leave it alone unless you ask. Unnamed-plus makes every yank and delete touch the system clipboard |
| `nospell` | You configured spell languages and camel-case, then never turned spell on. A toggle is enough. Always-on spell is noisy |
| `hlsearch` on | There is no key to clear the highlight. A `<C-l>` that redraws and runs `:nohlsearch` is the usual one |
| `termguicolors` off | Keep the ability to run with it off. Truecolor can be an extra tier when the terminal has it |
| `writebackup` on | Fine for normal files. Off inside encrypted buffers |
| `inccommand=nosplit` | Already live-previews `:substitute` in the buffer. No work needed |
| `hidden` on | Already can leave a modified buffer. No work needed |
| `signcolumn=auto` | Leave it until a gutter exists, then `yes`, so the text does not shift |

## Mappings to preserve

| Keys | Action |
| --- | --- |
| `-` | Directory of the current file, cursor on that file. Again goes up |
| `gc`, `gcc` | Toggle comment. Built in after commentary is gone |
| `<Space>` | `za` |
| `<Enter>` | `zx` (recompute folds under the cursor and honor `foldlevel`) |
| `Q` | `gq` in normal and visual. This replaces Ex mode |
| `gS` | Syntax group under the cursor. For treesitter captures and everything else, Neovim's own `:Inspect` |
| arrows in command line | Rotated while the wildmenu is open |
| netrw `I` | Banner toggle, once we hide the banner by default |

## Fold text

The custom fold text is worth keeping. It shows the first non-blank line, a short tail of the last non-blank line, a dotted filler, and `+N (P%)`. The tab drawing is hard-coded to `┊` and does not read `'listchars'`. The width trim uses a byte slice (`[0:max_width]`) rather than a display-width trim, which is the likely source of "sometimes does weird things" on multibyte lines and on the `⋯` tail.
