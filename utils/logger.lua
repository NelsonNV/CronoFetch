local M = {}

local verbose_enabled = false

local status_icons = {
	ok = "✓",
	warn = "⚠",
	error = "✗",
}

function M.init(verbose)
	verbose_enabled = verbose or false
end

function M.verbose(message)
	if not verbose_enabled then
		return
	end
	io.stderr:write("[DEBUG] " .. message .. "\n")
end

function M.check(status, message)
	local icon = status_icons[status] or "?"
	io.stderr:write(string.format("[%s] %s\n", icon, message))
end

function M.error(message)
	io.stderr:write("ERROR: " .. message .. "\n")
end

function M.section(title)
	io.stderr:write("\n=== " .. title .. " ===\n\n")
end

function M.subsection(title)
	io.stderr:write("[" .. title .. "]\n")
end

return M
