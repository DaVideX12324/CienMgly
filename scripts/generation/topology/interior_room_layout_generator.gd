class_name InteriorRoomLayoutGenerator
extends "res://modules/quiz_rpg/scripts/generation/topology/topology_generator.gd"

const MapGeneratorBase = preload("res://modules/quiz_rpg/scripts/generation/map_generator_base.gd")
const CellType = preload("res://modules/quiz_rpg/scripts/generation/core/cell_type.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationFlags = preload("res://modules/quiz_rpg/scripts/generation/core/generation_flags.gd")
const OrganicCaveRoomCarver = preload("res://modules/quiz_rpg/scripts/generation/topology/organic_cave_room_carver.gd")
const OrganicCorridorCarver = preload("res://modules/quiz_rpg/scripts/generation/topology/organic_corridor_carver.gd")
const ConnectivityRepair = preload("res://modules/quiz_rpg/scripts/generation/topology/connectivity_repair.gd")
const PortalGenerator = preload("res://modules/quiz_rpg/scripts/generation/topology/portal_generator.gd")
const GridPreprocessor = preload("res://modules/quiz_rpg/scripts/generation/preprocess/grid_preprocessor.gd")
const JunctionSmoothingPass = preload("res://modules/quiz_rpg/scripts/generation/preprocess/junction_smoothing_pass.gd")
const Remove1hWallsPass = preload("res://modules/quiz_rpg/scripts/generation/preprocess/remove_1h_walls_pass.gd")
const WallThicknessPass = preload("res://modules/quiz_rpg/scripts/generation/preprocess/wall_thickness_pass.gd")
const ShortBulgeFlattenPass = preload("res://modules/quiz_rpg/scripts/generation/preprocess/short_bulge_flatten_pass.gd")
const SpikeCleanupPass = preload("res://modules/quiz_rpg/scripts/generation/preprocess/spike_cleanup_pass.gd")
const ThinBridgeCleanupPass = preload("res://modules/quiz_rpg/scripts/generation/preprocess/thin_bridge_cleanup_pass.gd")
const StaircaseNormalizerPass = preload("res://modules/quiz_rpg/scripts/generation/preprocess/staircase_normalizer_pass.gd")
const SpawnPlanner = preload("res://modules/quiz_rpg/scripts/generation/spawn/spawn_planner.gd")

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
		var extra_loops := mini(3, rooms.size() / 3)
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
	if flags.enable_junction_smoothing:
		GridPreprocessor.run(ctx, [JunctionSmoothingPass.new()])

	# P5–P7. Wymuszenie minimalnej grubości murów i eliminacja ścian 1H
	GridPreprocessor.run(ctx, [
		Remove1hWallsPass.new(),
		WallThicknessPass.new(),
		ShortBulgeFlattenPass.new()
	])

	# P8. Twarda gwarancja spójności
	ConnectivityRepair.repair(ctx, corridor_width)

	# P9. Dedykowane wejście i wyjście
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
		var exit_room := rooms[exit_room_idx]

		var entrance_data: Dictionary = PortalGenerator.carve_portal_alcove(ctx, entrance_room)
		result.entrance_pos = entrance_data["center"] as Vector2i
		result.player_spawn = entrance_data["center"] as Vector2i
		result.entrance_zone = entrance_data["cells"] as Array[Vector2i]
		for p in result.entrance_zone:
			ctx.grid[p] = CellType.ENTRANCE
			ctx.portal_zone[p] = true

		var exit_data: Dictionary = PortalGenerator.carve_portal_alcove(ctx, exit_room, int(entrance_data["edge"]))
		result.exit_pos = exit_data["center"] as Vector2i
		result.exit_zone = exit_data["cells"] as Array[Vector2i]
		for p in result.exit_zone:
			ctx.grid[p] = CellType.EXIT
			ctx.portal_zone[p] = true

	# P10. Pre-pass normalizacji siatki (przeniesiony z apply_cave_tiles KROK 0)
	if flags.enable_grid_cleanup:
		GridPreprocessor.run_convergent(ctx, [
			SpikeCleanupPass.new(),
			ThinBridgeCleanupPass.new(),
			StaircaseNormalizerPass.new()
		], 4)

		# P11. Drugie spłaszczanie wybrzuszeń (przeniesione z apply_cave_tiles KROK 0)
		GridPreprocessor.run(ctx, [ShortBulgeFlattenPass.new()])

	# P12. Spawny wrogów i skrzyń
	if not rooms.is_empty():
		SpawnPlanner.plan_spawns(ctx, result, entrance_room_idx, exit_room_idx)

	result.portal_zone = ctx.portal_zone
	result.preprocess_stats = ctx.preprocess_stats
	return ctx
