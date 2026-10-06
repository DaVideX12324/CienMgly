class_name StructuredPathfinder
extends RefCounted

## Zoptymalizowany wyszukiwacz ścieżek i drążnik korytarzy dla generatora structured.
## Implementuje algorytmy z proto_layout11.py i proto_layout10.py:
## - A* z zachowaniem minimalnej grubości ścian (WALL_H, WALL_V) od innych struktur;
## - Kontrolowane prostopadłe przekraczanie kanałów (poziomy -> kładka pionowa, pionowy -> pozioma);
## - Zakaz przekraczania kanałów na zakrętach i skrzyżowaniach;
## - Prostopadłe wloty drzwiowe do pomieszczeń docelowych;
## - Generowanie kładek przecięć (crossing bridges) i pętli.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


class MinHeap:
	var data: Array = []  # Array of [prio: int, g_cost: int, x: int, y: int, dir_idx: int]

	func push(prio: int, g_cost: int, x: int, y: int, dir_idx: int) -> void:
		var item: Array = [prio, g_cost, x, y, dir_idx]
		data.append(item)
		var idx := data.size() - 1
		while idx > 0:
			var parent := (idx - 1) / 2
			if int(data[idx][0]) < int(data[parent][0]):
				var tmp = data[idx]
				data[idx] = data[parent]
				data[parent] = tmp
				idx = parent
			else:
				break

	func pop() -> Array:
		if data.is_empty():
			return []
		var res: Array = data[0]
		var last = data.pop_back()
		if not data.is_empty():
			data[0] = last
			var idx := 0
			var n := data.size()
			while true:
				var left := 2 * idx + 1
				var right := 2 * idx + 2
				var smallest := idx
				if left < n and int(data[left][0]) < int(data[smallest][0]):
					smallest = left
				if right < n and int(data[right][0]) < int(data[smallest][0]):
					smallest = right
				if smallest != idx:
					var tmp = data[idx]
					data[idx] = data[smallest]
					data[smallest] = tmp
					idx = smallest
				else:
					break
		return res

	func is_empty() -> bool:
		return data.is_empty()


## Buduje 2D tablicę sum prefiksowych (szerokość + 1) * (wysokość + 1) dla szybkiego testowania prostokątów O(1).
static func build_prefix_sum(width: int, height: int, cells: Dictionary) -> PackedInt32Array:
	var stride := width + 1
	var size := (height + 1) * stride
	var pfx := PackedInt32Array()
	pfx.resize(size)
	pfx.fill(0)

	for y in range(height):
		var row_sum := 0
		var r_idx := (y + 1) * stride
		var prev_r_idx := y * stride
		for x in range(width):
			if cells.has(Vector2i(x, y)):
				row_sum += 1
			pfx[r_idx + (x + 1)] = row_sum + pfx[prev_r_idx + (x + 1)]
	return pfx


## Sprawdza czy prostokąt [x0, y0] do [x1, y1] zawiera choć jedną komórkę.
static func rect_has_any(pfx: PackedInt32Array, width: int, height: int, x0: int, y0: int, x1: int, y1: int) -> bool:
	if x0 > x1 or y0 > y1:
		return false
	var rx0 := clampi(x0, 0, width)
	var ry0 := clampi(y0, 0, height)
	var rx1 := clampi(x1 + 1, 0, width)
	var ry1 := clampi(y1 + 1, 0, height)
	if rx0 >= rx1 or ry0 >= ry1:
		return false

	var stride := width + 1
	var s: int = pfx[ry1 * stride + rx1] - pfx[ry0 * stride + rx1] - pfx[ry1 * stride + rx0] + pfx[ry0 * stride + rx0]
	return s > 0


## Wyszukuje ścieżkę A* z punktu startowego do maski docelowej z zachowaniem reguł strukturalnych.
static func find_corridor_path(
	start: Vector2i,
	target_mask: Dictionary,
	own_mask: Dictionary,
	floor_cells: Dictionary,
	water_cells: Dictionary,
	width: int,
	height: int,
	wall_h: int = 5,
	wall_v: int = 4,
	segments: Array = [],
	margin: int = 3,
	bias: Dictionary = {},
	start_ok_rect: Rect2i = Rect2i(),
	extra_forb: Dictionary = {},
	max_len: int = 100,
	zone_skip: Dictionary = {},
	forbid_water: bool = false
) -> Array[Vector2i]:
	if target_mask.is_empty():
		return []

	# 1. Obce komórki podłogi (nie należące do startu i nie będące wodą kanału)
	var other_cells: Dictionary = {}
	for p in floor_cells:
		if not own_mask.has(p) and not water_cells.has(p):
			other_cells[p] = true

	var other_pfx := build_prefix_sum(width, height, other_cells)

	# 2. Strefy kanałów i zakrętów
	var zh_map: Dictionary = {}
	var zv_map: Dictionary = {}
	var jz_map: Dictionary = {}

	for s in segments:
		var r: Rect2i = s.get("rect", Rect2i())
		var axis: String = s.get("axis", "h")
		if axis == "h":
			for cy in range(maxi(0, r.position.y - wall_v - 2), mini(height, r.end.y + wall_v + 2)):
				for cx in range(maxi(0, r.position.x - wall_h - 2), mini(width, r.end.x + wall_h + 2)):
					zh_map[Vector2i(cx, cy)] = true
		else:
			for cy in range(maxi(0, r.position.y - wall_v - 2), mini(height, r.end.y + wall_v + 2)):
				for cx in range(maxi(0, r.position.x - wall_h - 2), mini(width, r.end.x + wall_h + 2)):
					zv_map[Vector2i(cx, cy)] = true

	# Zakręty / węzły (wspólny obszar zh i zv)
	for p in zh_map:
		if zv_map.has(p):
			jz_map[p] = true

	var tgt_min_x := 999999
	var tgt_min_y := 999999
	var tgt_max_x := -1
	var tgt_max_y := -1
	for tp: Vector2i in target_mask:
		tgt_min_x = mini(tgt_min_x, tp.x)
		tgt_min_y = mini(tgt_min_y, tp.y)
		tgt_max_x = maxi(tgt_max_x, tp.x)
		tgt_max_y = maxi(tgt_max_y, tp.y)

	var get_h = func(p: Vector2i) -> int:
		var dx := maxi(0, maxi(tgt_min_x - p.x, p.x - tgt_max_x))
		var dy := maxi(0, maxi(tgt_min_y - p.y, p.y - tgt_max_y))
		return dx + dy

	var heap := MinHeap.new()
	heap.push(get_h.call(start), 0, start.x, start.y, -1)

	var best: Dictionary = {}  # int_key -> cost
	var prev: Dictionary = {}  # int_key -> prev_int_key
	var start_key := (start.y * width + start.x) * 4 + 0
	best[start_key] = 0

	var max_iterations := 8000
	var iters := 0

	while not heap.is_empty() and iters < max_iterations:
		iters += 1
		var cur: Array = heap.pop()
		var prio: int = cur[0]
		var g: int = cur[1]
		var x: int = cur[2]
		var y: int = cur[3]
		var dI: int = cur[4]

		var cur_pos := Vector2i(x, y)
		var cur_key := (y * width + x) * 4 + (dI if dI >= 0 else 0)

		if int(best.get(cur_key, 9999999)) < g:
			continue

		# Sprawdzenie czy osiągnęliśmy cel lub prostą linię do celu (wlot drzwiowy)
		if not own_mask.has(cur_pos):
			var best_l := 999
			var best_dir := Vector2i.ZERO

			for d in DIRS:
				for l_step in range(1, wall_h + 6):
					var test_p := cur_pos + d * l_step
					if test_p.x < 0 or test_p.x >= width or test_p.y < 0 or test_p.y >= height:
						break
					if forbid_water and water_cells.has(test_p):
						break
					if extra_forb.has(test_p) and not target_mask.has(test_p):
						break
					if target_mask.has(test_p):
						if l_step < best_l:
							best_l = l_step
							best_dir = d
						break
					# Przeszkoda na prostej do celu
					if other_cells.has(test_p) and not target_mask.has(test_p):
						break

			if best_l < 999:
				# Zrekonstruuj ścieżkę
				var path: Array[Vector2i] = []
				var trace_key := cur_key
				while prev.has(trace_key):
					var pk: int = prev[trace_key]
					var p_cell := pk / 4
					var px := p_cell % width
					var py := p_cell / width
					path.append(Vector2i(px, py))
					trace_key = pk
				path.reverse()
				path.append(cur_pos)

				for k in range(1, best_l + 1):
					path.append(cur_pos + best_dir * k)
				return path

		# Rozszerzanie sąsiadów
		for ni in range(4):
			var d: Vector2i = DIRS[ni]
			var nx := x + d.x
			var ny := y + d.y
			var n_pos := Vector2i(nx, ny)

			if nx < margin + 1 or nx >= width - margin - 1 or ny < margin + 1 or ny >= height - margin - 1:
				continue

			if forbid_water and water_cells.has(n_pos):
				continue

			var in_own: bool = own_mask.has(n_pos)
			var in_start_ok := (start_ok_rect.has_point(n_pos) if start_ok_rect.size != Vector2i.ZERO else false)

			if not in_own and not in_start_ok:
				# Kontrola minimalnej odległości od obcej podłogi (utrzymanie muru)
				if rect_has_any(other_pfx, width, height, nx - (wall_h + 1), ny - (wall_v + 1), nx + (wall_h + 1), ny + (wall_v + 1)):
					# Dozwolone tylko jeśli jesteśmy w pobliżu target_mask
					var near_target := false
					for dy in range(-wall_v - 2, wall_v + 3):
						for dx in range(-wall_h - 2, wall_h + 3):
							if target_mask.has(n_pos + Vector2i(dx, dy)):
								near_target = true
								break
						if near_target:
							break
					if not near_target:
						continue

				if extra_forb.has(n_pos) and not target_mask.has(n_pos):
					continue

				if water_cells.has(n_pos) and jz_map.has(n_pos):
					continue

				# Reguła prostopadłego przekraczania kanałów (pomijana gdy w zone_skip)
				if not zone_skip.has(n_pos):
					var zh: bool = zh_map.has(n_pos)
					var zv: bool = zv_map.has(n_pos)
					if zh and zv and water_cells.has(n_pos):
						continue
					if zh and d.x != 0 and water_cells.has(n_pos):
						continue  # przez poziomy kanał tylko pionowo
					if zv and d.y != 0 and water_cells.has(n_pos):
						continue  # przez pionowy kanał tylko poziomo

			var turn_penalty: int = 4 if (dI >= 0 and dI != ni) else 0
			var bias_val: int = int(bias.get(n_pos, 0))
			var water_penalty: int = 15 if water_cells.has(n_pos) else 0

			var ng: int = g + 1 + turn_penalty + bias_val + water_penalty
			if ng > max_len * 2:
				continue

			var n_key := (ny * width + nx) * 4 + ni
			if ng < int(best.get(n_key, 9999999)):
				best[n_key] = ng
				prev[n_key] = cur_key
				heap.push(ng + get_h.call(n_pos), ng, nx, ny, ni)

	return []


## Drąży korytarz 3x3 na podstawie ścieżki i tworzy kładki przecięć tam gdzie korytarz przecina wodę.
static func carve_corridor(
	path: Array[Vector2i],
	floor_cells: Dictionary,
	corrm: Dictionary,
	water_cells: Dictionary,
	layout: LinearFeatureLayout,
	width: int,
	height: int,
	service: Dictionary = {},
	is_service: bool = false
) -> Array[Vector2i]:
	var carved_cells: Array[Vector2i] = []

	for p in path:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cp := p + Vector2i(dx, dy)
				if cp.x >= 1 and cp.x < width - 1 and cp.y >= 1 and cp.y < height - 1:
					if not water_cells.has(cp):
						floor_cells[cp] = true
						corrm[cp] = true
						carved_cells.append(cp)
						if is_service:
							service[cp] = true
							layout.service[cp] = true

	# Kładki przecięć (crossing bridges) na wodzie - korytarze serwisowe biegną za ścianą i nie stawiają kładek
	if not is_service:
		_add_crossing_bridges(path, floor_cells, water_cells, layout)

	return carved_cells


## Dodaje przepisowe kładki w miejscach przecięcia ścieżki z kanałem.
## Bezwzględny zakaz kładek na zakrętach, narożnikach i skrzyżowaniach oraz w obmurowanych korytach.
static func _add_crossing_bridges(
	path: Array[Vector2i],
	floor_cells: Dictionary,
	water_cells: Dictionary,
	layout: LinearFeatureLayout
) -> void:
	for p in path:
		if not water_cells.has(p):
			continue

		# Znajdź segment kanału zawierający p
		for seg in layout.segments:
			if seg.get("kind", "") == "walled":
				continue
			var r: Rect2i = seg.get("rect", Rect2i())
			if not r.has_point(p):
				continue

			var horiz: bool = (seg.get("axis", "h") == "h")
			var cw: int = int(seg.get("width", 4))

			if horiz:
				# Kanał poziomy -> Kładka pionowa
				var bx := p.x
				var y0 := r.position.y
				var y1 := r.end.y

				# Zakaz kładek na zakrętach, narożnikach i skrzyżowaniach (min. 4 kratki od końców)
				if bx - r.position.x < 4 or r.end.x - (bx + 2) < 4:
					continue

				# Sprawdź czy kładka w tym miejscu już istnieje
				var exists := false
				for cr in layout.crossings:
					var cr_rect: Rect2i = cr.get("rect", Rect2i())
					if absi(cr_rect.position.x - bx) < 3 and cr_rect.position.y == y0 - 1:
						exists = true
						break
				if exists:
					break

				var b_rect := Rect2i(bx, y0 - 1, 2, cw + 2)
				var b_cells: Array[Vector2i] = []
				for by in range(y0 - 1, y1 + 1):
					var p1 := Vector2i(bx, by)
					var p2 := Vector2i(bx + 1, by)
					b_cells.append(p1)
					b_cells.append(p2)
					floor_cells[p1] = true
					floor_cells[p2] = true
					layout.crossing_cells[p1] = true
					layout.crossing_cells[p2] = true

				# Clearance na obu brzegach
				floor_cells[Vector2i(bx, y0 - 2)] = true
				floor_cells[Vector2i(bx + 1, y0 - 2)] = true
				floor_cells[Vector2i(bx, y1 + 1)] = true
				floor_cells[Vector2i(bx + 1, y1 + 1)] = true

				layout.crossings.append({
					"rect": b_rect,
					"cells": b_cells,
					"vertical": true,
					"crossing": true
				})
				break
			else:
				# Kanał pionowy -> Kładka pozioma
				var by := p.y
				var x0 := r.position.x
				var x1 := r.end.x

				# Zakaz kładek na zakrętach, narożnikach i skrzyżowaniach (min. 4 kratki od końców)
				if by - r.position.y < 4 or r.end.y - (by + 2) < 4:
					continue

				var exists := false
				for cr in layout.crossings:
					var cr_rect: Rect2i = cr.get("rect", Rect2i())
					if absi(cr_rect.position.y - by) < 3 and cr_rect.position.x == x0 - 1:
						exists = true
						break
				if exists:
					break

				var b_rect := Rect2i(x0 - 1, by, cw + 2, 2)
				var b_cells: Array[Vector2i] = []
				for bx in range(x0 - 1, x1 + 1):
					var p1 := Vector2i(bx, by)
					var p2 := Vector2i(bx, by + 1)
					b_cells.append(p1)
					b_cells.append(p2)
					floor_cells[p1] = true
					floor_cells[p2] = true
					layout.crossing_cells[p1] = true
					layout.crossing_cells[p2] = true

				floor_cells[Vector2i(x0 - 2, by)] = true
				floor_cells[Vector2i(x0 - 2, by + 1)] = true
				floor_cells[Vector2i(x1 + 1, by)] = true
				floor_cells[Vector2i(x1 + 1, by + 1)] = true

				layout.crossings.append({
					"rect": b_rect,
					"cells": b_cells,
					"vertical": false,
					"crossing": true
				})
				break
