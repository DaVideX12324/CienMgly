class_name StepPlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeKind = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_kind.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const ThemeResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/theme_resolver.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")

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
	left_y: int,
	right_y: int,
	edges: Dictionary = {}
) -> void:
	var pos := edge.pos
	var x := pos.x
	var y := pos.y
	var table := ctx.priority_table

	if left_y != -1 and y > left_y:
		if edge.facade_height == 2:
			_queue(plan, pos, CaveTileConstants.WALL_2H_WEST_BASE, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_WEST_TOP, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		else:
			var dy: int = y - left_y
			var step_use_roots: bool = use_roots and (dy == 1)
			var base_t := CaveTileConstants.MOD_CRNR_NW_IN_BASE if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_BASE
			var mid_t := CaveTileConstants.MOD_CRNR_NW_IN_MID if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_MID
			var top_t := CaveTileConstants.MOD_CRNR_NW_IN_TOP if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_TOP

			_queue(plan, pos, base_t, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)

			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")

	elif right_y != -1 and y > right_y:
		if edge.facade_height == 2:
			_queue(plan, pos, CaveTileConstants.WALL_2H_EAST_BASE, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_EAST_TOP, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		else:
			var dy: int = y - right_y
			var step_use_roots: bool = use_roots and (dy == 1)
			var base_t := CaveTileConstants.MOD_CRNR_NE_IN_BASE if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_BASE
			var mid_t := CaveTileConstants.MOD_CRNR_NE_IN_MID if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_MID
			var top_t := CaveTileConstants.MOD_CRNR_NE_IN_TOP if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_TOP

			_queue(plan, pos, base_t, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)

			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")

