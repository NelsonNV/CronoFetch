local M = {}

local logger = require("logger")

function M.calculate_weights(item_list, history)
	local weights = {}
	for _, folder_name in ipairs(item_list) do
		local usage_count = history.usage_count[folder_name] or 0
		local weight = 1 / (usage_count + 1)
		table.insert(weights, weight)
		logger.verbose(string.format("  %s: usado %d semanas, peso %.2f", folder_name, usage_count, weight))
	end
	return weights
end

function M.update_usage_tracking(history, event_name, date_info)
	local last_used_info = history.last_used[event_name]

	local already_used_this_week = last_used_info
		and last_used_info.week == date_info.week_of_year
		and last_used_info.year == date_info.year

	if not already_used_this_week then
		history.usage_count[event_name] = (history.usage_count[event_name] or 0) + 1
		logger.verbose("Contador incrementado para " .. event_name .. ": " .. history.usage_count[event_name])
	end

	history.last_used[event_name] = {
		week = date_info.week_of_year,
		year = date_info.year,
	}
end

return M
