class_name PlateauPlacer
extends RefCounted


## Kafle płaskowyżów na warstwie Platforms: kształt z PlateauRenderera (pipeline ścian w trybie
## płaskowyżu), potem schody [LEFT][MID…][RIGHT] w miejscu lica (kategoria STAIR > FACADE).
## Musi iść PO ścianach — PlateauRenderer dzieli prawdziwe ściany na krawędzie i void z planu Walls.

const LAYER := &"Platforms"
const LEVEL_TIE_STEP := 1000000  # wyższy poziom wygrywa remis w tej samej kratce


static func plan(ctx: GenerationContext, placement_plan: TilePlacementPlan) -> void:
	if ctx.plateau == null or ctx.plateau.is_empty() or ctx.map_tile_profile == null:
		return
	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})

	# Każdy poziom osobno, tym samym pipeline'em (poziom niżej = „ziemia”). Poziomy <= 0 to ziemia
	# nad zagłębieniami — rysowana tylko w okolicy dołów (focus), krawędzie dołu to jej krawędzie.
	# Przy konflikcie w jednej kratce wygrywa wyższy poziom (tie_breaker).
	var pl = ctx.plateau
	var keys: Array = pl.levels.keys() if not pl.levels.is_empty() else [1]
	keys.sort()
	for k in keys:
		var m: Dictionary = pl.levels.get(k, pl.mask)
		if m.is_empty():
			continue
		var focus := {}
		if k <= 0:
			for c in pl.heights:
				if int(pl.heights[c]) < k:
					focus[c] = true
			if focus.is_empty():
				continue
		var res: Dictionary = PlateauRenderer.render(ctx, m, placement_plan.by_layer.get(&"Walls", {}), focus)
		if int(res.missing) > 0:
			push_warning("PlateauPlacer: %d kafli bez roli w '%s' (pominięte)" % [res.missing, PlateauRenderer.TILESET_ID])
		for pos in res.tiles:
			var src: TilePlacement = res.tiles[pos]
			var p := TilePlacement.new()
			p.pos = pos
			p.layer = LAYER
			p.source_id = src.source_id
			p.atlas_coords = src.atlas_coords
			p.alternative_tile = src.alternative_tile
			p.category = src.category
			p.origin = src.origin
			p.tie_breaker = src.tie_breaker + (k - pl.min_level) * LEVEL_TIE_STEP
			PlacementPriority.assign(p, table)
			placement_plan.queue(p)

	for st in ctx.plateau.stairs:
		if st.y == 1:
			_put_stair(ctx, placement_plan, Vector2i(st.x, st.z + 1), TileModuleRole.Id.STAIR_SINGLE, table)
		else:
			for x in range(st.x, st.x + st.y):
				var role: int = TileModuleRole.Id.STAIR_MID
				if x == st.x:
					role = TileModuleRole.Id.STAIR_LEFT
				elif x == st.x + st.y - 1:
					role = TileModuleRole.Id.STAIR_RIGHT
				_put_stair(ctx, placement_plan, Vector2i(x, st.z + 1), role, table)

	for st in ctx.plateau.stairs_north:
		if st.y == 1:
			_put_stair(ctx, placement_plan, Vector2i(st.x, st.z), TileModuleRole.Id.STAIR_NORTH_SINGLE, table)
		else:
			for x in range(st.x, st.x + st.y):
				var role: int = TileModuleRole.Id.STAIR_NORTH_MID
				if x == st.x:
					role = TileModuleRole.Id.STAIR_NORTH_LEFT
				elif x == st.x + st.y - 1:
					role = TileModuleRole.Id.STAIR_NORTH_RIGHT
				_put_stair(ctx, placement_plan, Vector2i(x, st.z), role, table)

	for st in ctx.plateau.stairs_east:
		var role: int = TileModuleRole.Id.STAIR_EAST_1H if st.z == 1 else TileModuleRole.Id.STAIR_EAST_3H
		_put_stair(ctx, placement_plan, Vector2i(st.x, st.y), role, table, st.z)

	for st in ctx.plateau.stairs_west:
		var role: int = TileModuleRole.Id.STAIR_WEST_1H if st.z == 1 else TileModuleRole.Id.STAIR_WEST_3H
		_put_stair(ctx, placement_plan, Vector2i(st.x, st.y), role, table, st.z)


## height > 3 (schody boczne 3H): moduł rozciągnięty — wiersz górny, środkowy powtórzony
## height-2 razy, dolny (tak jak szerokie schody S/N dokładają modułów MID).
static func _put_stair(ctx: GenerationContext, placement_plan: TilePlacementPlan, anchor: Vector2i, role: int, table: Dictionary, height: int = 0) -> void:
	var parts := TileResolver.resolve_strict(ctx, PlateauRenderer.TILESET_ID, anchor, role)
	if parts.is_empty():
		push_warning("PlateauPlacer: brak %s w '%s'" % [TileModuleRole.name_of(role), PlateauRenderer.TILESET_ID])
		return
	var cells: Array = []  # [pozycja, część]
	for rp in parts:
		if height > 3 and rp.offset.y == 1:
			for k in range(height - 2):
				cells.append([anchor + Vector2i(rp.offset.x, 1 + k), rp])
		elif height > 3 and rp.offset.y == 2:
			cells.append([anchor + Vector2i(rp.offset.x, height - 1), rp])
		else:
			cells.append([anchor + rp.offset, rp])
	for cell in cells:
		var rp = cell[1]
		var p := TilePlacement.new()
		p.pos = cell[0]
		p.layer = LAYER
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"STAIR"
		p.origin = anchor
		p.tie_breaker = 10
		PlacementPriority.assign(p, table)
		placement_plan.queue(p)
