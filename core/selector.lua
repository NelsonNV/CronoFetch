local M = {}

local logger = require("logger")
local tracker = require("tracker")

local function select_from_unused(item_list, current_cycle)
	local unused_folders = {}
	for _, folder_name in ipairs(item_list) do
		if not current_cycle[folder_name] then
			table.insert(unused_folders, folder_name)
		end
	end

	if #unused_folders == 0 then
		return nil
	end

	local random_index = math.random(1, #unused_folders)
	return unused_folders[random_index]
end

local function weighted_random_selection(item_list, weights)
	local total_weight = 0
	for _, weight in ipairs(weights) do
		total_weight = total_weight + weight
	end

	local random_value = math.random() * total_weight
	local cumulative_weight = 0

	for index, weight in ipairs(weights) do
		cumulative_weight = cumulative_weight + weight
		if random_value <= cumulative_weight then
			return item_list[index]
		end
	end

	return item_list[#item_list]
end

function M.select_event_with_history(item_list, history)
	if type(item_list) == "string" then
		return item_list
	end

	local unused_selection = select_from_unused(item_list, history.current_cycle)
	if unused_selection then
		logger.verbose("Seleccionado de carpetas no usadas en este ciclo")
		return unused_selection
	end

	logger.verbose("Todas las carpetas usadas en este ciclo, reseteando")
	history.current_cycle = {}

	local weights = tracker.calculate_weights(item_list, history)
	return weighted_random_selection(item_list, weights)
end

function M.get_daily_assignment(configuration, date_info, history)
	local weekday = date_info.weekday
	local current_assignment = history.daily_assignments[weekday]

	if current_assignment and current_assignment.date == date_info.date_string then
		logger.verbose("Asignación diaria existente: " .. current_assignment.event)
		return current_assignment.event
	end

	local birthday_event = configuration.birthdays and configuration.birthdays[date_info.month_day]
	if birthday_event then
		logger.verbose("Cumpleaños detectado: " .. birthday_event)
		return birthday_event
	end

	local weekly_options = configuration.weekly_schedule and configuration.weekly_schedule[weekday]
	if weekly_options then
		local selected = M.select_event_with_history(weekly_options, history)
		logger.verbose("Nueva asignación para hoy: " .. selected)
		history.daily_assignments[weekday] = {
			date = date_info.date_string,
			event = selected,
		}
		return selected
	end

	local fallback_character = configuration.fallback and configuration.fallback.character
	logger.verbose("Sin evento, usando fallback: " .. tostring(fallback_character))
	return fallback_character
end

return M
