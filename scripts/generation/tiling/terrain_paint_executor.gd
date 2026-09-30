class_name TerrainPaintExecutor
extends RefCounted


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


## Jak execute, ale porcjami po `chunk` kratek z klatką przerwy (ekran ładowania nie zamarza).
static func execute_chunked(layers: Dictionary, plan: TerrainPaintPlan, tree: SceneTree, chunk: int) -> void:
	if plan == null or plan.batches.is_empty():
		return
	for batch in plan.batches:
		var layer: TileMapLayer = layers.get(batch.layer)
		if layer == null or batch.cells.is_empty():
			continue
		var prep := TerrainAutotileSolver.prepare(layer, batch.cells, batch.terrain_set, batch.terrain)
		if prep.is_empty():
			continue
		for from in range(0, batch.cells.size(), chunk):
			TerrainAutotileSolver.paint_range(layer, batch.cells, prep, from, from + chunk)
			await tree.process_frame
