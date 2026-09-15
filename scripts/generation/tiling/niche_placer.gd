class_name NichePlacer
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


static func try_place_legacy(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan,
	use_roots: bool,
	facade_cols: Dictionary
) -> bool:
	var pos := edge.pos
	var x := pos.x
	var y := pos.y
	var pos_next := Vector2i(x + 1, y)
	var grid := ctx.grid
	var table := ctx.priority_table

	var can_niche := false
	var is_in_portal: bool = ctx.portal_zone.has(pos + Vector2i(0, 1)) or ctx.portal_zone.has(pos_next + Vector2i(0, 1))

	if ctx.flags.enable_decorative_niches and not is_in_portal and facade_cols.has(x + 1) and facade_cols[x + 1].has(y):
		if state.get_category(pos_next) != &"FACADE":
			var left_has_same_y: bool = facade_cols.has(x - 1) and facade_cols[x - 1].has(y)
			var right_has_same_y: bool = facade_cols.has(x + 2) and facade_cols[x + 2].has(y)
			var left_down_wall: bool = not GridUtils.is_walkable(grid, Vector2i(x - 1, y + 1)) or (facade_cols.has(x - 1) and facade_cols[x - 1].has(y + 1))
			var right_down_wall: bool = not GridUtils.is_walkable(grid, Vector2i(x + 2, y + 1)) or (facade_cols.has(x + 2) and facade_cols[x + 2].has(y + 1))
			var front_is_walkable: bool = GridUtils.is_walkable(grid, Vector2i(x, y + 1)) and GridUtils.is_walkable(grid, Vector2i(x + 1, y + 1))
			var left_wall_clear: bool = GridUtils.is_walkable(grid, Vector2i(x - 2, y))
			var right_wall_clear: bool = GridUtils.is_walkable(grid, Vector2i(x + 3, y))

			if left_has_same_y and right_has_same_y and not left_down_wall and not right_down_wall and front_is_walkable and left_wall_clear and right_wall_clear:
				can_niche = true

	if not can_niche:
		return false

	var can_place_out_niche := state.can_place_out_niche(pos)

	# 1. Nisza sekretna (para modułów OUT + OUT)
	if can_place_out_niche and ctx.tile_rng.randf() < ctx.flags.secret_niche_spawn_chance:
		var l_crown := CaveTileConstants.CRNR_SW_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SW_IN
		var l_top := CaveTileConstants.MOD_CRNR_NE_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_TOP
		var l_mid := CaveTileConstants.MOD_CRNR_NE_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_MID
		var l_base := CaveTileConstants.MOD_CRNR_NE_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_BASE

		_queue(plan, pos + Vector2i(0, -3), l_crown, &"FACADE", table)
		_queue(plan, pos + Vector2i(0, -2), l_top, &"FACADE", table)
		_queue(plan, pos + Vector2i(0, -1), l_mid, &"FACADE", table)
		_queue(plan, pos, l_base, &"FACADE", table)
		state.mark(pos + Vector2i(0, -3), &"FACADE")
		state.mark(pos + Vector2i(0, -2), &"FACADE")
		state.mark(pos + Vector2i(0, -1), &"FACADE")
		state.mark(pos, &"FACADE")

		var r_crown := CaveTileConstants.CRNR_SE_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SE_IN
		var r_top := CaveTileConstants.MOD_CRNR_NW_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_TOP
		var r_mid := CaveTileConstants.MOD_CRNR_NW_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_MID
		var r_base := CaveTileConstants.MOD_CRNR_NW_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_BASE

		_queue(plan, pos_next + Vector2i(0, -3), r_crown, &"FACADE", table)
		_queue(plan, pos_next + Vector2i(0, -2), r_top, &"FACADE", table)
		_queue(plan, pos_next + Vector2i(0, -1), r_mid, &"FACADE", table)
		_queue(plan, pos_next, r_base, &"FACADE", table)
		state.mark(pos_next + Vector2i(0, -3), &"FACADE")
		state.mark(pos_next + Vector2i(0, -2), &"FACADE")
		state.mark(pos_next + Vector2i(0, -1), &"FACADE")
		state.mark(pos_next, &"FACADE")

		state.register_out_niche(pos)
		return true

	# 2. Nisza standardowa (para modułów IN + IN)
	if ctx.tile_rng.randf() < ctx.flags.niche_spawn_chance:
		var l_crown := CaveTileConstants.CRNR_SW_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SW_IN
		var l_top := CaveTileConstants.MOD_CRNR_NE_IN_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_TOP
		var l_mid := CaveTileConstants.MOD_CRNR_NE_IN_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_MID
		var l_base := CaveTileConstants.MOD_CRNR_NE_IN_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_BASE

		_queue(plan, pos + Vector2i(0, -3), l_crown, &"FACADE", table)
		_queue(plan, pos + Vector2i(0, -2), l_top, &"FACADE", table)
		_queue(plan, pos + Vector2i(0, -1), l_mid, &"FACADE", table)
		_queue(plan, pos, l_base, &"FACADE", table)
		state.mark(pos + Vector2i(0, -3), &"FACADE")
		state.mark(pos + Vector2i(0, -2), &"FACADE")
		state.mark(pos + Vector2i(0, -1), &"FACADE")
		state.mark(pos, &"FACADE")

		var r_crown := CaveTileConstants.CRNR_SE_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SE_IN
		var r_top := CaveTileConstants.MOD_CRNR_NW_IN_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_TOP
		var r_mid := CaveTileConstants.MOD_CRNR_NW_IN_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_MID
		var r_base := CaveTileConstants.MOD_CRNR_NW_IN_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_BASE

		_queue(plan, pos_next + Vector2i(0, -3), r_crown, &"FACADE", table)
		_queue(plan, pos_next + Vector2i(0, -2), r_top, &"FACADE", table)
		_queue(plan, pos_next + Vector2i(0, -1), r_mid, &"FACADE", table)
		_queue(plan, pos_next, r_base, &"FACADE", table)
		state.mark(pos_next + Vector2i(0, -3), &"FACADE")
		state.mark(pos_next + Vector2i(0, -2), &"FACADE")
		state.mark(pos_next + Vector2i(0, -1), &"FACADE")
		state.mark(pos_next, &"FACADE")

		return true

	return false
