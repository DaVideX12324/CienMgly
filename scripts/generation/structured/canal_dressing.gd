class_name CanalDressing
extends RefCounted

## Dekorowanie i wyposażenie kanałów (LinearFeatureDressing dla ścieków).
## Pass 5 w architekturze structured:
## - Wyznaczanie krawędzi pod barierki (rail_edges) na brzegach podłogi;
## - Przerwy przy kładkach i strefach prześwitu (bridge_clearance);
## - Zawinięte końce i proste przęsła barierek (Props 6–9 x 4);
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
			# Północny brzeg (nad kanałem poziomy)
			_process_bank(ctx, layout, reservations, r.position.x, r.end.x - 1, r.position.y - 1, true, &"north", rail_runs)
			# Południowy brzeg (pod kanałem poziomym)
			_process_bank(ctx, layout, reservations, r.position.x, r.end.x - 1, r.end.y, true, &"south", rail_runs)
		else:
			# Zachodni brzeg (na lewo od kanału pionowego)
			_process_bank(ctx, layout, reservations, r.position.y, r.end.y - 1, r.position.x - 1, false, &"west", rail_runs)
			# Wschodni brzeg (na prawo od kanału pionowego)
			_process_bank(ctx, layout, reservations, r.position.y, r.end.y - 1, r.end.x, false, &"east", rail_runs)

	# 3. Zapis do layout.rail_edges i aktualizacja zablokowanych komórek
	layout.rail_edges = rail_runs
	for run in rail_runs:
		for cell_info in run["placements"]:
			var p: Vector2i = cell_info["pos"]
			layout.blocked[p] = true

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

		var qualifies := _cell_qualifies_for_rail(ctx, layout, reservations, p)
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
	p: Vector2i
) -> bool:
	# Kratka musi być podłogą w gridzie
	if not GridUtils.is_walkable(ctx.grid, p):
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


static func _pick_rail_tile(index: int, total: int, bank_side: StringName) -> Vector2i:
	match bank_side:
		&"north":
			if index == 0:
				return Vector2i(6, 12)  # lewy zawinięty koniec
			elif index == total - 1:
				return Vector2i(10, 12) # prawy zawinięty koniec
			else:
				return Vector2i(7 + (index % 3), 12) # przęsło poziome góra
		&"south":
			if index == 0:
				return Vector2i(6, 13)  # lewy zawinięty koniec
			elif index == total - 1:
				return Vector2i(10, 13) # prawy zawinięty koniec
			else:
				return Vector2i(7 + (index % 3), 13) # przęsło poziome dół
		&"west":
			if index == 0:
				return Vector2i(4, 9)   # górny zawinięty koniec
			elif index == total - 1:
				return Vector2i(4, 14)  # dolny zawinięty koniec
			else:
				return Vector2i(4, 10 + (index % 4)) # przęsło pionowe lewe
		&"east":
			if index == 0:
				return Vector2i(5, 9)   # górny zawinięty koniec
			elif index == total - 1:
				return Vector2i(5, 14)  # dolny zawinięty koniec
			else:
				return Vector2i(5, 10 + (index % 4)) # przęsło pionowe prawe
	return Vector2i(7, 12)
