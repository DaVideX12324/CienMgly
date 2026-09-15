class_name FacadePhasePlanner
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
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

static func _queue(plan: TilePlacementPlan, pos: Vector2i, atlas_coords: Vector2i, category: StringName, table: Dictionary) -> void:
	var p := TilePlacement.new()
	p.pos = pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
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

			var has_same_y := func(cx: int, cy: int) -> bool:
				if not facade_cols.has(cx): return false
				for fy in facade_cols[cx]:
					if abs(fy - cy) <= 1: return true
				return false

			var left_is_2h: bool = check_2h_col.call(x - 1, y)
			var right_is_2h: bool = check_2h_col.call(x + 1, y)
			var near_2h_context: bool = (left_is_2h and right_is_2h) \
				or (left_is_2h and check_2h_col.call(x + 2, y)) \
				or (right_is_2h and check_2h_col.call(x - 2, y))

			var is_horizontal_facade: bool = has_same_y.call(x - 1, y) or has_same_y.call(x + 1, y)
			var is_2h: bool = is_horizontal_facade and (GridUtils.is_walkable(grid, pos + Vector2i(0, -3)) or near_2h_context)

			# 1. Fasada 2H
			if is_2h:
				FacadePlacer.place_2h(ctx, edge, state, plan)
				continue

			# 2. Łączniki 2H <-> 3H
			var left_is_2h_same: bool = check_2h_col.call(x - 1, y)
			var right_is_2h_same: bool = check_2h_col.call(x + 1, y)
			var right_has_room_for_3h: bool = not check_2h_col.call(x + 1, y) and not check_2h_col.call(x + 2, y) and not check_2h_col.call(x + 3, y)
			var left_has_room_for_3h: bool = not check_2h_col.call(x - 1, y) and not check_2h_col.call(x - 2, y) and not check_2h_col.call(x - 3, y)
			var right_is_2h_step: bool = check_2h_col.call(x + 1, y - 1)
			var left_is_2h_step: bool = check_2h_col.call(x - 1, y - 1)

			if (left_is_2h_same and right_has_room_for_3h) or (right_is_2h_same and left_has_room_for_3h) or ((right_is_2h_same or right_is_2h_step) and not (left_is_2h_same or left_is_2h_step)):
				ConnectorPlacer.place(ctx, edge, state, plan)
				continue

			# 3. Sąsiedzi na innej wysokości
			var left_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x - 1, y, 4)
			var right_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x + 1, y, 4)

			# 4. Sprawdź OUT corner
			var w_open := GridUtils.is_walkable(grid, pos + Vector2i(-1, -1)) \
				and GridUtils.is_walkable(grid, pos + Vector2i(-1, -2)) \
				and not GridUtils.is_walkable(grid, pos + Vector2i(0, -2)) \
				and left_y == -1

			var e_open := GridUtils.is_walkable(grid, pos + Vector2i(1, -1)) \
				and GridUtils.is_walkable(grid, pos + Vector2i(1, -2)) \
				and not GridUtils.is_walkable(grid, pos + Vector2i(0, -2)) \
				and right_y == -1

			if (w_open and not e_open) or (e_open and not w_open):
				OutCornerPlacer.place(ctx, edge, state, plan, use_roots, step_downs, w_open, e_open)
				continue

			# 5. Schodek (STEP)
			if (left_y != -1 and y > left_y) or (right_y != -1 and y > right_y):
				StepPlacer.place(ctx, edge, state, plan, use_roots, step_downs, left_y, right_y)
				continue

			# 6. Nisza (dekoracyjna / sekretna)
			if NichePlacer.try_place_legacy(ctx, edge, state, plan, use_roots, facade_cols):
				continue

			# 7. Zwykła ściana prosta 3H
			FacadePlacer.place_3h(ctx, edge, state, plan, use_roots, left_y, right_y)

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
				if state.is_empty_or_rock(p_c):
					_queue(plan, p_c, CaveTileConstants.CRNR_SE_IN, &"CORNER", table)
					state.mark(p_c, &"CORNER")
				var side_b := CaveTileConstants.WALL_SIDE_EAST[1] if not use_roots_adj else CaveTileConstants.ROOT_WALL_SIDE_EAST[1]
				var p_b1 := Vector2i(adj_x, sy - 1)
				if state.is_empty_or_rock(p_b1):
					_queue(plan, p_b1, side_b, &"SIDE_WALL_FIXED", table)
					state.mark(p_b1, &"SIDE_FIXED")
			else:
				var p_c := Vector2i(adj_x, sy - 2)
				if state.is_empty_or_rock(p_c):
					_queue(plan, p_c, CaveTileConstants.CRNR_SW_IN, &"CORNER", table)
					state.mark(p_c, &"CORNER")
				var side_b := CaveTileConstants.WALL_SIDE_WEST[1] if not use_roots_adj else CaveTileConstants.ROOT_WALL_SIDE_WEST[1]
				var p_b1 := Vector2i(adj_x, sy - 1)
				if state.is_empty_or_rock(p_b1):
					_queue(plan, p_b1, side_b, &"SIDE_WALL_FIXED", table)
					state.mark(p_b1, &"SIDE_FIXED")
