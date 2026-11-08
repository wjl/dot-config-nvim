-- Change gutter: one column that marks lines differing from the git index.
--
-- The index, not HEAD: a mark means "changed here and not yet staged or
-- committed". `git add` clears it.
--
--   +   added                 ~   changed
--   _   lines deleted below   ‾   lines deleted above
--   ≃   changed, and lines deleted below it
--   ≂   changed, and lines deleted above it
--   ·   edited since the last diff (shown at once, until the diff runs)
--
-- A closed fold shows ~ when anything inside it is marked, or · when
-- something inside is only edited and not yet diffed.
--
-- The column is drawn by 'statuscolumn', between the fold column and the
-- line numbers. It is one cell wide, and only in windows that show a file
-- inside a repository. Signs from anything else (diagnostics) still get
-- the normal sign column, which only appears when there are some.
--
-- The diff is in memory (vim.text.diff with linematch, so a deleted line
-- next to a changed one is told apart) between the buffer and the index
-- copy of the file, so it follows unsaved edits. It runs a short pause
-- after you stop editing, and at least every few seconds while you keep
-- going. The index copy is reloaded when git rewrites the index (a watch
-- on the git directory), after :w, and on focus, at most once per
-- DEADLINE.
--
-- An untracked file is all added. An ignored file, a file outside a
-- repository, and a special buffer get no marks.
--
-- ]c / [c jump to the next / previous change. In diff mode they keep
-- their usual meaning.

local M = {}

local uv = vim.uv
local api = vim.api
-- Marks carry no decoration of their own; the status column reads them.
-- Extmarks move with edits, so marks stay on their lines until the next
-- diff.
local ns = api.nvim_create_namespace('config.gutter')
local ns_pending = api.nvim_create_namespace('config.gutter.pending')

-- Milliseconds. The pause restarts on every edit; the deadline does not.
local PAUSE = 600
local DEADLINE = 4000

local diff = vim.text and vim.text.diff or vim.diff

local symbols = {
	add = { '+', 'GutterAdd' },
	change = { '~', 'GutterChange' },
	below = { '_', 'GutterDelete' },
	above = { '‾', 'GutterDelete' },
	change_below = { '≃', 'GutterChange' },
	change_above = { '≂', 'GutterChange' },
	pending = { '·', 'GutterPending' },
}

-- buf -> { dir, name, gitdir, base, pause, deadline, kinds = {id -> kind} }
--   base: the index text, '' for an untracked file, nil while loading
local bufs = {}
-- gitdir -> { watch, timer, bufs = { [buf] = true } }
local repos = {}

local function redraw(buf)
	if not pcall(api.nvim__redraw, { buf = buf, statuscolumn = true }) then
		vim.cmd('redraw')
	end
end

local function clear(buf)
	if api.nvim_buf_is_valid(buf) then
		api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		api.nvim_buf_clear_namespace(buf, ns_pending, 0, -1)
		redraw(buf)
	end
end

-- Per line: what happened to it (add / change) and whether lines were
-- deleted just above or below it.
local function classify(hunks, count)
	local rows = {}
	local function at(line)
		local r = rows[line]
		if not r then
			r = {}
			rows[line] = r
		end
		return r
	end
	for _, h in ipairs(hunks) do
		local old_n, new_start, new_n = h[2], h[3], h[4]
		if old_n == 0 then
			for l = new_start, new_start + new_n - 1 do
				at(l).kind = 'add'
			end
		elseif new_n == 0 then
			-- Deleted after line new_start; before line 1 when it is 0.
			if new_start == 0 then
				at(1).above = true
			else
				at(math.min(new_start, count)).below = true
			end
		else
			local both = math.min(old_n, new_n)
			for l = new_start, new_start + both - 1 do
				at(l).kind = 'change'
			end
			for l = new_start + both, new_start + new_n - 1 do
				at(l).kind = 'add'
			end
			if old_n > new_n then
				at(new_start + both - 1).below = true
			end
		end
	end
	local kinds = {}
	for line, r in pairs(rows) do
		if line >= 1 and line <= math.max(count, 1) then
			local deleted = r.below and 'below' or (r.above and 'above' or nil)
			if r.kind and deleted then
				kinds[line] = 'change_' .. deleted
			else
				kinds[line] = r.kind or deleted
			end
		end
	end
	return kinds
end

local function render(buf)
	local st = bufs[buf]
	if not st or not st.base or not api.nvim_buf_is_loaded(buf) then
		return
	end
	local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
	local text = #lines > 0 and table.concat(lines, '\n') .. '\n' or ''
	local base = st.base
	if vim.bo[buf].fileformat == 'dos' then
		base = base:gsub('\r\n', '\n')
	end
	-- The last line's newline is a property of the file, not a change.
	if base ~= '' and base:sub(-1) ~= '\n' then
		base = base .. '\n'
	end
	if text == '\n' and base == '' then
		text = ''
	end

	local ok, hunks = pcall(diff, base, text, {
		result_type = 'indices',
		algorithm = 'histogram',
		linematch = 60,
	})
	api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	api.nvim_buf_clear_namespace(buf, ns_pending, 0, -1)
	st.kinds = {}
	if ok then
		for line, kind in pairs(classify(hunks, #lines)) do
			local id = api.nvim_buf_set_extmark(buf, ns, line - 1, 0, {})
			st.kinds[id] = kind
		end
	end
	redraw(buf)
end

local function stop_timers(st)
	st.pause:stop()
	st.deadline:stop()
end

-- An edit: the diff runs after the pause, or by the deadline.
local function edited(buf)
	local st = bufs[buf]
	if not st then
		return
	end
	local function fire()
		stop_timers(st)
		vim.schedule(function()
			if bufs[buf] == st then
				render(buf)
			end
		end)
	end
	st.pause:stop()
	st.pause:start(PAUSE, 0, fire)
	if not st.deadline:is_active() then
		st.deadline:start(DEADLINE, 0, fire)
	end
end

local function git(st, args, on_exit)
	local cmd = { 'git', '-C', st.dir }
	vim.list_extend(cmd, args)
	local ok = pcall(vim.system, cmd, { text = false }, function(res)
		vim.schedule(function()
			on_exit(res)
		end)
	end)
	if not ok then
		on_exit({ code = -1, stdout = '' })
	end
end

-- Fetch the index copy, then diff.
local function load_base(buf)
	local st = bufs[buf]
	if not st or not st.gitdir then
		return
	end
	git(st, { 'cat-file', '--filters', ':./' .. st.name }, function(res)
		if bufs[buf] ~= st then
			return
		end
		if res.code == 0 then
			st.base = res.stdout or ''
			render(buf)
			return
		end
		-- Not in the index: untracked (all added) unless git ignores it.
		git(st, { 'check-ignore', '-q', '--', st.name }, function(ig)
			if bufs[buf] ~= st then
				return
			end
			if ig.code == 1 then
				st.base = ''
				render(buf)
			else
				st.base = nil
				clear(buf)
			end
		end)
	end)
end

local function unwatch(gitdir)
	local repo = repos[gitdir]
	if repo and next(repo.bufs) == nil then
		if repo.watch then
			repo.watch:stop()
			repo.watch:close()
		end
		repo.timer:stop()
		repo.timer:close()
		repos[gitdir] = nil
	end
end

local function reload_repo(gitdir)
	local repo = repos[gitdir]
	if repo then
		for b in pairs(repo.bufs) do
			load_base(b)
		end
	end
end

local function reload_all()
	for gitdir in pairs(repos) do
		reload_repo(gitdir)
	end
end

-- git rewrites the index by renaming index.lock over it, so watch the
-- directory, not the file.
local function watch(gitdir, buf)
	local repo = repos[gitdir]
	if not repo then
		repo = { bufs = {}, timer = uv.new_timer() }
		repos[gitdir] = repo
		local w = uv.new_fs_event()
		if
			w
			and w:start(gitdir, {}, function(_, file)
				if file == 'index' or file == 'HEAD' then
					repo.timer:stop()
					repo.timer:start(100, 0, function()
						vim.schedule(function()
							reload_repo(gitdir)
						end)
					end)
				end
			end)
		then
			repo.watch = w
		elseif w then
			w:close()
		end
	end
	repo.bufs[buf] = true
end

local function detach(buf)
	local st = bufs[buf]
	if not st then
		return
	end
	bufs[buf] = nil
	stop_timers(st)
	st.pause:close()
	st.deadline:close()
	if st.gitdir and repos[st.gitdir] then
		repos[st.gitdir].bufs[buf] = nil
		unwatch(st.gitdir)
	end
	clear(buf)
end

local function attach(buf)
	detach(buf)
	if not api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then
		return
	end
	local name = api.nvim_buf_get_name(buf)
	if name == '' or name:match('^%a[%w+.-]*://') then
		return
	end
	local path = uv.fs_realpath(name) or vim.fn.fnamemodify(name, ':p')
	local dir = vim.fs.dirname(path)
	if not uv.fs_stat(dir) then
		return
	end

	local st = {
		dir = dir,
		name = vim.fs.basename(path),
		pause = uv.new_timer(),
		deadline = uv.new_timer(),
		kinds = {},
	}
	bufs[buf] = st
	git(st, { 'rev-parse', '--absolute-git-dir' }, function(res)
		if bufs[buf] ~= st then
			return
		end
		if res.code ~= 0 then
			detach(buf)
			return
		end
		st.gitdir = vim.trim(res.stdout or '')
		watch(st.gitdir, buf)
		load_base(buf)
	end)

	api.nvim_buf_attach(buf, false, {
		on_lines = function(_, b, _, first, _, new_last)
			if bufs[b] ~= st then
				return true
			end
			edited(b)
			if not st.base then
				return
			end
			-- A deletion marks the line that now sits where it was.
			local last = math.max(new_last, first + 1)
			vim.schedule(function()
				if bufs[b] ~= st or not api.nvim_buf_is_loaded(b) then
					return
				end
				local count = api.nvim_buf_line_count(b)
				for row = first, math.min(last, count) - 1 do
					api.nvim_buf_set_extmark(b, ns_pending, row, 0, {})
				end
				redraw(b)
			end)
		end,
		on_reload = function(_, b)
			if bufs[b] == st then
				edited(b)
			end
		end,
		on_detach = function(_, b)
			if bufs[b] == st then
				detach(b)
			end
		end,
	})
end

local function cell(sym)
	local s = symbols[sym]
	return '%#' .. s[2] .. '#' .. s[1] .. '%*'
end

-- The gutter cell for v:lnum in the window being drawn.
function M.column()
	local win = vim.g.statusline_winid or api.nvim_get_current_win()
	local buf = api.nvim_win_get_buf(win)
	local st = bufs[buf]
	if not st or not st.gitdir then
		return ''
	end
	if vim.v.virtnum ~= 0 then
		return ' '
	end
	local lnum = vim.v.lnum
	local row = lnum - 1
	local fold_end = api.nvim_win_call(win, function()
		return vim.fn.foldclosedend(lnum)
	end)
	if fold_end ~= -1 then
		if #api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { fold_end - 1, -1 }, { limit = 1 }) > 0 then
			return cell('change')
		end
		if #api.nvim_buf_get_extmarks(buf, ns_pending, { row, 0 }, { fold_end - 1, -1 }, { limit = 1 }) > 0 then
			return cell('pending')
		end
		return ' '
	end
	if #api.nvim_buf_get_extmarks(buf, ns_pending, { row, 0 }, { row, -1 }, { limit = 1 }) > 0 then
		return cell('pending')
	end
	local mark = api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, { limit = 1 })[1]
	local kind = mark and st.kinds[mark[1]]
	return kind and cell(kind) or ' '
end

-- Start of the change after (dir 1) / before (dir -1) the cursor.
local function jump(dir)
	local buf = api.nvim_get_current_buf()
	local rows = {}
	for _, m in ipairs(api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})) do
		rows[m[2]] = true
	end
	local starts = {}
	for row in pairs(rows) do
		if not rows[row - 1] then
			starts[#starts + 1] = row
		end
	end
	table.sort(starts)
	local cur = api.nvim_win_get_cursor(0)[1] - 1
	local target
	if dir > 0 then
		for _, r in ipairs(starts) do
			if r > cur then
				target = r
				break
			end
		end
	else
		for i = #starts, 1, -1 do
			if starts[i] < cur then
				target = starts[i]
				break
			end
		end
	end
	if target then
		vim.cmd("normal! m'")
		api.nvim_win_set_cursor(0, { target + 1, 0 })
	end
end

function M.highlights()
	local set = api.nvim_set_hl
	set(0, 'GutterAdd', { link = 'DiffAdd', default = true })
	set(0, 'GutterChange', { link = 'DiffChange', default = true })
	set(0, 'GutterDelete', { link = 'DiffDelete', default = true })
	set(0, 'GutterPending', { link = 'LineNr', default = true })
end

function M.setup()
	M.highlights()
	-- Fold column, other signs, our cell, line number. Without our cell
	-- this is what Neovim draws by default.
	_G.Config.gutter = M.column
	vim.o.statuscolumn = '%C%s%{%v:lua.Config.gutter()%}%l '

	local group = api.nvim_create_augroup('config.gutter', { clear = true })

	api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'BufFilePost' }, {
		group = group,
		callback = function(ev)
			attach(ev.buf)
		end,
	})
	-- After :w, a new file may now exist in the directory git looks at.
	api.nvim_create_autocmd('BufWritePost', {
		group = group,
		callback = function(ev)
			if bufs[ev.buf] then
				load_base(ev.buf)
			else
				attach(ev.buf)
			end
		end,
	})
	api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
		group = group,
		callback = function(ev)
			detach(ev.buf)
		end,
	})

	-- The watch catches git in another terminal. Focus is the fallback for
	-- filesystems that do not report changes. At most once per DEADLINE:
	-- the first focus reloads at once, and focus again inside the window
	-- reloads once when it ends.
	local focus = uv.new_timer()
	local last = 0
	api.nvim_create_autocmd('FocusGained', {
		group = group,
		callback = function()
			if focus:is_active() then
				return
			end
			local wait = last + DEADLINE - uv.now()
			if wait <= 0 then
				last = uv.now()
				reload_all()
				return
			end
			focus:start(wait, 0, function()
				vim.schedule(function()
					last = uv.now()
					reload_all()
				end)
			end)
		end,
	})

	for _, key in ipairs({ { ']c', 1 }, { '[c', -1 } }) do
		vim.keymap.set('n', key[1], function()
			if vim.wo.diff then
				vim.cmd('normal! ' .. vim.v.count1 .. key[1])
			else
				for _ = 1, vim.v.count1 do
					jump(key[2])
				end
			end
		end, { desc = key[2] > 0 and 'Next change' or 'Previous change' })
	end

	-- Buffers already loaded when this runs.
	for _, b in ipairs(api.nvim_list_bufs()) do
		if api.nvim_buf_is_loaded(b) then
			attach(b)
		end
	end
end

return M
