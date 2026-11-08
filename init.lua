-- Neovim configuration
-- Wesley J. Landaker
--
-- This work is marked with CC0 1.0.
-- https://creativecommons.org/publicdomain/zero/1.0/
--
-- The distro package vim-plugin-gnupg installs vim-gnupg in
-- /usr/share/vim/site. lua/config/gpg.lua handles those files instead, and
-- also sets g:loaded_gnupg. The only unrelated file there is a ninja syntax
-- script, and Neovim's runtime already provides syntax/ninja.vim.
vim.opt.runtimepath:remove('/usr/share/vim/site')

-- Set before the plugins that read them. matchparen and netrw load later.
vim.g.matchparen_disable_cursor_hl = 1
vim.g.netrw_banner = 0
vim.g.netrw_keepdir = 0
vim.g.netrw_timefmt = '%F %T'
-- Use our status line in the quickfix window too.
vim.g.qf_disable_statusline = 1
-- Fenced code blocks in markdown (and so in .txt files) are highlighted
-- in their own language. Each entry is `fence word=syntax name`, or just
-- the syntax name. Every entry loads that syntax file when a markdown
-- buffer opens, so keep the list to languages that are used.
vim.g.markdown_fenced_languages = {
	'sh',
	'bash=sh',
	'shell=sh',
	'zsh',
	'c',
	'cpp',
	'go',
	'rust',
	'rs=rust',
	'python',
	'py=python',
	'lua',
	'vim',
	'javascript',
	'js=javascript',
	'typescript',
	'ts=typescript',
	'json',
	'make',
	'makefile=make',
	'toml',
	'ini=dosini',
	'dosini',
	'systemd',
	'gitconfig',
	'yaml',
	'diff',
}

-- Functions that option expressions call ('foldexpr', 'statuscolumn').
-- Neovim runs those once per line, and v:lua.Config.name() costs about a
-- third of v:lua.require("module").name().
_G.Config = {}

require('config.options')
require('config.highlights').setup()
require('config.folds').setup()
require('config.gpg').setup()
require('config.gutter').setup()
require('config.autocmds').setup()
require('config.mappings').setup()
require('config.files').setup()
require('config.cursorword').setup()
require('config.statusline').setup()
require('config.tabs').setup()
