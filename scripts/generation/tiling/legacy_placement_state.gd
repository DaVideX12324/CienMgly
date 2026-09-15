class_name LegacyPlacementState
extends RefCounted

## Shadow state odtwarzający zachowanie placed_tiles z kodu legacy.
## Służy do weryfikacji blokad przed kolejkowaniem kafelków do TilePlacementPlan.

var categories: Dictionary = {} # Vector2i -> StringName
var out_niche_positions: Array[Vector2i] = []
const OUT_NICHE_MIN_DISTANCE := 10


func get_category(pos: Vector2i) -> StringName:
	return categories.get(pos, &"")


func has(pos: Vector2i) -> bool:
	return categories.has(pos)


func is_empty_or_rock(pos: Vector2i) -> bool:
	return not categories.has(pos) or categories[pos] == &"ROCK"


func is_one_of(pos: Vector2i, allowed: Array) -> bool:
	if not categories.has(pos):
		return true
	return categories[pos] in allowed


func mark(pos: Vector2i, category: StringName) -> void:
	categories[pos] = category


func can_place_out_niche(pos: Vector2i) -> bool:
	for existing in out_niche_positions:
		if Vector2(pos).distance_squared_to(Vector2(existing)) < OUT_NICHE_MIN_DISTANCE * OUT_NICHE_MIN_DISTANCE:
			return false
	return true


func register_out_niche(pos: Vector2i) -> void:
	out_niche_positions.append(pos)
