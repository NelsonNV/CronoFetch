local logger = require("logger")

local M = {}

local function get_state_path()
	return os.getenv("HOME") .. "/.config/fastfetch/state/history.lua"
end

local function get_log_path()
	return os.getenv("HOME") .. "/.config/fastfetch/state/history.log"
end

local function build_empty_state()
	return {
		usage_count = {},
		last_used = {},
		current_cycle = {},
		daily_assignments = {},
	}
end

function M.normalize_state(raw_state)
	if type(raw_state) ~= "table" then
		return build_empty_state()
	end

	return {
		usage_count = raw_state.usage_count or {},
		last_used = raw_state.last_used or {},
		current_cycle = raw_state.current_cycle or {},
		daily_assignments = raw_state.daily_assignments or {},
	}
end

function M.load()
	local state_path = get_state_path()
	local state_loader = loadfile(state_path)
	if state_loader then
		local raw_state = state_loader()
		return M.normalize_state(raw_state)
	end
	return build_empty_state()
end

function M.save(state)
	local state_path = get_state_path()
	local state_file = io.open(state_path, "w")
	if not state_file then
		logger.verbose("WARNING: No se pudo guardar el estado")
		return
	end

	state_file:write("return {\n")

	state_file:write("  usage_count = {\n")
	for folder_name, count in pairs(state.usage_count) do
		state_file:write(string.format('    ["%s"] = %d,\n', folder_name, count))
	end
	state_file:write("  },\n")

	state_file:write("  last_used = {\n")
	for folder_name, date_info in pairs(state.last_used) do
		state_file:write(
			string.format('    ["%s"] = { week = %d, year = %d },\n', folder_name, date_info.week, date_info.year)
		)
	end
	state_file:write("  },\n")

	state_file:write("  current_cycle = {\n")
	for folder_name, used in pairs(state.current_cycle) do
		state_file:write(string.format('    ["%s"] = %s,\n', folder_name, tostring(used)))
	end
	state_file:write("  },\n")

	state_file:write("  daily_assignments = {\n")
	for weekday, assignment in pairs(state.daily_assignments) do
		state_file:write(
			string.format('    [%d] = { date = "%s", event = "%s" },\n', weekday, assignment.date, assignment.event)
		)
	end
	state_file:write("  },\n")

	state_file:write("}\n")
	state_file:close()
end

-- NOTE: el log guarda la ruta original sin escapar, el output para fastfetch va escapado aparte
function M.log_execution(event_name, image_path)
	local log_path = get_log_path()
	local log_file = io.open(log_path, "a")
	if not log_file then
		logger.verbose("WARNING: No se pudo escribir en history.log")
		return
	end

	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local log_entry = string.format("%s|%s|%s\n", timestamp, event_name, image_path)
	log_file:write(log_entry)
	log_file:close()

	logger.verbose("Registrado en history.log")
end

return M
