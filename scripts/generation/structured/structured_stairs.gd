extends RefCounted

## Korytarz = schody (układ structured, ścieki): prosty korytarz (ściany po obu stronach), który jest JEDYNYM przejściem
## do obszaru na północ od siebie (pokój albo kilka pomieszczeń), na całej długości to schody w górę na północ — obszar
## leży wyżej. Grafika: stopnie modułu schodów platform (`platform_tiles.stairs`, bez poręczy — korytarz ma ściany),
## efekt wysokości: HeightVeil (reszta mapy pod voidem po wejściu `veil_rows` kratek schodów w górę albo w obszarze).
## Config: structured_layout.corridor_stairs {"chance": 0.7, "max": 3, "min_len": 4, "max_width": 4, "zone": [30, 900],
##   "veil_rows": 4, "portal_ring": 2}. Na razie tylko korytarze północne — jedyne schody paczki.

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Wybrane korytarze-schody -> canals.stair_corridors: {rect: Rect2i (kolumny korytarza, od górnego rzędu w dół),
## zone: Array[Vector2i] (obszar wyżej), veil_rows: int}; kratki -> canals.stair_cells. Zwraca liczbę.
static func select(ctx: GenerationContext, canals, cfg: Dictionary) -> int:
	if canals == null or cfg.is_empty() or not "stair_corridors" in canals:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "corridor_stairs"])
	var bad := _bad_cells(ctx, canals, int(cfg.get("portal_ring", 2)))
	var zr: Array = cfg.get("zone", [30, 900])
	var taken := {}
	var out := 0
	for seg in _segments(ctx.grid, canals, bad, int(cfg.get("min_len", 4)), int(cfg.get("max_width", 4))):
		if out >= int(cfg.get("max", 3)):
			break
		var r: Rect2i = seg
		if taken.has(r.position):
			continue
		var zone := _dead_end(ctx, canals, r, int(zr[0]), int(zr[1]))
		if zone.is_empty() or _overlaps(zone, taken):
			continue
		if rng.randf() >= float(cfg.get("chance", 0.7)):
			continue
		var cells: Array[Vector2i] = []
		for p in zone:
			cells.append(p)
			taken[p] = true
		cells.sort()
		canals.stair_corridors.append({"rect": r, "zone": cells, "veil_rows": int(cfg.get("veil_rows", 4))})
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				canals.stair_cells[Vector2i(x, y)] = true
				taken[Vector2i(x, y)] = true
		out += 1
	return out


## Kratki, przez które korytarz-schody nie przejdzie: woda, kładki, barierki, doły, ściany szer. 1, korytarze serwisowe
## (bramy GatePlanner), chodniki, portale z pierścieniem.
static func _bad_cells(ctx: GenerationContext, canals, ring: int) -> Dictionary:
	var bad := {}
	for src in [canals.water, canals.bridge_cells, canals.bridge_clearance, canals.rail_cells, canals.pit_cells,
			canals.walls_1w, canals.service, canals.lanes]:
		bad.merge(src)
	for p in ctx.portal_zone:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				bad[p + Vector2i(dx, dy)] = true
	return bad


## Proste pionowe korytarze: rząd kratek [x0..x1] (szerokość <= max_w) ze ścianą po obu stronach, ten sam przez
## >= min_len kolejnych rzędów, z przejściem nad i pod -> Rect2i (od górnego rzędu). Kolejność stała.
static func _segments(grid: Dictionary, canals, bad: Dictionary, min_len: int, max_w: int) -> Array:
	var rows := {}  # Vector2i(x0, x1) -> Array[int] y
	var ys := {}
	for p in grid:
		ys[p.y] = true
	for p: Vector2i in grid:
		# Początek rzędu: chodliwa kratka ze ścianą po lewej.
		if not _ok(grid, canals, bad, p) or GridUtils.is_walkable(grid, p + Vector2i(-1, 0)):
			continue
		var x1 := p.x
		while x1 - p.x + 1 <= max_w and _ok(grid, canals, bad, Vector2i(x1 + 1, p.y)):
			x1 += 1
		if x1 - p.x + 1 > max_w or GridUtils.is_walkable(grid, Vector2i(x1 + 1, p.y)):
			continue
		var key := Vector2i(p.x, x1)
		if not rows.has(key):
			rows[key] = []
		(rows[key] as Array).append(p.y)
	var out: Array = []
	var keys := rows.keys()
	keys.sort()
	for key: Vector2i in keys:
		var yl: Array = rows[key]
		yl.sort()
		var a: int = yl[0]
		for i in range(1, yl.size() + 1):
			if i < yl.size() and int(yl[i]) == int(yl[i - 1]) + 1:
				continue
			var b: int = yl[i - 1]
			if b - a + 1 >= min_len:
				out.append(Rect2i(key.x, a, key.y - key.x + 1, b - a + 1))
			if i < yl.size():
				a = yl[i]
	return out


static func _ok(grid: Dictionary, canals, bad: Dictionary, p: Vector2i) -> bool:
	return GridUtils.is_walkable(grid, p) and not bad.has(p) and not canals.blocked.has(p)


## Obszar na północ od korytarza `r`, gdy korytarz jest jedynym przejściem do niego: flood od kratek nad górnym
## rzędem bez kratek korytarza nie dochodzi pod korytarz ani do wejścia, rozmiar w [lo, hi]. Inaczej {}.
static func _dead_end(ctx: GenerationContext, canals, r: Rect2i, lo: int, hi: int) -> Dictionary:
	var grid := ctx.grid
	var seen := {}
	var stack: Array[Vector2i] = []
	for x in range(r.position.x, r.end.x):
		var top := Vector2i(x, r.position.y - 1)
		if not GridUtils.is_walkable(grid, top):
			return {}
		seen[top] = true
		stack.append(top)
	var below := {}
	for x in range(r.position.x, r.end.x):
		below[Vector2i(x, r.end.y)] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if below.has(c) or c == ctx.entrance_pos or seen.size() > hi:
			return {}
		for d in DIRS4:
			var q: Vector2i = c + d
			if seen.has(q) or r.has_point(q) or not GridUtils.is_walkable(grid, q) or canals.blocked.has(q):
				continue
			seen[q] = true
			stack.append(q)
	if seen.size() < lo:
		return {}
	return seen


static func _overlaps(a: Dictionary, b: Dictionary) -> bool:
	for p in a:
		if b.has(p):
			return true
	return false
