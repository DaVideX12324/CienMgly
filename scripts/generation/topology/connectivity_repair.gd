class_name ConnectivityRepair
extends RefCounted

const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const OrganicCorridorCarver = preload("res://modules/quiz_rpg/scripts/generation/topology/organic_corridor_carver.gd")

static func repair(ctx: GenerationContext, corridor_width: int) -> void:
	var rooms := ctx.rooms
	if rooms.size() < 2:
		return

	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height
	var carver := OrganicCorridorCarver.new()

	var reachable := GridUtils.get_reachable_cells(grid, rooms[0].get_center(), width, height)
	for room in rooms:
		var target := room.get_center()
		if reachable.has(target):
			continue

		var source := Vector2i.ZERO
		var best_distance := INF
		for connected_room in rooms:
			var candidate := connected_room.get_center()
			if not reachable.has(candidate):
				continue
			var distance := Vector2(candidate).distance_squared_to(Vector2(target))
			if distance < best_distance:
				best_distance = distance
				source = candidate

		if best_distance == INF:
			push_error("ConnectivityRepair: missing reachable room while repairing connectivity.")
			return

		carver.carve(ctx, source, target, maxi(corridor_width, 3))
		reachable = GridUtils.get_reachable_cells(grid, rooms[0].get_center(), width, height)

	# Sprawdzenie i naprawa osiągalności punktów wejścia i wyjścia (jeśli wyznaczone)
	var special_targets: Array[Vector2i] = []
	if ctx.entrance_pos != Vector2i.ZERO:
		special_targets.append(ctx.entrance_pos)
	if ctx.exit_pos != Vector2i.ZERO:
		special_targets.append(ctx.exit_pos)

	for target in special_targets:
		if reachable.has(target):
			continue

		var source := Vector2i.ZERO
		var best_distance := INF
		for connected_room in rooms:
			var candidate := connected_room.get_center()
			if not reachable.has(candidate):
				continue
			var distance := Vector2(candidate).distance_squared_to(Vector2(target))
			if distance < best_distance:
				best_distance = distance
				source = candidate

		if best_distance != INF:
			carver.carve(ctx, source, target, maxi(corridor_width, 3))
			reachable = GridUtils.get_reachable_cells(grid, rooms[0].get_center(), width, height)
