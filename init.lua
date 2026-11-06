-- Neovim configuration
-- Wesley J. Landaker
--
-- This work is marked with CC0 1.0.
-- https://creativecommons.org/publicdomain/zero/1.0/
--
-- pack/vendor keeps its own licenses. See pack/vendor/VENDOR.md.

-- Set before the plugins that read them. matchparen and netrw load later.
vim.g.matchparen_disable_cursor_hl = 1
vim.g.netrw_banner = 0
vim.g.netrw_keepdir = 0
vim.g.netrw_timefmt = '%F %T'
-- Use our status line in the quickfix window too.
vim.g.qf_disable_statusline = 1

require('config.options')
require('config.highlights').setup()
require('config.folds').setup()
require('config.autocmds').setup()
require('config.mappings').setup()
require('config.files').setup()
require('config.cursorword').setup()
require('config.statusline').setup()
require('config.tabs').setup()
