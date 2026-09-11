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

# Lewa ściana: kolumna 0 (wiersze 2, 3)
const WALL_LEFT: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 3)]
# Prawa ściana: kolumna 5 (wiersze 2, 3)
const WALL_RIGHT: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3)]

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

# Lewa i prawa ściana z korzeniami
const ROOT_WALL_LEFT: Array[Vector2i] = [Vector2i(0, 11), Vector2i(0, 12)]
const ROOT_WALL_RIGHT: Array[Vector2i] = [Vector2i(5, 11), Vector2i(5, 12)]

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
const CORNER_INNER_TOP_LEFT := Vector2i(1, 1)
const ROOT_CORNER_INNER_TOP_LEFT := Vector2i(1, 10)

const CORNER_INNER_TOP_RIGHT := Vector2i(4, 1)
const ROOT_CORNER_INNER_TOP_RIGHT := Vector2i(4, 10)

const CORNER_INNER_BOTTOM_LEFT := Vector2i(0, 4)
const ROOT_CORNER_INNER_BOTTOM_LEFT := Vector2i(0, 13)

const CORNER_INNER_BOTTOM_RIGHT := Vector2i(5, 4)
const ROOT_CORNER_INNER_BOTTOM_RIGHT := Vector2i(5, 13)

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
	max_room_size: int = 15,
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

	# 2. Generowanie komór jaskini (organiczne pokoje z zaokrąglonymi bokami)
	var rooms: Array[Rect2i] = []
	var attempts := 0
	var border := 6  # Większy margines dla wielokafelkowych ścian i nawisów

	while rooms.size() < max_rooms and attempts < 150:
		attempts += 1
		var rw := rng.randi_range(min_room_size, max_room_size)
		var rh := rng.randi_range(min_room_size, max_room_size)
		var rx := rng.randi_range(border, width - rw - border)
		var ry := rng.randi_range(border, height - rh - border)
		var new_room := Rect2i(rx, ry, rw, rh)

		var overlaps := false
		var expanded := Rect2i(rx - 3, ry - 3, rw + 6, rh + 6)
		for existing in rooms:
			if expanded.intersects(existing):
				overlaps = true
				break

		if overlaps:
			continue

		rooms.append(new_room)
		_carve_cave_chamber(result.grid, new_room, rng)

	result.rooms = rooms

	# 3. Szerokie korytarze jaskiniowe (min. 3 kratki szerokości)
	for i in range(rooms.size() - 1):
		var center_a := rooms[i].get_center()
		var center_b := rooms[i + 1].get_center()
		carve_corridor(result.grid, center_a, center_b, corridor_width, CellType.FLOOR, rng)

	if rooms.size() >= 4:
		var loop_a := rooms[0].get_center()
		var loop_b := rooms[rooms.size() - 2].get_center()
		carve_corridor(result.grid, loop_a, loop_b, corridor_width, CellType.FLOOR, rng)

	# 4. Rozmieszczenie punktów gry
	if not rooms.is_empty():
		# Komora startowa
		var start_room := rooms[0]
		result.player_spawn = start_room.get_center()
		result.entrance_pos = start_room.get_center()

		# Komora wyjściowa
		var last_room := rooms[rooms.size() - 1]
		result.exit_pos = last_room.get_center()
		result.grid[result.exit_pos] = CellType.EXIT

		# Boss w ostatniej komorze
		result.enemy_spawns.append({
			"pos": last_room.get_center() + Vector2i(0, -2),
			"tier": 3
		})

		# Pośrednie komory
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


## Rzeźbi komorę o zaokrąglonych, jaskiniowych kształtach
static func _carve_cave_chamber(grid: Dictionary, rect: Rect2i, rng: RandomNumberGenerator) -> void:
	# Podstawa: rzeźbimy główny prostokąt
	carve_rect(grid, rect, CellType.FLOOR)

	# Zaokrąglamy narożniki jaskini (ścięcie kantów)
	grid[rect.position] = CellType.WALL
	grid[Vector2i(rect.position.x + rect.size.x - 1, rect.position.y)] = CellType.WALL
	grid[Vector2i(rect.position.x, rect.position.y + rect.size.y - 1)] = CellType.WALL
	grid[Vector2i(rect.position.x + rect.size.x - 1, rect.position.y + rect.size.y - 1)] = CellType.WALL

	# Dodatkowe organiczne wypustki
	var center := rect.get_center()
	var radius := maxi(rect.size.x, rect.size.y) / 2
	for angle_step in range(4):
		if rng.randf() < 0.6:
			var offset_x := rng.randi_range(-2, 2)
			var offset_y := rng.randi_range(-2, 2)
			carve_circle(grid, center + Vector2i(offset_x, offset_y), radius - 1, CellType.FLOOR, 100, 100)


## Nanosi dopasowane kafelki z caves.tres na warstwy Floor, FloorDecor i Walls
static func apply_cave_tiles(
	floor_layer: TileMapLayer,
	walls_layer: TileMapLayer,
	result: GenerationResult,
	rng: RandomNumberGenerator,
	floor_decor_layer: TileMapLayer = null
) -> void:
	# Jeśli warstwa dekoracji podłogi nie została przekazana, poszukajmy jej w rodzicu
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
	# Cały obszar mapy i margines zewnętrzny wypełniamy ciemną litą skałą
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
	var grass_cells: Array[Vector2i] = []

	for pos in grid.keys():
		if _is_walkable(grid, pos):
			ground_cells.append(pos)
			var n_val := noise.get_noise_2d(float(pos.x), float(pos.y))
			if n_val > 0.05:
				grass_cells.append(pos)

	# Warstwa podstawowa: podłoga kamienna z autotilingiem
	floor_layer.set_cells_terrain_connect(ground_cells, 0, 0, false)

	# Warstwa dekoracyjna: mech/trawa nakładana na kamień z przezroczystymi krawędziami
	if floor_decor_layer:
		floor_decor_layer.set_cells_terrain_connect(grass_cells, 0, 1, false)
	else:
		floor_layer.set_cells_terrain_connect(grass_cells, 0, 1, false)

	# 3. ŚCIANY WIELOKAFELKOWE (Autotiling skryptowy)
	var theme_noise := FastNoiseLite.new()
	theme_noise.seed = rng.seed + 999
	theme_noise.frequency = 0.04

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

			var use_roots := (theme_noise.get_noise_2d(float(x), float(y)) > 0.15)

			# --- A. DOLNA FASADA (gdy pos jest na PÓŁNOC od podłogi -> s_floor == true) ---
			# Używa 3 bloków wysokości: baza z cieniem (row 7 lub 16), środek (row 6 lub 15), szczyt (row 5 lub 14)
			if s_floor:
				var is_left_end := not sw_floor
				var is_right_end := not se_floor

				if not use_roots:
					var base_t: Vector2i = WALL_BOTTOM_BASE[rng.randi() % WALL_BOTTOM_BASE.size()]
					var mid_t: Vector2i = WALL_BOTTOM_MID[rng.randi() % WALL_BOTTOM_MID.size()]
					var top_t: Vector2i = WALL_BOTTOM_TOP[rng.randi() % WALL_BOTTOM_TOP.size()]

					if is_left_end:
						base_t = WALL_BOTTOM_BASE_LEFT
						mid_t = WALL_BOTTOM_MID_LEFT
						top_t = WALL_BOTTOM_TOP_LEFT
					elif is_right_end:
						base_t = WALL_BOTTOM_BASE_RIGHT
						mid_t = WALL_BOTTOM_MID_RIGHT
						top_t = WALL_BOTTOM_TOP_RIGHT

					walls_layer.set_cell(pos, 0, base_t)

					var p_mid := pos + Vector2i(0, -1)
					if not _is_walkable(grid, p_mid):
						walls_layer.set_cell(p_mid, 0, mid_t)

					var p_top := pos + Vector2i(0, -2)
					if not _is_walkable(grid, p_top):
						walls_layer.set_cell(p_top, 0, top_t)
				else:
					var base_t: Vector2i = ROOT_BOTTOM_BASE[rng.randi() % ROOT_BOTTOM_BASE.size()]
					var mid_t: Vector2i = ROOT_BOTTOM_MID[rng.randi() % ROOT_BOTTOM_MID.size()]
					var top_t: Vector2i = ROOT_BOTTOM_TOP[rng.randi() % ROOT_BOTTOM_TOP.size()]

					if is_left_end:
						base_t = ROOT_BOTTOM_BASE_LEFT
						mid_t = ROOT_BOTTOM_MID_LEFT
						top_t = ROOT_BOTTOM_TOP_LEFT
					elif is_right_end:
						base_t = ROOT_BOTTOM_BASE_RIGHT
						mid_t = ROOT_BOTTOM_MID_RIGHT
						top_t = ROOT_BOTTOM_TOP_RIGHT

					walls_layer.set_cell(pos, 0, base_t)

					var p_mid := pos + Vector2i(0, -1)
					if not _is_walkable(grid, p_mid):
						walls_layer.set_cell(p_mid, 0, mid_t)

					var p_top := pos + Vector2i(0, -2)
					if not _is_walkable(grid, p_top):
						walls_layer.set_cell(p_top, 0, top_t)

				continue

			# --- B. GÓRNA ŚCIANA (gdy pos jest na POŁUDNIE od podłogi -> n_floor == true) ---
			# Zwykłe: 1 kafelek wysokości. Korzenie/kolce: 2 kafelki wysokości (row 8 szczyt, row 9 baza)
			if n_floor:
				var is_left_end := not nw_floor
				var is_right_end := not ne_floor

				if not use_roots:
					var top_t: Vector2i = WALL_TOP[rng.randi() % WALL_TOP.size()]
					if is_left_end:
						top_t = WALL_TOP_CORNER_LEFT
					elif is_right_end:
						top_t = WALL_TOP_CORNER_RIGHT
					walls_layer.set_cell(pos, 0, top_t)
				else:
					var spike_top: Vector2i = ROOT_TOP_TIPS[rng.randi() % ROOT_TOP_TIPS.size()]
					var spike_base: Vector2i = ROOT_TOP_BASE[rng.randi() % ROOT_TOP_BASE.size()]
					if is_left_end:
						spike_top = ROOT_TOP_TIPS_LEFT
						spike_base = ROOT_TOP_BASE_LEFT
					elif is_right_end:
						spike_top = ROOT_TOP_TIPS_RIGHT
						spike_base = ROOT_TOP_BASE_RIGHT

					walls_layer.set_cell(pos, 0, spike_top)

					var p_base := pos + Vector2i(0, 1)
					if not _is_walkable(grid, p_base):
						walls_layer.set_cell(p_base, 0, spike_base)
				continue

			# --- C. BOCZNE ŚCIANY ---
			if w_floor:
				var side_t: Vector2i = WALL_LEFT[rng.randi() % WALL_LEFT.size()] if not use_roots else ROOT_WALL_LEFT[rng.randi() % ROOT_WALL_LEFT.size()]
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, side_t)
				continue

			if e_floor:
				var side_t: Vector2i = WALL_RIGHT[rng.randi() % WALL_RIGHT.size()] if not use_roots else ROOT_WALL_RIGHT[rng.randi() % ROOT_WALL_RIGHT.size()]
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
				var c_t: Vector2i = CORNER_INNER_BOTTOM_LEFT if not use_roots else ROOT_CORNER_INNER_BOTTOM_LEFT
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, c_t)
			elif nw_floor:
				var c_t: Vector2i = CORNER_INNER_BOTTOM_RIGHT if not use_roots else ROOT_CORNER_INNER_BOTTOM_RIGHT
				if walls_layer.get_cell_atlas_coords(pos) == WALL_INSIDE:
					walls_layer.set_cell(pos, 0, c_t)


static func _is_walkable(grid: Dictionary, pos: Vector2i) -> bool:
	var t: int = grid.get(pos, CellType.VOID)
	return t == CellType.FLOOR or t == CellType.DOOR or t == CellType.ENTRANCE or t == CellType.EXIT

