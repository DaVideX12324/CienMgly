extends RefCounted

## Platformy układu structured (ścieki): podwyższona część pomieszczenia pod jego ścianą, z licem i schodami.
## Kształt stąd, schody i osiągalność — PlateauPass.solve_levels (wspólne z jaskiniami), kafle — PlateauPlacer.
## Pas pod ścianą północną: cała szerokość między ścianami bocznymi (bez drzwi w pasie), głębokość = rzędy góry
## + lico (plateau_face_h), przed licem wolna podłoga. Źródła: hale kompleksów, komnaty, większe pokoje.
## Config: structured_layout.platforms {
##   "sides": ["N"]           — strony ściany (na razie tylko N; miejsce na S / E / W w _strips),
##   "sources": {"hall": 0.6, "chamber": 0.4, "room": 0.3}   — szansa platformy w obszarze danego rodzaju,
##   "min_width": 8, "top_rows": [2, 3], "front": 3, "portal_ring": 3, "room_min_area": 90 }.
## Miejsce na rozszerzenie: „korytarz = schody” (cały prosty korytarz północny prowadzący do pokoju jako
## schody) — źródło "corridor" w _area_groups, na razie pomijane.

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Maska platform (kratka -> true) dla PlateauPass.solve_levels; pusta, gdy nic się nie zmieściło.
static func mask(ctx: GenerationContext, canals, flags: GenerationFlags, cfg: Dictionary) -> Dictionary:
	var out := {}
	if canals == null:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "structured_platforms"])
	var face_h := maxi(flags.plateau_face_h, 2)
	var sources: Dictionary = cfg.get("sources", {"hall": 0.6, "chamber": 0.4, "room": 0.3})
	var sides: Array = cfg.get("sides", ["N"])
	var excluded := _excluded(ctx, canals, int(cfg.get("portal_ring", 3)))
	for group in _area_groups(canals, sources):
		var kind: String = group[0]
		var cells: Dictionary = group[1]
		if kind == "room" and cells.size() < int(cfg.get("room_min_area", 90)):
			continue
		if rng.randf() >= float(sources.get(kind, 0.0)):
			continue
		var cands: Array = []
		for side in sides:
			cands.append_array(_strips(ctx, cells, excluded, canals.water, String(side), face_h, rng, cfg))
		if cands.is_empty():
			continue
		var strip: Dictionary = cands[rng.randi() % cands.size()]
		out.merge(strip)
	return out


## Obszary [rodzaj, {kratka: true}]: hale kompleksów (canals.areas "hall:N"), komnaty, pokoje ("room:N").
## Kolejność stała (klucze posortowane) — wynik zależy tylko od seeda.
static func _area_groups(canals, sources: Dictionary) -> Array:
	var by_key := {}
	for p in canals.areas:
		var key := String(canals.areas[p])
		if key == "corridor":
			continue  # miejsce na źródło "corridor" (korytarz = schody)
		if not by_key.has(key):
			by_key[key] = {}
		(by_key[key] as Dictionary)[p] = true
	var keys := by_key.keys()
	keys.sort()
	var out: Array = []
	for key in keys:
		var kind := String(key).get_slice(":", 0)
		if sources.has(kind):
			out.append([kind, by_key[key]])
	if sources.has("chamber"):
		for arr in canals.chambers:
			var cells := {}
			for p in arr:
				cells[p] = true
			out.append(["chamber", cells])
	return out


## Kratki, na których platforma nie stanie: woda (+1), chodniki, korytarze serwisowe, kładki z prześwitem,
## barierki, ściany szer. 1, doły, bramy, dźwignie, portale z pierścieniem.
static func _excluded(ctx: GenerationContext, canals, portal_ring: int) -> Dictionary:
	var ex := {}
	for src in [canals.water, canals.lanes, canals.service, canals.corridors, canals.blocked, canals.bridge_cells,
			canals.bridge_clearance, canals.rail_cells, canals.walls_1w, canals.pit_cells]:
		for p in src:
			ex[p] = true
	for p in canals.water:
		for d in DIRS4:
			ex[p + d] = true  # kratka od wody — brzeg z barierką
	for g in canals.gates:
		for p in g:
			ex[p] = true
	for p in canals.levers:
		ex[p] = true
	for p in ctx.portal_zone:
		for dy in range(-portal_ring, portal_ring + 1):
			for dx in range(-portal_ring, portal_ring + 1):
				ex[p + Vector2i(dx, dy)] = true
	return ex


## Pasy pod ścianą strony `side` w obszarze `cells` — każdy jako maska. Na razie tylko "N": bieg kratek
## z niechodliwą kratką nad sobą, od ściany do ściany (bez drzwi z boku w rzędach pasa), głębokość
## top_rows + face_h, przed licem `front` rzędów suchej podłogi (`wet` = woda).
static func _strips(ctx: GenerationContext, cells: Dictionary, excluded: Dictionary, wet: Dictionary, side: String, face_h: int, rng: RandomNumberGenerator, cfg: Dictionary) -> Array:
	var out: Array = []
	if side != "N":
		return out  # S / E / W: lico w innym kierunku — schody i kafle tylko dla lica południowego
	var grid := ctx.grid
	var min_w := int(cfg.get("min_width", 8))
	var tr: Array = cfg.get("top_rows", [2, 3])
	var depth: int = rng.randi_range(int(tr[0]), int(tr[1])) + face_h
	var front := int(cfg.get("front", 3))
	var rows := {}  # y -> Array[x]
	for p in cells:
		if GridUtils.is_walkable(grid, p) and not GridUtils.is_walkable(grid, p + Vector2i(0, -1)):
			if not rows.has(p.y):
				rows[p.y] = []
			(rows[p.y] as Array).append(p.x)
	var ys := rows.keys()
	ys.sort()
	for y in ys:
		var xs: Array = rows[y]
		xs.sort()
		var a: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and int(xs[i]) == int(xs[i - 1]) + 1:
				continue
			var b: int = xs[i - 1]
			if b - a + 1 >= min_w and _strip_ok(grid, cells, excluded, wet, a, b, y, depth, front):
				var m := {}
				for yy in range(y, y + depth):
					for x in range(a, b + 1):
						m[Vector2i(x, yy)] = true
				out.append(m)
			if i < xs.size():
				a = xs[i]
	return out


static func _strip_ok(grid: Dictionary, cells: Dictionary, excluded: Dictionary, wet: Dictionary, a: int, b: int, y: int, depth: int, front: int) -> bool:
	for yy in range(y, y + depth + front):
		for x in range(a, b + 1):
			var p := Vector2i(x, yy)
			if not GridUtils.is_walkable(grid, p):
				return false
			# Pas: w obszarze, bez wykluczonych; przed licem wystarczy sucha podłoga (korytarz / chodnik może biec).
			if yy < y + depth and (not cells.has(p) or excluded.has(p)):
				return false
			if yy >= y + depth and wet.has(p):
				return false
	# Od ściany do ściany: z boku pasa ściana w każdym rzędzie (drzwi z boku odpadają).
	for yy in range(y, y + depth):
		if GridUtils.is_walkable(grid, Vector2i(a - 1, yy)) or GridUtils.is_walkable(grid, Vector2i(b + 1, yy)):
			return false
	return true
