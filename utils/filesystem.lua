-- WARNING: las rutas se escapan con comillas dobles para evitar inyección de shell
local M = {}

local function escape_shell_argument(argument_value)
	return '"' .. argument_value:gsub('"', '\\"') .. '"'
end

function M.directory_exists(directory_path)
	local safe_path = escape_shell_argument(directory_path)
	local pipe = io.popen(string.format("test -d %s && echo yes || echo no", safe_path))
	if not pipe then
		return false
	end
	local result = pipe:read("*l")
	pipe:close()
	return result == "yes"
end

function M.count_files_in_directory(directory_path)
	local safe_path = escape_shell_argument(directory_path)
	local command = string.format("find %s -type f 2>/dev/null | wc -l", safe_path)
	local pipe = io.popen(command)
	if not pipe then
		return 0
	end
	local output = pipe:read("*l")
	pipe:close()
	if not output then
		return 0
	end
	local count = tonumber(output:match("%d+"))
	return count or 0
end

function M.get_files_in_directory(directory_path)
	local files = {}
	local safe_path = escape_shell_argument(directory_path)
	local command = string.format("find %s -type f 2>/dev/null", safe_path)
	local pipe = io.popen(command)
	if not pipe then
		return files
	end
	for line in pipe:lines() do
		table.insert(files, line)
	end
	pipe:close()
	return files
end

-- WARNING: fastfetch pasa la ruta a un shell interno, los espacios rompen el parsing
function M.escape_path_for_shell(file_path)
	return (file_path:gsub(" ", "\\ "))
end

return M
