-- Change gutter: signs for lines that differ from the git index.
--
-- The index, not HEAD: a sign means "changed here and not yet staged or
-- committed". `git add` clears a line's sign.
--
--   +   added            ~   changed
--   _   deleted below    ‾   deleted above line 1
--   ~_  changed, and lines deleted below it
--   ·   edited since the last diff (shown at once, until the diff runs)
--
-- The diff is in memory (vim.text.diff) between the buffer and the index
-- copy of the file, so it follows unsaved edits. It runs a short pause
-- after you stop editing, and at least every few seconds while you keep
-- going. The index copy is reloaded when git rewrites the index (a watch
-- on the git directory) and when Neovim regains focus.
--
-- An untracked file is all added. An ignored file, a file outside a
-- repository, and a special buffer get no signs.
--
-- ]c / [c jump to the next / previous change. In diff mode they keep
-- their usual meaning.

local M = {}

local uv = vim.uv
local ns = vim.api.nvim_create_namespace('config.gutter')
local ns_pending = vim.api.nvim_create_namespace('config.gutter.pending')

-- Milliseconds. The pause restarts on every edit; the deadline does not.
local PAUSE = 600
local DEADLINE = 4000

local diff = vim.text and vim.text.diff or vim.diff

-- buf -> { dir, name, gitdir, base, tick, pause, deadline, pending }
--   base: the index text, '' for an untracked file, nil while loading
local bufs = {}
-- gitdir -> { watch, timer, bufs = { [buf] = true } }
local repos = {}

local signs = {
	add = { '+', 'GutterAdd' },
	change = { '~', 'GutterChange' },
	delete = { '_', 'GutterDelete' },
	topdelete = { '‾', 'GutterDelete' },
	changedelete = { '~_', 'GutterChange' },
	pending = { '·', 'GutterPending' },
}

local function place(buf, space, row, kind, priority)
	local s = signs[kind]
	pcall(vim.api.nvim_buf_set_extmark, buf, space, row, 0, {
		sign_text = s[1],
		sign_hl_group = s[2],
		priority = priority,
	})
end

local function clear(buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		vim.api.nvim_buf_clear_namespace(buf, ns_pending, 0, -1)
	end
end

local function render(buf)
	local st = bufs[buf]
	if not st or not st.base or not vim.api.nvim_buf_is_loaded(buf) then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
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

	local ok, hunks = pcall(diff, base, text, { result_type = 'indices', algorithm = 'histogram' })
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	vim.api.nvim_buf_clear_namespace(buf, ns_pending, 0, -1)
	st.pending = false
	if not ok then
		return
	end
	local count = #lines
	for _, h in ipairs(hunks) do
		local _, old_n, new_start, new_n = h[1], h[2], h[3], h[4]
		if old_n == 0 then
			for l = new_start, new_start + new_n - 1 do
				place(buf, ns, l - 1, 'add', 10)
			end
		elseif new_n == 0 then
			if new_start == 0 then
				place(buf, ns, 0, 'topdelete', 10)
			else
				place(buf, ns, math.min(new_start, count) - 1, 'delete', 10)
			end
		else
			local both = math.min(old_n, new_n)
			for l = new_start, new_start + both - 1 do
				local kind = (l == new_start + both - 1 and old_n > new_n) and 'changedelete' or 'change'
				place(buf, ns, l - 1, kind, 10)
			end
			for l = new_start + both, new_start + new_n - 1 do
				place(buf, ns, l - 1, 'add', 10)
			end
		end
	end
end

local function stop_timers(st)
	st.pause:stop()
	st.deadline:stop()
end

-- An edit: mark it now, diff after the pause or by the deadline.
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
	if not st then
		return
	end
	local spec = ':./' .. st.name
	git(st, { 'cat-file', '--filters', spec }, function(res)
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

-- git rewrites the index by renaming index.lock over it, so watch the
-- directory, not the file.
local function watch(gitdir, buf)
	local repo = repos[gitdir]
	if not repo then
		repo = { bufs = {}, timer = uv.new_timer() }
		repos[gitdir] = repo
		local w = uv.new_fs_event()
		if w and w:start(gitdir, {}, function(_, file)
			if file == 'index' or file == 'HEAD' then
				repo.timer:stop()
				repo.timer:start(100, 0, function()
					vim.schedule(function()
						reload_repo(gitdir)
					end)
				end)
			end
		end) then
			repo.watch = w
		elseif w then
			w:close()
		end
	end
	repo.bufs[buf] = true
end

local function show_column(buf)
	local on = bufs[buf] ~= nil
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.wo[win][0].signcolumn = on and 'yes' or 'auto'
	end
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
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then
		return
	end
	local name = vim.api.nvim_buf_get_name(buf)
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
	}
	bufs[buf] = st
	git(st, { 'rev-parse', '--absolute-git-dir' }, function(res)
		if bufs[buf] ~= st then
			return
		end
		if res.code ~= 0 then
			detach(buf)
			show_column(buf)
			return
		end
		st.gitdir = vim.trim(res.stdout or '')
		watch(st.gitdir, buf)
		show_column(buf)
		load_base(buf)
	end)

	vim.api.nvim_buf_attach(buf, false, {
		on_lines = function(_, b, _, first, _, new_last)
			local cur = bufs[b]
			if cur ~= st then
				return true
			end
			edited(b)
			if not cur.base then
				return
			end
			vim.schedule(function()
				if bufs[b] ~= st or not vim.api.nvim_buf_is_loaded(b) then
					return
				end
				local last = math.max(new_last, first + 1)
				local count = vim.api.nvim_buf_line_count(b)
				for row = first, math.min(last, count) - 1 do
					place(b, ns_pending, row, 'pending', 20)
				end
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

-- Start of the change at or after (dir 1) / before (dir -1) the cursor.
local function jump(dir)
	local buf = vim.api.nvim_get_current_buf()
	local rows = {}
	for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})) do
		rows[m[2]] = true
	end
	local starts = {}
	for row in pairs(rows) do
		if not rows[row - 1] then
			starts[#starts + 1] = row
		end
	end
	table.sort(starts)
	local cur = vim.api.nvim_win_get_cursor(0)[1] - 1
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
		vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
	end
end

function M.highlights()
	local set = vim.api.nvim_set_hl
	set(0, 'GutterAdd', { link = 'DiffAdd', default = true })
	set(0, 'GutterChange', { link = 'DiffChange', default = true })
	set(0, 'GutterDelete', { link = 'DiffDelete', default = true })
	set(0, 'GutterPending', { link = 'LineNr', default = true })
end

function M.setup()
	M.highlights()
	local group = vim.api.nvim_create_augroup('config.gutter', { clear = true })

	vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'BufFilePost' }, {
		group = group,
		callback = function(ev)
			attach(ev.buf)
		end,
	})
	-- After :w, a new file may now exist in the directory git looks at.
	vim.api.nvim_create_autocmd('BufWritePost', {
		group = group,
		callback = function(ev)
			if bufs[ev.buf] then
				load_base(ev.buf)
			else
				attach(ev.buf)
			end
		end,
	})
	vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
		group = group,
		callback = function(ev)
			detach(ev.buf)
		end,
	})
	vim.api.nvim_create_autocmd('BufWinEnter', {
		group = group,
		callback = function(ev)
			show_column(ev.buf)
		end,
	})
	vim.api.nvim_create_autocmd('FocusGained', {
		group = group,
		callback = function()
			for gitdir in pairs(repos) do
				reload_repo(gitdir)
			end
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
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(b) then
			attach(b)
		end
	end
end

return M
