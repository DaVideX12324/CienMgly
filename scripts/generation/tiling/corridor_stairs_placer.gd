extends RefCounted

## Kafle korytarzy-schodów (canals.stair_corridors, StructuredStairs) na warstwie Platforms: stopnie modułu schodów
## platform (generator_behaviour.platform_tiles.stairs: kolumny poręcz, L, M, R, poręcz; rzędy góra / środek / dół) —
## bez poręczy, bo korytarz ma ściany. Kolumny: 1 -> M, 2 -> L R, więcej -> L M… R; rzędy: górny rząd korytarza = góra
## modułu, dolny = dół, pomiędzy powtarzany środek.

const LAYER := &"Platforms"
const PORTAL_LAYER := &"FloorDecor"  # schody portali: Platforms należy do płaskowyżów (testy jaskiń, renderer)
## Gradient na stopniu przy voidzie (generator_behaviour.portal_stairs_shade): osobna warstwa na samej górze
## (nad ścianami i postaciami — decyzja usera), tworzona przez prepare_cave_layers tylko przy schodach portali.
const SHADE_LAYER := &"PortalShade"
## Alternatywy kafla gradientu w caves.tres (ciemna strona kafla w arkuszu = E) — domyślne, gdy config nie poda
## portal_stairs_shade.alternatives: 1 flip_h (W), 2 transpose (S), 3 transpose + flip_v (N).
const SHADE_ALTERNATIVES := {"E": 0, "W": 1, "S": 2, "N": 3}


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
		# wyjście: schody poza jaskinię — kafle przeciwnego kierunku niż na wejściu
		if not ps.get("entrance", false):
			dir = {"N": "S", "S": "N", "E": "W", "W": "E"}.get(dir, dir)
		var r: Rect2i = ps.rect
		var void_side := String(ps.get("dir", "N"))  # strona voidu = kierunek krawędzi (bez zamiany kafli wejścia)
		var mc: Dictionary = pst.get(dir, ctx.generator_behaviour.get("platform_tiles", {}).get("stairs", {}) if dir == "N" else {})
		if mc.is_empty():
			push_warning("CorridorStairsPlacer: brak portal_stairs_tiles.%s — schody portalu bez kafli" % dir)
			continue
		if dir == "E" or dir == "W":
			_plan_copy(ctx, tiles, r, mc, PORTAL_LAYER, void_side)
		else:
			var one: Array[Rect2i] = [r]
			_plan_rects(ctx, tiles, one, mc, PORTAL_LAYER, void_side)
		_plan_shade(ctx, tiles, r, void_side)


## Schody boczne E / W. Z "middle": [kol, wiersz] (kolumna środków w arkuszu, tyle wierszy co moduł) — w poziomie
## lewy łącznik (kolumna 0 modułu), środki powtarzane, prawy łącznik (ostatnia kolumna); w pionie górny wiersz,
## powtarzany środkowy, dolny. Bez "middle": moduł 1:1 powtarzany (size) jak dawniej.
static func _plan_copy(ctx: GenerationContext, tiles: TilePlacementPlan, r: Rect2i, cfg: Dictionary, layer: StringName, void_side: String = "") -> void:
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
				# stopień przy voidzie (W: lewy, E: prawy koniec) — dalej środek, nie łącznik (gradient na nim)
				var at_void := (void_side == "W" and x == r.position.x) or (void_side == "E" and x == r.end.x - 1)
				if x == r.position.x and not at_void:
					p.atlas_coords = o + Vector2i(0, row)
				elif x == r.end.x - 1 and not at_void:
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


static func _plan_rects(ctx: GenerationContext, tiles: TilePlacementPlan, rects: Array[Rect2i], cfg: Dictionary, layer: StringName = LAYER, void_side: String = "") -> void:
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
			# stopień przy voidzie (N: górny, S: dolny rząd) — dalej środek modułu (gradient na nim)
			if (void_side == "N" and y == r.position.y) or (void_side == "S" and y == r.end.y - 1):
				row = mini(1, last_row)
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


## Gradient w stronę voidu na stopniu przy voidzie (rząd / kolumna schodów od strony krawędzi) — kafel
## generator_behaviour.portal_stairs_shade {source, coords} (ciemna strona kafla = E), alternatywa wg strony voidu (alternatives).
static func _plan_shade(ctx: GenerationContext, tiles: TilePlacementPlan, r: Rect2i, void_side: String) -> void:
	var cfg: Dictionary = ctx.generator_behaviour.get("portal_stairs_shade", {})
	var alts: Dictionary = cfg.get("alternatives", SHADE_ALTERNATIVES)
	if cfg.is_empty() or not alts.has(void_side):
		return
	var co: Array = cfg.get("coords", [0, 0])
	var cells: Array[Vector2i] = []
	match void_side:
		"N":
			for x in range(r.position.x, r.end.x):
				cells.append(Vector2i(x, r.position.y))
		"S":
			for x in range(r.position.x, r.end.x):
				cells.append(Vector2i(x, r.end.y - 1))
		"W":
			for y in range(r.position.y, r.end.y):
				cells.append(Vector2i(r.position.x, y))
		"E":
			for y in range(r.position.y, r.end.y):
				cells.append(Vector2i(r.end.x - 1, y))
	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})
	for c in cells:
		var p := TilePlacement.new()
		p.pos = c
		p.layer = SHADE_LAYER
		p.source_id = int(cfg.get("source", 0))
		p.atlas_coords = Vector2i(int(co[0]), int(co[1]))
		p.alternative_tile = int(alts[void_side])
		p.category = &"STAIR"
		p.origin = r.position
		p.tie_breaker = 10
		PlacementPriority.assign(p, table)
		tiles.queue(p)
