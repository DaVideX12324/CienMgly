class_name TreasurePlanner
extends RefCounted

## Skarb sekretnego pokoju ("treasure" w JSON mapy — nakładka "secret_room"): "count" skrzyń w pokoju najdalszym (po
## podłodze) od wejścia, jak najbliżej jego środka, na otwartej podłodze (wszyscy sąsiedzi chodliwi, bez barier
## płaskowyżów, stref portali, obiektów z kolizją i obiektów interaktywnych), co najmniej 2 kratki od spawnów wrogów i od
## siebie. Obiekty bez kolizji na kratce skrzyni i wokół niej zdjęte. Tier i łup — ProceduralLevel (_apply_treasure,
## prefiks unique_id "treasure_chest_"). Po planie kafli, przed siatką nawigacji i zapisem mapy. Bez losowania.
## "kind": "relic" (pokój relikwii) — zamiast skrzyni relikwia (relic_item.tscn, przedmiot i flaga z _apply_treasure).
## "guard_tier" > 0 — wróg tego tieru (4 = boss) na drodze od wejścia, GUARD_BACK kratek przed ostatnim pokojem.

const CHEST_DEF_ID := &"treasure_chest"
const RELIC_DEF_ID := &"treasure_relic"
const RARE_DEF_ID := &"rare_chest"
const RELIC_SCENE := "scenes/objects/relic_item.tscn"
const GUARD_BACK := 2
const QuizRpgPaths = preload("../../quiz_rpg_paths.gd")
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func plan(result, cfg: Dictionary) -> void:
	var count := int(cfg.get("count", 0))
	if count <= 0 or result.objects == null or result.rooms.is_empty() or result.entrance_pos == Vector2i.ZERO:
		return
	var objs: ObjectPlan = result.objects
	var blocked := {}
	if result.plateau != null and not result.plateau.is_empty():
		blocked = result.plateau.blocked
	var interactive := _interactive_cells(objs)
	var walk := func(c: Vector2i) -> bool:
		return GridUtils.is_walkable(result.grid, c) and not blocked.has(c)
	var dist := _floor_dist(result.entrance_pos, walk)
	# pokój najdalszy od wejścia (najdalsza osiągalna kratka w jego prostokącie)
	var room := Rect2i()
	var far := -1
	for r: Rect2i in result.rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var d := int(dist.get(Vector2i(x, y), -1))
				if d > far:
					far = d
					room = r
	if far < 0:
		return
	var relic: bool = cfg.get("kind", "chest") == "relic"
	var def := _def(RELIC_DEF_ID if relic else CHEST_DEF_ID, QuizRpgPaths.path(RELIC_SCENE) if relic else "chest")
	var avoid := _enemy_cells(result)
	var added := _place_in_room(result, room, def, count, avoid, walk, dist, interactive)
	if added.is_empty():
		return
	var guard_tier := int(cfg.get("guard_tier", 0))
	if guard_tier > 0:
		var g := _guard_cell(result, room, added[0].cell, walk)
		if g.x >= 0:
			result.enemy_spawns.append({"pos": g, "tier": guard_tier})
	_commit(objs, added)


## Skrzynie specjalne w rzadkich pokojach ("rare_rooms" w JSON mapy, pomysł usera 2026-10-12): pokoje najdalej od
## głównej drogi wejście -> wyjście (po podłodze, co najmniej "min_detour" kratek zboczenia), bez pokoju wejścia i wyjścia;
## liczba z "count": [min, max] (hash seeda mapy). W każdym jedna skrzynia blisko środka (unique_id "rare_chest_…");
## tier i łup — ProceduralLevel (_apply_special_chests z sekcji "rare_rooms"). Mapa bez wyjścia — bez rzadkich pokoi.
static func plan_rare(result, cfg: Dictionary) -> void:
	var rng_count: Array = cfg.get("count", [0, 0])
	if rng_count.size() != 2 or int(rng_count[1]) <= 0 or result.objects == null or result.rooms.is_empty() \
			or result.entrance_pos == Vector2i.ZERO or result.exit_pos == Vector2i.ZERO:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([result.seed_used, "rare_rooms"])
	var count := rng.randi_range(int(rng_count[0]), int(rng_count[1]))
	if count <= 0:
		return
	var objs: ObjectPlan = result.objects
	var blocked := {}
	if result.plateau != null and not result.plateau.is_empty():
		blocked = result.plateau.blocked
	var walk := func(c: Vector2i) -> bool:
		return GridUtils.is_walkable(result.grid, c) and not blocked.has(c)
	var path := _path_cells(result.entrance_pos, result.exit_pos, walk)
	if path.is_empty():
		return
	var detour := _multi_dist(path, walk)
	var min_detour := int(cfg.get("min_detour", 12))
	var scored: Array = []
	for r: Rect2i in result.rooms:
		if r.grow(2).has_point(result.entrance_pos) or r.grow(2).has_point(result.exit_pos):
			continue
		var best := -1
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				best = maxi(best, int(detour.get(Vector2i(x, y), -1)))
		if best >= min_detour:
			scored.append([best, r])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] or (a[0] == b[0] and (a[1].position.y < b[1].position.y or (a[1].position.y == b[1].position.y and a[1].position.x < b[1].position.x))))
	var interactive := _interactive_cells(objs)
	var dist := _floor_dist(result.entrance_pos, walk)
	var def := _def(RARE_DEF_ID, "chest")
	var avoid := _enemy_cells(result)
	var added: Array[ObjectPlacement] = []
	for s in scored:
		if added.size() >= count:
			break
		var one := _place_in_room(result, s[1], def, 1, avoid, walk, dist, interactive)
		added.append_array(one)
	if not added.is_empty():
		_commit(objs, added)


static func _def(id: StringName, scene: String) -> ObjectDef:
	var def := ObjectDef.new()
	def.id = id
	def.klass = ObjectDef.Klass.INTERACTIVE
	def.scene = scene
	def.footprint.assign([Vector2i.ZERO])
	return def


static func _enemy_cells(result) -> Array[Vector2i]:
	var avoid: Array[Vector2i] = []
	for e in result.enemy_spawns:
		avoid.append(e["pos"])
	return avoid


static func _interactive_cells(objs: ObjectPlan) -> Dictionary:
	var interactive := {}
	for pl in objs.placements:
		if pl.def.klass == ObjectDef.Klass.INTERACTIVE:
			for j in pl.cells:
				interactive[j] = true
			interactive[pl.cell.y * objs.width + pl.cell.x] = true
	return interactive


## `count` obiektów `def` na otwartej podłodze pokoju (osiągalnej — w `dist`), od środka, ≥ 2 kratki od `avoid`
## (dopisuje postawione); zajętość kratek ustawiona. Zwraca postawione (jeszcze nie w planie — _commit).
static func _place_in_room(result, room: Rect2i, def: ObjectDef, count: int, avoid: Array[Vector2i], walk: Callable,
		dist: Dictionary, interactive: Dictionary) -> Array[ObjectPlacement]:
	var objs: ObjectPlan = result.objects
	var center := room.get_center()
	var cands: Array[Vector2i] = []
	for c: Vector2i in dist:
		if room.grow(1).has_point(c) and _open(result, objs, c, walk, interactive):
			cands.append(c)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - center).length_squared()
		var db := (b - center).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var added: Array[ObjectPlacement] = []
	for c in cands:
		if added.size() >= count:
			break
		var near := false
		for q in avoid:
			if maxi(absi(q.x - c.x), absi(q.y - c.y)) < 2:
				near = true
				break
		if near:
			continue
		var pl := ObjectPlacement.new()
		pl.def = def
		pl.cell = c
		var i := c.y * objs.width + c.x
		pl.cells = PackedInt32Array([i])
		objs.occupancy[i] |= ObjectPlan.USED | ObjectPlan.SOLID
		interactive[i] = true
		added.append(pl)
		avoid.append(c)
	return added


## Dopisuje postawione obiekty do planu (statystyki) i zdejmuje obiekty bez kolizji z ich kratek i sąsiednich.
static func _commit(objs: ObjectPlan, added: Array[ObjectPlacement]) -> void:
	var clear := {}
	for pl in added:
		objs.stats[pl.def.id] = int(objs.stats.get(pl.def.id, 0)) + 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				clear[(pl.cell.y + dy) * objs.width + pl.cell.x + dx] = true
	var kept: Array[ObjectPlacement] = []
	for pl in objs.placements:
		var hit := false
		if pl.def.klass != ObjectDef.Klass.INTERACTIVE:
			hit = clear.has(pl.cell.y * objs.width + pl.cell.x)
			for j in pl.cells:
				hit = hit or clear.has(j)
		if hit:
			objs.stats[pl.def.id] = int(objs.stats.get(pl.def.id, 1)) - 1
			for j in pl.cells:
				objs.occupancy[j] &= ~(ObjectPlan.USED | ObjectPlan.SOLID)
		else:
			kept.append(pl)
	kept.append_array(added)
	objs.placements = kept


## Kratki najkrótszej drogi po podłodze `from` -> `to` (BFS); pusta, gdy brak drogi.
static func _path_cells(from: Vector2i, to: Vector2i, walk: Callable) -> Array[Vector2i]:
	var parent := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size() and not parent.has(to):
		var p := queue[head]
		head += 1
		for d in DIRS4:
			var n := p + d
			if not parent.has(n) and walk.call(n):
				parent[n] = p
				queue.append(n)
	var path: Array[Vector2i] = []
	if not parent.has(to):
		return path
	path.append(to)
	while path.back() != from:
		path.append(parent[path.back()])
	return path


## Odległość po podłodze od najbliższej z kratek `sources` (BFS wieloźródłowy).
static func _multi_dist(sources: Array[Vector2i], walk: Callable) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for s in sources:
		dist[s] = 0
		queue.append(s)
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d in DIRS4:
			var n := p + d
			if not dist.has(n) and walk.call(n):
				dist[n] = int(dist[p]) + 1
				queue.append(n)
	return dist


## Kratka strażnika: na najkrótszej drodze wejście -> skarb ostatnia kratka przed wejściem do pokoju skarbu (prostokąt + 1),
## cofnięta o GUARD_BACK; poza strefą portali. Droga cała w pokoju — jej środek. (-1, -1) = brak drogi.
static func _guard_cell(result, room: Rect2i, goal: Vector2i, walk: Callable) -> Vector2i:
	var parent := {result.entrance_pos: result.entrance_pos}
	var queue: Array[Vector2i] = [result.entrance_pos]
	var head := 0
	while head < queue.size() and not parent.has(goal):
		var p := queue[head]
		head += 1
		for d in DIRS4:
			var n := p + d
			if not parent.has(n) and walk.call(n):
				parent[n] = p
				queue.append(n)
	if not parent.has(goal):
		return Vector2i(-1, -1)
	var path: Array[Vector2i] = [goal]   # od skarbu do wejścia
	while path.back() != result.entrance_pos:
		path.append(parent[path.back()])
	var area := room.grow(1)
	var out := -1
	for i in range(path.size()):
		if not area.has_point(path[i]):
			out = i
			break
	var k := mini(out + GUARD_BACK, path.size() - 1) if out >= 0 else path.size() / 2
	var objs: ObjectPlan = result.objects
	while k > 0 and (result.portal_zone.has(path[k]) or objs.occupancy[path[k].y * objs.width + path[k].x] & ObjectPlan.SOLID):
		k -= 1
	return path[k]


## Kratka i jej 8 sąsiadów chodliwi, bez stref portali, kratka bez FORBID / obiektu z kolizją / obiektu interaktywnego.
static func _open(result, objs: ObjectPlan, c: Vector2i, walk: Callable, interactive: Dictionary) -> bool:
	if c.x < 1 or c.y < 1 or c.x >= objs.width - 1 or c.y >= objs.height - 1:
		return false
	var i := c.y * objs.width + c.x
	if objs.occupancy[i] & (ObjectPlan.FORBID | ObjectPlan.SOLID) or interactive.has(i):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := c + Vector2i(dx, dy)
			if not walk.call(q) or result.portal_zone.has(q):
				return false
	return true


## Odległość po podłodze (BFS, 4-sąsiedzi) od `from`.
static func _floor_dist(from: Vector2i, walk: Callable) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d in DIRS4:
			var n := p + d
			if not dist.has(n) and walk.call(n):
				dist[n] = int(dist[p]) + 1
				queue.append(n)
	return dist
