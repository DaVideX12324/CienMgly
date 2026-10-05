class_name PortalGenerator
extends RefCounted


## Strefa portalu w środku pokoju, bez tunelu i wnęki (flaga entrance_mode = "center").
## Kwadrat (2·PORTAL_RADIUS+1)² wokół środka pokoju zamieniony na podłogę. Ten sam format wyniku co
## carve_portal_alcove; "edge" = -1 (wyjście może wtedy wybrać dowolną krawędź).
const PORTAL_RADIUS := 2
const CENTER_ENTRANCE_MIN_SIDE := 10


## Wybiera pokoje wejścia i wyjścia, rzeźbi portale i rejestruje je w ctx i result.
## Zwraca Dictionary {"entrance_room_idx": int, "exit_room_idx": int}.
static func place_portals_in_rooms(
	ctx: GenerationContext,
	result: MapGeneratorBase.GenerationResult,
	rooms: Array[Rect2i],
	flags: GenerationFlags,
	corridor_width: int
) -> Dictionary:
	var entrance_room_idx := 0
	var exit_room_idx: int = maxi(0, rooms.size() - 1)
	if rooms.is_empty():
		return {"entrance_room_idx": 0, "exit_room_idx": 0}

	var center_entrance := flags.entrance_mode == "center"
	if center_entrance:
		# Wejście w pokoju najbliżej środka mapy (spośród pokoi o boku >= CENTER_ENTRANCE_MIN_SIDE, gdy
		# są — mniejsze wyglądają jak kawałek korytarza), wyjście w pokoju najdalszym od niego.
		var map_center := Vector2(ctx.width, ctx.height) * 0.5
		var best := INF
		for pass_i in range(2):
			for i in range(rooms.size()):
				if pass_i == 0 and mini(rooms[i].size.x, rooms[i].size.y) < CENTER_ENTRANCE_MIN_SIDE:
					continue
				var d := Vector2(rooms[i].get_center()).distance_squared_to(map_center)
				if d < best:
					best = d
					entrance_room_idx = i
			if best < INF:
				break
		var far := -1.0
		for i in range(rooms.size()):
			var d := Vector2(rooms[i].get_center()).distance_squared_to(Vector2(rooms[entrance_room_idx].get_center()))
			if i != entrance_room_idx and d > far:
				far = d
				exit_room_idx = i
	elif rooms.size() >= 2:
		var max_dist := 0.0
		for i in range(rooms.size()):
			for j in range(i + 1, rooms.size()):
				var d := Vector2(rooms[i].get_center()).distance_squared_to(Vector2(rooms[j].get_center()))
				if d > max_dist:
					max_dist = d
					entrance_room_idx = i
					exit_room_idx = j

	var entrance_room := rooms[entrance_room_idx]
	var entrance_data: Dictionary = carve_portal_in_room(ctx, entrance_room) if center_entrance \
		else carve_portal_alcove(ctx, entrance_room)
	ctx.entrance_pos = entrance_data["center"] as Vector2i
	result.entrance_pos = ctx.entrance_pos
	result.player_spawn = ctx.entrance_pos
	result.entrance_zone = entrance_data["cells"] as Array[Vector2i]
	for p in result.entrance_zone:
		ctx.grid[p] = CellType.ENTRANCE
		ctx.portal_zone[p] = true

	var exit_room := rooms[exit_room_idx]
	var exit_data: Dictionary = carve_portal_alcove(ctx, exit_room, int(entrance_data["edge"]))
	ctx.exit_pos = exit_data["center"] as Vector2i
	result.exit_pos = ctx.exit_pos
	result.exit_zone = exit_data["cells"] as Array[Vector2i]
	for p in result.exit_zone:
		ctx.grid[p] = CellType.EXIT
		ctx.portal_zone[p] = true

	# Dodatkowa gwarancja spójności po wycięciu portali
	ConnectivityRepair.repair(ctx, corridor_width)

	return {"entrance_room_idx": entrance_room_idx, "exit_room_idx": exit_room_idx}


static func carve_portal_in_room(ctx: GenerationContext, room: Rect2i) -> Dictionary:
	const MAP_BORDER := 2
	var center := room.get_center()
	var cells: Array[Vector2i] = []
	for dy in range(-PORTAL_RADIUS, PORTAL_RADIUS + 1):
		for dx in range(-PORTAL_RADIUS, PORTAL_RADIUS + 1):
			var p := center + Vector2i(dx, dy)
			if p.x >= MAP_BORDER and p.x < ctx.width - MAP_BORDER and p.y >= MAP_BORDER and p.y < ctx.height - MAP_BORDER:
				ctx.grid[p] = CellType.FLOOR
				cells.append(p)
	return {"center": center, "edge": -1, "cells": cells}


## Wyrzeźbi dedykowany tunel portalowy z komory ku krawędzi mapy, zakończony niszą wejściową/wyjściową.
## Zwraca Dictionary {"center": Vector2i, "edge": int (0=N, 1=E, 2=S, 3=W), "cells": Array[Vector2i]}
static func carve_portal_alcove(ctx: GenerationContext, room: Rect2i, avoid_edge: int = -1) -> Dictionary:
	const ALCOVE_RADIUS := 2
	const MAP_BORDER := 2
	const MIN_TUNNEL_LENGTH := 5
	const ALCOVE_CENTER_MARGIN := ALCOVE_RADIUS + MAP_BORDER

	var grid := ctx.grid
	var map_w := ctx.width
	var map_h := ctx.height
	var rng := ctx.rng

	var center := room.get_center()
	var edge_dists: Array[Dictionary] = [
		{"edge": 0, "dist": center.y},
		{"edge": 1, "dist": map_w - 1 - center.x},
		{"edge": 2, "dist": map_h - 1 - center.y},
		{"edge": 3, "dist": center.x},
	]
	edge_dists.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dist"]) < int(b["dist"]))

	var chosen_edge := -1
	var chosen_dir := Vector2i.ZERO
	var chosen_start := Vector2i.ZERO
	var chosen_perp := Vector2i.ZERO
	var chosen_max_length := 0
	var chosen_room_bridge_steps := 0

	for edge_data in edge_dists:
		var edge := int(edge_data["edge"])
		if edge == avoid_edge:
			continue

		var dir := Vector2i.ZERO
		var tunnel_start := Vector2i.ZERO
		var perp := Vector2i.ZERO
		var max_length := 0

		var bridge_steps := 0
		match edge:
			0:
				dir = Vector2i(0, -1)
				tunnel_start = Vector2i(center.x, room.position.y - 1)
				perp = Vector2i(1, 0)
				max_length = tunnel_start.y - ALCOVE_CENTER_MARGIN
				bridge_steps = center.y - tunnel_start.y
			1:
				dir = Vector2i(1, 0)
				tunnel_start = Vector2i(room.position.x + room.size.x, center.y)
				perp = Vector2i(0, 1)
				max_length = map_w - 1 - ALCOVE_CENTER_MARGIN - tunnel_start.x
				bridge_steps = tunnel_start.x - center.x
			2:
				dir = Vector2i(0, 1)
				tunnel_start = Vector2i(center.x, room.position.y + room.size.y)
				perp = Vector2i(1, 0)
				max_length = map_h - 1 - ALCOVE_CENTER_MARGIN - tunnel_start.y
				bridge_steps = tunnel_start.y - center.y
			3:
				dir = Vector2i(-1, 0)
				tunnel_start = Vector2i(room.position.x - 1, center.y)
				perp = Vector2i(0, 1)
				max_length = tunnel_start.x - ALCOVE_CENTER_MARGIN
				bridge_steps = center.x - tunnel_start.x

		if max_length >= MIN_TUNNEL_LENGTH:
			chosen_edge = edge
			chosen_dir = dir
			chosen_start = tunnel_start
			chosen_perp = perp
			chosen_max_length = max_length
			chosen_room_bridge_steps = bridge_steps
			break

	if chosen_edge == -1:
		push_error("PortalGenerator: no safe edge for portal alcove.")
		return {"center": center, "edge": -1, "cells": []}

	# 1. Ciągły most od centrum pokoju do punktu startowego tunelu
	var bridge_pos := center
	for i in range(chosen_room_bridge_steps):
		for w in range(-ALCOVE_RADIUS, ALCOVE_RADIUS + 1):
			var p := bridge_pos + chosen_perp * w
			if p.x >= MAP_BORDER and p.x < map_w - MAP_BORDER and p.y >= MAP_BORDER and p.y < map_h - MAP_BORDER:
				grid[p] = CellType.FLOOR
		bridge_pos += chosen_dir

	# 2. Tunel portalowy ku krawędzi mapy
	var tunnel_length := mini(rng.randi_range(5, 7), chosen_max_length)
	var current := chosen_start
	for i in range(tunnel_length):
		for w in range(-ALCOVE_RADIUS, ALCOVE_RADIUS + 1):
			var p := current + chosen_perp * w
			if p.x >= MAP_BORDER and p.x < map_w - MAP_BORDER and p.y >= MAP_BORDER and p.y < map_h - MAP_BORDER:
				grid[p] = CellType.FLOOR
		current += chosen_dir

	var alcove_cells: Array[Vector2i] = []
	for dy in range(-ALCOVE_RADIUS, ALCOVE_RADIUS + 1):
		for dx in range(-ALCOVE_RADIUS, ALCOVE_RADIUS + 1):
			var p := current + Vector2i(dx, dy)
			if p.x >= MAP_BORDER and p.x < map_w - MAP_BORDER and p.y >= MAP_BORDER and p.y < map_h - MAP_BORDER:
				grid[p] = CellType.FLOOR
				if dy >= -ALCOVE_RADIUS + 1:
					alcove_cells.append(p)

	return {"center": current, "edge": chosen_edge, "cells": alcove_cells}
