# Schemes

`folio`, `dos`, and `brimstone` live in this directory. Each file paints every tier and calls `scheme.apply`. Startup stays `folio`. A new name also goes in the owned set in `lua/config/highlights.lua`, or MatchParen and a `'termguicolors'` change ignore it.

The loader is `lua/config/colorscheme.lua`. A color is `{ hex, ansi, c256, ansi8 }`.

| Tier | When | Indexes |
| --- | --- | --- |
| `mono` | `'t_Co'` below 8 | none. Bold, italic, underline, reverse |
| `ansi8` | `'t_Co'` below 16, `'termguicolors'` off | 0–7 only |
| `ansi` | `'t_Co'` below 256, same | 0–15 |
| `c256` | `'t_Co'` is 256, same | hand-picked |
| `gui` | `'termguicolors'` on | the hex |

`'termguicolors'` wins over `'t_Co'`. An 8-color and a 16-color scheme do not share a palette. The fourth number is the 8-color index. If you leave it off, an index of 8 or more is dropped. On an 8-color terminal, 8 is SGR 38, which means "default", not a bright color. That is how text disappeared in the first 8-color pass.

## What an index actually is

The number is not a color. It is a slot in the terminal's palette.

Konsole's Breeze palette is the one this config is looked at in. Its blue (4) is `#1D99F3` and its red (1) is `#ED1515`. White on that blue is about 3:1. Yellow on that red is about 2.6:1. The same indexes on a CGA palette are navy and dark red, and white on that navy is about 13:1. A blue or red page cannot be both. After looking at both, the 16-color page stays black, and the scheme shows up in the foregrounds.

Foregrounds that stay readable on black in Breeze, CGA, and xterm: white (7, 15), yellow (3, 11), cyan (6), green (2, 10). Bright blue (12) is the blue that still looks blue on Breeze (`#3DAEE9`, about 6:1) and on CGA (`#5555FF`, about 4:1). Plain blue (4) is fine on Breeze and nearly invisible on CGA and xterm, about 1.6:1 and 2.2:1. dos uses 12 for strings at 16 colors, and 4 at 8 colors, because an 8-color terminal has no bright blue. Say so if a VGA console makes those strings vanish.

Bright cyan (14) is `#55FFFF` on CGA and `#16A085` on Breeze, which is darker than normal cyan. Comments use 6. Red as text on black is about 3:1 on Breeze and worse on CGA. Do not use it for a role someone has to read.

Two schemes that both use green and cyan on black look like the same terminal. dos is yellow, bright blue, and cyan. brimstone is yellow, white, and orange. Green is reserved for a diff.

## Truecolor and 256

Pick the hex for the page you want to stare at. Check the contrast, then look at it. dos is `#FFFFFF` on `#0000AA` (about 13:1). The first body was `#E4E4E4` and it was not enough. brimstone is `#F8E6B4` on `#4E2824` (about 10:1). A comment that is a darker gold reads as the body. brimstone's comments are gray (`#C6C6C6`, about 7.4:1).

The 256-color cube has no dark brown. brimstone's page there is index 52 (`#5f0000`). Do not ask a nearest-color function to choose. It maps different golds onto one index.

A one-look scheme does not read `'background'`. folio does, and neither scheme sets it. Vim reloads the active scheme when `'background'` changes.

`'termguicolors'` does not reload a scheme. The OptionSet autocmd in `highlights.lua` does, and it has to be `nested`, because `highlight clear` wipes the status line and the text-syntax links. The ColorScheme autocmd puts them back. The status line keeps its own colors.

MatchParen is an underline and a foreground. A background looks like a second cursor. The bracket under the cursor stays the cursor.

`@captures` link to classic groups. A scheme does not grow a second palette for treesitter.

At 8 and 16 colors the cursor line and the color column use the page color. A different background index draws a stripe through the file.

## Looking at a tier

Neovim ignores `:set t_Co`. A headless Neovim always reports 256 colors, so a headless run cannot show you the tier. In a real terminal, Konsole's own variables force 256 colors unless they are unset:

```bash
env -u COLORTERM -u KONSOLE_VERSION -u KONSOLE_DBUS_SESSION TERM=screen-16color nvim -c 'set notermguicolors' -c 'colorscheme dos'
env -u COLORTERM -u KONSOLE_VERSION -u KONSOLE_DBUS_SESSION TERM=ansi nvim -c 'set notermguicolors' -c 'colorscheme dos'
env -u COLORTERM -u KONSOLE_VERSION -u KONSOLE_DBUS_SESSION TERM=dumb nvim -c 'set notermguicolors' -c 'colorscheme dos'
```

Inside a truecolor session, `:set notermguicolors` is the 256-color tier. `:lua print(require('config.colorscheme').tier())` prints `gui`, `c256`, `ansi`, `ansi8`, or `mono`.
