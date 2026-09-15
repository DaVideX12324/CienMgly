class_name OutCornerPlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
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


static func place(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan,
	use_roots: bool,
	step_downs: Array[Dictionary],
	w_open: bool,
	e_open: bool
) -> void:
	var pos := edge.pos
	var x := pos.x
	var y := pos.y
	var grid := ctx.grid
	var table := ctx.priority_table

	if w_open and not e_open:
		var is_2h_corner := GridUtils.is_walkable(grid, pos + Vector2i(0, -3))
		if is_2h_corner:
			var base_2h := CaveTileConstants.WALL_2H_WEST_BASE
			var top_2h := CaveTileConstants.WALL_2H_WEST_TOP
			var crown_2h := Vector2i(0, 1)
			_queue(plan, pos + Vector2i(0, -1), base_2h, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -2), top_2h, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -3), crown_2h, &"FACADE", table)
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")
			state.mark(pos + Vector2i(0, -3), &"FACADE")

			var p_in := pos + Vector2i(1, -2)
			if not GridUtils.is_walkable(grid, p_in):
				var in_corner := CaveTileConstants.CRNR_SE_IN
				_queue(plan, p_in, in_corner, &"CORNER", table)
				state.mark(p_in, &"CORNER")

			var p_side := pos + Vector2i(1, -1)
			if not GridUtils.is_walkable(grid, p_side) and state.is_empty_or_rock(p_side):
				var side_b := CaveTileConstants.WALL_SIDE_EAST[1] if not use_roots else CaveTileConstants.ROOT_WALL_SIDE_EAST[1]
				_queue(plan, p_side, side_b, &"SIDE_WALL_FIXED", table)
				state.mark(p_side, &"SIDE_FIXED")
		else:
			var top_t := CaveTileConstants.MOD_CRNR_NW_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_TOP
			var mid_t := CaveTileConstants.MOD_CRNR_NW_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_MID
			var base_t := CaveTileConstants.MOD_CRNR_NW_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_BASE
			_queue(plan, pos, base_t, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")

			var p_up := pos + Vector2i(0, -3)
			if not GridUtils.is_walkable(grid, p_up) and GridUtils.is_walkable(grid, pos + Vector2i(-1, -3)):
				var side_t := CaveTileConstants.WALL_SIDE_EAST[1] if not use_roots else CaveTileConstants.ROOT_WALL_SIDE_EAST[1]
				_queue(plan, p_up, side_t, &"SIDE_WALL_FIXED", table)
				state.mark(p_up, &"SIDE_FIXED")

		if not GridUtils.is_walkable(grid, pos + Vector2i(1, 0)):
			step_downs.append({"x": x, "y": y, "dir": 1})

	elif e_open and not w_open:
		var is_2h_corner := GridUtils.is_walkable(grid, pos + Vector2i(0, -3))
		if is_2h_corner:
			var base_2h := CaveTileConstants.WALL_2H_EAST_BASE
			var top_2h := CaveTileConstants.WALL_2H_EAST_TOP
			var crown_2h := Vector2i(5, 1)
			_queue(plan, pos + Vector2i(0, -1), base_2h, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -2), top_2h, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -3), crown_2h, &"FACADE", table)
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")
			state.mark(pos + Vector2i(0, -3), &"FACADE")

			var p_in := pos + Vector2i(-1, -2)
			if not GridUtils.is_walkable(grid, p_in):
				var in_corner := CaveTileConstants.CRNR_SW_IN
				_queue(plan, p_in, in_corner, &"CORNER", table)
				state.mark(p_in, &"CORNER")

			var p_side := pos + Vector2i(-1, -1)
			if not GridUtils.is_walkable(grid, p_side) and state.is_empty_or_rock(p_side):
				var side_b := CaveTileConstants.WALL_SIDE_WEST[1] if not use_roots else CaveTileConstants.ROOT_WALL_SIDE_WEST[1]
				_queue(plan, p_side, side_b, &"SIDE_WALL_FIXED", table)
				state.mark(p_side, &"SIDE_FIXED")
		else:
			var top_t := CaveTileConstants.MOD_CRNR_NE_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_TOP
			var mid_t := CaveTileConstants.MOD_CRNR_NE_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_MID
			var base_t := CaveTileConstants.MOD_CRNR_NE_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_BASE
			_queue(plan, pos, base_t, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")

			var p_up := pos + Vector2i(0, -3)
			if not GridUtils.is_walkable(grid, p_up) and GridUtils.is_walkable(grid, pos + Vector2i(1, -3)):
				var side_t := CaveTileConstants.WALL_SIDE_WEST[1] if not use_roots else CaveTileConstants.ROOT_WALL_SIDE_WEST[1]
				_queue(plan, p_up, side_t, &"SIDE_WALL_FIXED", table)
				state.mark(p_up, &"SIDE_FIXED")

		if not GridUtils.is_walkable(grid, pos + Vector2i(-1, 0)):
			step_downs.append({"x": x, "y": y, "dir": -1})
