class_name FacadePlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
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
	p.tie_breaker = 10 if (origin == Vector2i.ZERO or target_pos.x == origin.x) else 1
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Stawia prostą fasadę o wysokości 2 kratek (2H). Zawsze motyw rock.
static func place_2h(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var pos := edge.pos
	var grid := ctx.grid
	var table := ctx.priority_table

	var is_west_end: bool = GridUtils.is_walkable(grid, pos + Vector2i(-1, -1)) or GridUtils.is_walkable(grid, pos + Vector2i(-1, -2))
	var is_east_end: bool = GridUtils.is_walkable(grid, pos + Vector2i(1, -1)) or GridUtils.is_walkable(grid, pos + Vector2i(1, -2))

	var top_2h := Vector2i.ZERO
	var base_2h := Vector2i.ZERO

	if is_west_end and not is_east_end:
		top_2h = CaveTileConstants.WALL_2H_WEST_TOP
		base_2h = CaveTileConstants.WALL_2H_WEST_BASE
	elif is_east_end and not is_west_end:
		top_2h = CaveTileConstants.WALL_2H_EAST_TOP
		base_2h = CaveTileConstants.WALL_2H_EAST_BASE
	else:
		var v_noise := _get_variant_noise(ctx)
		var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
		top_2h = CaveTileConstants.WALL_2H_TOP[1] if is_b else CaveTileConstants.WALL_2H_TOP[0]
		base_2h = CaveTileConstants.WALL_2H_BASE[1] if is_b else CaveTileConstants.WALL_2H_BASE[0]

	_queue(plan, pos, base_2h, &"FACADE", table)
	_queue(plan, pos + Vector2i(0, -1), top_2h, &"FACADE", table)

	state.mark(pos, &"FACADE")
	state.mark(pos + Vector2i(0, -1), &"FACADE")


## Stawia standardową prostą fasadę o wysokości 3 kratek (3H) z koroną.
static func place_3h(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan,
	use_roots: bool,
	left_y: int = -1,
	right_y: int = -1
) -> void:
	var pos := edge.pos
	var grid := ctx.grid
	var table := ctx.priority_table
	var v_noise := _get_variant_noise(ctx)

	var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
	var top_t := CaveTileConstants.WALL_BOTTOM_TOP[1] if is_b else CaveTileConstants.WALL_BOTTOM_TOP[0]
	var mid_t := CaveTileConstants.WALL_BOTTOM_MID[1] if is_b else CaveTileConstants.WALL_BOTTOM_MID[0]
	var base_t := CaveTileConstants.WALL_BOTTOM_BASE[1] if is_b else CaveTileConstants.WALL_BOTTOM_BASE[0]
	if use_roots:
		top_t = CaveTileConstants.ROOT_BOTTOM_TOP[1] if is_b else CaveTileConstants.ROOT_BOTTOM_TOP[0]
		mid_t = CaveTileConstants.ROOT_BOTTOM_MID[1] if is_b else CaveTileConstants.ROOT_BOTTOM_MID[0]
		base_t = CaveTileConstants.ROOT_BOTTOM_BASE[1] if is_b else CaveTileConstants.ROOT_BOTTOM_BASE[0]

	var crown_t := Vector2i(3, 4) if is_b else Vector2i(2, 4)
	if use_roots:
		crown_t = Vector2i(3, 13) if is_b else Vector2i(2, 13)

	_queue(plan, pos + Vector2i(0, -3), crown_t, &"FACADE", table)
	_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table)
	_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table)
	_queue(plan, pos, base_t, &"FACADE", table)

	state.mark(pos + Vector2i(0, -3), &"FACADE")
	state.mark(pos + Vector2i(0, -2), &"FACADE")
	state.mark(pos + Vector2i(0, -1), &"FACADE")
	state.mark(pos, &"FACADE")

	# Zakończenie lewe litym murem: ściana zachodnia B i wewnętrzny narożnik SW_IN
	if not GridUtils.is_walkable(grid, pos + Vector2i(-1, 0)) and left_y == -1:
		var side_b := CaveTileConstants.WALL_SIDE_WEST[1] if not use_roots else CaveTileConstants.ROOT_WALL_SIDE_WEST[1]
		var corner_t := CaveTileConstants.CRNR_SW_IN
		var p_corner := Vector2i(pos.x - 1, pos.y - 2)
		if not GridUtils.is_walkable(grid, p_corner) and state.is_empty_or_rock(p_corner):
			_queue(plan, p_corner, corner_t, &"CORNER", table, pos)
			state.mark(p_corner, &"CORNER")
		for cy in range(pos.y - 1, pos.y + 1):
			var p_side := Vector2i(pos.x - 1, cy)
			if not GridUtils.is_walkable(grid, p_side) and state.is_empty_or_rock(p_side):
				_queue(plan, p_side, side_b, &"SIDE_WALL_FIXED", table, pos)
				state.mark(p_side, &"SIDE_FIXED")

	# Zakończenie prawe litym murem: ściana wschodnia B i wewnętrzny narożnik SE_IN
	if not GridUtils.is_walkable(grid, pos + Vector2i(1, 0)) and right_y == -1:
		var side_b := CaveTileConstants.WALL_SIDE_EAST[1] if not use_roots else CaveTileConstants.ROOT_WALL_SIDE_EAST[1]
		var corner_t := CaveTileConstants.CRNR_SE_IN
		var p_corner := Vector2i(pos.x + 1, pos.y - 2)
		if not GridUtils.is_walkable(grid, p_corner) and state.is_empty_or_rock(p_corner):
			_queue(plan, p_corner, corner_t, &"CORNER", table, pos)
			state.mark(p_corner, &"CORNER")
		for cy in range(pos.y - 1, pos.y + 1):
			var p_side := Vector2i(pos.x + 1, cy)
			if not GridUtils.is_walkable(grid, p_side) and state.is_empty_or_rock(p_side):
				_queue(plan, p_side, side_b, &"SIDE_WALL_FIXED", table, pos)
				state.mark(p_side, &"SIDE_FIXED")
