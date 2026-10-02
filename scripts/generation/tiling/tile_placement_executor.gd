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
			layer.set_cell(pos, p.source_id, p.atlas_coords, _alternative(layer, p))


## Nisza-przejście: alternatywa PASSAGE_ALT kafla (inne kolizje), gdy TileSet ją ma — inaczej zwykły kafel.
static func _alternative(layer: TileMapLayer, p: TilePlacement) -> int:
	if not p.passage or layer.tile_set == null or not layer.tile_set.has_source(p.source_id):
		return p.alternative_tile
	var src := layer.tile_set.get_source(p.source_id) as TileSetAtlasSource
	if src != null and src.has_tile(p.atlas_coords) and src.has_alternative_tile(p.atlas_coords, NichePlacer.PASSAGE_ALT):
		return NichePlacer.PASSAGE_ALT
	return p.alternative_tile
