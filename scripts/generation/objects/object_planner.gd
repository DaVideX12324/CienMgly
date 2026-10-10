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
const GatePlannerScript = preload("gate_planner.gd")

const PORTAL_RING := 2
const STAIR_RING := 1
const SPAWN_RING := 1
const REACH_ROUNDS := 24
const REACH_NEAR := 2       # przeszkoda zdejmowana dla odciętego terenu leży najwyżej tyle kratek od niego
const REACH_MASS_ROUNDS := 4  # ostatnie rundy naprawy: wszystkie przeszkody w REACH_NEAR (zapas przy wielu kawałkach)
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
var pl_wall := PackedByteArray()   # 1: bariery płaskowyżu (lico, rimy) — rysunek dużego obiektu ich nie zasłania, jak ściany;
                                   # 2: schody z obwódką — rysunek nigdy (także przy licu, facade_ok)
var owner := PackedInt32Array()    # indeks defa + 1, który zajął kratkę (USED)
var stamp := PackedInt32Array()    # odstęp `spacing`: indeks defa + 1 w promieniu kotwicy
var reach0 := PackedByteArray()    # osiągalne z wejścia przed obiektami
var entrance_i := -1
var free_pts := {}                 # free: marker defa -> {kubełek (bok >= spacing_px) -> Array[Vector2] punktów}
var defs_by_id := {}               # id -> ObjectDef (towarzysze)
var markers := {}                  # id -> marker (indeks defa + 1)
var in_companions := false         # towarzysze nie dostawiają własnych towarzyszy
var area_kind := {}                # idx kratki -> rodzaj obszaru ("room" / "hall" / "corridor") z canals.areas
var area_weights := {}             # katalog: szansa kratki dla dużych obiektów wg rodzaju obszaru
var set_gap := 0                   # katalog: odstęp dużych obiektów różnych zestawów
var set_of := PackedInt32Array()   # idx kratki -> zestaw dużego obiektu (indeks w set_ids + 1), 0 = brak
var set_ids := {}                  # zestaw -> indeks
var parent_center := Vector2(-1, -1)  # środek rodzica (kratki) przy stawianiu towarzyszy — facing_pref "parent"
var canal_dist := PackedInt32Array()  # idx -> odległość (Chebyshev) od wody kanału; liczona, gdy jakiś obiekt ma canal_gap
var room_groups := {}               # room_group -> {indeks pokoju: true} — zajęte przez obiekt tej grupy
var vignettes_by_id := {}            # id winiety -> słownik z katalogu (wzory skupisk, cluster.patterns)
var gate_canals = null                # canals z bramami GatePlanner (kontrola osiągalności B)
var gate_gi := PackedInt32Array()     # brama (z otwieraczem) -> indeks w canals.gates
var gate_idx: Array[PackedInt32Array] = []  # brama -> kratki kolców
var gate_sets: Array = []             # brama -> Array[PackedInt32Array]: zestawy kratek, z których każdy ją otwiera


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
	pl_wall.resize(n)
	owner.resize(n)
	stamp.resize(n)
	set_of.resize(n)
	_forbid(result)
	_reserve_paths(result)
	_collect_gates(result)
	if catalog == null:
		return
	area_weights = catalog.area_weights
	set_gap = catalog.set_gap
	var max_gap := 0
	for d in catalog.defs:
		max_gap = maxi(max_gap, d.canal_gap)
	if max_gap > 0 and result.canals != null and not result.canals.is_empty():
		_canal_distance(result.canals, max_gap + 1)
	if result.canals != null and "areas" in result.canals:
		for c: Vector2i in result.canals.areas:
			if f.in_bounds(c):
				var a := String(result.canals.areas[c])
				area_kind[f.idx(c)] = StringName(a.get_slice(":", 0))
		if "chambers" in result.canals:
			for comp in result.canals.chambers:
				for c: Vector2i in comp:
					if f.in_bounds(c):
						area_kind[f.idx(c)] = &"chamber"
	for di in range(catalog.defs.size()):
		if catalog.defs[di].klass == ObjectDef.Klass.INTERACTIVE:
			plan.interactive_scenes[catalog.defs[di].scene] = true
		defs_by_id[catalog.defs[di].id] = catalog.defs[di]
		markers[catalog.defs[di].id] = di + 1
	for v in catalog.vignettes:
		vignettes_by_id[StringName(String(v.get("id", "")))] = v
	_place_vignettes(catalog.vignettes)
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
		# Lico na kratkach maski (ścieki, face_down 0): rysunek dużych obiektów nie wchodzi na lico. Jaskinie (2H ze
		# stopą) bez zmian — parytet obiektów i spawnów.
		var as_wall: bool = pl.face_down == 0
		for c in pl.blocked:
			if f.in_bounds(c):
				blocked[f.idx(c)] = 1
				if as_wall:
					pl_wall[f.idx(c)] = 1
				plan.occupancy[f.idx(c)] |= ObjectPlan.FORBID
		for c in pl.stair_cells():
			_forbid_ring(c, STAIR_RING, false)
			if as_wall:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var q: Vector2i = c + Vector2i(dx, dy)
						if f.in_bounds(q):
							pl_wall[f.idx(q)] = 2
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
		for c in canals.stair_cells:  # korytarze-schody — przechodnie, bez obiektów
			if f.in_bounds(c):
				plan.occupancy[f.idx(c)] |= ObjectPlan.FORBID
		# zejścia z kładek (prześwit) — przechodnie, bez obiektów
		for c in canals.bridge_clearance:
			if f.in_bounds(c):
				plan.occupancy[f.idx(c)] |= ObjectPlan.FORBID
		# kratownice w posadzce — bez drobnicy
		if "grating" in canals:
			for c in canals.grating:
				if f.in_bounds(c):
					plan.occupancy[f.idx(c)] |= ObjectPlan.NO_DECAL
	# zagadki bram: bariery, klucze, dojścia do zamków
	for c in GatePlannerScript.reserved_cells(canals):
		_forbid_ring(c, 1, true)
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
	if def.span_floor:
		return  # ozdoba posadzki w osi przęseł — stawia WallDecorPlanner
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, String(def.id)])
	var cands := _candidates(def)
	if cands.is_empty():
		return
	if def.per_room > 0.0 or def.per_chamber > 0.0:
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
		_place_room_extra(def, marker, rng)
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
	_place_room_extra(def, marker, rng)


## Dodatkowe sztuki w pokojach (poza portalowymi) i komnatach za ścianami działowymi: room_density na 100
## kandydatów w nich — pomieszczenia zastawione gęściej niż korytarze i promenady.
func _place_room_extra(def: ObjectDef, marker: int, rng: RandomNumberGenerator) -> void:
	if def.room_density <= 0.0:
		return
	var cands := PackedInt32Array()
	for i in _candidates(def):
		if f.room[i] >= 0 and not f.portal_rooms.has(f.room[i]):
			cands.append(i)
	var want := def.room_density * cands.size() / 100.0
	var extra := int(want) + (1 if rng.randf() < want - floorf(want) else 0)
	if extra > 0:
		_pick(def, marker, cands, rng, extra, 0)


## Losowanie bez powtórzeń z `cands` (tasowanie w miejscu) aż do `target` sztuk.
func _pick(def: ObjectDef, marker: int, cands: PackedInt32Array, rng: RandomNumberGenerator, target: int, placed: int) -> int:
	var k := cands.size()
	while k > 0 and placed < target:
		var j := rng.randi_range(0, k - 1)
		var i := cands[j]
		cands[j] = cands[k - 1]
		cands[k - 1] = i
		k -= 1
		if not area_weights.is_empty() and def.is_big() and rng.randf() >= float(area_weights.get(area_kind.get(i, &""), 1.0)):
			continue
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
	var used: Dictionary = room_groups.get(def.room_group, {})
	for r in rooms:
		var chance := def.per_room if r < f.chamber_first else def.per_chamber
		if not by_room.has(r) or chance <= 0.0 or rng.randf() >= chance:
			continue
		if def.room_group != &"" and used.has(r):
			continue   # pomieszczenie ma już obiekt tej grupy (np. inny stół)
		var parts: Array = by_room[r]
		var got := _pick(def, marker, parts[0], rng, 1, 0)
		if got == 0:
			got = _pick(def, marker, parts[1], rng, 1, 0)
		if got > 0 and def.room_group != &"":
			used[r] = true
	if def.room_group != &"":
		room_groups[def.room_group] = used


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
	var pat := _place_pattern(def, seed_i, rng)
	if pat > 0:
		return pat
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


## Skupisko w kształcie winiety (cluster.patterns): z szansą pattern_chance winiety w losowej kolejności, kotwica
## w kratce zarodka albo najbliższej w promieniu skupiska + 1 z tagami części 0, losowe odbicie (flip_h winiety) —
## pierwsza pasująca. Zwraca liczbę postawionych części (0 = brak).
func _place_pattern(def: ObjectDef, seed_i: int, rng: RandomNumberGenerator) -> int:
	if def.cluster_patterns.is_empty() or rng.randf() >= def.cluster_pattern_chance:
		return 0
	var order: Array[StringName] = def.cluster_patterns.duplicate()
	for k in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t := order[k]
		order[k] = order[j]
		order[j] = t
	for pid in order:
		var v: Dictionary = vignettes_by_id.get(pid, {})
		if v.is_empty():
			continue
		var parts := _vignette_parts(v)
		if parts.is_empty():
			continue
		var can_flip := bool(v.get("flip_h", false))
		var tags0: Array[StringName] = parts[0].tags
		# kotwice: zarodek, potem kratki w promieniu cluster_radius + 1 z tagami części 0 (najbliższe pierwsze)
		var anchors: Array[Vector2i] = [f.cell(seed_i)]
		var r := def.cluster_radius + 1
		for dist in range(1, r + 1):
			for dy in range(-dist, dist + 1):
				for dx in range(-dist, dist + 1):
					if maxi(absi(dx), absi(dy)) != dist:
						continue
					var q := f.cell(seed_i) + Vector2i(dx, dy)
					if not f.in_bounds(q) or plan.occupancy[f.idx(q)] & ObjectPlan.FORBID:
						continue
					var ok := true
					for t in tags0:
						if not (f.has_tag(f.idx(q), t) or (can_flip and t == &"wall_w" and f.has_tag(f.idx(q), &"wall_e")) 								or (can_flip and t == &"wall_e" and f.has_tag(f.idx(q), &"wall_w"))):
							ok = false
							break
					if ok:
						anchors.append(q)
		for a in anchors:
			var first := can_flip and rng.randf() < 0.5
			if _try_vignette(v, parts, a, first, rng) or (can_flip and _try_vignette(v, parts, a, not first, rng)):
				plan.stats[StringName("vignette:" + String(pid))] = int(plan.stats.get(StringName("vignette:" + String(pid)), 0)) + 1
				return parts.size()
	return 0


## Jedna sztuka + jej towarzysze (grupa mieszana, np. duży grzyb z małymi wokół).
func _place_one(def: ObjectDef, marker: int, i: int, rng: RandomNumberGenerator) -> bool:
	if not _try_place(def, marker, i, rng):
		return false
	if not def.companions.is_empty() and not in_companions:
		_place_companions(def, f.cell(i), rng)
	return true


## Towarzysze wokół kotwicy `c` (Chebyshev <= radius): każdy wg WŁASNYCH reguł (teren, kontekst,
## zajętość, odstępy), liczba z [min, max]. RNG rodzica — deterministycznie. Z "on" (szansa): sztuka najpierw
## próbuje leżeć NA rodzicu — w kratkach jego rysunku nad podstawą (blat stołu), inaczej obok. Z "no_corners"
## sztuka obok nie staje po skosie od rodzica (poza jego obrysem w obu osiach) — tylko przy bokach.
func _place_companions(def: ObjectDef, c: Vector2i, rng: RandomNumberGenerator) -> void:
	in_companions = true
	# środek rysunku rodzica (kotwica = lewy-dolny róg)
	parent_center = Vector2(c) + Vector2((maxi(def.size.x, 1) - 1) * 0.5, -(maxi(def.size.y, 1) - 1) * 0.5)
	for comp in def.companions:
		var cdef: ObjectDef = defs_by_id.get(comp["id"])
		if cdef == null:
			continue
		var cm: int = markers[comp["id"]]
		var n := rng.randi_range(int(comp["min"]), int(comp["max"]))
		var r := int(comp["radius"])
		var placed := 0
		var on := float(comp.get("on", 0.0))
		if on > 0.0:
			var top := _surface_cells(def, c)
			for _k in range(n):
				if top.is_empty() or rng.randf() >= on:
					continue
				var t := rng.randi_range(0, top.size() - 1)
				var tc: Vector2i = top[t]
				top.remove_at(t)
				if _try_place(cdef, cm, f.idx(tc), rng, true):
					placed += 1
		var tries := n * 5
		while placed < n and tries > 0:
			tries -= 1
			var q := c + Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
			if not f.in_bounds(q):
				continue
			if comp.get("no_corners", false) and _corner_of(def, c, q):
				continue
			var i := f.idx(q)
			if plan.occupancy[i] & ObjectPlan.FORBID or not f.rules_ok(i, cdef):
				continue
			if _try_place(cdef, cm, i, rng):
				placed += 1
	in_companions = false
	parent_center = Vector2(-1, -1)


## Kratka `q` po skosie od podstawy obiektu (footprint względem kotwicy `anchor`): poza nią w obu osiach — np.
## obok tylnej części blatu stołu to już narożnik.
static func _corner_of(def: ObjectDef, anchor: Vector2i, q: Vector2i) -> bool:
	var x0 := anchor.x
	var x1 := anchor.x
	var y0 := anchor.y
	var y1 := anchor.y
	for fp in def.footprint:
		x0 = mini(x0, anchor.x + fp.x)
		x1 = maxi(x1, anchor.x + fp.x)
		y0 = mini(y0, anchor.y + fp.y)
		y1 = maxi(y1, anchor.y + fp.y)
	return (q.x < x0 or q.x > x1) and (q.y < y0 or q.y > y1)


## Kratki rysunku obiektu nad jego podstawą (blat), w granicach mapy, na podłodze.
func _surface_cells(def: ObjectDef, anchor: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(1, def.size.y):
		for dx in range(def.size.x):
			var q := anchor + Vector2i(dx, -dy)
			if f.in_bounds(q) and not def.footprint.has(Vector2i(dx, -dy)) and f.walk[f.idx(q)] != 0:
				out.append(q)
	return out


func _try_place(def: ObjectDef, marker: int, i: int, rng: RandomNumberGenerator, on_top := false) -> bool:
	if def.placement == ObjectDef.Placement.FREE:
		return _try_free(def, marker, i, rng)
	if def.spacing > 1 and stamp[i] == marker:
		return false
	var anchor := f.cell(i)
	var cells := _fit_cells(def, anchor)
	if cells.is_empty():
		return false
	var offset := Vector2.ZERO
	if def.placement == ObjectDef.Placement.GRID_JITTER:
		offset = Vector2(rng.randf_range(-def.jitter_px, def.jitter_px), rng.randf_range(-def.jitter_px, def.jitter_px))
	if not _fit_rest(def, anchor, cells, offset):
		return false
	_commit(def, marker, anchor, cells, offset, on_top, rng)
	return true


## Kratki podstawy obiektu w `anchor` — wolne, na jednej wysokości; puste = nie mieści się.
func _fit_cells(def: ObjectDef, anchor: Vector2i) -> PackedInt32Array:
	if not f.in_bounds(anchor):
		return PackedInt32Array()
	var h := f.height_at(f.idx(anchor))
	var cells := PackedInt32Array()
	for fp in def.footprint:
		var q := anchor + fp
		if not f.in_bounds(q):
			return PackedInt32Array()
		var j := f.idx(q)
		if not _cell_free(def, j) or f.height_at(j) != h:
			return PackedInt32Array()
		cells.append(j)
	return cells


## Reszta reguł miejsca: kształt nie na przejściach, rysunek nie w ścianie (`facade_ok`: wolno przed licem), zestawy,
## odstęp od wody.
func _fit_rest(def: ObjectDef, anchor: Vector2i, cells: PackedInt32Array, offset: Vector2, facade_ok := false) -> bool:
	if _shape_on_reserved(def, def.base_point(anchor) + offset):
		return false
	if _visual_on_wall(def, def.base_point(anchor) + offset, facade_ok):
		return false
	if not _set_ok(def, cells):
		return false
	return _canal_ok(def, anchor)


## Postawienie obiektu (po _fit_cells / _fit_rest). `variant` / `flip` >= 0 wymuszają wariant i odbicie (winiety).
func _commit(def: ObjectDef, marker: int, anchor: Vector2i, cells: PackedInt32Array, offset: Vector2, on_top: bool,
		rng: RandomNumberGenerator, variant := -1, flip := -1) -> ObjectPlacement:
	var pl := ObjectPlacement.new()
	pl.def = def
	pl.cell = anchor
	pl.cells = cells
	pl.offset = offset
	pl.on_top = on_top
	_finish(pl, marker, rng)
	if variant >= 0:
		pl.variant = clampi(variant, 0, maxi(def.variant_count() - 1, 0))
	if flip >= 0:
		pl.flip = flip == 1
	_mark_set(def, cells)
	if def.spacing > 1:
		var s := def.spacing - 1
		for dy in range(-s, s + 1):
			for dx in range(-s, s + 1):
				var q := anchor + Vector2i(dx, dy)
				if f.in_bounds(q):
					stamp[f.idx(q)] = marker
	return pl


# --- 3a. Winiety --------------------------------------------------------------------------

## Winiety z katalogu (ObjectCatalog.vignettes) — przed pojedynczymi obiektami. Kotwice: kratki z tagami części 0.
## Cała winieta albo nic: każda część przechodzi te same reguły co pojedynczy obiekt (_fit_cells / _fit_rest) i swoje
## tagi, części się nie nakładają, kratki "clear" są wolne (potem RESERVED — dojście). per_room / per_chamber: jedna
## z szansą w każdym pokoju / komnacie (poza portalowymi); density: sztuki na 100 kotwic w halach (nie w korytarzach).
## Żadna część na przejściach (RESERVED) — winieta nie zatyka drogi i naprawa osiągalności jej nie rozbiera. "flip_h":
## losowo odbita w poziomie (przesunięcia x, tagi wall_e <-> wall_w, odbicie części).
func _place_vignettes(list: Array) -> void:
	for v: Dictionary in list:
		var vid := String(v.get("id", "winieta"))
		var parts := _vignette_parts(v)
		if parts.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "vignette", vid])
		var by_room := {}
		var outside := PackedInt32Array()
		for i in _vignette_anchors(parts[0].tags):
			var r := f.room[i]
			if r < 0:
				if area_kind.get(i, &"hall") == &"hall":   # poza pokojami tylko hale — nie zwężać korytarzy
					outside.append(i)
			elif not f.portal_rooms.has(r):
				var lst: PackedInt32Array = by_room.get(r, PackedInt32Array())
				lst.append(i)
				by_room[r] = lst   # PackedInt32Array to wartość — zapis z powrotem
		var made := 0
		var rooms: Array = by_room.keys()
		rooms.sort()
		for k in range(rooms.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t = rooms[k]
			rooms[k] = rooms[j]
			rooms[j] = t
		for r in rooms:
			var chance := float(v.get("per_room", 0.0)) if int(r) < f.chamber_first else float(v.get("per_chamber", 0.0))
			if chance > 0.0 and rng.randf() < chance:
				made += _vignette_pick(v, parts, by_room[r], rng, 1)
		var want := float(v.get("density", 0.0)) * outside.size() / 100.0
		var n := int(want) + (1 if rng.randf() < want - floorf(want) else 0)
		if n > 0:
			made += _vignette_pick(v, parts, outside, rng, n)
		if made > 0:
			plan.stats[StringName("vignette:" + vid)] = made


## Części winiety: [{def, marker, at, variant, flip, tags}]; pusto, gdy któraś wskazuje nieznany obiekt.
func _vignette_parts(v: Dictionary) -> Array:
	var out: Array = []
	for part in v.get("parts", []):
		var def: ObjectDef = defs_by_id.get(StringName(String(part.get("id", ""))))
		if def == null or def.placement == ObjectDef.Placement.FREE:
			return []
		var at: Array = part.get("at", [0, 0])
		var tags: Array[StringName] = []
		for t in part.get("tags", []):
			tags.append(StringName(t))
		out.append({
			"def": def, "marker": int(markers.get(def.id, 0)), "at": Vector2i(int(at[0]), int(at[1])),
			"variant": int(part.get("variant", -1)), "flip": (1 if bool(part["flip"]) else 0) if part.has("flip") else -1,
			"tags": tags,
		})
	return out


## Kandydaci na kotwicę: kratki pierwszego tagu części 0 (bez tagów — cała podłoga), bez FORBID.
func _vignette_anchors(tags: Array[StringName]) -> PackedInt32Array:
	var out := PackedInt32Array()
	var src: PackedInt32Array
	if not tags.is_empty() and f.tag_cells.has(tags[0]):
		src = f.tag_cells[tags[0]]
	else:
		for i in range(f.walk.size()):
			if f.walk[i] == 1:
				src.append(i)
	for i in src:
		if not plan.occupancy[i] & ObjectPlan.FORBID:
			out.append(i)
	return out


## Losowanie bez powtórzeń z `cands` aż do `target` winiet; każda kotwica w losowym odbiciu (flip_h), potem drugim.
func _vignette_pick(v: Dictionary, parts: Array, cands: PackedInt32Array, rng: RandomNumberGenerator, target: int) -> int:
	var k := cands.size()
	var placed := 0
	var can_flip := bool(v.get("flip_h", false))
	while k > 0 and placed < target:
		var j := rng.randi_range(0, k - 1)
		var i := cands[j]
		cands[j] = cands[k - 1]
		cands[k - 1] = i
		k -= 1
		var first := can_flip and rng.randf() < 0.5
		if _try_vignette(v, parts, f.cell(i), first, rng) or (can_flip and _try_vignette(v, parts, f.cell(i), not first, rng)):
			placed += 1
	return placed


func _try_vignette(v: Dictionary, parts: Array, anchor: Vector2i, mirrored: bool, rng: RandomNumberGenerator) -> bool:
	var fits: Array = []
	var taken := {}
	for p in parts:
		var def: ObjectDef = p.def
		var at: Vector2i = p.at
		if mirrored:
			at.x = -at.x - (maxi(def.size.x, 1) - 1)
		var a := anchor + at
		if not f.in_bounds(a):
			return false
		for t: StringName in p.tags:
			var tt := t
			if mirrored and t == &"wall_e":
				tt = &"wall_w"
			elif mirrored and t == &"wall_w":
				tt = &"wall_e"
			if not f.has_tag(f.idx(a), tt):
				return false
		var cells := _fit_cells(def, a)
		if cells.is_empty() or not _fit_rest(def, a, cells, Vector2.ZERO, true):
			return false
		for j in cells:
			if taken.has(j) or plan.occupancy[j] & ObjectPlan.RESERVED:   # nie na przejściach (jak keep_paths)
				return false
			taken[j] = true
		fits.append([p, a, cells])
	var clear := PackedInt32Array()
	for c in v.get("clear", []):
		var q := anchor + Vector2i(-int(c[0]) if mirrored else int(c[0]), int(c[1]))
		if not f.in_bounds(q):
			return false
		var j := f.idx(q)
		if not _movable(j) or taken.has(j) or plan.occupancy[j] & (ObjectPlan.USED | ObjectPlan.SOLID | ObjectPlan.FORBID):
			return false
		clear.append(j)
	for fit in fits:
		var p: Dictionary = fit[0]
		var fl: int = p.flip
		if mirrored:
			fl = 1 - (fl if fl >= 0 else 0)
		_commit(p.def, p.marker, fit[1], fit[2], Vector2.ZERO, false, rng, p.variant, fl)
	for j in clear:
		plan.occupancy[j] |= ObjectPlan.RESERVED
	# Obwódka (8 sąsiadów części na podłodze) bez innych obiektów: pojedyncza skrzynia tuż przed winietą zamykała
	# rząd przed nią w kieszeń, a naprawa osiągalności zdejmowała całą winietę (seed 3: 25 obiektów).
	for j in taken:
		var c := f.cell(j)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := c + Vector2i(dx, dy)
				if f.in_bounds(q) and not taken.has(f.idx(q)) and f.walk[f.idx(q)] == 1:
					plan.occupancy[f.idx(q)] |= ObjectPlan.FORBID
	return true


## Odległość od wody kanału (BFS Chebysheva do `limit`); dalej = limit.
func _canal_distance(canals, limit: int) -> void:
	var n := f.width * f.height
	canal_dist.resize(n)
	canal_dist.fill(limit)
	var frontier: Array[int] = []
	for c in canals.water:
		if f.in_bounds(c) and not canals.crossing_cells.has(c):
			canal_dist[f.idx(c)] = 0
			frontier.append(f.idx(c))
	var dist := 0
	while not frontier.is_empty() and dist < limit:
		dist += 1
		var nxt: Array[int] = []
		for i in frontier:
			var c := f.cell(i)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := c + Vector2i(dx, dy)
					if f.in_bounds(q) and canal_dist[f.idx(q)] > dist:
						canal_dist[f.idx(q)] = dist
						nxt.append(f.idx(q))
		frontier = nxt


## canal_gap: kratki podstawy i rysunku (size) co najmniej canal_gap wolnych kratek od wody (odległość > gap).
func _canal_ok(def: ObjectDef, anchor: Vector2i) -> bool:
	if def.canal_gap <= 0 or canal_dist.is_empty():
		return true
	for dy in range(-(maxi(def.size.y, 1) - 1), 1):
		for dx in range(maxi(def.size.x, 1)):
			var q := anchor + Vector2i(dx, dy)
			if f.in_bounds(q) and canal_dist[f.idx(q)] <= def.canal_gap:
				return false
	return true


## Duży obiekt z zestawem: w promieniu set_gap od jego kratek nie ma dużego obiektu z innego zestawu.
func _set_ok(def: ObjectDef, cells: PackedInt32Array) -> bool:
	if set_gap <= 0 or def.set_id == &"" or not def.is_big():
		return true
	var mine := int(set_ids.get(def.set_id, -1)) + 1
	for j in _draw_cells(def, cells):
		var c := f.cell(j)
		for dy in range(-set_gap, set_gap + 1):
			for dx in range(-set_gap, set_gap + 1):
				var q := c + Vector2i(dx, dy)
				if not f.in_bounds(q):
					continue
				var s := set_of[f.idx(q)]
				if s != 0 and s != mine:
					return false
	return true


func _mark_set(def: ObjectDef, cells: PackedInt32Array) -> void:
	if set_gap <= 0 or def.set_id == &"" or not def.is_big():
		return
	if not set_ids.has(def.set_id):
		set_ids[def.set_id] = set_ids.size()
	var mine := int(set_ids[def.set_id]) + 1
	for j in _draw_cells(def, cells):
		set_of[j] = mine


## Kratki rysunku obiektu: podstawa i kratki nad nią do wysokości size.y — odstęp zestawów liczony od całego rysunku
## (filar 1×5 stawał podstawą 3 kratki od stołu, a jego trzon sięgał blatu).
func _draw_cells(def: ObjectDef, cells: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for j in cells:
		var c := f.cell(j)
		for dy in range(maxi(def.size.y, 1)):
			var q := c + Vector2i(0, -dy)
			if f.in_bounds(q):
				out.append(f.idx(q))
	return out


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
## Przy losowym odbiciu sprawdzane są obie strony. `facade_ok` (części winiet): wolno zakryć lico tuż nad podstawą —
## kratkę ściany, pod którą w tej kolumnie jest podłoga obiektu (skrzynia przed licem, jak na makietach).
func _visual_on_wall(def: ObjectDef, pt: Vector2, facade_ok := false) -> bool:
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
			if not f.in_bounds(q):
				return true
			if f.walk[f.idx(q)] == 0 and not (facade_ok and _facade_over_floor(q)):
				return true
			var pw := pl_wall[f.idx(q)]
			if pw == 2 or (pw == 1 and not facade_ok):
				return true  # schody platformy / lico, rim — jak ściana
	return false


## Kratka ściany `q` należy do lica nad podłogą: w jej kolumnie, w zasięgu 3 kratek w dół, jest podłoga.
func _facade_over_floor(q: Vector2i) -> bool:
	for k in range(1, 4):
		var b := q + Vector2i(0, k)
		if not f.in_bounds(b):
			return false
		if f.walk[f.idx(b)] != 0:
			return true
	return false


## Kratka wolna dla obiektu: bez FORBID i innego obiektu; z kolizją — nie na przejściu (keep_paths).
func _cell_free(def: ObjectDef, j: int) -> bool:
	var o := plan.occupancy[j]
	if o & (ObjectPlan.FORBID | ObjectPlan.USED):
		return false
	if o & ObjectPlan.NO_DECAL and def.klass == ObjectDef.Klass.DECAL:
		return false
	return not (def.is_solid() and def.keep_paths and o & ObjectPlan.RESERVED)


## Free: punkt losowy w kratce, odstęp `spacing_px` od punktów tego obiektu (kubełki = kratki).
## Bez kolizji: kratka może mieć kilka punktów TEGO obiektu. Z kolizją: blokuje kratki, których
## środek leży w kształcie (≈ pokrycie ≥ połowy), co najmniej kratkę punktu.
func _try_free(def: ObjectDef, marker: int, i: int, rng: RandomNumberGenerator) -> bool:
	var o := plan.occupancy[i]
	if o & ObjectPlan.FORBID or (o & ObjectPlan.NO_DECAL and def.klass == ObjectDef.Klass.DECAL):
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
	if not def.facing.is_empty() and not def.facing_pref.is_empty():
		_pick_facing(pl, rng)
	else:
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


## Wariant + odbicie wg facing_pref: waga kombinacji = 1 + suma wag preferencji, których kierunek pasuje.
func _pick_facing(pl: ObjectPlacement, rng: RandomNumberGenerator) -> void:
	var def := pl.def
	var want := {}  # kierunek -> waga
	for key: StringName in def.facing_pref:
		var w: float = def.facing_pref[key]
		var dirs: Array[StringName] = []
		match key:
			&"parent":
				if parent_center.x >= 0.0:
					dirs = _dirs_toward(parent_center - Vector2(pl.cell))
			&"wall", &"away_wall":
				var d := _wall_dir(pl.cell)
				if d != Vector2i.ZERO:
					dirs = _dirs_toward(Vector2(d) if key == &"wall" else -Vector2(d))
			_:
				dirs = [key]
		for dn in dirs:
			want[dn] = float(want.get(dn, 0.0)) + w
	var combos: Array = []  # [wariant, odbicie, waga]
	var total := 0.0
	for v in range(def.variant_count()):
		for fl in ([false, true] if def.flip_h else [false]):
			var fc: StringName = def.facing[v]
			if fl and fc == &"E":
				fc = &"W"
			elif fl and fc == &"W":
				fc = &"E"
			var w := 1.0 + float(want.get(fc, 0.0))
			combos.append([v, fl, w])
			total += w
	var r := rng.randf() * total
	for cmb in combos:
		r -= float(cmb[2])
		if r <= 0.0:
			pl.variant = cmb[0]
			pl.flip = cmb[1]
			return
	pl.variant = combos[-1][0]
	pl.flip = combos[-1][1]


## Kierunki (N/S/E/W) wektora: dominująca oś, przy przekątnej — obie.
static func _dirs_toward(v: Vector2) -> Array[StringName]:
	var out: Array[StringName] = []
	if v == Vector2.ZERO:
		return out
	var ax := absf(v.x)
	var ay := absf(v.y)
	if ax >= ay * 0.5 and ax > 0.0:
		out.append(&"E" if v.x > 0.0 else &"W")
	if ay >= ax * 0.5 and ay > 0.0:
		out.append(&"S" if v.y > 0.0 else &"N")
	return out


## Kierunek do najbliższej ściany (sąsiad w odległości 1–2 kratek), ZERO gdy brak.
func _wall_dir(c: Vector2i) -> Vector2i:
	for dist in [1, 2]:
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var q: Vector2i = c + d * dist
			if f.in_bounds(q) and f.walk[f.idx(q)] == 0:
				return d
	return Vector2i.ZERO


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

## Teren osiągalny przed obiektami, a odcięty przez przeszkody -> z każdego odciętego kawałka zdejmij JEDNĄ przeszkodę
## (najbliżej przylegającą: promień 1, gdy brak — REACH_NEAR) i policz od nowa — zwykle szczelinę zamyka jeden obiekt,
## więc reszta zostaje. Osiągalność jak dla wroga (_bfs_agent): po środkach kratek, z odstępem
## promienia agenta od dokładnych kształtów przeszkód (te same obrysy co siatka nawigacji) — sama zajętość
## kratek przepuszczała szczeliny, w których siatka nawigacji się rwała (500×500: ~1/3 par bez ścieżki).
## Obiekt INTERACTIVE (skrzynia) bez osiągalnego sąsiada (obstawiony przeszkodami) -> zdejmij jedną przeszkodę
## przy nim, a gdy się nie da — jego samego. Powtarzaj do skutku.
## Kontrola B (bramy GatePlanner): przejście z wejścia przy zamkniętych bramach, brama otwiera się po dojściu do
## jej płyty albo klucza i zamka (_bfs_gated). Brama, której nic osiągalnego nie otwiera — z samego planu bram albo
## przez przeszkody, których naprawa nie zdjęła — nie powstaje (otwieracz "", płyty bez niej): mapa bez niej jest
## grywalna, a z nią odcięta. Po kontroli każda brama się otwiera, więc osiągalność bez bram = z bramami.
func _verify_reach() -> void:
	if entrance_i < 0:
		return
	if not gate_idx.is_empty():
		var zero := PackedByteArray()
		zero.resize(f.width * f.height)
		_drop_gates(_bfs_gated(zero, false)[1], &"gates_dropped_plan")
	_repair_reach()
	if not gate_idx.is_empty():
		_drop_gates(_bfs_gated(_clearance(), true)[1], &"gates_dropped_objects")


## Bramy z GatePlanner (z otwieraczem): kratki kolców i zestawy kratek, z których każdy ją otwiera — płyta naciskowa
## z jej id (zagadka albo skrót za bramą) albo klucz + zamek.
func _collect_gates(result) -> void:
	var canals = result.canals
	if canals == null or not "gate_openers" in canals:
		return
	gate_canals = canals
	for gi in range(mini(canals.gates.size(), canals.gate_openers.size())):
		var opener := String(canals.gate_openers[gi])
		if opener.is_empty():
			continue
		var cells := PackedInt32Array()
		for c: Vector2i in canals.gates[gi]:
			if f.in_bounds(c):
				cells.append(f.idx(c))
		var sets: Array = []
		if opener == "lock":
			var key: Vector2i = canals.levers[gi]
			var lock: Vector2i = canals.gate_locks[gi]
			if f.in_bounds(key) and f.in_bounds(lock):
				sets.append(PackedInt32Array([f.idx(key), f.idx(lock)]))
		if "gate_plates" in canals:
			for pe in canals.gate_plates:
				var pc: Vector2i = pe.cell
				if (pe.gates as Array).has(gi) and f.in_bounds(pc):
					sets.append(PackedInt32Array([f.idx(pc)]))
		gate_gi.append(gi)
		gate_idx.append(cells)
		gate_sets.append(sets)


## BFS jak _bfs_agent przy zamkniętych bramach: brama otwiera się, gdy wszystkie kratki któregoś jej zestawu są
## dotknięte (osiągalne albo z osiągalnym sąsiadem); powtarzane, dopóki otwierają się nowe.
## `with_objects` false: bez przeszkód (clr same zera) — sam plan bram. -> [rodzice, PackedByteArray otwartych bram].
func _bfs_gated(clr: PackedByteArray, with_objects: bool) -> Array:
	var n := f.width * f.height
	var closed := PackedByteArray()
	closed.resize(n)
	var opened := PackedByteArray()
	opened.resize(gate_idx.size())
	for cells in gate_idx:
		for j in cells:
			closed[j] = 1
	var parent := PackedInt32Array()
	for _stage in range(gate_idx.size() + 1):
		parent = _bfs_agent(entrance_i, clr, closed, with_objects)
		var more := false
		for g in range(gate_idx.size()):
			if opened[g] == 1:
				continue
			for st: PackedInt32Array in gate_sets[g]:
				var all := true
				for j in st:
					if not _touched(j, parent):
						all = false
						break
				if all:
					opened[g] = 1
					more = true
					for j in gate_idx[g]:
						closed[j] = 0
					break
		if not more:
			break
	return [parent, opened]


func _touched(i: int, parent: PackedInt32Array) -> bool:
	if parent[i] != -1:
		return true
	var w := f.width
	var x := i % w
	return (x > 0 and parent[i - 1] != -1) or (x < w - 1 and parent[i + 1] != -1) \
			or (i >= w and parent[i - w] != -1) or (i + w < parent.size() and parent[i + w] != -1)


## Bramy nieotwarte (`opened[g] == 0`) nie powstają: otwieracz "" w canals, płyty bez nich (pusta płyta znika).
func _drop_gates(opened: PackedByteArray, stat: StringName) -> void:
	var keep := PackedInt32Array()
	var dropped := {}
	for g in range(gate_idx.size()):
		if opened[g] == 1:
			keep.append(g)
		else:
			dropped[gate_gi[g]] = true
	if dropped.is_empty():
		return
	plan.stats[stat] = int(plan.stats.get(stat, 0)) + dropped.size()
	for gi: int in dropped:
		gate_canals.gate_openers[gi] = ""
	if "gate_plates" in gate_canals:
		var plates: Array = []
		for pe in gate_canals.gate_plates:
			var left: Array = []
			for gi in pe.gates:
				if not dropped.has(gi):
					left.append(gi)
			if not left.is_empty():
				pe.gates = left
				plates.append(pe)
		gate_canals.gate_plates = plates
	var gi2 := PackedInt32Array()
	var idx2: Array[PackedInt32Array] = []
	var sets2: Array = []
	for g in keep:
		gi2.append(gate_gi[g])
		idx2.append(gate_idx[g])
		sets2.append(gate_sets[g])
	gate_gi = gi2
	gate_idx = idx2
	gate_sets = sets2


func _repair_reach() -> void:
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
		# Grupy: odcięte kawałki (8-spójne) i kratki obstawionych obiektów interaktywnych — z każdej jedna przeszkoda.
		var groups: Array = _cut_groups(cut)
		for pl in boxed:
			groups.append(Array(pl.cells))
		var drop := {}
		# Ostatnie rundy (duże mapy, wiele kawałków): po staremu — wszystkie przeszkody w zasięgu, żeby nic nie zostało odcięte.
		var greedy: bool = _round < REACH_ROUNDS - REACH_MASS_ROUNDS
		for g in groups:
			if greedy:
				var pick: ObjectPlacement = _blocker(g, boxed, drop)
				if pick != null:
					drop[pick] = true
			else:
				for pl in _blockers_near(g, boxed):
					drop[pl] = true
		if drop.is_empty():
			if boxed.is_empty():
				return
			drop = boxed  # nic wokół nie da się zdjąć — zdejmij obstawione obiekty interaktywne
		var keep: Array[ObjectPlacement] = []
		var removed := 0
		for pl in plan.placements:
			if drop.has(pl):
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


## Kawałki (8-spójne) odciętych kratek -> Array[Array[int]], kolejność stała (od najmniejszego indeksu).
func _cut_groups(cut: Dictionary) -> Array:
	var w := f.width
	var keys: Array = cut.keys()
	keys.sort()
	var seen := {}
	var out: Array = []
	for start in keys:
		if seen.has(start):
			continue
		seen[start] = true
		var comp: Array = [start]
		var head := 0
		while head < comp.size():
			var i: int = comp[head]
			head += 1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var j: int = i + dy * w + dx
					if cut.has(j) and not seen.has(j) and absi(j % w - i % w) <= 1:
						seen[j] = true
						comp.append(j)
		out.append(comp)
	return out


## Przeszkoda do zdjęcia dla grupy kratek: z kolizją, nie obstawiona skrzynia, z największą liczbą kratek w promieniu 1
## od grupy (gdy żadnej — REACH_NEAR); null, gdy grupę obsługuje już zdejmowany obiekt albo nic nie ma w zasięgu.
func _blocker(group: Array, boxed: Dictionary, drop: Dictionary) -> ObjectPlacement:
	var w := f.width
	var n := f.width * f.height
	for r in [1, REACH_NEAR]:
		var near := {}
		for i in group:
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var j: int = i + dy * w + dx
					if j >= 0 and j < n and absi(j % w - i % w) <= r:
						near[j] = true
		var best: ObjectPlacement = null
		var best_hits := 0
		for pl in plan.placements:
			if not pl.def.is_solid() or boxed.has(pl):
				continue
			var hits := 0
			for j in pl.cells:
				if near.has(j):
					hits += 1
			if hits == 0:
				continue
			if drop.has(pl):
				return null
			if hits > best_hits:
				best = pl
				best_hits = hits
		if best != null:
			return best
	return null


## Wszystkie przeszkody z kolizją (bez obstawionych skrzyń) w promieniu REACH_NEAR od grupy.
func _blockers_near(group: Array, boxed: Dictionary) -> Array:
	var w := f.width
	var n := f.width * f.height
	var near := {}
	for i in group:
		for dy in range(-REACH_NEAR, REACH_NEAR + 1):
			for dx in range(-REACH_NEAR, REACH_NEAR + 1):
				var j: int = i + dy * w + dx
				if j >= 0 and j < n and absi(j % w - i % w) <= REACH_NEAR:
					near[j] = true
	var out: Array = []
	for pl in plan.placements:
		if not pl.def.is_solid() or boxed.has(pl):
			continue
		for j in pl.cells:
			if near.has(j):
				out.append(pl)
				break
	return out


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
## `closed`: kratki zamkniętych bram (puste = brak); `with_objects` false — przeszkody z planu nie blokują.
func _bfs_agent(start: int, clr: PackedByteArray, closed := PackedByteArray(), with_objects := true) -> PackedInt32Array:
	var n := f.width * f.height
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	if start < 0 or not _movable(start):
		return parent
	var ok := PackedByteArray()
	ok.resize(n)
	var solid := ObjectPlan.SOLID if with_objects else 0
	var gated := not closed.is_empty()
	for i in range(n):
		if f.walk[i] == 1 and blocked[i] == 0 and not plan.occupancy[i] & solid and clr[i] & CLR_CENTER == 0 \
				and not (gated and closed[i] == 1):
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
