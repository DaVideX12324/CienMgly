class_name StructuredRoomPacker
extends RefCounted

## Pakowanie pomieszczeń, korytarzy, kładek i pętli dla generatora structured.
## Implementuje etapy 4, 5, 5a, 5b, 6, 7 z proto_layout11.py.

const LinearFeatureLayout = preload("core/linear_feature_layout.gd")
const StructuredReservations = preload("structured_reservations.gd")
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

	var floor_cells: Dictionary = {}
	for p in water:
		floor_cells[p] = true
	for p in lanes:
		floor_cells[p] = true
	var hallm: Dictionary = zoning_data.get("hallm", {})
	for p in hallm:
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

	# 2. Korytarze łączące pokoje z siecią liniową bez rozcinania kanałów
	var carve_corridor = func(path: Array[Vector2i]) -> void:
		for p in path:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var cp := Vector2i(p.x + dx, p.y + dy)
					if cp.x >= 1 and cp.x < width - 1 and cp.y >= 1 and cp.y < height - 1:
						# Korytarz nigdy nie niszczy koryta kanału
						if not water.has(cp):
							floor_cells[cp] = true

	var find_dry_path = func(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
		var p1: Array[Vector2i] = []
		var blocked1 := false
		var sx := 1 if target.x >= start.x else -1
		for x in range(start.x, target.x + sx, sx):
			var pt := Vector2i(x, start.y)
			if water.has(pt):
				blocked1 = true
				break
			p1.append(pt)
		if not blocked1:
			var sy := 1 if target.y >= start.y else -1
			for y in range(start.y, target.y + sy, sy):
				var pt := Vector2i(target.x, y)
				if water.has(pt):
					blocked1 = true
					break
				p1.append(pt)
		if not blocked1:
			return p1

		var p2: Array[Vector2i] = []
		var blocked2 := false
		var sy2 := 1 if target.y >= start.y else -1
		for y in range(start.y, target.y + sy2, sy2):
			var pt := Vector2i(start.x, y)
			if water.has(pt):
				blocked2 = true
				break
			p2.append(pt)
		if not blocked2:
			var sx2 := 1 if target.x >= start.x else -1
			for x in range(start.x, target.x + sx2, sx2):
				var pt := Vector2i(x, target.y)
				if water.has(pt):
					blocked2 = true
					break
				p2.append(pt)
		if not blocked2:
			return p2

		return []

	# Łączenie pokoi z siecią po ich stronie kanału
	for r in rooms_r:
		var rc := r.get_center()
		var candidates: Array[Vector2i] = []
		for p in lanes:
			candidates.append(p)
		for p in hallm:
			candidates.append(p)

		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(rc).distance_squared_to(Vector2(a)) < Vector2(rc).distance_squared_to(Vector2(b))
		)

		for cand_pos in candidates.slice(0, mini(15, candidates.size())):
			var pth: Array[Vector2i] = find_dry_path.call(rc, cand_pos)
			if not pth.is_empty():
				carve_corridor.call(pth)
				break

	# 3. Kładki na odcinkach kanałów:
	# - Nigdy na skrzyżowaniach ani zakrętach (margines min. 5 kratek od rogów, bufor wolny od odnóg)
	# - Nigdy wzdłuż kanału: poziomy kanał -> pionowa kładka, pionowy kanał -> pozioma kładka
	# - Kładki dłuższe: długość cw + 2 (z obu stron leżą na stałej podłodze FLOOR)
	var placed_bridges: Array[Vector2i] = []

	for st in layout.segments:
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
		candidate_ts.shuffle()

		for bt in candidate_ts:
			var too_close := false
			for pb in placed_bridges:
				if (horiz and absi(pb.x - bt) < 14) or (not horiz and absi(pb.y - bt) < 14):
					too_close = true
					break
			if too_close:
				continue

			if horiz:
				# Kanał poziomy (W-E) -> Kładka PIONOWA (N-S), długość cw + 2
				var bx := bt
				var y0 := r.position.y
				var y1 := r.end.y

				# 1. Otoczenie w korycie czyste od zakrętów i skrzyżowań
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

				# 2. Obie strony (N i S) muszą mieć podłogę z bezpieczną głębokością w głąb sali/chodnika
				var n_ok := (floor_cells.has(Vector2i(bx, y0 - 1)) and floor_cells.has(Vector2i(bx + 1, y0 - 1)) and \
					floor_cells.has(Vector2i(bx, y0 - 2)) and floor_cells.has(Vector2i(bx + 1, y0 - 2)))
				var s_ok := (floor_cells.has(Vector2i(bx, y1)) and floor_cells.has(Vector2i(bx + 1, y1)) and \
					floor_cells.has(Vector2i(bx, y1 + 1)) and floor_cells.has(Vector2i(bx + 1, y1 + 1)))
				if not n_ok or not s_ok:
					continue

				# Rejestracja kładki pionowej (N-S)
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

				# Clearance na stałym lądzie
				floor_cells[Vector2i(bx, y0 - 2)] = true
				floor_cells[Vector2i(bx + 1, y0 - 2)] = true
				floor_cells[Vector2i(bx, y1 + 1)] = true
				floor_cells[Vector2i(bx + 1, y1 + 1)] = true

				bridges.append({"rect": b_rect, "cells": b_cells, "vertical": true, "crossing": false})
				placed_bridges.append(Vector2i(bx, y0))
				break

			else:
				# Kanał pionowy (N-S) -> Kładka POZIOMA (W-E), długość cw + 2
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

				# Rejestracja kładki poziomej (W-E)
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

