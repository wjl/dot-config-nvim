# Spell files

Copied in on purpose, so spell checking works with no network. The rest of this config is CC0. These files keep their own licenses, listed below.

English is not here: every Neovim ships `en.utf-8.spl` in its runtime (byte for byte the same file as upstream's).

All four come from the Vim spell file server, https://ftp.nluug.nl/pub/vim/runtime/spell/, fetched 2026-11-08. The `README_xx.txt` beside each one is upstream's, unchanged, and holds the full credits and license text.

| File | sha256 | Built from | License |
| --- | --- | --- | --- |
| `fr.utf-8.spl` | `abfb9702b98d887c175ace58f1ab39733dc08d03b674d914f56344ef86e63b61` | Dicollecte / OpenOffice.org `fr_FR` (Christophe Pythoud and others); includes 1990 reform spellings | MPL 1.1 / GPL 2.0+ / LGPL 2.1+, your choice |
| `de.utf-8.spl` | `73c7107ea339856cdbe921deb92a45939c4de6eb9c07261da1b9dd19f683a3d1` | LibreOffice "frami" word lists (Björn Jacke, Franz Michael Baumann), via https://github.com/Yamagi/vim-german-dictionaries | Word lists GPL 2 / GPL 3; Yamagi's work 2-clause BSD. See `COPYING_de.txt` |
| `sv.utf-8.spl` | `73ed2845a1766ca21d5388fc766d926074a90a7ba9223458fc0d0dcecc72ab52` | DSSO, http://dsso.se (Tom Westerberg, Göran Andersson) | MPL 1.1 / GPL 2.0 / LGPL 2.1, your choice |
| `es.utf-8.spl` | `963637ac925cf8a51bf207fac392d6b4c69795711dcc2d4809b78846ae367be3` | RLA-ES `es_ES` and `es_MX` (Santiago Bosio) | LGPL |

The word lists these were built from are the sources named above and in each README. Rebuild with `:mkspell` from those `.aff` / `.dic` files.

## Regions

A file can hold several regions. `spelllang=de` accepts all of them; a region narrows it.

| `spelllang` | Accepts |
| --- | --- |
| `en_us`, `en_gb`, `en_ca`, `en_au`, `en_nz` | one English (`en` accepts all) |
| `de_de`, `de_at`, `de_ch` | German, Austrian, Swiss (`de_ch` has no ß) |
| `de_20`, `de_19` | reformed spelling (1996), or the old one (`daß`) |
| `es_es`, `es_mx` | Spain or Mexico |
| `fr`, `sv` | one region each |

## Not here

The `.sug` files (sound-alike suggestions for `z=`) add about 10 MB. Tried on typical misspellings in all five languages, `z=` gave the same top suggestions with and without them, because the `.spl` files already carry the sound rules.

`zg` and `zw` write `xx.utf-8.add` here, a plain word list that belongs in git. Neovim compiles it to `xx.utf-8.add.spl` on its own, which `.gitignore` keeps out.

A language not listed here still triggers Neovim's own prompt to download it.
