# CronoFetch

Selector inteligente de logos/imágenes para fastfetch basado en calendario semanal, cumpleaños y reglas configurables.


## Instalación

```bash
# 1. Clonar repositorio (o copiar los archivos) a tu configuración de fastfetch
git clone https://github.com/NelsonNV/CronoFetch ~/.config/fastfetch

# 2. Copiar la configuración de ejemplo
cp ~/.config/fastfetch/config.example.lua ~/.config/fastfetch/config.lua

# 3. Editar con tus rutas y eventos
nvim ~/.config/fastfetch/config.lua
```

## Configuración

### Estructura básica (`config.lua`)

```lua
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
```

### Campos explicados

#### `base_directory`
Ruta absoluta al directorio base donde están todas las carpetas de eventos.
```lua
base_directory = "/home/usuario/fastfetch/images"
```

#### `mode`
Modo activo actual. Se puede cambiar dinámicamente con los flags `-m` o `-t`.
```lua
mode = "estandar"
```

#### `modes`
Lista de modos disponibles para el toggle cíclico.
```lua
modes = { "estandar", "completo", "anime" }
```

#### `mode_rules`
Políticas de resolución para cada modo. Se aplican en orden hasta encontrar una imagen válida.
```lua
mode_rules = {
	estandar = { "strict", "fallback" },      -- primero estricto, si falla usa respaldo
	completo = { "permissive" },              -- busca en la carpeta del evento ignorando el modo
	anime = { "override:anime_folder" },      -- ignora el evento del día, usa carpeta global
}
```

#### `default_rule`
Regla por defecto para modos que no tienen `mode_rules` definido explícitamente.
```lua
default_rule = { "strict", "fallback" }
```

#### `birthdays`
Eventos especiales en fechas específicas (formato obligatorio `MM-DD`).
```lua
birthdays = {
	["01-15"] = "cumpleaños_juan",
	["12-25"] = "navidad",
}
```

#### `weekly_schedule`
Opciones por día de la semana (`1`=lunes, `7`=domingo). Puede ser un string (opción única) o una tabla de strings (múltiples opciones con selección ponderada).
```lua
weekly_schedule = {
	[1] = { "evento_lunes_1", "evento_lunes_2" },
	[2] = "evento_martes",
	-- ...
}
```

#### `fallback`
Evento de respaldo cuando no hay nada configurado o todas las reglas fallan.
```lua
fallback = {
	character = "fallback_default",
}
```

## Sistema de políticas

Las políticas definen **cómo** se buscan las imágenes. Se aplican en el orden que las declares hasta que una tenga éxito.

| Política             | Comportamiento                                      |
| -------------------- | --------------------------------------------------- |
| `strict`             | Solo busca en `base_directory/evento/mode/`         |
| `permissive`         | Busca en `base_directory/evento/` ignorando el modo |
| `override:<carpeta>` | Ignora eventos del día, usa una carpeta global especial |
| `fallback`           | Usa el evento definido en `fallback.character`      |
| `mixed`              | Primero `strict`, si falla usa `permissive`         |

### Ejemplos de combinaciones

```lua
-- Estricto con respaldo (recomendado para modo estándar)
estandar = { "strict", "fallback" }

-- Flexible sin restricciones (muestra cualquier imagen del evento)
completo = { "permissive" }

-- Carpeta global temática con respaldo
anime = { "override:ilustraciones", "fallback" }
```

## Estructura de directorios esperada

```text
base_directory/
├── evento_lunes_1/
│   ├── estandar/
│   │   ├── imagen1.png
│   │   └── imagen2.jpg
│   └── completo/
│       └── imagen3.png
├── cumpleaños_juan/
│   └── imagenes...
├── ilustraciones/          # para override
│   └── imagenes...
└── fallback_default/
    └── imagenes...
```

## Comandos CLI

### Gestión de Modos

```bash
# Cambiar a un modo específico
lua $HOME/.config/fastfetch/main.lua -m estandar
lua $HOME/.config/fastfetch/main.lua --change-mode completo

# Toggle cíclico entre los modos configurados
lua $HOME/.config/fastfetch/main.lua -t
lua $HOME/.config/fastfetch/main.lua --toggle-mode

# Agregar un nuevo modo a la lista en config.lua
lua $HOME/.config/fastfetch/main.lua --mode-add cyberpunk
```

### Gestión de Reglas

```bash
# Ver reglas actuales de un modo
lua $HOME/.config/fastfetch/main.lua --rule-show estandar

# Establecer reglas de un modo (reemplaza las existentes)
lua $HOME/.config/fastfetch/main.lua --rule-set completo "permissive,fallback"

# Agregar una regla al final de la lista de un modo
lua $HOME/.config/fastfetch/main.lua --rule-add estandar "mixed"

# Quitar una regla específica de un modo
lua $HOME/.config/fastfetch/main.lua --rule-remove estandar "fallback"

# Cambiar la regla por defecto global
lua $HOME/.config/fastfetch/main.lua --rule-default "strict,fallback"

# Listar todas las políticas disponibles y su descripción
lua $HOME/.config/fastfetch/main.lua --rule-list
```

### Validación y Debug

```bash
# Validar configuración completa (recomendado tras cada cambio)
lua $HOME/.config/fastfetch/main.lua -c
lua $HOME/.config/fastfetch/main.lua --check

# Modo verbose (muestra todo el proceso de decisión paso a paso)
lua $HOME/.config/fastfetch/main.lua -v
lua $HOME/.config/fastfetch/main.lua --verbose
```

## Integración con fastfetch

El script está diseñado para usarse como la fuente (`source`) dinámica del módulo `logo` en tu configuración de fastfetch (`config.jsonc` o `config.json`).

Simplemente asigna la ejecución del script a la propiedad `source` dentro del objeto `logo`.

### Ejemplo de configuración (`config.jsonc`)

```json
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "$(lua $HOME/.config/fastfetch/main.lua)",
    "color": {
      "1": "blue",
      "2": "black"
    },
    "padding": {
      "top": 2,
      "right": 5
    },
    "height": 18
  },
  "display": {
    "separator": " ▸ "
  },
  "modules": [
    "title",
    "break",
    "os",
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "display",
    "de",
    "wm",
    "cpu",
    "gpu",
    "memory",
    "disk",
    "break",
    "colors"
  ]
}
```

> **Nota importante:** Usa siempre la ruta absoluta (`$HOME/.config/fastfetch/main.lua` o `/home/tu_usuario/...`) en el `source`. Fastfetch a veces se ejecuta desde directorios de trabajo distintos, y el script necesita saber dónde está para cargar sus módulos internos correctamente.

## Flujo de selección interno

1. **Cumpleaños**: Si la fecha actual coincide con una entrada en `birthdays`, usa ese evento (prioridad máxima).
2. **Calendario semanal**: Selecciona de las opciones del día actual en `weekly_schedule`.
   - Prioriza eventos no usados en el ciclo actual.
   - Si todos fueron usados, resetea el ciclo.
   - Aplica selección ponderada (menos uso histórico = mayor probabilidad).
3. **Fallback**: Si no hay evento configurado para el día, usa `fallback.character`.
4. **Resolución de imagen**: Aplica las políticas del `mode_rules` del modo activo en orden hasta encontrar un archivo.

