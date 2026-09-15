class_name SideWallPlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const ThemeResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/theme_resolver.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")

static func _queue(plan: TilePlacementPlan, pos: Vector2i, atlas_coords: Vector2i, category: StringName, table: Dictionary) -> void:
	var p := TilePlacement.new()
	p.pos = pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Planuje pionowe ściany boczne (WEST i EAST) w porządku kanonicznym (y, x).
static func plan(
	ctx: GenerationContext,
	edges: Dictionary,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var width := ctx.width
	var height := ctx.height
	var grid := ctx.grid
	var table := ctx.priority_table

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not GridUtils.is_walkable(grid, pos):
				var w_floor := GridUtils.is_walkable(grid, pos + Vector2i(-1, 0))
				var e_floor := GridUtils.is_walkable(grid, pos + Vector2i(1, 0))

				if e_floor and not w_floor:
					if state.is_empty_or_rock(pos):
						var use_roots_side: bool = ThemeResolver.resolve(ctx, pos + Vector2i(1, 0), ThemeResolver.RefPoint.SELF) == &"roots"
						var var_idx: int = ctx.tile_rng.randi() % 2
						var side_t: Vector2i = CaveTileConstants.WALL_SIDE_WEST[var_idx] if not use_roots_side else CaveTileConstants.ROOT_WALL_SIDE_WEST[var_idx]
						_queue(plan, pos, side_t, &"SIDE_WALL", table)
						state.mark(pos, &"SIDE")

				elif w_floor and not e_floor:
					if state.is_empty_or_rock(pos):
						var use_roots_side: bool = ThemeResolver.resolve(ctx, pos + Vector2i(-1, 0), ThemeResolver.RefPoint.SELF) == &"roots"
						var var_idx: int = ctx.tile_rng.randi() % 2
						var side_t: Vector2i = CaveTileConstants.WALL_SIDE_EAST[var_idx] if not use_roots_side else CaveTileConstants.ROOT_WALL_SIDE_EAST[var_idx]
						_queue(plan, pos, side_t, &"SIDE_WALL", table)
						state.mark(pos, &"SIDE")
