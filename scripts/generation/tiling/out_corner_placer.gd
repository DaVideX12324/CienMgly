class_name OutCornerPlacer
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

static func _get_variant_noise(ctx: GenerationContext) -> FastNoiseLite:
	if ctx.variant_noise != null:
		return ctx.variant_noise
	var n := FastNoiseLite.new()
	n.seed = ctx.seed_value + 777
	n.frequency = 0.45
	ctx.variant_noise = n
	return n


static func _queue(
	plan: TilePlacementPlan,
	target_pos: Vector2i,
	atlas_coords: Vector2i,
	category: StringName,
	table: Dictionary,
	origin: Vector2i = Vector2i.ZERO
) -> void:
	var p := TilePlacement.new()
	p.pos = target_pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	p.origin = origin
	# Na własnej kolumnie tie_breaker = 10; na kolumnie sąsiedniej = 1 (§10.4).
	p.tie_breaker = 10 if (origin == Vector2i.ZERO or target_pos.x == origin.x) else 1
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
	var v_noise := _get_variant_noise(ctx)
	var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0

	if w_open and not e_open:
		var is_2h_corner := GridUtils.is_walkable(grid, pos + Vector2i(0, -3))
		if is_2h_corner:
			var base_2h := CaveTileConstants.WALL_2H_WEST_BASE
			var top_2h := CaveTileConstants.WALL_2H_WEST_TOP
			_queue(plan, pos, base_2h, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), top_2h, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")

			var crown_pos := pos + Vector2i(0, -2)
			var crown_use_roots: bool = ThemeResolver.resolve(ctx, crown_pos, ThemeResolver.RefPoint.NORTH_FLOOR) == &"roots"
			if not crown_use_roots:
				var crown_2h := CaveTileConstants.CRNR_SW_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SW_OUT_BASE_A
				_queue(plan, crown_pos, crown_2h, &"FACADE", table, pos)
				state.mark(crown_pos, &"FACADE")
			else:
				var t_base := CaveTileConstants.CRNR_SW_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_BASE
				var t_tips := CaveTileConstants.CRNR_SW_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_TIPS
				_queue(plan, crown_pos, t_base, &"FACADE", table, pos)
				state.mark(crown_pos, &"FACADE")
				if GridUtils.is_walkable(grid, pos + Vector2i(0, -3)):
					_queue(plan, pos + Vector2i(0, -3), t_tips, &"FACADE", table, pos)
					state.mark(pos + Vector2i(0, -3), &"FACADE")

			var p_in := pos + Vector2i(1, -1)
			if not GridUtils.is_walkable(grid, p_in):
				var in_corner := CaveTileConstants.CRNR_SE_IN
				_queue(plan, p_in, in_corner, &"CORNER", table, pos)
				state.mark(p_in, &"CORNER")

			var p_side := pos + Vector2i(1, 0)
			if not GridUtils.is_walkable(grid, p_side) and state.is_empty_or_rock(p_side):
				var side_b := CaveTileConstants.WALL_SIDE_EAST[1] if not use_roots else CaveTileConstants.ROOT_WALL_SIDE_EAST[1]
				_queue(plan, p_side, side_b, &"SIDE_WALL_FIXED", table, pos)
				state.mark(p_side, &"SIDE_FIXED")
		else:
			var top_t := CaveTileConstants.MOD_CRNR_NW_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_TOP
			var mid_t := CaveTileConstants.MOD_CRNR_NW_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_MID
			var base_t := CaveTileConstants.MOD_CRNR_NW_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_BASE
			_queue(plan, pos, base_t, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")

			var p_up := pos + Vector2i(0, -3)
			var p_above := p_up + Vector2i(0, -1)
			if not GridUtils.is_walkable(grid, p_up) and GridUtils.is_walkable(grid, pos + Vector2i(-1, -3)) and GridUtils.is_walkable(grid, p_above):
				var crown_use_roots: bool = ThemeResolver.resolve(ctx, p_up, ThemeResolver.RefPoint.NORTH_FLOOR) == &"roots"
				if not crown_use_roots:
					var corner_t := CaveTileConstants.CRNR_SW_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SW_OUT_BASE_A
					_queue(plan, p_up, corner_t, &"FACADE", table, pos)
					state.mark(p_up, &"FACADE")
				else:
					var t_base := CaveTileConstants.CRNR_SW_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_BASE
					var t_tips := CaveTileConstants.CRNR_SW_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_TIPS
					_queue(plan, p_up, t_base, &"FACADE", table, pos)
					state.mark(p_up, &"FACADE")
					_queue(plan, p_above, t_tips, &"FACADE", table, pos)
					state.mark(p_above, &"FACADE")

		if not GridUtils.is_walkable(grid, pos + Vector2i(1, 0)):
			step_downs.append({"x": x, "y": y, "dir": 1})

	elif e_open and not w_open:
		var is_2h_corner := GridUtils.is_walkable(grid, pos + Vector2i(0, -3))
		if is_2h_corner:
			var base_2h := CaveTileConstants.WALL_2H_EAST_BASE
			var top_2h := CaveTileConstants.WALL_2H_EAST_TOP
			_queue(plan, pos, base_2h, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), top_2h, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")

			var crown_pos := pos + Vector2i(0, -2)
			var crown_use_roots: bool = ThemeResolver.resolve(ctx, crown_pos, ThemeResolver.RefPoint.NORTH_FLOOR) == &"roots"
			if not crown_use_roots:
				var crown_2h := CaveTileConstants.CRNR_SE_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SE_OUT_BASE_A
				_queue(plan, crown_pos, crown_2h, &"FACADE", table, pos)
				state.mark(crown_pos, &"FACADE")
			else:
				var t_base := CaveTileConstants.CRNR_SE_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_BASE
				var t_tips := CaveTileConstants.CRNR_SE_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_TIPS
				_queue(plan, crown_pos, t_base, &"FACADE", table, pos)
				state.mark(crown_pos, &"FACADE")
				if GridUtils.is_walkable(grid, pos + Vector2i(0, -3)):
					_queue(plan, pos + Vector2i(0, -3), t_tips, &"FACADE", table, pos)
					state.mark(pos + Vector2i(0, -3), &"FACADE")

			var p_in := pos + Vector2i(-1, -1)
			if not GridUtils.is_walkable(grid, p_in):
				var in_corner := CaveTileConstants.CRNR_SW_IN
				_queue(plan, p_in, in_corner, &"CORNER", table, pos)
				state.mark(p_in, &"CORNER")

			var p_side := pos + Vector2i(-1, 0)
			if not GridUtils.is_walkable(grid, p_side) and state.is_empty_or_rock(p_side):
				var side_b := CaveTileConstants.WALL_SIDE_WEST[1] if not use_roots else CaveTileConstants.ROOT_WALL_SIDE_WEST[1]
				_queue(plan, p_side, side_b, &"SIDE_WALL_FIXED", table, pos)
				state.mark(p_side, &"SIDE_FIXED")
		else:
			var top_t := CaveTileConstants.MOD_CRNR_NE_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_TOP
			var mid_t := CaveTileConstants.MOD_CRNR_NE_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_MID
			var base_t := CaveTileConstants.MOD_CRNR_NE_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_BASE
			_queue(plan, pos, base_t, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")

			var p_up := pos + Vector2i(0, -3)
			var p_above := p_up + Vector2i(0, -1)
			if not GridUtils.is_walkable(grid, p_up) and GridUtils.is_walkable(grid, pos + Vector2i(1, -3)) and GridUtils.is_walkable(grid, p_above):
				var crown_use_roots: bool = ThemeResolver.resolve(ctx, p_up, ThemeResolver.RefPoint.NORTH_FLOOR) == &"roots"
				if not crown_use_roots:
					var corner_t := CaveTileConstants.CRNR_SE_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SE_OUT_BASE_A
					_queue(plan, p_up, corner_t, &"FACADE", table, pos)
					state.mark(p_up, &"FACADE")
				else:
					var t_base := CaveTileConstants.CRNR_SE_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_BASE
					var t_tips := CaveTileConstants.CRNR_SE_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_TIPS
					_queue(plan, p_up, t_base, &"FACADE", table, pos)
					state.mark(p_up, &"FACADE")
					_queue(plan, p_above, t_tips, &"FACADE", table, pos)
					state.mark(p_above, &"FACADE")

		if not GridUtils.is_walkable(grid, pos + Vector2i(-1, 0)):
			step_downs.append({"x": x, "y": y, "dir": -1})
