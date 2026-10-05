class_name CanalDressing
extends RefCounted

## Dekorowanie i wyposażenie kanałów (LinearFeatureDressing dla ścieków).
## Pass 5 w architekturze structured:
## - Wyznaczanie krawędzi pod barierki (rail_edges) na brzegach podłogi;
## - Przerwy przy kładkach i strefach prześwitu (bridge_clearance);
## - Miedziane barierki ochronne na brzegach (Props 5, 6, 9 x 4);
## - Rezerwacja w StructuredReservations (blocks_movement: true);
## - Blokada ruchu i cięcie navmeshu (layout.blocked).

const StructuredReservations = preload("structured_reservations.gd")
const LinearFeatureLayout = preload("core/linear_feature_layout.gd")


## Główna metoda nakładająca barierki i dressing kanałów
static func apply_dressing(
	ctx: GenerationContext,
	result: MapGeneratorBase.GenerationResult,
	layout: LinearFeatureLayout,
	reservations: StructuredReservations,
	flags: GenerationFlags
) -> Array[Dictionary]:
	var width := ctx.width
	var height := ctx.height
	var grid := ctx.grid
	var rail_runs: Array[Dictionary] = []

	# 1. Wyznaczenie prześwitów kładek (bridge_clearance) — margines 1 kratki przed i za kładką na brzegach
	_compute_bridge_clearances(layout, grid)

	# 2. Wyznaczenie odcinków kwalifikujących się pod barierki
	for seg in layout.segments:
		var r: Rect2i = seg["rect"]
		var axis: String = seg.get("axis", "h")
		if axis == "h":
			# Północny brzeg (nad kanałem poziomym)
			_process_bank(ctx, layout, reservations, r.position.x, r.end.x - 1, r.position.y - 1, true, &"north", rail_runs)
			# Południowy brzeg (pod kanałem poziomym) — kratkę wyżej (r.end.y - 1) na dolnej krawędzi koryta
			_process_bank(ctx, layout, reservations, r.position.x, r.end.x - 1, r.end.y - 1, true, &"south", rail_runs)

	# 3. Zapis do layout.rail_edges i aktualizacja zablokowanych komórek
	layout.rail_edges = rail_runs
	for run in rail_runs:
		for cell_info in run["placements"]:
			var p: Vector2i = cell_info["pos"]
			layout.blocked[p] = true

	# 4. Generowanie czarnych dołów (pits) w suchym korycie
	_place_pits(ctx, layout)

	return rail_runs


static func _compute_bridge_clearances(layout: LinearFeatureLayout, grid: Dictionary) -> void:
	layout.bridge_clearance.clear()
	for b in layout.crossings:
		var cells: Array = b.get("cells", [])
		var is_vert: bool = b.get("vertical", true)

		for p: Vector2i in cells:
			var test_dirs: Array[Vector2i] = []
			if is_vert:
				test_dirs = [Vector2i(0, -1), Vector2i(0, 1)]
			else:
				test_dirs = [Vector2i(-1, 0), Vector2i(1, 0)]

			for d in test_dirs:
				var np := p + d
				if not layout.cells.has(np) and GridUtils.is_walkable(grid, np):
					layout.bridge_clearance[np] = true


static func _process_bank(
	ctx: GenerationContext,
	layout: LinearFeatureLayout,
	reservations: StructuredReservations,
	t_start: int,
	t_end: int,
	fixed_coord: int,
	is_horizontal: bool,
	bank_side: StringName,
	out_runs: Array[Dictionary]
) -> void:
	var current_run: Array[Vector2i] = []

	for t in range(t_start, t_end + 1):
		var p := Vector2i(t, fixed_coord) if is_horizontal else Vector2i(fixed_coord, t)

		var qualifies := _cell_qualifies_for_rail(ctx, layout, reservations, p, bank_side)
		if qualifies:
			current_run.append(p)
		else:
			if current_run.size() >= 2:
				_finalize_run(ctx, layout, reservations, current_run, is_horizontal, bank_side, out_runs)
			current_run = []

	if current_run.size() >= 2:
		_finalize_run(ctx, layout, reservations, current_run, is_horizontal, bank_side, out_runs)


static func _cell_qualifies_for_rail(
	ctx: GenerationContext,
	layout: LinearFeatureLayout,
	reservations: StructuredReservations,
	p: Vector2i,
	bank_side: StringName
) -> bool:
	if bank_side == &"south":
		# Dla południowego brzegu barierka stoi na dolnej krawędzi kanału (r.end.y - 1),
		# więc pod spodem na krawędzi podłogi (p.y + 1) musi być dostępna podłoga z rimem (nie woda kanału!).
		var floor_p := p + Vector2i(0, 1)
		if layout.cells.has(floor_p):
			return false
		if not GridUtils.is_walkable(ctx.grid, floor_p):
			return false
		if layout.crossing_cells.has(floor_p) or layout.bridge_clearance.has(floor_p):
			return false
		if reservations.is_reserved(floor_p):
			var owner := reservations.get_owner(floor_p)
			if owner.begins_with("portal"):
				return false
	else:
		# Północny brzeg (p.y = r.position.y - 1) — sama kratka musi być na podłodze z rimem (nie woda kanału!)
		if layout.cells.has(p):
			return false
		if not GridUtils.is_walkable(ctx.grid, p):
			return false
		if not layout.cells.has(p + Vector2i(0, 1)):
			return false

	# Nie może być w kładce ani w strefie prześwitu wejścia na kładkę
	if layout.crossing_cells.has(p) or layout.bridge_clearance.has(p):
		return false

	# Nie może być już zarezerwowana przez strefę portalu
	if reservations.is_reserved(p):
		var owner := reservations.get_owner(p)
		if owner.begins_with("portal"):
			return false

	return true


static func _finalize_run(
	ctx: GenerationContext,
	layout: LinearFeatureLayout,
	reservations: StructuredReservations,
	cells: Array[Vector2i],
	is_horizontal: bool,
	bank_side: StringName,
	out_runs: Array[Dictionary]
) -> void:
	var run_len := cells.size()
	var placements: Array[Dictionary] = []

	# Atomowa próba rezerwacji całego odcinka barierki
	var claimed := reservations.claim(
		cells,
		&"canal_railing",
		&"RAIL",
		{"blocks_movement": true}
	)

	if not claimed:
		return

	for i in range(run_len):
		var p := cells[i]
		var atlas_tile := _pick_rail_tile(i, run_len, bank_side)

		placements.append({
			"pos": p,
			"source_id": 1,
			"atlas_coords": atlas_tile,
			"bank": bank_side,
			"is_end": (i == 0 or i == run_len - 1)
		})

	out_runs.append({
		"bank": bank_side,
		"axis": "h" if is_horizontal else "v",
		"cells": cells,
		"placements": placements
	})


static func _pick_rail_tile(index: int, total: int, _bank_side: StringName = &"") -> Vector2i:
	if index == 0:
		return Vector2i(5, 4)  # lewy słupek barierki
	elif index == total - 1:
		return Vector2i(9, 4)  # prawy słupek barierki
	else:
		return Vector2i(6, 4)  # przęsło poziome barierki


## Pass 5b: Czarne doły (pits) z krawędzią w suchym korycie
static func _place_pits(ctx: GenerationContext, layout: LinearFeatureLayout) -> void:
	layout.pits.clear()
	layout.pit_cells.clear()
	if layout.dry.is_empty():
		return

	var rng := ctx.rng
	for seg in layout.segments:
		if not seg.get("dry", false):
			continue
		var r: Rect2i = seg["rect"]
		var axis: String = seg.get("axis", "h")

		if axis == "h":
			_place_pits_horizontal(ctx, layout, r, rng)
		else:
			_place_pits_vertical(ctx, layout, r, rng)


static func _place_pits_horizontal(ctx: GenerationContext, layout: LinearFeatureLayout, r: Rect2i, rng: RandomNumberGenerator) -> void:
	var py_start := r.position.y + 1
	var py_end := r.end.y - 1
	if py_end < py_start:
		return
	var pit_h := py_end - py_start + 1

	var safe_cols: Array[int] = []
	var x_min := r.position.x + 2
	var x_max := r.end.x - 3
	for x in range(x_min, x_max + 1):
		var ok := true
		for y in range(py_start, py_end + 1):
			if not layout.dry.has(Vector2i(x, y)):
				ok = false
				break
		if not ok:
			continue
		for cx in range(x - 1, x + 2):
			for cy in range(r.position.y, r.end.y + 1):
				var p := Vector2i(cx, cy)
				if layout.crossing_cells.has(p) or layout.bridge_clearance.has(p):
					ok = false
					break
			if not ok:
				break
		if ok:
			safe_cols.append(x)

	if safe_cols.is_empty():
		return

	var runs: Array[Array] = []
	var cur_run: Array[int] = []
	for x in safe_cols:
		if cur_run.is_empty() or x == cur_run[-1] + 1:
			cur_run.append(x)
		else:
			if cur_run.size() >= 3:
				runs.append(cur_run)
			cur_run = [x]
	if cur_run.size() >= 3:
		runs.append(cur_run)

	for run_x in runs:
		var run_w: int = run_x.size()
		var pit_count := 2 if run_w >= 14 else 1
		var x_cursor: int = run_x[0]
		var x_limit: int = run_x[-1]

		for _i in range(pit_count):
			var rem_w := x_limit - x_cursor + 1
			if rem_w < 3:
				break
			var pw := clampi(rng.randi_range(3, 4), 2, rem_w)
			var max_start := x_limit - pw + 1
			var px := rng.randi_range(x_cursor, mini(x_cursor + 2, max_start))
			var pit_rect := Rect2i(px, py_start, pw, pit_h)
			layout.pits.append(pit_rect)

			for cx in range(px, px + pw):
				for cy in range(py_start, py_end + 1):
					var cp := Vector2i(cx, cy)
					if cy == py_start:
						layout.pit_cells[cp] = &"TOP_B" if rng.randf() < 0.3 else &"TOP"
					elif cy == py_end:
						layout.pit_cells[cp] = &"BOTTOM"
					else:
						layout.pit_cells[cp] = &"VOID"

			x_cursor = px + pw + 3


static func _place_pits_vertical(ctx: GenerationContext, layout: LinearFeatureLayout, r: Rect2i, rng: RandomNumberGenerator) -> void:
	var safe_rows: Array[int] = []
	var y_min := r.position.y + 2
	var y_max := r.end.y - 3

	for y in range(y_min, y_max + 1):
		var ok := true
		for x in range(r.position.x + 1, r.end.x - 1):
			if not layout.dry.has(Vector2i(x, y)):
				ok = false
				break
		if not ok:
			continue
		for cy in range(y - 1, y + 2):
			for cx in range(r.position.x, r.end.x):
				var p := Vector2i(cx, cy)
				if layout.crossing_cells.has(p) or layout.bridge_clearance.has(p):
					ok = false
					break
			if not ok:
				break
		if ok:
			safe_rows.append(y)

	if safe_rows.is_empty():
		return

	var runs: Array[Array] = []
	var cur_run: Array[int] = []
	for y in safe_rows:
		if cur_run.is_empty() or y == cur_run[-1] + 1:
			cur_run.append(y)
		else:
			if cur_run.size() >= 3:
				runs.append(cur_run)
			cur_run = [y]
	if cur_run.size() >= 3:
		runs.append(cur_run)

	for run_y in runs:
		var run_h: int = run_y.size()
		var pit_count := 2 if run_h >= 14 else 1
		var y_cursor: int = run_y[0]
		var y_limit: int = run_y[-1]

		for _i in range(pit_count):
			var rem_h := y_limit - y_cursor + 1
			if rem_h < 3:
				break
			var ph := clampi(rng.randi_range(3, 4), 2, rem_h)
			var max_start := y_limit - ph + 1
			var py := rng.randi_range(y_cursor, mini(y_cursor + 2, max_start))

			var pw := 2
			var px := r.position.x + 1
			if r.size.x >= 4 and rng.randf() < 0.35:
				var full_ok := true
				for ty in range(py, py + ph):
					if not layout.dry.has(Vector2i(r.position.x, ty)) or not layout.dry.has(Vector2i(r.end.x - 1, ty)):
						full_ok = false
						break
				if full_ok:
					pw = r.size.x
					px = r.position.x

			var pit_rect := Rect2i(px, py, pw, ph)
			layout.pits.append(pit_rect)

			for cx in range(px, px + pw):
				for cy in range(py, py + ph):
					var cp := Vector2i(cx, cy)
					if cy == py:
						layout.pit_cells[cp] = &"TOP_B" if rng.randf() < 0.3 else &"TOP"
					elif cy == py + ph - 1:
						layout.pit_cells[cp] = &"BOTTOM"
					else:
						layout.pit_cells[cp] = &"VOID"

			y_cursor = py + ph + 3

