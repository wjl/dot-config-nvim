# Plan

Work one phase at a time. A phase is done when it has been used in a real editing session, not when the file parses.

The target is a TUI editor with Vim motions, a readable dark theme on any terminal, and no plugin that we cannot read or that downloads code at install time. LSP, completion menus, and AI stay out until you describe them. They are not implied by the rest of this plan.

## Decisions already made

These come straight from the request. Later phases should not relitigate them.

- Neovim only. 0.12 is the floor. No Vim-compatible vimscript layer.
- The config is split into Lua modules. `init.lua` only bootstraps.
- A behavior we can write clearly ourselves is written here. A plugin is a last resort.
- Nothing fetches from the network on startup or on first install. If a third-party file stays, it is copied into the repo with its license, upstream URL, and commit, and it updates only when we do that on purpose.
- `gc` / `gcc` stay, via the built-in implementation.
- The word under the cursor stays underlined, via our own code.
- `-` still opens the directory of the current file and lands on that file. `-` again goes up.
- Marker folds (`{{{` / `}}}`) and structural folds both work, including numbered markers at any level.
- Opening a `.gpg` / `.pgp` / `.asc` file decrypts it, editing is plaintext, and writing encrypts back to the same recipients or the same symmetric passphrase. Temp files live in a `0700` directory we choose. Swap, undo, and backup files are not written for that buffer. `'shada'` is not cleared for the whole session.
- The theme has to look intentional at four levels: monochrome, 16 ANSI colors, 256 colors, and truecolor. Truecolor is optional. The other three are required.
- There will be several themes, not one. The quality bar is PaperColor's light variant: a grey page (`#eeeeee`) rather than pure white, with color used deliberately. That palette is a reference, not the set we are required to clone. `slate` stays only until a replacement exists. `background=dark` in the current file would have selected PaperColor's dark variant (`#1c1c1c`) whenever the scheme obeyed `'background'`.
- The status line is ours. It keeps the information lightline shows now: mode, readonly, filename, modified, branch, line:virtual-column, percent, file format, filetype.
- A change gutter comes after the editor itself is solid. Git operations stay on the command line. The editor does not grow a second Git UI.
- Settings that only restate a 0.12 default get deleted. The audit is in [current-state.md](current-state.md).

## Proposed layout

```
init.lua
lua/config/options.lua
lua/config/highlights.lua
lua/config/mappings.lua
lua/config/autocmds.lua
lua/config/folds.lua
lua/config/statusline.lua
lua/config/cursorword.lua
lua/config/files.lua          -- netrw "-"
lua/config/tabs.lua           -- :TabSort
lua/config/gpg.lua            -- phase 5
colors/                       -- phase 3, several schemes
ftdetect/
ftplugin/
docs/
```

No `plugin/` directory that runs third-party code unless a phase explicitly vendors something. vim-plug is gone. The fold plugin is gone. GPG is copied under `pack/vendor/` until phase 5. That copy is GPL-2 and is deleted when `gpg.lua` replaces it.

## Phase 1 — Stop the damage

Applied, then carried into the Lua port. Checked in the terminal: the cursor on `(` stays the cursor, and the mate is a brighter yellow/orange underline. The same in the other direction.

- Delete the treesitter FileType autocmd and the `nvim-treesitter` plug line. C files stop throwing on open. Python goes back to the legacy syntax highlighter, which `slate` can paint, and syntax folds start working again on filetypes that define them.
- Set `g:matchparen_disable_cursor_hl = 1`. Check `(abcd)` with the cursor on `(` and on `)`. The cursor must stay on the bracket you are on, and `h` / `l` must land where the cursor is drawn. If it still teleports, disable `matchparen` in this same phase and replace it.
- Rebuild `g:lightline.component` as one table so `lineinfo` is `%3l:%-2v` and `fileformat` keeps its `%<`.
- In the FileType autocmd, set `shiftwidth=0` so it keeps following `tabstop`. Leave `noexpandtab` and `tabstop=4`.
- Delete `visualbell`. `'belloff=all'` already means silence.

Done when: a C file opens with no error, Python highlighting looks like it did before treesitter, the cursor stays on the bracket you moved to, and the status line still looks like lightline.

## Phase 2 — Lua, same behavior

Ported. `init.lua` is the only entry point. Neovim 0.12 errors with `E5422` if `init.vim` is also present, so the vimscript file was deleted. It is not ignored.

Headless checks on 2026-11-06, after `VimEnter` (netrw does not build a listing before that event, so a `-c quit` is not a valid test):

- A C file opens with legacy syntax, `shiftwidth=0`, `tabstop=4`, `noexpandtab`, and no startup message. Python keeps the same indent against its filetype plugin.
- `MatchParen` is underline plus yellow foreground, and no background.
- The status line is the lightline `one` layout, including an asynchronous git branch. In this repo that branch is `master`. A directory that is not a repository shows no branch.
- `-` from a file opens that file's directory and lands on the file. `-` again goes up and lands on the directory name. The netrw banner stays hidden.
- Opening a directory as the file argument also opens a netrw listing. An empty buffer name in that case is netrw itself. `--clean` does the same.
- `:TabSort` orders tabs by full path. The tab you were in stays current.
- `gc` is the built-in map. indent-object and characterize are gone. vim-plug is gone.
- vim-gnupg and vim-syntaxMarkerFold load from `pack/vendor/`.

Not brought over from vinegar: `.` to put the path on the command line, `y.` to yank it, and `~` to go home. Dotfiles stay visible.

This phase is in the editor. It is not signed off until a real editing session. The things to look at are the status line, `-`, and `:TabSort`.

`selection=exclusive` stays, with `virtualedit` including `onemore`, so the cursor can sit one past the last character and that character can be part of a selection. Half-open ranges are the reason to keep it. Some visual operations that assume an inclusive selection feel one character short. That is the tradeoff, and it was chosen on purpose.

`switchbuf=usetab,newtab` stays. The default `uselast` sends a quickfix jump to the window you used last, which is a split. `usetab` reuses a tab that already shows the buffer. `newtab` opens a new tab otherwise. `:split` still splits. This is the "one file per tab" setting. It covers quickfix, `:stag`, CTRL-W f, and `:sbuffer`.

Still loaded until its own phase: vim-gnupg. The fold plugin stayed through the port and was removed when folding moved to `foldmethod=expr`.

Done when: a day of editing does not turn up a missing mapping, and `:scriptnames` shows no plug path except GPG and the fold plugin.

## Phase 3 — Themes

A small set of schemes we own, not one, and not a gallery of the built-in defaults. PaperColor light is the quality bar: readable on a grey page, color carrying meaning, nothing fluorescent for its own sake. Each scheme still has to survive every terminal tier, including an 8-color terminal.

The first scheme is `folio`. It is one name with two pages. `:set background=light` loads the warm grey page. `:set background=dark` loads the warm near-black page. Startup stays dark. `:colorscheme slate` is still there. The status line keeps the lightline `one` colors, so the bar does not change with the page. Both pages have been looked at in a real terminal, including an 8-color terminal and a 16-color terminal.

`dos` and `brimstone` are one look each. `:set background` reloads them and the colors stay. Startup stays `folio`.

`dos` is white on the Borland blue (`#0000AA`) in truecolor and in 256 colors. Keywords are yellow, comments are light cyan, strings are light green, and a selection is a solid black-on-cyan bar. At 16 colors the page stays black. Konsole's ANSI blue is sky blue, so a blue page washes out. Keywords stay yellow, strings and types are bright blue, and comments are cyan. At 8 colors the page is white on black, keywords are yellow, and the strings and types are blue instead of green.

`brimstone` is warm gold (`#F8E6B4`) on a darker brick (`#4E2824`) in truecolor. Comments are gray, so they do not read as a second copy of the body. 256 colors have no dark brown, so that tier is the same gold on a deep red. At 16 colors the page stays black, because ANSI red is too bright on Konsole to be a page. The body is yellow, keywords are white, and comments are orange. At 8 colors the body is white on black and the other roles are yellow.

You have looked at `folio`, `dos`, and `brimstone` in a real terminal, including the 8-color and 16-color fallbacks. This set is enough for now. More schemes wait until you ask. The rules for a new one are in `colors/README.md`.

Tiers, picked from what the terminal can do:

| Tier | When | How highlights are specified |
| --- | --- | --- |
| Mono | `'t_Co'` below 8, or a dumb terminal | bold, underline, italic, reverse only. No assumption of color |
| 8 | `'t_Co'` below 16 and at least 8, `termguicolors` off | ANSI 0–7 only. Bright indexes are not colors on these terminals |
| 16 | `'t_Co'` at least 16 and below 256, `termguicolors` off | ANSI 0–15 only, so the terminal's own palette supplies the actual color |
| 256 | `'t_Co'` is 256 and `termguicolors` off | palette indexes chosen for that scheme |
| Truecolor | `termguicolors` on | the same design as hex |

The bracket under the cursor is left as the cursor. The other bracket is a foreground color plus an underline, with no background, so it cannot be mistaken for the cursor. `CursorWord` is underline too, but it does not match on brackets.

Every treesitter `@capture` we care about is linked to a classic group (`@function` to `Function`, `@comment` to `Comment`, and so on). Turning the highlighter on later must not invent a second palette.

`gS` prints the syntax stack and, when a treesitter highlighter is active, the captures under the cursor.

Done when: each scheme in the set is readable in `TERM=dumb`, an 8-color `TERM`, a 16-color `TERM`, `xterm-256color` with `termguicolors` off, and a truecolor terminal. A written note of that check goes in this file.

## Phase 4 — Folds

Replace syntaxMarkerFold.

`foldmethod=expr`. For each line:

1. If the line has a fold marker, use Vim's marker rules. That includes `{{{` / `}}}`, numbered `{{{1`, and a marker that is not inside a comment. The old plugin missed the last two, which is a lot of why it felt unreliable.
2. Otherwise use a structural level from a small scanner in Lua (`lua/config/foldscan/`). Legacy syntax folds do not have a supported "what level is this line" function, which is why the old plugin injected fake syntax regions. We will not keep doing that.
3. If that language has neither, the line does not add a structural fold. Indent folding is not a substitute unless you ask for it.

`foldlevelstart=999` and the fold text stay. `<Space>` and `<Enter>` stay. `foldcolumn` is 1 with `fillchars` `foldinner:│`: `-` where an open fold starts, `+` on a closed fold, `│` on every line inside a fold, and never a level digit. At 2 columns, nested folds showed digits that ran into the line numbers.

`*.txt` is the markdown filetype (`vim.filetype.add` in `options.lua`). Filenames Neovim knows, such as `CMakeLists.txt` and `requirements.txt`, and help files keep their own filetype. `after/syntax/markdown.vim` highlights `{{{` / `}}}` as `Special` and drops markdown's error mark on a `_` inside a word. The markdown filetype plugin turns `expandtab` on; the FileType indent lock turns it back off. Markdown treats a tab-indented line after a blank line as an indented code block. An earlier `syntax/text.vim` kept a smaller markdown-like set for `.txt`; it is gone.

Treesitter highlighting stays off in this phase unless a language passed the phase 3 capture links and a manual check that `()` navigation is still honest. A fold query does not require the highlighter.

`lua/config/folds.lua` is that expression. The marker half follows `:help fold-marker`, including a numbered marker past level 5 and a marker that is not in a comment. A line where a marker opens gets `>`, so two marker sections with no blank line between them stay two folds.

The structural half is `lua/config/foldscan/`, one small lexer per family. `init.lua` maps a filetype to its scanner and turns ranges into levels.

| Scanner | Filetypes | What folds |
| --- | --- | --- |
| `clike.lua` | c, cpp, go, rust, javascript, typescript (and the react variants), json | `{ }` blocks from the line their statement starts on, block comments; C `#if` branches, multi-line `#define`, `#include` runs; Go `import (` groups; multi-line `[ ]` in JS, JSON, and Rust |
| `python.lua` | python | a line ending in `:` and its deeper lines, decorators included |
| `lua.lua` | lua | `function`, `if`, `do`, `while`, `for`, `repeat`, multi-line tables |
| `shell.lua` | sh, bash, zsh, ksh | `if`, loops, `case`, `{ }` groups and function bodies, heredocs. Keywords count only in command position. Quotes and `$( )` nest across lines |
| `vim.lua` | vim | `function`/`def`, `if`, `for`, `while`, `try`, `augroup`, class/interface/enum, heredocs, with Vim's abbreviations (`fu`, `endf`, `en`) |
| `make.lua` | make | a rule and its recipe, `ifeq` … `else` … `endif`, `define`/`endef`, continued assignments |
| `config.lua` | toml, dosini, confini, systemd, gitconfig, desktop | sections; in TOML `[a.b]` nests in `[a]`, and multi-line arrays and strings fold |
| `markdown.lua` | markdown (and so `*.txt`) | heading sections nested by rank (setext too), code fences, front matter, HTML comments, a list of two or more items, a list item with sub-items |

`elif`, `else`, `except`, `case`, and `} else {` each get their own fold beside the one before. Inside a markdown or text code fence, the fence's language scanner runs too, so a function in a ```` ```python ```` block folds. The level is added to the marker level, so a function inside a `{{{` block is a nested fold and a function outside one still folds. Other filetypes get markers only. Adding a language is usually a few lines in one of these files.

Why a lexer and not treesitter: a treesitter parser is native code. Distros ship different sets (openSUSE has C, Lua, and Python but not C++; the official release tarball has no Python), and wasm parsers need a Neovim built with wasmtime, which is opt-in and experimental. The scanners are plain Lua, so folds are the same on every system that runs a recent Neovim, with nothing to build or install per machine. They know where blocks start and end and nothing about what a name means. Checked on real files from this system, about 3.4M lines over every filetype above: no errors, and blocks left open at the end of a file only where the file is not really that language (Perl and Tcl behind a `#!/bin/sh` line) or is itself unbalanced. Where treesitter could fold the same files (C, Python, Lua, Vimscript, Markdown), the fold starts agree except where the branch-per-fold choice above differs by design. A rescan on a 14k-line header takes about 8 ms per edit.

The runtime Lua filetype plugin turns the highlighter on and replaces `'foldexpr'`; `after/ftplugin/lua.lua` puts our expression back. Lua highlighting stays, because that language was already checked.

Markdown: the runtime filetype plugin also turns on the treesitter highlighter, which can only color a code fence whose language has a parser installed. `after/ftplugin/markdown.lua` stops it, so the classic markdown syntax colors fences in every language listed in `g:markdown_fenced_languages` (`init.lua`) on every system. `gO`, `]]`, and `[[` from the runtime plugin still work. `*.txt` no longer forces `foldmethod=marker`. `zf` and `zd` create markers only when `'foldmethod'` is `marker`, so they do not insert markers while this expression is set.

Not signed off until you have folded the samples in `~/Scratch/folds` (one per filetype above) and some real files of your own.

## Phase 5 — GPG

Until this phase, `g:GPGUsePipes` is set in `init.lua` so decrypt and encrypt do not write plaintext under `/tmp`. The save path still copies ciphertext from that temp directory onto the home filesystem, and a crash in that window can drop the original. That stays until the rewrite.

Write `lua/config/gpg.lua`. Do not start it by copying the plugin. The behavior spec:

- File patterns: `*.gpg`, `*.pgp`, `*.asc`.
- Read: `gpg --decrypt`. Passphrase comes from gpg-agent / pinentry. We never store it.
- The decrypt status is parsed for "encrypted with a passphrase" versus public-key packets, and the key ids are stored on the buffer.
- Write: encrypt with that same mode. Public-key files get the same recipient list. Symmetric files get `--symmetric` and the agent asks again only if the agent does not still have the passphrase. A new file asks once which of those two you want.
- The buffer is `noswapfile`, `noundofile`, `nobackup`, `nowritebackup`, `buftype=acwrite`.
- `'shada'` is left alone. We do not assign it inside a buffer hook.
- Temp files are created under `$XDG_RUNTIME_DIR/nvim-gpg` if that is set, otherwise `~/.local/state/nvim/gpg`, mode `0700`, and removed in a `finally`. No plaintext under `/tmp`.
- No `--trust-model always`.

Test with throwaway files only: one symmetric, one encrypted to a key you already have, one new file, and a write that fails (wrong passphrase, unknown key) and must not destroy the original. Confirm with `ls` that no swap, undo, or backup file appeared, and that `'shada'` after the session is not empty.

The plugin is removed in the same change that passes those checks, not before.

## Phase 6 — Change gutter

Wanted, after the editor itself is solid. This is the part of "Git in the editor" that is actually useful next to a CLI workflow.

- A sign column for added, changed, and deleted lines, from `git diff` against the file on disk versus `HEAD`.
- Refresh on save and on focus, not on every keystroke.
- No `:Git`, no status window, no hunk staging, unless you later ask.
- `signcolumn=yes` while this is on, so the text does not jump.
- Branch name is already on the status line from phase 2.

In-house. A vendored plugin is on the table only if the diff parsing turns out to be a project of its own, and then it is copied in at a pinned commit.

## Phase 7 — Defaults we choose

Turn on only the rows you say yes to. Candidates are in the audit: persistent undo, `smoothscroll`, a `<C-l>` that clears search highlighting, a spell toggle. Nothing else from that table changes by default.

## Phase 8 — AI

Not designed yet. When you describe it, the notes go in `docs/ai.md` before any code. Likely pieces, so we are not surprised later: a terminal or a buffer running a CLI you already use, versus inline completion, versus an LSP. Those are different projects. Supply-chain rules from phase 2 still apply. No plugin that phones home for its own install.

## Explicitly not in this refresh

- A plugin manager.
- `:TSUpdate` or any compile-on-install grammar.
- mason, a completion framework, or a fuzzy finder, unless a later note says so.
- Replacing netrw with a file-tree sidebar. `-` is the interface.
- Running Git operations from the editor.

## Open questions

Answered already: own status line. Change gutter in phase 6. PaperColor light is the quality bar, and phase 3 is a set of schemes, not a port of that one palette. Drop indent-object and characterize. Keep `selection=exclusive`. Keep `switchbuf=usetab,newtab`. `:TabSort` is the extra command from this round. Vinegar's `.`, `y.`, and `~` were not carried over.

| Question | Blocks |
| --- | --- |
| Persistent undo? `smoothscroll`? A clear-highlight key? A spell toggle? | Phase 7 |
| For new `.gpg` files, ask every time, or default to symmetric? | Phase 5 |
| Which AI tools, and inline versus a buffer versus a terminal? | Phase 8 |
