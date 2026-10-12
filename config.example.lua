return {
	base_directory = "/ruta/a/tu/directorio/base",
	mode = "estandar",
	modes = { "estandar", "completo", "anime" },

	mode_rules = {
		estandar = { "strict", "fallback" },
		completo = { "permissive" },
		anime = { "override:anime_folder", "fallback" },
	},

	default_rule = { "strict", "fallback" },

	birthdays = {
		["01-15"] = "cumpleaños_juan",
		["12-25"] = "navidad",
	},

	weekly_schedule = {
		[1] = { "evento_lunes_1", "evento_lunes_2" },
		[2] = "evento_martes",
		[3] = { "evento_miercoles_1", "evento_miercoles_2" },
		[4] = "evento_jueves",
		[5] = { "evento_viernes_1", "evento_viernes_2" },
		[6] = "evento_sabado",
		[7] = "evento_domingo",
	},

	fallback = {
		character = "fallback_default",
	},
}
