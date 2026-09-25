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

const PORTAL_RING := 2
const STAIR_RING := 1
const SPAWN_RING := 1
const REACH_ROUNDS := 8

var f: ObjectFeatures
var plan: ObjectPlan
var seed_value := 0
var blocked := PackedByteArray()   # bariery płaskowyżu (ruch)
var owner := PackedInt32Array()    # indeks defa + 1, który zajął kratkę (USED)
var stamp := PackedInt32Array()    # odstęp `spacing`: indeks defa + 1 w promieniu kotwicy
var reach0 := PackedByteArray()    # osiągalne z wejścia przed obiektami
var entrance_i := -1
var free_pts := {}                 # free: idx kratki -> Array[Vector2] punktów bieżącego defa


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
	var target := 0
	if def.count_min >= 0:
		target = rng.randi_range(def.count_min, def.count_max)
	else:
		# Zaokrąglenie losowe: 0.4 sztuki -> 1 sztuka w 40% map (zwykłe round dawało rzadkim
		# obiektom na małych mapach zawsze 0).
		var want := def.density * cands.size() / 100.0
		target = int(want) + (1 if rng.randf() < want - floorf(want) else 0)
	if target <= 0:
		return
	free_pts.clear()
	var placed := 0
	# Tryb free przy dużej gęstości: kilka przejść po kandydatach (kilka punktów na kratkę).
	var passes := 1
	if def.placement == ObjectDef.Placement.FREE:
		passes = clampi(ceili(float(target) / cands.size()) + 1, 1, 4)
	for _pass in range(passes):
		var k := cands.size()
		while k > 0 and placed < target:
			var j := rng.randi_range(0, k - 1)
			var i := cands[j]
			cands[j] = cands[k - 1]
			cands[k - 1] = i
			k -= 1
			if def.cluster_min > 0:
				placed += _place_cluster(def, marker, i, rng, target - placed)
			elif _try_place(def, marker, i, rng):
				placed += 1
		if placed >= target:
			break


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
	if not _try_place(def, marker, seed_i, rng):
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
		if _try_place(def, marker, i, rng):
			placed += 1
	return placed


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
	var pl := ObjectPlacement.new()
	pl.def = def
	pl.cell = anchor
	pl.cells = cells
	if def.placement == ObjectDef.Placement.GRID_JITTER:
		pl.offset = Vector2(rng.randf_range(-def.jitter_px, def.jitter_px), rng.randf_range(-def.jitter_px, def.jitter_px))
	_finish(pl, marker, rng)
	if def.spacing > 1:
		var s := def.spacing - 1
		for dy in range(-s, s + 1):
			for dx in range(-s, s + 1):
				var q := anchor + Vector2i(dx, dy)
				if f.in_bounds(q):
					stamp[f.idx(q)] = marker
	return true


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
	var reach := ceili(def.spacing_px / cs)
	var sp2 := def.spacing_px * def.spacing_px
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var q := c + Vector2i(dx, dy)
			if not f.in_bounds(q):
				continue
			var pts = free_pts.get(f.idx(q))
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
	else:
		cells.append(i)
	var pl := ObjectPlacement.new()
	pl.def = def
	pl.cell = c
	pl.cells = cells
	pl.offset = pt - def.base_point(c)
	_finish(pl, marker, rng)
	if free_pts.has(i):
		(free_pts[i] as Array).append(pt)
	else:
		free_pts[i] = [pt]
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


# --- 4. Osiągalność ----------------------------------------------------------------------

## Teren osiągalny przed obiektami, a odcięty przez przeszkody -> zdejmij przeszkody stykające się
## (8-sąsiedztwo) z odciętym kawałkiem; powtarzaj do skutku.
func _verify_reach() -> void:
	if entrance_i < 0:
		return
	var w := f.width
	for _round in range(REACH_ROUNDS):
		var parent := _bfs_parents(entrance_i, true)
		var cut := {}
		for i in range(parent.size()):
			if reach0[i] == 1 and parent[i] == -1 and not plan.occupancy[i] & ObjectPlan.SOLID:
				cut[i] = true
		if cut.is_empty():
			return
		var near := {}
		for i in cut:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var j: int = i + dy * w + dx
					if j >= 0 and j < parent.size() and absi(j % w - i % w) <= 1:
						near[j] = true
		var keep: Array[ObjectPlacement] = []
		var removed := 0
		for pl in plan.placements:
			var hit := false
			if pl.def.is_solid():
				for j in pl.cells:
					if near.has(j):
						hit = true
						break
			if hit:
				removed += 1
				for j in pl.cells:
					plan.occupancy[j] &= ~(ObjectPlan.USED | ObjectPlan.SOLID)
			else:
				keep.append(pl)
		if removed == 0:
			return
		plan.removed_for_reach += removed
		plan.placements = keep
		# Zdjęcie mogło odsłonić kratki innych obiektów (dzielone przez free) — odtwórz bity.
		for pl in keep:
			var bits := ObjectPlan.USED | (ObjectPlan.SOLID if pl.def.is_solid() else 0)
			for j in pl.cells:
				plan.occupancy[j] |= bits
