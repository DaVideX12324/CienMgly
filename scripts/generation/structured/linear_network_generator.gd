class_name LinearNetworkGenerator
extends RefCounted

## Generator sieci liniowej (pień + odnogi ze skrętami).
## Odpowiednik etapu 1 z proto_layout11.py:
## - Pień od lewej krawędzi w prawo ze sporadycznymi skrętami;
## - Odnogi odchodzące pod kątem prostym od istniejących odcinków;
## - Kontrola szerokości (żaden fragment nie może być szerszy niż canal_width, brak plam 5x5);
## - Kontrola minimalnego odstępu CLEAR między odnogami.

const LinearFeatureLayout = preload("core/linear_feature_layout.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate_network(
	width: int,
	height: int,
	rng: RandomNumberGenerator,
	layout: LinearFeatureLayout,
	cw: int = 4,
	clear_dist: int = 16,
	margin: int = 3,
	canal_dry_chance: float = 0.4
) -> void:
	var water_cells: Dictionary = layout.cells
	var segs: Array[Dictionary] = layout.segments
	var lines: Dictionary = layout.lines
	var sewage_cells: Dictionary = {}
	var dry_cells: Dictionary = {}

	# Pomocnicza funkcja prostokąta odcinka
	var get_seg_rect = func(hx: int, hy: int, d: Vector2i, L: int) -> Array:
		var r: Rect2i
		var nh: Vector2i
		if d == Vector2i(1, 0):
			r = Rect2i(hx, hy, L + cw, cw)
			nh = Vector2i(hx + L, hy)
		elif d == Vector2i(-1, 0):
			r = Rect2i(hx - L, hy, L + cw, cw)
			nh = Vector2i(hx - L, hy)
		elif d == Vector2i(0, 1):
			r = Rect2i(hx, hy, cw, L + cw)
			nh = Vector2i(hx, hy + L)
		else:
			r = Rect2i(hx, hy - L, cw, L + cw)
			nh = Vector2i(hx, hy - L)
		return [r, nh]

	var is_inside = func(r: Rect2i, m: int) -> bool:
		return r.position.x >= m and r.position.y >= m and r.end.x < width - m and r.end.y < height - m

	var is_too_wide = func(r: Rect2i, for_dry: bool) -> bool:
		var check_cells: Dictionary = dry_cells if for_dry else sewage_cells
		var k := cw + 1
		var x0 := maxi(0, r.position.x - 2)
		var y0 := maxi(0, r.position.y - 2)
		var x1 := mini(width - k, r.end.x + 2)
		var y1 := mini(height - k, r.end.y + 2)
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				var all_water := true
				for dy in range(k):
					for dx in range(k):
						var p := Vector2i(cx + dx, cy + dy)
						if not (check_cells.has(p) or r.has_point(p)):
							all_water = false
							break
					if not all_water:
						break
				if all_water:
					return true
		return false

	var is_clear_ok = func(r: Rect2i, hx: int, hy: int, for_dry: bool) -> bool:
		var zone_rect := Rect2i(r.position.x - clear_dist, r.position.y - clear_dist, r.size.x + clear_dist * 2, r.size.y + clear_dist * 2)
		if for_dry:
			# Bezwzględny brak jakichkolwiek ścieków w buforze 16 kratek!
			for p in sewage_cells:
				if zone_rect.has_point(p):
					return false
			# Względem własnych komórek suchego koryta zachowujemy standardowy near_rect
			var near_rect := Rect2i(hx - clear_dist - cw, hy - clear_dist - cw, (clear_dist + cw) * 2 + cw, (clear_dist + cw) * 2 + cw)
			for p in dry_cells:
				if zone_rect.has_point(p) and not near_rect.has_point(p):
					return false
			return true
		else:
			var near_rect := Rect2i(hx - clear_dist - cw, hy - clear_dist - cw, (clear_dist + cw) * 2 + cw, (clear_dist + cw) * 2 + cw)
			for p in sewage_cells:
				if zone_rect.has_point(p) and not near_rect.has_point(p):
					return false
			return true

	var walk = func(hx: int, hy: int, d: Vector2i, line_id: int, max_segs: int, turn_p: float, for_dry: bool = false) -> void:
		var idx := 0
		for _step in range(max_segs):
			var placed := false
			var length_options := [rng.randi_range(16, 34), rng.randi_range(12, 20), 10]
			for L in length_options:
				var res: Array = get_seg_rect.call(hx, hy, d, L)
				var r: Rect2i = res[0]
				var nh: Vector2i = res[1]

				if is_inside.call(r, margin + 1) and is_clear_ok.call(r, hx, hy, for_dry) and not is_too_wide.call(r, for_dry):
					var seg_info := {
						"rect": r,
						"axis": "h" if d.y == 0 else "v",
						"line": line_id,
						"idx": idx,
						"kind": "tunnel",
						"junction": false,
						"dry": for_dry
					}
					segs.append(seg_info)
					lines.get_or_add(line_id, []).append(seg_info)

					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							var cp := Vector2i(x, y)
							water_cells[cp] = true
							if for_dry:
								dry_cells[cp] = true
								layout.dry[cp] = true
							else:
								sewage_cells[cp] = true

					idx += 1
					hx = nh.x
					hy = nh.y
					placed = true
					break

			if not placed:
				# Spróbuj skręcić
				var opts: Array[Vector2i] = []
				for nd in DIRS:
					if nd.x * d.x + nd.y * d.y == 0:
						opts.append(nd)
				opts.shuffle()
				var turned := false
				for nd in opts:
					var res: Array = get_seg_rect.call(hx, hy, nd, 12)
					var r: Rect2i = res[0]
					if is_inside.call(r, margin + 1) and is_clear_ok.call(r, hx, hy, for_dry) and not is_too_wide.call(r, for_dry):
						d = nd
						turned = true
						break
				if not turned:
					return
				continue

			if rng.randf() < turn_p:
				var turn_opts: Array[Vector2i] = []
				for nd in DIRS:
					if nd.x * d.x + nd.y * d.y == 0:
						turn_opts.append(nd)
				d = turn_opts[rng.randi() % turn_opts.size()]

	# 1. Pień od lewej krawędzi
	var start_y := rng.randi_range(height / 3, 2 * height / 3)
	walk.call(margin + 1, start_y, Vector2i(1, 0), 0, 10, 0.35)

	# 2. Odnogi
	var n_branch := maxi(4, width * height / 2300)
	var current_line := 1
	var attempts := 0
	while current_line <= n_branch and attempts < 200 and not segs.is_empty():
		attempts += 1
		var p_seg: Dictionary = segs[rng.randi() % segs.size()]
		var r: Rect2i = p_seg["rect"]
		var hx := 0
		var hy := 0
		var d := Vector2i.ZERO

		if p_seg["axis"] == "h":
			if r.size.x < 20:
				continue
			hx = rng.randi_range(r.position.x + 8, r.end.x - 8 - cw)
			hy = r.position.y
			d = Vector2i(0, 1) if rng.randf() < 0.5 else Vector2i(0, -1)
		else:
			if r.size.y < 20:
				continue
			hy = rng.randi_range(r.position.y + 8, r.end.y - 8 - cw)
			hx = r.position.x
			d = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(-1, 0)

		var before_count := segs.size()
		walk.call(hx, hy, d, current_line, rng.randi_range(2, 5), 0.6)
		if segs.size() > before_count:
			p_seg["junction"] = true
			segs[before_count]["junction"] = true
			current_line += 1

	# 3. Osobna, całkowicie niezależna sieć pustego koryta (dry bed)
	if canal_dry_chance > 0.0 and rng.randf() < canal_dry_chance:
		var dry_line_id := 50
		var dry_starts: Array[Array] = [
			[rng.randi_range(width / 4, 3 * width / 4), margin + 1, Vector2i(0, 1)],
			[rng.randi_range(width / 4, 3 * width / 4), height - margin - 1 - cw, Vector2i(0, -1)],
			[width - margin - 1 - cw, rng.randi_range(height / 4, 3 * height / 4), Vector2i(-1, 0)]
		]
		dry_starts.shuffle()
		for s_info in dry_starts:
			var sx: int = s_info[0]
			var sy: int = s_info[1]
			var sd: Vector2i = s_info[2]
			var before_dry := segs.size()
			walk.call(sx, sy, sd, dry_line_id, rng.randi_range(3, 6), 0.35, true)
			if segs.size() > before_dry:
				break
