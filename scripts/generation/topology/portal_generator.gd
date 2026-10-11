class_name PortalGenerator
extends RefCounted


## Strefa portalu w środku pokoju, bez tunelu i wnęki (flaga entrance_mode = "center").
## Kwadrat (2·PORTAL_RADIUS+1)² wokół środka pokoju zamieniony na podłogę. Ten sam format wyniku co
## carve_portal_alcove; "edge" = -1 (wyjście może wtedy wybrać dowolną krawędź).
const PORTAL_RADIUS := 2
const CENTER_ENTRANCE_MIN_SIDE := 10
## Schody wnęki (alcove_stairs, decyzja usera 2026-10-11): od linii ściany (tam, gdzie stałaby podstawa lica / ściana
## za wnęką) tyle kratek w głąb, za nimi void.
const ALCOVE_STAIRS_DEPTH := 4


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
	_apply_portal(ctx, result, entrance_data, true)

	var exit_room := rooms[exit_room_idx]
	var exit_data: Dictionary = carve_portal_at_wall(ctx, exit_room, wall_style) if wall_style != "" \
		else carve_portal_alcove(ctx, exit_room, int(entrance_data["edge"]))
	register_wall_portal(result, exit_data, flags)
	_apply_portal(ctx, result, exit_data, false)

	# Dodatkowa gwarancja spójności po wycięciu portali
	ConnectivityRepair.repair(ctx, corridor_width)

	# Schody wnęk dopiero po naprawie spójności: jej korytarze potrafiły wejść w pas ściany za schodami (void stykał się
	# z nową salą); głębokość schodów liczona na siatce po naprawie.
	if flags.portal_style == "alcove_stairs":
		register_alcove_stairs(ctx, result, entrance_data, true)
		_apply_portal(ctx, result, entrance_data, true)
		register_alcove_stairs(ctx, result, exit_data, false)
		_apply_portal(ctx, result, exit_data, false)

	return {"entrance_room_idx": entrance_room_idx, "exit_room_idx": exit_room_idx}


## Punkt i strefa portalu z danych wnęki / ściany (po register_alcove_stairs — szczyt schodów i strefa ze schodami).
static func _apply_portal(ctx: GenerationContext, result: MapGeneratorBase.GenerationResult, data: Dictionary, entrance: bool) -> void:
	var cells := data["cells"] as Array[Vector2i]
	var kind := CellType.ENTRANCE if entrance else CellType.EXIT
	if entrance:
		ctx.entrance_pos = data["center"] as Vector2i
		result.entrance_pos = ctx.entrance_pos
		result.player_spawn = ctx.entrance_pos
		result.entrance_zone = cells
	else:
		ctx.exit_pos = data["center"] as Vector2i
		result.exit_pos = ctx.exit_pos
		result.exit_zone = cells
	for q in cells:
		ctx.grid[q] = kind
		ctx.portal_zone[q] = true


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


## Schody we wnęce portalu (portal_style "alcove_stairs", wnęka carve_portal_alcove 5 × 5): od pierwszej warstwy ściany za
## wnęką (linia podstawy lica) ALCOVE_STAIRS_DEPTH kratek w głąb, na końcu void bez ściany (końcowy stopień — ręcznie albo
## nakładką, decyzja usera). Wnęka stoi dość daleko od krawędzi mapy (carve_portal_alcove), gdy ściany mniej — krócej.
## Kratki schodów -> podłoga i strefa portalu (lico nad strefą nie powstaje, kafle ścian na niej wymazane), przejście na
## szczycie schodów (data.center), ostatni rząd przy krawędzi mapy -> result.portal_void (PortalClearPlacer wymazuje
## kafle ścian). N / S: 5 kratek szerokości, E / W: 4 rzędy (o 1 więcej w dół, moduł schodów bocznych).
static func register_alcove_stairs(ctx: GenerationContext, result: MapGeneratorBase.GenerationResult, data: Dictionary, entrance: bool) -> void:
	var c: Vector2i = data.get("center", Vector2i.ZERO)
	var edge := int(data.get("edge", -1))
	if edge < 0 or edge > 3:
		return
	var d: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][edge]
	var side := Vector2i(absi(d.y), absi(d.x))          # w poprzek schodów
	var half := 2 if d.x == 0 else 1                     # N / S: 5 kratek podłogi, E / W: 3 rzędy podłogi
	# Ile warstw ściany za wnęką zajmują schody (najwyżej ALCOVE_STAIRS_DEPTH); zawsze >= 1 warstwa ściany zostaje przed
	# inną podłogą (void na końcu).
	var max_depth := ALCOVE_STAIRS_DEPTH
	var end := c + d * 2                                 # ostatnia kratka wnęki w kierunku krawędzi
	var layer_wall := func(k: int) -> bool:
		for t in range(-half, half + 1):
			var q: Vector2i = end + d * k + side * t
			if q.x < 0 or q.y < 0 or q.x >= ctx.width or q.y >= ctx.height or GridUtils.is_walkable(ctx.grid, q):
				return false
		return true
	# Za voidem (warstwa depth + 1) dwie warstwy ochronne: ściana albo koniec mapy — void nie styka się z podłogą innej
	# sali (wcześniej sprawdzane tylko stopień + void); pas void + 2 ma grubość 3, więc późniejsze przejścia ścian
	# (cienkie ściany, 3H) go nie przebijają.
	var layer_shield := func(k: int) -> bool:
		for t in range(-half, half + 1):
			var q: Vector2i = end + d * k + side * t
			if q.x >= 0 and q.y >= 0 and q.x < ctx.width and q.y < ctx.height and GridUtils.is_walkable(ctx.grid, q):
				return false
		return true
	var depth := 0
	while depth < max_depth and layer_wall.call(depth + 1) and layer_wall.call(depth + 2) and layer_shield.call(depth + 3) \
			and layer_shield.call(depth + 4):
		depth += 1
	# schody: od pierwszej warstwy ściany (linia podstawy lica) do warstwy `depth`; void: warstwa depth + 1. Bez ściany
	# za wnęką (depth 0) — jak dawniej od środka wnęki.
	# W E / W grafika schodów (rect) sięga o 1 kratkę w dół (t=2) pod dolną ścianę (chowa się pod nią, bez poszerzania ścian).
	var a_cell: Vector2i = (end + d if depth >= 1 else c) - side * half
	var b_cell: Vector2i = end + d * depth + side * (half if d.x == 0 else 2)
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
	# Podłogę drążymy tylko w obszarze użytkowym (-half..half) — dolna ściana w E/W (t=2) nie jest poszerzana.
	for k in range(1 if depth >= 1 else 0, depth + 1):
		for t in range(-half, half + 1):
			var q: Vector2i = (end if depth >= 1 else c) + d * k + side * t
			ctx.grid[q] = CellType.FLOOR
	# Strefa portalu: kratki schodów poza tymi tuż pod ścianą (jak górny rząd wnęki) — tam stopa lica / krawędzi dołu.
	var is_void := {}
	for q in void_cells:
		is_void[q] = true
	for k in range(1 if depth >= 1 else 0, depth + 1):
		for t in range(-half, half + 1):
			var q: Vector2i = (end if depth >= 1 else c) + d * k + side * t
			var up := q + Vector2i(0, -1)
			if have.has(q) or (q != top and not is_void.has(up) and not GridUtils.is_walkable(ctx.grid, up)):
				continue
			cells.append(q)
			have[q] = true
	# Ostatni rząd wnęki (pod linią ściany) wnęka pomija (stopa lica) — nad nim są teraz schody, więc należy do strefy:
	# łączy wnękę ze schodami w jedną strefę portalu (płaskowyże trzymają ją na jednej wysokości).
	if depth >= 1:
		for t in range(-half, half + 1):
			var q: Vector2i = end + side * t
			if not have.has(q) and GridUtils.is_walkable(ctx.grid, q):
				cells.append(q)
				have[q] = true
	data["cells"] = cells
	data["center"] = top
	result.portal_stairs.append({"rect": rect, "dir": dir, "entrance": entrance})
	result.portal_void.append_array(void_cells)
	ctx.portal_void.append_array(void_cells)


## Wyrzeźbi dedykowany tunel portalowy z komory ku krawędzi mapy, zakończony niszą wejściową/wyjściową.
## Długość tunelu wnęki (alcove_stairs) i liczba warstw litej ściany (albo końca mapy) za wnęką (5 × 5, środek =
## start + dir * długość), najwyżej ALCOVE_STAIRS_DEPTH schodów + void + 2 warstwy ochronne. Najpierw losowa 5–7, potem
## pozostałe od najdłuższej do 3; pierwsza z pełnym zapasem wygrywa, inaczej ta z największym. [długość, warstwy].
static func _stairs_tunnel_length(ctx: GenerationContext, start: Vector2i, dir: Vector2i, perp: Vector2i, max_length: int, rng: RandomNumberGenerator) -> Array:
	var need := ALCOVE_STAIRS_DEPTH + 3
	var first := mini(rng.randi_range(5, 7), max_length)
	var order: Array[int] = [first]
	for n in range(mini(7, max_length), 2, -1):
		if n != first:
			order.append(n)
	var best := [-1, -1]
	for n in order:
		var end := start + dir * n + dir * 2   # ostatni rząd wnęki w kierunku krawędzi
		var layers := 0
		for k in range(1, need + 1):
			var solid := true
			for w in range(-2, 3):
				var q: Vector2i = end + dir * k + perp * w
				if q.x >= 0 and q.y >= 0 and q.x < ctx.width and q.y < ctx.height and GridUtils.is_walkable(ctx.grid, q):
					solid = false
					break
			if not solid:
				break
			layers += 1
		if layers >= need:
			return [n, layers]
		if layers > int(best[1]):
			best = [n, layers]
	return best


## Zwraca Dictionary {"center": Vector2i, "edge": int (0=N, 1=E, 2=S, 3=W), "cells": Array[Vector2i]}
static func carve_portal_alcove(ctx: GenerationContext, room: Rect2i, avoid_edge: int = -1) -> Dictionary:
	const ALCOVE_RADIUS := 2
	const MAP_BORDER := 2
	const MIN_TUNNEL_LENGTH := 5
	# Środek wnęki od krawędzi mapy: promień + ramka; przy schodach wnęki dodatkowo miejsce na ALCOVE_STAIRS_DEPTH
	# warstw ściany i void za nimi.
	var alcove_center_margin := ALCOVE_RADIUS + MAP_BORDER
	if ctx.flags != null and ctx.flags.portal_style == "alcove_stairs":
		alcove_center_margin = maxi(alcove_center_margin, ALCOVE_RADIUS + ALCOVE_STAIRS_DEPTH + 1)

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
	var chosen_tunnel_length := -1  # alcove_stairs: długość z miejscem na schody za wnęką (-1 = losowa)
	var stairs_style := ctx.flags != null and ctx.flags.portal_style == "alcove_stairs"
	var fallback: Dictionary = {}   # krawędź z największym zapasem ściany, gdy żadna nie ma miejsca na pełne schody

	# Runda 0: zwykłe zasady. Runda 1 (tylko schody wnęki, gdy żadna krawędź nie mieści choć 1 schodka + void + 2 warstw
	# ochronnych): także krawędź wejścia i krótszy tunel (od 3) — inaczej void schodów lądował na podłodze sali obok.
	for pass_i in range(2 if stairs_style else 1):
		if pass_i == 1 and (chosen_edge != -1 or int(fallback.get("layers", -1)) >= 4):
			break
		for edge_data in edge_dists:
			var edge := int(edge_data["edge"])
			if edge == avoid_edge and pass_i == 0:
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
					max_length = tunnel_start.y - alcove_center_margin
					bridge_steps = center.y - tunnel_start.y
				1:
					dir = Vector2i(1, 0)
					tunnel_start = Vector2i(room.position.x + room.size.x, center.y)
					perp = Vector2i(0, 1)
					max_length = map_w - 1 - alcove_center_margin - tunnel_start.x
					bridge_steps = tunnel_start.x - center.x
				2:
					dir = Vector2i(0, 1)
					tunnel_start = Vector2i(center.x, room.position.y + room.size.y)
					perp = Vector2i(1, 0)
					max_length = map_h - 1 - alcove_center_margin - tunnel_start.y
					bridge_steps = tunnel_start.y - center.y
				3:
					dir = Vector2i(-1, 0)
					tunnel_start = Vector2i(room.position.x - 1, center.y)
					perp = Vector2i(0, 1)
					max_length = tunnel_start.x - alcove_center_margin
					bridge_steps = center.x - tunnel_start.x

			if max_length >= (MIN_TUNNEL_LENGTH if pass_i == 0 else 3):
				var cand := {"edge": edge, "dir": dir, "start": tunnel_start, "perp": perp, "max": max_length, "bridge": bridge_steps}
				if stairs_style:
					var fit: Array = _stairs_tunnel_length(ctx, tunnel_start, dir, perp, max_length, rng)
					if int(fit[1]) < ALCOVE_STAIRS_DEPTH + 3:
						cand["len"] = int(fit[0])
						cand["layers"] = int(fit[1])
						if fallback.is_empty() or int(fit[1]) > int(fallback.get("layers", -1)):
							fallback = cand
						continue
					chosen_tunnel_length = int(fit[0])
				chosen_edge = edge
				chosen_dir = dir
				chosen_start = tunnel_start
				chosen_perp = perp
				chosen_max_length = max_length
				chosen_room_bridge_steps = bridge_steps
				break

	if chosen_edge == -1 and not fallback.is_empty():
		if int(fallback.get("layers", -1)) >= 4:   # co najmniej 1 schodek + void + 2 ochronne
			chosen_tunnel_length = int(fallback["len"])
		chosen_edge = int(fallback["edge"])
		chosen_dir = fallback["dir"]
		chosen_start = fallback["start"]
		chosen_perp = fallback["perp"]
		chosen_max_length = int(fallback["max"])
		chosen_room_bridge_steps = int(fallback["bridge"])
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
	var tunnel_length := chosen_tunnel_length if chosen_tunnel_length >= 0 else mini(rng.randi_range(5, 7), chosen_max_length)
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
