class_name InteriorRoomLayoutGenerator
extends "topology_generator.gd"

const GenProgress = preload("../core/gen_progress.gd")
const DiagonalTouchPassScript = preload("../preprocess/diagonal_touch_pass.gd")
const SlopeThicknessPassScript = preload("../preprocess/slope_thickness_pass.gd")
const GridRoomLayoutScript = preload("grid_room_layout.gd")

## Pełna orkiestracja P1–P12 zgodnie z tabelą w §12.4
static func generate_layout(
	width: int,
	height: int,
	seed_val: int,
	min_room_size: int,
	max_room_size: int,
	max_rooms: int,
	corridor_width: int,
	flags: GenerationFlags,
	result: MapGeneratorBase.GenerationResult
) -> GenerationContext:
	GenProgress.begin(&"rooms")
	var ctx := GenerationContext.new()
	ctx.flags = flags
	ctx.seed_value = seed_val
	ctx.width = width
	ctx.height = height
	ctx.rng = MapGeneratorBase.create_rng(seed_val)
	ctx.grid = result.grid
	result.seed_used = ctx.rng.seed

	var rng := ctx.rng

	# P1. Wypełnij siatkę ścianami
	for y in range(height):
		for x in range(width):
			ctx.grid[Vector2i(x, y)] = CellType.WALL

	var rooms: Array[Rect2i] = []
	if flags.room_layout == "grid":
		# P2–P3 (siatka): pokoje w komórkach + korytarze między sąsiadami (GridRoomLayout).
		rooms = GridRoomLayoutScript.carve(ctx, min_room_size, max_room_size, corridor_width, flags)
		ctx.rooms = rooms
		result.rooms = rooms
		GenProgress.end(&"rooms")
		GenProgress.begin(&"corridors")
		GenProgress.end(&"corridors")
	else:
		# P2. Generowanie komór jaskini (organiczne pokoje z bezpiecznym marginesem)
		var attempts := 0
		var border := 6
		var max_attempts := maxi(300, max_rooms * 25)
		var room_carver := RoomCarverFactory.create(StringName(flags.room_shape))

		while rooms.size() < max_rooms and attempts < max_attempts:
			attempts += 1
			var rw := rng.randi_range(min_room_size, max_room_size)
			var rh := rng.randi_range(min_room_size, max_room_size)
			var rx := rng.randi_range(border, width - rw - border)
			var ry := rng.randi_range(border, height - rh - border)
			var new_room := Rect2i(rx, ry, rw, rh)

			var overlaps := false
			var expanded := Rect2i(rx - 5, ry - 6, rw + 10, rh + 12)
			for existing in rooms:
				if expanded.intersects(existing):
					overlaps = true
					break

			if overlaps:
				continue

			rooms.append(new_room)
			room_carver.carve(ctx, new_room)

		ctx.rooms = rooms
		result.rooms = rooms

		GenProgress.end(&"rooms")

		# P3. Korytarze jaskiniowe - MST + pętle
		GenProgress.begin(&"corridors")
		var corridor_carver := CorridorCarverFactory.create(StringName(flags.corridor_shape), flags)
		if "corner_room_size" in corridor_carver:
			corridor_carver.corner_room_size = Vector2i(min_room_size, max_room_size)
		if rooms.size() >= 2:
			var connected_indices: Array[int] = [0]
			var unconnected_indices: Array[int] = []
			for i in range(1, rooms.size()):
				unconnected_indices.append(i)

			while not unconnected_indices.is_empty():
				var best_dist := INF
				var best_conn := -1
				var best_unconn := -1
				var best_unconn_idx := -1

				for c_idx in connected_indices:
					var c_center := rooms[c_idx].get_center()
					for u_i in range(unconnected_indices.size()):
						var u_idx := unconnected_indices[u_i]
						var u_center := rooms[u_idx].get_center()
						var dist := Vector2(c_center).distance_squared_to(Vector2(u_center))
						if dist < best_dist:
							best_dist = dist
							best_conn = c_idx
							best_unconn = u_idx
							best_unconn_idx = u_i

				if best_unconn_idx != -1:
					corridor_carver.carve(ctx, rooms[best_conn].get_center(), rooms[best_unconn].get_center(), corridor_width)
					connected_indices.append(best_unconn)
					unconnected_indices.remove_at(best_unconn_idx)

			# Dodatkowe korytarze pętlowe
			var extra_loops := mini(3, floori(rooms.size() / 3.0))
			var loop_attempts := 0
			var loops_added := 0
			while loops_added < extra_loops and loop_attempts < 25:
				loop_attempts += 1
				var idx_a := rng.randi() % rooms.size()
				var idx_b := rng.randi() % rooms.size()
				if idx_a != idx_b:
					var d := Vector2(rooms[idx_a].get_center()).distance_to(Vector2(rooms[idx_b].get_center()))
					if d < maxf(width, height) * 0.45:
						corridor_carver.carve(ctx, rooms[idx_a].get_center(), rooms[idx_b].get_center(), corridor_width)
						loops_added += 1

		# Pokoje wycięte na zakrętach korytarzy L (corridor_corner_room_chance) — pełnoprawne pokoje (spawny).
		if "carved_rooms" in corridor_carver:
			rooms.append_array(corridor_carver.carved_rooms)
		GenProgress.end(&"corridors")

	# P4. Morfologiczne wygładzenie styków komór i korytarzy
	GenProgress.begin(&"smoothing")
	if flags.enable_junction_smoothing:
		GridPreprocessor.run(ctx, [JunctionSmoothingPass.new()])
	GenProgress.sub(0.6)

	# P5–P7. Wymuszenie minimalnej grubości murów i eliminacja ścian 1H
	GridPreprocessor.run(ctx, [
		Remove1hWallsPass.new(),
		WallThicknessPass.new()
	])

	GenProgress.end(&"smoothing")

	# P8. Twarda gwarancja spójności
	GenProgress.begin(&"connectivity")
	ConnectivityRepair.repair(ctx, corridor_width)

	GenProgress.end(&"connectivity")

	# P9. Dedykowane wejście i wyjście
	GenProgress.begin(&"portals")
	var entrance_room_idx := 0
	var exit_room_idx: int = rooms.size() - 1
	var center_entrance := flags.entrance_mode == "center"
	if not rooms.is_empty():
		if center_entrance:
			# Wejście w pokoju najbliżej środka mapy (spośród pokoi o boku >= CENTER_ENTRANCE_MIN_SIDE, gdy
			# są — mniejsze wyglądają jak kawałek korytarza), wyjście w pokoju najdalszym od niego.
			const CENTER_ENTRANCE_MIN_SIDE := 10
			var map_center := Vector2(width, height) * 0.5
			var best := INF
			for pass_i in range(2):
				for i in range(rooms.size()):
					if pass_i == 0 and mini(rooms[i].size.x, rooms[i].size.y) < CENTER_ENTRANCE_MIN_SIDE:
						continue
					var d := Vector2(rooms[i].get_center()).distance_squared_to(map_center)
					if d < best:
						best = d
						entrance_room_idx = i
				if best < INF:
					break
			var far := -1.0
			for i in range(rooms.size()):
				var d := Vector2(rooms[i].get_center()).distance_squared_to(Vector2(rooms[entrance_room_idx].get_center()))
				if i != entrance_room_idx and d > far:
					far = d
					exit_room_idx = i
		elif rooms.size() >= 2:
			var max_dist := 0.0
			for i in range(rooms.size()):
				for j in range(i + 1, rooms.size()):
					var d := Vector2(rooms[i].get_center()).distance_squared_to(Vector2(rooms[j].get_center()))
					if d > max_dist:
						max_dist = d
						entrance_room_idx = i
						exit_room_idx = j

		var entrance_room := rooms[entrance_room_idx]
		var entrance_data: Dictionary = PortalGenerator.carve_portal_in_room(ctx, entrance_room) if center_entrance \
			else PortalGenerator.carve_portal_alcove(ctx, entrance_room)
		ctx.entrance_pos = entrance_data["center"] as Vector2i
		result.entrance_pos = ctx.entrance_pos
		result.player_spawn = ctx.entrance_pos
		result.entrance_zone = entrance_data["cells"] as Array[Vector2i]
		for p in result.entrance_zone:
			ctx.grid[p] = CellType.ENTRANCE
			ctx.portal_zone[p] = true

		var exit_room := rooms[exit_room_idx]
		var exit_data: Dictionary = PortalGenerator.carve_portal_alcove(ctx, exit_room, int(entrance_data["edge"]))
		ctx.exit_pos = exit_data["center"] as Vector2i
		result.exit_pos = ctx.exit_pos
		result.exit_zone = exit_data["cells"] as Array[Vector2i]
		for p in result.exit_zone:
			ctx.grid[p] = CellType.EXIT
			ctx.portal_zone[p] = true

		# Dodatkowa gwarancja spójności po wycięciu portali
		ConnectivityRepair.repair(ctx, corridor_width)

	# P10. Pre-pass normalizacji siatki (przeniesiony z apply_cave_tiles KROK 0)
	if flags.enable_grid_cleanup:
		GridPreprocessor.run_convergent(ctx, [
			SpikeCleanupPass.new(),
			ThinBridgeCleanupPass.new(),
			StaircaseNormalizerPass.new()
		], 4)

	# P11a. Wąskie wypustki 2H przy licu 3H+ -> 3H albo usunięte; potem skośne styki podłóg przez
	# ścianę (100/000/001), które podniesienie wypustki mogło odtworzyć po WallThicknessPass.
	# Na koniec ukośne ściany (skosy) o grubości 3 -> 4 (SlopeThicknessPass).
	GridPreprocessor.run(ctx, [ShortLedgeRaisePass.new(), DiagonalTouchPassScript.new(), SlopeThicknessPassScript.new()])

	# P11b. Płaskowyże — maska z szumu jako nakładka na podłogę, grid bez zmian. Przed spawnami,
	# żeby SpawnPlanner mógł zsunąć spawny z barier.
	GenProgress.end(&"portals")
	GenProgress.begin(&"plateaus")
	ctx.plateau = PlateauPass.run(ctx, flags)
	result.plateau = ctx.plateau
	GenProgress.end()  # plateaus albo plateau_stairs (PlateauPass.run zaczyna schody sam)

	# P11c. Obiekty statyczne i interaktywne (ObjectPlanner) — przed wrogami, którzy omijają zajętość.
	result.portal_zone = ctx.portal_zone
	if flags.enable_objects:
		GenProgress.begin(&"terrain")
		var catalog := ObjectCatalog.load_path(flags.objects_catalog)
		if not catalog.defs.is_empty():
			# Teren (błoto / trawa) liczony tu, bo obiekty go czytają; planer kafli użyje tych masek
			# (ten sam seed — procedural_level planuje kafle z result.seed_used).
			result.terrain_masks = TerrainMaskPlanner.compute_for_result(result, result.seed_used, flags)
			GenProgress.end(&"terrain")
			GenProgress.begin(&"objects")
			result.objects = ObjectPlanner.plan_objects(result, catalog, result.seed_used)
		GenProgress.end()  # terrain (pusty katalog) albo objects

	# P12. Spawny wrogów i skrzyń
	GenProgress.begin(&"spawns")
	if not rooms.is_empty():
		SpawnPlanner.plan_spawns(ctx, result, entrance_room_idx, exit_room_idx)
	GenProgress.end(&"spawns")

	result.portal_zone = ctx.portal_zone
	result.preprocess_stats = ctx.preprocess_stats
	return ctx
