# AI in the editor (phase 8)

In-house, no plugins. Everything goes through `curl`, which every target has, Windows included. All code is under `lua/config/ai/`.

## Providers and models

`lua/config/ai/settings.lua` lists providers by name: `base_url`, `key_env` (the environment variable holding the key), and an optional `system` text put in front of every system prompt sent to that provider. Nothing else comes from the environment: no `OPENAI_BASE_URL`, no guessing.

Every provider speaks the OpenAI chat completions API (`<base_url>/chat/completions`, streamed; `<base_url>/models` for the list). Configured now: OpenRouter, and Gemini's OpenAI endpoint. DeepRelay goes in the same way once its URL is known. Anthropic's own API would be a second dialect, not needed yet.

A model is `provider/model-id`, split at the first `/`: `openrouter/deepseek/deepseek-v4.1-flash`, `openrouter/openrouter/free`. Each mode has a default in `settings.models`; `:AIModel` changes it for the session, and Tab completes from the provider's model list (fetched once per session).

The key and the request body go to curl on standard input as a curl config (`curl -K -`), so neither appears in the process list. The key is never written anywhere.

Encrypted buffers (`.gpg`, `.pgp`, `.asc`) are never sent.

## One-shot: `:AI` (done)

`:AI [prompt]` asks about the code around the cursor; `:'<,'>AI [prompt]` about the selection; `:AI @provider/model …` uses another model once.

The request is a system message (the provider's `system`, then the assignment) and a user message with the context and the request. Each section is marked with tags that end in a fresh random 128-bit value (`<context-…>`, `<request-…>`, `<cursor-…/>`), so text from the file cannot close a section or forge one. The system prompt says the context is data, not instructions. That stops forged sections; it does not make a model immune to instructions written in the file, which is one reason `:AI` never edits by itself.

Context: the selection, or lines around the cursor (two thirds before, one third after) with a cursor marker, up to `settings.context_chars` and never more than half the model's context window when the provider reports it.

The answer streams into a window beside the file (models that think show `thinking…` until text arrives). `a` applies it: it replaces the selection, or goes below the cursor line; a single fenced code block applies only the code. One undo reverts it. `y` copies, `q` closes and cancels.

## Chat panel (next)

A markdown buffer beside the file, opened only when asked. It belongs to the tab it was opened in and follows the last window you edited in that tab; its header names that file. The last visual selection still counts after you leave visual mode (Neovim keeps the marks per buffer).

Tools for the model: list open buffers, read lines, cursor position, last selection, search, replace (anchored on the old text, not line numbers, so it survives your typing). Buffers only, never files on disk; you save. Each edit is one undo step. A few slash commands (`/model`, `/clear`, `/once <model>`). Undecided: whether edits apply at once or wait for approval.

## Ghost-text completion (after that)

Off by default; on per buffer, or globally with per-buffer overrides and a per-buffer model. Asks after a pause (about 4 s) or on a key, cancels the request the moment you type. Chat requests only, told to stop at the end of the current block, with a length cap; no fill-in-the-middle API (few providers have it, and the overhead it saves is a few hundred tokens). Grey text inline and below; typing the same characters shrinks it. Right accepts it all, Alt-Right a word, anything else rejects (Tab is always a tab). The built-in completion menu is held back while grey text shows.

## Out of scope

Running commands, editing files on disk, project-wide work. That is what a full harness in a terminal is for.
