# Vendored plugins

These are copied into the repo on purpose. Nothing here is fetched when Neovim starts. Update them by copying a known commit in, then record that commit below.

The rest of this config is CC0. These two directories keep their own licenses.

| Directory | Upstream | Commit | License | Why it is still here |
| --- | --- | --- | --- | --- |
| `start/vim-gnupg` | https://github.com/jamessan/vim-gnupg | `026943e5722ba8c507ebd299522c2763a5e862e9` | GPL-2.0 | Decrypt, edit, and re-encrypt `.gpg` / `.pgp` / `.asc`. Replaced in phase 5. |
| `start/vim-syntaxMarkerFold` | https://github.com/Jorengarenar/vim-syntaxMarkerFold | `f9b6ad822d4a1d355cb56b8c026e059871149c69` | MIT | Syntax folds and `{{{` markers at the same time. Replaced in phase 4. |
