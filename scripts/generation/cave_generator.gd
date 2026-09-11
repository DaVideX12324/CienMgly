class_name CaveGenerator
extends "res://modules/quiz_rpg/scripts/generation/map_generator_base.gd"

## Generator jaskiń dla modułu Quiz RPG.
## Wykorzystuje kafelki z caves.tres, manualnie dopasowując kafelki ścian (autotiling skryptowy),
## narożników wewnętrznych i zewnętrznych, fasad wielokafelkowych oraz podłogi kamiennej z mchem.

const CAVES_TILESET_PATH := "res://modules/quiz_rpg/resources/tilemaps/caves.tres"

# --- Koordynaty kafelków w atlasie caves.tres (Tiles.png) ---

# 1. Podłoga kamienna (Stone Floor): kolumny 7-9, wiersze 13-16
const FLOOR_STONE := [
	Vector2i(8, 14), Vector2i(9, 14), Vector2i(8, 15), Vector2i(9, 15)
]

# 2. Podłoga porośnięta mchem/trawą (Moss / Grass Floor): kolumny 12-14, wiersze 13-16
const FLOOR_MOSS := [
	Vector2i(13, 14), Vector2i(14, 14), Vector2i(13, 15), Vector2i(14, 15)
]

# 3. Ściany zwykłe (Standard Walls):
# Szczyt / góra: wiersz 0 (kolumny 2, 3)
const WALL_TOP := [Vector2i(2, 0), Vector2i(3, 0)]
# Lewa ściana: kolumna 0 (wiersze 2, 3)
const WALL_LEFT := [Vector2i(0, 2), Vector2i(0, 3)]
# Prawa ściana: kolumna 5 (wiersze 2, 3)
const WALL_RIGHT := [Vector2i(5, 2), Vector2i(5, 3)]
# Dół / fasada opadająca: wiersze 4-7
const WALL_BOTTOM_ROW0 := [Vector2i(2, 4), Vector2i(3, 4)]
const WALL_BOTTOM_ROW1 := [Vector2i(2, 5), Vector2i(3, 5)]
const WALL_BOTTOM_ROW2 := [Vector2i(2, 6), Vector2i(3, 6)]
const WALL_BOTTOM_BASE := [Vector2i(2, 7), Vector2i(3, 7)]

# 4. Ściany z korzeniami / kolcami (Root & Thorn Walls)
const ROOT_BOTTOM_ROW0 := [Vector2i(2, 10), Vector2i(3, 10)]
const ROOT_BOTTOM_ROW1 := [Vector2i(2, 11), Vector2i(3, 11)]
const ROOT_BOTTOM_ROW2 := [Vector2i(2, 12), Vector2i(3, 12)]
const ROOT_BOTTOM_BASE := [Vector2i(2, 13), Vector2i(3, 13)]

# 5. Narożniki zewnętrzne (Outer Corners)
const CORNER_OUTER_TOP_LEFT := Vector2i(1, 0)
const CORNER_OUTER_TOP_RIGHT := Vector2i(4, 0)
const CORNER_OUTER_BOTTOM_LEFT := Vector2i(0, 1)
const CORNER_OUTER_BOTTOM_RIGHT := Vector2i(5, 1)

# 6. Narożniki wewnętrzne (Inner Corners)
# Pojedynczy skręt
const CORNER_INNER_TOP_LEFT := Vector2i(1, 1)
const CORNER_INNER_TOP_RIGHT := Vector2i(4, 1)
const CORNER_INNER_BOTTOM_LEFT := Vector2i(0, 4)
const CORNER_INNER_BOTTOM_RIGHT := Vector2i(5, 4)

# Wnętrze ściany / pełny ciemny blok
const WALL_INSIDE := Vector2i(2, 2)


static func get_default_palette() -> Dictionary:
	return {
		"tileset_path": CAVES_TILESET_PATH,
		"floor_stone": FLOOR_STONE,
		"floor_moss": FLOOR_MOSS,
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


## Skryptowy autotiling - nanosi dopasowane kafelki z caves.tres na warstwy Floor i Walls
static func apply_cave_tiles(
	floor_layer: TileMapLayer,
	walls_layer: TileMapLayer,
	result: GenerationResult,
	rng: RandomNumberGenerator
) -> void:
	floor_layer.clear()
	walls_layer.clear()

	# 1. Rysowanie podłogi (Kamienna z plamami mchu/trawy)
	var noise := FastNoiseLite.new()
	noise.seed = rng.seed
	noise.frequency = 0.08

	for pos in result.grid.keys():
		var type: int = result.grid[pos]
		if type == CellType.FLOOR or type == CellType.DOOR or type == CellType.ENTRANCE or type == CellType.EXIT:
			var n_val := noise.get_noise_2d(float(pos.x), float(pos.y))
			if n_val > 0.15:
				# Plama mchu / trawy
				var tile: Vector2i = FLOOR_MOSS[rng.randi() % FLOOR_MOSS.size()]
				floor_layer.set_cell(pos, 0, tile)
			else:
				# Zwykła posadzka kamienna
				var tile: Vector2i = FLOOR_STONE[rng.randi() % FLOOR_STONE.size()]
				floor_layer.set_cell(pos, 0, tile)

	# 2. Rysowanie ścian - manualna analiza sąsiadów (Autotiling skryptowy)
	for pos in result.grid.keys():
		if result.grid[pos] != CellType.WALL:
			continue

		var tile_coord := _resolve_wall_tile(pos, result.grid, rng)
		if tile_coord != Vector2i(-1, -1):
			# Pod każdą ścianą kładziemy również podłogę kamienną, by nie było czarnych przerw przy krawędziach
			floor_layer.set_cell(pos, 0, FLOOR_STONE[0])
			walls_layer.set_cell(pos, 0, tile_coord)


## Dobiera koordynat kafelka ściany na podstawie sąsiedztwa 8-kierunkowego
static func _resolve_wall_tile(pos: Vector2i, grid: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var n_is_floor  := _is_walkable(grid, pos + Vector2i(0, -1))
	var s_is_floor  := _is_walkable(grid, pos + Vector2i(0, 1))
	var w_is_floor  := _is_walkable(grid, pos + Vector2i(-1, 0))
	var e_is_floor  := _is_walkable(grid, pos + Vector2i(1, 0))

	var nw_is_floor := _is_walkable(grid, pos + Vector2i(-1, -1))
	var ne_is_floor := _is_walkable(grid, pos + Vector2i(1, -1))
	var sw_is_floor := _is_walkable(grid, pos + Vector2i(-1, 1))
	var se_is_floor := _is_walkable(grid, pos + Vector2i(1, 1))

	# 1. Narożniki zewnętrzne (Outer Corners)
	if n_is_floor and w_is_floor:
		return CORNER_OUTER_TOP_LEFT
	if n_is_floor and e_is_floor:
		return CORNER_OUTER_TOP_RIGHT
	if s_is_floor and w_is_floor:
		return CORNER_OUTER_BOTTOM_LEFT
	if s_is_floor and e_is_floor:
		return CORNER_OUTER_BOTTOM_RIGHT

	# 2. Proste odcinki ścian
	if n_is_floor:
		# Ściana górna pokoju (widziana od dołu)
		return WALL_TOP[rng.randi() % WALL_TOP.size()]

	if s_is_floor:
		# Ściana dolna pokoju (frontowa fasada nad podłogą)
		# Losowo: 70% zwykła fasada, 30% porośnięta korzeniami
		if rng.randf() < 0.3:
			return ROOT_BOTTOM_BASE[rng.randi() % ROOT_BOTTOM_BASE.size()]
		return WALL_BOTTOM_BASE[rng.randi() % WALL_BOTTOM_BASE.size()]

	if w_is_floor:
		return WALL_LEFT[rng.randi() % WALL_LEFT.size()]

	if e_is_floor:
		return WALL_RIGHT[rng.randi() % WALL_RIGHT.size()]

	# 3. Narożniki wewnętrzne (Inner Corners)
	# Gdy ściana nie ma bezpośredniego sąsiada podłogi N/S/W/E, ale ma po skosie:
	if se_is_floor:
		return CORNER_INNER_TOP_LEFT
	if sw_is_floor:
		return CORNER_INNER_TOP_RIGHT
	if ne_is_floor:
		return CORNER_INNER_BOTTOM_LEFT
	if nw_is_floor:
		return CORNER_INNER_BOTTOM_RIGHT

	# 4. Głębokie wnętrze masywu skalnego
	# Jeśli kafelek jest w odległości 1 od ściany z podłogą, rysujemy wnętrze
	if _has_any_floor_nearby(pos, grid):
		return WALL_INSIDE

	# Pustka / odległy void
	return Vector2i(-1, -1)


static func _is_walkable(grid: Dictionary, pos: Vector2i) -> bool:
	var t: int = grid.get(pos, CellType.VOID)
	return t == CellType.FLOOR or t == CellType.DOOR or t == CellType.ENTRANCE or t == CellType.EXIT


static func _has_any_floor_nearby(pos: Vector2i, grid: Dictionary) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if _is_walkable(grid, pos + Vector2i(dx, dy)):
				return true
	return false
