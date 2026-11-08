-- The runtime ftplugin turns on the treesitter highlighter and points
-- 'foldexpr' at treesitter alone. Lua highlighting stays. The fold
-- expression is ours, so a {{{ marker still counts inside a Lua file.
vim.wo.foldexpr = 'v:lua.Config.foldlevel()'
vim.wo.foldmethod = 'expr'
