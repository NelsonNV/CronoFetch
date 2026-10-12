local logger = require("logger")

local filesystem = require("filesystem")

local M = {}

local function select_random_file(directory_path)
	local files = filesystem.get_files_in_directory(directory_path)
	if #files == 0 then
		return nil
	end
	local random_index = math.random(1, #files)
	return files[random_index]
end

local function try_directory(full_path)
	logger.verbose("Intentando: " .. full_path)
	local selected_file = select_random_file(full_path)
	if selected_file then
		logger.verbose("Encontrado: " .. selected_file)
		return selected_file
	end
	logger.verbose("No existe o vacío")
	return nil
end

local function parse_policy(policy_string)
	local policy_name, policy_param = policy_string:match("^([^:]+):(.+)$")
	if policy_name then
		return policy_name, policy_param
	end
	return policy_string, nil
end

local function apply_strict_policy(configuration, event_name)
	local base_path = configuration.base_directory
	local mode = configuration.mode
	return try_directory(base_path .. "/" .. event_name .. "/" .. mode)
end

local function apply_permissive_policy(configuration, event_name)
	local base_path = configuration.base_directory
	return try_directory(base_path .. "/" .. event_name)
end

local function apply_override_policy(configuration, folder_name)
	local base_path = configuration.base_directory
	return try_directory(base_path .. "/" .. folder_name)
end

local function apply_fallback_policy(configuration)
	local fallback_name = configuration.fallback and configuration.fallback.character
	if not fallback_name then
		return nil
	end

	local base_path = configuration.base_directory
	local mode = configuration.mode

	local found_image = try_directory(base_path .. "/" .. fallback_name .. "/" .. mode)
	if found_image then
		return found_image
	end

	return try_directory(base_path .. "/" .. fallback_name)
end

local function apply_mixed_policy(configuration, event_name)
	local found_image = apply_strict_policy(configuration, event_name)
	if found_image then
		return found_image
	end
	return apply_permissive_policy(configuration, event_name)
end

local function apply_policy(policy_name, policy_param, configuration, event_name)
	if policy_name == "strict" then
		return apply_strict_policy(configuration, event_name)
	elseif policy_name == "permissive" then
		return apply_permissive_policy(configuration, event_name)
	elseif policy_name == "override" then
		return apply_override_policy(configuration, policy_param)
	elseif policy_name == "fallback" then
		return apply_fallback_policy(configuration)
	elseif policy_name == "mixed" then
		return apply_mixed_policy(configuration, event_name)
	else
		logger.verbose("Política desconocida: " .. policy_name)
		return nil
	end
end

local function get_rule_for_mode(configuration)
	local mode_rules = configuration.mode_rules or {}
	local current_mode = configuration.mode

	if mode_rules[current_mode] then
		return mode_rules[current_mode]
	end

	return configuration.default_rule or { "strict", "fallback" }
end

function M.resolve_image_path(configuration, event_name)
	math.randomseed(os.time())

	local rule = get_rule_for_mode(configuration)
	logger.verbose("Regla activa: " .. table.concat(rule, ", "))

	for _, policy in ipairs(rule) do
		local policy_name, policy_param = parse_policy(policy)
		logger.verbose("Aplicando política: " .. policy)

		local found_image = apply_policy(policy_name, policy_param, configuration, event_name)
		if found_image then
			return found_image
		end
	end

	return nil
end

return M
