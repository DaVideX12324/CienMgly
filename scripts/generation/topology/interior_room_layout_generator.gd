class_name InteriorRoomLayoutGenerator
extends "res://modules/quiz_rpg/scripts/generation/topology/topology_generator.gd"

const GenProgress = preload("res://modules/quiz_rpg/scripts/generation/core/gen_progress.gd")

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

	# P2. Generowanie komór jaskini (organiczne pokoje z bezpiecznym marginesem)
	var rooms: Array[Rect2i] = []
	var attempts := 0
	var border := 6
	var max_attempts := maxi(300, max_rooms * 25)
	var room_carver := OrganicCaveRoomCarver.new()

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

	# P3. Korytarze jaskiniowe - MST + pętle
	GenProgress.begin(&"corridors")
	var corridor_carver := OrganicCorridorCarver.new()
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

	# P4. Morfologiczne wygładzenie styków komór i korytarzy
	GenProgress.begin(&"smoothing")
	if flags.enable_junction_smoothing:
		GridPreprocessor.run(ctx, [JunctionSmoothingPass.new()])

	# P5–P7. Wymuszenie minimalnej grubości murów i eliminacja ścian 1H
	GridPreprocessor.run(ctx, [
		Remove1hWallsPass.new(),
		WallThicknessPass.new(),
		ShortBulgeFlattenPass.new()
	])

	# P8. Twarda gwarancja spójności
	GenProgress.begin(&"connectivity")
	ConnectivityRepair.repair(ctx, corridor_width)

	# P9. Dedykowane wejście i wyjście
	GenProgress.begin(&"portals")
	var entrance_room_idx := 0
	var exit_room_idx: int = rooms.size() - 1
	if not rooms.is_empty():
		if rooms.size() >= 2:
			var max_dist := 0.0
			for i in range(rooms.size()):
				for j in range(i + 1, rooms.size()):
					var d := Vector2(rooms[i].get_center()).distance_squared_to(Vector2(rooms[j].get_center()))
					if d > max_dist:
						max_dist = d
						entrance_room_idx = i
						exit_room_idx = j

		var entrance_room := rooms[entrance_room_idx]
		var entrance_data: Dictionary = PortalGenerator.carve_portal_alcove(ctx, entrance_room)
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

		# P11. Drugie spłaszczanie wybrzuszeń (przeniesione z apply_cave_tiles KROK 0)
		GridPreprocessor.run(ctx, [ShortBulgeFlattenPass.new()])

	# P11b. Płaskowyże — maska z szumu jako nakładka na podłogę, grid bez zmian. Przed spawnami,
	# żeby SpawnPlanner mógł zsunąć spawny z barier.
	GenProgress.begin(&"plateaus")
	ctx.plateau = PlateauPass.run(ctx, flags)
	result.plateau = ctx.plateau

	# P11c. Obiekty statyczne i interaktywne (ObjectPlanner) — przed wrogami, którzy omijają zajętość.
	result.portal_zone = ctx.portal_zone
	if flags.enable_objects:
		GenProgress.begin(&"objects")
		var catalog := ObjectCatalog.load_path(flags.objects_catalog)
		if not catalog.defs.is_empty():
			# Teren (błoto / trawa) liczony tu, bo obiekty go czytają; planer kafli użyje tych masek
			# (ten sam seed — procedural_level planuje kafle z result.seed_used).
			result.terrain_masks = TerrainMaskPlanner.compute_for_result(result, result.seed_used, flags)
			result.objects = ObjectPlanner.plan_objects(result, catalog, result.seed_used)

	# P12. Spawny wrogów i skrzyń
	GenProgress.begin(&"spawns")
	if not rooms.is_empty():
		SpawnPlanner.plan_spawns(ctx, result, entrance_room_idx, exit_room_idx)

	result.portal_zone = ctx.portal_zone
	result.preprocess_stats = ctx.preprocess_stats
	return ctx
