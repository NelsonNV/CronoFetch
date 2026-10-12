local logger = require("logger")
local date_utils = require("date_utils")
local filesystem = require("filesystem")

local M = {}

local day_names = { "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo" }

local VALID_POLICIES = { "strict", "permissive", "override", "fallback", "mixed" }

local function is_valid_policy(policy_string)
	if type(policy_string) ~= "string" or policy_string == "" then
		return false
	end
	local policy_name = policy_string:match("^([^:]+)")
	for _, valid_policy in ipairs(VALID_POLICIES) do
		if valid_policy == policy_name then
			return true
		end
	end
	return false
end

local function parse_policy(policy_string)
	local policy_name, policy_param = policy_string:match("^([^:]+):(.+)$")
	if policy_name then
		return policy_name, policy_param
	end
	return policy_string, nil
end

-- ---------------------------------------------------------------------------
-- validaciones individuales
-- ---------------------------------------------------------------------------

local function validate_base_directory(configuration, errors)
	logger.subsection("estructura")

	if not configuration.base_directory then
		table.insert(errors, "base_directory no definido")
		logger.check("error", "base_directory no definido")
		return
	end

	if type(configuration.base_directory) ~= "string" then
		table.insert(errors, "base_directory debe ser string")
		logger.check("error", "base_directory debe ser string")
		return
	end

	if filesystem.directory_exists(configuration.base_directory) then
		logger.check("ok", "base_directory existe: " .. configuration.base_directory)
	else
		table.insert(errors, "base_directory no existe: " .. configuration.base_directory)
		logger.check("error", "base_directory no existe: " .. configuration.base_directory)
	end
end

local function validate_mode(configuration, errors)
	if not configuration.mode then
		table.insert(errors, "mode no definido")
		logger.check("error", "mode no definido")
		return
	end

	if type(configuration.mode) ~= "string" then
		table.insert(errors, "mode debe ser string")
		logger.check("error", "mode debe ser string")
		return
	end

	logger.check("ok", "mode: " .. configuration.mode)
end

local function validate_modes_list(configuration, errors, warnings)
	logger.subsection("lista de modos")

	if not configuration.modes or type(configuration.modes) ~= "table" then
		table.insert(warnings, "modes no definido (se usará solo el mode actual)")
		logger.check("warn", "modes no definido")
		return {}
	end

	local valid_modes = {}
	local seen_modes = {}

	for _, mode_name in ipairs(configuration.modes) do
		if type(mode_name) ~= "string" or mode_name == "" then
			table.insert(errors, "modo inválido en modes: " .. tostring(mode_name))
			logger.check("error", "modo inválido: " .. tostring(mode_name))
		elseif seen_modes[mode_name] then
			table.insert(errors, "modo duplicado en modes: " .. mode_name)
			logger.check("error", "modo duplicado: " .. mode_name)
		else
			seen_modes[mode_name] = true
			table.insert(valid_modes, mode_name)
			logger.check("ok", "modo: " .. mode_name)
		end
	end

	if #valid_modes == 0 then
		table.insert(errors, "modes está vacío o todos los modos son inválidos")
		logger.check("error", "modes sin modos válidos")
	end

	return valid_modes
end

local function validate_active_mode(configuration, valid_modes, errors, warnings)
	if #valid_modes == 0 then
		return
	end

	local current_mode = configuration.mode
	local mode_exists = false
	for _, mode_name in ipairs(valid_modes) do
		if mode_name == current_mode then
			mode_exists = true
			break
		end
	end

	if not mode_exists then
		table.insert(errors, "mode actual '" .. current_mode .. "' no está en la lista modes")
		logger.check("error", "mode actual '" .. current_mode .. "' no está en modes")
	else
		logger.check("ok", "mode actual '" .. current_mode .. "' está en modes")
	end
end

local function validate_birthdays(configuration, errors, warnings)
	logger.subsection("cumpleaños")

	if not configuration.birthdays or type(configuration.birthdays) ~= "table" then
		table.insert(warnings, "birthdays no definido o inválido")
		logger.check("warn", "birthdays no definido")
		return
	end

	local valid_birthdays_count = 0
	for date_key, event_name in pairs(configuration.birthdays) do
		local valid, error_message = date_utils.validate_date_format(date_key)
		if not valid then
			table.insert(errors, string.format('cumpleaños "%s": %s', date_key, error_message))
			logger.check("error", string.format('"%s" → %s → %s', date_key, event_name, error_message))
		elseif type(event_name) ~= "string" or event_name == "" then
			table.insert(errors, string.format('cumpleaños "%s": evento vacío o inválido', date_key))
			logger.check("error", string.format('"%s" → evento vacío o inválido', date_key))
		else
			valid_birthdays_count = valid_birthdays_count + 1
			logger.check("ok", string.format('"%s" → %s', date_key, event_name))
		end
	end

	if valid_birthdays_count == 0 and next(configuration.birthdays) ~= nil then
		table.insert(warnings, "ningún cumpleaños tiene formato válido")
	end
end

local function validate_weekly_options(day_number, options, errors, warnings)
	local day_name = day_names[day_number]

	if type(options) == "string" then
		logger.check("ok", string.format("%s (%d): '%s'", day_name, day_number, options))
		return
	end

	if type(options) ~= "table" then
		table.insert(errors, string.format("%s (%d): tipo inválido (esperado string o tabla)", day_name, day_number))
		logger.check("error", string.format("%s: tipo inválido", day_name))
		return
	end

	if #options == 0 then
		table.insert(warnings, string.format("%s (%d): lista vacía", day_name, day_number))
		logger.check("warn", string.format("%s (%d): lista vacía", day_name, day_number))
		return
	end

	local invalid_options = {}
	for _, option in ipairs(options) do
		if type(option) ~= "string" or option == "" then
			table.insert(invalid_options, tostring(option))
		end
	end

	if #invalid_options > 0 then
		table.insert(
			errors,
			string.format("%s (%d): opciones inválidas: %s", day_name, day_number, table.concat(invalid_options, ", "))
		)
		logger.check("error", string.format("%s: opciones inválidas", day_name))
		return
	end

	logger.check("ok", string.format("%s (%d): %d opciones", day_name, day_number, #options))
end

local function validate_weekly_schedule(configuration, errors, warnings)
	logger.subsection("calendario semanal")

	if not configuration.weekly_schedule or type(configuration.weekly_schedule) ~= "table" then
		table.insert(errors, "weekly_schedule no definido")
		logger.check("error", "weekly_schedule no definido")
		return
	end

	local missing_days = {}
	for day_number = 1, 7 do
		missing_days[day_number] = day_number
	end

	for day_number, options in pairs(configuration.weekly_schedule) do
		if type(day_number) ~= "number" or day_number < 1 or day_number > 7 then
			table.insert(errors, string.format("día de semana inválido: %s (debe ser 1-7)", tostring(day_number)))
			logger.check("error", string.format("día %s inválido (debe ser 1-7)", tostring(day_number)))
		else
			missing_days[day_number] = nil
			validate_weekly_options(day_number, options, errors, warnings)
		end
	end

	for _, missing_day in pairs(missing_days) do
		table.insert(warnings, string.format("día %d (%s) sin configuración", missing_day, day_names[missing_day]))
		logger.check("warn", string.format("%s (%d) sin configuración", day_names[missing_day], missing_day))
	end
end

local function validate_fallback(configuration, warnings)
	logger.subsection("fallback")

	if not configuration.fallback or type(configuration.fallback) ~= "table" then
		table.insert(warnings, "fallback no definido")
		logger.check("warn", "fallback no definido")
		return
	end

	if configuration.fallback.character then
		logger.check("ok", "fallback.character: " .. configuration.fallback.character)
	else
		table.insert(warnings, "fallback.character no definido")
		logger.check("warn", "fallback.character no definido")
	end
end

-- ---------------------------------------------------------------------------
-- validación de reglas de modo
-- ---------------------------------------------------------------------------

local function validate_single_rule_list(rule_list, label, errors)
	if type(rule_list) ~= "table" or #rule_list == 0 then
		table.insert(errors, label .. ": reglas vacías o inválidas")
		logger.check("error", label .. ": reglas vacías")
		return
	end

	for _, rule in ipairs(rule_list) do
		if not is_valid_policy(rule) then
			table.insert(errors, label .. ": política inválida '" .. tostring(rule) .. "'")
			logger.check("error", label .. ": política inválida '" .. tostring(rule) .. "'")
		else
			local policy_name, policy_param = parse_policy(rule)
			if policy_name == "override" and (not policy_param or policy_param == "") then
				table.insert(errors, label .. ": override requiere parámetro (override:<carpeta>)")
				logger.check("error", label .. ": override sin parámetro")
			else
				logger.check("ok", label .. ": " .. rule)
			end
		end
	end
end

local function validate_mode_rules(configuration, valid_modes, errors, warnings)
	logger.subsection("reglas de modo")

	local mode_rules = configuration.mode_rules

	if not mode_rules or type(mode_rules) ~= "table" then
		table.insert(warnings, "mode_rules no definido (se usará default_rule)")
		logger.check("warn", "mode_rules no definido")
		return
	end

	local modes_with_rules = {}
	for mode_name, rules in pairs(mode_rules) do
		modes_with_rules[mode_name] = true

		local mode_is_known = false
		for _, valid_mode in ipairs(valid_modes) do
			if valid_mode == mode_name then
				mode_is_known = true
				break
			end
		end

		if not mode_is_known then
			table.insert(warnings, "mode_rules contiene modo desconocido: " .. mode_name)
			logger.check("warn", "modo desconocido en mode_rules: " .. mode_name)
		end

		validate_single_rule_list(rules, mode_name, errors)
	end

	for _, mode_name in ipairs(valid_modes) do
		if not modes_with_rules[mode_name] then
			table.insert(warnings, "modo '" .. mode_name .. "' sin reglas (usará default_rule)")
			logger.check("warn", mode_name .. " sin reglas definidas")
		end
	end
end

local function validate_default_rule(configuration, errors)
	logger.subsection("regla por defecto")

	if not configuration.default_rule then
		logger.check("ok", "default_rule no definido (se usará { strict, fallback })")
		return
	end

	validate_single_rule_list(configuration.default_rule, "default_rule", errors)
end

local function validate_override_folders(configuration, errors, warnings)
	logger.subsection("carpetas override")

	local has_override = false

	local function check_rules(rule_list, label)
		if type(rule_list) ~= "table" then
			return
		end
		for _, rule in ipairs(rule_list) do
			local policy_name, policy_param = parse_policy(rule)
			if policy_name == "override" and policy_param then
				has_override = true
				local folder_path = configuration.base_directory .. "/" .. policy_param
				if not filesystem.directory_exists(folder_path) then
					table.insert(errors, label .. ": carpeta override no existe: " .. folder_path)
					logger.check("error", label .. " → " .. policy_param .. " no existe")
				else
					local file_count = filesystem.count_files_in_directory(folder_path)
					if file_count == 0 then
						table.insert(warnings, label .. ": carpeta override vacía: " .. policy_param)
						logger.check("warn", label .. " → " .. policy_param .. " vacía")
					else
						logger.check("ok", label .. " → " .. policy_param .. " (" .. file_count .. " archivos)")
					end
				end
			end
		end
	end

	if configuration.mode_rules then
		for mode_name, rules in pairs(configuration.mode_rules) do
			check_rules(rules, mode_name)
		end
	end

	if configuration.default_rule then
		check_rules(configuration.default_rule, "default_rule")
	end

	if not has_override then
		logger.check("ok", "sin políticas override, nada que validar")
	end
end

-- ---------------------------------------------------------------------------
-- validación de rutas de eventos
-- ---------------------------------------------------------------------------

local function collect_all_events(configuration)
	local all_events = {}
	local seen_events = {}

	local function add_event(event_name)
		if not seen_events[event_name] then
			table.insert(all_events, event_name)
			seen_events[event_name] = true
		end
	end

	for _, event_name in pairs(configuration.birthdays or {}) do
		add_event(event_name)
	end

	for _, options in pairs(configuration.weekly_schedule or {}) do
		if type(options) == "table" then
			for _, event_name in ipairs(options) do
				add_event(event_name)
			end
		end
	end

	local fallback_character = configuration.fallback and configuration.fallback.character
	if fallback_character then
		add_event(fallback_character)
	end

	return all_events
end

local function validate_event_paths(configuration, errors, warnings)
	logger.subsection("rutas de eventos")

	local all_events = collect_all_events(configuration)
	local existing_events_count = 0
	local total_files_count = 0

	for _, event_name in ipairs(all_events) do
		local base_path = configuration.base_directory .. "/" .. event_name

		if not filesystem.directory_exists(base_path) then
			table.insert(warnings, string.format("carpeta no encontrada: %s", event_name))
			logger.check("warn", string.format("%s → carpeta no encontrada", event_name))
		else
			local file_count = filesystem.count_files_in_directory(base_path)
			total_files_count = total_files_count + file_count
			existing_events_count = existing_events_count + 1
			logger.check("ok", string.format("%s → %d archivos", event_name, file_count))
		end
	end

	if existing_events_count == 0 then
		table.insert(errors, "ningún evento tiene carpeta existente")
		logger.check("error", "ningún evento tiene carpeta existente")
	else
		io.stderr:write(
			string.format(
				"\n[resultado] %d eventos con carpetas, %d archivos totales\n",
				existing_events_count,
				total_files_count
			)
		)
	end
end

-- ---------------------------------------------------------------------------
-- simulación del flujo actual
-- ---------------------------------------------------------------------------

local function simulate_current_flow(configuration, errors, warnings)
	logger.subsection("simulación del flujo actual")

	local selector = require("selector")
	local resolver = require("resolver")
	local date_utils_mod = require("date_utils")

	local date_info = date_utils_mod.get_current_date_info()
	local empty_history = {
		usage_count = {},
		last_used = {},
		current_cycle = {},
		daily_assignments = {},
	}

	local selected_event = selector.get_daily_assignment(configuration, date_info, empty_history)
	if not selected_event then
		table.insert(errors, "no se pudo seleccionar un evento para hoy")
		logger.check("error", "no se pudo seleccionar evento")
		return
	end

	logger.check("ok", "evento seleccionado: " .. selected_event)

	local selected_image = resolver.resolve_image_path(configuration, selected_event)
	if not selected_image then
		table.insert(errors, "no se encontró imagen para el evento '" .. selected_event .. "' con las reglas actuales")
		logger.check("error", "sin imagen para: " .. selected_event)
	else
		logger.check("ok", "imagen encontrada: " .. selected_image)
	end
end

-- ---------------------------------------------------------------------------
-- entrada principal
-- ---------------------------------------------------------------------------

function M.validate_configuration(configuration)
	local errors = {}
	local warnings = {}

	logger.section("Validación de configuración")

	validate_base_directory(configuration, errors)
	validate_mode(configuration, errors)

	local valid_modes = validate_modes_list(configuration, errors, warnings)
	validate_active_mode(configuration, valid_modes, errors, warnings)

	validate_birthdays(configuration, errors, warnings)
	validate_weekly_schedule(configuration, errors, warnings)
	validate_fallback(configuration, warnings)

	validate_default_rule(configuration, errors)
	validate_mode_rules(configuration, valid_modes, errors, warnings)
	validate_override_folders(configuration, errors, warnings)

	validate_event_paths(configuration, errors, warnings)

	-- NOTE: la simulación se salta si hay errores críticos previos
	if #errors == 0 then
		simulate_current_flow(configuration, errors, warnings)
	else
		logger.subsection("simulación del flujo actual")
		logger.check("warn", "omitida por errores previos en la configuración")
	end

	return errors, warnings
end

return M
