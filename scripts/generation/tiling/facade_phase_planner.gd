class_name FacadePhasePlanner
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const EdgeKind = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_kind.gd")
const EdgeAnalysisResult = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_analysis_result.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const ThemeResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/theme_resolver.gd")
const FacadeSegmentDetector = preload("res://modules/quiz_rpg/scripts/generation/edge/facade_segment_detector.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")

const FacadePlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/facade_placer.gd")
const ConnectorPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/connector_placer.gd")
const OutCornerPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/out_corner_placer.gd")
const StepPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/step_placer.gd")
const NichePlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/niche_placer.gd")

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


static func plan(
	ctx: GenerationContext,
	analysis: EdgeAnalysisResult,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var grid := ctx.grid
	var facade_cols := analysis.facade_cols
	var sorted_xs := analysis.sorted_xs
	var edges := analysis.edges
	var table := ctx.priority_table
	var step_downs: Array[Dictionary] = []

	var check_2h_col := func(cx: int, fy: int) -> bool:
		return GridUtils.is_walkable(grid, Vector2i(cx, fy)) \
			and not GridUtils.is_walkable(grid, Vector2i(cx, fy - 1)) \
			and not GridUtils.is_walkable(grid, Vector2i(cx, fy - 2)) \
			and GridUtils.is_walkable(grid, Vector2i(cx, fy - 3))

	for x in sorted_xs:
		for y in facade_cols[x]:
			var pos := Vector2i(x, y)
			if state.get_category(pos) == &"FACADE":
				continue

			var edge: EdgeContext = edges[pos]
			var use_roots: bool = ThemeResolver.resolve(ctx, pos, ThemeResolver.RefPoint.SELF) == &"roots"
			var left_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x - 1, y, 4)
			var right_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x + 1, y, 4)

			match edge.edge_kind:
				EdgeKind.Kind.OUT_CORNER:
					var w_open := edge.orientation == EdgeKind.Orientation.WEST
					var e_open := edge.orientation == EdgeKind.Orientation.EAST
					OutCornerPlacer.place(ctx, edge, state, plan, use_roots, step_downs, w_open, e_open)
					continue

				EdgeKind.Kind.STEP:
					StepPlacer.place(ctx, edge, state, plan, use_roots, step_downs, left_y, right_y, analysis.edges)
					continue

				EdgeKind.Kind.CONNECTOR:
					ConnectorPlacer.place(ctx, edge, state, plan)
					continue

				EdgeKind.Kind.FACADE:
					if edge.facade_height == 2:
						FacadePlacer.place_2h(ctx, edge, state, plan)
						continue
					else:
						if NichePlacer.try_place_legacy(ctx, edge, state, plan, use_roots, facade_cols):
							continue
						FacadePlacer.place_3h(ctx, edge, state, plan, use_roots, left_y, right_y, edges)
						continue
				_:
					continue

	# FAZA 2.5: Ściany pionowe B obok kończącego się schodka w dół
	for s in step_downs:
		var sx: int = s.x
		var sy: int = s.y
		var sdir: int = s.dir
		var adj_x: int = sx + sdir

		var is_wall_at_sy := true
		if facade_cols.has(adj_x):
			for fy in facade_cols[adj_x]:
				if abs(fy - sy) <= 2:
					is_wall_at_sy = false
					break

		if is_wall_at_sy and not GridUtils.is_walkable(grid, Vector2i(adj_x, sy)):
			var use_roots_adj: bool = ThemeResolver.resolve(ctx, Vector2i(adj_x, sy), ThemeResolver.RefPoint.SELF) == &"roots"
			if sdir == 1:
				var p_c := Vector2i(adj_x, sy - 2)
				var edge_c: EdgeContext = edges.get(p_c)
				var can_place_crown: bool = state.is_empty_or_rock(p_c) and edge_c != null and not edge_c.is_protected_solid and edge_c.neighborhood_mask != 0 and (edge_c.edge_kind == EdgeKind.Kind.SOLID_FILL or edge_c.edge_kind == EdgeKind.Kind.NONE)
				if can_place_crown:
					_queue(plan, p_c, CaveTileConstants.CRNR_SE_IN, &"CORNER", table, Vector2i(sx, sy))
					state.mark(p_c, &"CORNER")
				var side_b := CaveTileConstants.WALL_SIDE_EAST[1] if not use_roots_adj else CaveTileConstants.ROOT_WALL_SIDE_EAST[1]
				var p_b1 := Vector2i(adj_x, sy - 1)
				var edge_b1: EdgeContext = edges.get(p_b1)
				var can_place_side: bool = state.is_empty_or_rock(p_b1) and edge_b1 != null and not edge_b1.is_protected_solid and edge_b1.neighborhood_mask != 0 and (edge_b1.edge_kind == EdgeKind.Kind.SOLID_FILL or edge_b1.edge_kind == EdgeKind.Kind.NONE)
				if can_place_side:
					_queue(plan, p_b1, side_b, &"SIDE_WALL_FIXED", table, Vector2i(sx, sy))
					state.mark(p_b1, &"SIDE_FIXED")
			else:
				var p_c := Vector2i(adj_x, sy - 2)
				var edge_c: EdgeContext = edges.get(p_c)
				var can_place_crown: bool = state.is_empty_or_rock(p_c) and edge_c != null and not edge_c.is_protected_solid and edge_c.neighborhood_mask != 0 and (edge_c.edge_kind == EdgeKind.Kind.SOLID_FILL or edge_c.edge_kind == EdgeKind.Kind.NONE)
				if can_place_crown:
					_queue(plan, p_c, CaveTileConstants.CRNR_SW_IN, &"CORNER", table, Vector2i(sx, sy))
					state.mark(p_c, &"CORNER")
				var side_b := CaveTileConstants.WALL_SIDE_WEST[1] if not use_roots_adj else CaveTileConstants.ROOT_WALL_SIDE_WEST[1]
				var p_b1 := Vector2i(adj_x, sy - 1)
				var edge_b1: EdgeContext = edges.get(p_b1)
				var can_place_side: bool = state.is_empty_or_rock(p_b1) and edge_b1 != null and not edge_b1.is_protected_solid and edge_b1.neighborhood_mask != 0 and (edge_b1.edge_kind == EdgeKind.Kind.SOLID_FILL or edge_b1.edge_kind == EdgeKind.Kind.NONE)
				if can_place_side:
					_queue(plan, p_b1, side_b, &"SIDE_WALL_FIXED", table, Vector2i(sx, sy))
					state.mark(p_b1, &"SIDE_FIXED")
