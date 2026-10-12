local M = {}

function M.parse()
	local arguments = {
		verbose = false,
		check = false,
		change_mode = nil,
		toggle_mode = false,
		mode_add = nil,
		rule_show = nil,
		rule_set = nil,
		rule_add = nil,
		rule_remove = nil,
		rule_default = nil,
		rule_list = false,
	}

	local argument_index = 1
	while argument_index <= #arg do
		local argument = arg[argument_index]

		if argument == "-v" or argument == "--verbose" then
			arguments.verbose = true
		elseif argument == "-c" or argument == "--check" then
			arguments.check = true
		elseif argument == "-m" or argument == "--change-mode" then
			local mode_name = arg[argument_index + 1]
			if not mode_name or mode_name:sub(1, 1) == "-" then
				io.stderr:write("ERROR: --change-mode requiere un nombre de modo\n")
				os.exit(1)
			end
			arguments.change_mode = mode_name
			argument_index = argument_index + 1
		elseif argument == "-t" or argument == "--toggle-mode" then
			arguments.toggle_mode = true
		elseif argument == "--mode-add" then
			local mode_name = arg[argument_index + 1]
			if not mode_name or mode_name:sub(1, 1) == "-" then
				io.stderr:write("ERROR: --mode-add requiere un nombre de modo\n")
				os.exit(1)
			end
			arguments.mode_add = mode_name
			argument_index = argument_index + 1
		elseif argument == "--rule-show" then
			local mode_name = arg[argument_index + 1]
			if not mode_name or mode_name:sub(1, 1) == "-" then
				io.stderr:write("ERROR: --rule-show requiere un nombre de modo\n")
				os.exit(1)
			end
			arguments.rule_show = mode_name
			argument_index = argument_index + 1
		elseif argument == "--rule-set" then
			local mode_name = arg[argument_index + 1]
			local rules_string = arg[argument_index + 2]
			if not mode_name or mode_name:sub(1, 1) == "-" or not rules_string or rules_string:sub(1, 1) == "-" then
				io.stderr:write("ERROR: --rule-set requiere <modo> <reglas>\n")
				os.exit(1)
			end
			arguments.rule_set = { mode = mode_name, rules = rules_string }
			argument_index = argument_index + 2
		elseif argument == "--rule-add" then
			local mode_name = arg[argument_index + 1]
			local rule_name = arg[argument_index + 2]
			if not mode_name or mode_name:sub(1, 1) == "-" or not rule_name or rule_name:sub(1, 1) == "-" then
				io.stderr:write("ERROR: --rule-add requiere <modo> <regla>\n")
				os.exit(1)
			end
			arguments.rule_add = { mode = mode_name, rule = rule_name }
			argument_index = argument_index + 2
		elseif argument == "--rule-remove" then
			local mode_name = arg[argument_index + 1]
			local rule_name = arg[argument_index + 2]
			if not mode_name or mode_name:sub(1, 1) == "-" or not rule_name or rule_name:sub(1, 1) == "-" then
				io.stderr:write("ERROR: --rule-remove requiere <modo> <regla>\n")
				os.exit(1)
			end
			arguments.rule_remove = { mode = mode_name, rule = rule_name }
			argument_index = argument_index + 2
		elseif argument == "--rule-default" then
			local rules_string = arg[argument_index + 1]
			if not rules_string or rules_string:sub(1, 1) == "-" then
				io.stderr:write("ERROR: --rule-default requiere <reglas>\n")
				os.exit(1)
			end
			arguments.rule_default = rules_string
			argument_index = argument_index + 1
		elseif argument == "--rule-list" then
			arguments.rule_list = true
		end

		argument_index = argument_index + 1
	end

	return arguments
end

return M
