extends RefCounted

## Kafle korytarzy-schodów (canals.stair_corridors, StructuredStairs) na warstwie Platforms: stopnie modułu schodów
## platform (generator_behaviour.platform_tiles.stairs: kolumny poręcz, L, M, R, poręcz; rzędy góra / środek / dół) —
## bez poręczy, bo korytarz ma ściany. Kolumny: 1 -> M, 2 -> L R, więcej -> L M… R; rzędy: górny rząd korytarza = góra
## modułu, dolny = dół, pomiędzy powtarzany środek.

const LAYER := &"Platforms"
const PORTAL_LAYER := &"FloorDecor"  # schody portali: Platforms należy do płaskowyżów (testy jaskiń, renderer)


static func plan(ctx: GenerationContext, tiles: TilePlacementPlan) -> void:
	var rects: Array[Rect2i] = []
	var canals = ctx.canals
	if canals != null and "stair_corridors" in canals:
		for sc in canals.stair_corridors:
			rects.append(sc.rect)
	if not rects.is_empty():
		_plan_rects(ctx, tiles, rects, ctx.generator_behaviour.get("platform_tiles", {}).get("stairs", {}))
	# schody wejścia / wyjścia (portal_style "stairs" / "alcove_stairs") — moduł portal_stairs_tiles[kierunek]: N i S jak
	# korytarze (L / M / R, góra / środek / dół), E i W — kafle 1:1 (moduł wielkości schodów)
	var pst: Dictionary = ctx.generator_behaviour.get("portal_stairs_tiles", {})
	for ps in ctx.portal_stairs:
		var dir := String(ps.get("dir", "N"))
		# wejście: schody w dół do jaskini — kafle przeciwnego kierunku niż na wyjściu (w górę)
		if ps.get("entrance", false):
			dir = {"N": "S", "S": "N", "E": "W", "W": "E"}.get(dir, dir)
		var r: Rect2i = ps.rect
		var mc: Dictionary = pst.get(dir, ctx.generator_behaviour.get("platform_tiles", {}).get("stairs", {}) if dir == "N" else {})
		if mc.is_empty():
			push_warning("CorridorStairsPlacer: brak portal_stairs_tiles.%s — schody portalu bez kafli" % dir)
			continue
		if dir == "E" or dir == "W":
			_plan_copy(ctx, tiles, r, mc, PORTAL_LAYER)
		else:
			var one: Array[Rect2i] = [r]
			_plan_rects(ctx, tiles, one, mc, PORTAL_LAYER)


## Schody boczne E / W. Z "middle": [kol, wiersz] (kolumna środków w arkuszu, tyle wierszy co moduł) — w poziomie
## lewy łącznik (kolumna 0 modułu), środki powtarzane, prawy łącznik (ostatnia kolumna); w pionie górny wiersz,
## powtarzany środkowy, dolny. Bez "middle": moduł 1:1 powtarzany (size) jak dawniej.
static func _plan_copy(ctx: GenerationContext, tiles: TilePlacementPlan, r: Rect2i, cfg: Dictionary, layer: StringName) -> void:
	var src := int(cfg.get("source", 0))
	var org: Array = cfg.get("origin", [0, 0])
	var o := Vector2i(int(org[0]), int(org[1]))
	var sz: Array = cfg.get("size", [r.size.x, r.size.y])
	var ms := Vector2i(maxi(int(sz[0]), 1), maxi(int(sz[1]), 1))
	var mid: Array = cfg.get("middle", [])
	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := TilePlacement.new()
			p.pos = Vector2i(x, y)
			p.layer = layer
			p.source_id = src
			if mid.size() >= 2 and ms.y >= 2:
				var row := 0 if y == r.position.y else (ms.y - 1 if y == r.end.y - 1 else mini(1, ms.y - 1))
				if x == r.position.x:
					p.atlas_coords = o + Vector2i(0, row)
				elif x == r.end.x - 1:
					p.atlas_coords = o + Vector2i(ms.x - 1, row)
				else:
					p.atlas_coords = Vector2i(int(mid[0]), int(mid[1])) + Vector2i(0, row)
			else:
				# moduł powtarzany (schody dłuższe niż moduł)
				p.atlas_coords = o + Vector2i(posmod(x - r.position.x, ms.x), posmod(y - r.position.y, ms.y))
			p.category = &"STAIR"
			p.origin = r.position
			p.tie_breaker = 10
			PlacementPriority.assign(p, table)
			tiles.queue(p)


static func _plan_rects(ctx: GenerationContext, tiles: TilePlacementPlan, rects: Array[Rect2i], cfg: Dictionary, layer: StringName = LAYER) -> void:
	if cfg.is_empty():
		push_warning("CorridorStairsPlacer: brak modułu schodów (platform_tiles.stairs / portal_stairs_tiles) — schody bez kafli")
		return
	var src := int(cfg.get("source", 0))
	var org: Array = cfg.get("origin", [0, 0])
	var sz: Array = cfg.get("size", [5, 3])
	var o := Vector2i(int(org[0]), int(org[1]))
	var last_col := int(sz[0]) - 2   # kolumna R (przed prawą poręczą)
	var last_row := int(sz[1]) - 1
	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})
	for r in rects:
		for y in range(r.position.y, r.end.y):
			var row := 0 if y == r.position.y else (last_row if y == r.end.y - 1 else mini(1, last_row))
			for x in range(r.position.x, r.end.x):
				var col := 2
				if r.size.x >= 2 and x == r.position.x:
					col = 1
				elif r.size.x >= 2 and x == r.end.x - 1:
					col = last_col
				var p := TilePlacement.new()
				p.pos = Vector2i(x, y)
				p.layer = layer
				p.source_id = src
				p.atlas_coords = o + Vector2i(col, row)
				p.category = &"STAIR"
				p.origin = r.position
				p.tie_breaker = 10
				PlacementPriority.assign(p, table)
				tiles.queue(p)
