class_name OverworldForestGenerator
extends "res://modules/quiz_rpg/scripts/generation/map_generator_base.gd"

## Generator mapy otwartej / lasu (Overworld) bazujacy na szumie FastNoiseLite,
## naturalnych polanach, wydeptanych sciezkach i zageszczeniu drzew.

const FAIRY_FOREST_TILES_PATH := "res://assets/pixel_crawler/environments/fairy_forest/Pixel Crawler - Fairy Forest 1.7/Assets/Tiles.png"
const FALLBACK_TILES_PATH := "res://assets/textures/legacy_amonra/atlases/Dungeon tileset/Dungeon tileset.png"


static func get_default_palette() -> Dictionary:
	var use_fairy := FileAccess.file_exists(FAIRY_FOREST_TILES_PATH)
	var tex_path := FAIRY_FOREST_TILES_PATH if use_fairy else FALLBACK_TILES_PATH
	
	if use_fairy:
		return {
			"texture_path": tex_path,
			"floor_tiles": [Vector2i(1, 1), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0)], # Trawa i warianty
			"path_tiles": [Vector2i(1, 5), Vector2i(2, 5), Vector2i(0, 5)], # Sciezka polna / ziemia
			"wall_tiles": [Vector2i(7, 1), Vector2i(8, 1)], # Pien / kamienie
			"tree_tiles": [Vector2i(6, 1), Vector2i(6, 2), Vector2i(7, 2)], # Zageszczenie drzew
			"void_tiles": [Vector2i(6, 1)],
			"collision_tiles": [Vector2i(6, 1), Vector2i(6, 2), Vector2i(7, 1), Vector2i(7, 2), Vector2i(8, 1)]
		}
	else:
		return {
			"texture_path": tex_path,
			"floor_tiles": [Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9)],
			"path_tiles": [Vector2i(3, 9), Vector2i(4, 9)],
			"wall_tiles": [Vector2i(2, 0), Vector2i(3, 0)],
			"tree_tiles": [Vector2i(2, 0)],
			"void_tiles": [Vector2i(2, 0)],
			"collision_tiles": [Vector2i(2, 0), Vector2i(3, 0)]
		}


static func generate(
	width: int = 60,
	height: int = 60,
	seed_val: int = -1,
	num_clearings: int = 5,
	forest_density: float = 0.28,
	path_width: int = 2
) -> GenerationResult:
	var rng := create_rng(seed_val)
	var result := GenerationResult.new()
	result.width = width
	result.height = height
	result.seed_used = rng.seed
	
	# 1. Konfiguracja szumu
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	
	var border_margin := 4
	
	# 2. Wypelnij mape bazowa: trawa vs las
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			# Granica mapy - zawsze nieprzekraczalny las
			if x < border_margin or x >= width - border_margin or y < border_margin or y >= height - border_margin:
				result.grid[p] = CellType.TREE
				continue
				
			var n_val := noise.get_noise_2d(float(x), float(y))
			if n_val > (0.5 - forest_density):
				result.grid[p] = CellType.TREE
			else:
				result.grid[p] = CellType.FLOOR
				
	# 3. Wyznacz i wyrzezbiaj polany (Clearings)
	var safe_min_x := border_margin + 6
	var safe_max_x := width - border_margin - 6
	var safe_min_y := border_margin + 6
	var safe_max_y := height - border_margin - 6
	
	var clearings: Array[Dictionary] = []
	var attempts := 0
	var min_clearing_dist := 14
	
	while clearings.size() < num_clearings and attempts < 200:
		attempts += 1
		var cx := rng.randi_range(safe_min_x, safe_max_x)
		var cy := rng.randi_range(safe_min_y, safe_max_y)
		var center := Vector2i(cx, cy)
		
		var too_close := false
		for cl in clearings:
			var prev_center: Vector2i = cl["center"]
			if center.distance_to(Vector2(prev_center)) < min_clearing_dist:
				too_close = true
				break
		if too_close:
			continue
			
		var radius := rng.randi_range(4, 7)
		var type_str := "combat"
		if clearings.is_empty():
			type_str = "start"
		elif clearings.size() == num_clearings - 1:
			type_str = "dungeon_entrance"
		elif clearings.size() == num_clearings - 2:
			type_str = "treasure"
			
		clearings.append({
			"center": center,
			"radius": radius,
			"type": type_str
		})
		
	result.clearings = clearings
	
	# Wyrzezbij polany na mapie
	for cl in clearings:
		var center: Vector2i = cl["center"]
		var radius: int = cl["radius"]
		var type_str: String = cl["type"]
		carve_circle(result.grid, center, radius, CellType.FLOOR, width, height)
		
		match type_str:
			"start":
				result.player_spawn = center
			"dungeon_entrance":
				result.exit_pos = center
				result.grid[center] = CellType.EXIT
			"treasure":
				result.chest_spawns.append(center)
			"combat":
				# Spawnowanie wrogow na polanie
				var enemy_count := rng.randi_range(1, 3)
				var dist_from_start: float = Vector2(center).distance_to(Vector2(result.player_spawn))
				var tier := 1
				if dist_from_start > 35:
					tier = 3
				elif dist_from_start > 20:
					tier = 2
					
				for i in range(enemy_count):
					var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
					result.enemy_spawns.append({
						"pos": center + offset,
						"tier": tier
					})

	# 4. Polacz polany naturalnymi sciezkami (AStar2D)
	if clearings.size() > 1:
		for i in range(clearings.size() - 1):
			var from_c: Vector2i = clearings[i]["center"]
			var to_c: Vector2i = clearings[i + 1]["center"]
			carve_natural_path(result.grid, from_c, to_c, width, height, rng, CellType.PATH, path_width)
			
		# Dodatkowa sciezka-petla, zeby uklad byl bardziej otwarty
		if clearings.size() >= 4:
			var loop_from: Vector2i = clearings[0]["center"]
			var loop_to: Vector2i = clearings[rng.randi_range(2, clearings.size() - 1)]["center"]
			carve_natural_path(result.grid, loop_from, loop_to, width, height, rng, CellType.PATH, 1)

	# 5. Zapewnij bezpieczenstwo spawnu gracza
	if result.player_spawn != Vector2i.ZERO:
		carve_circle(result.grid, result.player_spawn, 3, CellType.FLOOR, width, height)
		
	return result
