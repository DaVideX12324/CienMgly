class_name TilePlacementPlan
extends RefCounted

const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")

## layer -> Dictionary[Vector2i -> TilePlacement]
var by_layer: Dictionary = {}

func queue(placement: TilePlacement) -> void:
	var cells: Dictionary = by_layer.get(placement.layer, {})
	if not by_layer.has(placement.layer):
		by_layer[placement.layer] = cells

	var existing: TilePlacement = cells.get(placement.pos)
	if existing == null:
		cells[placement.pos] = placement
		return

	# Ostro >: przy równym priorytecie NIE nadpisujemy — wynik niezależny od kolejności.
	if placement.priority > existing.priority:
		cells[placement.pos] = placement
		return

	# Remis: rozstrzygamy deterministycznie, nie "ostatni wygrywa".
	if placement.priority == existing.priority:
		if placement.tie_breaker > existing.tie_breaker:
			cells[placement.pos] = placement
		elif placement.tie_breaker == existing.tie_breaker:
			if _atlas_less(existing.atlas_coords, placement.atlas_coords):
				cells[placement.pos] = placement
			push_warning("TilePlacementPlan: nierozstrzygalny remis %s @ %s (%s vs %s)"
				% [placement.layer, placement.pos, existing.category, placement.category])


static func _atlas_less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


## Kanoniczna serializacja do snapshotu regresyjnego (§13.3).
func serialize_canonical() -> String:
	var out := PackedStringArray()
	var layer_names: Array = by_layer.keys()
	layer_names.sort()

	for layer_name in layer_names:
		var cells: Dictionary = by_layer[layer_name]
		var positions: Array = cells.keys()
		positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)

		for pos in positions:
			var p: TilePlacement = cells[pos]
			out.append("%s|%d,%d|%d|%d,%d|%d" % [
				layer_name, p.pos.x, p.pos.y,
				p.source_id, p.atlas_coords.x, p.atlas_coords.y,
				p.alternative_tile
			])

	return "\n".join(out)


func compute_digest() -> String:
	return serialize_canonical().sha256_text()


func get_placements(layer: StringName) -> Dictionary:
	return by_layer.get(layer, {})
