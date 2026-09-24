class_name TileModuleRole
extends RefCounted

## Wizualna abstrakcja MODUŁU żądana z nowego systemu (osobna od granularnych ról
## EdgeAnalyzera). Placer/adapter zamienia geometrię (np. FACADE_TOP_2H w kotwicy)
## na jedno żądanie modułu (FACADE_2H) w znanej pozycji.


enum Id {
	NONE = 0,
	FLOOR,
	SOLID_FILL,
	FACADE_2H,
	FACADE_3H,
	STEP_LEFT,
	STEP_RIGHT,
	CONNECTOR_LEFT,
	CONNECTOR_RIGHT,
	SLOPE_LEFT,
	SLOPE_RIGHT,
	SIDE_WALL_EAST,
	SIDE_WALL_WEST,
	OUT_CORNER_WEST,
	OUT_CORNER_EAST,
	INNER_CORNER_NW,
	INNER_CORNER_NE,
	INNER_CORNER_SW,
	INNER_CORNER_SE,
	RIM_NORTH,
	RIM_EAST,
	RIM_WEST,
	NICHE_STANDARD,
	NICHE_SECRET,
	STAIR_LEFT,
	STAIR_MID,
	STAIR_RIGHT,
	STAIR_NORTH_LEFT,
	STAIR_NORTH_MID,
	STAIR_NORTH_RIGHT,
	STAIR_SINGLE,
	STAIR_NORTH_SINGLE,
	STAIR_EAST_3H,
	STAIR_EAST_1H,
	STAIR_WEST_3H,
	STAIR_WEST_1H,
}

## Klucz, pod którym NamedTileSetDefinition przechowuje wpis danego modułu
## (reużywamy istniejący enum TileRole.Id jako klucz TileRoleEntry.role).
static func to_storage_role(module_role: Id) -> int:
	match module_role:
		Id.FLOOR: return TileRole.Id.FLOOR_BASE
		Id.SOLID_FILL: return TileRole.Id.SOLID_FILL
		Id.FACADE_2H: return TileRole.Id.FACADE_2H
		Id.FACADE_3H: return TileRole.Id.FACADE_3H
		Id.STEP_LEFT: return TileRole.Id.STEP_LEFT
		Id.STEP_RIGHT: return TileRole.Id.STEP_RIGHT
		Id.CONNECTOR_LEFT: return TileRole.Id.CONNECTOR_LEFT
		Id.CONNECTOR_RIGHT: return TileRole.Id.CONNECTOR_RIGHT
		Id.SLOPE_LEFT: return TileRole.Id.SLOPE_LEFT
		Id.SLOPE_RIGHT: return TileRole.Id.SLOPE_RIGHT
		Id.SIDE_WALL_EAST: return TileRole.Id.SIDE_WALL_EAST
		Id.SIDE_WALL_WEST: return TileRole.Id.SIDE_WALL_WEST
		Id.OUT_CORNER_WEST: return TileRole.Id.OUTER_CORNER_NW
		Id.OUT_CORNER_EAST: return TileRole.Id.OUTER_CORNER_NE
		Id.INNER_CORNER_NW: return TileRole.Id.INNER_CORNER_NW
		Id.INNER_CORNER_NE: return TileRole.Id.INNER_CORNER_NE
		Id.INNER_CORNER_SW: return TileRole.Id.INNER_CORNER_SW
		Id.INNER_CORNER_SE: return TileRole.Id.INNER_CORNER_SE
		Id.RIM_NORTH: return TileRole.Id.RIM_NORTH
		Id.RIM_EAST: return TileRole.Id.RIM_EAST
		Id.RIM_WEST: return TileRole.Id.RIM_WEST
		Id.NICHE_STANDARD: return TileRole.Id.NICHE_STANDARD
		Id.NICHE_SECRET: return TileRole.Id.NICHE_SECRET
		Id.STAIR_LEFT: return TileRole.Id.STAIR_LEFT
		Id.STAIR_MID: return TileRole.Id.STAIR_MID
		Id.STAIR_RIGHT: return TileRole.Id.STAIR_RIGHT
		Id.STAIR_NORTH_LEFT: return TileRole.Id.STAIR_NORTH_LEFT
		Id.STAIR_NORTH_MID: return TileRole.Id.STAIR_NORTH_MID
		Id.STAIR_NORTH_RIGHT: return TileRole.Id.STAIR_NORTH_RIGHT
		Id.STAIR_SINGLE: return TileRole.Id.STAIR_SINGLE
		Id.STAIR_NORTH_SINGLE: return TileRole.Id.STAIR_NORTH_SINGLE
		Id.STAIR_EAST_3H: return TileRole.Id.STAIR_EAST_3H
		Id.STAIR_EAST_1H: return TileRole.Id.STAIR_EAST_1H
		Id.STAIR_WEST_3H: return TileRole.Id.STAIR_WEST_3H
		Id.STAIR_WEST_1H: return TileRole.Id.STAIR_WEST_1H
		_: return TileRole.Id.NONE

## Ile części ma mieć poprawny moduł (0 = dowolnie). Do walidacji kształtu.
static func expected_part_count(module_role: Id) -> int:
	match module_role:
		Id.FACADE_2H: return 2
		Id.FACADE_3H: return 3
		Id.STAIR_LEFT, Id.STAIR_MID, Id.STAIR_RIGHT: return 2
		Id.STAIR_NORTH_LEFT, Id.STAIR_NORTH_MID, Id.STAIR_NORTH_RIGHT: return 2
		Id.STAIR_SINGLE, Id.STAIR_NORTH_SINGLE: return 2
		Id.STAIR_EAST_1H, Id.STAIR_WEST_1H: return 2
		Id.STAIR_EAST_3H, Id.STAIR_WEST_3H: return 6
		_: return 0

static func name_of(module_role: int) -> String:
	var keys := Id.keys()
	if module_role >= 0 and module_role < keys.size():
		return keys[module_role]
	return "UNKNOWN(%d)" % module_role
