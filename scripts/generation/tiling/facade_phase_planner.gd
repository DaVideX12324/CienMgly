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
const SlopePlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/slope_placer.gd")
const NichePlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/niche_placer.gd")

static func plan(
	ctx: GenerationContext,
	analysis: EdgeAnalysisResult,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var facade_cols := analysis.facade_cols
	var sorted_xs := analysis.sorted_xs
	var edges := analysis.edges

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
					OutCornerPlacer.place(ctx, edge, state, plan, use_roots, w_open, e_open)
					continue

				EdgeKind.Kind.STEP:
					StepPlacer.place(ctx, edge, state, plan, use_roots, left_y, right_y, analysis.edges)
					continue

				EdgeKind.Kind.SLOPE:
					SlopePlacer.place(ctx, edge, state, plan)
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
