class_name TileRole
extends RefCounted

## Rola LOGICZNA kafelka w generatorze. Opisuje wyłącznie geometrię (co to za element
## ściany/podłogi), NIE grafikę i NIE zestaw, z którego kafelek pochodzi. Mapowanie
## rola -> konkretny kafelek atlasu żyje w NamedTileSetDefinition (.tres).
enum Id {
	NONE = 0,

	FLOOR_BASE,
	FLOOR_DECOR,
	SOLID_FILL,

	RIM_NORTH,
	RIM_SOUTH,
	RIM_EAST,
	RIM_WEST,

	SIDE_WALL_EAST,
	SIDE_WALL_WEST,

	FACADE_TOP_1H,
	FACADE_BASE_1H,
	FACADE_TOP_2H,
	FACADE_MID_2H,
	FACADE_BASE_2H,
	FACADE_TOP_3H,
	FACADE_MID_3H,
	FACADE_BASE_3H,

	INNER_CORNER_NE,
	INNER_CORNER_NW,
	INNER_CORNER_SE,
	INNER_CORNER_SW,

	OUTER_CORNER_NE,
	OUTER_CORNER_NW,
	OUTER_CORNER_SE,
	OUTER_CORNER_SW,

	STEP_LEFT,
	STEP_RIGHT,
	CONNECTOR_LEFT,
	CONNECTOR_RIGHT,
	SLOPE_LEFT,
	SLOPE_RIGHT,

	# --- Faza 2: klucze przechowywania modułów (dopisane na końcu, bez renumeracji
	# istniejących granularnych ról). Pod tymi kluczami NamedTileSetDefinition trzyma
	# wpisy modułów wielokaflowych (fasady). Granularne role zostają dla EdgeAnalyzera.
	FACADE_2H,
	FACADE_3H,
	NICHE_STANDARD,
	NICHE_SECRET,
}


## Nazwa roli (do logów/walidacji). Bezpieczne dla wartości spoza enuma.
static func name_of(role: int) -> String:
	var keys := Id.keys()
	if role >= 0 and role < keys.size():
		return keys[role]
	return "UNKNOWN(%d)" % role
