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

	# Wrogowie i skrzynie w pokojach pośrednich
	for i in range(rooms.size()):
		if i == entrance_room_idx or i == exit_room_idx:
			continue
		var r := rooms[i]
		var center := r.get_center()
		if i % 2 == 1:
			var num_enemies := rng.randi_range(2, 4)
			for e in range(num_enemies):
				var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
				result.enemy_spawns.append({
					"pos": center + offset,
					"tier": rng.randi_range(1, 2)
				})
		elif not chests_by_objects:
			result.chest_spawns.append(center)

	var covered := {}
	if ctx.plateau != null and not ctx.plateau.is_empty():
		covered = ctx.plateau.blocked
	if result.objects != null:
		covered = covered.duplicate()
		covered.merge(result.objects.solid_cells())
	if not covered.is_empty():
		_nudge_off(ctx, result, covered)


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
