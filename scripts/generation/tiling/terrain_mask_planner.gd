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


## Maski terenu (błoto, trawa) dla komórek terenu — czysta funkcja seeda i komórek, więc generator
## obiektów liczy je już w topologii (GenerationResult.terrain_masks), a planer kafli używa tych
## samych masek, gdy seed się zgadza. {seed: int, mud: Array[Vector2i], grass: Array[Vector2i]}.
static func compute_masks(ctx: GenerationContext, terrain_cells: Array[Vector2i]) -> Dictionary:
	var fl: GenerationFlags = ctx.flags if ctx.flags != null else GenerationFlags.new()
	var smoothing := ctx.flags != null and ctx.flags.enable_terrain_smoothing
	return {
		"seed": ctx.seed_value,
		"mud": _mask(terrain_cells, ctx.portal_zone, ctx.seed_value + 202, fl.terrain_mud_frequency, fl.terrain_mud_threshold, smoothing),
		"grass": _mask(terrain_cells, ctx.portal_zone, ctx.seed_value, fl.terrain_grass_frequency, fl.terrain_grass_threshold, smoothing),
	}


## Maski dla wyniku generacji (bez planu kafli): komórki terenu jak w TilePlacementPlanner
## (podłoga + 2 kratki, bez barier i schodów płaskowyżu), strefa portali z wejścia i wyjścia.
static func compute_for_result(result, seed_value: int, flags: GenerationFlags) -> Dictionary:
	var ctx := GenerationContext.new()
	ctx.grid = result.grid
	ctx.width = result.width
	ctx.height = result.height
	ctx.seed_value = seed_value
	ctx.flags = flags
	ctx.plateau = result.plateau
	for p in result.entrance_zone:
		ctx.portal_zone[p] = true
	for p in result.exit_zone:
		ctx.portal_zone[p] = true
	var cells := TilePlacementPlanner.terrain_cells(ctx, FloorPlacer.get_ground_cells(ctx))
	return compute_masks(ctx, cells)


static func _mask(cells: Array[Vector2i], portal_zone: Dictionary, noise_seed: int, frequency: float, threshold: float, smoothing: bool) -> Array[Vector2i]:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	var candidates := {}
	for p in cells:
		if portal_zone.has(p):
			continue
		if noise.get_noise_2d(float(p.x), float(p.y)) > threshold:
			candidates[p] = true
	if smoothing:
		return clean_terrain_mask(candidates)
	var cells_set := {}
	for p in candidates.keys():
		if candidates.has(p + Vector2i(1, 0)) and candidates.has(p + Vector2i(0, 1)) and candidates.has(p + Vector2i(1, 1)):
			cells_set[p] = true
			cells_set[p + Vector2i(1, 0)] = true
			cells_set[p + Vector2i(0, 1)] = true
			cells_set[p + Vector2i(1, 1)] = true
	var out: Array[Vector2i] = []
	for p in cells_set.keys():
		out.append(p)
	return out


## Plamy błota (Terrain 1 'Mud') na Floor i mchu / trawy (Terrain 2 'Grass') na FloorDecor.
## Gotowe maski z ctx.terrain_masks, gdy policzone tym samym seedem; inaczej liczone tutaj.
static func plan_masks(ctx: GenerationContext, terrain_plan: TerrainPaintPlan, terrain_cells: Array[Vector2i]) -> Dictionary:
	var masks: Dictionary = ctx.terrain_masks
	if masks.is_empty() or int(masks.get("seed", 0)) != ctx.seed_value:
		masks = compute_masks(ctx, terrain_cells)
	terrain_plan.add_batch(&"Floor", masks["mud"], 0, 1, 0, true)
	terrain_plan.add_batch(&"FloorDecor", masks["grass"], 0, 2, 1, true)
	return masks
