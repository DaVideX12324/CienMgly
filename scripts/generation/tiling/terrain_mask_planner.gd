class_name TerrainMaskPlanner
extends RefCounted


## Wygładza maskę terenu, dopełniając klastry i eliminując ząbkowane styki diagonalne.
static func clean_terrain_mask(candidates: Dictionary) -> Array[Vector2i]:
	var refined: Dictionary = {}
	for p in candidates.keys():
		if candidates.has(p + Vector2i(1, 0)) and candidates.has(p + Vector2i(0, 1)) and candidates.has(p + Vector2i(1, 1)):
			refined[p] = true
			refined[p + Vector2i(1, 0)] = true
			refined[p + Vector2i(0, 1)] = true
			refined[p + Vector2i(1, 1)] = true

	var filled: Dictionary = refined.duplicate()
	for p in refined.keys():
		if refined.has(p + Vector2i(1, 1)) and not refined.has(p + Vector2i(1, 0)) and not refined.has(p + Vector2i(0, 1)):
			filled[p + Vector2i(1, 0)] = true
		if refined.has(p + Vector2i(-1, 1)) and not refined.has(p + Vector2i(-1, 0)) and not refined.has(p + Vector2i(0, 1)):
			filled[p + Vector2i(0, 1)] = true

	var out: Array[Vector2i] = []
	for p in filled.keys():
		out.append(p)
	return out


## Planuje organiczne plamy błota/ziemi (Terrain 1 'Mud') na warstwie Floor.
static func plan_mud(
	ctx: GenerationContext,
	terrain_plan: TerrainPaintPlan,
	ground_cells: Array[Vector2i] = []
) -> Array[Vector2i]:
	var cells := ground_cells
	if cells.is_empty():
		cells = FloorPlacer.get_ground_cells(ctx)

	var mud_noise := FastNoiseLite.new()
	mud_noise.seed = ctx.seed_value + 202
	mud_noise.frequency = 0.035

	var mud_candidates := {}
	for p in cells:
		if ctx.portal_zone.has(p):
			continue
		if mud_noise.get_noise_2d(float(p.x), float(p.y)) > -0.02:
			mud_candidates[p] = true

	var mud_cells: Array[Vector2i] = []
	if ctx.flags != null and ctx.flags.enable_terrain_smoothing:
		mud_cells = clean_terrain_mask(mud_candidates)
	else:
		var mud_cells_set := {}
		for p in mud_candidates.keys():
			if mud_candidates.has(p + Vector2i(1, 0)) and mud_candidates.has(p + Vector2i(0, 1)) and mud_candidates.has(p + Vector2i(1, 1)):
				mud_cells_set[p] = true
				mud_cells_set[p + Vector2i(1, 0)] = true
				mud_cells_set[p + Vector2i(0, 1)] = true
				mud_cells_set[p + Vector2i(1, 1)] = true
		for p in mud_cells_set.keys():
			mud_cells.append(p)

	terrain_plan.add_batch(&"Floor", mud_cells, 0, 1, 0, true)
	return mud_cells


## Planuje organiczne plamy mchu / trawy (Terrain 2 'Grass') na warstwie FloorDecor.
static func plan_grass(
	ctx: GenerationContext,
	terrain_plan: TerrainPaintPlan,
	ground_cells: Array[Vector2i] = []
) -> Array[Vector2i]:
	var cells := ground_cells
	if cells.is_empty():
		cells = FloorPlacer.get_ground_cells(ctx)

	var grass_noise := FastNoiseLite.new()
	grass_noise.seed = ctx.seed_value
	grass_noise.frequency = 0.13

	var grass_candidates := {}
	for p in cells:
		if ctx.portal_zone.has(p):
			continue
		if grass_noise.get_noise_2d(float(p.x), float(p.y)) > 0.10:
			grass_candidates[p] = true

	var grass_cells: Array[Vector2i] = []
	if ctx.flags != null and ctx.flags.enable_terrain_smoothing:
		grass_cells = clean_terrain_mask(grass_candidates)
	else:
		var grass_cells_set := {}
		for p in grass_candidates.keys():
			if grass_candidates.has(p + Vector2i(1, 0)) and grass_candidates.has(p + Vector2i(0, 1)) and grass_candidates.has(p + Vector2i(1, 1)):
				grass_cells_set[p] = true
				grass_cells_set[p + Vector2i(1, 0)] = true
				grass_cells_set[p + Vector2i(0, 1)] = true
				grass_cells_set[p + Vector2i(1, 1)] = true
		for p in grass_cells_set.keys():
			grass_cells.append(p)

	terrain_plan.add_batch(&"FloorDecor", grass_cells, 0, 2, 1, true)
	return grass_cells
