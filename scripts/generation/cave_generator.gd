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
const WALL_TOP_CORNER_LEFT := Vector2i(0, 1) # Kafelek 5 z katalogu (RED B5)
const WALL_TOP_CORNER_RIGHT := Vector2i(5, 1) # Kafelek 8 z katalogu (RED mirror B5)
const WALL_TOP_SLOPE_RIGHT := Vector2i(4, 1) # Kafelek 7 z katalogu (BLUE mirror B5)
const WALL_TOP_SLOPE_LEFT := Vector2i(1, 1)  # Kafelek 6 z katalogu (BLUE B5)

# Lewa ściana (zachodnia ściana pokoju, e_floor == true): kolumna 5
const WALL_SIDE_WEST: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3)]
# Prawa ściana (wschodnia ściana pokoju, w_floor == true): kolumna 0
const WALL_SIDE_EAST: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 3)]
const WALL_LEFT: Array[Vector2i] = WALL_SIDE_WEST
const WALL_RIGHT: Array[Vector2i] = WALL_SIDE_EAST

# Dół / fasada opadająca: 3 klocki wysokości (wiersze 5, 6, 7)
# Prosta fasada (MOD_WALL_FOOT)
const WALL_BOTTOM_TOP: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5)]
const WALL_BOTTOM_MID: Array[Vector2i] = [Vector2i(2, 6), Vector2i(3, 6)]
const WALL_BOTTOM_BASE: Array[Vector2i] = [Vector2i(2, 7), Vector2i(3, 7)]

# Moduł schodka prawego / skos opadający w dół w prawo (MOD_CRNR_NW_IN): kolumna 1
const MOD_CRNR_NW_IN_TOP := Vector2i(1, 5)
const MOD_CRNR_NW_IN_MID := Vector2i(1, 6)
const MOD_CRNR_NW_IN_BASE := Vector2i(1, 7)

# Moduł zakończenia lewego bez schodka (MOD_CRNR_NW_OUT): kolumna 0
const MOD_CRNR_NW_OUT_TOP := Vector2i(0, 4)
const MOD_CRNR_NW_OUT_MID := Vector2i(0, 5)
const MOD_CRNR_NW_OUT_BASE := Vector2i(0, 6)

# Moduł schodka lewego / skos opadający w dół w lewo (MOD_CRNR_NE_IN): kolumna 4
const MOD_CRNR_NE_IN_TOP := Vector2i(4, 5)
const MOD_CRNR_NE_IN_MID := Vector2i(4, 6)
const MOD_CRNR_NE_IN_BASE := Vector2i(4, 7)

# Moduł zakończenia prawego bez schodka (MOD_CRNR_NE_OUT): kolumna 5
const MOD_CRNR_NE_OUT_TOP := Vector2i(5, 4)
const MOD_CRNR_NE_OUT_MID := Vector2i(5, 5)
const MOD_CRNR_NE_OUT_BASE := Vector2i(5, 6)

# Kompatybilność wsteczna aliasów:
const WALL_BOTTOM_TOP_LEFT := MOD_CRNR_NW_IN_TOP
const WALL_BOTTOM_MID_LEFT := MOD_CRNR_NW_IN_MID
const WALL_BOTTOM_BASE_LEFT := MOD_CRNR_NW_IN_BASE
const WALL_BOTTOM_TOP_RIGHT := MOD_CRNR_NE_IN_TOP
const WALL_BOTTOM_MID_RIGHT := MOD_CRNR_NE_IN_MID
const WALL_BOTTOM_BASE_RIGHT := MOD_CRNR_NE_IN_BASE

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

const ROOT_MOD_CRNR_NW_IN_TOP := Vector2i(1, 14)
const ROOT_MOD_CRNR_NW_IN_MID := Vector2i(1, 15)
const ROOT_MOD_CRNR_NW_IN_BASE := Vector2i(1, 16)

const ROOT_MOD_CRNR_NW_OUT_TOP := Vector2i(0, 13)
const ROOT_MOD_CRNR_NW_OUT_MID := Vector2i(0, 14)
const ROOT_MOD_CRNR_NW_OUT_BASE := Vector2i(0, 15)

const ROOT_MOD_CRNR_NE_IN_TOP := Vector2i(4, 14)
const ROOT_MOD_CRNR_NE_IN_MID := Vector2i(4, 15)
const ROOT_MOD_CRNR_NE_IN_BASE := Vector2i(4, 16)

const ROOT_MOD_CRNR_NE_OUT_TOP := Vector2i(5, 13)
const ROOT_MOD_CRNR_NE_OUT_MID := Vector2i(5, 14)
const ROOT_MOD_CRNR_NE_OUT_BASE := Vector2i(5, 15)

const ROOT_BOTTOM_TOP_LEFT := ROOT_MOD_CRNR_NW_IN_TOP
const ROOT_BOTTOM_MID_LEFT := ROOT_MOD_CRNR_NW_IN_MID
const ROOT_BOTTOM_BASE_LEFT := ROOT_MOD_CRNR_NW_IN_BASE
const ROOT_BOTTOM_TOP_RIGHT := ROOT_MOD_CRNR_NE_IN_TOP
const ROOT_BOTTOM_MID_RIGHT := ROOT_MOD_CRNR_NE_IN_MID
const ROOT_BOTTOM_BASE_RIGHT := ROOT_MOD_CRNR_NE_IN_BASE

# 5. Narożniki wewnętrzne Foot (domykające schodek od dołu):
# CRNR_SW_IN: (4,4) - domyka formację dla MOD_CRNR_NE_IN od strony SW (po prawej stronie schodka)
const CRNR_SW_IN := Vector2i(4, 4)
const ROOT_CRNR_SW_IN := Vector2i(4, 13)

# CRNR_SE_IN: (1,4) - domyka formację dla MOD_CRNR_NW_IN od strony SE (po lewej stronie schodka)
const CRNR_SE_IN := Vector2i(1, 4)
const ROOT_CRNR_SE_IN := Vector2i(1, 13)

const CORNER_INNER_TOP_LEFT := CRNR_SW_IN
const ROOT_CORNER_INNER_TOP_LEFT := ROOT_CRNR_SW_IN
const CORNER_INNER_TOP_RIGHT := CRNR_SE_IN
const ROOT_CORNER_INNER_TOP_RIGHT := ROOT_CRNR_SE_IN

# Narożniki dolne wewnętrzne:
# Gdy floor jest na NE -> lewy dolny róg pokoju / BLUE lustro: kafelek 7 (4, 1)
const CORNER_INNER_BOTTOM_LEFT := Vector2i(4, 1)
const ROOT_CORNER_INNER_BOTTOM_LEFT := Vector2i(4, 10)

# Gdy floor jest na NW -> prawy dolny róg pokoju / BLUE: kafelek 6 (1, 1)
const CORNER_INNER_BOTTOM_RIGHT := Vector2i(1, 1)
const ROOT_CORNER_INNER_BOTTOM_RIGHT := Vector2i(1, 10)

# Wnętrze ściany / pełny ciemny blok litej skały
const WALL_INSIDE := Vector2i(2, 2)

# 6. Ściany fasad o wysokości 2 kratek (wiersze 19, 20, 21):
const WALL_2H_TOP: Array[Vector2i] = [Vector2i(2, 20), Vector2i(3, 20)]
const WALL_2H_BASE: Array[Vector2i] = [Vector2i(2, 21), Vector2i(3, 21)]

# Zakończenia / narożniki zewnętrzne 2H:
const WALL_2H_WEST_TOP := Vector2i(0, 19)
const WALL_2H_WEST_BASE := Vector2i(0, 20)
const WALL_2H_EAST_TOP := Vector2i(5, 19)
const WALL_2H_EAST_BASE := Vector2i(5, 20)

# Narożniki wewnętrzne / skosy 2H:
const WALL_2H_SLOPE_LEFT_TOP := Vector2i(1, 19)
const WALL_2H_SLOPE_LEFT_MID := Vector2i(1, 20)
const WALL_2H_SLOPE_LEFT_BASE := Vector2i(1, 21)

const WALL_2H_SLOPE_RIGHT_TOP := Vector2i(4, 19)
const WALL_2H_SLOPE_RIGHT_MID := Vector2i(4, 20)
const WALL_2H_SLOPE_RIGHT_BASE := Vector2i(4, 21)

# Łączniki modularne (przejścia między fasadą 2H a 3H):
# Przejście 2H (lewo) -> 3H (prawo): kolumna 7
const CONNECTOR_2H_TO_3H_TOP := Vector2i(7, 19)
const CONNECTOR_2H_TO_3H_MID := Vector2i(7, 20)
const CONNECTOR_2H_TO_3H_BASE := Vector2i(7, 21)

# Przejście 3H (lewo) -> 2H (prawo): kolumna 10
const CONNECTOR_3H_TO_2H_TOP := Vector2i(10, 19)
const CONNECTOR_3H_TO_2H_MID := Vector2i(10, 20)
const CONNECTOR_3H_TO_2H_BASE := Vector2i(10, 21)



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
	width: int = 160,
	height: int = 160,
	seed_val: int = -1,
	min_room_size: int = 6,
	max_room_size: int = 24,
	max_rooms: int = 15,
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
	var max_attempts := maxi(300, max_rooms * 25)

	while rooms.size() < max_rooms and attempts < max_attempts:
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
		_carve_cave_chamber(result.grid, new_room, rng, width, height)

	result.rooms = rooms

	# 3. Korytarze jaskiniowe - Minimum Spanning Tree (MST) gwarantujące połączenie wszystkich komór
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
				_carve_organic_corridor(result.grid, rooms[best_conn].get_center(), rooms[best_unconn].get_center(), corridor_width, rng, width, height)
				connected_indices.append(best_unconn)
				unconnected_indices.remove_at(best_unconn_idx)

		# Dodatkowe korytarze pętlowe (cykle) między bliskimi komorami
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
					_carve_organic_corridor(result.grid, rooms[idx_a].get_center(), rooms[idx_b].get_center(), corridor_width, rng, width, height)
					loops_added += 1

	# 4. Wymuszenie minimalnej grubości murów i eliminacja ścian o wysokości 1 kratki
	_remove_1height_walls(result.grid, width, height)
	_enforce_wall_thickness(result.grid, width, height)

	# 4.5. Twarda gwarancja spójności po wszystkich modyfikacjach gridu.
	_ensure_rooms_connected(result.grid, rooms, width, height, corridor_width, rng)

	# 5. Dedykowane wejście i wyjście - ZAWSZE obecne na mapie
	if not rooms.is_empty():
		# Znajdź parę komór o maksymalnym dystansie między centrami
		var entrance_room_idx := 0
		var exit_room_idx: int = rooms.size() - 1
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

		# Wyrzeźb tunel wejściowy (z najbliższej krawędzi mapy)
		var entrance_data: Dictionary = _carve_portal_alcove(result.grid, entrance_room, width, height, rng)
		result.entrance_pos = entrance_data["center"] as Vector2i
		result.player_spawn = entrance_data["center"] as Vector2i
		result.entrance_zone = entrance_data["cells"] as Array[Vector2i]
		for p in result.entrance_zone:
			result.grid[p] = CellType.ENTRANCE

		# Wyrzeźb tunel wyjściowy (unikaj krawędzi użytej przez wejście)
		var exit_data: Dictionary = _carve_portal_alcove(result.grid, exit_room, width, height, rng, int(entrance_data["edge"]))
		result.exit_pos = exit_data["center"] as Vector2i
		result.exit_zone = exit_data["cells"] as Array[Vector2i]
		for p in result.exit_zone:
			result.grid[p] = CellType.EXIT

		# Boss w pokoju wyjściowym
		result.enemy_spawns.append({
			"pos": exit_room.get_center() + Vector2i(0, -2),
			"tier": 3
		})

		# Wrogowie i skrzynie w pokojach pośrednich
		for i in range(rooms.size()):
			if i == entrance_room_idx or i == exit_room_idx:
				continue
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

		# 6. Ostateczna eliminacja ścian o wysokości 1 kratki oraz egzekucja grubości murów po wycięciu portali
		_remove_1height_walls(result.grid, width, height)
		_enforce_wall_thickness(result.grid, width, height)
		_remove_1height_walls(result.grid, width, height)

	return result


## Zwraca wszystkie przechodnie komórki osiągalne ze startu (4-kierunkowy flood fill).
static func _get_reachable_cells(grid: Dictionary, start: Vector2i, width: int, height: int) -> Dictionary:
	var reachable: Dictionary = {}
	if not _is_walkable(grid, start):
		return reachable

	var queue: Array[Vector2i] = [start]
	var head := 0
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	reachable[start] = true

	while head < queue.size():
		var current := queue[head]
		head += 1
		for direction in directions:
			var next := current + direction
			if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
				continue
			if reachable.has(next) or not _is_walkable(grid, next):
				continue
			reachable[next] = true
			queue.append(next)

	return reachable


## Dopina komory odłączone po korektach grubości ścian.
static func _ensure_rooms_connected(grid: Dictionary, rooms: Array[Rect2i], width: int, height: int, corridor_width: int, rng: RandomNumberGenerator) -> void:
	if rooms.size() < 2:
		return

	var reachable := _get_reachable_cells(grid, rooms[0].get_center(), width, height)
	for room in rooms:
		var target := room.get_center()
		if reachable.has(target):
			continue

		var source := Vector2i.ZERO
		var best_distance := INF
		for connected_room in rooms:
			var candidate := connected_room.get_center()
			if not reachable.has(candidate):
				continue
			var distance := Vector2(candidate).distance_squared_to(Vector2(target))
			if distance < best_distance:
				best_distance = distance
				source = candidate

		if best_distance == INF:
			push_error("CaveGenerator: missing reachable room while repairing connectivity.")
			return

		_carve_organic_corridor(grid, source, target, maxi(corridor_width, 3), rng, width, height)
		reachable = _get_reachable_cells(grid, rooms[0].get_center(), width, height)


## Usuwa pojedyncze ściany o wysokości 1 kratki (obszar walls o wysokości 1 kratki nie może istnieć)
static func _remove_1height_walls(grid: Dictionary, width: int, height: int) -> void:
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var p := Vector2i(x, y)
			if not _is_walkable(grid, p):
				# Jeśli bezpośrednio nad i pod tą kratką jest podłoga, to pionowa wysokość ściany wynosi 1
				if _is_walkable(grid, p + Vector2i(0, -1)) and _is_walkable(grid, p + Vector2i(0, 1)):
					grid[p] = CellType.FLOOR


## Rzeźbi komorę o naturalnych, organicznych kształtach jaskini (rdzeń eliptyczny + losowe wybrzuszenia)
static func _carve_cave_chamber(grid: Dictionary, rect: Rect2i, rng: RandomNumberGenerator, map_w: int = 160, map_h: int = 160) -> void:
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
		carve_circle(grid, lobe_center, lobe_radius, CellType.FLOOR, map_w, map_h)


## Rzeźbi meandrujący, zaokrąglony korytarz jaskiniowy
static func _carve_organic_corridor(grid: Dictionary, from: Vector2i, to: Vector2i, width: int, rng: RandomNumberGenerator, map_w: int = 160, map_h: int = 160) -> void:
	var mid := (from + to) / 2
	var dir := Vector2(to - from).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var jitter := normal * rng.randf_range(-3.0, 3.0)
	var mid_curved := Vector2i(mid + Vector2i(int(jitter.x), int(jitter.y)))
	mid_curved.x = clampi(mid_curved.x, 3, map_w - 4)
	mid_curved.y = clampi(mid_curved.y, 3, map_h - 4)

	var points = [from, mid_curved, to]
	for seg in range(points.size() - 1):
		var p0: Vector2 = Vector2(points[seg])
		var p1: Vector2 = Vector2(points[seg + 1])
		var dist := p0.distance_to(p1)
		var steps := int(dist * 2.0)
		for s in range(steps + 1):
			var t := float(s) / maxf(float(steps), 1.0)
			var cur := p0.lerp(p1, t)
			carve_circle(grid, Vector2i(int(cur.x), int(cur.y)), width / 2 + 1, CellType.FLOOR, map_w, map_h)


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

					# Jeśli ściana dzieli dwie komory w pionie i ma mniej niż 2 kratki (nie zmieści żadnego modułu):
					if has_floor_above and has_floor_below and wall_len < 2:
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


## Wyrzeźbi dedykowany tunel portalowy z komory ku krawędzi mapy, zakończony niszą wejściową/wyjściową.
## Zwraca Dictionary {"center": Vector2i, "edge": int (0=N, 1=E, 2=S, 3=W), "cells": Array[Vector2i]}
static func _carve_portal_alcove(grid: Dictionary, room: Rect2i, map_w: int, map_h: int, rng: RandomNumberGenerator, avoid_edge: int = -1) -> Dictionary:
	const ALCOVE_RADIUS := 2
	const ALCOVE_NORTH_EXTRA := 1  # Dodatkowy wiersz w górę na bazę fasady ściany północnej
	const MAP_BORDER := 2
	const MIN_TUNNEL_LENGTH := 5
	const ALCOVE_CENTER_MARGIN := ALCOVE_RADIUS + MAP_BORDER

	var center := room.get_center()
	var edge_dists: Array[Dictionary] = [
		{"edge": 0, "dist": center.y},
		{"edge": 1, "dist": map_w - 1 - center.x},
		{"edge": 2, "dist": map_h - 1 - center.y},
		{"edge": 3, "dist": center.x},
	]
	edge_dists.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dist"]) < int(b["dist"]))

	var chosen_edge := -1
	var chosen_dir := Vector2i.ZERO
	var chosen_start := Vector2i.ZERO
	var chosen_perp := Vector2i.ZERO
	var chosen_max_length := 0

	# Wybieramy najbliższą dozwoloną krawędź tylko wtedy, gdy po tunelu
	# zmieści się pełna alkowa 5x5 wraz z marginesem mapy.
	for edge_data in edge_dists:
		var edge := int(edge_data["edge"])
		if edge == avoid_edge:
			continue

		var dir := Vector2i.ZERO
		var tunnel_start := Vector2i.ZERO
		var perp := Vector2i.ZERO
		var max_length := 0

		match edge:
			0:
				dir = Vector2i(0, -1)
				tunnel_start = Vector2i(center.x, room.position.y - 1)
				perp = Vector2i(1, 0)
				max_length = tunnel_start.y - (ALCOVE_CENTER_MARGIN + ALCOVE_NORTH_EXTRA)
			1:
				dir = Vector2i(1, 0)
				tunnel_start = Vector2i(room.position.x + room.size.x, center.y)
				perp = Vector2i(0, 1)
				max_length = map_w - 1 - ALCOVE_CENTER_MARGIN - tunnel_start.x
			2:
				dir = Vector2i(0, 1)
				tunnel_start = Vector2i(center.x, room.position.y + room.size.y)
				perp = Vector2i(1, 0)
				max_length = map_h - 1 - ALCOVE_CENTER_MARGIN - tunnel_start.y
			3:
				dir = Vector2i(-1, 0)
				tunnel_start = Vector2i(room.position.x - 1, center.y)
				perp = Vector2i(0, 1)
				max_length = tunnel_start.x - ALCOVE_CENTER_MARGIN

		if max_length >= MIN_TUNNEL_LENGTH:
			chosen_edge = edge
			chosen_dir = dir
			chosen_start = tunnel_start
			chosen_perp = perp
			chosen_max_length = max_length
			break

	# Przy obecnym bezpiecznym marginesie generacji zawsze powinna istnieć
	# przynajmniej jedna poprawna krawędź. Nie twórz częściowej alkowy, jeśli nie ma.
	if chosen_edge == -1:
		push_error("CaveGenerator: no safe edge for portal alcove.")
		return {"center": center, "edge": -1, "cells": []}

	var tunnel_length := mini(rng.randi_range(5, 7), chosen_max_length)
	var current := chosen_start
	for i in range(tunnel_length):
		for w in range(-ALCOVE_RADIUS, ALCOVE_RADIUS + 1):
			var p := current + chosen_perp * w
			if p.x >= MAP_BORDER and p.x < map_w - MAP_BORDER and p.y >= MAP_BORDER and p.y < map_h - MAP_BORDER:
				grid[p] = CellType.FLOOR
		current += chosen_dir

	var alcove_cells: Array[Vector2i] = []
	for dy in range(-ALCOVE_RADIUS - ALCOVE_NORTH_EXTRA, ALCOVE_RADIUS + 1):
		for dx in range(-ALCOVE_RADIUS, ALCOVE_RADIUS + 1):
			var p := current + Vector2i(dx, dy)
			if p.x >= MAP_BORDER and p.x < map_w - MAP_BORDER and p.y >= MAP_BORDER and p.y < map_h - MAP_BORDER:
				grid[p] = CellType.FLOOR
				# Dodatkowy wiersz u góry (dy < -ALCOVE_RADIUS) przeznaczony jest na bazę fasady;
				# nie włączamy go do alcove_cells/portal_zone, aby czyszczenie kolizji nie usunęło bazy.
				if dy >= -ALCOVE_RADIUS:
					alcove_cells.append(p)

	return {"center": current, "edge": chosen_edge, "cells": alcove_cells}

## Nanosi dopasowane kafelki z caves.tres na warstwy Floor, FloorDecor i Walls
static func apply_cave_tiles(
	floor_layer: TileMapLayer,
	walls_layer: TileMapLayer,
	result: GenerationResult,
	rng: RandomNumberGenerator,
	floor_decor_layer: TileMapLayer = null,
	theme_override: int = -1
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

	# Gwarancja: obszar walls o wysokości 1 kratki nie powinien generować ścian
	_remove_1height_walls(grid, width, height)

	# 1. WYPEŁNIENIE VOIDU
	for y in range(-4, height + 4):
		for x in range(-4, width + 4):
			var pos := Vector2i(x, y)
			if not _is_walkable(grid, pos):
				walls_layer.set_cell(pos, 0, WALL_INSIDE)

	# 2. PODŁOGA DWUWARSTWOWA (Kamienna z plamami błota/ziemi + osobna warstwa mchu/trawy)
	var near_floor: Dictionary = {}
	for pos in grid.keys():
		if _is_walkable(grid, pos):
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					near_floor[pos + Vector2i(dx, dy)] = true

	var ground_cells: Array[Vector2i] = []
	for pos in near_floor.keys():
		ground_cells.append(pos)

	# 2a. Bazowe wypełnienie podłogi kafelkiem (10, 13) (Terrain 0)
	for p in ground_cells:
		floor_layer.set_cell(p, 0, Vector2i(10, 13))

	# 2b. Organiczne plamy ziemi / błota (Terrain 1 'Mud') na warstwie brązowej podłogi
	# Duże, rozległe plamy błota (niska częstotliwość)
	var mud_noise := FastNoiseLite.new()
	mud_noise.seed = rng.seed + 202
	mud_noise.frequency = 0.035

	var portal_zone: Dictionary = {}
	for p in result.entrance_zone:
		portal_zone[p] = true
	for p in result.exit_zone:
		portal_zone[p] = true

	var mud_candidates := {}
	for p in ground_cells:
		if portal_zone.has(p):
			continue
		if mud_noise.get_noise_2d(float(p.x), float(p.y)) > -0.02:
			mud_candidates[p] = true

	var mud_cells_set := {}
	for p in mud_candidates.keys():
		if mud_candidates.has(p + Vector2i(1, 0)) and mud_candidates.has(p + Vector2i(0, 1)) and mud_candidates.has(p + Vector2i(1, 1)):
			mud_cells_set[p] = true
			mud_cells_set[p + Vector2i(1, 0)] = true
			mud_cells_set[p + Vector2i(0, 1)] = true
			mud_cells_set[p + Vector2i(1, 1)] = true

	var mud_cells: Array[Vector2i] = []
	for p in mud_cells_set.keys():
		mud_cells.append(p)

	floor_layer.set_cells_terrain_connect(mud_cells, 0, 1, true)

	# 2c. Organiczne plamy mchu / trawy (Terrain 2 'Grass') na osobnej warstwie FloorDecor
	# Mniejsze, ale częstsze plamy mchu (wyższa częstotliwość)
	var grass_noise := FastNoiseLite.new()
	grass_noise.seed = rng.seed
	grass_noise.frequency = 0.13

	var grass_candidates := {}
	for p in ground_cells:
		if portal_zone.has(p):
			continue
		if grass_noise.get_noise_2d(float(p.x), float(p.y)) > 0.10:
			grass_candidates[p] = true

	var grass_cells_set := {}
	for p in grass_candidates.keys():
		if grass_candidates.has(p + Vector2i(1, 0)) and grass_candidates.has(p + Vector2i(0, 1)) and grass_candidates.has(p + Vector2i(1, 1)):
			grass_cells_set[p] = true
			grass_cells_set[p + Vector2i(1, 0)] = true
			grass_cells_set[p + Vector2i(0, 1)] = true
			grass_cells_set[p + Vector2i(1, 1)] = true

	var grass_cells: Array[Vector2i] = []
	for p in grass_cells_set.keys():
		grass_cells.append(p)

	if floor_decor_layer:
		floor_decor_layer.set_cells_terrain_connect(grass_cells, 0, 2, true)

	# 3. MOTYW ŚCIAN: SZUM O PLAMACH NA KILKA KRATEK (30% Roots, 70% Standard Rock)
	# Oraz drobny szum dla częstych zmian wariantów A/B ścian prostych
	var roots_theme_noise := FastNoiseLite.new()
	roots_theme_noise.seed = rng.seed + 333
	roots_theme_noise.frequency = 0.08  # Większy szum - plamy o szerokości kilku kratek

	var ab_noise := FastNoiseLite.new()
	ab_noise.seed = rng.seed + 777
	ab_noise.frequency = 0.45  # Drobny szum - warianty A/B zmieniają się co 1-2 kratki

	var res_entrance: Vector2i = result.entrance_pos
	var res_exit: Vector2i = result.exit_pos

	var get_use_roots := func(pos: Vector2i) -> bool:
		if theme_override == 0:
			return false
		if theme_override == 1:
			return true
		# W strefach portali zapewnij jednolity motyw dla całego pokoju
		if res_entrance != Vector2i.ZERO and abs(pos.x - res_entrance.x) <= 4 and abs(pos.y - res_entrance.y) <= 4:
			return roots_theme_noise.get_noise_2d(float(res_entrance.x), float(res_entrance.y)) > 0.14
		if res_exit != Vector2i.ZERO and abs(pos.x - res_exit.x) <= 4 and abs(pos.y - res_exit.y) <= 4:
			return roots_theme_noise.get_noise_2d(float(res_exit.x), float(res_exit.y)) > 0.14
		# Progiem 0.14 uzyskujemy ~30% powierzchni dla dekorowanego zestawu (Roots)
		return roots_theme_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.14

	# 4. POTOK KAFELKOWANIA ŚCIAN (GROUND TRUTH MODULAR PIPELINE)
	var placed_tiles: Dictionary = {}

	# FAZA 1: Wypełnienie litej skały (Rock Fill)
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not _is_walkable(grid, pos):
				var r := (int(hash(Vector2i(x, y + rng.seed))) & 0x7fffffff) % 100
				var rock_t := Vector2i(2, 3)
				if r < 45:
					rock_t = Vector2i(2, 2)
				elif r < 92:
					rock_t = Vector2i(2, 3)
				else:
					rock_t = Vector2i(3, 2)
				walls_layer.set_cell(pos, 0, rock_t)
				placed_tiles[pos] = "ROCK"

	# FAZA 2: Fasady południowe i schodkowe łuki
	# Bazy fasad leżą w pierwszym wierszu otwartej podłogi pod sufitem (cur == 1, prev == 0)
	var facade_cols: Dictionary = {} # x -> Array of y positions
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if _is_walkable(grid, pos) and not _is_walkable(grid, pos + Vector2i(0, -1)):
				# Sprawdź, czy nad głową jest co najmniej 2 kratki ściany (fasada 2H lub 3H)
				if not _is_walkable(grid, pos + Vector2i(0, -2)):
					if not facade_cols.has(x):
						facade_cols[x] = []
					facade_cols[x].append(y)

	var sorted_xs: Array = facade_cols.keys()
	sorted_xs.sort()

	var step_downs: Array[Dictionary] = []

	for x in sorted_xs:
		for y in facade_cols[x]:
			var pos := Vector2i(x, y)
			if placed_tiles.has(pos) and placed_tiles[pos] == "FACADE":
				continue
			var use_roots: bool = get_use_roots.call(pos)

			# 1. Obsługa fasady 2-kratkowej (gdy ściana ma grubość dokładnie 2 kratek)
			var has_same_y := func(cx: int, cy: int) -> bool:
				if not facade_cols.has(cx): return false
				for fy in facade_cols[cx]:
					if abs(fy - cy) <= 1: return true
				return false

			var is_horizontal_facade: bool = has_same_y.call(x - 1, y) or has_same_y.call(x + 1, y)
			var is_2h: bool = is_horizontal_facade and _is_walkable(grid, pos + Vector2i(0, -3))
			if is_2h:
				var is_west_end: bool = _is_walkable(grid, pos + Vector2i(-1, -1)) or _is_walkable(grid, pos + Vector2i(-1, -2))
				var is_east_end: bool = _is_walkable(grid, pos + Vector2i(1, -1)) or _is_walkable(grid, pos + Vector2i(1, -2))

				var top_2h: Vector2i = Vector2i.ZERO
				var base_2h: Vector2i = Vector2i.ZERO

				if is_west_end and not is_east_end:
					top_2h = WALL_2H_WEST_TOP
					base_2h = WALL_2H_WEST_BASE
				elif is_east_end and not is_west_end:
					top_2h = WALL_2H_EAST_TOP
					base_2h = WALL_2H_EAST_BASE
				else:
					var is_b: bool = ab_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
					top_2h = WALL_2H_TOP[1] if is_b else WALL_2H_TOP[0]
					base_2h = WALL_2H_BASE[1] if is_b else WALL_2H_BASE[0]

				walls_layer.set_cell(pos + Vector2i(0, -2), 0, top_2h)
				walls_layer.set_cell(pos + Vector2i(0, -1), 0, base_2h)
				placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
				continue

			# 2. Obsługa łączników modułowych 2H <-> 3H
			var check_2h_col := func(cx: int, fy: int) -> bool:
				return _is_walkable(grid, Vector2i(cx, fy)) \
					and not _is_walkable(grid, Vector2i(cx, fy - 1)) \
					and not _is_walkable(grid, Vector2i(cx, fy - 2)) \
					and _is_walkable(grid, Vector2i(cx, fy - 3))

			var left_is_2h_same: bool = check_2h_col.call(x - 1, y)
			var left_is_2h_step: bool = check_2h_col.call(x - 1, y - 1)
			var right_is_2h_same: bool = check_2h_col.call(x + 1, y)
			var right_is_2h_step: bool = check_2h_col.call(x + 1, y - 1)

			if (left_is_2h_same or left_is_2h_step) and not (right_is_2h_same or right_is_2h_step):
				# Łącznik: przejście z 2H po lewej do 3H po prawej (kolumna 7)
				var dy_off := 0 if left_is_2h_same else -1
				walls_layer.set_cell(pos + Vector2i(0, -2 + dy_off), 0, CONNECTOR_2H_TO_3H_TOP)
				walls_layer.set_cell(pos + Vector2i(0, -1 + dy_off), 0, CONNECTOR_2H_TO_3H_MID)
				walls_layer.set_cell(pos + Vector2i(0, dy_off), 0, CONNECTOR_2H_TO_3H_BASE)
				placed_tiles[pos + Vector2i(0, -2 + dy_off)] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1 + dy_off)] = "FACADE"
				placed_tiles[pos + Vector2i(0, dy_off)] = "FACADE"
				continue
			elif (right_is_2h_same or right_is_2h_step) and not (left_is_2h_same or left_is_2h_step):
				# Łącznik: przejście z 3H po lewej do 2H po prawej (kolumna 10)
				var dy_off := 0 if right_is_2h_same else -1
				walls_layer.set_cell(pos + Vector2i(0, -2 + dy_off), 0, CONNECTOR_3H_TO_2H_TOP)
				walls_layer.set_cell(pos + Vector2i(0, -1 + dy_off), 0, CONNECTOR_3H_TO_2H_MID)
				walls_layer.set_cell(pos + Vector2i(0, dy_off), 0, CONNECTOR_3H_TO_2H_BASE)
				placed_tiles[pos + Vector2i(0, -2 + dy_off)] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1 + dy_off)] = "FACADE"
				placed_tiles[pos + Vector2i(0, dy_off)] = "FACADE"
				continue

			# Sprawdź OUT corner ("jak jest schodek tylko jeden w bok to powinien być użyty narożnik out zamiast zwykłej ściany")
			var w_open := not _is_walkable(grid, pos + Vector2i(1, 0)) \
				and _is_walkable(grid, pos + Vector2i(-1, -1)) \
				and _is_walkable(grid, pos + Vector2i(-1, -2)) \
				and _is_walkable(grid, pos + Vector2i(-1, -3))
			var e_open := not _is_walkable(grid, pos + Vector2i(-1, 0)) \
				and _is_walkable(grid, pos + Vector2i(1, -1)) \
				and _is_walkable(grid, pos + Vector2i(1, -2)) \
				and _is_walkable(grid, pos + Vector2i(1, -3))

			if w_open and not e_open:
				var is_2h_corner := _is_walkable(grid, pos + Vector2i(0, -3))
				if is_2h_corner:
					var base_2h := WALL_2H_WEST_BASE
					var top_2h := WALL_2H_WEST_TOP
					var crown_2h := Vector2i(0, 1)
					walls_layer.set_cell(pos + Vector2i(0, -1), 0, base_2h)
					walls_layer.set_cell(pos + Vector2i(0, -2), 0, top_2h)
					walls_layer.set_cell(pos + Vector2i(0, -3), 0, crown_2h)
					placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -3)] = "FACADE"
					var p_in := pos + Vector2i(1, -2)
					if not _is_walkable(grid, p_in):
						var in_corner := CRNR_SE_IN  # Zawsze niedekorowany – pod nim jest ściana B, nie ROOT TOP
						walls_layer.set_cell(p_in, 0, in_corner)
						placed_tiles[p_in] = "CORNER"
					var p_side := pos + Vector2i(1, -1)
					if not _is_walkable(grid, p_side) and (not placed_tiles.has(p_side) or placed_tiles[p_side] == "ROCK"):
						var side_b := WALL_SIDE_EAST[1] if not use_roots else ROOT_WALL_SIDE_EAST[1]
						walls_layer.set_cell(p_side, 0, side_b)
						placed_tiles[p_side] = "SIDE_FIXED"
				else:
					var top_t := MOD_CRNR_NW_OUT_TOP if not use_roots else ROOT_MOD_CRNR_NW_OUT_TOP
					var mid_t := MOD_CRNR_NW_OUT_MID if not use_roots else ROOT_MOD_CRNR_NW_OUT_MID
					var base_t := MOD_CRNR_NW_OUT_BASE if not use_roots else ROOT_MOD_CRNR_NW_OUT_BASE
					walls_layer.set_cell(pos, 0, base_t)
					walls_layer.set_cell(pos + Vector2i(0, -1), 0, mid_t)
					walls_layer.set_cell(pos + Vector2i(0, -2), 0, top_t)
					placed_tiles[pos] = "FACADE"
					placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
				step_downs.append({"x": x, "y": y, "dir": 1})
				continue
			elif e_open and not w_open:
				var is_2h_corner := _is_walkable(grid, pos + Vector2i(0, -3))
				if is_2h_corner:
					var base_2h := WALL_2H_EAST_BASE
					var top_2h := WALL_2H_EAST_TOP
					var crown_2h := Vector2i(5, 1)
					walls_layer.set_cell(pos + Vector2i(0, -1), 0, base_2h)
					walls_layer.set_cell(pos + Vector2i(0, -2), 0, top_2h)
					walls_layer.set_cell(pos + Vector2i(0, -3), 0, crown_2h)
					placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -3)] = "FACADE"
					var p_in := pos + Vector2i(-1, -2)
					if not _is_walkable(grid, p_in):
						var in_corner := CRNR_SE_IN  # Zawsze niedekorowany – pod nim jest ściana B, nie ROOT TOP
						walls_layer.set_cell(p_in, 0, in_corner)
						placed_tiles[p_in] = "CORNER"
					var p_side := pos + Vector2i(-1, -1)
					if not _is_walkable(grid, p_side) and (not placed_tiles.has(p_side) or placed_tiles[p_side] == "ROCK"):
						var side_b := WALL_SIDE_WEST[1] if not use_roots else ROOT_WALL_SIDE_WEST[1]
						walls_layer.set_cell(p_side, 0, side_b)
						placed_tiles[p_side] = "SIDE_FIXED"
				else:
					var top_t := MOD_CRNR_NE_OUT_TOP if not use_roots else ROOT_MOD_CRNR_NE_OUT_TOP
					var mid_t := MOD_CRNR_NE_OUT_MID if not use_roots else ROOT_MOD_CRNR_NE_OUT_MID
					var base_t := MOD_CRNR_NE_OUT_BASE if not use_roots else ROOT_MOD_CRNR_NE_OUT_BASE
					walls_layer.set_cell(pos, 0, base_t)
					walls_layer.set_cell(pos + Vector2i(0, -1), 0, mid_t)
					walls_layer.set_cell(pos + Vector2i(0, -2), 0, top_t)
					placed_tiles[pos] = "FACADE"
					placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
				step_downs.append({"x": x, "y": y, "dir": -1})
				continue

			# Określenie typu kolumny na podstawie sąsiadów
			var left_y: int = -1
			if facade_cols.has(x - 1):
				for ly in facade_cols[x - 1]:
					if abs(ly - y) <= 4:
						left_y = ly
						break
			var right_y: int = -1
			if facade_cols.has(x + 1):
				for ry in facade_cols[x + 1]:
					if abs(ry - y) <= 4:
						right_y = ry
						break

			if left_y != -1 and y > left_y:
				# Schodek opada z lewej w prawo (kolumna y jest niżej niż lewy sąsiad)
				var dy: int = y - left_y
				# ZASADA: Moduł dekorowany MOD_CRNR_NW/NE_IN nie może się pojawić, jeśli bezpośrednio nad nim nie ma CRNR_SE/SW_IN.
				# Jeśli jest odstęp o ścianę (dy > 1), to musi zawsze być niedekorowany zestaw MOD_CRNR_NW/NE_IN oraz CRNR_SE/SW_IN.
				var step_use_roots: bool = use_roots and (dy == 1)

				var base_t := MOD_CRNR_NW_IN_BASE if not step_use_roots else ROOT_MOD_CRNR_NW_IN_BASE
				var mid_t := MOD_CRNR_NW_IN_MID if not step_use_roots else ROOT_MOD_CRNR_NW_IN_MID
				var top_t := MOD_CRNR_NW_IN_TOP if not step_use_roots else ROOT_MOD_CRNR_NW_IN_TOP

				walls_layer.set_cell(pos, 0, base_t)
				walls_layer.set_cell(pos + Vector2i(0, -1), 0, mid_t)
				walls_layer.set_cell(pos + Vector2i(0, -2), 0, top_t)
				placed_tiles[pos] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
				placed_tiles[pos + Vector2i(0, -2)] = "FACADE"

				if dy == 1:
					var crown_t := ROOT_CRNR_SE_IN if step_use_roots else CRNR_SE_IN
					walls_layer.set_cell(pos + Vector2i(0, -3), 0, crown_t)
					placed_tiles[pos + Vector2i(0, -3)] = "FACADE"
				else:
					var p_crown := Vector2i(x, left_y - 2)
					var crown_t := CRNR_SE_IN
					walls_layer.set_cell(p_crown, 0, crown_t)
					placed_tiles[p_crown] = "CORNER"

					var p_side := Vector2i(x, left_y - 1)
					var side_t := WALL_SIDE_EAST[1]
					walls_layer.set_cell(p_side, 0, side_t)
					placed_tiles[p_side] = "SIDE_FIXED"

				# Sprawdź, czy schodek kończy się w dół (prawy sąsiad to lita ściana kontynuująca w dół)
				if not _is_walkable(grid, pos + Vector2i(1, 0)):
					step_downs.append({"x": x, "y": y, "dir": 1})

			elif right_y != -1 and y > right_y:
				# Schodek opada z prawej w lewo (kolumna y jest niżej niż prawy sąsiad)
				var dy: int = y - right_y
				var step_use_roots: bool = use_roots and (dy == 1)

				var base_t := MOD_CRNR_NE_IN_BASE if not step_use_roots else ROOT_MOD_CRNR_NE_IN_BASE
				var mid_t := MOD_CRNR_NE_IN_MID if not step_use_roots else ROOT_MOD_CRNR_NE_IN_MID
				var top_t := MOD_CRNR_NE_IN_TOP if not step_use_roots else ROOT_MOD_CRNR_NE_IN_TOP

				walls_layer.set_cell(pos, 0, base_t)
				walls_layer.set_cell(pos + Vector2i(0, -1), 0, mid_t)
				walls_layer.set_cell(pos + Vector2i(0, -2), 0, top_t)
				placed_tiles[pos] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
				placed_tiles[pos + Vector2i(0, -2)] = "FACADE"

				if dy == 1:
					var crown_t := ROOT_CRNR_SW_IN if step_use_roots else CRNR_SW_IN
					walls_layer.set_cell(pos + Vector2i(0, -3), 0, crown_t)
					placed_tiles[pos + Vector2i(0, -3)] = "FACADE"
				else:
					var p_crown := Vector2i(x, right_y - 2)
					var crown_t := CRNR_SW_IN
					walls_layer.set_cell(p_crown, 0, crown_t)
					placed_tiles[p_crown] = "CORNER"

					var p_side := Vector2i(x, right_y - 1)
					var side_t := WALL_SIDE_WEST[1]
					walls_layer.set_cell(p_side, 0, side_t)
					placed_tiles[p_side] = "SIDE_FIXED"

				# Sprawdź, czy schodek kończy się w dół (lewy sąsiad to lita ściana kontynuująca w dół)
				if not _is_walkable(grid, pos + Vector2i(-1, 0)):
					step_downs.append({"x": x, "y": y, "dir": -1})

			else:
				# Sprawdź, czy można zastosować dwukafelkową niszową formację dodającą głębi ścianom
				# Para modułów: (MOD_CRNR_NW_IN + nad nim CRNR_SE_IN) z lewej oraz (MOD_CRNR_NE_IN + nad nim CRNR_SW_IN) z prawej
				# ZASADA: nie generuj nisz, jeśli sąsiad z lewej/prawej jest na innej wysokości, ściana schodzi w dół, lub jest to strefa portalu!
				var can_niche := false
				var pos_next := Vector2i(x + 1, y)
				var is_in_portal := portal_zone.has(pos + Vector2i(0, 1)) or portal_zone.has(pos_next + Vector2i(0, 1))

				if not is_in_portal and facade_cols.has(x + 1) and facade_cols[x + 1].has(y):
					if not (placed_tiles.has(pos_next) and placed_tiles[pos_next] == "FACADE"):
						# Kafelek z lewej (x - 1) MUSI być na DOKŁADNIE tej samej wysokości y
						var left_has_same_y: bool = facade_cols.has(x - 1) and facade_cols[x - 1].has(y)
						# Kafelek z prawej (x + 2) MUSI być na DOKŁADNIE tej samej wysokości y
						var right_has_same_y: bool = facade_cols.has(x + 2) and facade_cols[x + 2].has(y)

						# Sąsiad 1 w bok 1 w dół: jeśli ściana idzie w dół (lity mur lub schodek fasady), nie twórz niszy
						var left_down_wall: bool = not _is_walkable(grid, Vector2i(x - 1, y + 1)) or (facade_cols.has(x - 1) and facade_cols[x - 1].has(y + 1))
						var right_down_wall: bool = not _is_walkable(grid, Vector2i(x + 2, y + 1)) or (facade_cols.has(x + 2) and facade_cols[x + 2].has(y + 1))
						var front_is_walkable: bool = _is_walkable(grid, Vector2i(x, y + 1)) and _is_walkable(grid, Vector2i(x + 1, y + 1))
						# Nisza nie powinna dotykać bezpośrednio bocznych ścian pomieszczenia
						var left_wall_clear: bool = _is_walkable(grid, Vector2i(x - 2, y))
						var right_wall_clear: bool = _is_walkable(grid, Vector2i(x + 3, y))

						if left_has_same_y and right_has_same_y and not left_down_wall and not right_down_wall and front_is_walkable and left_wall_clear and right_wall_clear:
							can_niche = true

				if can_niche and rng.randf() < 0.15:
					# Nisza odwrócona: lewy = MOD_CRNR_NE_OUT, prawy = MOD_CRNR_NW_OUT
					# Razem tworzą wgłębienie skierowane do wewnątrz (ściana-NE_OUT-NW_OUT-ściana)
					var l_crown := WALL_TOP_CORNER_RIGHT  # (5,1) – korona nad MOD_CRNR_NE_OUT
					var l_top := MOD_CRNR_NE_OUT_TOP if not use_roots else ROOT_MOD_CRNR_NE_OUT_TOP
					var l_mid := MOD_CRNR_NE_OUT_MID if not use_roots else ROOT_MOD_CRNR_NE_OUT_MID
					var l_base := MOD_CRNR_NE_OUT_BASE if not use_roots else ROOT_MOD_CRNR_NE_OUT_BASE

					walls_layer.set_cell(pos + Vector2i(0, -3), 0, l_crown)
					walls_layer.set_cell(pos + Vector2i(0, -2), 0, l_top)
					walls_layer.set_cell(pos + Vector2i(0, -1), 0, l_mid)
					walls_layer.set_cell(pos, 0, l_base)
					placed_tiles[pos + Vector2i(0, -3)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
					placed_tiles[pos] = "FACADE"

					# Prawy moduł: MOD_CRNR_NW_OUT – patrzy w lewo, domyka wgłębienie od prawej
					var r_crown := WALL_TOP_CORNER_LEFT  # (0,1) – korona nad MOD_CRNR_NW_OUT
					var r_top := MOD_CRNR_NW_OUT_TOP if not use_roots else ROOT_MOD_CRNR_NW_OUT_TOP
					var r_mid := MOD_CRNR_NW_OUT_MID if not use_roots else ROOT_MOD_CRNR_NW_OUT_MID
					var r_base := MOD_CRNR_NW_OUT_BASE if not use_roots else ROOT_MOD_CRNR_NW_OUT_BASE

					walls_layer.set_cell(pos_next + Vector2i(0, -3), 0, r_crown)
					walls_layer.set_cell(pos_next + Vector2i(0, -2), 0, r_top)
					walls_layer.set_cell(pos_next + Vector2i(0, -1), 0, r_mid)
					walls_layer.set_cell(pos_next, 0, r_base)
					placed_tiles[pos_next + Vector2i(0, -3)] = "FACADE"
					placed_tiles[pos_next + Vector2i(0, -2)] = "FACADE"
					placed_tiles[pos_next + Vector2i(0, -1)] = "FACADE"
					placed_tiles[pos_next] = "FACADE"
					continue

				# Ściana prosta MOD_WALL_A / MOD_WALL_B
				var is_b: bool = ab_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
				var top_t := WALL_BOTTOM_TOP[1] if is_b else WALL_BOTTOM_TOP[0]
				var mid_t := WALL_BOTTOM_MID[1] if is_b else WALL_BOTTOM_MID[0]
				var base_t := WALL_BOTTOM_BASE[1] if is_b else WALL_BOTTOM_BASE[0]
				if use_roots:
					top_t = ROOT_BOTTOM_TOP[1] if is_b else ROOT_BOTTOM_TOP[0]
					mid_t = ROOT_BOTTOM_MID[1] if is_b else ROOT_BOTTOM_MID[0]
					base_t = ROOT_BOTTOM_BASE[1] if is_b else ROOT_BOTTOM_BASE[0]

				var crown_t := Vector2i(3, 4) if is_b else Vector2i(2, 4)
				if use_roots:
					crown_t = Vector2i(3, 13) if is_b else Vector2i(2, 13)
				walls_layer.set_cell(pos + Vector2i(0, -3), 0, crown_t)
				placed_tiles[pos + Vector2i(0, -3)] = "FACADE"

				walls_layer.set_cell(pos + Vector2i(0, -2), 0, top_t)
				walls_layer.set_cell(pos + Vector2i(0, -1), 0, mid_t)
				walls_layer.set_cell(pos, 0, base_t)
				placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
				placed_tiles[pos] = "FACADE"

				# Jeśli ściana kończy się z lewej strony litym murem, po lewej stronie MUSZĄ być ściany lewe typu B
				# kończące się na wysokości MID fasady, a nad nią narożnik wewnętrzny skierowany w stronę ściany
				if not _is_walkable(grid, pos + Vector2i(-1, 0)) and not facade_cols.has(pos.x - 1):
					var side_b := WALL_SIDE_WEST[1] if not use_roots else ROOT_WALL_SIDE_WEST[1]
					var corner_t := CRNR_SE_IN
					var p_corner := Vector2i(pos.x - 1, pos.y - 2)
					if not _is_walkable(grid, p_corner) and (not placed_tiles.has(p_corner) or placed_tiles[p_corner] == "ROCK"):
						walls_layer.set_cell(p_corner, 0, corner_t)
						placed_tiles[p_corner] = "CORNER"
					for cy in range(pos.y - 1, pos.y):
						var p_side := Vector2i(pos.x - 1, cy)
						if not _is_walkable(grid, p_side) and (not placed_tiles.has(p_side) or placed_tiles[p_side] == "ROCK"):
							walls_layer.set_cell(p_side, 0, side_b)
							placed_tiles[p_side] = "SIDE_FIXED"

				# Jeśli ściana kończy się z prawej strony litym murem, po prawej stronie MUSZĄ być ściany pionowe prawe typu B
				# kończące się na wysokości MID fasady, a nad nią narożnik wewnętrzny skierowany w stronę ściany
				if not _is_walkable(grid, pos + Vector2i(1, 0)) and not facade_cols.has(pos.x + 1):
					var side_b := WALL_SIDE_EAST[1] if not use_roots else ROOT_WALL_SIDE_EAST[1]
					var corner_t := CRNR_SW_IN
					var p_corner := Vector2i(pos.x + 1, pos.y - 2)
					if not _is_walkable(grid, p_corner) and (not placed_tiles.has(p_corner) or placed_tiles[p_corner] == "ROCK"):
						walls_layer.set_cell(p_corner, 0, corner_t)
						placed_tiles[p_corner] = "CORNER"
					for cy in range(pos.y - 1, pos.y):
						var p_side := Vector2i(pos.x + 1, cy)
						if not _is_walkable(grid, p_side) and (not placed_tiles.has(p_side) or placed_tiles[p_side] == "ROCK"):
							walls_layer.set_cell(p_side, 0, side_b)
							placed_tiles[p_side] = "SIDE_FIXED"

	# FAZA 2.5: Ściany pionowe B obok kończącego się schodka w dół
	# "jak się schodek kończy w dół, to obok niego powinny być jeszcze ściany pionowe B"
	for s in step_downs:
		var sx: int = s.x
		var sy: int = s.y
		var sdir: int = s.dir # 1 -> adj is sx + 1, -1 -> adj is sx - 1
		var adj_x: int = sx + sdir

		var is_wall_at_sy := true
		if facade_cols.has(adj_x):
			for fy in facade_cols[adj_x]:
				if abs(fy - sy) <= 2:
					is_wall_at_sy = false
					break

		if is_wall_at_sy and not _is_walkable(grid, Vector2i(adj_x, sy)):
			var use_roots_adj: bool = get_use_roots.call(Vector2i(adj_x, sy))
			if sdir == 1:
				var p_c := Vector2i(adj_x, sy - 2)
				if not placed_tiles.has(p_c) or placed_tiles[p_c] == "ROCK":
					var crown_t := CRNR_SE_IN  # Zawsze niedekorowany – pod nim jest ściana B, nie ROOT_MOD_NW_IN_TOP
					walls_layer.set_cell(p_c, 0, crown_t)
					placed_tiles[p_c] = "CORNER"
				var side_b := WALL_SIDE_EAST[1] if not use_roots_adj else ROOT_WALL_SIDE_EAST[1]
				var p_b1 := Vector2i(adj_x, sy - 1)
				if not placed_tiles.has(p_b1) or placed_tiles[p_b1] == "ROCK":
					walls_layer.set_cell(p_b1, 0, side_b)
					placed_tiles[p_b1] = "SIDE_FIXED"
			else:
				var p_c := Vector2i(adj_x, sy - 2)
				if not placed_tiles.has(p_c) or placed_tiles[p_c] == "ROCK":
					var crown_t := CRNR_SW_IN  # Zawsze niedekorowany – pod nim jest ściana B, nie ROOT_MOD_NE_IN_TOP
					walls_layer.set_cell(p_c, 0, crown_t)
					placed_tiles[p_c] = "CORNER"
				var side_b := WALL_SIDE_WEST[1] if not use_roots_adj else ROOT_WALL_SIDE_WEST[1]
				var p_b1 := Vector2i(adj_x, sy - 1)
				if not placed_tiles.has(p_b1) or placed_tiles[p_b1] == "ROCK":
					walls_layer.set_cell(p_b1, 0, side_b)
					placed_tiles[p_b1] = "SIDE_FIXED"

	# FAZA 3: Ściany pionowe boczne (Side Walls)
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not _is_walkable(grid, pos):
				var w_floor := _is_walkable(grid, pos + Vector2i(-1, 0))
				var e_floor := _is_walkable(grid, pos + Vector2i(1, 0))
				var use_roots: bool = get_use_roots.call(pos)

				if e_floor and not w_floor: # Zachodnia ściana
					if not placed_tiles.has(pos) or placed_tiles[pos] == "ROCK":
						var use_roots_side: bool = get_use_roots.call(pos + Vector2i(1, 0))
						var var_idx: int = rng.randi() % 2
						var side_t: Vector2i = WALL_SIDE_WEST[var_idx] if not use_roots_side else ROOT_WALL_SIDE_WEST[var_idx]
						walls_layer.set_cell(pos, 0, side_t)
						placed_tiles[pos] = "SIDE"
				elif w_floor and not e_floor: # Wschodnia ściana
					if not placed_tiles.has(pos) or placed_tiles[pos] == "ROCK":
						var use_roots_side: bool = get_use_roots.call(pos + Vector2i(-1, 0))
						var var_idx: int = rng.randi() % 2
						var side_t: Vector2i = WALL_SIDE_EAST[var_idx] if not use_roots_side else ROOT_WALL_SIDE_EAST[var_idx]
						walls_layer.set_cell(pos, 0, side_t)
						placed_tiles[pos] = "SIDE"

	# FAZA 4: Dolny rim, półki i misy (Rims & Bowls)
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not _is_walkable(grid, pos):
				var n_floor := _is_walkable(grid, pos + Vector2i(0, -1))
				var nw_floor := _is_walkable(grid, pos + Vector2i(-1, -1))
				var ne_floor := _is_walkable(grid, pos + Vector2i(1, -1))
				var w_floor := _is_walkable(grid, pos + Vector2i(-1, 0))
				var e_floor := _is_walkable(grid, pos + Vector2i(1, 0))
				var se_floor := _is_walkable(grid, pos + Vector2i(1, 1))
				var sw_floor := _is_walkable(grid, pos + Vector2i(-1, 1))
				var use_roots: bool = get_use_roots.call(pos + Vector2i(0, -1) if n_floor else pos)

				if n_floor:
					if placed_tiles.has(pos) and (placed_tiles[pos] == "FACADE" or placed_tiles[pos] == "SIDE_FIXED"):
						continue # Nie nadpisuj fasad ani stałych ścian bocznych B

					# Jeśli bezpośrednio pod ścianą jest podłoga (obszar walls ma tylko 1 kratkę wysokości), nie generuj tu ściany
					if _is_walkable(grid, pos + Vector2i(0, 1)):
						continue

					if not use_roots:
						# Zwykły rim (1-kafelkowy)
						var is_2h_touch_left: bool = placed_tiles.has(pos + Vector2i(-1, 0)) and (placed_tiles[pos + Vector2i(-1, 0)] == "FACADE" or placed_tiles[pos + Vector2i(-1, 0)] == "CORNER")
						var is_2h_touch_right: bool = placed_tiles.has(pos + Vector2i(1, 0)) and (placed_tiles[pos + Vector2i(1, 0)] == "FACADE" or placed_tiles[pos + Vector2i(1, 0)] == "CORNER")

						var rim_t := Vector2i(2, 0)
						if is_2h_touch_left or is_2h_touch_right:
							var is_b: bool = ab_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
							rim_t = Vector2i(3, 0) if is_b else Vector2i(2, 0)
						elif e_floor and not w_floor:
							rim_t = Vector2i(5, 1)
							if not se_floor:
								var p_b := pos + Vector2i(0, 1)
								if not _is_walkable(grid, p_b) and (not placed_tiles.has(p_b) or placed_tiles[p_b] == "ROCK"):
									walls_layer.set_cell(p_b, 0, Vector2i(4, 1))
									placed_tiles[p_b] = "RIM"
						elif w_floor and not e_floor:
							rim_t = Vector2i(0, 1)
							if not sw_floor:
								var p_b := pos + Vector2i(0, 1)
								if not _is_walkable(grid, p_b) and (not placed_tiles.has(p_b) or placed_tiles[p_b] == "ROCK"):
									walls_layer.set_cell(p_b, 0, Vector2i(1, 1))
									placed_tiles[p_b] = "RIM"
						else:
							var is_b: bool = ab_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
							rim_t = Vector2i(3, 0) if is_b else Vector2i(2, 0)

						walls_layer.set_cell(pos, 0, rim_t)
						placed_tiles[pos] = "RIM"
					else:
						# Udekorowany rim z kolcami (2-kafelkowy kompletny moduł TOP + BASE)
						# BASE jest tam gdzie było w zwykłych (pos), a nad nimi jest TOP (pos + Vector2i(0, -1))
						var is_2h_touch_left: bool = placed_tiles.has(pos + Vector2i(-1, 0)) and (placed_tiles[pos + Vector2i(-1, 0)] == "FACADE" or placed_tiles[pos + Vector2i(-1, 0)] == "CORNER")
						var is_2h_touch_right: bool = placed_tiles.has(pos + Vector2i(1, 0)) and (placed_tiles[pos + Vector2i(1, 0)] == "FACADE" or placed_tiles[pos + Vector2i(1, 0)] == "CORNER")
						var p_top := pos + Vector2i(0, -1)
						var p_b := pos + Vector2i(0, 1)
						var can_place_top: bool = not (placed_tiles.has(p_top) and placed_tiles[p_top] == "FACADE")
						var can_place_base: bool = not _is_walkable(grid, p_b) and not (placed_tiles.has(p_b) and (placed_tiles[p_b] == "FACADE" or placed_tiles[p_b] == "SIDE_FIXED" or placed_tiles[p_b] == "CORNER"))

						if is_2h_touch_left or is_2h_touch_right:
							var is_b: bool = ab_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
							var t_top: Vector2i = ROOT_TOP_TIPS[1] if is_b else ROOT_TOP_TIPS[0]
							var t_base: Vector2i = ROOT_TOP_BASE[1] if is_b else ROOT_TOP_BASE[0]
							walls_layer.set_cell(pos, 0, t_base)
							placed_tiles[pos] = "RIM"
							if can_place_top:
								walls_layer.set_cell(p_top, 0, t_top)
								placed_tiles[p_top] = "RIM"
						elif e_floor and not w_floor:
							# Corner SE Out: BASE na pos, TOP nad nim
							walls_layer.set_cell(pos, 0, ROOT_TOP_SLOPE_BASE_RIGHT) # (5, 10)
							placed_tiles[pos] = "RIM"
							if can_place_top:
								walls_layer.set_cell(p_top, 0, ROOT_TOP_SLOPE_TIPS_RIGHT) # (5, 9)
								placed_tiles[p_top] = "RIM"
							if not se_floor and can_place_base:
								walls_layer.set_cell(p_b, 0, ROOT_CORNER_INNER_BOTTOM_LEFT) # (4, 10)
								placed_tiles[p_b] = "RIM"
						elif w_floor and not e_floor:
							# Corner SW Out: BASE na pos, TOP nad nim
							walls_layer.set_cell(pos, 0, ROOT_TOP_SLOPE_BASE_LEFT) # (0, 10)
							placed_tiles[pos] = "RIM"
							if can_place_top:
								walls_layer.set_cell(p_top, 0, ROOT_TOP_SLOPE_TIPS_LEFT) # (0, 9)
								placed_tiles[p_top] = "RIM"
							if not sw_floor and can_place_base:
								walls_layer.set_cell(p_b, 0, ROOT_CORNER_INNER_BOTTOM_RIGHT) # (1, 10)
								placed_tiles[p_b] = "RIM"
						else:
							# Ściana prosta pozioma: BASE na pos, TOP nad nim
							var is_b: bool = ab_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
							var t_top: Vector2i = ROOT_TOP_TIPS[1] if is_b else ROOT_TOP_TIPS[0]
							var t_base: Vector2i = ROOT_TOP_BASE[1] if is_b else ROOT_TOP_BASE[0]
							walls_layer.set_cell(pos, 0, t_base)
							placed_tiles[pos] = "RIM"
							if can_place_top:
								walls_layer.set_cell(p_top, 0, t_top)
								placed_tiles[p_top] = "RIM"

				elif nw_floor and not ne_floor and not w_floor:
					if not placed_tiles.has(pos) or placed_tiles[pos] == "ROCK":
						walls_layer.set_cell(pos, 0, Vector2i(1, 1) if not use_roots else Vector2i(1, 10))
						placed_tiles[pos] = "RIM"
				elif ne_floor and not nw_floor and not e_floor:
					if not placed_tiles.has(pos) or placed_tiles[pos] == "ROCK":
						walls_layer.set_cell(pos, 0, Vector2i(4, 1) if not use_roots else Vector2i(4, 10))
						placed_tiles[pos] = "RIM"
	# Strefy portali muszą pozostać całkowicie przechodnie:
	# żadnego kafla ściany ani kolizji na ich komórkach.
	for p in portal_zone:
		walls_layer.erase_cell(p)


static func _is_walkable(grid: Dictionary, pos: Vector2i) -> bool:
	var t: int = grid.get(pos, CellType.VOID)
	return t == CellType.FLOOR or t == CellType.DOOR or t == CellType.ENTRANCE or t == CellType.EXIT
