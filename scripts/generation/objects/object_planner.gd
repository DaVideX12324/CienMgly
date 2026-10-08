class_name ObjectPlanner
extends RefCounted

## Rozmieszczanie obiektów z katalogu na gotowej mapie (topologia + płaskowyże). Czyste dane, bez
## węzłów — działa w wątku roboczym. Deterministyczne: każdy obiekt ma własne RNG z hash(seed, id),
## więc dodanie obiektu do katalogu nie przelosowuje pozostałych (poza kratkami, które zajmie).
##
## 1. Zajętość: ściany, bariery płaskowyżu, schody (+1), strefa portali (+2), spawn gracza (+1) -> FORBID.
## 2. Rezerwacja przejść: BFS z wejścia, ścieżki do wyjścia, schodów i pokoi, poszerzone o 1 -> RESERVED
##    (obiekty z kolizją i keep_paths tam nie staną).
## 3. Obiekty w kolejności katalogu (priorytet): kandydaci z list tagów, losowanie bez powtórzeń,
##    test podstawy / odstępów / zajętości, klastry, tryb free z odstępem w px (kubełki = kratki).
## 4. Weryfikacja osiągalności: teren odcięty przez przeszkody -> zdejmij przeszkody przy nim.

const GenProgress = preload("../core/gen_progress.gd")

const PORTAL_RING := 2
const STAIR_RING := 1
const SPAWN_RING := 1
const REACH_ROUNDS := 8
const REACH_NEAR := 2       # przeszkody w tym promieniu (kratki) od odciętego terenu są zdejmowane
# Przejezdność dla wroga (bity na kratkę): środek kratki / odcinek do środka kratki na E / na S za blisko
# kształtu przeszkody (promień agenta siatki nawigacji).
const CLR_CENTER := 1
const CLR_EAST := 2
const CLR_SOUTH := 4
const VISUAL_MARGIN := 3.0  # px: przezroczyste brzegi sprite'a mogą lekko zachodzić na ścianę

var f: ObjectFeatures
var plan: ObjectPlan
var seed_value := 0
var blocked := PackedByteArray()   # bariery płaskowyżu (ruch)
var owner := PackedInt32Array()    # indeks defa + 1, który zajął kratkę (USED)
var stamp := PackedInt32Array()    # odstęp `spacing`: indeks defa + 1 w promieniu kotwicy
var reach0 := PackedByteArray()    # osiągalne z wejścia przed obiektami
var entrance_i := -1
var free_pts := {}                 # free: marker defa -> {kubełek (bok >= spacing_px) -> Array[Vector2] punktów}
var defs_by_id := {}               # id -> ObjectDef (towarzysze)
var markers := {}                  # id -> marker (indeks defa + 1)
var in_companions := false         # towarzysze nie dostawiają własnych towarzyszy


## Plan obiektów dla wyniku generacji. `features` można podać, gdy są już policzone.
static func plan_objects(result, catalog: ObjectCatalog, seed_v: int, features: ObjectFeatures = null) -> ObjectPlan:
	var t0 := Time.get_ticks_usec()
	var p := ObjectPlanner.new()
	p.seed_value = seed_v
	p.f = features if features != null else ObjectFeatures.build(result)
	p._run(result, catalog)
	p.plan.time_usec = Time.get_ticks_usec() - t0
	return p.plan


func _run(result, catalog: ObjectCatalog) -> void:
	plan = ObjectPlan.new()
	plan.width = f.width
	plan.height = f.height
	var n := f.width * f.height
	plan.occupancy.resize(n)
	blocked.resize(n)
	owner.resize(n)
	stamp.resize(n)
	_forbid(result)
	_reserve_paths(result)
	if catalog == null:
		return
	for di in range(catalog.defs.size()):
		if catalog.defs[di].klass == ObjectDef.Klass.INTERACTIVE:
			plan.interactive_scenes[catalog.defs[di].scene] = true
		defs_by_id[catalog.defs[di].id] = catalog.defs[di]
		markers[catalog.defs[di].id] = di + 1
	for di in range(catalog.defs.size()):
		GenProgress.sub_in(&"objects", float(di) / catalog.defs.size())
		_place_def(catalog.defs[di], di + 1)
	_verify_reach()
	for pl in plan.placements:
		plan.stats[pl.def.id] = plan.count(pl.def.id) + 1


# --- 1. Zajętość stała -------------------------------------------------------------------

func _forbid(result) -> void:
	for i in range(plan.occupancy.size()):
		if f.walk[i] == 0:
			plan.occupancy[i] = ObjectPlan.FORBID
	var pl = result.plateau
	if pl != null and not pl.is_empty():
		for c in pl.blocked:
			if f.in_bounds(c):
				blocked[f.idx(c)] = 1
				plan.occupancy[f.idx(c)] |= ObjectPlan.FORBID
		for c in pl.stair_cells():
			_forbid_ring(c, STAIR_RING, false)
	# Kanały: kwas nieprzechodni, kładki przechodnie, ale bez obiektów.
	var canals = result.canals
	if canals != null and not canals.is_empty():
		for c in canals.blocked:
			if f.in_bounds(c):
				blocked[f.idx(c)] = 1
				plan.occupancy[f.idx(c)] |= ObjectPlan.FORBID
		for c in canals.bridge_cells:
			if f.in_bounds(c):
				plan.occupancy[f.idx(c)] |= ObjectPlan.FORBID
		for c in canals.rail_cells:
			if f.in_bounds(c):
				plan.occupancy[f.idx(c)] |= ObjectPlan.FORBID
		# zejścia z kładek (prześwit) — przechodnie, bez obiektów
		for c in canals.bridge_clearance:
			if f.in_bounds(c):
				plan.occupancy[f.idx(c)] |= ObjectPlan.FORBID
	for c in result.portal_zone:
		_forbid_ring(c, PORTAL_RING, true)
	_forbid_ring(result.player_spawn, SPAWN_RING, true)
	_forbid_ring(result.entrance_pos, SPAWN_RING, true)


## FORBID na kratce i wokół niej (`square` = kwadrat Chebysheva, inaczej krzyż 4-sąsiadów).
func _forbid_ring(c: Vector2i, r: int, square: bool) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if not square and absi(dx) + absi(dy) > r:
				continue
			var q := c + Vector2i(dx, dy)
			if f.in_bounds(q):
				plan.occupancy[f.idx(q)] |= ObjectPlan.FORBID


# --- 2. Rezerwacja przejść ---------------------------------------------------------------

func _movable(i: int) -> bool:
	return f.walk[i] == 1 and blocked[i] == 0


## BFS z wejścia (ruch: podłoga bez barier, 4-sąsiedzi) — tablica rodziców, -1 = nieosiągalne.
## `solid_blocks`: obiekty z kolizją też blokują.
func _bfs_parents(start: int, solid_blocks: bool) -> PackedInt32Array:
	var n := f.width * f.height
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	if start < 0 or not _movable(start):
		return parent
	parent[start] = start
	# Ruchome kratki jako jedna tablica bajtów — pętla bez wywołań funkcji i alokacji.
	var ok := PackedByteArray()
	ok.resize(n)
	for i in range(n):
		if f.walk[i] == 1 and blocked[i] == 0 and not (solid_blocks and plan.occupancy[i] & ObjectPlan.SOLID):
			ok[i] = 1
	var queue := PackedInt32Array()
	queue.resize(n)
	queue[0] = start
	var tail := 1
	var head := 0
	var w := f.width
	while head < tail:
		var i := queue[head]
		head += 1
		var x := i % w
		if x < w - 1 and ok[i + 1] == 1 and parent[i + 1] == -1:
			parent[i + 1] = i
			queue[tail] = i + 1
			tail += 1
		if x > 0 and ok[i - 1] == 1 and parent[i - 1] == -1:
			parent[i - 1] = i
			queue[tail] = i - 1
			tail += 1
		if i + w < n and ok[i + w] == 1 and parent[i + w] == -1:
			parent[i + w] = i
			queue[tail] = i + w
			tail += 1
		if i - w >= 0 and ok[i - w] == 1 and parent[i - w] == -1:
			parent[i - w] = i
			queue[tail] = i - w
			tail += 1
	return parent


func _reserve_paths(result) -> void:
	if f.in_bounds(result.entrance_pos):
		entrance_i = f.idx(result.entrance_pos)
	var parent := _bfs_parents(entrance_i, false)
	var n := parent.size()
	reach0.resize(n)
	for i in range(n):
		reach0[i] = 1 if parent[i] != -1 else 0
	if entrance_i < 0 or parent[entrance_i] == -1:
		return

	var targets: Array[Vector2i] = [result.exit_pos]
	var pl = result.plateau
	if pl != null and not pl.is_empty():
		targets.append_array(pl.stair_cells())
	for r in result.rooms:
		targets.append(_room_target(r, parent))
	var path := PackedByteArray()
	path.resize(n)
	for t in targets:
		if not f.in_bounds(t):
			continue
		var i := f.idx(t)
		if parent[i] == -1:
			continue
		while path[i] == 0:
			path[i] = 1
			if i == entrance_i:
				break
			i = parent[i]
	var w := f.width
	for i in range(n):
		if path[i] == 0:
			continue
		for j in [i, i - 1, i + 1, i - w, i + w]:
			if j >= 0 and j < n and absi(j % w - i % w) <= 1 and _movable(j):
				plan.occupancy[j] |= ObjectPlan.RESERVED


## Osiągalna kratka pokoju najbliższa środkowi (środek bywa ścianą albo barierą).
func _room_target(r: Rect2i, parent: PackedInt32Array) -> Vector2i:
	var center := r.get_center()
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for y in range(maxi(r.position.y, 0), mini(r.end.y, f.height)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, f.width)):
			if parent[y * f.width + x] == -1:
				continue
			var d := absi(x - center.x) + absi(y - center.y)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


# --- 3. Rozmieszczanie -------------------------------------------------------------------

func _place_def(def: ObjectDef, marker: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, String(def.id)])
	var cands := _candidates(def)
	if cands.is_empty():
		return
	if def.per_room > 0.0:
		_place_per_room(def, marker, cands, rng)
		return
	var total := cands.size()
	# prefer: najpierw kandydaci z tagami preferowanymi, potem reszta (każda część losowo).
	var pref := PackedInt32Array()
	if not def.prefer.is_empty():
		var rest := PackedInt32Array()
		for i in cands:
			if _preferred(i, def):
				pref.append(i)
			else:
				rest.append(i)
		cands = rest
	var target := 0
	if def.count_min >= 0:
		target = rng.randi_range(def.count_min, def.count_max)
	else:
		# Zaokrąglenie losowe: 0.4 sztuki -> 1 sztuka w 40% map (zwykłe round dawało rzadkim
		# obiektom na małych mapach zawsze 0).
		var want := def.density * total / 100.0
		target = int(want) + (1 if rng.randf() < want - floorf(want) else 0)
	if target <= 0:
		return
	var placed := 0
	if not pref.is_empty():
		placed = _pick(def, marker, pref, rng, target, 0)
	# Tryb free przy dużej gęstości: kilka przejść po kandydatach (kilka punktów na kratkę).
	var passes := 1
	if def.placement == ObjectDef.Placement.FREE:
		passes = clampi(ceili(float(target) / maxi(cands.size(), 1)) + 1, 1, 4)
	for _pass in range(passes):
		if placed >= target:
			break
		placed = _pick(def, marker, cands, rng, target, placed)


## Losowanie bez powtórzeń z `cands` (tasowanie w miejscu) aż do `target` sztuk.
func _pick(def: ObjectDef, marker: int, cands: PackedInt32Array, rng: RandomNumberGenerator, target: int, placed: int) -> int:
	var k := cands.size()
	while k > 0 and placed < target:
		var j := rng.randi_range(0, k - 1)
		var i := cands[j]
		cands[j] = cands[k - 1]
		cands[k - 1] = i
		k -= 1
		if def.cluster_min > 0:
			placed += _place_cluster(def, marker, i, rng, target - placed)
		elif _place_one(def, marker, i, rng):
			placed += 1
	return placed


func _preferred(i: int, def: ObjectDef) -> bool:
	for t in def.prefer:
		if f.has_tag(i, t):
			return true
	return false


## per_room: w każdym pokoju poza portalowymi (losowa kolejność) z szansą per_room jedna sztuka —
## najpierw w kratkach preferowanych, potem w pozostałych kratkach pokoju.
func _place_per_room(def: ObjectDef, marker: int, cands: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	var by_room := {}
	for i in cands:
		var r := f.room[i]
		if r < 0 or f.portal_rooms.has(r):
			continue
		if not by_room.has(r):
			by_room[r] = [PackedInt32Array(), PackedInt32Array()]
		(by_room[r] as Array)[0 if _preferred(i, def) else 1].append(i)
	var rooms: Array = range(f.room_count)
	for k in range(rooms.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = rooms[k]
		rooms[k] = rooms[j]
		rooms[j] = t
	for r in rooms:
		if not by_room.has(r) or rng.randf() >= def.per_room:
			continue
		var parts: Array = by_room[r]
		if _pick(def, marker, parts[0], rng, 1, 0) == 0:
			_pick(def, marker, parts[1], rng, 1, 0)


## Kratki kotwic spełniające reguły i wolne od FORBID (bez duplikatów między tagami).
func _candidates(def: ObjectDef) -> PackedInt32Array:
	var base := f.base_cells(def)
	var out := PackedInt32Array()
	var seen := {}
	var dedup := def.context.size() > 1
	# Jeden tag (albo żaden), bez avoid i poziomów: lista tagu to już dokładnie kandydaci.
	if not dedup and def.avoid.is_empty() and def.levels.is_empty() and def.terrain.is_empty():
		for i in base:
			if not plan.occupancy[i] & ObjectPlan.FORBID:
				out.append(i)
		return out
	for i in base:
		if plan.occupancy[i] & ObjectPlan.FORBID:
			continue
		if dedup:
			if seen.has(i):
				continue
			seen[i] = true
		if f.rules_ok(i, def):
			out.append(i)
	return out


func _place_cluster(def: ObjectDef, marker: int, seed_i: int, rng: RandomNumberGenerator, left: int) -> int:
	if not _place_one(def, marker, seed_i, rng):
		return 0
	var size := mini(rng.randi_range(def.cluster_min, def.cluster_max), left)
	var placed := 1
	var c := f.cell(seed_i)
	var r := def.cluster_radius
	var tries := size * 4
	while placed < size and tries > 0:
		tries -= 1
		var q := c + Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
		if not f.in_bounds(q):
			continue
		var i := f.idx(q)
		if plan.occupancy[i] & ObjectPlan.FORBID or not f.rules_ok(i, def):
			continue
		if _place_one(def, marker, i, rng):
			placed += 1
	return placed


## Jedna sztuka + jej towarzysze (grupa mieszana, np. duży grzyb z małymi wokół).
func _place_one(def: ObjectDef, marker: int, i: int, rng: RandomNumberGenerator) -> bool:
	if not _try_place(def, marker, i, rng):
		return false
	if not def.companions.is_empty() and not in_companions:
		_place_companions(def, f.cell(i), rng)
	return true


## Towarzysze wokół kotwicy `c` (Chebyshev <= radius): każdy wg WŁASNYCH reguł (teren, kontekst,
## zajętość, odstępy), liczba z [min, max]. RNG rodzica — deterministycznie.
func _place_companions(def: ObjectDef, c: Vector2i, rng: RandomNumberGenerator) -> void:
	in_companions = true
	for comp in def.companions:
		var cdef: ObjectDef = defs_by_id.get(comp["id"])
		if cdef == null:
			continue
		var cm: int = markers[comp["id"]]
		var n := rng.randi_range(int(comp["min"]), int(comp["max"]))
		var r := int(comp["radius"])
		var placed := 0
		var tries := n * 5
		while placed < n and tries > 0:
			tries -= 1
			var q := c + Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
			if not f.in_bounds(q):
				continue
			var i := f.idx(q)
			if plan.occupancy[i] & ObjectPlan.FORBID or not f.rules_ok(i, cdef):
				continue
			if _try_place(cdef, cm, i, rng):
				placed += 1
	in_companions = false


func _try_place(def: ObjectDef, marker: int, i: int, rng: RandomNumberGenerator) -> bool:
	if def.placement == ObjectDef.Placement.FREE:
		return _try_free(def, marker, i, rng)
	if def.spacing > 1 and stamp[i] == marker:
		return false
	var anchor := f.cell(i)
	var h := f.height_at(i)
	var cells := PackedInt32Array()
	for fp in def.footprint:
		var q := anchor + fp
		if not f.in_bounds(q):
			return false
		var j := f.idx(q)
		if not _cell_free(def, j) or f.height_at(j) != h:
			return false
		cells.append(j)
	var offset := Vector2.ZERO
	if def.placement == ObjectDef.Placement.GRID_JITTER:
		offset = Vector2(rng.randf_range(-def.jitter_px, def.jitter_px), rng.randf_range(-def.jitter_px, def.jitter_px))
	if _shape_on_reserved(def, def.base_point(anchor) + offset):
		return false
	if _visual_on_wall(def, def.base_point(anchor) + offset):
		return false
	var pl := ObjectPlacement.new()
	pl.def = def
	pl.cell = anchor
	pl.cells = cells
	pl.offset = offset
	_finish(pl, marker, rng)
	if def.spacing > 1:
		var s := def.spacing - 1
		for dy in range(-s, s + 1):
			for dx in range(-s, s + 1):
				var q := anchor + Vector2i(dx, dy)
				if f.in_bounds(q):
					stamp[f.idx(q)] = marker
	return true


## Czy kształt kolizji obiektu w punkcie `pt` zachodzi (choćby częściowo) na zarezerwowane przejście.
## Kratki kształtu liczone są po środkach (≈ pokrycie ≥ połowy), więc skała mogła wystawać na przejście
## i zwężać je poniżej szerokości wroga (siatka nawigacji się tam rwała).
func _shape_on_reserved(def: ObjectDef, pt: Vector2) -> bool:
	if not (def.is_solid() and def.keep_paths):
		return false
	var cs := float(ObjectDef.CELL)
	var ctr := pt + def.shape_offset
	var half := def.shape_rect * 0.5 if def.shape_radius <= 0.0 else Vector2(def.shape_radius, def.shape_radius)
	for y in range(floori((ctr.y - half.y) / cs), floori((ctr.y + half.y - 0.001) / cs) + 1):
		for x in range(floori((ctr.x - half.x) / cs), floori((ctr.x + half.x - 0.001) / cs) + 1):
			var q := Vector2i(x, y)
			if f.in_bounds(q) and plan.occupancy[f.idx(q)] & ObjectPlan.RESERVED:
				return true
	return false


## Czy grafika dużego obiektu (większego niż kratka) w punkcie `pt` zakrywa ścianę albo wystaje poza mapę.
## Przy losowym odbiciu sprawdzane są obie strony.
func _visual_on_wall(def: ObjectDef, pt: Vector2) -> bool:
	if not def.is_large() or def.visual_rect.size == Vector2.ZERO:
		return false
	var r := def.visual_rect
	if def.flip_h:
		r = r.merge(Rect2(Vector2(-r.end.x, r.position.y), r.size))
	r = Rect2(r.position + pt, r.size).grow(-VISUAL_MARGIN)
	var cs := float(ObjectDef.CELL)
	for y in range(floori(r.position.y / cs), floori((r.end.y - 0.001) / cs) + 1):
		for x in range(floori(r.position.x / cs), floori((r.end.x - 0.001) / cs) + 1):
			var q := Vector2i(x, y)
			if not f.in_bounds(q) or f.walk[f.idx(q)] == 0:
				return true
	return false


## Kratka wolna dla obiektu: bez FORBID i innego obiektu; z kolizją — nie na przejściu (keep_paths).
func _cell_free(def: ObjectDef, j: int) -> bool:
	var o := plan.occupancy[j]
	if o & (ObjectPlan.FORBID | ObjectPlan.USED):
		return false
	return not (def.is_solid() and def.keep_paths and o & ObjectPlan.RESERVED)


## Free: punkt losowy w kratce, odstęp `spacing_px` od punktów tego obiektu (kubełki = kratki).
## Bez kolizji: kratka może mieć kilka punktów TEGO obiektu. Z kolizją: blokuje kratki, których
## środek leży w kształcie (≈ pokrycie ≥ połowy), co najmniej kratkę punktu.
func _try_free(def: ObjectDef, marker: int, i: int, rng: RandomNumberGenerator) -> bool:
	var o := plan.occupancy[i]
	if o & ObjectPlan.FORBID:
		return false
	if o & ObjectPlan.USED and (owner[i] != marker or def.is_solid()):
		return false
	var c := f.cell(i)
	var cs := float(ObjectDef.CELL)
	var pt := Vector2((c.x + rng.randf()) * cs, (c.y + rng.randf()) * cs)
	var sp2 := def.spacing_px * def.spacing_px
	# Kubełki o boku >= spacing_px: punkt bliżej niż spacing_px leży w kubełku sąsiednim (3×3), więc
	# 9 odczytów zamiast (2·ceil(spacing/kratka)+1)² kubełków-kratek (przy 112 px — 225) na próbę.
	var bs := maxf(def.spacing_px, cs)
	var bucket := Vector2i(floori(pt.x / bs), floori(pt.y / bs))
	if not free_pts.has(marker):
		free_pts[marker] = {}
	var mine: Dictionary = free_pts[marker]
	if not mine.is_empty():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var pts = mine.get(bucket + Vector2i(dx, dy))
				if pts == null:
					continue
				for other in pts:
					if pt.distance_squared_to(other) < sp2:
						return false
	var cells := PackedInt32Array()
	if def.is_solid():
		cells = _shape_cells(def, pt)
		var h := f.height_at(i)
		for j in cells:
			if j < 0 or not _cell_free(def, j) or f.height_at(j) != h:
				return false
		if _shape_on_reserved(def, pt):
			return false
	else:
		cells.append(i)
	if _visual_on_wall(def, pt):
		return false
	var pl := ObjectPlacement.new()
	pl.def = def
	pl.cell = c
	pl.cells = cells
	pl.offset = pt - def.base_point(c)
	_finish(pl, marker, rng)
	if mine.has(bucket):
		(mine[bucket] as Array).append(pt)
	else:
		mine[bucket] = [pt]
	return true


## Kratki pod kształtem kolizji (środek kratki w kształcie) + kratka punktu. -1 = poza mapą.
func _shape_cells(def: ObjectDef, pt: Vector2) -> PackedInt32Array:
	var cs := float(ObjectDef.CELL)
	var ctr := pt + def.shape_offset
	var half := def.shape_rect * 0.5 if def.shape_radius <= 0.0 else Vector2(def.shape_radius, def.shape_radius)
	var out := PackedInt32Array()
	var pc := Vector2i(floori(pt.x / cs), floori(pt.y / cs))
	out.append(f.idx(pc))
	for y in range(floori((ctr.y - half.y) / cs), floori((ctr.y + half.y) / cs) + 1):
		for x in range(floori((ctr.x - half.x) / cs), floori((ctr.x + half.x) / cs) + 1):
			var q := Vector2i(x, y)
			if q == pc:
				continue
			var mid := (Vector2(q) + Vector2(0.5, 0.5)) * cs
			var inside := false
			if def.shape_radius > 0.0:
				inside = mid.distance_squared_to(ctr) <= def.shape_radius * def.shape_radius
			else:
				inside = absf(mid.x - ctr.x) <= half.x and absf(mid.y - ctr.y) <= half.y
			if inside:
				out.append(f.idx(q) if f.in_bounds(q) else -1)
	return out


func _finish(pl: ObjectPlacement, marker: int, rng: RandomNumberGenerator) -> void:
	var def := pl.def
	if def.variant_count() > 1:
		pl.variant = rng.randi_range(0, def.variant_count() - 1)
	pl.flip = def.flip_h and rng.randf() < 0.5
	var bits := ObjectPlan.USED | (ObjectPlan.SOLID if def.is_solid() else 0)
	for j in pl.cells:
		plan.occupancy[j] |= bits
		owner[j] = marker
	plan.placements.append(pl)
	if def.klass == ObjectDef.Klass.INTERACTIVE:
		_reserve_access(pl)


## Dojście do obiektu interaktywnego (skrzynia — często w niszy z jednym wejściem): najkrótsza droga
## (BFS od wolnych sąsiadów, bez barier i przeszkód z kolizją) do sieci przejść (RESERVED) albo wejścia,
## poszerzona o 1 -> RESERVED na kratkach niezajętych przez obiekty. Przeszkody z kolizją nie zachodzą na
## RESERVED nawet częściowo (_shape_on_reserved), więc nie zasłonią skrzyni (sama zajętość środkami kratek
## przepuszczała kamień w połowie wejścia do niszy). Obstawioną skrzynię i tak łapie _verify_reach.
func _reserve_access(pl: ObjectPlacement) -> void:
	if reach0.is_empty():
		return
	var w := f.width
	var n := reach0.size()
	var walkable := func(k: int) -> bool:
		return _movable(k) and reach0[k] == 1 and not plan.occupancy[k] & (ObjectPlan.USED | ObjectPlan.SOLID)
	var prev := {}
	var queue: Array[int] = []
	for j in pl.cells:
		for k in [j - 1, j + 1, j - w, j + w]:
			if k >= 0 and k < n and absi(k % w - j % w) <= 1 and not prev.has(k) and walkable.call(k):
				prev[k] = -1
				queue.append(k)
	var goal := -1
	var qi := 0
	while qi < queue.size():
		var i: int = queue[qi]
		qi += 1
		if plan.occupancy[i] & ObjectPlan.RESERVED or i == entrance_i:
			goal = i
			break
		for k in [i - 1, i + 1, i - w, i + w]:
			if k >= 0 and k < n and absi(k % w - i % w) <= 1 and not prev.has(k) and walkable.call(k):
				prev[k] = i
				queue.append(k)
	var i := goal
	while i >= 0:
		for j in [i, i - 1, i + 1, i - w, i + w]:
			if j >= 0 and j < n and absi(j % w - i % w) <= 1 and _movable(j) and not plan.occupancy[j] & ObjectPlan.USED:
				plan.occupancy[j] |= ObjectPlan.RESERVED
		i = prev[i]


# --- 4. Osiągalność ----------------------------------------------------------------------

## Teren osiągalny przed obiektami, a odcięty przez przeszkody -> zdejmij przeszkody w promieniu
## REACH_NEAR od odciętego kawałka. Osiągalność jak dla wroga (_bfs_agent): po środkach kratek, z odstępem
## promienia agenta od dokładnych kształtów przeszkód (te same obrysy co siatka nawigacji) — sama zajętość
## kratek przepuszczała szczeliny, w których siatka nawigacji się rwała (500×500: ~1/3 par bez ścieżki).
## Obiekt INTERACTIVE (skrzynia) bez osiągalnego sąsiada (obstawiony przeszkodami) -> zdejmij przeszkody
## wokół niego, a gdy się nie da — jego samego. Powtarzaj do skutku.
func _verify_reach() -> void:
	if entrance_i < 0:
		return
	var w := f.width
	var n := f.width * f.height
	for _round in range(REACH_ROUNDS):
		var clr := _clearance()
		var parent := _bfs_agent(entrance_i, clr)
		var cut := {}
		for i in range(parent.size()):
			# Kratki, na których środku wróg się nie mieści (obrzeże przeszkody), nie liczą się jako odcięte.
			if reach0[i] == 1 and parent[i] == -1 and not plan.occupancy[i] & ObjectPlan.SOLID and clr[i] & CLR_CENTER == 0:
				cut[i] = true
		var boxed := {}
		for pl in plan.placements:
			if pl.def.klass != ObjectDef.Klass.INTERACTIVE:
				continue
			var ok := false
			for j in pl.cells:
				for k in [j - 1, j + 1, j - w, j + w]:
					if k >= 0 and k < n and absi(k % w - j % w) <= 1 and parent[k] != -1 and not plan.occupancy[k] & ObjectPlan.SOLID:
						ok = true
			if not ok:
				boxed[pl] = true
		if cut.is_empty() and boxed.is_empty():
			return
		var near := {}
		var src: Array = cut.keys()
		for pl in boxed:
			src.append_array(Array(pl.cells))
		for i in src:
			for dy in range(-REACH_NEAR, REACH_NEAR + 1):
				for dx in range(-REACH_NEAR, REACH_NEAR + 1):
					var j: int = i + dy * w + dx
					if j >= 0 and j < n and absi(j % w - i % w) <= REACH_NEAR:
						near[j] = true
		var keep: Array[ObjectPlacement] = []
		var removed := 0
		for pl in plan.placements:
			var hit := false
			if pl.def.is_solid() and not boxed.has(pl):
				for j in pl.cells:
					if near.has(j):
						hit = true
						break
			if hit:
				removed += 1
			else:
				keep.append(pl)
		if removed == 0:
			if boxed.is_empty():
				return
			# Nic wokół nie da się zdjąć — zdejmij obstawione obiekty interaktywne.
			keep = []
			for pl in plan.placements:
				if boxed.has(pl):
					removed += 1
				else:
					keep.append(pl)
		plan.removed_for_reach += removed
		plan.placements = keep
		# Odtwórz bity zajętości z pozostałych obiektów (zdjęte kratki bywają dzielone przez free).
		for i in range(n):
			plan.occupancy[i] &= ~(ObjectPlan.USED | ObjectPlan.SOLID)
		for pl in keep:
			var bits := ObjectPlan.USED | (ObjectPlan.SOLID if pl.def.is_solid() else 0)
			for j in pl.cells:
				plan.occupancy[j] |= bits


## Przejezdność dla wroga przy obecnych przeszkodach (bity CLR_* na kratkę). Próbki: środek kratki oraz
## 3 punkty co 4 px na odcinku do środka kratki na E i na S — zajęte, gdy leżą w obrysie przeszkody albo
## bliżej niż promień agenta. Ściany i bariery nie zwężają ruchu po środkach kratek (8 px > promień).
func _clearance() -> PackedByteArray:
	var w := f.width
	var h := f.height
	var out := PackedByteArray()
	out.resize(w * h)
	var r := NavOutlines.AGENT_RADIUS
	var cs := float(ObjectDef.CELL)
	var east := [Vector2(4, 0), Vector2(8, 0), Vector2(12, 0)]
	var south := [Vector2(0, 4), Vector2(0, 8), Vector2(0, 12)]
	for pl in plan.placements:
		if not pl.def.is_solid():
			continue
		for poly in NavOutlines.placement_outlines(pl, plan):
			var box := NavOutlines._bounds(poly).grow(r)
			var x0 := maxi(floori(box.position.x / cs) - 1, 0)
			var y0 := maxi(floori(box.position.y / cs) - 1, 0)
			var x1 := mini(floori(box.end.x / cs), w - 1)
			var y1 := mini(floori(box.end.y / cs), h - 1)
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					var i := y * w + x
					if f.walk[i] == 0:
						continue
					var c := Vector2((x + 0.5) * cs, (y + 0.5) * cs)
					var bits := int(out[i])
					if bits & CLR_CENTER == 0 and _near_poly(poly, box, c, r):
						bits |= CLR_CENTER
					if bits & CLR_EAST == 0:
						for o in east:
							if _near_poly(poly, box, c + o, r):
								bits |= CLR_EAST
								break
					if bits & CLR_SOUTH == 0:
						for o in south:
							if _near_poly(poly, box, c + o, r):
								bits |= CLR_SOUTH
								break
					out[i] = bits
	return out


## Punkt w wielokącie albo bliżej niż r od jego krawędzi (box = obrys poszerzony o r — szybkie odrzucenie).
static func _near_poly(poly: PackedVector2Array, box: Rect2, p: Vector2, r: float) -> bool:
	if not box.has_point(p):
		return false
	if Geometry2D.is_point_in_polygon(p, poly):
		return true
	var r2 := r * r
	for k in range(poly.size()):
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < r2:
			return true
	return false


## BFS z wejścia jak dla wroga: kratka chodliwa bez bariery i przeszkody, środek wolny (CLR_CENTER),
## przejście do sąsiada tylko po wolnym odcinku (CLR_EAST / CLR_SOUTH kratki z lewej / z góry).
func _bfs_agent(start: int, clr: PackedByteArray) -> PackedInt32Array:
	var n := f.width * f.height
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	if start < 0 or not _movable(start):
		return parent
	var ok := PackedByteArray()
	ok.resize(n)
	for i in range(n):
		if f.walk[i] == 1 and blocked[i] == 0 and not plan.occupancy[i] & ObjectPlan.SOLID and clr[i] & CLR_CENTER == 0:
			ok[i] = 1
	ok[start] = 1  # strefa wejścia jest wolna od przeszkód (FORBID), start zawsze
	parent[start] = start
	var queue := PackedInt32Array()
	queue.resize(n)
	queue[0] = start
	var tail := 1
	var head := 0
	var w := f.width
	while head < tail:
		var i := queue[head]
		head += 1
		var x := i % w
		if x < w - 1 and ok[i + 1] == 1 and parent[i + 1] == -1 and clr[i] & CLR_EAST == 0:
			parent[i + 1] = i
			queue[tail] = i + 1
			tail += 1
		if x > 0 and ok[i - 1] == 1 and parent[i - 1] == -1 and clr[i - 1] & CLR_EAST == 0:
			parent[i - 1] = i
			queue[tail] = i - 1
			tail += 1
		if i + w < n and ok[i + w] == 1 and parent[i + w] == -1 and clr[i] & CLR_SOUTH == 0:
			parent[i + w] = i
			queue[tail] = i + w
			tail += 1
		if i - w >= 0 and ok[i - w] == 1 and parent[i - w] == -1 and clr[i - w] & CLR_SOUTH == 0:
			parent[i - w] = i
			queue[tail] = i - w
			tail += 1
	return parent
