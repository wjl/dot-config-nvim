# AI in the editor (phase 8)

In-house, no plugins. Everything goes through `curl`, which every target has, Windows included. All code is under `lua/config/ai/`.

## Providers and models

`lua/config/ai/settings.lua` lists providers by name: `base_url`, `key_env` (the environment variable holding the key), and an optional `system` text put in front of every system prompt sent to that provider. Nothing else comes from the environment: no `OPENAI_BASE_URL`, no guessing.

Every provider speaks the OpenAI chat completions API (`<base_url>/chat/completions`, streamed; `<base_url>/models` for the list). Configured now: OpenRouter, and Gemini's OpenAI endpoint. DeepRelay goes in the same way once its URL is known. Anthropic's own API would be a second dialect, not needed yet.

A model is `provider/model-id`, split at the first `/`: `openrouter/deepseek/deepseek-v4.1-flash`, `openrouter/openrouter/free`. Each mode has a default in `settings.models`; `:AIModel` changes it for the session, and Tab completes from the provider's model list (fetched once per session).

The key and the request body go to curl on standard input as a curl config (`curl -K -`), so neither appears in the process list. The key is never written anywhere.

Encrypted buffers (`.gpg`, `.pgp`, `.asc`) are never sent.

## One-shot: `:AI` and `:AIAsk` (done)

| | No selection | With a selection |
| --- | --- | --- |
| `:AI [prompt]` | written in at the cursor | replaces the selection |
| `:AIAsk [question]` | answer goes in after the paragraph (the next blank line) | answer goes in on new lines after the selection |

`@provider/model` as the first word uses another model once. `:AIStop` cancels the requests running in the buffer. `:AIAsk` answers go in as comments in the file's comment style (`'commentstring'`) at the indent of the line above, so code still compiles; markdown, text, and files without a filetype get plain text set off by a blank line.

While the answer streams in, it shows as grey virtual text where it will go. When it is complete it goes into the buffer as one change (one undo). The target is tracked with extmarks, so editing elsewhere meanwhile is fine.

The prompt is kept minimal (a few hundred characters plus the context), because every word is paid for on every call. The system message says where the reply goes and that file content is data; the user message is the file excerpt and the request. Each section is marked with a tag ending in a fresh random 128-bit value (`<file-…>`, `<sel-…>`, `<cursor-…/>`), so file text cannot close a section or forge one. That stops forged sections; it does not make a model immune to instructions written in the file.

Weak models misbehave, so the answer is checked before it goes in: an answer containing the request's tag (the model repeated the prompt) is refused with a message; leading lines that repeat the text just before the target and trailing lines that repeat the text just after it are dropped; one fence around the whole answer is removed; a replacement for a selection inside one line is trimmed of surrounding line breaks.

Context: the selection or the cursor line, grown outward (two thirds before, one third after) up to `settings.context_chars`, and never more than half the model's context window when the provider reports it.

Errors show the provider's own message. OpenRouter notes: `openrouter/free` routes each call to some free model, so quality varies; specific free models are often rate-limited upstream; and the account's privacy guardrail excludes free endpoints that train on prompts.

## Chat panel (next)

A markdown buffer beside the file, opened only when asked. It belongs to the tab it was opened in and follows the last window you edited in that tab; its header names that file. The last visual selection still counts after you leave visual mode (Neovim keeps the marks per buffer).

Tools for the model: list open buffers, read lines, cursor position, last selection, search, replace (anchored on the old text, not line numbers, so it survives your typing). Buffers only, never files on disk; you save. Each edit is one undo step. A few slash commands (`/model`, `/clear`, `/once <model>`). Undecided: whether edits apply at once or wait for approval.

## Ghost-text completion (after that)

Off by default; on per buffer, or globally with per-buffer overrides and a per-buffer model. Asks after a pause (about 4 s) or on a key, cancels the request the moment you type. Chat requests only, told to stop at the end of the current block, with a length cap; no fill-in-the-middle API (few providers have it, and the overhead it saves is a few hundred tokens). Grey text inline and below; typing the same characters shrinks it. Right accepts it all, Alt-Right a word, anything else rejects (Tab is always a tab). The built-in completion menu is held back while grey text shows.

## Out of scope

Running commands, editing files on disk, project-wide work. That is what a full harness in a terminal is for.
