class_name TileModuleRole
extends RefCounted

## Wizualna abstrakcja MODUŁU żądana z nowego systemu (osobna od granularnych ról
## EdgeAnalyzera). Placer/adapter zamienia geometrię (np. FACADE_TOP_2H w kotwicy)
## na jedno żądanie modułu (FACADE_2H) w znanej pozycji.

const TileRole = preload("res://modules/quiz_rpg/scripts/generation/core/tile_role.gd")

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
		_: return TileRole.Id.NONE

## Ile części ma mieć poprawny moduł (0 = dowolnie). Do walidacji kształtu.
static func expected_part_count(module_role: Id) -> int:
	match module_role:
		Id.FACADE_2H: return 2
		Id.FACADE_3H: return 3
		_: return 0

static func name_of(module_role: int) -> String:
	var keys := Id.keys()
	if module_role >= 0 and module_role < keys.size():
		return keys[module_role]
	return "UNKNOWN(%d)" % module_role
