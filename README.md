# ~/.config/nvim

This is my NeoVim configuration. `init.lua` is the entry point. The refresh plan is in [docs/](docs/README.md). Feel free to use as-is, modify it, or just mine it for ideas.

It requires:
- NeoVim -- this won't work with Vim.
- a NerdFont to display correctly (it assumes Meslo NF in GUI mode).
- probably makes some other assumptions that I'm forgetting.

Known issues:
- The custom foldmethod is great, but sometimes does weird things.
If this happens, just use ":set foldmethod=marker" or whatever you want on the fly.
- Probably some other little things, see the TODOs and FIXMEs in the code.
