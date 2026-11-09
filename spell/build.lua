-- Rebuild the spell files that come from hunspell sources: French and
-- Swedish. German and Spanish are Vim's own prebuilt files (README.md).
--
--   nvim -l spell/build.lua
--
-- Needs curl and unzip. Downloads are checked against the sha256 below, so
-- a changed upstream file stops the build instead of slipping in. To move
-- to a new version, change the URL and the hash together.
--
-- Vim's :mkspell does not know a few hunspell items in the French affix
-- file (ICONV/OCONV, BREAK, FULLSTRIP, KEY, WORDCHARS) and skips them. The
-- one that shows: a typographic apostrophe (aujourd’hui) is not taken as
-- the ASCII one, so type ' . WORDCHARS being skipped is a gain: '-' stays a
-- word separator, so English hyphenated compounds still pass with
-- spelllang=en,fr.

local here = vim.fs.dirname(vim.fs.normalize(debug.getinfo(1, 'S').source:sub(2)))
local work = vim.fn.tempname()
vim.fn.mkdir(work, 'p')

local libreoffice = 'https://raw.githubusercontent.com/LibreOffice/dictionaries/4f1df64b2e8e14751aa7c2205d170ca016071315/'

local sources = {
	{
		lang = 'fr',
		-- Grammalecte 7.7, "toutes variantes": traditional and 1990 spellings.
		url = 'https://grammalecte.net/dic/hunspell-french-dictionaries-v7.7.zip',
		sha256 = '44314d992f94b4658c31a86ef2351724a43067531b0af3643f91bf0220eee616',
		unzip = { aff = 'fr-toutesvariantes.aff', dic = 'fr-toutesvariantes.dic', readme = 'README_dict_fr.txt' },
	},
	{
		lang = 'sv',
		-- LibreOffice "Den stora svenska ordlistan" 2.42 (Göran Andersson).
		files = {
			aff = { libreoffice .. 'sv_SE/dictionaries/sv_SE.aff', '97fc1a3cd998f62ba48366ac13398b919a17e991cb69115fa60bb861093406b9' },
			dic = { libreoffice .. 'sv_SE/dictionaries/sv_SE.dic', 'bd44b19cd8c061fb1d2504dc676adc3a68d41a866c99d10c8163fc396049fcad' },
			readme = { libreoffice .. 'sv_SE/LICENSE_sv_SE.txt', '841736f210169ce2c9c6907c0d88495e6d41ff7d067a3033c56ae1179ce62127' },
		},
		region = 'SE',
	},
}

local function die(msg)
	io.stderr:write('spell/build.lua: ' .. msg .. '\n')
	os.exit(1)
end

local function run(cmd)
	local res = vim.system(cmd):wait()
	if res.code ~= 0 then
		die(table.concat(cmd, ' ') .. ' failed:\n' .. (res.stderr or ''))
	end
end

local function read(path)
	local f = assert(io.open(path, 'rb'))
	local data = f:read('*a')
	f:close()
	return data
end

local function fetch(url, sha256, out)
	run({ 'curl', '-fsSL', '-o', out, url })
	local got = vim.fn.sha256(read(out))
	if got ~= sha256 then
		die(('%s\n  expected sha256 %s\n  got             %s'):format(url, sha256, got))
	end
end

local function copy(from, to)
	local f = assert(io.open(to, 'wb'))
	f:write(read(from))
	f:close()
end

for _, src in ipairs(sources) do
	local dir = work .. '/' .. src.lang
	vim.fn.mkdir(dir, 'p')
	-- :mkspell reads <base>.aff and <base>.dic; a _XX suffix names a region.
	local base = dir .. '/' .. src.lang .. (src.region and ('_' .. src.region) or '')
	local readme
	if src.url then
		local zip = dir .. '/src.zip'
		fetch(src.url, src.sha256, zip)
		run({ 'unzip', '-oq', zip, '-d', dir })
		copy(dir .. '/' .. src.unzip.aff, base .. '.aff')
		copy(dir .. '/' .. src.unzip.dic, base .. '.dic')
		readme = { dir .. '/' .. src.unzip.readme, src.unzip.readme }
	else
		fetch(src.files.aff[1], src.files.aff[2], base .. '.aff')
		fetch(src.files.dic[1], src.files.dic[2], base .. '.dic')
		local name = vim.fs.basename(src.files.readme[1])
		fetch(src.files.readme[1], src.files.readme[2], dir .. '/' .. name)
		readme = { dir .. '/' .. name, name }
	end

	io.stdout:write(('building %s.utf-8.spl ...\n'):format(src.lang))
	vim.cmd(('silent mkspell! %s %s'):format(vim.fn.fnameescape(here .. '/' .. src.lang), vim.fn.fnameescape(base)))
	copy(readme[1], here .. '/' .. readme[2])
	io.stdout:write(('  %s  %s.utf-8.spl\n'):format(vim.fn.sha256(read(here .. '/' .. src.lang .. '.utf-8.spl')), src.lang))
end

vim.fn.delete(work, 'rf')
