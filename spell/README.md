# Spell files

Copied in on purpose, so spell checking works with no network. The rest of this config is CC0. These files keep their own licenses, listed below.

English is not here: every Neovim ships `en.utf-8.spl` in its runtime (byte for byte the same file as upstream's).

French and Swedish are built here from current hunspell dictionaries by `nvim -l spell/build.lua` (needs curl and unzip; sources are pinned by URL and sha256, and the build is reproducible). German and Spanish are Vim's own prebuilt files from https://ftp.nluug.nl/pub/vim/runtime/spell/, fetched 2026-11-08. The README or license file beside each one is upstream's, unchanged, and holds the full credits and license text.

| File | sha256 | Built from | License |
| --- | --- | --- | --- |
| `fr.utf-8.spl` | `1c38db27da11cba4636d6dacabd437f5575ea70b3c1a5f7fe08458471c8b3298` | Grammalecte 7.7 "toutes variantes" (Olivier R. and contributors): traditional and 1990 spellings both pass. See `README_dict_fr.txt` | MPL 2.0 |
| `de.utf-8.spl` | `73c7107ea339856cdbe921deb92a45939c4de6eb9c07261da1b9dd19f683a3d1` | LibreOffice "frami" word lists (Björn Jacke, Franz Michael Baumann), via https://github.com/Yamagi/vim-german-dictionaries | Word lists GPL 2 / GPL 3; Yamagi's work 2-clause BSD. See `COPYING_de.txt` |
| `sv.utf-8.spl` | `c30157b068d974d0521d4c1cde7516fd7f7eab140ce1fa9bd1381c3f5614b34f` | LibreOffice "Den stora svenska ordlistan" 2.42 (Göran Andersson), LibreOffice/dictionaries at `4f1df64` | LGPL 3. See `LICENSE_sv_SE.txt` |
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
| `sv`, `sv_se` | Swedish |
| `fr` | French, every spelling Grammalecte knows (no regions) |

## French notes

Grammalecte publishes three French dictionaries: "classique" (usual spelling plus a few reformed forms), "réforme 1990" (reformed only), and "toutes variantes" (both). The 1990 spellings are recommended, never required, and both old and new are correct; the reform is still argued over. "toutes variantes" accepts `oignon` and `ognon`, `connaître` and `connaitre`, and flags neither.

Vim's builder skips some hunspell rules in the French file. A typographic apostrophe (`aujourd’hui`) is not read as `'`, so `aujourd'hui` passes and `aujourd’hui` is flagged; `va-t-il` is flagged. A gain: `-` separates words, so `spelllang=en,fr` checks English compounds (`cross-platform`) half by half, as English alone does.

## Not here

The `.sug` files (sound-alike suggestions for `z=`) add about 10 MB. Tried on typical misspellings in all five languages, `z=` gave the same top suggestions with and without them, because the `.spl` files already carry the sound rules.

`zg` and `zw` write `xx.utf-8.add` here, a plain word list that belongs in git. Neovim compiles it to `xx.utf-8.add.spl` on its own, which `.gitignore` keeps out.

A language not listed here still triggers Neovim's own prompt to download it.
