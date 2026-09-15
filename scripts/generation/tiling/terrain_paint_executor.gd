class_name TerrainPaintExecutor
extends RefCounted

const TerrainPaintPlan = preload("res://modules/quiz_rpg/scripts/generation/core/terrain_paint_plan.gd")

## Wykonuje zaplanowane batche autotilingu set_cells_terrain_connect na warstwach.
## Jeśli warstwa docelowa (np. FloorDecor) jest null, batch zostaje bezpiecznie pominięty.
static func execute(layers: Dictionary, plan: TerrainPaintPlan) -> void:
	if plan == null or plan.batches.is_empty():
		return

	for batch in plan.batches:
		if not layers.has(batch.layer):
			continue
		var layer: TileMapLayer = layers[batch.layer]
		if layer == null:
			continue

		if not batch.cells.is_empty():
			layer.set_cells_terrain_connect(batch.cells, batch.terrain_set, batch.terrain, batch.ignore_empty_terrains)
