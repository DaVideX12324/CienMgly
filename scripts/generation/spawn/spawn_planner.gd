class_name SpawnPlanner
extends RefCounted


const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func plan_spawns(ctx: GenerationContext, result: MapGeneratorBase.GenerationResult, entrance_room_idx: int, exit_room_idx: int) -> void:
	var rooms := ctx.rooms
	var rng := ctx.rng
	if rooms.is_empty():
		return

	var exit_room := rooms[exit_room_idx]

	# Boss w pokoju wyjściowym
	result.enemy_spawns.append({
		"pos": exit_room.get_center() + Vector2i(0, -2),
		"tier": 3
	})

	# Skrzynie stawia generator obiektów, gdy jego katalog je ma (INTERACTIVE ze sceną "chest").
	var chests_by_objects: bool = result.objects != null and result.objects.interactive_scenes.has("chest")

	var spread: Dictionary = ctx.flags.spawn_config if ctx.flags != null else {}

	# Wrogowie i skrzynie w pokojach pośrednich (wrogowie tylko w starym trybie — spread rozkłada ich po mapie)
	for i in range(rooms.size()):
		if i == entrance_room_idx or i == exit_room_idx:
			continue
		var r := rooms[i]
		var center := r.get_center()
		if i % 2 == 1 and spread.is_empty():
			var num_enemies := rng.randi_range(2, 4)
			for e in range(num_enemies):
				var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
				result.enemy_spawns.append({
					"pos": center + offset,
					"tier": rng.randi_range(1, 2)
				})
		elif i % 2 == 0 and not chests_by_objects:
			result.chest_spawns.append(center)

	var covered := {}
	if ctx.plateau != null and not ctx.plateau.is_empty():
		covered = ctx.plateau.blocked
	if result.objects != null:
		covered = covered.duplicate()
		covered.merge(result.objects.solid_cells())
	if result.canals != null and not result.canals.is_empty():
		covered = covered.duplicate()
		covered.merge(result.canals.blocked)
	if not spread.is_empty():
		_plan_spread(ctx, result, rooms[entrance_room_idx] if entrance_room_idx >= 0 else Rect2i(), exit_room, spread, covered)
	if not covered.is_empty():
		_nudge_off(ctx, result, covered)
	_separate(ctx, result, covered)


## Wrogowie rozproszeni po całej osiągalnej podłodze (korytarze, hale, pokoje), także zaraz za pokojem wejścia:
## liczba = per_1000 na 1000 kratek, punkty co najmniej `spacing` kratek od siebie (Chebyshev), w punkcie pojedynczy wróg
## albo z szansą group_chance grupka group_size (stoją obok siebie — w walce łączą się w jedną). Bez pokoju wejścia
## (+1), bez kratek bliżej wejścia niż entrance_clear (po ścieżce) i bez pokoju wyjścia (boss). Tier z odległości od
## wejścia: do tier2_from (część najdalszej odległości) 1, dalej 2, a z szansą tier3_chance za tier3_from 3.
## Osiągalność bez obiektów (kolce bram też są obiektem — za bramami też ma być kogo spotkać).
## Najpierw near_entrance punktów najbliżej wejścia (pierwsze korytarze za pokojem startowym), potem losowo.
## JSON "spawns": {"per_1000": 8, "spacing": 6, "entrance_clear": 7, "near_entrance": 2, "group_chance": 0.35,
##   "group_size": [2, 3], "tier2_from": 0.35, "tier3_from": 0.7, "tier3_chance": 0.15}
static func _plan_spread(ctx: GenerationContext, result: MapGeneratorBase.GenerationResult, entrance_room: Rect2i,
		exit_room: Rect2i, cfg: Dictionary, covered: Dictionary) -> void:
	var blocked := {}
	if ctx.plateau != null and not ctx.plateau.is_empty():
		blocked.merge(ctx.plateau.blocked)
	if result.canals != null and not result.canals.is_empty():
		blocked.merge(result.canals.blocked)
	# odległość po podłodze od wejścia
	var dist := {ctx.entrance_pos: 0}
	var queue: Array[Vector2i] = [ctx.entrance_pos]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d in DIRS4:
			var n := p + d
			if not dist.has(n) and GridUtils.is_walkable(ctx.grid, n) and not blocked.has(n):
				dist[n] = int(dist[p]) + 1
				queue.append(n)
	var max_d := 1
	for p in queue:
		max_d = maxi(max_d, int(dist[p]))
	var clear := int(cfg.get("entrance_clear", 7))
	var no_room := entrance_room.grow(1)
	var stairs: Dictionary = result.canals.stair_cells if result.canals != null and "stair_cells" in result.canals else {}
	var cands: Array[Vector2i] = []
	for p in queue:
		if int(dist[p]) < clear or no_room.has_point(p) or exit_room.has_point(p) or covered.has(p) \
				or ctx.portal_zone.has(p) or stairs.has(p):
			continue
		cands.append(p)
	cands.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "spawn_spread"])
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t := cands[i]
		cands[i] = cands[j]
		cands[j] = t
	# Najpierw near_entrance punktów najbliżej wejścia (po ścieżce) — pierwsze korytarze za pokojem startowym.
	var first: Array[Vector2i] = cands.duplicate()
	first.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(dist[a]) < int(dist[b]) or (int(dist[a]) == int(dist[b]) and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var lead: Array[Vector2i] = []
	for p in first:
		if lead.size() >= int(cfg.get("near_entrance", 2)):
			break
		var close := false
		for q in lead:
			if maxi(absi(q.x - p.x), absi(q.y - p.y)) < int(cfg.get("spacing", 7)):
				close = true
				break
		if not close:
			lead.append(p)
	cands = lead + cands
	var target := int(round(cands.size() * float(cfg.get("per_1000", 6.0)) / 1000.0))
	var spacing := int(cfg.get("spacing", 7))
	var gs: Array = cfg.get("group_size", [2, 3])
	var picked: Array[Vector2i] = []
	var taken := covered.duplicate()
	var placed := 0
	for p in cands:
		if placed >= target:
			break
		var near := false
		for q in picked:
			if maxi(absi(q.x - p.x), absi(q.y - p.y)) < spacing:
				near = true
				break
		if near:
			continue
		picked.append(p)
		var frac := float(dist[p]) / float(max_d)
		var tier := 1 if frac < float(cfg.get("tier2_from", 0.35)) else 2
		if frac >= float(cfg.get("tier3_from", 0.7)) and rng.randf() < float(cfg.get("tier3_chance", 0.15)):
			tier = 3
		var n := 1
		if rng.randf() < float(cfg.get("group_chance", 0.35)):
			n = rng.randi_range(int(gs[0]), int(gs[1]))
		var cell := p
		for k in n:
			result.enemy_spawns.append({"pos": cell, "tier": tier})
			taken[cell] = true
			placed += 1
			cell = _nearest_free(ctx, cell, taken)


## Każdy wróg i każda skrzynia na własnej kratce. Dwa ciała w tym samym punkcie nie mają kierunku
## rozsunięcia — fizyka wypycha je w jedną stronę (w górę) przez ściany aż do voidu. Duplikat idzie na
## najbliższą wolną podłogę (bez dodatkowych losowań — spawny bez konfliktu zostają na miejscu).
static func _separate(ctx: GenerationContext, result: MapGeneratorBase.GenerationResult, covered: Dictionary) -> void:
	var taken := covered.duplicate()
	var used := {}
	for e in result.enemy_spawns:
		if used.has(e["pos"]):
			e["pos"] = _nearest_free(ctx, e["pos"], taken)
		used[e["pos"]] = true
		taken[e["pos"]] = true
	for i in range(result.chest_spawns.size()):
		if used.has(result.chest_spawns[i]):
			result.chest_spawns[i] = _nearest_free(ctx, result.chest_spawns[i], taken)
		used[result.chest_spawns[i]] = true
		taken[result.chest_spawns[i]] = true


## Spawn na barierze płaskowyżu (rim, bok, lico, stopa) albo na przeszkodzie z generatora obiektów
## -> najbliższa wolna podłoga (BFS). Góra płaskowyżu jest dozwolona (osiągalna schodami).
static func _nudge_off(ctx: GenerationContext, result: MapGeneratorBase.GenerationResult, covered: Dictionary) -> void:

	for e in result.enemy_spawns:
		if covered.has(e["pos"]):
			e["pos"] = _nearest_free(ctx, e["pos"], covered)
	for i in range(result.chest_spawns.size()):
		if covered.has(result.chest_spawns[i]):
			result.chest_spawns[i] = _nearest_free(ctx, result.chest_spawns[i], covered)


static func _nearest_free(ctx: GenerationContext, start: Vector2i, covered: Dictionary) -> Vector2i:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		if not covered.has(p) and not ctx.portal_zone.has(p) and GridUtils.is_walkable(ctx.grid, p):
			return p
		for d in DIRS4:
			var n := p + d
			if not seen.has(n) and GridUtils.in_bounds(n, ctx.width, ctx.height):
				seen[n] = true
				queue.append(n)
	return start
