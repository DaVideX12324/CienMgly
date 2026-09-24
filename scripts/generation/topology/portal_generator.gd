class_name PortalGenerator
extends RefCounted


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
