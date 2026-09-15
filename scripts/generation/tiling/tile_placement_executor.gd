class_name TilePlacementExecutor
extends RefCounted

const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")

## Wykonuje zaplanowane kafelkowanie set_cell / erase_cell na zadanej warstwie w porządku kanonicznym (y, x).
static func execute(layer: TileMapLayer, plan: TilePlacementPlan, layer_name: StringName) -> int:
	if layer == null:
		return 0

	var cells: Dictionary = plan.by_layer.get(layer_name, {})
	if cells.is_empty():
		return 0

	var positions: Array = cells.keys()
	positions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)

	var count := 0
	for pos in positions:
		var p: TilePlacement = cells[pos]
		if p.is_erase():
			layer.erase_cell(pos)
		else:
			layer.set_cell(pos, p.source_id, p.atlas_coords, p.alternative_tile)
		count += 1

	return count
