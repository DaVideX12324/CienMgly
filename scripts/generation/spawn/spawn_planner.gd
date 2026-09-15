class_name SpawnPlanner
extends RefCounted

const MapGeneratorBase = preload("res://modules/quiz_rpg/scripts/generation/map_generator_base.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")

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
		else:
			result.chest_spawns.append(center)
