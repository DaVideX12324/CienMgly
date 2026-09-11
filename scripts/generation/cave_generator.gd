class_name CaveGenerator
extends "res://modules/quiz_rpg/scripts/generation/map_generator_base.gd"

## Generator jaskiń dla modułu Quiz RPG.
## Wykorzystuje kafelki z caves.tres, manualnie dopasowując kafelki ścian (autotiling skryptowy),
## narożników wewnętrznych i zewnętrznych, fasad wielokafelkowych oraz podłogi kamiennej z mchem.

const CAVES_TILESET_PATH := "res://modules/quiz_rpg/resources/tilemaps/caves.tres"

# --- Koordynaty kafelków w atlasie caves.tres (Tiles.png) ---

# 1. Podłoga kamienna (Stone Floor): autotiling w terrain_set 0, terrain 0
# 2. Podłoga porośnięta mchem/trawą (Moss / Grass Floor): autotiling w terrain_set 0, terrain 1

# 3. Ściany zwykłe (Standard Walls):
# Szczyt / góra: wiersz 0 (kolumny 2, 3) - 1 kafelek wysokości
const WALL_TOP: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 0)]
const WALL_TOP_CORNER_LEFT := Vector2i(1, 0)
const WALL_TOP_CORNER_RIGHT := Vector2i(4, 0)
const WALL_TOP_SLOPE_RIGHT := Vector2i(5, 1)
const WALL_TOP_SLOPE_LEFT := Vector2i(0, 1)

# Lewa ściana (zachodnia ściana pokoju, e_floor == true): kolumna 5
const WALL_SIDE_WEST: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3)]
# Prawa ściana (wschodnia ściana pokoju, w_floor == true): kolumna 0
const WALL_SIDE_EAST: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 3)]
const WALL_LEFT: Array[Vector2i] = WALL_SIDE_WEST
const WALL_RIGHT: Array[Vector2i] = WALL_SIDE_EAST

# Dół / fasada opadająca: 3 klocki wysokości (wiersze 5, 6, 7)
const WALL_BOTTOM_TOP: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5)]
const WALL_BOTTOM_MID: Array[Vector2i] = [Vector2i(2, 6), Vector2i(3, 6)]
const WALL_BOTTOM_BASE: Array[Vector2i] = [Vector2i(2, 7), Vector2i(3, 7)]

const WALL_BOTTOM_TOP_LEFT := Vector2i(1, 5)
const WALL_BOTTOM_MID_LEFT := Vector2i(1, 6)
const WALL_BOTTOM_BASE_LEFT := Vector2i(1, 7)

const WALL_BOTTOM_TOP_RIGHT := Vector2i(4, 5)
const WALL_BOTTOM_MID_RIGHT := Vector2i(4, 6)
const WALL_BOTTOM_BASE_RIGHT := Vector2i(4, 7)

# 4. Ściany z korzeniami / kolcami (Root & Thorn Walls):
# Szczyt / góra: 2 kafelki wysokości (wiersz 8 szczyt, wiersz 9 baza kolców)
const ROOT_TOP_TIPS: Array[Vector2i] = [Vector2i(2, 8), Vector2i(3, 8)]
const ROOT_TOP_BASE: Array[Vector2i] = [Vector2i(2, 9), Vector2i(3, 9)]

const ROOT_TOP_TIPS_LEFT := Vector2i(1, 8)
const ROOT_TOP_BASE_LEFT := Vector2i(1, 9)

const ROOT_TOP_TIPS_RIGHT := Vector2i(4, 8)
const ROOT_TOP_BASE_RIGHT := Vector2i(4, 9)

const ROOT_TOP_SLOPE_TIPS_RIGHT := Vector2i(5, 9)
const ROOT_TOP_SLOPE_BASE_RIGHT := Vector2i(5, 10)
const ROOT_TOP_SLOPE_TIPS_LEFT := Vector2i(0, 9)
const ROOT_TOP_SLOPE_BASE_LEFT := Vector2i(0, 10)

# Lewa i prawa ściana z korzeniami
const ROOT_WALL_SIDE_WEST: Array[Vector2i] = [Vector2i(5, 11), Vector2i(5, 12)]
const ROOT_WALL_SIDE_EAST: Array[Vector2i] = [Vector2i(0, 11), Vector2i(0, 12)]
const ROOT_WALL_LEFT: Array[Vector2i] = ROOT_WALL_SIDE_WEST
const ROOT_WALL_RIGHT: Array[Vector2i] = ROOT_WALL_SIDE_EAST

# Dół / fasada opadająca z korzeniami: 3 klocki wysokości (wiersze 14, 15, 16)
const ROOT_BOTTOM_TOP: Array[Vector2i] = [Vector2i(2, 14), Vector2i(3, 14)]
const ROOT_BOTTOM_MID: Array[Vector2i] = [Vector2i(2, 15), Vector2i(3, 15)]
const ROOT_BOTTOM_BASE: Array[Vector2i] = [Vector2i(2, 16), Vector2i(3, 16)]

const ROOT_BOTTOM_TOP_LEFT := Vector2i(1, 14)
const ROOT_BOTTOM_MID_LEFT := Vector2i(1, 15)
const ROOT_BOTTOM_BASE_LEFT := Vector2i(1, 16)

const ROOT_BOTTOM_TOP_RIGHT := Vector2i(4, 14)
const ROOT_BOTTOM_MID_RIGHT := Vector2i(4, 15)
const ROOT_BOTTOM_BASE_RIGHT := Vector2i(4, 16)

# 5. Narożniki wewnętrzne (Inner Corners):
const CORNER_INNER_TOP_LEFT := Vector2i(4, 4)
const ROOT_CORNER_INNER_TOP_LEFT := Vector2i(4, 13)

const CORNER_INNER_TOP_RIGHT := Vector2i(1, 4)
const ROOT_CORNER_INNER_TOP_RIGHT := Vector2i(1, 13)

# Narożniki dolne wewnętrzne:
# Gdy floor jest na NE -> lewy dolny róg pokoju, lico skały patrzy na wschód (kolumna 5)
const CORNER_INNER_BOTTOM_LEFT := Vector2i(5, 4)
const ROOT_CORNER_INNER_BOTTOM_LEFT := Vector2i(5, 13)

# Gdy floor jest na NW -> prawy dolny róg pokoju, lico skały patrzy na zachód (kolumna 0)
const CORNER_INNER_BOTTOM_RIGHT := Vector2i(0, 4)
const ROOT_CORNER_INNER_BOTTOM_RIGHT := Vector2i(0, 13)

# Wnętrze ściany / pełny ciemny blok litej skały
const WALL_INSIDE := Vector2i(2, 2)


static func get_default_palette() -> Dictionary:
	return {
		"tileset_path": CAVES_TILESET_PATH,
		"wall_top": WALL_TOP,
		"wall_left": WALL_LEFT,
		"wall_right": WALL_RIGHT,
		"wall_bottom": WALL_BOTTOM_BASE,
		"wall_inside": WALL_INSIDE
	}


static func generate(
	width: int = 60,
	height: int = 60,
	seed_val: int = -1,
	min_room_size: int = 8,
	max_room_size: int = 14,
	max_rooms: int = 6,
	corridor_width: int = 3
) -> GenerationResult:
	var rng := create_rng(seed_val)
	var result := GenerationResult.new()
	result.width = width
	result.height = height
	result.seed_used = rng.seed

	# 1. Wypełnij siatkę ścianami
	for y in range(height):
		for x in range(width):
			result.grid[Vector2i(x, y)] = CellType.WALL

	# 2. Generowanie komór jaskini (organiczne pokoje z bezpiecznym marginesem)
	var rooms: Array[Rect2i] = []
	var attempts := 0
	var border := 6

	while rooms.size() < max_rooms and attempts < 200:
		attempts += 1
		var rw := rng.randi_range(min_room_size, max_room_size)
		var rh := rng.randi_range(min_room_size, max_room_size)
		var rx := rng.randi_range(border, width - rw - border)
		var ry := rng.randi_range(border, height - rh - border)
		var new_room := Rect2i(rx, ry, rw, rh)

		# Margines separacji: min. 5 kafelków poziomo i 6 kafelków pionowo,
		# aby ściany między komorami miały grubość co najmniej 2 modułów (min. 4-5 kratek w pionie).
		var overlaps := false
		var expanded := Rect2i(rx - 5, ry - 6, rw + 10, rh + 12)
		for existing in rooms:
			if expanded.intersects(existing):
				overlaps = true
				break

		if overlaps:
			continue

		rooms.append(new_room)
		_carve_cave_chamber(result.grid, new_room, rng)

	result.rooms = rooms

	# 3. Korytarze jaskiniowe (meandrujące, organiczne tunele)
	for i in range(rooms.size() - 1):
		var center_a := rooms[i].get_center()
		var center_b := rooms[i + 1].get_center()
		_carve_organic_corridor(result.grid, center_a, center_b, corridor_width, rng)

	if rooms.size() >= 4:
		var loop_a := rooms[0].get_center()
		var loop_b := rooms[rooms.size() - 2].get_center()
		_carve_organic_corridor(result.grid, loop_a, loop_b, corridor_width, rng)

	# 4. Wymuszenie minimalnej grubości murów (eliminacja zbyt cienkich ścianek < 4 w pionie i < 2 w poziomie)
	_enforce_wall_thickness(result.grid, width, height)

	# 5. Rozmieszczenie punktów gry
	if not rooms.is_empty():
		var start_room := rooms[0]
		result.player_spawn = start_room.get_center()
		result.entrance_pos = start_room.get_center()

		var last_room := rooms[rooms.size() - 1]
		result.exit_pos = last_room.get_center()
		result.grid[result.exit_pos] = CellType.EXIT

		result.enemy_spawns.append({
			"pos": last_room.get_center() + Vector2i(0, -2),
			"tier": 3
		})

		for i in range(1, rooms.size() - 1):
			var r := rooms[i]
			var center := r.get_center()
			if i % 2 == 1:
				var num_enemies := rng.randi_range(2, 4)
				for e in range(num_enemies):
					var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
					result.enemy_spawns.append({
						"pos": center + offset,
						"tier": rng.randi_range(1, 2)
					})
			else:
				result.chest_spawns.append(center)

	return result


## Rzeźbi komorę o naturalnych, organicznych kształtach jaskini (rdzeń eliptyczny + losowe wybrzuszenia)
static func _carve_cave_chamber(grid: Dictionary, rect: Rect2i, rng: RandomNumberGenerator) -> void:
	var center := rect.get_center()
	var rx_rad := rect.size.x / 2.0
	var ry_rad := rect.size.y / 2.0

	# 1. Główny rdzeń eliptyczny
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var dx := (x - center.x) / rx_rad
			var dy := (y - center.y) / ry_rad
			if dx * dx + dy * dy <= 1.0:
				grid[Vector2i(x, y)] = CellType.FLOOR

	# 2. Dodatkowe organiczne wybrzuszenia (lobes)
	var num_lobes := rng.randi_range(3, 5)
	for i in range(num_lobes):
		var angle := rng.randf_range(0.0, TAU)
		var dist_x := rng.randf_range(0.2, 0.6) * rx_rad
		var dist_y := rng.randf_range(0.2, 0.6) * ry_rad
		var lobe_center := center + Vector2i(int(cos(angle) * dist_x), int(sin(angle) * dist_y))
		var lobe_radius := rng.randi_range(2, int(min(rx_rad, ry_rad) * 0.6))
		carve_circle(grid, lobe_center, lobe_radius, CellType.FLOOR, 100, 100)


## Rzeźbi meandrujący, zaokrąglony korytarz jaskiniowy
static func _carve_organic_corridor(grid: Dictionary, from: Vector2i, to: Vector2i, width: int, rng: RandomNumberGenerator) -> void:
	var mid := (from + to) / 2
	var dir := Vector2(to - from).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var jitter := normal * rng.randf_range(-3.0, 3.0)
	var mid_curved := Vector2i(mid + Vector2i(int(jitter.x), int(jitter.y)))
	var points = [from, mid_curved, to]
	for seg in range(points.size() - 1):
		var p0: Vector2 = Vector2(points[seg])
		var p1: Vector2 = Vector2(points[seg + 1])
		var dist := p0.distance_to(p1)
		var steps := int(dist * 2.0)
		for s in range(steps + 1):
			var t := float(s) / maxf(float(steps), 1.0)
			var cur := p0.lerp(p1, t)
			carve_circle(grid, Vector2i(int(cur.x), int(cur.y)), width / 2 + 1, CellType.FLOOR, 100, 100)


## Usuwa cienkie ścianki (< 4 kratek w pionie, < 2 kratek w poziomie), łącząc komory w szerokie przejścia
static func _enforce_wall_thickness(grid: Dictionary, width: int, height: int) -> void:
	var changed := true
	var passes := 0
	while changed and passes < 5:
		changed = false
		passes += 1

		# 1. Sprawdzanie pionowej grubości ścian między otwartymi przestrzeniami
		for x in range(width):
			var y := 0
			while y < height:
				if grid.get(Vector2i(x, y), CellType.WALL) == CellType.WALL:
					var y_start := y
					while y < height and grid.get(Vector2i(x, y), CellType.WALL) == CellType.WALL:
						y += 1
					var y_end := y - 1
					var wall_len := y_end - y_start + 1

					var has_floor_above := (y_start > 0 and _is_walkable(grid, Vector2i(x, y_start - 1)))
					var has_floor_below := (y_end < height - 1 and _is_walkable(grid, Vector2i(x, y_end + 1)))

					# Jeśli ściana dzieli dwie komory w pionie i ma mniej niż 4 kratki (nie zmieści modułów):
					if has_floor_above and has_floor_below and wall_len < 4:
						for cy in range(y_start, y_end + 1):
							grid[Vector2i(x, cy)] = CellType.FLOOR
						changed = true
				else:
					y += 1

		# 2. Sprawdzanie poziomej grubości ścian między otwartymi przestrzeniami
		for y in range(height):
			var x := 0
			while x < width:
				if grid.get(Vector2i(x, y), CellType.WALL) == CellType.WALL:
					var x_start := x
					while x < width and grid.get(Vector2i(x, y), CellType.WALL) == CellType.WALL:
						x += 1
					var x_end := x - 1
					var wall_len := x_end - x_start + 1

					var has_floor_left := (x_start > 0 and _is_walkable(grid, Vector2i(x_start - 1, y)))
					var has_floor_right := (x_end < width - 1 and _is_walkable(grid, Vector2i(x_end + 1, y)))

					# Jeśli ściana dzieli dwie komory w poziomie i ma tylko 1 kratkę:
					if has_floor_left and has_floor_right and wall_len < 2:
						for cx in range(x_start, x_end + 1):
							grid[Vector2i(cx, y)] = CellType.FLOOR
						changed = true
				else:
					x += 1

		# 3. Usuwanie pojedynczych izolowanych klocków ściany otoczonych podłogą
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var p := Vector2i(x, y)
				if grid.get(p, CellType.WALL) == CellType.WALL:
					var floor_count := 0
					if _is_walkable(grid, p + Vector2i(1, 0)): floor_count += 1
					if _is_walkable(grid, p + Vector2i(-1, 0)): floor_count += 1
					if _is_walkable(grid, p + Vector2i(0, 1)): floor_count += 1
					if _is_walkable(grid, p + Vector2i(0, -1)): floor_count += 1
					if floor_count >= 3:
						grid[p] = CellType.FLOOR
						changed = true

		# 4. Usuwanie mikrowcięć podłogi otoczonych ścianami
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var p := Vector2i(x, y)
				if _is_walkable(grid, p):
					var wall_count := 0
					if not _is_walkable(grid, p + Vector2i(1, 0)): wall_count += 1
					if not _is_walkable(grid, p + Vector2i(-1, 0)): wall_count += 1
					if not _is_walkable(grid, p + Vector2i(0, 1)): wall_count += 1
					if not _is_walkable(grid, p + Vector2i(0, -1)): wall_count += 1
					if wall_count >= 3:
						grid[p] = CellType.WALL
						changed = true


## Zwraca pionową grubość ściany na danej pozycji (do najbliższej podłogi w górę i w dół)
static func _get_vertical_wall_thickness(grid: Dictionary, pos: Vector2i, height: int) -> int:
	var thickness := 0
	var cy := pos.y
	while cy >= 0 and not _is_walkable(grid, Vector2i(pos.x, cy)):
		thickness += 1
		cy -= 1
	cy = pos.y + 1
	while cy < height and not _is_walkable(grid, Vector2i(pos.x, cy)):
		thickness += 1
		cy += 1
	return thickness


## Nanosi dopasowane kafelki z caves.tres na warstwy Floor, FloorDecor i Walls
static func apply_cave_tiles(
	floor_layer: TileMapLayer,
	walls_layer: TileMapLayer,
	result: GenerationResult,
	rng: RandomNumberGenerator,
	floor_decor_layer: TileMapLayer = null
) -> void:
	if floor_decor_layer == null and floor_layer.get_parent():
		floor_decor_layer = floor_layer.get_parent().get_node_or_null("FloorDecor") as TileMapLayer
		if not floor_decor_layer:
			floor_decor_layer = TileMapLayer.new()
			floor_decor_layer.name = "FloorDecor"
			floor_decor_layer.tile_set = floor_layer.tile_set
			floor_decor_layer.z_index = -1
			floor_decor_layer.y_sort_enabled = true
			floor_layer.get_parent().add_child(floor_decor_layer)

	floor_layer.clear()
	if floor_decor_layer:
		floor_decor_layer.clear()
	walls_layer.clear()

	var width := result.width
	var height := result.height
	var grid := result.grid

	# 1. WYPEŁNIENIE VOIDU
	for y in range(-4, height + 4):
		for x in range(-4, width + 4):
			var pos := Vector2i(x, y)
			if not _is_walkable(grid, pos):
				walls_layer.set_cell(pos, 0, WALL_INSIDE)

	# 2. PODŁOGA DWUWARSTWOWA (Kamienna + organiczne plamy mchu/trawy)
	var noise := FastNoiseLite.new()
	noise.seed = rng.seed
	noise.frequency = 0.07

	var ground_cells: Array[Vector2i] = []
	var grass_candidates: Dictionary = {}
	var near_floor: Dictionary = {}

	for pos in grid.keys():
		if _is_walkable(grid, pos):
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if abs(dx) + abs(dy) <= 4:
						near_floor[pos + Vector2i(dx, dy)] = true

	for pos in near_floor.keys():
		ground_cells.append(pos)
		var n_val := noise.get_noise_2d(float(pos.x), float(pos.y))
		if n_val > 0.02:
			grass_candidates[pos] = true

	# Filtr 2x2 dla trawy
	var grass_cells: Array[Vector2i] = []
	for p in grass_candidates.keys():
		var is_2x2 := false
		if grass_candidates.has(p + Vector2i(1, 0)) and grass_candidates.has(p + Vector2i(0, 1)) and grass_candidates.has(p + Vector2i(1, 1)):
			is_2x2 = true
		elif grass_candidates.has(p + Vector2i(-1, 0)) and grass_candidates.has(p + Vector2i(0, 1)) and grass_candidates.has(p + Vector2i(-1, 1)):
			is_2x2 = true
		elif grass_candidates.has(p + Vector2i(1, 0)) and grass_candidates.has(p + Vector2i(0, -1)) and grass_candidates.has(p + Vector2i(1, -1)):
			is_2x2 = true
		elif grass_candidates.has(p + Vector2i(-1, 0)) and grass_candidates.has(p + Vector2i(0, -1)) and grass_candidates.has(p + Vector2i(-1, -1)):
			is_2x2 = true
		if is_2x2:
			grass_cells.append(p)

	floor_layer.set_cells_terrain_connect(ground_cells, 0, 0, false)

	if floor_decor_layer:
		floor_decor_layer.set_cells_terrain_connect(grass_cells, 0, 1, false)
	else:
		floor_layer.set_cells_terrain_connect(grass_cells, 0, 1, false)

	# 3. SPÓJNY MOTYW ŚCIAN NA POZIOMIE KOMÓR
	var room_themes: Array[bool] = []
	for i in range(result.rooms.size()):
		var r := result.rooms[i]
		var can_support_roots := true
		for x in range(r.position.x, r.position.x + r.size.x):
			if _get_vertical_wall_thickness(grid, Vector2i(x, r.position.y - 1), height) < 5:
				can_support_roots = false
				break
		if can_support_roots and rng.randf() < 0.35:
			room_themes.append(true)
		else:
			room_themes.append(false)

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if _is_walkable(grid, pos):
				continue

			var s_floor := _is_walkable(grid, pos + Vector2i(0, 1))
			var n_floor := _is_walkable(grid, pos + Vector2i(0, -1))
			var e_floor := _is_walkable(grid, pos + Vector2i(1, 0))
			var w_floor := _is_walkable(grid, pos + Vector2i(-1, 0))

			var se_floor := _is_walkable(grid, pos + Vector2i(1, 1))
			var sw_floor := _is_walkable(grid, pos + Vector2i(-1, 1))
			var ne_floor := _is_walkable(grid, pos + Vector2i(1, -1))
			var nw_floor := _is_walkable(grid, pos + Vector2i(-1, -1))

			var use_roots := false
			if not room_themes.is_empty():
				var closest_dist := 999999.0
				var closest_idx := 0
				for r_i in range(result.rooms.size()):
					var d := Vector2(pos).distance_to(Vector2(result.rooms[r_i].get_center()))
					if d < closest_dist:
						closest_dist = d
						closest_idx = r_i
				use_roots = room_themes[closest_idx]

			var v_thickness := _get_vertical_wall_thickness(grid, pos, height)
			if v_thickness < 5:
				use_roots = false

			# --- A. DOLNA FASADA (gdy pos jest na PÓŁNOC od podłogi -> s_floor == true) ---
			# Pełny moduł 3 klocków wysokości: baza z cieniem (row 7/16), środek (row 6/15), korona (row 5/14)
			if s_floor:
				# Zakręt wewnętrzny do korytarza biegnącego na północ:
				var is_north_opening_left := e_floor and _is_walkable(grid, pos + Vector2i(1, -1))
				var is_north_opening_right := w_floor and _is_walkable(grid, pos + Vector2i(-1, -1))

				if is_north_opening_left:
					var c_t: Vector2i = Vector2i(5, 4) if not use_roots else Vector2i(5, 13)
					walls_layer.set_cell(pos, 0, c_t)
					continue
				elif is_north_opening_right:
					var c_t: Vector2i = Vector2i(0, 4) if not use_roots else Vector2i(0, 13)
					walls_layer.set_cell(pos, 0, c_t)
					continue

				# Wykrywanie końca ściany lub schodka w dół:
				var is_west_end := not sw_floor
				var is_east_end := not se_floor

				# Schodki diagonalne (gdzie podłoga sąsiedniej kolumny schodzi w dół):
				var right_has_step_down := _is_walkable(grid, pos + Vector2i(1, 2)) and not _is_walkable(grid, pos + Vector2i(1, 1))
				var left_has_step_down := _is_walkable(grid, pos + Vector2i(-1, 2)) and not _is_walkable(grid, pos + Vector2i(-1, 1))

				var base_t: Vector2i
				var mid_t: Vector2i
				var top_t: Vector2i

				if not use_roots:
					# Zestaw modułów schodka tylko wtedy, gdy ze skrętu przechodzi w skręt:
					if right_has_step_down:
						base_t = WALL_BOTTOM_BASE_LEFT # (1, 7)
						mid_t = WALL_BOTTOM_MID_LEFT   # (1, 6)
						top_t = WALL_BOTTOM_TOP_LEFT   # (1, 5)
					elif left_has_step_down:
						base_t = WALL_BOTTOM_BASE_RIGHT # (4, 7)
						mid_t = WALL_BOTTOM_MID_RIGHT   # (4, 6)
						top_t = WALL_BOTTOM_TOP_RIGHT   # (4, 5)
					else:
						base_t = WALL_BOTTOM_BASE[rng.randi() % WALL_BOTTOM_BASE.size()]
						mid_t = WALL_BOTTOM_MID[rng.randi() % WALL_BOTTOM_MID.size()]
						top_t = WALL_BOTTOM_TOP[rng.randi() % WALL_BOTTOM_TOP.size()]
				else:
					if right_has_step_down:
						base_t = ROOT_BOTTOM_BASE_LEFT # (1, 16)
						mid_t = ROOT_BOTTOM_MID_LEFT   # (1, 15)
						top_t = ROOT_BOTTOM_TOP_LEFT   # (1, 14)
					elif left_has_step_down:
						base_t = ROOT_BOTTOM_BASE_RIGHT # (4, 16)
						mid_t = ROOT_BOTTOM_MID_RIGHT   # (4, 15)
						top_t = ROOT_BOTTOM_TOP_RIGHT   # (4, 14)
					else:
						base_t = ROOT_BOTTOM_BASE[rng.randi() % ROOT_BOTTOM_BASE.size()]
						mid_t = ROOT_BOTTOM_MID[rng.randi() % ROOT_BOTTOM_MID.size()]
						top_t = ROOT_BOTTOM_TOP[rng.randi() % ROOT_BOTTOM_TOP.size()]

				walls_layer.set_cell(pos, 0, base_t)

				var p_mid := pos + Vector2i(0, -1)
				if not _is_walkable(grid, p_mid):
					walls_layer.set_cell(p_mid, 0, mid_t)

				var p_top := pos + Vector2i(0, -2)
				if not _is_walkable(grid, p_top):
					walls_layer.set_cell(p_top, 0, top_t)

				# Ukośny bark tylko przy faktycznym schodkowaniu w dół między kolumnami podłogi:
				if right_has_step_down:
					var p_sh := pos + Vector2i(1, -2)
					if not _is_walkable(grid, p_sh):
						var sh_t := Vector2i(0, 5) if not use_roots else Vector2i(0, 14)
						walls_layer.set_cell(p_sh, 0, sh_t)
				elif left_has_step_down:
					var p_sh := pos + Vector2i(-1, -2)
					if not _is_walkable(grid, p_sh):
						var sh_t := Vector2i(5, 5) if not use_roots else Vector2i(5, 14)
						walls_layer.set_cell(p_sh, 0, sh_t)

				# Pojedynczy narożnik 90° wyrównany do góry korony ściany (Pair 8: (4, 4) i (1, 4)):
				if is_west_end and not right_has_step_down:
					var p_c := pos + Vector2i(-1, -2)
					if not _is_walkable(grid, p_c):
						var c_t: Vector2i = CORNER_INNER_TOP_LEFT if not use_roots else ROOT_CORNER_INNER_TOP_LEFT
						walls_layer.set_cell(p_c, 0, c_t)
					for dy in [-1, 0]:
						var p_s := pos + Vector2i(-1, dy)
						if not _is_walkable(grid, p_s):
							var side_t: Vector2i = WALL_SIDE_WEST[rng.randi() % WALL_SIDE_WEST.size()] if not use_roots else ROOT_WALL_SIDE_WEST[rng.randi() % ROOT_WALL_SIDE_WEST.size()]
							walls_layer.set_cell(p_s, 0, side_t)

				if is_east_end and not left_has_step_down:
					var p_c := pos + Vector2i(1, -2)
					if not _is_walkable(grid, p_c):
						var c_t: Vector2i = CORNER_INNER_TOP_RIGHT if not use_roots else ROOT_CORNER_INNER_TOP_RIGHT
						walls_layer.set_cell(p_c, 0, c_t)
					for dy in [-1, 0]:
						var p_s := pos + Vector2i(1, dy)
						if not _is_walkable(grid, p_s):
							var side_t: Vector2i = WALL_SIDE_EAST[rng.randi() % WALL_SIDE_EAST.size()] if not use_roots else ROOT_WALL_SIDE_EAST[rng.randi() % ROOT_WALL_SIDE_EAST.size()]
							walls_layer.set_cell(p_s, 0, side_t)

				continue

			# --- B. GÓRNA ŚCIANA (gdy pos jest na POŁUDNIE od podłogi -> n_floor == true) ---
			# Zwykłe: 1 kafelek wysokości. Korzenie/kolce: 2 kafelki wysokości (row 8 szczyt, row 9 baza)
			if n_floor:
				# Płynne ukośne zbocza ściany dolnej (smooth slopes zamiast schodków 90°):
				var is_slope_right := e_floor or (ne_floor and not nw_floor and not w_floor)
				var is_slope_left := w_floor or (nw_floor and not ne_floor and not e_floor)

				var is_turn_to_corridor_r := e_floor
				var is_turn_to_corridor_l := w_floor
				var is_room_end_l := not nw_floor and not w_floor
				var is_room_end_r := not ne_floor and not e_floor

				var use_left_corner := is_turn_to_corridor_l or (is_room_end_l and not is_turn_to_corridor_r)
				var use_right_corner := is_turn_to_corridor_r or (is_room_end_r and not is_turn_to_corridor_l)

				if not use_roots:
					var top_t: Vector2i = WALL_TOP[rng.randi() % WALL_TOP.size()]
					if is_slope_right and not is_slope_left:
						top_t = WALL_TOP_SLOPE_RIGHT
					elif is_slope_left and not is_slope_right:
						top_t = WALL_TOP_SLOPE_LEFT
					elif use_left_corner and not use_right_corner:
						top_t = WALL_TOP_CORNER_LEFT
					elif use_right_corner and not use_left_corner:
						top_t = WALL_TOP_CORNER_RIGHT
					walls_layer.set_cell(pos, 0, top_t)
				else:
					var spike_top: Vector2i = ROOT_TOP_TIPS[rng.randi() % ROOT_TOP_TIPS.size()]
					var spike_base: Vector2i = ROOT_TOP_BASE[rng.randi() % ROOT_TOP_BASE.size()]
					if is_slope_right and not is_slope_left:
						spike_top = ROOT_TOP_SLOPE_TIPS_RIGHT
						spike_base = ROOT_TOP_SLOPE_BASE_RIGHT
					elif is_slope_left and not is_slope_right:
						spike_top = ROOT_TOP_SLOPE_TIPS_LEFT
						spike_base = ROOT_TOP_SLOPE_BASE_LEFT
					elif use_left_corner and not use_right_corner:
						spike_top = ROOT_TOP_TIPS_LEFT
						spike_base = ROOT_TOP_BASE_LEFT
					elif use_right_corner and not use_left_corner:
						spike_top = ROOT_TOP_TIPS_RIGHT
						spike_base = ROOT_TOP_BASE_RIGHT

					walls_layer.set_cell(pos, 0, spike_top)

					var p_base := pos + Vector2i(0, 1)
					if not _is_walkable(grid, p_base):
						walls_layer.set_cell(p_base, 0, spike_base)

				continue

			# --- C. BOCZNE ŚCIANY ---
			# e_floor == true -> ściana po lewej stronie (zachodnia ściana pokoju), lico skały patrzy na WSCHÓD (kolumna 5)
			if e_floor:
				var side_t: Vector2i = WALL_SIDE_WEST[rng.randi() % WALL_SIDE_WEST.size()] if not use_roots else ROOT_WALL_SIDE_WEST[rng.randi() % ROOT_WALL_SIDE_WEST.size()]
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, side_t)
				continue

			# w_floor == true -> ściana po prawej stronie (wschodnia ściana pokoju), lico skały patrzy na ZACHÓD (kolumna 0)
			if w_floor:
				var side_t: Vector2i = WALL_SIDE_EAST[rng.randi() % WALL_SIDE_EAST.size()] if not use_roots else ROOT_WALL_SIDE_EAST[rng.randi() % ROOT_WALL_SIDE_EAST.size()]
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, side_t)
				continue

			# --- D. NAROŻNIKI WEWNĘTRZNE (pojedyncze kafelki przy zakrętach) ---
			if se_floor:
				var c_t: Vector2i = CORNER_INNER_TOP_LEFT if not use_roots else ROOT_CORNER_INNER_TOP_LEFT
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, c_t)
			elif sw_floor:
				var c_t: Vector2i = CORNER_INNER_TOP_RIGHT if not use_roots else ROOT_CORNER_INNER_TOP_RIGHT
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, c_t)
			elif ne_floor:
				# floor jest na NE -> lewy dolny narożnik pokoju, lico skały patrzy na WSCHÓD (kolumna 5)
				var c_t: Vector2i = CORNER_INNER_BOTTOM_LEFT if not use_roots else ROOT_CORNER_INNER_BOTTOM_LEFT
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, c_t)
			elif nw_floor:
				# floor jest na NW -> prawy dolny narożnik pokoju, lico skały patrzy na ZACHÓD (kolumna 0)
				var c_t: Vector2i = CORNER_INNER_BOTTOM_RIGHT if not use_roots else ROOT_CORNER_INNER_BOTTOM_RIGHT
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, c_t)


static func _is_walkable(grid: Dictionary, pos: Vector2i) -> bool:
	var t: int = grid.get(pos, CellType.VOID)
	return t == CellType.FLOOR or t == CellType.DOOR or t == CellType.ENTRANCE or t == CellType.EXIT
