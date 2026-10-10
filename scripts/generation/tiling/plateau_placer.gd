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
	var jobs: Array = []  # [k, maska, focus, udział w postępie]
	var total := 0.0
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
		var share := float(focus.size() if k <= 0 else m.size())
		jobs.append([k, m, focus, share])
		total += share
	var done := 0.0
	for job in jobs:
		var k: int = job[0]
		var m: Dictionary = job[1]
		var focus: Dictionary = job[2]
		# Postęp paska: każdy poziom dostaje część etapu proporcjonalną do swojej wielkości.
		var from := done / maxf(total, 1.0)
		done += float(job[3])
		var res: Dictionary = PlateauRenderer.render(ctx, m, placement_plan.by_layer.get(&"Walls", {}), focus, from, done / maxf(total, 1.0))
		if int(res.missing) > 0:
			push_warning("PlateauPlacer: %d kafli bez roli w '%s' (pominięte)" % [res.missing, PlateauRenderer.tileset_id(ctx)])
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
			if not _put_stair(ctx, placement_plan, Vector2i(st.x, st.z + 1), TileModuleRole.Id.STAIR_SINGLE, table):
				_hole(ctx, placement_plan, 0, st, table)
		else:
			for x in range(st.x, st.x + st.y):
				var role: int = TileModuleRole.Id.STAIR_MID
				if x == st.x:
					role = TileModuleRole.Id.STAIR_LEFT
				elif x == st.x + st.y - 1:
					role = TileModuleRole.Id.STAIR_RIGHT
				if not _put_stair(ctx, placement_plan, Vector2i(x, st.z + 1), role, table):
					_hole(ctx, placement_plan, 0, st, table)
					break

	for st in ctx.plateau.stairs_north:
		if st.y == 1:
			if not _put_stair(ctx, placement_plan, Vector2i(st.x, st.z), TileModuleRole.Id.STAIR_NORTH_SINGLE, table):
				_hole(ctx, placement_plan, 1, st, table)
		else:
			for x in range(st.x, st.x + st.y):
				var role: int = TileModuleRole.Id.STAIR_NORTH_MID
				if x == st.x:
					role = TileModuleRole.Id.STAIR_NORTH_LEFT
				elif x == st.x + st.y - 1:
					role = TileModuleRole.Id.STAIR_NORTH_RIGHT
				if not _put_stair(ctx, placement_plan, Vector2i(x, st.z), role, table):
					_hole(ctx, placement_plan, 1, st, table)
					break

	for st in ctx.plateau.stairs_east:
		var role: int = TileModuleRole.Id.STAIR_EAST_1H if st.z == 1 else TileModuleRole.Id.STAIR_EAST_3H
		if not _put_stair(ctx, placement_plan, Vector2i(st.x, st.y), role, table, st.z):
			_hole(ctx, placement_plan, 2, st, table)

	for st in ctx.plateau.stairs_west:
		var role: int = TileModuleRole.Id.STAIR_WEST_1H if st.z == 1 else TileModuleRole.Id.STAIR_WEST_3H
		if not _put_stair(ctx, placement_plan, Vector2i(st.x, st.y), role, table, st.z):
			_hole(ctx, placement_plan, 3, st, table)


## Schody bez kafli w zestawie (np. ścieki: paczka ma tylko schody S) -> przejście w krawędzi platformy:
## kafle Platforms na kratkach schodów wymazane (kategoria STAIR wygrywa z rimem / bokiem / licem), widać podłogę.
## Kratki schodów są chodliwe (PlateauLayout.stair_cells), więc dojście działa bez grafiki schodów.
static func _hole(ctx: GenerationContext, placement_plan: TilePlacementPlan, dir: int, st: Vector3i, table: Dictionary) -> void:
	var tmp := PlateauLayout.new()
	tmp.face_up = ctx.plateau.face_up
	tmp.face_down = ctx.plateau.face_down
	([tmp.stairs, tmp.stairs_north, tmp.stairs_east, tmp.stairs_west][dir] as Array).append(st)
	for c in tmp.stair_cells():
		var p := TilePlacement.new()
		p.pos = c
		p.layer = LAYER
		p.source_id = -1
		p.atlas_coords = Vector2i(-1, -1)
		p.category = &"STAIR"
		p.origin = c
		p.tie_breaker = 10
		PlacementPriority.assign(p, table)
		placement_plan.queue(p)


## height > 3 (schody boczne 3H): moduł rozciągnięty — wiersz górny, środkowy powtórzony
## height-2 razy, dolny (tak jak szerokie schody S/N dokładają modułów MID).
## False, gdy zestaw nie ma roli — wołający zostawia przejście (_hole).
static func _put_stair(ctx: GenerationContext, placement_plan: TilePlacementPlan, anchor: Vector2i, role: int, table: Dictionary, height: int = 0) -> bool:
	var parts := TileResolver.resolve_in_set(ctx, PlateauRenderer.platform_tileset(ctx), anchor, role)
	if parts.is_empty():
		return false
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
	return true
