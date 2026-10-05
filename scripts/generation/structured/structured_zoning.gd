class_name StructuredZoning
extends RefCounted

## Strefowanie wokół sieci liniowej:
## - Kompleksy sal i obmurowane koryta: Hala A -> walled -> Hala B z proto_layout10.py;
## - Korytarze serwisowe w murze (carve_service) łączące Halę A z Halą B;
## - Bramy (gates) przy wyjściu z hali do korytarza serwisowego;
## - Odcinki tunnel z obustronnymi chodnikami dla swobodnej eksploracji i kładek;
## - 100% determinizm i spójność dzięki awaryjnemu fallbackowi do tunnel.

const LinearFeatureLayout = preload("core/linear_feature_layout.gd")
const StructuredReservations = preload("structured_reservations.gd")
const StructuredPathfinder = preload("structured_pathfinder.gd")
const MapGeneratorBaseScript = preload("../map_generator_base.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func build_zoning(
	width: int,
	height: int,
	rng: RandomNumberGenerator,
	layout: LinearFeatureLayout,
	reservations: StructuredReservations,
	cw: int = 4,
	lane_width: int = 3,
	wall_h: int = 5,
	wall_v: int = 4,
	canal_dry_chance: float = 0.4
) -> Dictionary:
	var segs: Array[Dictionary] = layout.segments
	var lines: Dictionary = layout.lines
	var water: Dictionary = layout.cells
	var complexes: Dictionary = layout.complexes
	var lanes: Dictionary = layout.lanes
	var service: Dictionary = layout.service
	var dry: Dictionary = layout.dry

	# 1. Wybór kompleksów sal wzdłuż linii kanałów (wzorzec ['hall', 'walled', 'hall'])
	var min_cplx_gap := 20
	var cplx_rects: Array[Rect2i] = []
	var max_cplx := maxi(2, width * height / 5500)
	var line_ids: Array = lines.keys()
	MapGeneratorBaseScript.shuffle_array(line_ids, rng)

	var rect_gap = func(a: Rect2i, b: Rect2i) -> int:
		var dx := maxi(0, maxi(a.position.x, b.position.x) - mini(a.end.x, b.end.x))
		var dy := maxi(0, maxi(a.position.y, b.position.y) - mini(a.end.y, b.end.y))
		return maxi(dx, dy)

	var far_from_complexes = func(check_rects: Array) -> bool:
		for r in check_rects:
			var rr: Rect2i = r as Rect2i
			for cr in cplx_rects:
				if rect_gap.call(rr, cr) < min_cplx_gap:
					return false
		return true

	var placed_any := true
	while placed_any and complexes.size() < max_cplx:
		placed_any = false
		MapGeneratorBaseScript.shuffle_array(line_ids, rng)
		for lid in line_ids:
			if complexes.size() >= max_cplx:
				break
			var ln: Array = lines[lid]
			var free: Array[int] = []
			for k in range(ln.size() - 2):
				if ln[k]["kind"] == "tunnel":
					free.append(k)
			MapGeneratorBaseScript.shuffle_array(free, rng)

			var choice_k0 := -1
			var choice_pattern: Array[String] = []

			for k0 in free:
				# Wzorzec: sala, [obmurowane | sala, sala]*reps
				var reps_opts := [rng.randi_range(1, 2), 1]
				reps_opts.sort()
				reps_opts.reverse()
				for reps in reps_opts:
					var pattern: Array[String] = ["hall"]
					for _r in range(reps):
						pattern.append("walled" if rng.randf() < 0.67 else "hall")
						pattern.append("hall")
					while pattern.size() > ln.size() - k0:
						pattern.pop_back()
					while not pattern.is_empty() and pattern.back() != "hall":
						pattern.pop_back()
					if pattern.size() < 3:
						continue
					var all_tunnel := true
					for i in range(pattern.size()):
						if ln[k0 + i]["kind"] != "tunnel":
							all_tunnel = false
							break
					if not all_tunnel:
						continue
					var run_rects: Array[Rect2i] = []
					for i in range(pattern.size()):
						run_rects.append(ln[k0 + i]["rect"])
					if not far_from_complexes.call(run_rects):
						continue
					choice_k0 = k0
					choice_pattern = pattern
					break
				if choice_k0 != -1:
					break

			if choice_k0 == -1:
				continue

			placed_any = true
			var cid: int = complexes.size()
			var cplx_segs: Array = []
			for i in range(choice_pattern.size()):
				var st: Dictionary = ln[choice_k0 + i]
				var kind: String = choice_pattern[i]
				st["kind"] = kind
				cplx_rects.append(st["rect"])
				cplx_segs.append(st)
				if kind == "hall":
					st["cid"] = cid
				else:
					# walled
					st["side"] = rng.randi() % 2
					st["prev"] = ln[choice_k0 + i - 1]
					st["next"] = ln[choice_k0 + i + 1]
					st["cid"] = cid
					for nb in [st["prev"], st["next"]]:
						var need: Dictionary = nb.get_or_add("need", {})
						need[st["side"]] = true

			complexes[cid] = {"segs": cplx_segs, "mask": {}, "members": []}

	# 2. Pozostałe węzły: czasem pojedyncza sala z kanałem
	for s_ in segs:
		if s_["kind"] == "tunnel" and s_.get("junction", false) and rng.randf() < 0.12 and far_from_complexes.call([s_["rect"]]):
			cplx_rects.append(s_["rect"])
			var cid: int = complexes.size()
			s_["kind"] = "hall"
			s_["cid"] = cid
			complexes[cid] = {"segs": [s_], "mask": {}, "members": []}

	# 3. Pasy ruchu (chodniki w tunelach)
	for st in segs:
		if st["kind"] != "tunnel":
			continue
		var r: Rect2i = st["rect"]
		var horiz: bool = (st["axis"] == "h")
		var w_lane := lane_width

		if horiz:
			for y in range(r.position.y - w_lane, r.position.y):
				for x in range(r.position.x, r.end.x):
					var p := Vector2i(x, y)
					if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
						lanes[p] = true
			for y in range(r.end.y, r.end.y + w_lane):
				for x in range(r.position.x, r.end.x):
					var p := Vector2i(x, y)
					if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
						lanes[p] = true
		else:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x - w_lane, r.position.x):
					var p := Vector2i(x, y)
					if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
						lanes[p] = true
			for y in range(r.position.y, r.end.y):
				for x in range(r.end.x, r.end.x + w_lane):
					var p := Vector2i(x, y)
					if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
						lanes[p] = true

	# 4. Budowanie sal kompleksów (Hale kanałowe z rozszerzeniem pod korytarze serwisowe)
	var hallm: Dictionary = {}
	var hall_cid_map: Dictionary = {}

	for s in segs:
		if s["kind"] != "hall":
			continue
		var r: Rect2i = s["rect"]
		var horiz: bool = (s["axis"] == "h")
		var x0 := r.position.x
		var y0 := r.position.y
		var x1 := r.end.x - 1
		var y1 := r.end.y - 1
		var cid: int = int(s.get("cid", -1))
		var need: Dictionary = s.get("need", {})

		# Własna woda tego odcinka (oraz stykających się bezpośrednio odcinków sieci)
		var own_water: Dictionary = {}
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				own_water[Vector2i(cx, cy)] = true
		for o in segs:
			var orc: Rect2i = o["rect"]
			if not (orc.end.x < x0 - 1 or orc.position.x > x1 + 1 or orc.end.y < y0 - 1 or orc.position.y > y1 + 1):
				for cy in range(orc.position.y, orc.end.y):
					for cx in range(orc.position.x, orc.end.x):
						own_water[Vector2i(cx, cy)] = true

		var fit_side = func(want: int, rect_func: Callable) -> int:
			var e := 0
			while e < want:
				var test_r: Rect2i = rect_func.call(e + 1)
				if test_r.position.x < 3 or test_r.position.y < 3 or test_r.end.x >= width - 3 or test_r.end.y >= height - 3:
					break
				var collides := false
				for ty in range(test_r.position.y, test_r.end.y):
					for tx in range(test_r.position.x, test_r.end.x):
						var tp := Vector2i(tx, ty)
						if water.has(tp) and not own_water.has(tp):
							collides = true
							break
						if hall_cid_map.has(tp) and hall_cid_map[tp] != cid:
							collides = true
							break
					if collides:
						break
				if collides:
					break
				e += 1
			return e

		var a: int = 0
		var b: int = 0
		var hr: Rect2i
		if horiz:
			var want_a := maxi(rng.randi_range(3, 8), 9 if need.get(0, false) else 0)
			var want_b := maxi(rng.randi_range(3, 8), 9 if need.get(1, false) else 0)
			a = fit_side.call(want_a, func(e: int) -> Rect2i:
				return Rect2i(x0, y0 - lane_width - e, x1 - x0 + 1, e)
			)
			b = fit_side.call(want_b, func(e: int) -> Rect2i:
				return Rect2i(x0, y1 + 1 + lane_width, x1 - x0 + 1, e)
			)
			hr = Rect2i(x0, y0 - lane_width - a, x1 - x0 + 1, (y1 - y0 + 1) + 2 * lane_width + a + b)
		else:
			var want_a := maxi(rng.randi_range(3, 7), 6 if need.get(0, false) else 0)
			var want_b := maxi(rng.randi_range(3, 7), 6 if need.get(1, false) else 0)
			a = fit_side.call(want_a, func(e: int) -> Rect2i:
				return Rect2i(x0 - lane_width - e, y0, e, y1 - y0 + 1)
			)
			b = fit_side.call(want_b, func(e: int) -> Rect2i:
				return Rect2i(x1 + 1 + lane_width, y0, e, y1 - y0 + 1)
			)
			hr = Rect2i(x0 - lane_width - a, y0, (x1 - x0 + 1) + 2 * lane_width + a + b, y1 - y0 + 1)

		s["hall_rect"] = hr
		var s_hall_mask: Dictionary = {}
		for hy in range(hr.position.y, hr.end.y):
			for hx in range(hr.position.x, hr.end.x):
				var hp := Vector2i(hx, hy)
				for dy in range(-wall_v - 1, wall_v + 2):
					for dx in range(-wall_h - 1, wall_h + 2):
						var mp := hp + Vector2i(dx, dy)
						if not hall_cid_map.has(mp):
							hall_cid_map[mp] = cid
				if not water.has(hp):
					hallm[hp] = true
					s_hall_mask[hp] = true
					if complexes.has(cid):
						complexes[cid]["mask"][hp] = true

		s["hall_mask"] = s_hall_mask
		if complexes.has(cid):
			complexes[cid]["members"].append(hr)

	# 5. Korytarze za ścianą wzdłuż obmurowanych koryt (carve_service)
	for st in segs:
		if st["kind"] == "walled":
			var success := _carve_service(st, hallm, water, lanes, service, layout, width, height, wall_h, wall_v, rng)
			if not success:
				# Druga strona koryta
				st["side"] = 1 - int(st.get("side", 0))
				success = _carve_service(st, hallm, water, lanes, service, layout, width, height, wall_h, wall_v, rng)
			if not success:
				# Bez korytarza obok koryto nie może zostać obmurowane -> tunel
				st["kind"] = "tunnel"
				var r: Rect2i = st["rect"]
				var horiz: bool = (st["axis"] == "h")
				var w_lane := lane_width
				if horiz:
					for y in range(r.position.y - w_lane, r.position.y):
						for x in range(r.position.x, r.end.x):
							var p := Vector2i(x, y)
							if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
								lanes[p] = true
					for y in range(r.end.y, r.end.y + w_lane):
						for x in range(r.position.x, r.end.x):
							var p := Vector2i(x, y)
							if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
								lanes[p] = true
				else:
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x - w_lane, r.position.x):
							var p := Vector2i(x, y)
							if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
								lanes[p] = true
					for y in range(r.position.y, r.end.y):
						for x in range(r.end.x, r.end.x + w_lane):
							var p := Vector2i(x, y)
							if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
								lanes[p] = true

	# Rezerwacja pasów ruchu i wody w StructuredReservations
	var water_cells_arr: Array[Vector2i] = []
	for p in water:
		water_cells_arr.append(p)
	reservations.claim(water_cells_arr, &"linear_water", &"LINEAR", {"blocks_movement": true})

	var lane_cells_arr: Array[Vector2i] = []
	for p in lanes:
		lane_cells_arr.append(p)
	reservations.claim(lane_cells_arr, &"lanes", &"LANE", {"blocks_movement": false})

	return {
		"hallm": hallm,
		"lanes": lanes,
		"dry": dry
	}


## Drąży korytarz za ścianą wzdłuż obmurowanego koryta (Hala A -> serwis -> Hala B) z bramą przy Hali A.
static func _carve_service(
	st: Dictionary,
	hallm: Dictionary,
	water: Dictionary,
	lanes: Dictionary,
	service: Dictionary,
	layout: LinearFeatureLayout,
	width: int,
	height: int,
	wall_h: int,
	wall_v: int,
	rng: RandomNumberGenerator
) -> bool:
	var prev_seg: Dictionary = st.get("prev", {})
	var next_seg: Dictionary = st.get("next", {})
	var own: Dictionary = prev_seg.get("hall_mask", {})
	var tgt: Dictionary = next_seg.get("hall_mask", {})
	if own.is_empty() or tgt.is_empty():
		return false

	var r: Rect2i = st["rect"]
	var horiz: bool = (st["axis"] == "h")
	var k: int = int(st.get("side", 0))

	# 1. Filtruj punkty startowe w Hall A na wybranej stronie k, oddalone od wody
	var candidates: Array[Vector2i] = []
	for p: Vector2i in own:
		var on_side := false
		if horiz:
			on_side = (p.y < r.position.y if k == 0 else p.y >= r.end.y)
		else:
			on_side = (p.x < r.position.x if k == 0 else p.x >= r.end.x)
		if not on_side:
			continue

		var near_water := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if water.has(p + Vector2i(dx, dy)):
					near_water = true
					break
			if near_water:
				break
		if not near_water:
			candidates.append(p)

	if candidates.is_empty():
		return false

	MapGeneratorBaseScript.shuffle_array(candidates, rng)

	# 2. Przygotuj strefy ograniczeń: extra_forb, zone_skip, bias
	var extra_forb: Dictionary = {}
	var ef_rect := Rect2i(
		r.position.x - (wall_h + 1),
		r.position.y - (wall_v + 1),
		r.size.x + 2 * (wall_h + 1),
		r.size.y + 2 * (wall_v + 1)
	)
	for ey in range(ef_rect.position.y, ef_rect.end.y):
		for ex in range(ef_rect.position.x, ef_rect.end.x):
			var ep := Vector2i(ex, ey)
			if not own.has(ep) and not tgt.has(ep):
				extra_forb[ep] = true

	var zone_skip: Dictionary = {}
	var zs_rect := Rect2i(
		r.position.x - (wall_h + 16),
		r.position.y - (wall_v + 16),
		r.size.x + 2 * (wall_h + 16),
		r.size.y + 2 * (wall_v + 16)
	)
	for zy in range(zs_rect.position.y, zs_rect.end.y):
		for zx in range(zs_rect.position.x, zs_rect.end.x):
			var zp := Vector2i(zx, zy)
			if not water.has(zp) or r.has_point(zp):
				zone_skip[zp] = true

	# Bias: preferuj stronę k wokół kanału (koszt 0), kara za złą stronę (+50)
	var bias: Dictionary = {}
	var bias_rect := Rect2i(
		r.position.x - 20,
		r.position.y - 20,
		r.size.x + 40,
		r.size.y + 40
	)
	for by in range(maxi(0, bias_rect.position.y), mini(height, bias_rect.end.y)):
		for bx in range(maxi(0, bias_rect.position.x), mini(width, bias_rect.end.x)):
			var bp := Vector2i(bx, by)
			var on_side := false
			if horiz:
				on_side = (bp.y < r.position.y if k == 0 else bp.y >= r.end.y)
			else:
				on_side = (bp.x < r.position.x if k == 0 else bp.x >= r.end.x)
			if not on_side:
				bias[bp] = 50

	# 3. Zbuduj sumaryczną podłogę na ten moment (hallm + lanes + service + water)
	var floor_cells: Dictionary = {}
	for p in water:
		floor_cells[p] = true
	for p in lanes:
		floor_cells[p] = true
	for p in hallm:
		floor_cells[p] = true
	for p in service:
		floor_cells[p] = true

	# 4. Próba znalezienia ścieżki z kilku losowych kandydatów
	var path: Array[Vector2i] = []
	var attempts := mini(5, candidates.size())
	for i in range(attempts):
		var start_p: Vector2i = candidates[i]
		path = StructuredPathfinder.find_corridor_path(
			start_p, tgt, own, floor_cells, water, width, height,
			wall_h, wall_v, layout.segments, 3, bias, Rect2i(), extra_forb, 120, zone_skip
		)
		if not path.is_empty():
			break

	if path.is_empty():
		return false

	# 5. Wydrąż korytarz 3x3
	var carved := StructuredPathfinder.carve_corridor(
		path, floor_cells, {}, water, layout, width, height, service, true
	)
	for cp in carved:
		if not own.has(cp) and not tgt.has(cp):
			service[cp] = true
			layout.service[cp] = true

	# 6. Postaw bramę przy wyjściu z Hali A
	var out: Array[Vector2i] = []
	for p in path:
		if not own.has(p):
			out.append(p)

	if not out.is_empty():
		var gx := out[0].x
		var gy := out[0].y
		var nx := out[1].x if out.size() > 1 else gx
		var ny := out[1].y if out.size() > 1 else gy
		var gate_cells: Array[Vector2i] = []
		if nx != gx:
			# Ruch poziomy -> brama pionowa
			gate_cells = [Vector2i(gx, gy - 1), Vector2i(gx, gy), Vector2i(gx, gy + 1)]
		else:
			# Ruch pionowy -> brama pozioma
			gate_cells = [Vector2i(gx - 1, gy), Vector2i(gx, gy), Vector2i(gx + 1, gy)]
		layout.gates.append({
			"cells": gate_cells,
			"pos": Vector2i(gx, gy),
			"horizontal": (nx == gx)
		})

	return true
