-- The runtime ftplugin turns on the treesitter highlighter. Treesitter can
-- only color a fenced block whose language has a parser installed, and that
-- set differs from system to system. The classic markdown syntax colors
-- every language in g:markdown_fenced_languages (init.lua) everywhere, so
-- markdown uses that. The ftplugin's gO, ]], and [[ still work; they read
-- the parser, not the highlighter.
vim.treesitter.stop()
