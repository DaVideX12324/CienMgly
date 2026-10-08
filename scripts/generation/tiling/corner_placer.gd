class_name CornerPlacer
extends RefCounted


static func _queue(placement_plan: TilePlacementPlan, pos: Vector2i, atlas_coords: Vector2i, category: StringName, table: Dictionary) -> void:
	var p := TilePlacement.new()
	p.pos = pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	PlacementPriority.assign(p, table)
	placement_plan.queue(p)


## Narożnik wewnętrzny schodka przy łączniku 3H↔4H (krawędź w kolumnie łącznika albo obok, w wysokości lica —
## przed podniesieniem o rząd / dwa nad lico).
static func _over_connector(ctx: GenerationContext, pos: Vector2i) -> bool:
	if ctx.facade_4h_connectors.is_empty():
		return false
	for dx in [-1, 0, 1]:
		for dy in range(1, 8):
			if ctx.facade_4h_connectors.has(pos + Vector2i(dx, dy)):
				return true
	return false


## Ścieżka modułowa (1 kafel, kategoria CORNER, tie_breaker=0 jak legacy). true jeśli położono.
static func _try_corner(ctx: GenerationContext, placement_plan: TilePlacementPlan, pos: Vector2i, module_role: TileModuleRole.Id, variant_id: StringName, table: Dictionary, force_id: StringName = &"") -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, pos, module_role, [], -1, variant_id, force_id)
	if parts.is_empty():
		return false
	for rp in parts:
		var p := TilePlacement.new()
		p.pos = pos + rp.offset
		p.layer = rp.layer if rp.layer != &"" else &"Walls"
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"CORNER"
		PlacementPriority.assign(p, table)
		placement_plan.queue(p)
	return true


## Planuje wyłącznie diagonalne INNER_CORNER na podstawie klasyfikacji EdgeAnalyzer (SSOT).
static func plan(
	ctx: GenerationContext,
	edges: Dictionary,
	state: LegacyPlacementState,
	placement_plan: TilePlacementPlan
) -> void:
	var scan := ctx.scan_bounds()
	var table := ctx.priority_table

	for y in range(scan.position.y, scan.end.y):
		for x in range(scan.position.x, scan.end.x):
			var pos := Vector2i(x, y)
			var edge: EdgeContext = edges.get(pos)
			if edge == null or edge.edge_kind != EdgeKind.Kind.INNER_CORNER or edge.is_protected_solid:
				continue
			# Nad łącznikiem 3H↔4H wierzch muru biegnie równo — narożnik schodka zbędny (sterczący rant).
			if _over_connector(ctx, pos):
				continue

			# Narożnik wewnętrzny SW / SE stoi na wysokości góry lica: rząd wyżej przy licu 4H i rząd wyżej przy licu
			# na kratkach ściany (facade_base_on_wall). Nad końcem lica zwolnione kratki zajmuje moduł; obok lica —
			# ściana boczna.
			var lift := 0
			var side_role: int = TileModuleRole.Id.NONE
			if edge.orientation in [EdgeKind.Orientation.SOUTH_WEST, EdgeKind.Orientation.SOUTH_EAST]:
				var dx := 1 if edge.orientation == EdgeKind.Orientation.SOUTH_WEST else -1
				var off := FacadePlacer.facade_row_offset(ctx)
				var above_end := state.has(pos + Vector2i(0, 1)) and state.get_category(pos + Vector2i(0, 1)) == &"FACADE"
				if ctx.facade_4h_tops.has(pos) or ctx.facade_4h_tops.has(pos + Vector2i(dx, -1)):
					lift = 1 + off
				else:
					lift = off
				if lift > 0 and not above_end and not ctx.facade_4h_tops.has(pos) and state.is_empty_or_rock(pos):
					side_role = TileModuleRole.Id.SIDE_WALL_EAST if dx == 1 else TileModuleRole.Id.SIDE_WALL_WEST
				elif lift > off and not ctx.facade_4h_tops.has(pos):
					# Obok wyższego lica 4H (narożnik podniesiony nad koniec niższego lica): odsłonięty bok wyższego lica
					# nad wierzchem niższego dostaje ścianę boczną — kratki zajęte przez lico pętla i tak pomija.
					side_role = TileModuleRole.Id.SIDE_WALL_EAST if dx == 1 else TileModuleRole.Id.SIDE_WALL_WEST
			for _l in lift:
				if side_role != TileModuleRole.Id.NONE and state.is_empty_or_rock(pos) \
						and _try_corner(ctx, placement_plan, pos, side_role, &"A", table, &""):
					state.mark(pos, &"SIDE")
				pos += Vector2i(0, -1)
			if not state.is_empty_or_rock(pos):
				continue

			var wall_cells: Dictionary = placement_plan.by_layer.get(&"Walls", {})
			var placement_under: TilePlacement = wall_cells.get(pos + Vector2i(0, 1))
			var tile_under: Vector2i = placement_under.atlas_coords if placement_under != null else Vector2i(-1, -1)

			var tile := Vector2i(-1, -1)
			var module_role: int = TileModuleRole.Id.NONE
			var variant_id: StringName = &"A"
			var force_id: StringName = &""

			match edge.orientation:
				EdgeKind.Orientation.NORTH_WEST:
					tile = Vector2i(1, 1)
					module_role = TileModuleRole.Id.INNER_CORNER_NW
				EdgeKind.Orientation.NORTH_EAST:
					tile = Vector2i(4, 1)
					module_role = TileModuleRole.Id.INNER_CORNER_NE
				EdgeKind.Orientation.SOUTH_WEST:
					module_role = TileModuleRole.Id.INNER_CORNER_SW
					if tile_under == CaveTileConstants.ROOT_MOD_CRNR_NE_IN_TOP:
						tile = CaveTileConstants.ROOT_CRNR_SW_IN
						force_id = &"caves_roots"
					else:
						tile = CaveTileConstants.CRNR_SW_IN
				EdgeKind.Orientation.SOUTH_EAST:
					module_role = TileModuleRole.Id.INNER_CORNER_SE
					if tile_under == CaveTileConstants.ROOT_MOD_CRNR_NW_IN_TOP:
						tile = CaveTileConstants.ROOT_CRNR_SE_IN
						force_id = &"caves_roots"
					else:
						tile = CaveTileConstants.CRNR_SE_IN

			if tile != Vector2i(-1, -1):
				if not _try_corner(ctx, placement_plan, pos, module_role, variant_id, table, force_id):
					_queue(placement_plan, pos, tile, &"CORNER", table)
				state.mark(pos, &"CORNER")
