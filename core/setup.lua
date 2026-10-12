local logger = require("logger")

local M = {}

local function build_config_paths()
	return {
		os.getenv("HOME") .. "/.config/fastfetch/config.lua",
		"./config.lua",
	}
end

local function get_primary_config_path()
	return os.getenv("HOME") .. "/.config/fastfetch/config.lua"
end

local function get_mode_state_path()
	return os.getenv("HOME") .. "/.config/fastfetch/state/mode.lua"
end

function M.load_configuration()
	local configuration

	for _, config_path in ipairs(build_config_paths()) do
		local config_loader = loadfile(config_path)
		if config_loader then
			configuration = config_loader()
			break
		end
	end

	if not configuration then
		io.stderr:write("ERROR: No se encontró configuración\n")
		io.stderr:write("Copia config.example.lua a ~/.config/fastfetch/config.lua\n")
		os.exit(1)
	end

	local mode_state_loader = loadfile(get_mode_state_path())
	if mode_state_loader then
		local current_mode = mode_state_loader()
		if type(current_mode) == "string" and current_mode ~= "" then
			configuration.mode = current_mode
			logger.verbose("Mode override activo: " .. current_mode)
		end
	end

	return configuration
end

local function load_available_modes(configuration)
	if not configuration.modes or type(configuration.modes) ~= "table" or #configuration.modes == 0 then
		return { configuration.mode }
	end
	return configuration.modes
end

local function find_next_mode(available_modes, current_mode)
	for index, mode_name in ipairs(available_modes) do
		if mode_name == current_mode then
			local next_index = (index % #available_modes) + 1
			return available_modes[next_index]
		end
	end
	return available_modes[1]
end

local function persist_mode(mode_name)
	local mode_state_path = get_mode_state_path()
	local mode_file = io.open(mode_state_path, "w")
	if not mode_file then
		io.stderr:write("ERROR: No se pudo escribir en " .. mode_state_path .. "\n")
		os.exit(1)
	end
	mode_file:write('return "' .. mode_name .. '"\n')
	mode_file:close()
end

local function read_config_file()
	local config_path = get_primary_config_path()
	local config_file = io.open(config_path, "r")
	if not config_file then
		io.stderr:write("ERROR: No se pudo leer " .. config_path .. "\n")
		os.exit(1)
	end
	local config_content = config_file:read("*a")
	config_file:close()
	return config_content
end

local function write_config_file(config_content)
	local config_path = get_primary_config_path()
	local config_file = io.open(config_path, "w")
	if not config_file then
		io.stderr:write("ERROR: No se pudo escribir en " .. config_path .. "\n")
		os.exit(1)
	end
	config_file:write(config_content)
	config_file:close()
end

function M.change_mode(mode_name, configuration)
	local available_modes = load_available_modes(configuration)
	local current_mode = configuration.mode

	local is_valid_mode = false
	for _, existing_mode in ipairs(available_modes) do
		if existing_mode == mode_name then
			is_valid_mode = true
			break
		end
	end

	if not is_valid_mode then
		io.stderr:write("ERROR: modo '" .. mode_name .. "' no está en la lista de modos\n")
		io.stderr:write("Modos disponibles: " .. table.concat(available_modes, ", ") .. "\n")
		os.exit(1)
	end

	if mode_name == current_mode then
		io.stderr:write("Ya estás en el modo: " .. current_mode .. "\n")
		return
	end

	persist_mode(mode_name)
	io.stderr:write("✓ Modo cambiado: " .. current_mode .. " → " .. mode_name .. "\n")
end

function M.toggle_mode(configuration)
	local available_modes = load_available_modes(configuration)
	local current_mode = configuration.mode

	if #available_modes < 2 then
		io.stderr:write("No hay suficientes modos para hacer toggle (actual: " .. current_mode .. ")\n")
		io.stderr:write("Agrega modos con --mode-add <nombre>\n")
		return
	end

	local next_mode = find_next_mode(available_modes, current_mode)

	if next_mode == current_mode then
		io.stderr:write("Ya estás en el modo: " .. current_mode .. "\n")
		return
	end

	persist_mode(next_mode)
	io.stderr:write("✓ Modo cambiado: " .. current_mode .. " → " .. next_mode .. "\n")
end

function M.add_mode(new_mode_name)
	local config_content = read_config_file()

	local modes_list_match = config_content:match("modes%s*=%s*%b{}")
	if modes_list_match then
		if modes_list_match:find('"' .. new_mode_name .. '"') then
			io.stderr:write("El modo '" .. new_mode_name .. "' ya existe en la lista\n")
			return
		end
		local updated_modes = modes_list_match:gsub("%s*}$", ', "' .. new_mode_name .. '" }')
		local updated_content = config_content:gsub("modes%s*=%s*%b{}", updated_modes)
		write_config_file(updated_content)
		io.stderr:write("✓ Modo '" .. new_mode_name .. "' agregado a la lista\n")
		return
	end

	local mode_field_match = config_content:match('mode%s*=%s*"[^"]*"')
	if not mode_field_match then
		io.stderr:write("ERROR: no se encontró el campo 'mode' en la configuración\n")
		os.exit(1)
	end

	local new_modes_field = '\n\n\tmodes = { "' .. new_mode_name .. '" },\n'
	local updated_content = config_content:gsub('(mode%s*=%s*"[^"]*")', "%1," .. new_modes_field)

	write_config_file(updated_content)
	io.stderr:write("✓ Modo '" .. new_mode_name .. "' agregado (se creó la lista modes)\n")
end

local function parse_rules_string(rules_string)
	local rules = {}
	for rule in rules_string:gmatch("[^,]+") do
		table.insert(rules, rule:match("^%s*(.-)%s*$"))
	end
	return rules
end

local function format_rules(rules)
	return "{" .. table.concat(rules, ", ") .. "}"
end

function M.show_rule(mode_name, configuration)
	local mode_rules = configuration.mode_rules or {}
	local rules = mode_rules[mode_name] or configuration.default_rule or { "strict", "fallback" }

	io.stderr:write(mode_name .. ": " .. format_rules(rules) .. "\n")
end

function M.set_rule(mode_name, rules_string)
	local config_content = read_config_file()
	local rules = parse_rules_string(rules_string)

	local mode_rules_match = config_content:match("mode_rules%s*=%s*%b{}")
	if not mode_rules_match then
		local new_mode_rules = "\n\n\tmode_rules = {\n\t\t" .. mode_name .. " = " .. format_rules(rules) .. ",\n\t},\n"
		config_content = config_content:gsub("(modes%s*=%s*%b{})", "%1," .. new_mode_rules)
	else
		local mode_entry = mode_rules_match:match(mode_name .. "%s*=%s*%b{}")
		if mode_entry then
			local updated_entry = mode_name .. " = " .. format_rules(rules)
			local updated_mode_rules = mode_rules_match:gsub(mode_name .. "%s*=%s*%b{}", updated_entry)
			config_content = config_content:gsub("mode_rules%s*=%s*%b{}", updated_mode_rules)
		else
			local new_entry = "\n\t\t" .. mode_name .. " = " .. format_rules(rules) .. ","
			local updated_mode_rules = mode_rules_match:gsub("(%b{})", function(block)
				return block:gsub("}$", new_entry .. "\n\t}")
			end)
			config_content = config_content:gsub("mode_rules%s*=%s*%b{}", updated_mode_rules)
		end
	end

	write_config_file(config_content)
	io.stderr:write("✓ Reglas de '" .. mode_name .. "' establecidas: " .. format_rules(rules) .. "\n")
end

function M.add_rule(mode_name, rule_name)
	local config_content = read_config_file()
	local mode_rules_match = config_content:match("mode_rules%s*=%s*%b{}")

	if not mode_rules_match then
		M.set_rule(mode_name, rule_name)
		return
	end

	local mode_entry = mode_rules_match:match(mode_name .. "%s*=%s*%b{}")
	if not mode_entry then
		local current_rules = parse_rules_string(rule_name)
		M.set_rule(mode_name, rule_name)
		return
	end

	local rules_list = mode_entry:match("%b{}")
	local updated_rules = rules_list:gsub("}$", ', "' .. rule_name .. '" }')
	local updated_entry = mode_name .. " = " .. updated_rules
	local updated_mode_rules = mode_rules_match:gsub(mode_name .. "%s*=%s*%b{}", updated_entry)
	config_content = config_content:gsub("mode_rules%s*=%s*%b{}", updated_mode_rules)

	write_config_file(config_content)
	io.stderr:write("✓ Regla '" .. rule_name .. "' agregada a '" .. mode_name .. "'\n")
end

function M.remove_rule(mode_name, rule_name)
	local config_content = read_config_file()
	local mode_rules_match = config_content:match("mode_rules%s*=%s*%b{}")

	if not mode_rules_match then
		io.stderr:write("No hay reglas configuradas\n")
		return
	end

	local mode_entry = mode_rules_match:match(mode_name .. "%s*=%s*%b{}")
	if not mode_entry then
		io.stderr:write("El modo '" .. mode_name .. "' no tiene reglas configuradas\n")
		return
	end

	local rules_list = mode_entry:match("%b{}")
	local updated_rules = rules_list:gsub(',%s*"' .. rule_name .. '"', ""):gsub('"' .. rule_name .. '"%s*,?', "")
	updated_rules = updated_rules:gsub(",%s*}", " }")

	if updated_rules == "{ }" or updated_rules == "{}" then
		io.stderr:write("No se puede eliminar la última regla\n")
		return
	end

	local updated_entry = mode_name .. " = " .. updated_rules
	local updated_mode_rules = mode_rules_match:gsub(mode_name .. "%s*=%s*%b{}", updated_entry)
	config_content = config_content:gsub("mode_rules%s*=%s*%b{}", updated_mode_rules)

	write_config_file(config_content)
	io.stderr:write("✓ Regla '" .. rule_name .. "' eliminada de '" .. mode_name .. "'\n")
end

function M.set_default_rule(rules_string)
	local config_content = read_config_file()
	local rules = parse_rules_string(rules_string)

	local default_rule_match = config_content:match("default_rule%s*=%s*%b{}")
	if default_rule_match then
		local updated_default = "default_rule = " .. format_rules(rules)
		config_content = config_content:gsub("default_rule%s*=%s*%b{}", updated_default)
	else
		local new_default = "\n\n\tdefault_rule = " .. format_rules(rules) .. ",\n"
		config_content = config_content:gsub("(mode_rules%s*=%s*%b{})", "%1," .. new_default)
	end

	write_config_file(config_content)
	io.stderr:write("✓ Regla por defecto establecida: " .. format_rules(rules) .. "\n")
end

function M.list_policies()
	io.stderr:write("Políticas disponibles:\n\n")
	io.stderr:write("  strict              Solo busca en base_directory/evento/modo/\n")
	io.stderr:write("  permissive          Busca en base_directory/evento/ ignorando el modo\n")
	io.stderr:write("  override:<carpeta>  Ignora eventos, usa carpeta global especial\n")
	io.stderr:write("  fallback            Usa el fallback character\n")
	io.stderr:write("  mixed               Primero strict, si falla permissive\n")
end

return M
