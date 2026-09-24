class_name PortalClearPlacer
extends RefCounted


## Planuje wymazanie kafelków ścian na polach portali (entrance_zone i exit_zone).
static func plan(ctx: GenerationContext, placement_plan: TilePlacementPlan) -> void:
	var portal_cells: Dictionary = {}
	for pos in ctx.entrance_zone:
		portal_cells[pos] = true
	for pos in ctx.exit_zone:
		portal_cells[pos] = true

	if OS.is_debug_build() and not ctx.portal_zone.is_empty():
		assert(ctx.portal_zone.size() == portal_cells.size(), "Portal zone size mismatch: %d vs %d" % [ctx.portal_zone.size(), portal_cells.size()])
		for pos in portal_cells.keys():
			assert(ctx.portal_zone.has(pos), "Portal zone missing cell %s" % str(pos))
		for pos in ctx.portal_zone.keys():
			assert(portal_cells.has(pos), "Portal zone has unexpected cell %s" % str(pos))

	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})

	for pos in portal_cells.keys():
		var placement := TilePlacement.new()
		placement.pos = pos
		placement.layer = &"Walls"
		placement.atlas_coords = Vector2i(-1, -1)
		placement.category = &"PORTAL_CLEAR"
		PlacementPriority.assign(placement, table)
		placement_plan.queue(placement)
