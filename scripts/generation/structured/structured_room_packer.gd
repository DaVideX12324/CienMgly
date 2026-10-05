class_name StructuredRoomPacker
extends RefCounted

## Pakowanie pomieszczeń, korytarzy, kładek i pętli dla generatora structured.
## Implementuje etapy 4, 5, 5a, 5b, 6, 7 z proto_layout11.py:
## - Pomieszczenia wolnostojące w oddaleniu od sieci;
## - Korytarze A* łączące pokoje z siecią liniową ze ścianami od obcej podłogi;
## - Pętle między salami (pokój A <-> pokój B);
## - Pętle kompleksów (korytarz z kompleksu do dalekiej części kompleksu);
## - Pokoiki doklejane do długich korytarzy;
## - Kładki o długości 6 z gwarancją posadowienia obu końców na podłodze FLOOR.

const LinearFeatureLayout = preload("core/linear_feature_layout.gd")
const StructuredReservations = preload("structured_reservations.gd")
const StructuredPathfinder = preload("structured_pathfinder.gd")
const MapGeneratorBaseScript = preload("../map_generator_base.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func pack_rooms_and_corridors(
	ctx: GenerationContext,
	result: MapGeneratorBase.GenerationResult,
	layout: LinearFeatureLayout,
	reservations: StructuredReservations,
	zoning_data: Dictionary,
	corridor_width: int = 3
) -> Array[Rect2i]:
	var width := ctx.width
	var height := ctx.height
	var rng := ctx.rng
	var grid := ctx.grid
	var water := layout.cells
	var lanes := layout.lanes
	var bridges := layout.crossings
	var bridge_cells := layout.crossing_cells
	var complexes := layout.complexes
	var dry := layout.dry
	var service := layout.service

	var cfg_struct: Dictionary = ctx.flags.structured_config if ctx.flags != null else {}
	var wall_th_h: int = int(cfg_struct.get("wall_thickness_h", 5))
	var wall_th_v: int = int(cfg_struct.get("wall_thickness_v", 4))
	var loop_chance: float = float(cfg_struct.get("loop_chance", 0.35))
	var corridor_room_chance: float = float(cfg_struct.get("corridor_room_chance", 0.5))

	var floor_cells: Dictionary = {}
	for p in water:
		floor_cells[p] = true
	for p in lanes:
		floor_cells[p] = true
	var hallm: Dictionary = zoning_data.get("hallm", {})
	for p in hallm:
		floor_cells[p] = true
	for p in service:
		floor_cells[p] = true

	# 1. Pokoje wolnostojące: rzadko, w odległości >= 9/12 od podłogi
	var rooms_r: Array[Rect2i] = []
	var target := maxi(5, width * height / 2000)

	var is_near_floor = func(r: Rect2i, dist_x: int, dist_y: int) -> bool:
		var check_rect := Rect2i(r.position.x - dist_x, r.position.y - dist_y, r.size.x + dist_x * 2, r.size.y + dist_y * 2)
		for p in floor_cells:
			if check_rect.has_point(p):
				return true
		return false

	var attempts := 0
	while rooms_r.size() < target and attempts < target * 40:
		attempts += 1
		var rw := rng.randi_range(10, 17)
		var rh := rng.randi_range(9, 14)
		var x0 := rng.randi_range(4, width - 4 - rw)
		var y0 := rng.randi_range(4, height - 4 - rh)
		var r := Rect2i(x0, y0, rw, rh)

		if is_near_floor.call(r, 9, 12):
			continue
		if not is_near_floor.call(r, 30, 30):
			continue

		rooms_r.append(r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				floor_cells[Vector2i(x, y)] = true

	var corrm: Dictionary = {}
	var corridors: Array[Array] = []

	# 2. Korytarze A* łączące pokoje z siecią liniową (chodnik / hala / korytarz serwisowy)
	var link_target: Dictionary = {}
	for p in lanes:
		link_target[p] = true
	for p in hallm:
		link_target[p] = true
	for p in service:
		link_target[p] = true

	for r in rooms_r:
		var rc := r.get_center()
		var own: Dictionary = {}
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				own[Vector2i(x, y)] = true

		var path := StructuredPathfinder.find_corridor_path(
			rc, link_target, own, floor_cells, water, width, height, wall_th_h, wall_th_v, layout.segments
		)
		if not path.is_empty():
			var carved := StructuredPathfinder.carve_corridor(
				path, floor_cells, corrm, water, layout, width, height
			)
			corridors.append(carved)

	# 2b. Pętle między salami: część pokoi łączy się z innym pokojem
	for r in rooms_r:
		if rng.randf() < loop_chance:
			var rc := r.get_center()
			var own: Dictionary = {}
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					own[Vector2i(x, y)] = true

			var others: Dictionary = {}
			for other_r in rooms_r:
				if other_r == r:
					continue
				for y in range(other_r.position.y, other_r.end.y):
					for x in range(other_r.position.x, other_r.end.x):
						others[Vector2i(x, y)] = true

			var path := StructuredPathfinder.find_corridor_path(
				rc, others, own, floor_cells, water, width, height, wall_th_h, wall_th_v, layout.segments, 3, {}, Rect2i(), {}, 75
			)
			if not path.is_empty() and path.size() < 75:
				var carved := StructuredPathfinder.carve_corridor(
					path, floor_cells, corrm, water, layout, width, height
				)
				corridors.append(carved)

	# 2c. Pętle kompleksów (5a z proto_layout11.py): korytarz wychodzi z kompleksu i wraca do jego dalekiej części
	var max_loops := maxi(2, width * height / 7000)
	var loops_added := 0
	var cplx_keys: Array = complexes.keys()
	MapGeneratorBaseScript.shuffle_array(cplx_keys, rng)

	for cid in cplx_keys:
		if loops_added >= max_loops:
			break
		var cx: Dictionary = complexes[cid]
		var pm: Dictionary = cx.get("mask", {})
		if pm.size() < 100:
			continue

		# Punkty obwodowe kompleksu stykające się z murem
		var perimeter: Array[Vector2i] = []
		for p: Vector2i in pm:
			for d in DIRS:
				var np := p + d
				if not floor_cells.has(np):
					perimeter.append(p)
					break

		if perimeter.is_empty():
			continue

		MapGeneratorBaseScript.shuffle_array(perimeter, rng)
		var loop_placed := false

		for i in range(mini(25, perimeter.size())):
			var px: int = perimeter[i].x
			var py: int = perimeter[i].y

			for d in DIRS:
				var l_arm := (wall_th_h if d.y != 0 else wall_th_v) + 3
				var sx := px + d.x * l_arm
				var sy := py + d.y * l_arm

				if sx < 4 or sx >= width - 4 or sy < 4 or sy >= height - 4:
					continue
				if floor_cells.has(Vector2i(sx, sy)):
					continue

				# Szukamy powrotu do odległej części kompleksu (> 24 kratek)
				var far_cells: Dictionary = {}
				for fp: Vector2i in pm:
					if absi(fp.x - px) + absi(fp.y - py) > 24:
						far_cells[fp] = true

				if far_cells.is_empty():
					continue

				var start_rect := Rect2i(sx - 1, sy - 1, 3, 3)
				var path := StructuredPathfinder.find_corridor_path(
					Vector2i(sx, sy), far_cells, {}, floor_cells, water, width, height,
					wall_th_h, wall_th_v, layout.segments, 3, {}, start_rect, {}, 80
				)
				if not path.is_empty() and path.size() >= 15:
					var full_path: Array[Vector2i] = []
					for k in range(1, l_arm):
						full_path.append(Vector2i(px + d.x * k, py + d.y * k))
					full_path.append_array(path)

					var carved := StructuredPathfinder.carve_corridor(
						full_path, floor_cells, corrm, water, layout, width, height
					)
					corridors.append(carved)
					loops_added += 1
					loop_placed = true
					break

			if loop_placed:
				break

	# 2d. Pokoiki doklejone do długich korytarzy (5b z proto_layout11.py)
	for cc in corridors:
		if cc.size() < 40 or rng.randf() > corridor_room_chance:
			continue

		var ccm: Dictionary = {}
		for p: Vector2i in cc:
			ccm[p] = true

		for _att in range(25):
			var p: Vector2i = cc[rng.randi() % cc.size()]
			var rw := rng.randi_range(7, 10)
			var rh := rng.randi_range(6, 9)
			var side: Vector2i = DIRS[rng.randi() % DIRS.size()]
			var r: Rect2i

			if side == Vector2i(1, 0):
				r = Rect2i(p.x + 1, p.y - rh / 2, rw, rh)
			elif side == Vector2i(-1, 0):
				r = Rect2i(p.x - rw, p.y - rh / 2, rw, rh)
			elif side == Vector2i(0, 1):
				r = Rect2i(p.x - rw / 2, p.y + 1, rw, rh)
			else:
				r = Rect2i(p.x - rw / 2, p.y - rh, rw, rh)

			if r.position.x < 3 or r.position.y < 3 or r.end.x >= width - 3 or r.end.y >= height - 3:
				continue

			# Pokój nie może przecinać żadnej innej obcej podłogi poza stykiem z tym korytarzem
			var collides := false
			for ry in range(r.position.y - 1, r.end.y + 1):
				for rx in range(r.position.x - 1, r.end.x + 1):
					var cp := Vector2i(rx, ry)
					if floor_cells.has(cp) and not ccm.has(cp):
						collides = true
						break
				if collides:
					break

			if collides:
				continue

			# Wytnij pokoik
			for ry in range(r.position.y, r.end.y):
				for rx in range(r.position.x, r.end.x):
					floor_cells[Vector2i(rx, ry)] = true
			rooms_r.append(r)
			break

	# 3. Kładki na odcinkach kanałów:
	# - Nigdy na skrzyżowaniach ani zakrętach (margines min. 5 kratek od rogów)
	# - Nigdy wzdłuż kanału: poziomy kanał -> pionowa kładka, pionowy kanał -> pozioma kładka
	# - Kładki o długości 6 (cw + 2), z obu stron leżą na stałej podłodze FLOOR
	var placed_bridges: Array[Vector2i] = []

	for st in layout.segments:
		if st.get("kind", "") == "walled":
			continue
		var r: Rect2i = st["rect"]
		var horiz: bool = (st["axis"] == "h")
		var cw: int = int(st.get("width", 4))
		var span: int = (r.size.x if horiz else r.size.y)
		if span < 16:
			continue

		var min_t := (r.position.x if horiz else r.position.y) + 5
		var max_t := (r.end.x if horiz else r.end.y) - 5 - 2
		if min_t > max_t:
			continue

		var candidate_ts: Array[int] = []
		var step := maxi(1, (max_t - min_t) / 3)
		for t in range(min_t, max_t + 1, maxi(3, step)):
			candidate_ts.append(t)
		MapGeneratorBaseScript.shuffle_array(candidate_ts, rng)

		for bt in candidate_ts:
			var too_close := false
			for pb in placed_bridges:
				if (horiz and absi(pb.x - bt) < 14) or (not horiz and absi(pb.y - bt) < 14):
					too_close = true
					break
			if too_close:
				continue

			if horiz:
				# Kanał poziomy (W-E) -> Kładka PIONOWA (N-S), długość cw + 2 = 6
				var bx := bt
				var y0 := r.position.y
				var y1 := r.end.y

				var clear_canal := true
				for cx in range(bx - 3, bx + 5):
					for cy in range(y0, y1):
						if not layout.cells.has(Vector2i(cx, cy)):
							clear_canal = false
							break
					if not clear_canal:
						break
					if layout.cells.has(Vector2i(cx, y0 - 1)) or layout.cells.has(Vector2i(cx, y1)):
						clear_canal = false
						break
				if not clear_canal:
					continue

				var n_ok := (floor_cells.has(Vector2i(bx, y0 - 1)) and floor_cells.has(Vector2i(bx + 1, y0 - 1)) and \
					floor_cells.has(Vector2i(bx, y0 - 2)) and floor_cells.has(Vector2i(bx + 1, y0 - 2)))
				var s_ok := (floor_cells.has(Vector2i(bx, y1)) and floor_cells.has(Vector2i(bx + 1, y1)) and \
					floor_cells.has(Vector2i(bx, y1 + 1)) and floor_cells.has(Vector2i(bx + 1, y1 + 1)))
				if not n_ok or not s_ok:
					continue

				var b_rect := Rect2i(bx, y0 - 1, 2, cw + 2)
				var b_cells: Array[Vector2i] = []
				for by in range(y0 - 1, y1 + 1):
					var p1 := Vector2i(bx, by)
					var p2 := Vector2i(bx + 1, by)
					b_cells.append(p1)
					b_cells.append(p2)
					floor_cells[p1] = true
					floor_cells[p2] = true
					bridge_cells[p1] = true
					bridge_cells[p2] = true

				floor_cells[Vector2i(bx, y0 - 2)] = true
				floor_cells[Vector2i(bx + 1, y0 - 2)] = true
				floor_cells[Vector2i(bx, y1 + 1)] = true
				floor_cells[Vector2i(bx + 1, y1 + 1)] = true

				bridges.append({"rect": b_rect, "cells": b_cells, "vertical": true, "crossing": false})
				placed_bridges.append(Vector2i(bx, y0))
				break

			else:
				# Kanał pionowy (N-S) -> Kładka POZIOMA (W-E), długość cw + 2 = 6
				var by := bt
				var x0 := r.position.x
				var x1 := r.end.x

				var clear_canal := true
				for cy in range(by - 3, by + 5):
					for cx in range(x0, x1):
						if not layout.cells.has(Vector2i(cx, cy)):
							clear_canal = false
							break
					if not clear_canal:
						break
					if layout.cells.has(Vector2i(x0 - 1, cy)) or layout.cells.has(Vector2i(x1, cy)):
						clear_canal = false
						break
				if not clear_canal:
					continue

				var w_ok := (floor_cells.has(Vector2i(x0 - 1, by)) and floor_cells.has(Vector2i(x0 - 1, by + 1)) and \
					floor_cells.has(Vector2i(x0 - 2, by)) and floor_cells.has(Vector2i(x0 - 2, by + 1)))
				var e_ok := (floor_cells.has(Vector2i(x1, by)) and floor_cells.has(Vector2i(x1, by + 1)) and \
					floor_cells.has(Vector2i(x1 + 1, by)) and floor_cells.has(Vector2i(x1 + 1, by + 1)))
				if not w_ok or not e_ok:
					continue

				var b_rect := Rect2i(x0 - 1, by, cw + 2, 2)
				var b_cells: Array[Vector2i] = []
				for bx in range(x0 - 1, x1 + 1):
					var p1 := Vector2i(bx, by)
					var p2 := Vector2i(bx, by + 1)
					b_cells.append(p1)
					b_cells.append(p2)
					floor_cells[p1] = true
					floor_cells[p2] = true
					bridge_cells[p1] = true
					bridge_cells[p2] = true

				floor_cells[Vector2i(x0 - 2, by)] = true
				floor_cells[Vector2i(x0 - 2, by + 1)] = true
				floor_cells[Vector2i(x1 + 1, by)] = true
				floor_cells[Vector2i(x1 + 1, by + 1)] = true

				bridges.append({"rect": b_rect, "cells": b_cells, "vertical": false, "crossing": false})
				placed_bridges.append(Vector2i(x0, by))
				break

	# 4. Zapis do gridu GenerationContext (woda i podłoga jako FLOOR, reszta WALL)
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if floor_cells.has(p):
				grid[p] = CellType.FLOOR
			else:
				grid[p] = CellType.WALL

	layout.rebuild_blocked()

	return rooms_r
