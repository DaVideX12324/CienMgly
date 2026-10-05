class_name BridgeConnectivityResolver
extends RefCounted

## Rozwiązywacz spójności fragmentów i kładek dla generatora structured.
## Gwarantuje, że każdy odcięty fragment lądu za kanałem ma zapewnione legalne przejście przez kładkę.
## - Wykrywa spójne składowe chodliwe gracza (gdzie woda bez kładki blokuje ruch);
## - Dla fragmentów rozdzielonych litym murem drąży optymalny łącznik lądowy Multi-Source BFS;
## - Dla fragmentów odciętych kanałem stawia kładki o długości seg_cw + 2 łączące oba brzegi;
## - Zapewnia czyste lądowanie kładki na stałej podłodze FLOOR (wraz z podejściami);
## - Usuwa nieosiągalne mikro-odłamki podłogi (<= 5 kratek) w litych ścianach.

const LinearFeatureLayout = preload("core/linear_feature_layout.gd")


static func resolve(ctx: GenerationContext, layout: LinearFeatureLayout) -> void:
	var width := ctx.width
	var height := ctx.height
	var grid: Dictionary = ctx.grid
	var water: Dictionary = layout.cells
	var bridge_cells: Dictionary = layout.crossing_cells
	var bridges: Array[Dictionary] = layout.crossings
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	var is_walkable = func(p: Vector2i) -> bool:
		var t: int = int(grid.get(p, -1))
		if t != CellType.FLOOR and t != CellType.ENTRANCE and t != CellType.EXIT and t != CellType.DOOR:
			return false
		if water.has(p) and not bridge_cells.has(p):
			return false
		return true

	var get_components = func() -> Array[Dictionary]:
		var visited: Dictionary = {}
		var comps: Array[Dictionary] = []
		for p in grid:
			if visited.has(p) or not is_walkable.call(p):
				continue
			var comp: Dictionary = {}
			var queue: Array[Vector2i] = [p]
			visited[p] = true
			comp[p] = true
			var head := 0
			while head < queue.size():
				var cur: Vector2i = queue[head]
				head += 1
				for d in dirs:
					var n: Vector2i = cur + d
					if not visited.has(n) and is_walkable.call(n):
						visited[n] = true
						comp[n] = true
						queue.append(n)
			comps.append(comp)

		# Składowa zawierająca wejście gracza (jeśli wyznaczone) ma najwyższy priorytet
		var entrance_comp_idx := -1
		if ctx.entrance_pos != Vector2i.ZERO:
			for ci in range(comps.size()):
				if comps[ci].has(ctx.entrance_pos):
					entrance_comp_idx = ci
					break

		if entrance_comp_idx > 0:
			var ent_comp: Dictionary = comps[entrance_comp_idx]
			comps.remove_at(entrance_comp_idx)
			comps.insert(0, ent_comp)
		else:
			comps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a.size() > b.size()
			)
		return comps

	# Pętla łączenia fragmentów dopóki są rozłączone składowe
	var pass_count := 0
	while pass_count < 60:
		pass_count += 1
		var comps: Array = get_components.call()
		if comps.size() <= 1:
			break

		var main_c: Dictionary = comps[0] as Dictionary
		var cut_c: Dictionary = comps[1] as Dictionary

		# 1. Sprawdzenie i usunięcie mikro-odłamków (<= 5 kratek) niebędących portalami
		var has_portal := false
		if ctx.entrance_pos != Vector2i.ZERO and cut_c.has(ctx.entrance_pos):
			has_portal = true
		if ctx.exit_pos != Vector2i.ZERO and cut_c.has(ctx.exit_pos):
			has_portal = true

		if not has_portal and cut_c.size() < 6:
			for p in cut_c:
				grid[p] = CellType.WALL
			continue

		# 2. Kładka przez kanał (dla odciętych wysp otoczonych kanałem - priorytet nad drążeniem w murach)
		var best_bridge: Dictionary = {}
		var min_total_dist := 999999

		for st in layout.segments:
			if st.get("kind", "") == "walled":
				continue
			var r: Rect2i = st["rect"]
			var horiz: bool = (st["axis"] == "h")
			var seg_cw: int = (r.size.y if horiz else r.size.x)
			var span: int = (r.size.x if horiz else r.size.y)
			if span < seg_cw + 2:
				continue

			if horiz:
				var y0 := r.position.y
				var y1 := r.end.y
				var min_bx := r.position.x + 1
				var max_bx := r.end.x - 3
				if min_bx > max_bx:
					continue

				for bx in range(min_bx, max_bx + 1):
					if bridge_cells.has(Vector2i(bx, y0)) or bridge_cells.has(Vector2i(bx + 1, y0)):
						continue

					var dist_n_cut := -1
					var dist_n_main := -1
					for dy in range(1, 16):
						var py := y0 - dy
						var pa := Vector2i(bx, py)
						var pb := Vector2i(bx + 1, py)
						if water.has(pa) or water.has(pb) or py < 2:
							break
						if dist_n_cut == -1 and (cut_c.has(pa) or cut_c.has(pb)):
							dist_n_cut = dy
						if dist_n_main == -1 and (main_c.has(pa) or main_c.has(pb)):
							dist_n_main = dy
						if dist_n_cut != -1 or dist_n_main != -1:
							break

					var dist_s_cut := -1
					var dist_s_main := -1
					for dy in range(0, 15):
						var py := y1 + dy
						var pa := Vector2i(bx, py)
						var pb := Vector2i(bx + 1, py)
						if water.has(pa) or water.has(pb) or py >= height - 2:
							break
						if dist_s_cut == -1 and (cut_c.has(pa) or cut_c.has(pb)):
							dist_s_cut = dy
						if dist_s_main == -1 and (main_c.has(pa) or main_c.has(pb)):
							dist_s_main = dy
						if dist_s_cut != -1 or dist_s_main != -1:
							break

					var valid := false
					var cur_dist := 0
					var dn := 0
					var ds := 0
					if dist_n_cut != -1 and dist_s_main != -1:
						valid = true
						cur_dist = dist_n_cut + dist_s_main
						dn = dist_n_cut
						ds = dist_s_main
					elif dist_n_main != -1 and dist_s_cut != -1:
						valid = true
						cur_dist = dist_n_main + dist_s_cut
						dn = dist_n_main
						ds = dist_s_cut

					if valid and cur_dist < min_total_dist:
						min_total_dist = cur_dist
						best_bridge = {
							"horiz": true,
							"bx": bx,
							"y0": y0,
							"y1": y1,
							"seg_cw": seg_cw,
							"dn": dn,
							"ds": ds
						}
			else:
				var x0 := r.position.x
				var x1 := r.end.x
				var min_by := r.position.y + 1
				var max_by := r.end.y - 3
				if min_by > max_by:
					continue

				for by in range(min_by, max_by + 1):
					if bridge_cells.has(Vector2i(x0, by)) or bridge_cells.has(Vector2i(x0, by + 1)):
						continue

					var dist_w_cut := -1
					var dist_w_main := -1
					for dx in range(1, 16):
						var px := x0 - dx
						var pa := Vector2i(px, by)
						var pb := Vector2i(px, by + 1)
						if water.has(pa) or water.has(pb) or px < 2:
							break
						if dist_w_cut == -1 and (cut_c.has(pa) or cut_c.has(pb)):
							dist_w_cut = dx
						if dist_w_main == -1 and (main_c.has(pa) or main_c.has(pb)):
							dist_w_main = dx
						if dist_w_cut != -1 or dist_w_main != -1:
							break

					var dist_e_cut := -1
					var dist_e_main := -1
					for dx in range(0, 15):
						var px := x1 + dx
						var pa := Vector2i(px, by)
						var pb := Vector2i(px, by + 1)
						if water.has(pa) or water.has(pb) or px >= width - 2:
							break
						if dist_e_cut == -1 and (cut_c.has(pa) or cut_c.has(pb)):
							dist_e_cut = dx
						if dist_e_main == -1 and (main_c.has(pa) or main_c.has(pb)):
							dist_e_main = dx
						if dist_e_cut != -1 or dist_e_main != -1:
							break

					var valid := false
					var cur_dist := 0
					var dw := 0
					var de := 0
					if dist_w_cut != -1 and dist_e_main != -1:
						valid = true
						cur_dist = dist_w_cut + dist_e_main
						dw = dist_w_cut
						de = dist_e_main
					elif dist_w_main != -1 and dist_e_cut != -1:
						valid = true
						cur_dist = dist_w_main + dist_e_cut
						dw = dist_w_main
						de = dist_e_cut

					if valid and cur_dist < min_total_dist:
						min_total_dist = cur_dist
						best_bridge = {
							"horiz": false,
							"by": by,
							"x0": x0,
							"x1": x1,
							"seg_cw": seg_cw,
							"dw": dw,
							"de": de
						}

		if not best_bridge.is_empty():
			if best_bridge["horiz"]:
				var bx: int = best_bridge["bx"]
				var y0: int = best_bridge["y0"]
				var y1: int = best_bridge["y1"]
				var seg_cw: int = best_bridge["seg_cw"]
				var dn: int = best_bridge["dn"]
				var ds: int = best_bridge["ds"]

				var b_rect := Rect2i(bx, y0 - 1, 2, seg_cw + 2)
				var b_cells: Array[Vector2i] = []
				for by in range(y0 - 1, y1 + 1):
					var p1 := Vector2i(bx, by)
					var p2 := Vector2i(bx + 1, by)
					b_cells.append(p1)
					b_cells.append(p2)
					grid[p1] = CellType.FLOOR
					grid[p2] = CellType.FLOOR
					bridge_cells[p1] = true
					bridge_cells[p2] = true

				bridges.append({"rect": b_rect, "cells": b_cells, "vertical": true, "crossing": false})

				for dy in range(1, dn + 2):
					var py := y0 - 1 - dy
					if py >= 2:
						grid[Vector2i(bx, py)] = CellType.FLOOR
						grid[Vector2i(bx + 1, py)] = CellType.FLOOR
				for dy in range(0, ds + 2):
					var py := y1 + 1 + dy
					if py < height - 2:
						grid[Vector2i(bx, py)] = CellType.FLOOR
						grid[Vector2i(bx + 1, py)] = CellType.FLOOR
				continue
			else:
				var by: int = best_bridge["by"]
				var x0: int = best_bridge["x0"]
				var x1: int = best_bridge["x1"]
				var seg_cw: int = best_bridge["seg_cw"]
				var dw: int = best_bridge["dw"]
				var de: int = best_bridge["de"]

				var b_rect := Rect2i(x0 - 1, by, seg_cw + 2, 2)
				var b_cells: Array[Vector2i] = []
				for bx in range(x0 - 1, x1 + 1):
					var p1 := Vector2i(bx, by)
					var p2 := Vector2i(bx, by + 1)
					b_cells.append(p1)
					b_cells.append(p2)
					grid[p1] = CellType.FLOOR
					grid[p2] = CellType.FLOOR
					bridge_cells[p1] = true
					bridge_cells[p2] = true

				bridges.append({"rect": b_rect, "cells": b_cells, "vertical": false, "crossing": false})

				for dx in range(1, dw + 2):
					var px := x0 - 1 - dx
					if px >= 2:
						grid[Vector2i(px, by)] = CellType.FLOOR
						grid[Vector2i(px, by + 1)] = CellType.FLOOR
				for dx in range(0, de + 2):
					var px := x1 + 1 + dx
					if px < width - 2:
						grid[Vector2i(px, by)] = CellType.FLOOR
						grid[Vector2i(px, by + 1)] = CellType.FLOOR
				continue

		# 3. Multi-Source BFS przez ląd omijający wodę (tylko w ostateczności, gdy nie można postawić kładki)
		var bfs_queue: Array[Vector2i] = []
		var came_from: Dictionary = {}
		var bfs_visited: Dictionary = {}
		for p in cut_c:
			bfs_queue.append(p)
			bfs_visited[p] = true

		var head := 0
		var found_target := Vector2i.ZERO
		while head < bfs_queue.size():
			var cur: Vector2i = bfs_queue[head]
			head += 1

			if main_c.has(cur):
				found_target = cur
				break

			for d in dirs:
				var n: Vector2i = cur + d
				if n.x < 2 or n.y < 2 or n.x >= width - 2 or n.y >= height - 2:
					continue
				if water.has(n):
					continue
				if not bfs_visited.has(n):
					bfs_visited[n] = true
					came_from[n] = cur
					bfs_queue.append(n)

		if found_target != Vector2i.ZERO:
			var curr: Vector2i = found_target
			while came_from.has(curr):
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var cp := curr + Vector2i(dx, dy)
						if cp.x >= 2 and cp.x < width - 2 and cp.y >= 2 and cp.y < height - 2:
							if not water.has(cp):
								grid[cp] = CellType.FLOOR
				curr = came_from[curr]
			continue


		# 4. Jeśli nie dało się połączyć ani BFS-em ani kładką, a fragment nie zawiera portalu
		if not has_portal:
			for p in cut_c:
				grid[p] = CellType.WALL
		else:
			break

	layout.rebuild_blocked()
