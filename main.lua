local script_directory = arg[0]:match("(.*/)") or "./"
package.path = script_directory
	.. "core/?.lua;"
	.. script_directory
	.. "services/?.lua;"
	.. script_directory
	.. "utils/?.lua;"
	.. package.path

local args = require("args")
local logger = require("logger")
local setup = require("setup")
local state = require("state")
local date_utils = require("date_utils")
local selector = require("selector")
local resolver = require("resolver")
local tracker = require("tracker")
local validator = require("validator")
local filesystem = require("filesystem")

local parsed_arguments = args.parse()
logger.init(parsed_arguments.verbose)

local function run_check_mode()
	local configuration = setup.load_configuration()
	local errors, warnings = validator.validate_configuration(configuration)

	logger.section("Resumen")
	io.stderr:write(string.format("Errores: %d\n", #errors))
	io.stderr:write(string.format("Advertencias: %d\n", #warnings))

	if #errors > 0 then
		io.stderr:write("\n[errores]\n")
		for _, error_message in ipairs(errors) do
			io.stderr:write("  ✗ " .. error_message .. "\n")
		end
	end

	if #warnings > 0 then
		io.stderr:write("\n[advertencias]\n")
		for _, warning_message in ipairs(warnings) do
			io.stderr:write("  ⚠ " .. warning_message .. "\n")
		end
	end

	if #errors == 0 then
		io.stderr:write("\n✓ Configuración válida\n")
		os.exit(0)
	end

	io.stderr:write("\n✗ Configuración inválida\n")
	os.exit(1)
end

local function run_main_flow()
	local configuration = setup.load_configuration()
	local date_info = date_utils.get_current_date_info()
	local current_state = state.load()

	logger.verbose("Modo: " .. configuration.mode)
	logger.verbose("Fecha: " .. date_info.date_string)

	local selected_event = selector.get_daily_assignment(configuration, date_info, current_state)
	logger.verbose("Evento final: " .. selected_event)

	local selected_image = resolver.resolve_image_path(configuration, selected_event)

	if not selected_image then
		logger.error("No valid image found")
		os.exit(1)
	end

	current_state.current_cycle[selected_event] = true
	tracker.update_usage_tracking(current_state, selected_event, date_info)

	state.save(current_state)
	state.log_execution(selected_event, selected_image)

	print(filesystem.escape_path_for_shell(selected_image))
end

if parsed_arguments.rule_list then
	setup.list_policies()
elseif parsed_arguments.rule_show then
	local configuration = setup.load_configuration()
	setup.show_rule(parsed_arguments.rule_show, configuration)
elseif parsed_arguments.rule_set then
	setup.set_rule(parsed_arguments.rule_set.mode, parsed_arguments.rule_set.rules)
elseif parsed_arguments.rule_add then
	setup.add_rule(parsed_arguments.rule_add.mode, parsed_arguments.rule_add.rule)
elseif parsed_arguments.rule_remove then
	setup.remove_rule(parsed_arguments.rule_remove.mode, parsed_arguments.rule_remove.rule)
elseif parsed_arguments.rule_default then
	setup.set_default_rule(parsed_arguments.rule_default)
elseif parsed_arguments.mode_add then
	setup.add_mode(parsed_arguments.mode_add)
elseif parsed_arguments.change_mode then
	local configuration = setup.load_configuration()
	setup.change_mode(parsed_arguments.change_mode, configuration)
elseif parsed_arguments.toggle_mode then
	local configuration = setup.load_configuration()
	setup.toggle_mode(configuration)
elseif parsed_arguments.check then
	run_check_mode()
else
	run_main_flow()
end
