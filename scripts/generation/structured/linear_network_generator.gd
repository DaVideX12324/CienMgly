class_name LinearNetworkGenerator
extends RefCounted

## Generator sieci liniowej (pień + odnogi ze skrętami).
## Odpowiednik etapu 1 z proto_layout11.py:
## - Pień od lewej krawędzi w prawo ze sporadycznymi skrętami;
## - Odnogi odchodzące pod kątem prostym od istniejących odcinków;
## - Kontrola szerokości (żaden fragment nie może być szerszy niż canal_width, brak plam 5x5);
## - Kontrola minimalnego odstępu CLEAR między odnogami.

const SeededNoise = preload("../core/seeded_noise.gd")
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

	# 0. Szum jak heightmap, ale tylko dwa poziomy: 0 (ścieki) i 1 (koryto puste)
	var noise: FastNoiseLite = SeededNoise.create(hash([rng.seed, "canal_heightmap_2levels"]), 0.005)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2

	var threshold: float = 0.0
	if canal_dry_chance <= 0.0:
		threshold = 999.0
	elif canal_dry_chance >= 1.0:
		threshold = 0.0
	else:
		threshold = lerpf(0.4, -0.4, canal_dry_chance)

	var get_zone_level = func(p: Vector2i) -> int:
		if canal_dry_chance <= 0.0:
			return 0
		var h: float = noise.get_noise_2d(float(p.x), float(p.y))
		return 1 if h >= threshold else 0

	var is_dry_zone = func(p: Vector2i) -> bool:
		return get_zone_level.call(p) == 1

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

	var is_zone_ok = func(r: Rect2i, for_dry: bool) -> bool:
		if canal_dry_chance <= 0.0:
			return not for_dry
		var target_lvl := 1 if for_dry else 0
		var buf := 4
		var check_rect := Rect2i(r.position.x - buf, r.position.y - buf, r.size.x + buf * 2, r.size.y + buf * 2)
		var check_pts: Array[Vector2i] = [
			check_rect.position,
			Vector2i(check_rect.end.x - 1, check_rect.position.y),
			Vector2i(check_rect.position.x, check_rect.end.y - 1),
			Vector2i(check_rect.end.x - 1, check_rect.end.y - 1),
			check_rect.get_center()
		]
		if check_rect.size.x > 16:
			check_pts.append(Vector2i(check_rect.position.x + check_rect.size.x / 2, check_rect.position.y))
			check_pts.append(Vector2i(check_rect.position.x + check_rect.size.x / 2, check_rect.end.y - 1))
		if check_rect.size.y > 16:
			check_pts.append(Vector2i(check_rect.position.x, check_rect.position.y + check_rect.size.y / 2))
			check_pts.append(Vector2i(check_rect.end.x - 1, check_rect.position.y + check_rect.size.y / 2))

		for p in check_pts:
			if int(get_zone_level.call(p)) != target_lvl:
				return false
		return true

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
			# Bezwzględny brak jakichkolwiek ścieków w buforze clear_dist kratek!
			for p in sewage_cells:
				if zone_rect.has_point(p):
					return false
			var near_rect := Rect2i(hx - clear_dist - cw, hy - clear_dist - cw, (clear_dist + cw) * 2 + cw, (clear_dist + cw) * 2 + cw)
			for p in dry_cells:
				if zone_rect.has_point(p) and not near_rect.has_point(p):
					return false
			return true
		else:
			# Bezwzględny brak jakichkolwiek suchych komórek w buforze clear_dist kratek!
			for p in dry_cells:
				if zone_rect.has_point(p):
					return false
			var near_rect := Rect2i(hx - clear_dist - cw, hy - clear_dist - cw, (clear_dist + cw) * 2 + cw, (clear_dist + cw) * 2 + cw)
			for p in sewage_cells:
				if zone_rect.has_point(p) and not near_rect.has_point(p):
					return false
			return true

	var walk = func(hx: int, hy: int, d: Vector2i, line_id: int, max_segs: int, turn_p: float, for_dry: bool = false) -> int:
		var idx := 0
		for _step in range(max_segs):
			var placed := false
			var length_options := [rng.randi_range(16, 28), rng.randi_range(12, 18), 10]
			for L in length_options:
				var res: Array = get_seg_rect.call(hx, hy, d, L)
				var r: Rect2i = res[0]
				var nh: Vector2i = res[1]

				if is_inside.call(r, margin + 1) and is_zone_ok.call(r, for_dry) and is_clear_ok.call(r, hx, hy, for_dry) and not is_too_wide.call(r, for_dry):
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
					if is_inside.call(r, margin + 1) and is_zone_ok.call(r, for_dry) and is_clear_ok.call(r, hx, hy, for_dry) and not is_too_wide.call(r, for_dry):
						d = nd
						turned = true
						break
				if not turned:
					return idx
				continue

			if rng.randf() < turn_p:
				var turn_opts: Array[Vector2i] = []
				for nd in DIRS:
					if nd.x * d.x + nd.y * d.y == 0:
						turn_opts.append(nd)
				d = turn_opts[rng.randi() % turn_opts.size()]
		return idx

	# 1. Podział na siatkę sektorów i pnie magistral
	var cols: int = clampi(int(ceil(float(width) / 85.0)), 1, 3)
	var rows: int = clampi(int(ceil(float(height) / 85.0)), 1, 3)
	var current_line := 0

	for r_idx in range(rows):
		for c_idx in range(cols):
			var x0 := c_idx * width / cols + margin + 4
			var x1 := (c_idx + 1) * width / cols - margin - 4
			var y0 := r_idx * height / rows + margin + 4
			var y1 := (r_idx + 1) * height / rows - margin - 4

			var found_start := false
			for _att in range(30):
				var sx := rng.randi_range(x0 + 6, x1 - 6)
				var sy := rng.randi_range(y0 + 6, y1 - 6)
				var p_dry: bool = bool(is_dry_zone.call(Vector2i(sx, sy)))
				var dirs_test: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				dirs_test.shuffle()
				for sd in dirs_test:
					var test_res: Array = get_seg_rect.call(sx, sy, sd, 16)
					var tr: Rect2i = test_res[0]
					if is_inside.call(tr, margin + 1) and is_zone_ok.call(tr, p_dry) and is_clear_ok.call(tr, sx, sy, p_dry) and not is_too_wide.call(tr, p_dry):
						var placed_segs: int = int(walk.call(sx, sy, sd, current_line, 8, 0.35, p_dry))
						if placed_segs > 0:
							current_line += 1
							found_start = true
							break
				if found_start:
					break

	# 2. Odnogi
	var n_branch := maxi(6, width * height / 1800)
	var attempts := 0
	while current_line <= n_branch and attempts < 200 and not segs.is_empty():
		attempts += 1
		var p_seg: Dictionary = segs[rng.randi() % segs.size()]
		var r: Rect2i = p_seg["rect"]
		var for_dry: bool = p_seg["dry"]
		var hx := 0
		var hy := 0
		var d := Vector2i.ZERO

		if p_seg["axis"] == "h":
			if r.size.x < 16:
				continue
			hx = rng.randi_range(r.position.x + 4, r.end.x - 4 - cw)
			hy = r.position.y
			d = Vector2i(0, 1) if rng.randf() < 0.5 else Vector2i(0, -1)
		else:
			if r.size.y < 16:
				continue
			hy = rng.randi_range(r.position.y + 4, r.end.y - 4 - cw)
			hx = r.position.x
			d = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(-1, 0)

		var before_count := segs.size()
		walk.call(hx, hy, d, current_line, rng.randi_range(2, 5), 0.5, for_dry)
		if segs.size() > before_count:
			p_seg["junction"] = true
			segs[before_count]["junction"] = true
			current_line += 1
