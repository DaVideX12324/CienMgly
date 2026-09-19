class_name TileSetField
extends RefCounted

## Przechowuje ID nazwanego zestawu przypisane do każdej komórki gridu.
## Źródło ID jest dowolne (strefy, noise, tagi pokoi, JSON, narzędzie) — reszta
## pipeline'u działa identycznie niezależnie od pochodzenia.

var cells: Dictionary = {} # Vector2i -> StringName

func set_tileset_id(pos: Vector2i, tileset_id: StringName) -> void:
	cells[pos] = tileset_id

func get_tileset_id(pos: Vector2i, fallback_id: StringName) -> StringName:
	return cells.get(pos, fallback_id)

func has(pos: Vector2i) -> bool:
	return cells.has(pos)

func is_empty() -> bool:
	return cells.is_empty()

## Wypełnia prostokąt jednym ID (wygodne dla stref/pokoi).
func fill_rect(rect: Rect2i, tileset_id: StringName) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			cells[Vector2i(x, y)] = tileset_id
