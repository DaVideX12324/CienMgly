class_name StructuredZoning
extends RefCounted

## Strefowanie wokół sieci liniowej:
## - Kompleksy sal jako spójne wielokąty wzdłuż 2–4 odcinków jednej linii;
## - Zróżnicowane odcinki kanałów: tunnel (obustronny), side (jednostronny), walled (obmurowany bez ścieżek);
## - Zwężenia (pinch) w kompleksach i korytarze serwisowe za ścianą (service);
## - Suche koryto (dry bed).

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

	# 1. Wybór kompleksów sal (ciąg 2–4 odcinków wzdłuż jednej linii)
	var min_cplx_gap := 20
	var cplx_rects: Array[Rect2i] = []
	var max_cplx := maxi(2, width * height / 5500)
	var line_ids: Array = lines.keys()
	MapGeneratorBaseScript.shuffle_array(line_ids, rng)

	var rect_gap = func(a: Rect2i, b: Rect2i) -> int:
		var dx := maxi(0, maxi(a.position.x, b.position.x) - mini(a.end.x, b.end.x))
		var dy := maxi(0, maxi(a.position.y, b.position.y) - mini(a.end.y, b.end.y))
		return maxi(dx, dy)

	var far_from_complexes = func(check_rects: Array[Rect2i]) -> bool:
		for r in check_rects:
			for cr in cplx_rects:
				if rect_gap.call(r, cr) < min_cplx_gap:
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
			var starts: Array[int] = []
			for k in range(ln.size()):
				starts.append(k)
			MapGeneratorBaseScript.shuffle_array(starts, rng)

			var choice: Array = []
			for k0 in starts:
				for n in [4, 3, 2, 1]:
					if k0 + n > ln.size():
						continue
					var run := ln.slice(k0, k0 + n)
					var all_tunnel := true
					for st in run:
						if st["kind"] != "tunnel":
							all_tunnel = false
							break
					if not all_tunnel:
						continue
					if n == 1 and not run[0].get("junction", false):
						continue

					var run_rects: Array[Rect2i] = []
					for st in run:
						run_rects.append(st["rect"])

					if far_from_complexes.call(run_rects):
						choice = run
						break
				if not choice.is_empty():
					break

			if choice.is_empty():
				continue

			var cid := complexes.size()
			for st in choice:
				st["kind"] = "hall"
				st["cid"] = cid
				cplx_rects.append(st["rect"])
			complexes[cid] = {"segs": choice, "mask": {}, "pinch": null}
			placed_any = true

	# 2. Klasyfikacja odcinków poza kompleksami (tunnel, side, walled)
	for st in segs:
		if st["kind"] != "tunnel":
			continue
		if st.get("junction", false):
			st["kind"] = "tunnel"
			continue

		var roll := rng.randf()
		if roll < 0.35:
			st["kind"] = "side"
			st["side"] = rng.randi() % 2
		elif roll < 0.48:
			st["kind"] = "walled"
		else:
			st["kind"] = "tunnel"

	# 3. Pasy ruchu (chodniki w tunelach oraz na odcinkach bocznych)
	for st in segs:
		var kind: String = st["kind"]
		var r: Rect2i = st["rect"]
		var horiz: bool = (st["axis"] == "h")
		var w_lane := lane_width

		if kind == "tunnel":
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

		elif kind == "side":
			var side_idx: int = int(st.get("side", 0))
			if horiz:
				var y_range = range(r.position.y - w_lane, r.position.y) if side_idx == 0 else range(r.end.y, r.end.y + w_lane)
				for y in y_range:
					for x in range(r.position.x, r.end.x):
						var p := Vector2i(x, y)
						if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
							lanes[p] = true
			else:
				var x_range = range(r.position.x - w_lane, r.position.x) if side_idx == 0 else range(r.end.x, r.end.x + w_lane)
				for y in range(r.position.y, r.end.y):
					for x in x_range:
						var p := Vector2i(x, y)
						if not water.has(p) and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
							lanes[p] = true

	# 4. Budowanie wielokątów sal kompleksów wokół odcinków
	var hallm: Dictionary = {}
	var ext_max := 10

	for cid in complexes:
		var cx: Dictionary = complexes[cid]
		var run: Array = cx["segs"]
		var pm: Dictionary = {}

		# Szukanie długiego odcinka na zwężenie (pinch)
		var longs: Array = []
		for st in run:
			var r: Rect2i = st["rect"]
			if maxi(r.size.x, r.size.y) >= 18:
				longs.append(st)

		var pinch = null
		if not longs.is_empty() and rng.randf() < 0.8:
			var pst: Dictionary = longs[rng.randi() % longs.size()]
			var pr: Rect2i = pst["rect"]
			var lo := pr.position.x if pst["axis"] == "h" else pr.position.y
			var hi := pr.end.x - 1 if pst["axis"] == "h" else pr.end.y - 1
			pinch = {
				"seg": pst,
				"k": rng.randi() % 2,
				"p0": lo + 6,
				"p1": hi - 6
			}
		cx["pinch"] = pinch

		for st in run:
			var r: Rect2i = st["rect"]
			var horiz: bool = st["axis"] == "h"
			var lo := r.position.x if horiz else r.position.y
			var hi := r.end.x - 1 if horiz else r.end.y - 1

			var mid := (lo + hi) / 2
			st["bridge_t"] = mid

			var ext := [rng.randi_range(3, 7), rng.randi_range(3, 7)]
			var t := lo
			while t <= hi:
				var t1 := mini(hi, t + rng.randi_range(4, 8) - 1)
				for k in [0, 1]:
					ext[k] = clampi(ext[k] + rng.randi_range(-3, 3), 0, ext_max)

				var want := [ext[0], ext[1]]
				if pinch != null and pinch["seg"] == st:
					var pk: int = pinch["k"]
					if t1 >= pinch["p0"] and t <= pinch["p1"]:
						want[pk] = 0
						want[1 - pk] = maxi(want[1 - pk], 2)
					elif t1 >= pinch["p0"] - 8 and t <= pinch["p1"] + 8:
						want[pk] = maxi(want[pk], (wall_h if horiz else wall_v) + 4)
						want[1 - pk] = maxi(want[1 - pk], 2)

				if t <= mid + 1 and t1 >= mid:
					want[0] = maxi(want[0], 2)
					want[1] = maxi(want[1], 2)

				for k in [0, 1]:
					var e: int = want[k]
					if e < 2:
						continue
					# Wypełnij pas
					for coord in range(t, t1 + 1):
						if horiz:
							var y_start := r.position.y - e if k == 0 else r.end.y
							var y_end := r.position.y if k == 0 else r.end.y + e
							for py in range(y_start, y_end):
								var p := Vector2i(coord, py)
								if p.x >= 2 and p.x < width - 2 and p.y >= 2 and p.y < height - 2:
									pm[p] = true
						else:
							var x_start := r.position.x - e if k == 0 else r.end.x
							var x_end := r.position.x if k == 0 else r.end.x + e
							for px in range(x_start, x_end):
								var p := Vector2i(px, coord)
								if p.x >= 2 and p.x < width - 2 and p.y >= 2 and p.y < height - 2:
									pm[p] = true

				t = t1 + 1

		# Usuń nakładanie wody
		for p in pm.keys():
			if water.has(p):
				pm.erase(p)
			else:
				hallm[p] = true
		cx["mask"] = pm

		# 5. Korytarz za ścianą przy zwężeniu kompleksu (carve_service)
		if pinch != null:
			var pst: Dictionary = pinch["seg"]
			var p0: int = pinch["p0"]
			var p1: int = pinch["p1"]
			var horiz: bool = pst["axis"] == "h"

			var own: Dictionary = {}
			var tgt: Dictionary = {}
			for p in pm:
				var c_val: int = p.x if horiz else p.y
				if c_val < p0 - 2:
					own[p] = true
				elif c_val > p1 + 2:
					tgt[p] = true

			if not own.is_empty() and not tgt.is_empty():
				var own_keys: Array = own.keys()
				var start_p: Vector2i = own_keys[rng.randi() % own_keys.size()]
				var path := StructuredPathfinder.find_corridor_path(
					start_p, tgt, own, hallm, water, width, height, wall_h, wall_v, segs
				)
				if not path.is_empty():
					var carved := StructuredPathfinder.carve_corridor(
						path, hallm, {}, water, layout, width, height, service, true
					)
					for cp in carved:
						service[cp] = true
						layout.service[cp] = true

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
