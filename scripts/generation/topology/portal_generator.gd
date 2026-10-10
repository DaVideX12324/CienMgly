class_name PortalGenerator
extends RefCounted


## Strefa portalu w środku pokoju, bez tunelu i wnęki (flaga entrance_mode = "center").
## Kwadrat (2·PORTAL_RADIUS+1)² wokół środka pokoju zamieniony na podłogę. Ten sam format wyniku co
## carve_portal_alcove; "edge" = -1 (wyjście może wtedy wybrać dowolną krawędź).
const PORTAL_RADIUS := 2
const CENTER_ENTRANCE_MIN_SIDE := 10
const ALCOVE_WALL_DEPTH_N := 3  # schody wnęki w ścianie północnej: lico + krawędź
const ALCOVE_WALL_DEPTH := 2    # S / E / W: krawędź ściany


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
	var wall_style := flags.portal_style if flags.portal_style in ["ladder", "stairs"] else ""
	var entrance_data: Dictionary
	if wall_style != "":
		entrance_data = carve_portal_at_wall(ctx, entrance_room, wall_style)
	else:
		entrance_data = carve_portal_in_room(ctx, entrance_room) if center_entrance else carve_portal_alcove(ctx, entrance_room)
	register_wall_portal(result, entrance_data, flags)
	if flags.portal_style == "alcove_stairs":
		register_alcove_stairs(ctx, result, entrance_data, true)
	ctx.entrance_pos = entrance_data["center"] as Vector2i
	result.entrance_pos = ctx.entrance_pos
	result.player_spawn = ctx.entrance_pos
	result.entrance_zone = entrance_data["cells"] as Array[Vector2i]
	for p in result.entrance_zone:
		ctx.grid[p] = CellType.ENTRANCE
		ctx.portal_zone[p] = true

	var exit_room := rooms[exit_room_idx]
	var exit_data: Dictionary = carve_portal_at_wall(ctx, exit_room, wall_style) if wall_style != "" \
		else carve_portal_alcove(ctx, exit_room, int(entrance_data["edge"]))
	register_wall_portal(result, exit_data, flags)
	if flags.portal_style == "alcove_stairs":
		register_alcove_stairs(ctx, result, exit_data, false)
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


## Przejście przy północnej ścianie pokoju (portal_style): kolumna najbliżej środka (przesunięcia 0, ±1, ±2, ±3), od środka
## pokoju w górę do ściany. "ladder": przejście = górna kratka podłogi pod ścianą (nad nią co najmniej 3 kratki ściany — lico
## pod drabinę), strefa = 3 × 2 kratki pod nią. "stairs": pas 3 kratek od rzędu pod ścianą (stopa lica jaskini) do środka
## pokoju zamieniony na podłogę = schody ("stairs": Rect2i, min. 2 rzędy), przejście na ich szczycie, strefa = schody + rząd pod
## nimi. Rząd tuż pod ścianą nigdy w strefie (lico nad strefą portalu nie powstaje). Brak miejsca — carve_portal_in_room.
static func carve_portal_at_wall(ctx: GenerationContext, room: Rect2i, style: String) -> Dictionary:
	const MAP_BORDER := 2
	var c := room.get_center()
	var grid := ctx.grid
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := c + Vector2i(dx, dy)
			if q.x >= MAP_BORDER and q.x < ctx.width - MAP_BORDER and q.y >= MAP_BORDER and q.y < ctx.height - MAP_BORDER:
				if not GridUtils.is_walkable(grid, q):
					grid[q] = CellType.FLOOR
	var stairs := style == "stairs"
	# W obrębie pokoju (z marginesem na stopę ściany), bez wody i blokad kanałów (woda to w siatce podłoga).
	var area := room.grow(1)
	var blocked := {}
	if ctx.canals != null and not ctx.canals.is_empty():
		blocked.merge(ctx.canals.water)
		blocked.merge(ctx.canals.blocked)
	for off in [0, -1, 1, -2, 2, -3, 3]:
		var x: int = c.x + off
		var ok_col := func(y: int) -> bool:
			for k in ([-1, 0, 1] if stairs else [0]):
				var q := Vector2i(x + k, y)
				if not GridUtils.is_walkable(grid, q) or not area.has_point(q) or blocked.has(q):
					return false
			return true
		if not ok_col.call(c.y):
			continue
		var top := c.y
		while top - 1 >= MAP_BORDER + 4 and ok_col.call(top - 1):
			top -= 1
		if GridUtils.is_walkable(grid, Vector2i(x, top - 1)):
			continue  # nad górną kratką nie ma ściany (przejście w ścianie) — inna kolumna
		var wall_ok := true
		for k in range(1, 4):
			if GridUtils.is_walkable(grid, Vector2i(x, top - k)):
				wall_ok = false
		if not wall_ok:
			continue
		# Rząd tuż pod ścianą (top) poza strefą: EdgeAnalyzer nie stawia lica nad strefą portalu (w jaskiniach stopa lica
		# leży właśnie na tym rzędzie).
		var portal := Vector2i(x, top)
		var cells: Array[Vector2i] = []
		var rect := Rect2i()
		if stairs:
			var bottom := maxi(c.y, top + 2)
			rect = Rect2i(x - 1, top + 1, 3, bottom - top)
			portal = Vector2i(x, top + 1)
			for y in range(rect.position.y, rect.end.y + 1):
				for xx in range(rect.position.x, rect.end.x):
					var q := Vector2i(xx, y)
					grid[q] = CellType.FLOOR
					cells.append(q)
		else:
			for y in range(top + 1, top + 3):
				for xx in range(x - 1, x + 2):
					var q := Vector2i(xx, y)
					if GridUtils.is_walkable(grid, q):
						cells.append(q)
		return {"center": portal, "edge": -1, "cells": cells, "stairs": rect, "style": style}
	return carve_portal_in_room(ctx, room)


## Zapisuje grafikę przejścia przy ścianie w wyniku: schody (portal_stairs) albo drabinę (portal_ladders, wysokość lica
## uzupełnia generator po ozdobach — domyślnie 3).
static func register_wall_portal(result: MapGeneratorBase.GenerationResult, data: Dictionary, flags: GenerationFlags) -> void:
	match String(data.get("style", "")):
		"stairs":
			var r: Rect2i = data.get("stairs", Rect2i())
			if r.size.y > 0:
				result.portal_stairs.append({"rect": r, "dir": "N"})
		"ladder":
			result.portal_ladders.append({"cell": data["center"], "height": 3})
			result.portal_scene = flags.portal_scene


## Schody we wnęce portalu (portal_style "alcove_stairs", wnęka carve_portal_alcove 5 × 5) jak wyjście w tutorialu: od
## połowy wnęki przez jej tylną ścianę aż do szczytu ściany (ALCOVE_WALL_DEPTH_N / ALCOVE_WALL_DEPTH warstw), na końcu void
## bez ściany (końcowy stopień — ręcznie albo nakładką, decyzja usera).
## Kratki schodów -> podłoga i strefa portalu (lico nad strefą nie powstaje, kafle ścian na niej wymazane), przejście na
## szczycie schodów (data.center), ostatni rząd przy krawędzi mapy -> result.portal_void (PortalClearPlacer wymazuje
## kafle ścian). N / S: 5 kratek szerokości, E / W: 3 rzędy (moduł schodów bocznych).
static func register_alcove_stairs(ctx: GenerationContext, result: MapGeneratorBase.GenerationResult, data: Dictionary, entrance: bool) -> void:
	var c: Vector2i = data.get("center", Vector2i.ZERO)
	var edge := int(data.get("edge", -1))
	if edge < 0 or edge > 3:
		return
	var d: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][edge]
	var side := Vector2i(absi(d.y), absi(d.x))          # w poprzek schodów
	var half := 2 if d.x == 0 else 1                     # N / S: 5 kratek szerokości, E / W: 3 rzędy
	# Ile warstw ściany za wnęką przebijają schody: do szczytu ściany (N: lico + krawędź), zawsze >= 1 warstwa ściany
	# zostaje przed inną podłogą (void na końcu).
	var max_depth := ALCOVE_WALL_DEPTH_N if edge == 0 else ALCOVE_WALL_DEPTH
	var end := c + d * 2                                 # ostatnia kratka wnęki w kierunku krawędzi
	var layer_wall := func(k: int) -> bool:
		for t in range(-half, half + 1):
			var q: Vector2i = end + d * k + side * t
			if q.x < 0 or q.y < 0 or q.x >= ctx.width or q.y >= ctx.height or GridUtils.is_walkable(ctx.grid, q):
				return false
		return true
	var depth := 0
	while depth < max_depth and layer_wall.call(depth + 1) and layer_wall.call(depth + 2):
		depth += 1
	# schody: od środka wnęki (połowa) do warstwy `depth` za nią; void: warstwa depth + 1
	var a_cell: Vector2i = c - side * half
	var b_cell: Vector2i = end + d * depth + side * half
	var rect := Rect2i(Vector2i(mini(a_cell.x, b_cell.x), mini(a_cell.y, b_cell.y)), (a_cell - b_cell).abs() + Vector2i.ONE)
	var top: Vector2i = end + d * depth
	var dir: String = ["N", "E", "S", "W"][edge]
	var void_cells: Array[Vector2i] = []
	for t in range(-half, half + 1):
		void_cells.append(end + d * (depth + 1) + side * t)
	var cells: Array[Vector2i] = data.get("cells", [] as Array[Vector2i])
	var have := {}
	for q in cells:
		have[q] = true
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			ctx.grid[Vector2i(x, y)] = CellType.FLOOR
	# Strefa portalu: kratki schodów poza tymi tuż pod ścianą (jak górny rząd wnęki) — tam stopa lica / krawędzi dołu.
	var is_void := {}
	for q in void_cells:
		is_void[q] = true
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var q := Vector2i(x, y)
			var up := q + Vector2i(0, -1)
			if have.has(q) or (q != top and not is_void.has(up) and not GridUtils.is_walkable(ctx.grid, up)):
				continue
			cells.append(q)
			have[q] = true
	data["cells"] = cells
	data["center"] = top
	result.portal_stairs.append({"rect": rect, "dir": dir, "entrance": entrance})
	result.portal_void.append_array(void_cells)
	ctx.portal_void.append_array(void_cells)


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
