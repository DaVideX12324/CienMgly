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

	# 2. Korytarze A* łączące pokoje z siecią liniową (chodnikiem lub kompleksem)
	var add_crossing_bridges = func(path: Array[Vector2i]) -> void:
		var wc: Array[Vector2i] = []
		for p in path:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var cp := Vector2i(p.x + dx, p.y + dy)
					if water.has(cp) and not wc.has(cp):
						wc.append(cp)
		if wc.is_empty():
			return
		for p in wc:
			floor_cells[p] = true
			bridge_cells[p] = true
		var min_p: Vector2i = wc[0]
		var max_p: Vector2i = wc[0]
		for p in wc:
			min_p.x = mini(min_p.x, p.x)
			min_p.y = mini(min_p.y, p.y)
			max_p.x = maxi(max_p.x, p.x)
			max_p.y = maxi(max_p.y, p.y)
		var b_rect := Rect2i(min_p, max_p - min_p + Vector2i(1, 1))
		bridges.append({"rect": b_rect, "cells": wc, "vertical": true, "crossing": true})

	var carve_path = func(path: Array[Vector2i]) -> void:
		for p in path:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var cp := Vector2i(p.x + dx, p.y + dy)
					if cp.x >= 1 and cp.x < width - 1 and cp.y >= 1 and cp.y < height - 1:
						floor_cells[cp] = true
		add_crossing_bridges.call(path)

	# Proste łączenie każdego pokoju do najbliższego punktu sieci
	for r in rooms_r:
		var rc := r.get_center()
		var best_target := Vector2i(-1, -1)
		var best_dist := INF

		for p in lanes:
			var d := Vector2(rc).distance_squared_to(Vector2(p))
			if d < best_dist:
				best_dist = d
				best_target = p

		for p in hallm:
			var d := Vector2(rc).distance_squared_to(Vector2(p))
			if d < best_dist:
				best_dist = d
				best_target = p

		if best_target != Vector2i(-1, -1):
			# Korytarz L
			var path: Array[Vector2i] = []
			var cx := rc.x
			var cy := rc.y
			var tx := best_target.x
			var ty := best_target.y

			var step_x := 1 if tx >= cx else -1
			for x in range(cx, tx + step_x, step_x):
				path.append(Vector2i(x, cy))
			var step_y := 1 if ty >= cy else -1
			for y in range(cy, ty + step_y, step_y):
				path.append(Vector2i(tx, y))

			carve_path.call(path)

	# 3. Kładki na odcinkach kanałów
	for st in layout.segments:
		var r: Rect2i = st["rect"]
		var horiz: bool = st["axis"] == "h"
		var cw: int = int(st.get("width", 4))
		var span := (r.size.x if horiz else r.size.y) - 2 * cw
		if span < 6:
			continue

		var n_bridges := maxi(1, span / (20 if horiz else 18))
		for bi in range(n_bridges):
			var bx: int = st.get("bridge_t", r.position.x + cw + (bi + 1) * span / (n_bridges + 1))
			var b_cells: Array[Vector2i] = []

			var b_rect := Rect2i()
			if horiz:
				var x_pos := clampi(bx, r.position.x + 1, r.end.x - 2)
				b_rect = Rect2i(x_pos, r.position.y - 1, 2, r.size.y + 2)
				for y in range(r.position.y, r.end.y):
					b_cells.append(Vector2i(x_pos, y))
					b_cells.append(Vector2i(x_pos + 1, y))
			else:
				var y_pos := clampi(bx, r.position.y + 1, r.end.y - 2)
				b_rect = Rect2i(r.position.x - 1, y_pos, r.size.x + 2, 2)
				for x in range(r.position.x, r.end.x):
					b_cells.append(Vector2i(x, y_pos))
					b_cells.append(Vector2i(x, y_pos + 1))

			if not b_cells.is_empty():
				for p in b_cells:
					bridge_cells[p] = true
				bridges.append({"rect": b_rect, "cells": b_cells, "vertical": horiz, "crossing": false})

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
