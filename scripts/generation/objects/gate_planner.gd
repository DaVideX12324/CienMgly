extends RefCounted

## Bramy korytarzy serwisowych (canals.gates — 3 kratki w poprzek korytarza) jako zagadka „klucz -> zamek":
## - bariera z kolców (scena "barrier", tryb BARRIER) na każdej kratce bramy — blokuje przejście;
## - zamek na licu ściany (scena "lock") najbliżej bramy po stronie wejścia (BFS do LOCK_RADIUS kratek);
##   kratka podłogi pod licem = dojście do zamka;
## - klucz (scena "key") w miejscu canals.levers (pokój / sala osiągalna z wejścia bez przechodzenia przez bramy,
##   ~18 kratek od bramy) — każdy klucz osiągalny, więc zagadka zawsze rozwiązywalna.
## Klucze są wspólne dla poziomu (licznik: podniesione - użyte), zamek po włożeniu klucza otwiera swoją bramę.
## Brama bez miejsca na zamek albo bez klucza nie powstaje (korytarz zostaje otwarty).
##
## select() — w generatorze układu przed planerem obiektów: canals.gate_locks (kratka lica, wyrównane z gates;
## (-1, -1) = brak). ObjectPlanner trzyma z dala obiekty, WallDecorPlanner — ozdoby lica.
## emit() — po planerach: sceny w ObjectPlan (ObjectPlacement.link = id bramy).
## Katalog obiektów: "gates": {"barrier": "res://…", "barrier_column": "res://…", "lock": "res://…", "key": "res://…"}
## — barrier_column (opcjonalnie): brama w kolumnie kratek (korytarz poziomy) — niskie kolce, żeby wysokie nie
## zlewały się w jeden słup.

const LOCK_RADIUS := 16
const MIN_FACE_H := 3
const NONE := Vector2i(-1, -1)


static func select(result, on_wall: bool) -> int:
	var canals = result.canals
	if canals == null or not "gates" in canals or canals.gates.is_empty():
		return 0
	canals.gate_locks = []
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
		if key != NONE and reach.has(key):
			lock = _lock_cell(result, canals.gates[gi], reach, gate_cells)
		if lock != NONE:
			made += 1
			lock = lock + Vector2i(0, -1) if on_wall else lock   # kotwica jak ozdoby lica (facade_base_on_wall)
		canals.gate_locks.append(lock)
	return made


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
	if canals == null or not "gate_locks" in canals:
		return out
	for gi in range(mini(canals.gates.size(), canals.gate_locks.size())):
		var lock: Vector2i = canals.gate_locks[gi]
		if lock == NONE:
			continue
		for c: Vector2i in canals.gates[gi]:
			out.append(c)
		out.append(canals.levers[gi])
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
	var c: Vector2i = gate[1]
	return "gate_%d_%d" % [c.x, c.y]


## Sceny bram, zamków i kluczy do ObjectPlan (po planerach obiektów i ozdób lica).
static func emit(result, scenes: Dictionary, objects: ObjectPlan) -> int:
	var canals = result.canals
	if objects == null or scenes.is_empty() or canals == null or not "gate_locks" in canals:
		return 0
	var barrier_def := _def(&"gate_barrier", String(scenes.get("barrier", "")), &"")
	var lock_def := _def(&"gate_lock", String(scenes.get("lock", "")), &"facade")
	var key_def := _def(&"gate_key", String(scenes.get("key", "")), &"")
	var column_def := _def(&"gate_barrier", String(scenes.get("barrier_column", scenes.get("barrier", ""))), &"")
	if barrier_def.scene.is_empty() or lock_def.scene.is_empty() or key_def.scene.is_empty():
		return 0
	var made := 0
	for gi in range(mini(canals.gates.size(), canals.gate_locks.size())):
		var lock: Vector2i = canals.gate_locks[gi]
		if lock == NONE:
			continue
		var id := gate_id(canals.gates[gi])
		var gate: Array = canals.gates[gi]
		var column: bool = gate[0].x == gate[2].x
		for c: Vector2i in gate:
			_add(objects, column_def if column else barrier_def, c, id)
		_add(objects, lock_def, lock, id)
		_add(objects, key_def, canals.levers[gi], id)
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
