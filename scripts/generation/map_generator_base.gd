class_name MapGeneratorBase
extends RefCounted

## Bazowa klasa generatora map w module Quiz RPG.
## Odpowiada za wspolne algorytmy siatki, szumy, sciezki A*, oraz budowanie wezlow mapy.

const GenProgressScript = preload("core/gen_progress.gd")
const LevelPortal = preload("../maps/level_portal.gd")

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
	var entrance_edge: int = -1  # krawędź mapy wnęki wejścia / wyjścia (0 N, 1 E, 2 S, 3 W; -1 = w pokoju, drabina, schody w ścianie)
	var exit_edge: int = -1
	var decoration_spawns: Array[Dictionary] = [] # { pos: Vector2i, id: int }
	var entrance_zone: Array[Vector2i] = []  # komórki strefy wejściowej
	var exit_zone: Array[Vector2i] = []  # komórki strefy wyjściowej
	var portal_stairs: Array[Dictionary] = []  # schody wejścia / wyjścia {rect: Rect2i, dir: "N"/"E"/"S"/"W"} — CorridorStairsPlacer
	var portal_void: Array[Vector2i] = []   # koniec schodów portalu przy krawędzi mapy — kafle ścian wymazane (void)
	var portal_ladders: Array[Dictionary] = []  # {cell, height} — drabiny wejścia / wyjścia (portal_style "ladder")
	var portal_scene: String = ""           # scena drabiny (flags.portal_scene)
	var profile_id: StringName = &""  # który profil wygenerował ten wynik
	var flags_used: RefCounted = null  # GenerationFlags faktycznie użyte
	var overrides_used: Dictionary = {}  # nadpisania runtime
	var portal_zone: Dictionary = {}  # Vector2i -> bool (union entrance+exit)
	var corridors: Array[Dictionary] = []  # { from, to, width } — do debugowania
	var preprocess_stats: Dictionary = {}  # ile komórek zmienił każdy pass
	var plateau: RefCounted = null  # PlateauLayout — płaskowyże jako nakładka (komórki zostają FLOOR)
	var objects: RefCounted = null  # ObjectPlan — obiekty statyczne/interaktywne (null = wyłączone)
	var nav_polygons: Array[NavigationPolygon] = []  # siatka nawigacji z NavOutlines w kawałkach (puste = prostokąt mapy)
	var nav_chunk_keys: Array[Vector2i] = []  # indeksy kawałków nav_polygons (NavOutlines.CHUNK_CELLS) — przebudowa po otwarciu bramy
	var nav_excluded: Dictionary = {}  # Vector2i -> true: bez nawigacji wrogów (pokoje wejścia / wyjścia, pierwszy za wejściem, portale)
	var canals: RefCounted = null  # CanalLayout — kanały ścieków jako nakładka (komórki zostają FLOOR)
	var terrain_masks: Dictionary = {}  # {seed, mud, grass} — maski terenu z etapu obiektów (planer kafli je używa)
	var out_niches: Array[Vector2i] = []  # nisze out z planu kafli (lewa kolumna, rząd stopy ściany) — NicheContentPlanner


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
	var half := floori(width / 2.0)
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
	
	var cols := int(tex.get_width() / 16.0)
	var rows := int(tex.get_height() / 16.0)
	
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

## Wpis puli wrogów: jedna scena albo tablica wariantów tego samego tieru. Wariant zależy od
## pozycji spawnu (nie od globalnego RNG), więc ten sam seed daje tych samych wrogów.
static func _pick_enemy_variant(entry: Variant, pos: Vector2i) -> PackedScene:
	if entry is Array:
		var variants: Array = entry
		if variants.is_empty():
			return null
		return variants[posmod(hash(pos), variants.size())] as PackedScene
	return entry as PackedScene


static func spawn_entities(
	target_node: Node2D,
	result: GenerationResult,
	enemy_scenes: Array = [],  # indeks = tier - 1; element: PackedScene albo tablica wariantów
	chest_scene: PackedScene = null,
	door_scene: PackedScene = null,
	cell_size: int = 16,
	slicer = null,  # FrameSlicer: porcje między klatkami wg budżetu czasu; null = wszystko od razu
	faction_pools: Dictionary = {},  # frakcja -> pula (jak enemy_scenes); spawn z "faction" bierze swoją
	enemy_levels: Dictionary = {}  # "1" / "2" / "3" (tier) -> [min, max] poziomu wroga (companion-JSON "enemy_levels")
) -> void:
	# slicer: po przekroczeniu budżetu klatki czekamy klatkę (generowanie w tle — pasek ładowania żyje).
	# null = wszystko od razu (synchronicznie; wywołanie bez await działa jak dawniej).
	var total: int = result.enemy_spawns.size() + result.chest_spawns.size() + (result.doors.size() if door_scene else 0)
	var made := 0
	# Skala XP wg rozmiaru mapy: wzorzec "ref_spawns" (wrogowie z miniebossami, bez bossa, na mapie wzorcowej 160x160) / ich liczba na tej
	# mapie, żeby wyczyszczenie mapy dawało ten sam budżet XP (poziomów) niezależnie od jej wielkości.
	var regular_spawns := 0
	for sp in result.enemy_spawns:
		if int(sp.get("tier", 1)) < 4:
			regular_spawns += 1
	var xp_scale := 1.0
	if enemy_levels.has("ref_spawns") and regular_spawns > 0:
		# "xp_size_exponent" (domyślnie 1,0 = pełna normalizacja budżetu mapy; < 1 = większe mapy dają więcej łącznego XP, np. 0,75)
		xp_scale = clampf(pow(float(enemy_levels["ref_spawns"]) / float(regular_spawns), float(enemy_levels.get("xp_size_exponent", 1.0))), 0.25, 4.0)

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
	# Przyjście z poprzedniego poziomu: obok wejścia, poza jego obszarem przejścia.
	var spawn_cell := arrival_cell(result, result.entrance_pos) if result.entrance_pos != Vector2i.ZERO else result.player_spawn
	spawn_marker.position = _cell_center(spawn_cell, cell_size)

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
			
	if not enemy_scenes.is_empty() or not faction_pools.is_empty():
		for spawn_info in result.enemy_spawns:
			var pos: Vector2i = spawn_info.get("pos", Vector2i.ZERO)
			var tier: int = spawn_info.get("tier", 1)
			var faction := String(spawn_info.get("faction", ""))
			var pool: Array = faction_pools.get(faction, enemy_scenes)
			if pool.is_empty():
				continue
			var scene_idx := mini(tier - 1, pool.size() - 1)
			var own_scene := String(spawn_info.get("scene", ""))   # boss powrotu: własna scena (TreasurePlanner.plan_return_boss)
			var enemy_packed: PackedScene = load(own_scene) as PackedScene if own_scene != "" \
				else _pick_enemy_variant(pool[scene_idx], pos)
			if enemy_packed:
				var enemy_inst := enemy_packed.instantiate() as Node2D
				if enemy_inst:
					enemy_inst.position = Vector2(pos.x * cell_size + cell_size * 0.5, pos.y * cell_size + cell_size * 0.5)
					if "faction" in enemy_inst:
						enemy_inst.set("faction", StringName(faction))
					if own_scene != "":
						enemy_inst.set("boss_story_id", String(spawn_info.get("story_id", "")))
						enemy_inst.set("requires_flag", String(spawn_info.get("requires_flag", "")))
					var band: Variant = enemy_levels.get(str(scene_idx + 1))
					if int(spawn_info.get("level", 0)) > 0 and enemy_inst.has_method("set_enemy_level"):
						enemy_inst.call("set_enemy_level", int(spawn_info.level), 1.0)
					elif band is Array and band.size() == 2 and enemy_inst.has_method("set_enemy_level"):
						# poziom z przedziału tieru, deterministycznie z pozycji (ten sam seed = te same poziomy)
						enemy_inst.call("set_enemy_level", int(band[0]) + absi(hash(pos)) % (int(band[1]) - int(band[0]) + 1), xp_scale if tier < 4 else 1.0)
					enemies_node.add_child(enemy_inst)
			made += 1
			if slicer != null and slicer.due():
				GenProgressScript.sub(float(made) / total)
				await slicer.next_frame(target_node.get_tree())

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
			made += 1
			if slicer != null and slicer.due():
				GenProgressScript.sub(float(made) / total)
				await slicer.next_frame(target_node.get_tree())

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
			made += 1
			if slicer != null and slicer.due():
				GenProgressScript.sub(float(made) / total)
				await slicer.next_frame(target_node.get_tree())

	# 5. Wejscie / Wyjscie - trigger zony: wyjście -> następny poziom, wejście -> powrót do poprzedniego;
	# przy wyjściu marker FromNext (tu trafia gracz wracający z następnego poziomu).
	# Schody we wnęce (alcove_stairs): obszar na całym najwyższym stopniu (rząd przy voidzie), nie tylko na środku.
	_setup_portal_trigger(target_node, LevelPortal.NEXT_AREA, result.exit_pos, cell_size, _portal_top_row(result, false, result.exit_pos))
	_setup_portal_trigger(target_node, LevelPortal.PREVIOUS_AREA, result.entrance_pos, cell_size, _portal_top_row(result, true, result.entrance_pos))
	if result.exit_pos != Vector2i.ZERO:
		LevelPortal.place_from_next_marker(target_node, _cell_center(arrival_cell(result, result.exit_pos), cell_size))
	# 6. Drabiny wejścia / wyjścia (portal_style "ladder") — scena na kratce przejścia, wysokość lica z generatora.
	if not result.portal_ladders.is_empty() and ResourceLoader.exists(result.portal_scene):
		var ladder_scene := load(result.portal_scene) as PackedScene
		for lad in result.portal_ladders:
			var inst := ladder_scene.instantiate() as Node2D
			if inst == null:
				continue
			inst.position = _cell_center(lad["cell"], cell_size)
			if "height_cells" in inst:
				inst.set("height_cells", int(lad.get("height", 3)))
			if lad["cell"] == result.exit_pos:
				inst.add_to_group(EXIT_PORTAL_GROUP)
			objects_node.add_child(inst)


## Grupa grafiki wyjścia (drabina) — ProceduralLevel ukrywa snop światła, gdy wyjście jest zamknięte do pokonania bossa.
const EXIT_PORTAL_GROUP := &"exit_portal_visuals"


## Odległość (w kratkach, w linii prostej) punktu pojawienia się od kratki przejścia — obszar ma 1,5 kratki.
const ARRIVAL_DIST := 3


## Kratka pojawienia się przy przejściu `portal`: BFS po podłodze (4-sąsiedzi) na tej samej wysokości
## płaskowyżu, bez barier i obiektów z kolizją; najbliższa (po drodze) kratka co najmniej ARRIVAL_DIST kratek
## w linii prostej od przejścia z wolnymi wszystkimi 8 sąsiadami, inaczej pierwsza tak daleka, inaczej
## najdalsza osiągnięta (ślepy zaułek).
static func arrival_cell(result: GenerationResult, portal: Vector2i, min_dist: int = ARRIVAL_DIST) -> Vector2i:
	var solid: Dictionary = result.objects.solid_cells() if result.objects != null else {}
	var pl = result.plateau
	var has_plateau: bool = pl != null and not pl.is_empty()
	var h0: int = pl.height_of(portal) if has_plateau else 0
	var walkable := func(c: Vector2i) -> bool:
		var t: int = int(result.grid.get(c, CellType.VOID))
		if t != CellType.FLOOR and t != CellType.PATH and t != CellType.ENTRANCE and t != CellType.EXIT:
			return false
		if solid.has(c):
			return false
		if result.canals != null and result.canals.blocked.has(c):
			return false
		return not has_plateau or (not pl.blocked.has(c) and pl.height_of(c) == h0)
	var dist := {portal: 0}
	var queue: Array[Vector2i] = [portal]
	var head := 0
	var far := portal
	var first_far := Vector2i(-1, -1)
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var d: int = dist[c]
		if d > int(dist[far]):
			far = c
		if Vector2(c - portal).length() >= min_dist:
			var open := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not walkable.call(c + Vector2i(dx, dy)):
						open = false
			if open:
				return c
			if first_far.x < 0:
				first_far = c
			if d >= min_dist * 3:
				continue
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := c + step
			if not dist.has(n) and walkable.call(n):
				dist[n] = d + 1
				queue.append(n)
	return first_far if first_far.x >= 0 else far


static func _cell_center(cell: Vector2i, cell_size: int) -> Vector2:
	return Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)


const PORTAL_AREA_OVERLAP := 4.0

## Obszar przejścia na inny poziom: `cells` (kratki, np. najwyższy stopień schodów) albo kwadrat 1,5 kratki na `cell`.
static func _setup_portal_trigger(target_node: Node2D, area_name: String, cell: Vector2i, cell_size: int, cells: Rect2i = Rect2i()) -> void:
	if cell == Vector2i.ZERO:
		return
	var area := target_node.get_node_or_null(area_name) as Area2D
	if not area:
		area = Area2D.new()
		area.name = area_name
		area.collision_layer = 0
		area.collision_mask = 1
		var col := CollisionShape2D.new()
		col.shape = RectangleShape2D.new()
		area.add_child(col)
		target_node.add_child(area)
	var shape: RectangleShape2D = null
	for c in area.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is RectangleShape2D:
			shape = (c as CollisionShape2D).shape
			break
	if shape == null:
		return
	if cells.has_area():
		area.set_meta(QuizRpgPortalFade.META, true)  # schody wnęki: postać znika stopniowo, zanim dotknie obszaru
		# Obszar wchodzi PORTAL_AREA_OVERLAP px w ostatni stopień (po obu stronach cienkiej osi): kolizja gradientu
		# (ostatnie piksele kafla) zatrzymuje postać tuż przed voidem, więc bez zakładki nie dotykałaby obszaru.
		shape.size = Vector2(cells.size * cell_size) + Vector2(PORTAL_AREA_OVERLAP * 2 if cells.size.x == 1 else 0, PORTAL_AREA_OVERLAP * 2 if cells.size.y == 1 else 0)
		area.position = Vector2(cells.position * cell_size) + Vector2(cells.size * cell_size) * 0.5
	else:
		shape.size = Vector2(cell_size * 1.5, cell_size * 1.5)
		area.position = _cell_center(cell, cell_size)


## Kratki za gradientem na najwyższym stopniu schodów wnęki (portal_stairs z "entrance"): rząd / kolumna voidu tuż za
## stopniem przy krawędzi mapy (dir), cały na szerokość schodów. Pusty Rect2i, gdy brak schodów albo najwyższy stopień
## nie zawiera punktu przejścia `cell`.
static func _portal_top_row(result: GenerationResult, entrance: bool, cell: Vector2i) -> Rect2i:
	for ps in result.portal_stairs:
		if not ps.has("entrance") or bool(ps["entrance"]) != entrance:
			continue
		var r: Rect2i = ps["rect"]
		var row := Rect2i()
		match String(ps.get("dir", "")):
			"N": row = Rect2i(r.position, Vector2i(r.size.x, 1))
			"S": row = Rect2i(Vector2i(r.position.x, r.end.y - 1), Vector2i(r.size.x, 1))
			"W": row = Rect2i(r.position, Vector2i(1, r.size.y))
			"E": row = Rect2i(Vector2i(r.end.x - 1, r.position.y), Vector2i(1, r.size.y))
		if row.has_point(cell):
			row.position += {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "W": Vector2i(-1, 0), "E": Vector2i(1, 0)}[String(ps["dir"])]
			return row
	return Rect2i()


# --- Automatyczne tworzenie NavigationRegion2D ---

## Nazwa węzła kawałka siatki nawigacji o indeksie k (NavOutlines) — GateNav podmienia kawałki po otwarciu bramy.
static func chunk_name(k: Vector2i) -> String:
	return "NavChunk_%d_%d" % [k.x, k.y]


static func setup_navigation_region(target_node: Node2D, result: GenerationResult, cell_size: int = 16) -> void:
	var nav_node := target_node.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if not nav_node:
		nav_node = NavigationRegion2D.new()
		nav_node.name = "NavigationRegion2D"
		target_node.add_child(nav_node)

	# Kawałki z poprzedniej generacji (regeneracja w tej samej scenie).
	for child in nav_node.get_children():
		if child is NavigationRegion2D and String(child.name).begins_with("NavChunk"):
			nav_node.remove_child(child)
			child.queue_free()

	# Siatka z generatora (NavOutlines, wypieczona w wątku roboczym): podłoga bez ścian, barier
	# płaskowyżów i przeszkód — gotowa, bez bake'a na głównym wątku. Jeden region na kawałek;
	# sąsiednie regiony serwer nawigacji łączy na wspólnych krawędziach.
	if not result.nav_polygons.is_empty():
		nav_node.navigation_polygon = null
		for i in range(result.nav_polygons.size()):
			var chunk := NavigationRegion2D.new()
			chunk.name = chunk_name(result.nav_chunk_keys[i]) if i < result.nav_chunk_keys.size() else "NavChunk%d" % i
			chunk.navigation_polygon = result.nav_polygons[i]
			nav_node.add_child(chunk)
		return

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
