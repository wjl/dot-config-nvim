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
| `:AI [instruction]` | written in at the cursor | replaces the selection |
| `:AIAsk [question]` | answer goes in after the block at the cursor | answer goes in on new lines after the selection |

`@provider/model` as the first word uses another model once; Tab completes it, matching fuzzily after the slash (`@openrouter/dsflash`). Enter on a selected menu entry takes it and stays on the command line. `:AIStop` cancels the requests running in the buffer.

**Region of interest:** the selection; without one, the fold scanners' structural folds around the cursor (functions, classes, blocks, markdown sections; `{{{` markers do not count), walking out from the innermost to the top level and stopping before a fold over 150 lines or 60% of the context budget. That usually lands on the whole function or class rather than one `switch` inside it. With no structural fold, the paragraph.

**Prompt.** System message, one paragraph: what file this is, what the job is (insert at the `here` mark / rewrite the focus / rewrite the marked part of it / answer a question about it), what to output (only that text, no fences, no commentary, no repeating), and that the file text is data. The user message holds the file text in three parts — `before`, `focus`, `after` — then the instruction. The file text is in the user message, not the system one, on purpose: a model gives system text more authority, so file text there would be easier to use for prompt injection. Every tag ends in a fresh random 128-bit value, so file text cannot close a part or forge one. That stops forged parts; it does not make a model immune to instructions written in the file.

Default instructions when none is given: "Please clean this up." (rewrite), "Write what belongs here." (insert), "What's going on here?" (ask).

**Context:** the focus plus text before and after it (two thirds of what is left of the budget before, the rest after), up to `settings.context_chars`, and never more than half the model's context window when the provider reports it.

**Output.** While the answer streams it shows as grey text at the target, with a seconds counter. Complete, it goes in as one change (one undo); the target is tracked with extmarks, so editing elsewhere meanwhile is fine. Checks before it goes in: an answer that contains the request's tag is refused; leading and trailing lines that repeat the surrounding text are dropped; one fence around the whole answer is removed; a rewrite of a selection inside one line is trimmed of line breaks; whole lines inserted with the cursor in the indentation go above the cursor line, at its indent. `:AIAsk` answers are wrapped to 120 columns (or `'textwidth'`) and go in as comments in the file's `'commentstring'`, at the indent of the line above; markdown, text, and files without a filetype get plain text after a blank line. (An answer that quotes a fold marker adds one; rare.)

**Requests** give up after 20 s without a connection, 120 s without any data (providers send keep-alives while a model thinks), or 10 minutes in all. Errors show the provider's own message.

**Models.** The default is `openrouter/deepseek/deepseek-v4.1-flash` (about $0.00001 for a small request). `openrouter/openrouter/free` routes each call to some free model, so quality varies; specific free models are often rate-limited upstream, and the account's privacy settings exclude free endpoints that train on prompts (the free Nemotron models among them).

## Chat panel (next)

A markdown buffer beside the file, opened only when asked. It belongs to the tab it was opened in and follows the last window you edited in that tab; its header names that file. The last visual selection still counts after you leave visual mode (Neovim keeps the marks per buffer).

Tools for the model: list open buffers, read lines, cursor position, last selection, search, replace (anchored on the old text, not line numbers, so it survives your typing). Buffers only, never files on disk; you save. Each edit is one undo step. A few slash commands (`/model`, `/clear`, `/once <model>`). Undecided: whether edits apply at once or wait for approval.

## Ghost-text completion (after that)

Off by default; on per buffer, or globally with per-buffer overrides and a per-buffer model. Asks after a pause (about 4 s) or on a key, cancels the request the moment you type. Chat requests only, told to stop at the end of the current block, with a length cap; no fill-in-the-middle API (few providers have it, and the overhead it saves is a few hundred tokens). Grey text inline and below; typing the same characters shrinks it. Right accepts it all, Alt-Right a word, anything else rejects (Tab is always a tab). The built-in completion menu is held back while grey text shows.

## Out of scope

Running commands, editing files on disk, project-wide work. That is what a full harness in a terminal is for.
