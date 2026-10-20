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
	var interactive := {}
	for pl in objs.placements:
		if pl.def.klass == ObjectDef.Klass.INTERACTIVE:
			for j in pl.cells:
				interactive[j] = true
			interactive[pl.cell.y * objs.width + pl.cell.x] = true
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
	var center := room.get_center()
	var cands: Array[Vector2i] = []
	for c: Vector2i in dist:
		if room.grow(1).has_point(c) and _open(result, objs, c, walk, interactive):
			cands.append(c)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - center).length_squared()
		var db := (b - center).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var avoid: Array[Vector2i] = []
	for e in result.enemy_spawns:
		avoid.append(e["pos"])
	var relic: bool = cfg.get("kind", "chest") == "relic"
	var def := ObjectDef.new()
	def.id = RELIC_DEF_ID if relic else CHEST_DEF_ID
	def.klass = ObjectDef.Klass.INTERACTIVE
	def.scene = QuizRpgPaths.path(RELIC_SCENE) if relic else "chest"
	def.footprint.assign([Vector2i.ZERO])
	var clear := {}   # idx kratek skrzyń i ich sąsiadów — bez obiektów bez kolizji
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
		added.append(pl)
		avoid.append(c)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				clear[(c.y + dy) * objs.width + c.x + dx] = true
	if added.is_empty():
		return
	objs.stats[def.id] = int(objs.stats.get(def.id, 0)) + added.size()
	var guard_tier := int(cfg.get("guard_tier", 0))
	if guard_tier > 0:
		var g := _guard_cell(result, room, added[0].cell, walk)
		if g.x >= 0:
			result.enemy_spawns.append({"pos": g, "tier": guard_tier})
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
