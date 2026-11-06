-- Neovim configuration
-- Wesley J. Landaker
--
-- This work is marked with CC0 1.0.
-- https://creativecommons.org/publicdomain/zero/1.0/
--
-- pack/vendor keeps its own licenses. See pack/vendor/VENDOR.md.

-- The distro package vim-plugin-gnupg installs an older plugin in
-- /usr/share/vim/site. That file loads first, sets g:loaded_gnupg, and the
-- vendored copy never installs. The only unrelated file there is a ninja
-- syntax script, and Neovim's runtime already provides syntax/ninja.vim.
vim.opt.runtimepath:remove('/usr/share/vim/site')

-- Set before the plugins that read them. matchparen and netrw load later.
vim.g.matchparen_disable_cursor_hl = 1
vim.g.netrw_banner = 0
vim.g.netrw_keepdir = 0
vim.g.netrw_timefmt = '%F %T'
-- Use our status line in the quickfix window too.
vim.g.qf_disable_statusline = 1
-- vim-gnupg defaults to shell temp files, which puts plaintext under /tmp.
-- Pipes keep the plaintext off disk. Pinentry is GTK, so it does not need the
-- curses tty this setting can disrupt. Removed when gpg.lua replaces the plugin.
vim.g.GPGUsePipes = 1

require('config.options')
require('config.highlights').setup()
require('config.folds').setup()
require('config.autocmds').setup()
require('config.mappings').setup()
require('config.files').setup()
require('config.cursorword').setup()
require('config.statusline').setup()
require('config.tabs').setup()
