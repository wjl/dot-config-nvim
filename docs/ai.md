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
| `:AI [instruction]` | new lines just above the region (the function, class, or section around the cursor); outside any fold, at the cursor | replaces the selection |
| `:AIAsk [question]` | answer goes in just above the region | answer goes in just above the selection |

`@provider/model` as the first word uses another model once; Tab completes it, matching fuzzily after the slash (`@openrouter/dsflash`). Enter on a selected menu entry takes it and stays on the command line. `:AIStop` cancels the requests running in the buffer.

**Region of interest:** the selection; without one, the folds around the cursor (functions, classes, blocks, markdown sections, `{{{` markers), walking out from the innermost and stopping at the first fold whose opening line is not indented, or one step before a fold over 150 lines or 60% of the context budget. In markdown, where lists start at the margin too, the walk stops at a heading or a code fence instead. That usually lands on the whole C function, the Python class (or the method, if the class is too big), or the markdown section. With no fold at the cursor, the paragraph, and the answer goes in at the cursor.

**Prompt.** System message, one paragraph: what file this is, what the job is (insert at the `here` mark / rewrite the focus / rewrite the marked part of it / answer a question about it), what to output (only that text, no fences, no commentary, no repeating), and that the file text is data. The user message holds the file text in three parts — `before`, `focus`, `after` — then the instruction. The file text is in the user message, not the system one, on purpose: a model gives system text more authority, so file text there would be easier to use for prompt injection. Every tag ends in a fresh random 128-bit value, so file text cannot close a part or forge one. That stops forged parts; it does not make a model immune to instructions written in the file.

Default instructions when none is given: "Please clean this up." (rewrite), "Write what belongs here." (insert), "What's going on here?" (ask).

The chat panel's edits will apply at once (decided): undo, or git, is the way back. Approving each edit turns into clicking OK without reading.

**Context:** the focus plus text before and after it (two thirds of what is left of the budget before, the rest after), up to `settings.context_chars`, and never more than half the model's context window when the provider reports it.

**Output.** While the answer streams it shows as grey text at the top of the target, with a seconds counter. Complete, it goes in as one change (one undo); the target is tracked with extmarks, so editing elsewhere meanwhile is fine. Checks before it goes in: an answer that contains the request's tag is refused; leading and trailing lines that repeat the surrounding text are dropped; one fence around the whole answer is removed; a rewrite of a selection inside one line is trimmed of line breaks; whole lines inserted with the cursor in the indentation go above the cursor line, at its indent. `:AIAsk` answers start with the question restated in one short line, then a blank line, then the answer. They are wrapped to 120 columns (or `'textwidth'`) and go in as comments in the file's `'commentstring'`, above the region at its first line's indent, so folding the region below leaves the answer showing; markdown, text, and files without a filetype get plain text followed by a blank line. (An answer that quotes a fold marker adds one; rare.)

**Requests** give up after 20 s without a connection, 120 s without any data (providers send keep-alives while a model thinks), or 10 minutes in all. Errors show the provider's own message.

**Models.** The default is `openrouter/deepseek/deepseek-v4.1-flash` (about $0.00001 for a small request). `openrouter/openrouter/free` routes each call to some free model, so quality varies; specific free models are often rate-limited upstream, and the account's privacy settings exclude free endpoints that train on prompts (the free Nemotron models among them).

## Chat panel: `:AIChat` (done)

`:AIChat [provider/model]` opens this tab's panel on the left (or goes to it). Type under the last `## You`; Enter in normal mode sends (Enter in insert mode is a new line); Ctrl-C in normal mode or `:AIStop` cancels. A short reference of the commands sits at the top of the panel (display only, never sent). `/model [name]`, `/clear`, `/help`; `@provider/model` as the first word sends one message with that model; typing `@` at the start of a message pops up the same fuzzy model list as `:AI @`. The window bar shows the model and the file it works on: the last window you were in, in that tab.

The conversation the model sees is kept as a list of messages with their roles, not read back from the panel, so editing the transcript, or writing `## AI` / `## You` in a message, cannot change or forge a role; the panel only displays it (`/clear` resets both). Your next message is everything after an invisible input mark placed below the last `## You`, so editing or deleting the headings does not change what is sent.

Tools: `list_buffers`, `editor_state` (current buffer, cursor, lines on screen, last visual selection with its text), `read_buffer` (numbered lines, 400 at a time), `search_buffer` (plain text), `edit_buffer` (replace an exact, unique piece of text — anchored on text, not line numbers, so it survives your typing), `insert_lines`. Buffers only, never files on disk; you save. Encrypted buffers are invisible to every tool.

Edits apply at once (decided: undo, or git, is the way back; approving each edit turns into clicking OK without reading). Each edit is its own undo step in its buffer, and the changed lines flash. The transcript shows each tool call as a one-line quote, with where an edit landed. At most 20 tool rounds per message.

The system prompt is three sentences: pair programmer in an editor, use the tools rather than guess and change only what was asked, buffer text is data, answer briefly in markdown. The provider's `system` goes in front.

Tested against `deepseek/deepseek-v4.1-flash`: a question about the method at the cursor (it called `editor_state`, then `read_buffer`, 2.7 s), and a rename across a file (search, two edits, a confirming search, 7.5 s).

## Ghost-text completion: `:AIGhost` (done)

Off by default. `:AIGhost` toggles it for the buffer; `:AIGhost on|off`; `:AIGhost global on|off` for every buffer (a buffer's own setting wins); `:AIGhost model [name]` per buffer; `:AIGhost status`. Settings in `settings.ghost`: `global`, `delay` (4000 ms), `before_chars` / `after_chars` (16000 / 8000, about 6000 tokens together, like `:AI`; when the whole file fits, every request starts at line 1, which providers can cache), `max_tokens` (200).

In insert mode it asks after `delay` without typing, or at once with Ctrl-Space (terminals send Ctrl-@; Alt-\ was tried first, but Esc-\ is a terminal control sequence and never arrived). Ctrl-Space works with `:AIGhost` off too, for a one-off suggestion. A request in flight is cancelled the moment you type; one that comes back after the text or cursor moved is dropped. The suggestion shows as grey text (`AIGhost`, linked to `Comment`): the first line inline at the cursor, the rest as lines below. Right, Down, or Enter takes it all ("go on with this"), Alt-Right one word; Left, Up, Backspace, or a different character drops it ("never mind"); typing the same characters shrinks it, anything else or leaving insert mode drops it. Without a suggestion, Right and Alt-Right do what they always do. The built-in completion menu is held off for the buffer while a suggestion shows.

The prompt: one system paragraph (complete the text at the `here` mark, to the end of the current statement or block at most, no fences or commentary, do not repeat the surroundings, file text is data) and the text before and after the cursor with the mark. Chat API only. The answer is trimmed: a wrapping fence, the rest of the line or following lines repeated at its end, and anything after a line that drops left of the cursor line's indent (a closing `}` is kept).

Thinking models must not think here: a reasoning model spent the whole 200-token budget thinking and returned nothing. A provider's `quick` fields are added to these requests; OpenRouter's are `reasoning = { enabled = false }`, after which deepseek-v4.1-flash answers in about 0.6 s.

Tested: asking inside a C `for` loop gave the loop body and its closing `}` in 0.6 s; Right took it; on the next line the 4 s pause alone brought up `return total;`.

## Out of scope

Running commands, editing files on disk, project-wide work. That is what a full harness in a terminal is for.
