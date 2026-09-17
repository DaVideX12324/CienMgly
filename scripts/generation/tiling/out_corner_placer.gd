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
	w_open: bool,
	e_open: bool
) -> void:
	var pos := edge.pos
	var table := ctx.priority_table

	if w_open and not e_open:
		if edge.facade_height == 2:
			var base_2h := CaveTileConstants.WALL_2H_WEST_BASE
			var top_2h := CaveTileConstants.WALL_2H_WEST_TOP
			_queue(plan, pos, base_2h, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), top_2h, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
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

	elif e_open and not w_open:
		if edge.facade_height == 2:
			var base_2h := CaveTileConstants.WALL_2H_EAST_BASE
			var top_2h := CaveTileConstants.WALL_2H_EAST_TOP
			_queue(plan, pos, base_2h, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), top_2h, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
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

