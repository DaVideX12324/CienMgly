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
			if dy == 1 and (right_y == y + 1 or right_y == -1):
				var p_diag := pos + Vector2i(1, -2)
				var e_diag: EdgeContext = edges.get(p_diag)
				var is_thick_conn := e_diag != null and (
					(e_diag.edge_kind == EdgeKind.Kind.INNER_CORNER and e_diag.orientation == EdgeKind.Orientation.SOUTH_EAST) or
					(e_diag.edge_kind == EdgeKind.Kind.SIDE_WALL and e_diag.orientation == EdgeKind.Orientation.WEST)
				)
				if is_thick_conn:
					_queue(plan, pos, CaveTileConstants.CONNECTOR_2H_TO_3H_BASE, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.CONNECTOR_2H_TO_3H_MID, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.CONNECTOR_2H_TO_3H_TOP, &"FACADE", table, pos)
					state.mark(pos + Vector2i(0, -2), &"FACADE")
				else:
					_queue(plan, pos, CaveTileConstants.WALL_2H_SLOPE_LEFT_BASE, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_SLOPE_LEFT_MID, &"FACADE", table, pos)
					var p_top := pos + Vector2i(0, -2)
					var e_top: EdgeContext = edges.get(p_top)
					if e_top == null or e_top.edge_kind != EdgeKind.Kind.SIDE_WALL:
						_queue(plan, p_top, CaveTileConstants.WALL_2H_SLOPE_LEFT_TOP, &"FACADE", table, pos)
						state.mark(p_top, &"FACADE")
			else:
				var step_use_roots: bool = use_roots and (dy == 1)
				var base_t := CaveTileConstants.MOD_CRNR_NW_IN_BASE if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_BASE
				var mid_t := CaveTileConstants.MOD_CRNR_NW_IN_MID if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_MID
				var top_t := CaveTileConstants.MOD_CRNR_NW_IN_TOP if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_TOP

				_queue(plan, pos, base_t, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)
				state.mark(pos + Vector2i(0, -2), &"FACADE")

			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")

	elif right_y != -1 and y > right_y:
		if edge.facade_height == 2:
			_queue(plan, pos, CaveTileConstants.WALL_2H_EAST_BASE, &"FACADE", table, pos)
			_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_EAST_TOP, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		else:
			var dy: int = y - right_y
			if dy == 1 and (left_y == y + 1 or left_y == -1):
				var p_diag := pos + Vector2i(-1, -2)
				var e_diag: EdgeContext = edges.get(p_diag)
				var is_thick_conn := e_diag != null and (
					(e_diag.edge_kind == EdgeKind.Kind.INNER_CORNER and e_diag.orientation == EdgeKind.Orientation.SOUTH_WEST) or
					(e_diag.edge_kind == EdgeKind.Kind.SIDE_WALL and e_diag.orientation == EdgeKind.Orientation.EAST)
				)
				if is_thick_conn:
					_queue(plan, pos, CaveTileConstants.CONNECTOR_3H_TO_2H_BASE, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.CONNECTOR_3H_TO_2H_MID, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.CONNECTOR_3H_TO_2H_TOP, &"FACADE", table, pos)
					state.mark(pos + Vector2i(0, -2), &"FACADE")
				else:
					_queue(plan, pos, CaveTileConstants.WALL_2H_SLOPE_RIGHT_BASE, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_SLOPE_RIGHT_MID, &"FACADE", table, pos)
					var p_top := pos + Vector2i(0, -2)
					var e_top: EdgeContext = edges.get(p_top)
					if e_top == null or e_top.edge_kind != EdgeKind.Kind.SIDE_WALL:
						_queue(plan, p_top, CaveTileConstants.WALL_2H_SLOPE_RIGHT_TOP, &"FACADE", table, pos)
						state.mark(p_top, &"FACADE")
			else:
				var step_use_roots: bool = use_roots and (dy == 1)
				var base_t := CaveTileConstants.MOD_CRNR_NE_IN_BASE if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_BASE
				var mid_t := CaveTileConstants.MOD_CRNR_NE_IN_MID if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_MID
				var top_t := CaveTileConstants.MOD_CRNR_NE_IN_TOP if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_TOP

				_queue(plan, pos, base_t, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)
				state.mark(pos + Vector2i(0, -2), &"FACADE")

			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
