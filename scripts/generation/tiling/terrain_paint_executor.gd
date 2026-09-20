class_name TerrainPaintExecutor
extends RefCounted

const TerrainPaintPlan = preload("res://modules/quiz_rpg/scripts/generation/core/terrain_paint_plan.gd")
const TerrainAutotileSolver = preload("res://modules/quiz_rpg/scripts/generation/tiling/terrain_autotile_solver.gd")

## Wykonuje zaplanowane batche autotilingu terenu na warstwach.
## Używa własnego solvera (TerrainAutotileSolver) zamiast set_cells_terrain_connect,
## który przy nakładających się terenach wstawia zły kafel (Godot #70218 -> twarde
## cięcia krawędzi, najgorzej po prawej). Solver dobiera kafel wprost z wzorca sąsiedztwa.
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
			TerrainAutotileSolver.paint(layer, batch.cells, batch.terrain_set, batch.terrain)
