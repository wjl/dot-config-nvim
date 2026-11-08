-- Structural folds without a parser. Each scanner reads the buffer once,
-- skips comments and strings, and returns ranges { first, last } of lines.
-- M.levels turns those ranges into fold levels.
--
-- These are lexers, so they know where blocks begin and end, and nothing
-- about what a name means. They are plain Lua, so they work the same in
-- every recent Neovim on every system, with nothing to build or install.

local M = {}

-- filetype -> module under config.foldscan
local modules = {
	c = 'clike',
	cpp = 'clike',
	go = 'clike',
	rust = 'clike',
	javascript = 'clike',
	javascriptreact = 'clike',
	typescript = 'clike',
	typescriptreact = 'clike',
	json = 'clike',
	jsonc = 'clike',
	json5 = 'clike',
	python = 'python',
	lua = 'lua',
	sh = 'shell',
	bash = 'shell',
	zsh = 'shell',
	ksh = 'shell',
	vim = 'vim',
	make = 'make',
	toml = 'config',
	dosini = 'config',
	confini = 'config',
	systemd = 'config',
	gitconfig = 'config',
	desktop = 'config',
	markdown = 'markdown',
	text = 'markdown',
}

function M.supports(ft)
	return modules[ft] ~= nil
end

-- The raw ranges for a list of lines, or nil if no scanner knows `ft`.
function M.ranges(lines, ft)
	local mod = modules[ft]
	if not mod then
		return nil
	end
	return require('config.foldscan.' .. mod)[ft](lines)
end

-- Per line: the structural level, and whether a fold starts there.
-- A fold that ends on the line where the next one starts (`} else {`)
-- ends one line sooner, so the two stay side by side. Ranges that cross
-- each other are dropped, so levels always nest.
function M.levels(lines, ft)
	local ranges = M.ranges(lines, ft)
	if not ranges then
		return nil
	end

	local starts_at = {}
	for _, r in ipairs(ranges) do
		starts_at[r[1]] = true
	end
	local trimmed = {}
	for _, r in ipairs(ranges) do
		local first, last = r[1], r[2]
		if starts_at[last] then
			last = last - 1
		end
		if last > first then
			trimmed[#trimmed + 1] = { first, last }
		end
	end
	table.sort(trimmed, function(a, b)
		if a[1] ~= b[1] then
			return a[1] < b[1]
		end
		return a[2] > b[2]
	end)

	local opens, closes = {}, {}
	local open = {}
	for _, r in ipairs(trimmed) do
		while #open > 0 and open[#open][2] < r[1] do
			open[#open] = nil
		end
		local top = open[#open]
		if not top or r[2] <= top[2] then
			open[#open + 1] = r
			opens[r[1]] = (opens[r[1]] or 0) + 1
			closes[r[2]] = (closes[r[2]] or 0) + 1
		end
	end

	local levels, starts = {}, {}
	local level = 0
	for ln = 1, #lines do
		local o = opens[ln]
		if o then
			level = level + o
			starts[ln] = true
		end
		levels[ln] = level
		level = level - (closes[ln] or 0)
	end
	return levels, starts
end

return M
