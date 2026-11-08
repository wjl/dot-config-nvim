-- Edit OpenPGP-encrypted files: *.gpg, *.pgp, *.asc.
--
-- Reading decrypts into the buffer. Writing encrypts the buffer the same way
-- the file was encrypted: to the same keys, or with a passphrase. A new file
-- asks which, and offers your own key as the recipient.
--
-- Plaintext never touches the disk. It goes to and from gpg over pipes. The
-- buffer has no swap file and no undo file. The ciphertext is written to a
-- new file next to the target and renamed over it, so a failed or
-- interrupted save leaves the old file as it was.
--
-- Passphrases are gpg-agent's business. With a graphical session (or on
-- Windows) the agent's pinentry asks. Without one, a curses pinentry would
-- fight Neovim for the terminal, so Neovim asks instead and hands the
-- passphrase to gpg over a pipe (loopback). It is never stored.
--
-- gpg runs with your normal keyring and gpg.conf. Trust is not overridden:
-- a key gpg does not consider valid is refused, with gpg's reason.
--
-- :GpgInfo        how this buffer will be encrypted
-- :GpgEncryption  choose again: a passphrase, or a list of recipients

local M = {}

local uv = vim.uv
local patterns = { '*.gpg', '*.pgp', '*.asc' }

-- Per-buffer state, keyed by buffer number.
--   plain      the file is not encrypted (a public key, a signature); it is
--              read and written as an ordinary file
--   failed     decryption failed; the buffer is empty and must not be saved
--   symmetric  encrypt with a passphrase
--   recipients key ids or names to encrypt to
--   armor      write ASCII armor
local state = {}

local function program()
	local name = vim.g.gpg_program
	if name then
		return name
	end
	if vim.fn.executable('gpg') == 1 then
		return 'gpg'
	end
	if vim.fn.executable('gpg2') == 1 then
		return 'gpg2'
	end
	return 'gpg'
end

-- True when the agent's pinentry can ask without using our terminal.
local function pinentry_ok()
	if vim.g.gpg_loopback ~= nil then
		return not vim.g.gpg_loopback
	end
	if vim.fn.has('win32') == 1 then
		return true
	end
	local env = vim.env
	return (env.DISPLAY or '') ~= '' or (env.WAYLAND_DISPLAY or '') ~= ''
end

-- Run gpg. input goes to stdin. passphrase, if given, goes over fd 3 with
-- loopback pinentry. mode 'error' makes gpg fail instead of starting a
-- pinentry, so a cached or empty passphrase works and anything else is
-- reported as needing one. Returns { code, out, status = {lines}, messages
-- = {lines} }, or nil and an error.
local function run(args, input, opts)
	opts = opts or {}
	local full = { '--batch', '--no-tty', '--yes', '--status-fd', '2' }
	local pass
	if opts.passphrase then
		pass = uv.new_pipe()
		vim.list_extend(full, { '--pinentry-mode', 'loopback', '--passphrase-fd', '3' })
	elseif opts.mode then
		vim.list_extend(full, { '--pinentry-mode', opts.mode })
	end
	vim.list_extend(full, args)

	local stdin, stdout, stderr = uv.new_pipe(), uv.new_pipe(), uv.new_pipe()
	local out, err = {}, {}
	local code, out_done, err_done
	local pipes = { stdin, stdout, stderr, pass }

	local handle, spawn_err = uv.spawn(program(), {
		args = full,
		stdio = { stdin, stdout, stderr, pass },
		hide = true,
	}, function(c)
		code = c
	end)
	if not handle then
		for _, p in pairs(pipes) do
			p:close()
		end
		return nil, ('cannot run %s: %s'):format(program(), spawn_err)
	end

	stdout:read_start(function(_, data)
		if data then
			out[#out + 1] = data
		else
			out_done = true
		end
	end)
	stderr:read_start(function(_, data)
		if data then
			err[#err + 1] = data
		else
			err_done = true
		end
	end)
	if pass then
		pass:write(opts.passphrase .. '\n')
		pass:shutdown()
	end
	if input then
		stdin:write(input)
	end
	stdin:shutdown()

	-- A pinentry can take as long as you like. Ctrl-C gives up.
	local ok = vim.wait(0x7fffffff, function()
		return code ~= nil and out_done and err_done
	end, 10)
	if not ok then
		handle:kill('sigterm')
		vim.wait(1000, function()
			return code ~= nil
		end, 10)
	end
	for _, p in pairs(pipes) do
		if not p:is_closing() then
			p:close()
		end
	end
	if not handle:is_closing() then
		handle:close()
	end
	if not ok then
		return nil, 'interrupted'
	end

	local status, messages = {}, {}
	for line in table.concat(err):gmatch('[^\n]+') do
		local s = line:match('^%[GNUPG:%] (.*)')
		if s then
			status[#status + 1] = s
		else
			messages[#messages + 1] = line
		end
	end
	return { code = code, out = table.concat(out), status = status, messages = messages }
end

local function has_status(res, pattern)
	for _, s in ipairs(res.status) do
		if s:match(pattern) then
			return true
		end
	end
	return false
end

-- gpg wanted a passphrase and could not get one without asking.
local function needs_passphrase(res)
	return has_status(res, '^ERROR get_passphrase 85') or has_status(res, '^ERROR get_passphrase %d+_No_Pinentry')
end

local function fail(msg, res)
	local lines = { msg }
	if res then
		for _, m in ipairs(res.messages) do
			if not m:match('^gpg: WARNING: ') or #res.messages == 1 then
				lines[#lines + 1] = m
			end
		end
	end
	vim.notify(table.concat(lines, '\n'), vim.log.levels.ERROR)
end

local function ask_secret(prompt)
	local ok, value = pcall(vim.fn.inputsecret, prompt)
	vim.cmd('redraw')
	if not ok or value == '' then
		return nil
	end
	return value
end

-- Bytes to buffer lines. Returns lines, eol, fileformat.
local function decode(data)
	local lines = vim.split(data, '\n', { plain = true })
	local eol = true
	if lines[#lines] == '' then
		lines[#lines] = nil
	else
		eol = false
	end
	local dos = #lines > 0
	for _, l in ipairs(lines) do
		if l:sub(-1) ~= '\r' then
			dos = false
			break
		end
	end
	if dos then
		for i, l in ipairs(lines) do
			lines[i] = l:sub(1, -2)
		end
	end
	return lines, eol, dos and 'dos' or 'unix'
end

local function encode(buf, lines, whole)
	local bo = vim.bo[buf]
	local nl = bo.fileformat == 'dos' and '\r\n' or (bo.fileformat == 'mac' and '\r' or '\n')
	local data = table.concat(lines, nl)
	if #lines > 0 and (not whole or bo.eol or bo.fixeol) then
		data = data .. nl
	end
	return data
end

-- Replace the buffer's text without leaving an undo step back to empty.
local function set_text(buf, lines)
	local bo = vim.bo[buf]
	local ul = bo.undolevels
	bo.undolevels = -1
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	bo.undolevels = ul
end

local function read_file(path)
	local fd = uv.fs_open(path, 'r', 0)
	if not fd then
		return nil
	end
	local stat = uv.fs_fstat(fd)
	local data = stat and uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	return data
end

-- Write data over path without ever leaving it missing or half written:
-- write a new file in the same directory, flush it, then rename it over.
-- A symlink is followed, so the link stays a link. The old file's
-- permissions are kept; a new file is private.
local function replace_file(path, data)
	local real = uv.fs_realpath(path) or path
	local old = uv.fs_stat(real)
	local mode = old and old.mode % 0x1000 or tonumber('600', 8)
	local dir, base = vim.fs.dirname(real), vim.fs.basename(real)
	local tmp, fd, err
	for i = 1, 100 do
		tmp = ('%s/.%s.%d-%d.tmp'):format(dir, base, uv.os_getpid(), i)
		fd, err = uv.fs_open(tmp, 'wx', mode)
		if fd or not tostring(err):match('^EEXIST') then
			break
		end
	end
	if not fd then
		return nil, err
	end
	local ok, werr = uv.fs_write(fd, data, 0)
	if ok and ok ~= #data then
		ok, werr = nil, 'short write'
	end
	if ok then
		ok, werr = uv.fs_fsync(fd)
	end
	uv.fs_close(fd)
	if ok then
		-- The new file was created with mode filtered by the umask.
		uv.fs_chmod(tmp, mode)
		ok, werr = uv.fs_rename(tmp, real)
	end
	if not ok then
		uv.fs_unlink(tmp)
		return nil, werr
	end
	return true
end

-- The key to offer as a recipient: default-key from gpg.conf, or the first
-- valid secret key that can encrypt.
local function own_key()
	local ok, res = pcall(function()
		return vim.system({ 'gpgconf', '--list-options', 'gpg' }, { text = true }):wait()
	end)
	if ok and res.code == 0 then
		for line in res.stdout:gmatch('[^\n]+') do
			local value = line:match('^default%-key:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:"?([^:]+)')
			if value then
				return value
			end
		end
	end
	local keys = run({ '--with-colons', '--list-secret-keys' })
	if keys and keys.code == 0 then
		local usable
		for line in keys.out:gmatch('[^\n]+') do
			local f = vim.split(line, ':', { plain = true })
			if f[1] == 'sec' then
				usable = (f[2] == 'u' or f[2] == 'f') and (f[12] or ''):find('E') ~= nil
			elseif f[1] == 'fpr' and usable then
				return f[10]
			end
		end
	end
	return nil
end

-- "Name <email>" for a key id, or the id when gpg does not know it.
local function describe(id)
	local res = run({ '--with-colons', '--list-keys', '--', id })
	if res and res.code == 0 then
		for line in res.out:gmatch('[^\n]+') do
			local f = vim.split(line, ':', { plain = true })
			if f[1] == 'uid' and f[2] ~= 'r' and f[2] ~= 'e' then
				return ('%s (%s)'):format(f[10]:gsub('\\x3a', ':'), id)
			end
		end
	end
	return id
end

-- Ask how to encrypt. Returns true when st was set.
local function choose(st, name)
	local pick = vim.fn.confirm(('How should %s be encrypted?'):format(name), '&Passphrase\n&Recipients\n&Cancel', 0)
	vim.cmd('redraw')
	if pick == 1 then
		st.symmetric, st.recipients = true, nil
		return true
	elseif pick ~= 2 then
		return false
	end

	local default = st.recipients and table.concat(st.recipients, ' ') or own_key() or ''
	local prompt = 'Recipients (key ids, fingerprints, or emails; spaces between): '
	if not st.recipients and default ~= '' then
		prompt = ('Your key: %s\n%s'):format(describe(default), prompt)
	end
	local cancelled = '\1'
	local ok, answer = pcall(vim.fn.input, { prompt = prompt, default = default, cancelreturn = cancelled })
	vim.cmd('redraw')
	if not ok or answer == cancelled then
		return false
	end
	local list = {}
	for r in answer:gmatch('[^%s,]+') do
		list[#list + 1] = r
	end
	if #list == 0 then
		vim.notify('No recipients: nothing was written', vim.log.levels.WARN)
		return false
	end
	st.symmetric, st.recipients = false, list
	return true
end

local function decrypt(data)
	if pinentry_ok() then
		return run({ '--decrypt' }, data)
	end
	local res, err = run({ '--decrypt' }, data, { mode = 'error' })
	if not res or not needs_passphrase(res) then
		return res, err
	end
	local pass = ask_secret('Passphrase: ')
	if not pass then
		return nil, 'no passphrase'
	end
	return run({ '--decrypt' }, data, { passphrase = pass })
end

local function encrypted(res)
	return has_status(res, '^BEGIN_DECRYPTION') or has_status(res, '^ENC_TO ') or has_status(res, '^NEED_PASSPHRASE_SYM')
end

-- Filetype from the name without .gpg: notes.md.gpg is markdown.
local function filetype(buf, path, keep_ext)
	local inner = keep_ext and path or path:gsub('%.[^./\\]+$', '')
	local ft = vim.filetype.match({ filename = inner, buf = buf })
	if ft then
		vim.bo[buf].filetype = ft
	end
end

-- Decrypt path. Returns lines and the state, or nil and why.
local function load(path)
	local data = read_file(path)
	if not data then
		return nil, 'cannot read ' .. path
	end
	local res, err = decrypt(data)
	if not res then
		return nil, err
	end
	if not encrypted(res) then
		return nil, nil, { plain = true }
	end
	if res.code ~= 0 or not has_status(res, '^DECRYPTION_OKAY') then
		return nil, res
	end

	local st = { symmetric = false, armor = data:match('^%s*%-%-%-%-%-BEGIN PGP') ~= nil }
	local ids = {}
	for _, s in ipairs(res.status) do
		local id = s:match('^ENC_TO (%x+)')
		if id and not id:match('^0+$') and not vim.tbl_contains(ids, id) then
			ids[#ids + 1] = id
		end
		if s:match('^NEED_PASSPHRASE_SYM') then
			st.symmetric = true
		end
	end
	if #ids > 0 then
		st.recipients = ids
		-- Encrypted to both keys and a passphrase: keep the keys, which is
		-- what gpg reported using.
		if st.symmetric and not has_status(res, '^NEED_PASSPHRASE_SYM') then
			st.symmetric = false
		end
	end
	if not st.symmetric and not st.recipients then
		-- Hidden recipients (--throw-keyids): ask on the first save.
		st.unknown = true
	end
	local lines, eol, ff = decode(res.out)
	return lines, nil, st, eol, ff
end

local function plain_read(buf, path)
	local bo = vim.bo[buf]
	bo.buftype = ''
	vim.api.nvim_buf_call(buf, function()
		vim.cmd('silent noautocmd keepalt read ++edit ' .. vim.fn.fnameescape(path))
		local ul = bo.undolevels
		bo.undolevels = -1
		vim.cmd('silent 1delete _')
		bo.undolevels = ul
	end)
	bo.modified = false
	filetype(buf, path, true)
end

local function buf_read(ev)
	local buf, path = ev.buf, vim.fn.fnamemodify(ev.match, ':p')
	local bo = vim.bo[buf]
	bo.swapfile = false
	bo.undofile = false
	bo.buftype = 'acwrite'
	bo.modifiable = true
	bo.readonly = false
	state[buf] = nil

	if not uv.fs_stat(path) then
		state[buf] = { new = true, armor = path:match('%.asc$') ~= nil }
		filetype(buf, path)
		vim.api.nvim_echo({ { ('"%s" [New]'):format(vim.fn.fnamemodify(path, ':~:.')) } }, false, {})
		return
	end

	local lines, why, st, eol, ff = load(path)
	if st and st.plain then
		state[buf] = st
		plain_read(buf, path)
		return
	end
	if not lines then
		state[buf] = { failed = true }
		set_text(buf, {})
		bo.modified = false
		bo.modifiable = false
		bo.readonly = true
		if type(why) == 'table' then
			fail(('Could not decrypt %s. The file is unchanged; :e to try again.'):format(path), why)
		else
			fail(('Could not decrypt %s: %s. The file is unchanged; :e to try again.'):format(path, why or '?'))
		end
		return
	end

	state[buf] = st
	bo.fileformat = ff
	bo.eol = eol
	bo.fileencoding = 'utf-8'
	set_text(buf, lines)
	bo.modified = false
	filetype(buf, path)
	vim.api.nvim_echo({ { ('"%s" %dL, decrypted'):format(vim.fn.fnamemodify(path, ':~:.'), #lines) } }, false, {})
end

-- :r file.gpg
local function file_read(ev)
	local path = vim.fn.fnamemodify(ev.match, ':p')
	local lines, why, st = load(path)
	if st and st.plain then
		lines = vim.split((read_file(path) or ''):gsub('\n$', ''), '\n', { plain = true })
	elseif not lines then
		fail('Could not decrypt ' .. path, type(why) == 'table' and why or nil)
		return
	end
	local after = vim.api.nvim_buf_get_mark(0, '[')[1]
	vim.api.nvim_buf_set_lines(0, after, after, false, lines)
end

local function encrypt_args(st)
	local args = {}
	if st.symmetric then
		args[#args + 1] = '--symmetric'
	end
	if st.recipients then
		args[#args + 1] = '--encrypt'
		for _, r in ipairs(st.recipients) do
			vim.list_extend(args, { '--recipient', r })
		end
	end
	if st.armor then
		args[#args + 1] = '--armor'
	end
	return args
end

local reasons = {
	['0'] = 'not usable',
	['1'] = 'not found',
	['2'] = 'ambiguous',
	['3'] = 'wrong key usage',
	['4'] = 'revoked',
	['5'] = 'expired',
	['6'] = 'no CRL known',
	['7'] = 'CRL too old',
	['8'] = 'policy mismatch',
	['9'] = 'not a secret key',
	['10'] = 'not trusted',
	['11'] = 'missing certificate',
	['12'] = 'missing issuer certificate',
	['13'] = 'key disabled',
	['14'] = 'syntax error in specification',
}

-- Symmetric passphrase for a save in loopback mode. One prompt when it
-- still opens the file on disk; otherwise it is new, so ask twice.
local function save_passphrase(path)
	local pass = ask_secret('Passphrase: ')
	if not pass then
		return nil
	end
	local old = read_file(path)
	if old then
		local res = run({ '--decrypt' }, old, { passphrase = pass })
		if res and res.code == 0 then
			return pass
		end
	end
	local again = ask_secret(old and 'New passphrase; repeat it: ' or 'Repeat passphrase: ')
	if again ~= pass then
		vim.notify('Passphrases differ: nothing was written', vim.log.levels.ERROR)
		return nil
	end
	return pass
end

local function write(buf, target, lines, whole)
	-- A buffer that is not an encrypted file (:w copy.gpg from a plain
	-- buffer) asks every time and keeps no state.
	local st = state[buf] or { new = true, armor = target:match('%.asc$') ~= nil }
	local shown = vim.fn.fnamemodify(target, ':~:.')

	if st.failed then
		fail(('Not written: %s was never decrypted. :e to try again.'):format(shown))
		return false
	end

	if st.plain then
		local first, last = vim.fn.line("'["), vim.fn.line("']")
		local range = whole and '' or ('%d,%d'):format(first, last)
		vim.api.nvim_buf_call(buf, function()
			vim.cmd(('noautocmd keepalt %swrite%s %s'):format(range, vim.v.cmdbang == 1 and '!' or '', vim.fn.fnameescape(target)))
		end)
		return true
	end

	if st.new or st.unknown then
		if not choose(st, shown) then
			return false
		end
		st.new, st.unknown = nil, nil
	end

	local opts
	if st.symmetric and not pinentry_ok() then
		local pass = save_passphrase(target)
		if not pass then
			return false
		end
		opts = { passphrase = pass }
	end

	local res, err = run(encrypt_args(st), encode(buf, lines, whole), opts)
	if not res then
		fail(('Not written: %s'):format(err))
		return false
	end
	if res.code ~= 0 or res.out == '' then
		local bad = {}
		for _, s in ipairs(res.status) do
			local code, who = s:match('^INV_RECP (%d+) (.*)')
			if code then
				bad[#bad + 1] = ('%s: %s'):format(who, reasons[code] or ('reason ' .. code))
			end
		end
		local msg = 'Not written: gpg could not encrypt. The file is unchanged.'
		if #bad > 0 then
			msg = msg .. '\n' .. table.concat(bad, '\n')
		end
		fail(msg, res)
		return false
	end

	local ok, werr = replace_file(target, res.out)
	if not ok then
		fail(('Not written: %s. The file is unchanged.'):format(werr))
		return false
	end

	local how = st.symmetric and 'with a passphrase' or ('to %d key%s'):format(#st.recipients, #st.recipients == 1 and '' or 's')
	vim.api.nvim_echo({ { ('"%s" %dL, encrypted %s'):format(shown, #lines, how) } }, false, {})
	return true
end

local function buf_write(ev)
	local buf = ev.buf
	local target = vim.fn.fnamemodify(ev.match, ':p')
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local ok = write(buf, target, lines, true)
	local own = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':p')
	if ok and (target == own or vim.o.cpoptions:find('+', 1, true)) then
		vim.bo[buf].modified = false
	end
end

-- :'<,'>w part.gpg
local function file_write(ev)
	local buf = ev.buf
	local first, last = vim.fn.line("'["), vim.fn.line("']")
	local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
	write(buf, vim.fn.fnamemodify(ev.match, ':p'), lines, false)
end

local function info()
	local buf = vim.api.nvim_get_current_buf()
	local st = state[buf]
	if not st then
		vim.notify('Not an encrypted buffer', vim.log.levels.INFO)
		return
	end
	local lines
	if st.failed then
		lines = { 'Decryption failed; this buffer cannot be saved.' }
	elseif st.plain then
		lines = { 'Not encrypted: read and written as an ordinary file.' }
	elseif st.new or st.unknown then
		lines = { 'Asks on the next save: passphrase or recipients.' }
	elseif st.symmetric then
		lines = { 'Encrypted with a passphrase.' }
	else
		lines = { 'Encrypted to:' }
		for _, r in ipairs(st.recipients) do
			lines[#lines + 1] = '  ' .. describe(r)
		end
	end
	if not st.failed and not st.plain then
		lines[#lines + 1] = st.armor and 'Written as ASCII armor.' or 'Written as binary.'
		lines[#lines + 1] = pinentry_ok() and 'Passphrases: gpg-agent pinentry.' or 'Passphrases: asked here (no display for pinentry).'
	end
	vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

local function change()
	local buf = vim.api.nvim_get_current_buf()
	local st = state[buf]
	if not st or st.failed or st.plain then
		vim.notify('Not an encrypted buffer that can be saved', vim.log.levels.WARN)
		return
	end
	if choose(st, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':~:.')) then
		st.new, st.unknown = nil, nil
		vim.bo[buf].modified = true
		info()
	end
end

function M.setup()
	-- Another copy of vim-gnupg (a distro package) would install its own
	-- handlers for the same files.
	vim.g.loaded_gnupg = 1

	local group = vim.api.nvim_create_augroup('config.gpg', { clear = true })
	vim.api.nvim_create_autocmd('BufReadCmd', { group = group, pattern = patterns, callback = buf_read })
	vim.api.nvim_create_autocmd('FileReadCmd', { group = group, pattern = patterns, callback = file_read })
	vim.api.nvim_create_autocmd('BufWriteCmd', { group = group, pattern = patterns, callback = buf_write })
	vim.api.nvim_create_autocmd('FileWriteCmd', { group = group, pattern = patterns, callback = file_write })
	vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
		group = group,
		callback = function(ev)
			state[ev.buf] = nil
		end,
	})

	vim.api.nvim_create_user_command('GpgInfo', info, { desc = 'How this buffer is encrypted' })
	vim.api.nvim_create_user_command('GpgEncryption', change, { desc = 'Choose a passphrase or recipients' })
end

return M
