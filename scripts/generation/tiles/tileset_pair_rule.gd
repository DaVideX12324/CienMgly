class_name TileSetPairRule
extends Resource

## Reguła relacji między dwoma KONKRETNYMI ID nazwanych zestawów na ich styku.

enum Mode {
	FORBIDDEN,
	ALLOWED,
	TRANSITION,
	OVERLAY,
	USE_FIRST,
	USE_SECOND,
}

@export_category("Para zestawów")
@export var first_tileset_id: StringName
@export var second_tileset_id: StringName
## Gdy true, reguła obowiązuje tylko dla kierunku first -> second (bez symetrii).
@export var directional: bool = false

@export_category("Zachowanie")
@export var mode: Mode = Mode.FORBIDDEN
@export var fallback_mode: Mode = Mode.USE_FIRST

@export_category("Kafelki przejściowe")
@export var transition_entries: Array[TileRoleEntry] = []

## Kafelek przejściowy dla roli lub null (nie każda rola musi mieć przejście).
func get_transition_tile(role: TileRole.Id) -> TileRef:
	for entry in transition_entries:
		if entry != null and entry.role == role:
			return entry.tile
	return null
