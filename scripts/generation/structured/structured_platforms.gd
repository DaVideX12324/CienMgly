extends RefCounted

## Platformy układu structured (ścieki): podwyższona część pomieszczenia pod jego ścianą, z licem i schodami.
## Kształt stąd, schody i osiągalność — PlateauPass.solve_levels (wspólne z jaskiniami), kafle — PlateauPlacer.
## Pas pod ścianą: cała długość między ścianami po bokach (bez drzwi w pasie), głębokość = rzędy góry + krawędź
## (pod ścianą N lico plateau_face_h), przed krawędzią wolna podłoga. Źródła: hale kompleksów, komnaty, większe pokoje.
## Config: structured_layout.platforms {
##   "sides": ["N", "S", "E", "W"] — strony ściany, pod którą może stanąć platforma (N: lico + schody z paczki;
##            S / E / W: rim / bok, schody bez kafli — PlateauPlacer zostawia w krawędzi przejście),
##   "sources": {"hall": 0.6, "chamber": 0.4, "room": 0.3}   — szansa platformy w obszarze danego rodzaju,
##   "min_width": 8, "top_rows": [2, 3], "front": 3, "portal_ring": 3, "room_min_area": 90,
##   "wobble": {"chance": 0.7, "segment": [4, 7], "extra": 2} — krawędź łamana: odcinki różnej głębokości }.
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
## barierki, ściany szer. 1, doły, kraty podłogowe, bramy, dźwignie, portale z pierścieniem.
static func _excluded(ctx: GenerationContext, canals, portal_ring: int) -> Dictionary:
	var ex := {}
	for src in [canals.water, canals.lanes, canals.service, canals.corridors, canals.blocked, canals.bridge_cells,
			canals.bridge_clearance, canals.rail_cells, canals.walls_1w, canals.pit_cells, canals.grating]:
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


## Pasy pod ścianą strony `side` ("N", "S", "E", "W") w obszarze `cells` — każdy jako maska. Bieg kratek z niechodliwą
## kratką po stronie ściany, od ściany do ściany (bez drzwi z boku w rzędach pasa), głębokość top_rows + krawędź
## (N: lico face_h, inaczej 1 rząd rimu / boku), przed krawędzią `front` rzędów suchej podłogi (`wet` = woda).
static func _strips(ctx: GenerationContext, cells: Dictionary, excluded: Dictionary, wet: Dictionary, side: String, face_h: int, rng: RandomNumberGenerator, cfg: Dictionary) -> Array:
	var out: Array = []
	if not SIDE_DIRS.has(side):
		return out
	var d: Vector2i = SIDE_DIRS[side]   # w stronę ściany
	var vertical := d.x != 0            # pas wzdłuż ściany E / W biegnie w osi y
	var grid := ctx.grid
	var min_w := int(cfg.get("min_width", 8))
	var tr: Array = cfg.get("top_rows", [2, 3])
	var edge: int = face_h if side == "N" else 1
	var depth: int = rng.randi_range(int(tr[0]), int(tr[1])) + edge
	var front := int(cfg.get("front", 3))
	var wobble: Dictionary = cfg.get("wobble", {})
	var lines := {}  # linia (y dla N / S, x dla E / W) -> Array[pozycja wzdłuż]
	for p in cells:
		if GridUtils.is_walkable(grid, p) and not GridUtils.is_walkable(grid, p + d):
			var line: int = p.x if vertical else p.y
			if not lines.has(line):
				lines[line] = []
			(lines[line] as Array).append(p.y if vertical else p.x)
	var keys := lines.keys()
	keys.sort()
	for line in keys:
		var ts: Array = lines[line]
		ts.sort()
		var a: int = ts[0]
		for i in range(1, ts.size() + 1):
			if i < ts.size() and int(ts[i]) == int(ts[i - 1]) + 1:
				continue
			var b: int = ts[i - 1]
			if b - a + 1 >= min_w:
				var prof := _profile(a, b, depth, edge, side, tr, wobble, rng)
				if _strip_ok(grid, cells, excluded, wet, d, line, a, b, prof, front):
					var m := {}
					var deepest := 0
					for v in prof:
						deepest = maxi(deepest, v)
					for k in range(deepest):
						for t in range(a, b + 1):
							if k < prof[t - a]:
								m[_at(d, line, t, k)] = true
					out.append(m)
			if i < ts.size():
				a = ts[i]
	return out


const SIDE_DIRS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}


## Kratka pasu: linia `line` przy ścianie (kierunek `d`), pozycja `t` wzdłuż, `k` kratek w głąb pomieszczenia.
static func _at(d: Vector2i, line: int, t: int, k: int) -> Vector2i:
	var base := Vector2i(line, t) if d.x != 0 else Vector2i(t, line)
	return base - d * k


## Głębokość pasa w każdej kolumnie [a..b]. Bez wobble (albo gdy los nie trafi w wobble.chance): stała `depth`.
## Z wobble: odcinki długości wobble.segment (pod ścianą N min. 5 — schody z poręczami na prostym licu), każdy
## o głębokości edge + top_rows[0] .. top_rows[1] + wobble.extra, sąsiednie różne — krawędź platformy łamana.
static func _profile(a: int, b: int, depth: int, edge: int, side: String, tr: Array, wobble: Dictionary, rng: RandomNumberGenerator) -> PackedInt32Array:
	var n := b - a + 1
	var prof := PackedInt32Array()
	prof.resize(n)
	prof.fill(depth)
	if wobble.is_empty() or rng.randf() >= float(wobble.get("chance", 0.0)):
		return prof
	var sg: Array = wobble.get("segment", [4, 7])
	var s_min := maxi(int(sg[0]), 5 if side == "N" else 2)
	var s_max := maxi(int(sg[1]), s_min)
	var lo := edge + int(tr[0])
	var hi := edge + int(tr[1]) + int(wobble.get("extra", 2))
	var lens: Array[int] = []
	var left := n
	while left > 0:
		var l := rng.randi_range(s_min, s_max)
		if left - l < s_min:
			l = left  # reszta krótsza od odcinka — do tego odcinka
		lens.append(l)
		left -= l
	var t := 0
	var prev := -1
	for l in lens:
		var dd := rng.randi_range(lo, hi)
		if dd == prev:
			dd = dd + 1 if dd < hi else dd - 1
		for i in l:
			prof[t + i] = dd
		t += l
		prev = dd
	return prof


static func _strip_ok(grid: Dictionary, cells: Dictionary, excluded: Dictionary, wet: Dictionary, d: Vector2i, line: int, a: int, b: int, prof: PackedInt32Array, front: int) -> bool:
	for t in range(a, b + 1):
		var depth: int = prof[t - a]
		for k in range(depth + front):
			var p := _at(d, line, t, k)
			if not GridUtils.is_walkable(grid, p):
				return false
			# Pas: w obszarze, bez wykluczonych; przed krawędzią wystarczy sucha podłoga (korytarz / chodnik może biec).
			if k < depth and (not cells.has(p) or excluded.has(p)):
				return false
			if k >= depth and wet.has(p):
				return false
	# Od ściany do ściany: na obu końcach pasa ściana w każdym rzędzie (drzwi z boku odpadają).
	for k in range(prof[0]):
		if GridUtils.is_walkable(grid, _at(d, line, a - 1, k)):
			return false
	for k in range(prof[prof.size() - 1]):
		if GridUtils.is_walkable(grid, _at(d, line, b + 1, k)):
			return false
	return true
