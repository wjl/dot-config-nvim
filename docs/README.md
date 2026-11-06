# Neovim config refresh

The live config is `init.lua` and `lua/config/`. Nothing in this directory is loaded by Neovim.

Read these in order:

1. [current-state.md](current-state.md) is the audit of the old vimscript config, including the bugs that the port was fixing.
2. [plan.md](plan.md) is the order of work. Phase 2 is what the editor runs now. It still needs a real editing session before phase 3 starts.

We change one phase at a time, and we check it in real editing before starting the next. Neovim 0.12 is the baseline. This config is not trying to load in Vim.
