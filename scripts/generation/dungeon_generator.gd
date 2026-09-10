class_name DungeonGenerator
extends "res://modules/quiz_rpg/scripts/generation/map_generator_base.gd"

## Generator wnetrz / lochow / zamkow bazujacy na pokojach (BSP / Room Placement)
## i korytarzach ze scianami kolizyjnymi oraz drzwiami.

const CASTLE_TILES_PATH := "res://assets/pixel_crawler/environments/castle/Assets/Tiles.png"
const FALLBACK_TILES_PATH := "res://assets/textures/legacy_amonra/atlases/Dungeon tileset/Dungeon tileset.png"


static func get_default_palette() -> Dictionary:
	var use_castle := FileAccess.file_exists(CASTLE_TILES_PATH)
	var tex_path := CASTLE_TILES_PATH if use_castle else FALLBACK_TILES_PATH
	
	if use_castle:
		return {
			"texture_path": tex_path,
			"floor_tiles": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2)], # Posadzka kamienna
			"path_tiles": [Vector2i(2, 1)],
			"wall_tiles": [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)], # Sciany zamkowe
			"tree_tiles": [Vector2i(1, 4)],
			"void_tiles": [Vector2i(0, 0)],
			"collision_tiles": [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(0, 0)]
		}
	else:
		return {
			"texture_path": tex_path,
			"floor_tiles": [Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9)],
			"path_tiles": [Vector2i(0, 9)],
			"wall_tiles": [Vector2i(2, 0), Vector2i(3, 0)],
			"tree_tiles": [Vector2i(2, 0)],
			"void_tiles": [Vector2i(2, 0)],
			"collision_tiles": [Vector2i(2, 0), Vector2i(3, 0)]
		}


static func generate(
	width: int = 50,
	height: int = 50,
	seed_val: int = -1,
	min_room_size: int = 6,
	max_room_size: int = 12,
	max_rooms: int = 7,
	corridor_width: int = 2
) -> GenerationResult:
	var rng := create_rng(seed_val)
	var result := GenerationResult.new()
	result.width = width
	result.height = height
	result.seed_used = rng.seed
	
	# 1. Wypelnij cala mape scianami
	for y in range(height):
		for x in range(width):
			result.grid[Vector2i(x, y)] = CellType.WALL
			
	# 2. Generowanie i rzezbienie pokoi
	var rooms: Array[Rect2i] = []
	var attempts := 0
	var border := 4
	
	while rooms.size() < max_rooms and attempts < 150:
		attempts += 1
		var rw := rng.randi_range(min_room_size, max_room_size)
		var rh := rng.randi_range(min_room_size, max_room_size)
		var rx := rng.randi_range(border, width - rw - border)
		var ry := rng.randi_range(border, height - rh - border)
		var new_room := Rect2i(rx, ry, rw, rh)
		
		# Sprawdz czy nie nachodzi na inny pokoj (z marginesem 2 kafli)
		var overlaps := false
		var expanded_room := Rect2i(rx - 2, ry - 2, rw + 4, rh + 4)
		for existing in rooms:
			if expanded_room.intersects(existing):
				overlaps = true
				break
				
		if overlaps:
			continue
			
		rooms.append(new_room)
		carve_rect(result.grid, new_room, CellType.FLOOR)
		
	result.rooms = rooms
	
	# 3. Laczenie pokoi korytarzami
	for i in range(rooms.size() - 1):
		var center_a := rooms[i].get_center()
		var center_b := rooms[i + 1].get_center()
		carve_corridor(result.grid, center_a, center_b, corridor_width, CellType.FLOOR, rng)
		
	# Dodatkowy korytarz zamykajacy petle lochu
	if rooms.size() >= 4:
		var loop_a := rooms[0].get_center()
		var loop_b := rooms[rooms.size() - 2].get_center()
		carve_corridor(result.grid, loop_a, loop_b, corridor_width, CellType.FLOOR, rng)

	# 4. Przypisanie rol pokojom i rozmieszczenie encji
	if not rooms.is_empty():
		# Pokoj 0: Start gracza
		var start_room := rooms[0]
		result.player_spawn = start_room.get_center()
		result.entrance_pos = start_room.get_center() + Vector2i(-1, 0)
		
		# Pokoj koncowy: Boss / Wyjscie
		var last_room := rooms[rooms.size() - 1]
		result.exit_pos = last_room.get_center()
		result.grid[result.exit_pos] = CellType.EXIT
		
		# Wrog-Boss w ostatnim pokoju
		result.enemy_spawns.append({
			"pos": last_room.get_center() + Vector2i(0, -2),
			"tier": 3
		})
		
		# Pokoje posrednie
		for i in range(1, rooms.size() - 1):
			var r := rooms[i]
			var center := r.get_center()
			
			if i % 2 == 1:
				# Pokoj z wrogami
				var num_enemies := rng.randi_range(1, 3)
				for e in range(num_enemies):
					var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
					result.enemy_spawns.append({
						"pos": center + offset,
						"tier": rng.randi_range(1, 2)
					})
			else:
				# Pokoj ze skrzynia / quizem
				result.chest_spawns.append(center)
				
	# 5. Wyznacz drzwi na wejsciach do pokoi
	_detect_and_place_doors(result, rooms)
	
	return result


static func _detect_and_place_doors(result: GenerationResult, rooms: Array[Rect2i]) -> void:
	for room in rooms:
		# Gora i dol
		for x in range(room.position.x, room.position.x + room.size.x):
			for y in [room.position.y - 1, room.position.y + room.size.y]:
				var p := Vector2i(x, y)
				if result.grid.get(p, CellType.WALL) == CellType.FLOOR:
					if not result.doors.has(p):
						result.doors.append(p)
						result.grid[p] = CellType.DOOR
		# Lewo i prawo
		for y in range(room.position.y, room.position.y + room.size.y):
			for x in [room.position.x - 1, room.position.x + room.size.x]:
				var p := Vector2i(x, y)
				if result.grid.get(p, CellType.WALL) == CellType.FLOOR:
					if not result.doors.has(p):
						result.doors.append(p)
						result.grid[p] = CellType.DOOR
