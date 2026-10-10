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

	var walls: Dictionary = placement_plan.get_placements(&"Walls")
	# Koniec schodów portalu przy krawędzi mapy (alcove_stairs): void bez ściany, jak wyjście w tutorialu.
	for pos in ctx.portal_void:
		for layer in [&"Walls", &"Floor", &"FloorDecor"]:
			var vp := TilePlacement.new()
			vp.pos = pos
			vp.layer = layer
			vp.atlas_coords = Vector2i(-1, -1)
			vp.category = &"PORTAL_CLEAR"
			if layer == &"Walls":
				# kafel voidu mapy (SOLID_FILL z profilu), żeby kolor zgadzał się z resztą voidu
				var parts := TileResolver.resolve_module_parts(ctx, pos, TileModuleRole.Id.SOLID_FILL)
				if not parts.is_empty():
					vp.source_id = parts[0].tile.source_id
					vp.atlas_coords = parts[0].tile.atlas_coords
					vp.alternative_tile = parts[0].tile.alternative_tile
			PlacementPriority.assign(vp, table)
			placement_plan.queue(vp)
	for pos in portal_cells.keys():
		# Dekoracja szczytu ściany (RIM_TIP — górna część rimu z korzeniami) wisi nad podłogą tuż nad rimem;
		# nie zasłania portalu, więc zostaje (zgłoszenie usera 2026-10-03: portal ucinał TOP rimów z dekoracją).
		var existing: TilePlacement = walls.get(pos)
		if existing != null and existing.category == &"RIM_TIP":
			continue
		var placement := TilePlacement.new()
		placement.pos = pos
		placement.layer = &"Walls"
		placement.atlas_coords = Vector2i(-1, -1)
		placement.category = &"PORTAL_CLEAR"
		PlacementPriority.assign(placement, table)
		placement_plan.queue(placement)
