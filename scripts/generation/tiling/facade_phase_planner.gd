class_name FacadePhasePlanner
extends RefCounted



static func plan(
	ctx: GenerationContext,
	analysis: EdgeAnalysisResult,
	state: LegacyPlacementState,
	placement_plan: TilePlacementPlan
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
					OutCornerPlacer.place(ctx, edge, state, placement_plan, use_roots, w_open, e_open)
					continue

				EdgeKind.Kind.STEP:
					StepPlacer.place(ctx, edge, state, placement_plan, use_roots, left_y, right_y, analysis.edges)
					continue

				EdgeKind.Kind.CONNECTOR:
					ConnectorPlacer.place(ctx, edge, state, placement_plan)
					continue

				EdgeKind.Kind.FACADE:
					if edge.facade_height == 2:
						FacadePlacer.place_2h(ctx, edge, state, placement_plan)
						continue
					else:
						if NichePlacer.try_place_legacy(ctx, edge, state, placement_plan, use_roots, facade_cols):
							continue
						FacadePlacer.place_3h(ctx, edge, state, placement_plan, use_roots, left_y, right_y, edges)
						continue
				_:
					continue
