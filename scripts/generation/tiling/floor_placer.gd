class_name FloorPlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")

## Oblicza komórki podłogi (dylatacja 5x5 wokół komórek przechodnich).
static func get_ground_cells(ctx: GenerationContext) -> Array[Vector2i]:
	var near_floor: Dictionary = {}
	var grid := ctx.grid
	for pos in grid.keys():
		if GridUtils.is_walkable(grid, pos):
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					near_floor[pos + Vector2i(dx, dy)] = true

	var ground_cells: Array[Vector2i] = []
	for pos in near_floor.keys():
		ground_cells.append(pos)
	return ground_cells


## Planuje bazowe wypełnienie podłogi kafelkiem (10, 13) na warstwie Floor.
static func plan(
	ctx: GenerationContext,
	plan: TilePlacementPlan,
	ground_cells: Array[Vector2i] = []
) -> Array[Vector2i]:
	var cells := ground_cells
	if cells.is_empty():
		cells = get_ground_cells(ctx)

	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})

	for p in cells:
		var placement := TilePlacement.new()
		placement.pos = p
		placement.layer = &"Floor"
		placement.atlas_coords = CaveTileConstants.FLOOR_BASE_TILE
		placement.category = &"FLOOR_BASE"
		PlacementPriority.assign(placement, table)
		plan.queue(placement)

	return cells
