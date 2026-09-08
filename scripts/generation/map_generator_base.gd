class_name MapGeneratorBase
extends RefCounted

## Bazowa klasa generatora map w module Quiz RPG.
## Odpowiada za wspolne algorytmy siatki, szumy, sciezki A*, oraz budowanie wezlow mapy.

enum CellType {
	VOID = 0,
	FLOOR = 1,
	WALL = 2,
	PATH = 3,
	TREE = 4,
	WATER = 5,
	DOOR = 6,
	ENTRANCE = 7,
	EXIT = 8,
	DECORATION = 9
}

class GenerationResult:
	var grid: Dictionary = {} # Vector2i -> CellType (int)
	var width: int = 50
	var height: int = 50
	var seed_used: int = 0
	var player_spawn: Vector2i = Vector2i.ZERO
	var rooms: Array[Rect2i] = []
	var clearings: Array[Dictionary] = [] # { center: Vector2i, radius: int, type: String }
	var enemy_spawns: Array[Dictionary] = [] # { pos: Vector2i, tier: int }
	var chest_spawns: Array[Vector2i] = []
	var doors: Array[Vector2i] = []
	var entrance_pos: Vector2i = Vector2i.ZERO
	var exit_pos: Vector2i = Vector2i.ZERO
	var decoration_spawns: Array[Dictionary] = [] # { pos: Vector2i, id: int }


# --- Inicjalizacja RNG ---

static func create_rng(seed_val: int = -1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if seed_val <= 0:
		rng.randomize()
	else:
		rng.seed = seed_val
	return rng


# --- Operacje na siatce ---

static func in_bounds(pos: Vector2i, w: int, h: int) -> bool:
	return pos.x >= 0 and pos.x < w and pos.y >= 0 and pos.y < h


static func get_4_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		pos + Vector2i.RIGHT,
		pos + Vector2i.LEFT,
		pos + Vector2i.DOWN,
		pos + Vector2i.UP
	]


static func get_8_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		pos + Vector2i(-1, -1), pos + Vector2i(0, -1), pos + Vector2i(1, -1),
		pos + Vector2i(-1, 0),                          pos + Vector2i(1, 0),
		pos + Vector2i(-1, 1),  pos + Vector2i(0, 1),  pos + Vector2i(1, 1)
	]


static func carve_rect(grid: Dictionary, rect: Rect2i, type: int) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			grid[Vector2i(x, y)] = type


static func carve_circle(grid: Dictionary, center: Vector2i, radius: int, type: int, w: int, h: int) -> void:
	var r2 := radius * radius
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var p := Vector2i(x, y)
			if in_bounds(p, w, h):
				var dx := x - center.x
				var dy := y - center.y
				if (dx * dx + dy * dy) <= r2:
					grid[p] = type


static func carve_corridor(grid: Dictionary, from: Vector2i, to: Vector2i, width: int = 1, type: int = CellType.FLOOR, rng: RandomNumberGenerator = null) -> void:
	var current := from
	var first_horizontal := rng.randf() > 0.5 if rng else true
	
	if first_horizontal:
		while current.x != to.x:
			_carve_brush(grid, current, width, type)
			current.x += 1 if to.x > current.x else -1
		while current.y != to.y:
			_carve_brush(grid, current, width, type)
			current.y += 1 if to.y > current.y else -1
	else:
		while current.y != to.y:
			_carve_brush(grid, current, width, type)
			current.y += 1 if to.y > current.y else -1
		while current.x != to.x:
			_carve_brush(grid, current, width, type)
			current.x += 1 if to.x > current.x else -1
	_carve_brush(grid, current, width, type)


static func _carve_brush(grid: Dictionary, center: Vector2i, width: int, type: int) -> void:
	var half := width / 2
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			grid[center + Vector2i(dx, dy)] = type


# --- Naturalna sciezka A* ---

static func carve_natural_path(grid: Dictionary, from: Vector2i, to: Vector2i, w: int, h: int, rng: RandomNumberGenerator, path_type: int = CellType.PATH, width: int = 1) -> void:
	var astar := AStar2D.new()
	var point_id_map: Dictionary = {}
	var id_counter := 0
	
	# Tworzymy wezly w poblizu prostokata obejmujacego oba punkty z marginesem
	var margin := 8
	var min_x := maxi(0, mini(from.x, to.x) - margin)
	var max_x := mini(w - 1, maxi(from.x, to.x) + margin)
	var min_y := maxi(0, mini(from.y, to.y) - margin)
	var max_y := mini(h - 1, maxi(from.y, to.y) + margin)
	
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2i(x, y)
			var id := id_counter
			id_counter += 1
			point_id_map[p] = id
			
			var cell: int = grid.get(p, CellType.VOID)
			var weight := 1.0
			# Sciezka woli isc po istniejacej podlodze/sciezce, trudniej przez drzewa/sciany
			if cell == CellType.FLOOR or cell == CellType.PATH:
				weight = 0.8
			elif cell == CellType.TREE or cell == CellType.WALL:
				weight = 6.0
			# Dodaj lekki losowy koszt zeby sciezka byla naturalnie nieregularna
			weight += rng.randf_range(0.0, 1.5)
			
			astar.add_point(id, Vector2(x, y), weight)
	
	# Polacz sasiadow
	for p in point_id_map.keys():
		var id: int = point_id_map[p]
		for n in [p + Vector2i.RIGHT, p + Vector2i.DOWN]:
			if point_id_map.has(n):
				var n_id: int = point_id_map[n]
				astar.connect_points(id, n_id)
	
	if not point_id_map.has(from) or not point_id_map.has(to):
		carve_corridor(grid, from, to, width, path_type, rng)
		return
		
	var start_id: int = point_id_map[from]
	var goal_id: int = point_id_map[to]
	var path := astar.get_point_path(start_id, goal_id)
	
	if path.is_empty():
		carve_corridor(grid, from, to, width, path_type, rng)
		return
		
	for pt in path:
		var cell_pt := Vector2i(int(round(pt.x)), int(round(pt.y)))
		_carve_brush(grid, cell_pt, width, path_type)


# --- Budowanie warstw TileMapLayer ---

static func create_default_tileset(texture_path: String, collision_coords: Array = []) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)
	
	var tex := load(texture_path) as Texture2D
	if not tex:
		return ts
		
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(16, 16)
	
	var cols := int(tex.get_width() / 16)
	var rows := int(tex.get_height() / 16)
	
	var col_set: Dictionary = {}
	for c in collision_coords:
		col_set[c] = true
		
	for y in range(rows):
		for x in range(cols):
			source.create_tile(Vector2i(x, y))
					
	ts.add_source(source, 0)
	
	for coord in col_set.keys():
		var data := source.get_tile_data(coord, 0)
		if data:
			var poly := PackedVector2Array([
				Vector2(-8, -8),
				Vector2(8, -8),
				Vector2(8, 8),
				Vector2(-8, 8)
			])
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, poly)
			
	return ts


static func apply_grid_to_layers(
	floor_layer: TileMapLayer,
	walls_layer: TileMapLayer,
	result: GenerationResult,
	palette: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var floor_coords: Array = palette.get("floor_tiles", [Vector2i(0, 0)])
	var wall_coords: Array = palette.get("wall_tiles", [Vector2i(1, 0)])
	var path_coords: Array = palette.get("path_tiles", floor_coords)
	var tree_coords: Array = palette.get("tree_tiles", wall_coords)
	var void_coords: Array = palette.get("void_tiles", tree_coords)
	
	floor_layer.clear()
	walls_layer.clear()
	
	for pos in result.grid.keys():
		var type: int = result.grid[pos]
		match type:
			CellType.FLOOR:
				var c: Vector2i = floor_coords[rng.randi() % floor_coords.size()]
				floor_layer.set_cell(pos, 0, c)
			CellType.PATH:
				var c: Vector2i = path_coords[rng.randi() % path_coords.size()]
				floor_layer.set_cell(pos, 0, c)
			CellType.WALL:
				var fc: Vector2i = floor_coords[0]
				floor_layer.set_cell(pos, 0, fc)
				var wc: Vector2i = wall_coords[rng.randi() % wall_coords.size()]
				walls_layer.set_cell(pos, 0, wc)
			CellType.TREE:
				var tc: Vector2i = tree_coords[rng.randi() % tree_coords.size()]
				walls_layer.set_cell(pos, 0, tc)
			CellType.VOID:
				var vc: Vector2i = void_coords[rng.randi() % void_coords.size()]
				walls_layer.set_cell(pos, 0, vc)
			CellType.DOOR, CellType.ENTRANCE, CellType.EXIT:
				var fc: Vector2i = floor_coords[0]
				floor_layer.set_cell(pos, 0, fc)


# --- Wstawianie encji (gracz, wrogowie, skrzynie) ---

static func spawn_entities(
	target_node: Node2D,
	result: GenerationResult,
	enemy_scenes: Array[PackedScene] = [],
	chest_scene: PackedScene = null,
	door_scene: PackedScene = null,
	cell_size: int = 16
) -> void:
	# 1. Spawns / Spawn
	var spawns_node := target_node.get_node_or_null("Spawns")
	if not spawns_node:
		spawns_node = Node2D.new()
		spawns_node.name = "Spawns"
		target_node.add_child(spawns_node)
	
	var spawn_marker := spawns_node.get_node_or_null("Spawn") as Marker2D
	if not spawn_marker:
		spawn_marker = Marker2D.new()
		spawn_marker.name = "Spawn"
		spawns_node.add_child(spawn_marker)
	spawn_marker.position = Vector2(result.player_spawn.x * cell_size + cell_size * 0.5, result.player_spawn.y * cell_size + cell_size * 0.5)

	# 2. Enemies
	var enemies_node := target_node.get_node_or_null("Enemies")
	if not enemies_node:
		enemies_node = Node2D.new()
		enemies_node.name = "Enemies"
		enemies_node.y_sort_enabled = true
		target_node.add_child(enemies_node)
	else:
		for child in enemies_node.get_children():
			child.queue_free()
			
	if not enemy_scenes.is_empty():
		for spawn_info in result.enemy_spawns:
			var pos: Vector2i = spawn_info.get("pos", Vector2i.ZERO)
			var tier: int = spawn_info.get("tier", 1)
			var scene_idx := mini(tier - 1, enemy_scenes.size() - 1)
			var enemy_packed: PackedScene = enemy_scenes[scene_idx]
			if enemy_packed:
				var enemy_inst := enemy_packed.instantiate() as Node2D
				if enemy_inst:
					enemy_inst.position = Vector2(pos.x * cell_size + cell_size * 0.5, pos.y * cell_size + cell_size * 0.5)
					enemies_node.add_child(enemy_inst)

	# 3. Objects / Skrzynie
	var objects_node := target_node.get_node_or_null("Objects")
	if not objects_node:
		objects_node = Node2D.new()
		objects_node.name = "Objects"
		objects_node.y_sort_enabled = true
		target_node.add_child(objects_node)
	else:
		for child in objects_node.get_children():
			child.queue_free()
			
	if chest_scene:
		for c_pos in result.chest_spawns:
			var chest_inst := chest_scene.instantiate() as Node2D
			if chest_inst:
				chest_inst.position = Vector2(c_pos.x * cell_size + cell_size * 0.5, c_pos.y * cell_size + cell_size * 0.5)
				objects_node.add_child(chest_inst)

	# 4. Drzwi
	if door_scene:
		var doors_node := target_node.get_node_or_null("Doors")
		if not doors_node:
			doors_node = Node2D.new()
			doors_node.name = "Doors"
			doors_node.y_sort_enabled = true
			target_node.add_child(doors_node)
		else:
			for child in doors_node.get_children():
				child.queue_free()
				
		for d_pos in result.doors:
			var door_inst := door_scene.instantiate() as Node2D
			if door_inst:
				door_inst.position = Vector2(d_pos.x * cell_size + cell_size * 0.5, d_pos.y * cell_size + cell_size * 0.5)
				doors_node.add_child(door_inst)

	# 5. Wejscie / Wyjscie - trigger zony
	_setup_exit_trigger(target_node, result.exit_pos, cell_size)


static func _setup_exit_trigger(target_node: Node2D, exit_pos: Vector2i, cell_size: int) -> void:
	if exit_pos == Vector2i.ZERO:
		return
	var exit_area := target_node.get_node_or_null("enter_next_level") as Area2D
	if not exit_area:
		exit_area = Area2D.new()
		exit_area.name = "enter_next_level"
		exit_area.collision_layer = 0
		exit_area.collision_mask = 1
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(cell_size * 1.5, cell_size * 1.5)
		col.shape = rect
		exit_area.add_child(col)
		target_node.add_child(exit_area)
	exit_area.position = Vector2(exit_pos.x * cell_size + cell_size * 0.5, exit_pos.y * cell_size + cell_size * 0.5)


# --- Automatyczne tworzenie NavigationRegion2D ---

static func setup_navigation_region(target_node: Node2D, result: GenerationResult, cell_size: int = 16) -> void:
	var nav_node := target_node.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if not nav_node:
		nav_node = NavigationRegion2D.new()
		nav_node.name = "NavigationRegion2D"
		target_node.add_child(nav_node)

	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 8.0
	
	var min_x: float = 1.0 * cell_size
	var min_y: float = 1.0 * cell_size
	var max_x: float = (result.width - 1.0) * cell_size
	var max_y: float = (result.height - 1.0) * cell_size
	
	var bounding_outline := PackedVector2Array([
		Vector2(min_x, min_y),
		Vector2(max_x, min_y),
		Vector2(max_x, max_y),
		Vector2(min_x, max_y)
	])
	nav_poly.add_outline(bounding_outline)
	nav_node.navigation_polygon = nav_poly
	
	if target_node.is_inside_tree():
		nav_node.call_deferred("bake_navigation_polygon")
	else:
		target_node.ready.connect(func(): if is_instance_valid(nav_node): nav_node.bake_navigation_polygon(), CONNECT_ONE_SHOT)
