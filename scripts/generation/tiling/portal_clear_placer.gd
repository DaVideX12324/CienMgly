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
	# Koniec schodów portalu przy krawędzi mapy (alcove_stairs): void bez ściany, jak wyjście w tutorialu. Także ściany
	# ZA schodami (decyzja usera 2026-10-11): kolumna / rząd voidu i 2 warstwy ochronne, od lica nad schodami do rzędu pod
	# nimi — bez kawałków lica i krawędzi ściany za ostatnim stopniem (tylko na kratkach niechodliwych).
	var void_cells: Dictionary = {}
	for pos in ctx.portal_void:
		void_cells[pos] = true
	for pos in behind_stairs_cells(ctx):
		void_cells[pos] = true
	for pos in void_cells:
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
	# Najwyższy stopień schodów portalu przy krawędzi mapy (gdzie schody zaczynają się od voidu na wejściu / wychodzą w void na wyjściu):
	# wymazanie podłogi na warstwie Floor, żeby nie prześwitywała za krawędzią schodów (widoczne tylko schody).
	for ps in ctx.portal_stairs:
		var r: Rect2i = ps.get("rect", Rect2i())
		var dir := String(ps.get("dir", ""))
		var top_row := Rect2i()
		match dir:
			"N": top_row = Rect2i(r.position, Vector2i(r.size.x, 1))
			"S": top_row = Rect2i(Vector2i(r.position.x, r.end.y - 1), Vector2i(r.size.x, 1))
			"W": top_row = Rect2i(r.position, Vector2i(1, r.size.y))
			"E": top_row = Rect2i(Vector2i(r.end.x - 1, r.position.y), Vector2i(1, r.size.y))
		for y in range(top_row.position.y, top_row.end.y):
			for x in range(top_row.position.x, top_row.end.x):
				var fp := TilePlacement.new()
				fp.pos = Vector2i(x, y)
				fp.layer = &"Floor"
				fp.atlas_coords = Vector2i(-1, -1)
				fp.category = &"PORTAL_CLEAR"
				PlacementPriority.assign(fp, table)
				placement_plan.queue(fp)
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


## Kratki ścian za schodami portalu (za ostatnim stopniem w stronę voidu): E / W — kolumny voidu + 2 ochronne, wiersze
## od BEHIND_UP nad schodami do rzędu pod nimi; N / S — rzędy voidu + 2, kolumny schodów ± 1. Tylko niechodliwe.
const BEHIND_UP := 4
static func behind_stairs_cells(ctx: GenerationContext) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for ps in ctx.portal_stairs:
		var r: Rect2i = ps.get("rect", Rect2i())
		var box := Rect2i()
		match String(ps.get("dir", "")):
			"E": box = Rect2i(r.end.x, r.position.y - BEHIND_UP, 3, r.size.y + BEHIND_UP + 1)
			"W": box = Rect2i(r.position.x - 3, r.position.y - BEHIND_UP, 3, r.size.y + BEHIND_UP + 1)
			"N": box = Rect2i(r.position.x - 1, r.position.y - 3, r.size.x + 2, 3)
			"S": box = Rect2i(r.position.x - 1, r.end.y, r.size.x + 2, 3)
			_: continue
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				var c := Vector2i(x, y)
				if x >= 0 and y >= 0 and x < ctx.width and y < ctx.height and not GridUtils.is_walkable(ctx.grid, c):
					out.append(c)
	return out
