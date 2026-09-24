class_name TilePlacementExecutor
extends RefCounted


## Wykonuje zaplanowane kafelkowanie set_cell / erase_cell na zadanej warstwie. Każda pozycja
## występuje w planie raz, więc kolejność wstawiania nie zmienia wyniku (bez sortowania).
static func execute(layer: TileMapLayer, plan: TilePlacementPlan, layer_name: StringName) -> int:
	if layer == null:
		return 0
	var cells: Dictionary = plan.by_layer.get(layer_name, {})
	var positions: Array = cells.keys()
	place_range(layer, cells, positions, 0, positions.size())
	return positions.size()


## Wstawia positions[from..to) z cells (pos -> TilePlacement) — do wykonania porcjami między klatkami.
static func place_range(layer: TileMapLayer, cells: Dictionary, positions: Array, from: int, to: int) -> void:
	for i in range(from, mini(to, positions.size())):
		var pos: Vector2i = positions[i]
		var p: TilePlacement = cells[pos]
		if p.is_erase():
			layer.erase_cell(pos)
		else:
			layer.set_cell(pos, p.source_id, p.atlas_coords, p.alternative_tile)
