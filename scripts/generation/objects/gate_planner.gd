extends RefCounted

## Bramy na korytarzach (canals.gates — 2–4 kratki w poprzek korytarza): bariera z kolców (scena "barrier",
## tryb BARRIER) na każdej kratce bramy blokuje przejście; otwiera ją jedna z dwóch zagadek:
## - „klucz -> zamek": zamek na licu ściany (scena "lock") najbliżej bramy po stronie wejścia (BFS do LOCK_RADIUS
##   kratek; kratka podłogi pod licem = dojście), klucz (scena "key") w miejscu canals.levers. Klucze wspólne dla
##   poziomu (podniesione - użyte), zamek po włożeniu klucza otwiera swoją bramę;
## - płyta naciskowa (scena "plate") w miejscu canals.levers: gracz staje -> płyta wciśnięta na stałe, brama otwarta.
## Miejsce dźwigni (canals.levers) leży w pokoju / sali osiągalnej z wejścia bez przechodzenia przez bramy, ~18 kratek
## od bramy — zagadka zawsze rozwiązywalna. Bramy są też na zwykłych korytarzach (decyzja usera — nie tylko serwisowe):
## gdy bram jest mniej niż `min_gates`, _add_corridor_gates dokłada je w poprzek prostych odcinków korytarzy, których
## zamknięcie odcina od wejścia część mapy z pokojem (>= CUT_MIN kratek). Z szansą `plate_chance` (katalog
## "gates") płyta, inaczej zamek; bez miejsca na zamek — płyta; bez sceny płyty i bez zamka — brama nie powstaje.
##
## select() — w generatorze układu przed planerem obiektów: canals.gate_openers ("lock" / "plate" / "", wyrównane
## z gates) i canals.gate_locks (kratka lica, (-1, -1) = brak). ObjectPlanner trzyma z dala obiekty,
## WallDecorPlanner — ozdoby lica.
## emit() — po planerach: sceny w ObjectPlan (ObjectPlacement.link = id bramy).
## Katalog obiektów: "gates": {"barrier": "res://…", "barrier_column": "res://…", "lock": "res://…", "key": "res://…",
##   "plate": "res://…", "plate_chance": 0.5, "min_gates": 2, "barrier_offset": "res://…", "barrier_offset_chance": 0.5}
##   — barrier_offset (opcjonalnie): brama w rzędzie z kolcami przesuniętymi o pół kratki, na granicach kratek i na
##   krawędziach podłogi przy murze (z szansą barrier_offset_chance).
## — barrier_column (opcjonalnie): brama w kolumnie kratek (korytarz poziomy) — niskie kolce, żeby wysokie nie
## zlewały się w jeden słup.

const LOCK_RADIUS := 16
const CUT_MIN := 40           # brama na korytarzu: tyle kratek musi zostać za nią (z pokojem)
const GATE_SPACING := 20      # odstęp (Manhattan) środków bram
const CORRIDOR_TRIES := 80    # najwyżej tyle kandydatów sprawdzanych przeszukiwaniem
const MIN_FACE_H := 3
const NONE := Vector2i(-1, -1)


static func select(result, on_wall: bool, cfg: Dictionary = {}) -> int:
	var canals = result.canals
	if canals == null or not "gates" in canals:
		return 0
	_add_corridor_gates(result, cfg)
	if canals.gates.is_empty():
		return 0
	canals.gate_locks = []
	canals.gate_openers = []
	var has_plate := not String(cfg.get("plate", "")).is_empty()
	var has_lock := not String(cfg.get("lock", "")).is_empty() and not String(cfg.get("key", "")).is_empty()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([result.seed_used, "gates"])
	var grid: Dictionary = result.grid
	var gate_cells := {}
	for g in canals.gates:
		for c: Vector2i in g:
			gate_cells[c] = true
	var reach := _reach(result, gate_cells)
	var made := 0
	for gi in range(canals.gates.size()):
		var key: Vector2i = canals.levers[gi] if gi < canals.levers.size() else NONE
		var lock := NONE
		var opener := ""
		if key == NONE or not reach.has(key):
			# miejsce dźwigni wybrane przed czyszczeniem siatki / ścianami działowymi mogło wypaść z części startowej
			key = _fallback_key(result, canals.gates[gi], reach)
			if gi < canals.levers.size():
				canals.levers[gi] = key
		if key != NONE and reach.has(key):
			if has_plate and (not has_lock or rng.randf() < float(cfg.get("plate_chance", 0.5))):
				opener = "plate"
			elif has_lock:
				lock = _lock_cell(result, canals.gates[gi], reach, gate_cells)
				if lock != NONE:
					opener = "lock"
					lock = lock + Vector2i(0, -1) if on_wall else lock   # kotwica jak ozdoby lica (facade_base_on_wall)
				elif has_plate:
					opener = "plate"
		if not opener.is_empty():
			made += 1
		canals.gate_locks.append(lock)
		canals.gate_openers.append(opener)
	return made


## Bramy w poprzek prostych odcinków korytarzy (canals.corridors), aż będzie ich `min_gates` (katalog "gates").
## Kandydat: przekrój korytarza szerokości 2–4 (mur po obu stronach), ten sam przekrój 2 kratki przed i za. Brama
## zostaje, gdy po jej zamknięciu (razem z wcześniejszymi bramami) część mapy z pokojem i >= CUT_MIN kratek jest
## nieosiągalna z wejścia. Miejsce klucza / płyty — _fallback_key (canals.levers = NONE).
static func _add_corridor_gates(result, cfg: Dictionary) -> void:
	var canals = result.canals
	var want: int = int(cfg.get("min_gates", 2)) - canals.gates.size()
	if want <= 0 or not "corridors" in canals or canals.corridors.is_empty():
		return
	var w: int = result.width
	var h: int = result.height
	var walk := PackedByteArray()
	walk.resize(w * h)
	var total := 0
	for y in range(h):
		for x in range(w):
			if _walk(result, Vector2i(x, y)):
				walk[y * w + x] = 1
				total += 1
	for g in canals.gates:
		for c: Vector2i in g:
			if walk[c.y * w + c.x]:
				walk[c.y * w + c.x] = 0
				total -= 1
	var start: Vector2i = result.entrance_pos
	if start.x < 0 or start.y < 0 or start.x >= w or start.y >= h or not walk[start.y * w + start.x]:
		return
	var rooms := PackedInt32Array()
	for c: Vector2i in canals.areas:
		if String(canals.areas[c]).begins_with("room:"):
			rooms.append(c.y * w + c.x)
	var near_portal := {}
	for p: Vector2i in result.portal_zone:
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				near_portal[p + Vector2i(dx, dy)] = true
	var is_open := func(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and walk[c.y * w + c.x] == 1
	# kandydaci: przekroje korytarza
	var keys: Array = canals.corridors.keys()
	keys.sort()
	var cands: Array = []
	for c: Vector2i in keys:
		for horiz in [true, false]:
			var across := Vector2i(0, 1) if horiz else Vector2i(1, 0)
			var along := Vector2i(1, 0) if horiz else Vector2i(0, 1)
			if is_open.call(c - across):
				continue   # c = pierwsza kratka przekroju
			var cells: Array[Vector2i] = _cross_section(is_open, c, across)
			if cells.size() < 2 or cells.size() > 4:
				continue
			var ok := true
			for k in [-2, -1, 1, 2]:
				var o: Vector2i = along * k
				if is_open.call(c + o - across) or _cross_section(is_open, c + o, across).size() != cells.size():
					ok = false
					break
			for q in cells:
				ok = ok and canals.corridors.has(q) and not near_portal.has(q) and not canals.bridge_cells.has(q) \
						and not canals.service.has(q) and not canals.water.has(q)
			if ok:
				cands.append(cells)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([result.seed_used, "corridor_gates"])
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = cands[i]
		cands[i] = cands[j]
		cands[j] = t
	var tries := 0
	for cells: Array in cands:
		if want <= 0 or tries >= CORRIDOR_TRIES:
			break
		var mid: Vector2i = cells[cells.size() / 2]
		var far := true
		for g in canals.gates:
			var gc: Vector2i = g[g.size() / 2]
			if absi(gc.x - mid.x) + absi(gc.y - mid.y) < GATE_SPACING:
				far = false
		if not far:
			continue
		tries += 1
		for q: Vector2i in cells:
			walk[q.y * w + q.x] = 0
		var seen := _flood(walk, w, h, start.y * w + start.x)
		var reached := 0
		for i in range(seen.size()):
			reached += seen[i]
		var cut := total - cells.size() - reached
		var room_cut := false
		if cut >= CUT_MIN:
			for i in rooms:
				if walk[i] and not seen[i]:
					room_cut = true
					break
		if room_cut:
			canals.gates.append(cells)
			canals.levers.append(NONE)
			total -= cells.size()
			want -= 1
		else:
			for q: Vector2i in cells:
				walk[q.y * w + q.x] = 1


## Przekrój korytarza od `c` w kierunku `across` (kratki otwarte aż do muru).
static func _cross_section(is_open: Callable, c: Vector2i, across: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var q := c
	while is_open.call(q) and out.size() <= 5:
		out.append(q)
		q += across
	return out


static func _flood(walk: PackedByteArray, w: int, h: int, start: int) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var q := PackedInt32Array([start])
	seen[start] = 1
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var x := i % w
		var y := i / w
		if x > 0 and walk[i - 1] and not seen[i - 1]:
			seen[i - 1] = 1
			q.append(i - 1)
		if x < w - 1 and walk[i + 1] and not seen[i + 1]:
			seen[i + 1] = 1
			q.append(i + 1)
		if y > 0 and walk[i - w] and not seen[i - w]:
			seen[i - w] = 1
			q.append(i - w)
		if y < h - 1 and walk[i + w] and not seen[i + w]:
			seen[i + w] = 1
			q.append(i + w)
	return seen


static func _walk(result, c: Vector2i) -> bool:
	return GridUtils.is_walkable(result.grid, c) and not result.canals.blocked.has(c)


## Kratki osiągalne z wejścia bez przechodzenia przez bramy (4-sąsiedzi).
static func _reach(result, gate_cells: Dictionary) -> Dictionary:
	var seen := {}
	var start: Vector2i = result.entrance_pos
	if not _walk(result, start):
		return seen
	seen[start] = true
	var q: Array[Vector2i] = [start]
	var h := 0
	while h < q.size():
		var c := q[h]
		h += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or gate_cells.has(n) or not _walk(result, n):
				continue
			seen[n] = true
			q.append(n)
	return seen


## Zastępcze miejsce klucza / płyty: kratka pokoju albo sali osiągalna z wejścia bez bram, bez wody, chodników,
## korytarzy serwisowych, kładek, barierek, kratownic i portali, najbliżej 18 kratek (Manhattan) od bramy.
static func _fallback_key(result, gate: Array, reach: Dictionary) -> Vector2i:
	var canals = result.canals
	var gc: Vector2i = gate[gate.size() / 2]
	var best := NONE
	var bd := 1 << 30
	for c: Vector2i in reach:
		var a := String(canals.areas.get(c, ""))
		if not (a.begins_with("room:") or a.begins_with("hall:")):
			continue
		if canals.water.has(c) or canals.lanes.has(c) or canals.service.has(c) or canals.bridge_cells.has(c) 				or canals.rail_cells.has(c) or canals.grating.has(c) or result.portal_zone.has(c):
			continue
		var d: int = absi(absi(c.x - gc.x) + absi(c.y - gc.y) - 18)
		if d < bd or (d == bd and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			bd = d
			best = c
	return best


## Kratka podłogi pod licem (ściana >= MIN_FACE_H nad nią) najbliżej bramy, w części osiągalnej z wejścia.
static func _lock_cell(result, gate: Array, reach: Dictionary, gate_cells: Dictionary) -> Vector2i:
	var canals = result.canals
	var near_portal := {}
	for p: Vector2i in result.portal_zone:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				near_portal[p + Vector2i(dx, dy)] = true
	var dist := {}
	var q: Array[Vector2i] = []
	for c: Vector2i in gate:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if reach.has(n) and not dist.has(n):
				dist[n] = 1
				q.append(n)
	var h := 0
	var best := NONE
	var bd := 1 << 30
	while h < q.size():
		var c := q[h]
		h += 1
		var dc: int = dist[c]
		if dc > bd or dc > LOCK_RADIUS:
			break
		if _face_above(result, c) and not near_portal.has(c) and not canals.bridge_cells.has(c) \
				and not canals.rail_cells.has(c) and not canals.water.has(c):
			if dc < bd or (dc == bd and (c.y < best.y or (c.y == best.y and c.x < best.x))):
				best = c
				bd = dc
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if reach.has(n) and not dist.has(n) and not gate_cells.has(n):
				dist[n] = dc + 1
				q.append(n)
	return best


## Nad kratką `c` lico: MIN_FACE_H kratek ściany (nie ściana szer. 1, nie woda).
static func _face_above(result, c: Vector2i) -> bool:
	for k in range(1, MIN_FACE_H + 1):
		var w := c + Vector2i(0, -k)
		if GridUtils.is_walkable(result.grid, w) or result.canals.water.has(w) or result.canals.walls_1w.has(w):
			return false
	return true


## Kratki zajęte przez zagadki bram (bramy, klucze, dojścia do zamków) — planer obiektów ich nie zastawia.
static func reserved_cells(canals) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if canals == null or not "gate_openers" in canals:
		return out
	for gi in range(mini(canals.gates.size(), canals.gate_openers.size())):
		if String(canals.gate_openers[gi]).is_empty():
			continue
		for c: Vector2i in canals.gates[gi]:
			out.append(c)
		out.append(canals.levers[gi])
		var lock: Vector2i = canals.gate_locks[gi]
		if lock != NONE:
			out.append(lock)
			out.append(lock + Vector2i(0, 1))
			out.append(lock + Vector2i(0, 2))
	return out


## Kolumny lica z zamkami (kotwica -> true, z sąsiednimi kolumnami) — bez ozdób lica.
static func lock_face_cells(canals) -> Dictionary:
	var out := {}
	if canals == null or not "gate_locks" in canals:
		return out
	for lock: Vector2i in canals.gate_locks:
		if lock == NONE:
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				out[lock + Vector2i(dx, dy)] = true
	return out


static func gate_id(gate: Array) -> String:
	var c: Vector2i = gate[gate.size() / 2]
	return "gate_%d_%d" % [c.x, c.y]


## Sceny bram, zamków i kluczy do ObjectPlan (po planerach obiektów i ozdób lica).
static func emit(result, scenes: Dictionary, objects: ObjectPlan) -> int:
	var canals = result.canals
	if objects == null or scenes.is_empty() or canals == null or not "gate_openers" in canals:
		return 0
	var barrier_def := _def(&"gate_barrier", String(scenes.get("barrier", "")), &"")
	var lock_def := _def(&"gate_lock", String(scenes.get("lock", "")), &"facade")
	var key_def := _def(&"gate_key", String(scenes.get("key", "")), &"")
	var plate_def := _def(&"gate_plate", String(scenes.get("plate", "")), &"")
	var column_def := _def(&"gate_barrier", String(scenes.get("barrier_column", scenes.get("barrier", ""))), &"")
	var offset_def := _def(&"gate_barrier", String(scenes.get("barrier_offset", "")), &"")
	var offset_chance := float(scenes.get("barrier_offset_chance", 0.5))
	if barrier_def.scene.is_empty():
		return 0
	var made := 0
	for gi in range(mini(canals.gates.size(), canals.gate_openers.size())):
		var opener := String(canals.gate_openers[gi])
		if opener.is_empty():
			continue
		var id := gate_id(canals.gates[gi])
		var gate: Array = canals.gates[gi]
		var column: bool = gate[0].x == gate[gate.size() - 1].x
		var c0: Vector2i = gate[0]
		if not column and not offset_def.scene.is_empty() \
				and float(hash([result.seed_used, c0, "gate_offset"]) & 0xFFFF) / 65536.0 < offset_chance:
			# wariant z kolcami przesuniętymi o pół kratki (Props (4–5,15)): kolec na każdej granicy kratek, także na
			# krawędziach podłogi przy murze (skrajne nachodzą na ścianę); kolizja każdego obejmuje obie sąsiednie kratki
			_add(objects, offset_def, c0 + Vector2i(-1, 0), id)
			for c: Vector2i in gate:
				_add(objects, offset_def, c, id)
			for c: Vector2i in gate:
				_reserve(objects, c)
		else:
			for c: Vector2i in gate:
				_add(objects, column_def if column else barrier_def, c, id)
		if opener == "lock":
			_add(objects, lock_def, canals.gate_locks[gi], id)
			_add(objects, key_def, canals.levers[gi], id)
		else:
			_add(objects, plate_def, canals.levers[gi], id)
		made += 1
	if made > 0:
		objects.stats[&"gates"] = made
	return made


static func _def(id: StringName, scene: String, mount: StringName) -> ObjectDef:
	var d := ObjectDef.new()
	d.id = id
	d.klass = ObjectDef.Klass.INTERACTIVE
	d.scene = scene
	d.mount = mount
	d.footprint = [Vector2i.ZERO]
	return d


static func _reserve(objects: ObjectPlan, c: Vector2i) -> void:
	if c.x >= 0 and c.y >= 0 and c.x < objects.width and c.y < objects.height:
		objects.occupancy[c.y * objects.width + c.x] |= ObjectPlan.USED


static func _add(objects: ObjectPlan, def: ObjectDef, c: Vector2i, link: String) -> void:
	var pl := ObjectPlacement.new()
	pl.def = def
	pl.cell = c
	pl.link = link
	if c.x >= 0 and c.y >= 0 and c.x < objects.width and c.y < objects.height:
		var j := c.y * objects.width + c.x
		pl.cells = PackedInt32Array([j])
		if def.mount.is_empty():
			objects.occupancy[j] |= ObjectPlan.USED
	objects.placements.append(pl)
