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

	# --- Platformy: schody w licu klifu 2H (moduły 2-częściowe: base (0,0) + top (0,-1)).
	STAIR_LEFT,
	STAIR_MID,
	STAIR_RIGHT,

	# --- Platformy: schody w rimie północnym (moduły 2-częściowe: base (0,0) + top (0,-1)).
	STAIR_NORTH_LEFT,
	STAIR_NORTH_MID,
	STAIR_NORTH_RIGHT,

	# --- Platformy: schody pojedyncze 1W (South / North)
	STAIR_SINGLE,
	STAIR_NORTH_SINGLE,

	# --- Platformy: schody boczne (East / West, 1H i 3H)
	STAIR_EAST_3H,
	STAIR_EAST_1H,
	STAIR_WEST_3H,
	STAIR_WEST_1H,
	# --- Korona lica 3H (kafel nad górą lica, rząd -3, gdy ściana głębsza niż 3). Opcjonalna:
	# brak wpisu w profilu -> stała placera (caves).
	FACADE_CROWN_3H,
	# --- Lico 4H (moduł 4-częściowy: base (0,0), mid (0,-1), mid (0,-2), top (0,-3)). Opcjonalne:
	# flaga enable_4h_facades + wpis w profilu; inaczej 3H z koroną.
	FACADE_4H,
	# Końce lica 4H (narożniki OUT i schodki, 4 części jak FACADE_4H).
	OUTER_CORNER_NW_4H,
	OUTER_CORNER_NE_4H,
	STEP_LEFT_4H,
	STEP_RIGHT_4H,
	# Kanały ścieków (CanalPlacer): kwas, lico brzegu, obrzeża na podłodze — wariant = układ sąsiedztwa;
	# kładki pionowa / pozioma jako moduły na cały ślad.
	CANAL_WATER,
	CANAL_FACE,
	CANAL_BANK,
	BRIDGE_V,
	BRIDGE_H,
	# Puste koryto (kanał bez kwasu, flaga canal_dry_chance) — warianty jak CANAL_WATER.
	CANAL_BED,
	# Doły w pustym korycie (czarna pustka): VOID, TOP / TOP_B (pierwszy rząd pod kamieniem — wiszące kołki),
	# BOTTOM (ostatni rząd nad kamieniem — stojące kołki).
	CANAL_PIT,
}


## Nazwa roli (do logów/walidacji). Bezpieczne dla wartości spoza enuma.
static func name_of(role: int) -> String:
	var keys := Id.keys()
	if role >= 0 and role < keys.size():
		return keys[role]
	return "UNKNOWN(%d)" % role
