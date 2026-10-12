local M = {}

function M.get_current_date_info()
	local timestamp = os.time()
	return {
		month_day = os.date("%m-%d", timestamp),
		weekday = tonumber(os.date("%u", timestamp)),
		week_of_year = tonumber(os.date("%V", timestamp)),
		year = tonumber(os.date("%Y", timestamp)),
		date_string = os.date("%Y-%m-%d", timestamp),
	}
end

function M.is_leap_year(year)
	return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

function M.days_in_month(month, year)
	local days_per_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	if month == 2 and M.is_leap_year(year) then
		return 29
	end
	return days_per_month[month]
end

function M.validate_date_format(date_string)
	local month, day = date_string:match("^(%d%d)-(%d%d)$")
	if not month or not day then
		return false, "formato inválido (esperado MM-DD)"
	end

	local month_number = tonumber(month)
	local day_number = tonumber(day)

	if month_number < 1 or month_number > 12 then
		return false, string.format("mes %d fuera de rango (1-12)", month_number)
	end

	local current_year = tonumber(os.date("%Y"))
	local max_days = M.days_in_month(month_number, current_year)

	if day_number < 1 or day_number > max_days then
		return false, string.format("día %d fuera de rango para el mes %d (1-%d)", day_number, month_number, max_days)
	end

	return true, nil
end

return M
