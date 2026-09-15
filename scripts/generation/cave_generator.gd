class_name CaveGenerator
extends "res://modules/quiz_rpg/scripts/generation/map_generator_base.gd"

## Generator jaskiń dla modułu Quiz RPG.
## Wykorzystuje kafelki z caves.tres, manualnie dopasowując kafelki ścian (autotiling skryptowy),
## narożników wewnętrznych i zewnętrznych, fasad wielokafelkowych oraz podłogi kamiennej z mchem.

const CAVES_TILESET_PATH := "res://modules/quiz_rpg/resources/tilemaps/caves.tres"

# =========================================================================
# FLAGI GENERACJI I KAFELKOWANIA (Wewnętrzna konfiguracja cech)
# =========================================================================
const GenerationFlags = preload("res://modules/quiz_rpg/scripts/generation/core/generation_flags.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const InteriorRoomLayoutGenerator = preload("res://modules/quiz_rpg/scripts/generation/topology/interior_room_layout_generator.gd")
const EdgeKind = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_kind.gd")
const EdgeAnalyzer = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_analyzer.gd")

# --- Koordynaty kafelków w atlasie caves.tres (Tiles.png) ---

# 1. Podłoga kamienna (Stone Floor): autotiling w terrain_set 0, terrain 0
# 2. Podłoga porośnięta mchem (Mud - terrain 1), trawą (Grass - terrain 2): autotiling w terrain_set 0

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
	corridor_width: int = 3,
	flags: GenerationFlags = null
) -> GenerationResult:
	if flags == null:
		flags = GenerationFlags.new()

	var result := GenerationResult.new()
	result.width = width
	result.height = height

	InteriorRoomLayoutGenerator.generate_layout(
		width, height, seed_val,
		min_room_size, max_room_size, max_rooms,
		corridor_width, flags, result
	)

	return result



## Wygładza maskę terenu, dopełniając klastry i eliminując ząbkowane styki diagonalne
static func _clean_terrain_mask(candidates: Dictionary) -> Array[Vector2i]:
	var refined: Dictionary = {}
	for p in candidates.keys():
		if candidates.has(p + Vector2i(1, 0)) and candidates.has(p + Vector2i(0, 1)) and candidates.has(p + Vector2i(1, 1)):
			refined[p] = true
			refined[p + Vector2i(1, 0)] = true
			refined[p + Vector2i(0, 1)] = true
			refined[p + Vector2i(1, 1)] = true

	var filled: Dictionary = refined.duplicate()
	for p in refined.keys():
		if refined.has(p + Vector2i(1, 1)) and not refined.has(p + Vector2i(1, 0)) and not refined.has(p + Vector2i(0, 1)):
			filled[p + Vector2i(1, 0)] = true
		if refined.has(p + Vector2i(-1, 1)) and not refined.has(p + Vector2i(-1, 0)) and not refined.has(p + Vector2i(0, 1)):
			filled[p + Vector2i(0, 1)] = true

	var out: Array[Vector2i] = []
	for p in filled.keys():
		out.append(p)
	return out


## Czysta funkcja wyroczni legacy do weryfikacji równoległej w Etapie 4 (§4.8, §12.5).
## Nie modyfikuje żadnego stanu, nie stawia kafelków, nie konsumuje RNG.
static func _legacy_classify(
	grid: Dictionary,
	pos: Vector2i,
	facade_cols: Dictionary,
	portal_zone: Dictionary,
	_flags: GenerationFlags
) -> int:
	if portal_zone.has(pos):
		return EdgeKind.Kind.PORTAL_CLEAR

	if _is_walkable(grid, pos):
		var x := pos.x
		var y := pos.y
		if not (facade_cols.has(x) and facade_cols[x].has(y)):
			return EdgeKind.Kind.FLOOR

		# Komórka jest stopą fasady
		var has_same_y := func(cx: int, cy: int) -> bool:
			if not facade_cols.has(cx): return false
			for fy in facade_cols[cx]:
				if abs(fy - cy) <= 1: return true
			return false

		var check_2h_col := func(cx: int, fy: int) -> bool:
			return _is_walkable(grid, Vector2i(cx, fy)) \
				and not _is_walkable(grid, Vector2i(cx, fy - 1)) \
				and not _is_walkable(grid, Vector2i(cx, fy - 2)) \
				and _is_walkable(grid, Vector2i(cx, fy - 3))

		var left_is_2h: bool = check_2h_col.call(x - 1, y)
		var right_is_2h: bool = check_2h_col.call(x + 1, y)
		var near_2h_context: bool = (left_is_2h and right_is_2h) \
			or (left_is_2h and check_2h_col.call(x + 2, y)) \
			or (right_is_2h and check_2h_col.call(x - 2, y))

		var is_horizontal_facade: bool = has_same_y.call(x - 1, y) or has_same_y.call(x + 1, y)
		var is_2h: bool = is_horizontal_facade and (_is_walkable(grid, pos + Vector2i(0, -3)) or near_2h_context)
		if is_2h:
			return EdgeKind.Kind.FACADE

		var left_is_2h_same: bool = check_2h_col.call(x - 1, y)
		var right_is_2h_same: bool = check_2h_col.call(x + 1, y)
		var right_has_room_for_3h: bool = not check_2h_col.call(x + 1, y) and not check_2h_col.call(x + 2, y) and not check_2h_col.call(x + 3, y)
		var left_has_room_for_3h: bool = not check_2h_col.call(x - 1, y) and not check_2h_col.call(x - 2, y) and not check_2h_col.call(x - 3, y)
		var right_is_2h_step: bool = check_2h_col.call(x + 1, y - 1)
		var left_is_2h_step: bool = check_2h_col.call(x - 1, y - 1)

		if left_is_2h_same and right_has_room_for_3h:
			return EdgeKind.Kind.CONNECTOR
		elif right_is_2h_same and left_has_room_for_3h:
			return EdgeKind.Kind.CONNECTOR
		elif (right_is_2h_same or right_is_2h_step) and not (left_is_2h_same or left_is_2h_step):
			return EdgeKind.Kind.CONNECTOR

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

		var w_open := _is_walkable(grid, pos + Vector2i(-1, -1)) \
			and _is_walkable(grid, pos + Vector2i(-1, -2)) \
			and not _is_walkable(grid, pos + Vector2i(0, -2)) \
			and left_y == -1

		var e_open := _is_walkable(grid, pos + Vector2i(1, -1)) \
			and _is_walkable(grid, pos + Vector2i(1, -2)) \
			and not _is_walkable(grid, pos + Vector2i(0, -2)) \
			and right_y == -1

		if (w_open and not e_open) or (e_open and not w_open):
			return EdgeKind.Kind.OUT_CORNER

		if (left_y != -1 and y > left_y) or (right_y != -1 and y > right_y):
			return EdgeKind.Kind.STEP

		return EdgeKind.Kind.FACADE

	# Komórka ściany
	var n_floor := _is_walkable(grid, pos + Vector2i(0, -1))
	var s_floor := _is_walkable(grid, pos + Vector2i(0, 1))
	var e_floor := _is_walkable(grid, pos + Vector2i(1, 0))
	var w_floor := _is_walkable(grid, pos + Vector2i(-1, 0))
	var nw_floor := _is_walkable(grid, pos + Vector2i(-1, -1))
	var ne_floor := _is_walkable(grid, pos + Vector2i(1, -1))
	var sw_floor := _is_walkable(grid, pos + Vector2i(-1, 1))
	var se_floor := _is_walkable(grid, pos + Vector2i(1, 1))

	if n_floor and not s_floor:
		return EdgeKind.Kind.TOP_RIM

	if e_floor and not w_floor:
		return EdgeKind.Kind.SIDE_WALL
	elif w_floor and not e_floor:
		return EdgeKind.Kind.SIDE_WALL

	if nw_floor and not ne_floor and not w_floor and not n_floor:
		return EdgeKind.Kind.INNER_CORNER
	elif ne_floor and not nw_floor and not e_floor and not n_floor:
		return EdgeKind.Kind.INNER_CORNER
	elif sw_floor and not se_floor and not w_floor and not s_floor:
		return EdgeKind.Kind.INNER_CORNER
	elif se_floor and not sw_floor and not e_floor and not s_floor:
		return EdgeKind.Kind.INNER_CORNER

	return EdgeKind.Kind.SOLID_FILL


## Nanosi dopasowane kafelki z caves.tres na warstwy Floor, FloorDecor i Walls
static func apply_cave_tiles(
	floor_layer: TileMapLayer,
	walls_layer: TileMapLayer,
	result: GenerationResult,
	rng: RandomNumberGenerator,
	floor_decor_layer: TileMapLayer = null,
	theme_override: int = -1,
	flags: GenerationFlags = null
) -> void:
	if flags == null:
		flags = GenerationFlags.new()

	# Reset globalnego seeda dla operacji silnika (np. set_cells_terrain_connect)
	seed(rng.seed)

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

	var mud_cells: Array[Vector2i] = []
	if flags.enable_terrain_smoothing:
		mud_cells = _clean_terrain_mask(mud_candidates)
	else:
		var mud_cells_set := {}
		for p in mud_candidates.keys():
			if mud_candidates.has(p + Vector2i(1, 0)) and mud_candidates.has(p + Vector2i(0, 1)) and mud_candidates.has(p + Vector2i(1, 1)):
				mud_cells_set[p] = true
				mud_cells_set[p + Vector2i(1, 0)] = true
				mud_cells_set[p + Vector2i(0, 1)] = true
				mud_cells_set[p + Vector2i(1, 1)] = true
		for p in mud_cells_set.keys():
			mud_cells.append(p)

	floor_layer.set_cells_terrain_connect(mud_cells, 0, 1, true)

	# 2c. Organiczne plamy mchu / trawy (Terrain 2 'Grass') na osobnej warstwie FloorDecor
	var grass_noise := FastNoiseLite.new()
	grass_noise.seed = rng.seed
	grass_noise.frequency = 0.13

	var grass_candidates := {}
	for p in ground_cells:
		if portal_zone.has(p):
			continue
		if grass_noise.get_noise_2d(float(p.x), float(p.y)) > 0.10:
			grass_candidates[p] = true

	var grass_cells: Array[Vector2i] = []
	if flags.enable_terrain_smoothing:
		grass_cells = _clean_terrain_mask(grass_candidates)
	else:
		var grass_cells_set := {}
		for p in grass_candidates.keys():
			if grass_candidates.has(p + Vector2i(1, 0)) and grass_candidates.has(p + Vector2i(0, 1)) and grass_candidates.has(p + Vector2i(1, 1)):
				grass_cells_set[p] = true
				grass_cells_set[p + Vector2i(1, 0)] = true
				grass_cells_set[p + Vector2i(0, 1)] = true
				grass_cells_set[p + Vector2i(1, 1)] = true
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

	# =========================================================================
	# 4. POTOK KAFELKOWANIA ŚCIAN (GROUND TRUTH MODULAR PIPELINE)
	# =========================================================================
	var placed_tiles: Dictionary = {}
	# Rzadkie nisze OUT są punktami sekretów; nie grupuj ich blisko siebie.
	var out_niche_positions: Array[Vector2i] = []
	const OUT_NICHE_MIN_DISTANCE := 10

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

	# Weryfikacja równoległa wyroczni legacy z EdgeAnalyzer (Etap 4, §4.8)
	if OS.is_debug_build() and flags.debug_log_edge_kinds:
		var ctx := GenerationContext.new()
		ctx.grid = grid
		ctx.width = width
		ctx.height = height
		ctx.seed_value = rng.seed
		ctx.flags = flags
		ctx.portal_zone = portal_zone
		ctx.rng = rng
		var edges := EdgeAnalyzer.analyze(ctx)
		for check_y in range(height):
			for check_x in range(width):
				var check_p := Vector2i(check_x, check_y)
				var expected_kind := _legacy_classify(grid, check_p, facade_cols, portal_zone, flags)
				var actual_kind: int = edges[check_p].edge_kind
				assert(expected_kind == actual_kind, "Stage 4 parity mismatch at %s: legacy=%d vs edge_analyzer=%d" % [str(check_p), expected_kind, actual_kind])

	var step_downs: Array[Dictionary] = []

	for x in sorted_xs:
		for y in facade_cols[x]:
			var pos := Vector2i(x, y)
			if placed_tiles.has(pos) and placed_tiles[pos] == "FACADE":
				continue
			var use_roots: bool = get_use_roots.call(pos)
			# Sprawdzenie sąsiadów fasady w poziomie na tej samej wysokości
			var has_same_y := func(cx: int, cy: int) -> bool:
				if not facade_cols.has(cx): return false
				for fy in facade_cols[cx]:
					if abs(fy - cy) <= 1: return true
				return false
			# 1. Sprawdzenie czy sąsiedzi w poziomie to 2H
			var check_2h_col := func(cx: int, fy: int) -> bool:
				return _is_walkable(grid, Vector2i(cx, fy)) \
					and not _is_walkable(grid, Vector2i(cx, fy - 1)) \
					and not _is_walkable(grid, Vector2i(cx, fy - 2)) \
					and _is_walkable(grid, Vector2i(cx, fy - 3))

			var left_is_2h: bool = check_2h_col.call(x - 1, y)
			var right_is_2h: bool = check_2h_col.call(x + 1, y)
			var near_2h_context: bool = (left_is_2h and right_is_2h) \
				or (left_is_2h and check_2h_col.call(x + 2, y)) \
				or (right_is_2h and check_2h_col.call(x - 2, y))

			var is_horizontal_facade: bool = has_same_y.call(x - 1, y) or has_same_y.call(x + 1, y)
			var is_2h: bool = is_horizontal_facade and (_is_walkable(grid, pos + Vector2i(0, -3)) or near_2h_context)

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

				# Baza ZAWSZE na kaflu podłogi pos, a szczyt na kaflu ściany pos + (0, -1)
				walls_layer.set_cell(pos, 0, base_2h)
				walls_layer.set_cell(pos + Vector2i(0, -1), 0, top_2h)
				placed_tiles[pos] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
				continue

			# 2. Obsługa łączników modularnych 2H <-> 3H
			# Łącznik wolno postawić TYLKO wtedy, gdy po stronie 3H ściana ma min. 3 kratki szerokości
			var left_is_2h_same: bool = check_2h_col.call(x - 1, y)
			var right_is_2h_same: bool = check_2h_col.call(x + 1, y)
			var right_has_room_for_3h: bool = not check_2h_col.call(x + 1, y) and not check_2h_col.call(x + 2, y) and not check_2h_col.call(x + 3, y)
			var left_has_room_for_3h: bool = not check_2h_col.call(x - 1, y) and not check_2h_col.call(x - 2, y) and not check_2h_col.call(x - 3, y)
			var right_is_2h_step: bool = check_2h_col.call(x + 1, y - 1)
			var left_is_2h_step: bool = check_2h_col.call(x - 1, y - 1)

			
			if left_is_2h_same and right_has_room_for_3h:
				walls_layer.set_cell(pos + Vector2i(0, -2), 0, CONNECTOR_2H_TO_3H_TOP)
				walls_layer.set_cell(pos + Vector2i(0, -1), 0, CONNECTOR_2H_TO_3H_MID)
				walls_layer.set_cell(pos, 0, CONNECTOR_2H_TO_3H_BASE)
				placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
				placed_tiles[pos] = "FACADE"
				continue
			elif right_is_2h_same and left_has_room_for_3h:
				walls_layer.set_cell(pos + Vector2i(0, -2), 0, CONNECTOR_3H_TO_2H_TOP)
				walls_layer.set_cell(pos + Vector2i(0, -1), 0, CONNECTOR_3H_TO_2H_MID)
				walls_layer.set_cell(pos, 0, CONNECTOR_3H_TO_2H_BASE)
				placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
				placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
				placed_tiles[pos] = "FACADE"
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

			# Sprawdzenie sąsiadów w poziomie
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

			# Sprawdź OUT corner (początek fasady przy korytarzu lub otwartej przestrzeni)
			var w_open := _is_walkable(grid, pos + Vector2i(-1, -1)) \
				and _is_walkable(grid, pos + Vector2i(-1, -2)) \
				and not _is_walkable(grid, pos + Vector2i(0, -2)) \
				and left_y == -1

			var e_open := _is_walkable(grid, pos + Vector2i(1, -1)) \
				and _is_walkable(grid, pos + Vector2i(1, -2)) \
				and not _is_walkable(grid, pos + Vector2i(0, -2)) \
				and right_y == -1

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

					# Dopięcie pionowej ściany wschodniej bezpośrednio nad narożnikiem
					var p_up := pos + Vector2i(0, -3)
					if not _is_walkable(grid, p_up) and _is_walkable(grid, pos + Vector2i(-1, -3)):
						var side_t := WALL_SIDE_EAST[1] if not use_roots else ROOT_WALL_SIDE_EAST[1]
						walls_layer.set_cell(p_up, 0, side_t)
						placed_tiles[p_up] = "SIDE_FIXED"

				if not _is_walkable(grid, pos + Vector2i(1, 0)):
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
						var in_corner := CRNR_SW_IN
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

					# Dopięcie pionowej ściany zachodniej bezpośrednio nad narożnikiem
					var p_up := pos + Vector2i(0, -3)
					if not _is_walkable(grid, p_up) and _is_walkable(grid, pos + Vector2i(1, -3)):
						var side_t := WALL_SIDE_WEST[1] if not use_roots else ROOT_WALL_SIDE_WEST[1]
						walls_layer.set_cell(p_up, 0, side_t)
						placed_tiles[p_up] = "SIDE_FIXED"

				if not _is_walkable(grid, pos + Vector2i(-1, 0)):
					step_downs.append({"x": x, "y": y, "dir": -1})
				continue

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

					for cy in range(left_y - 1, y - 2):
						var p_side := Vector2i(x, cy)
						var side_t := WALL_SIDE_EAST[1]
						walls_layer.set_cell(p_side, 0, side_t)
						placed_tiles[p_side] = "SIDE_FIXED"

				# Sprawdź, czy schodek kończy się w dół (prawy sąsiad to lita ściana kontynuująca w dół)
				if not _is_walkable(grid, pos + Vector2i(1, 0)) and right_y == -1:
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

					for cy in range(right_y - 1, y - 2):
						var p_side := Vector2i(x, cy)
						var side_t := WALL_SIDE_WEST[1]
						walls_layer.set_cell(p_side, 0, side_t)
						placed_tiles[p_side] = "SIDE_FIXED"

				if not _is_walkable(grid, pos + Vector2i(-1, 0)) and left_y == -1:
					step_downs.append({"x": x, "y": y, "dir": -1})

			else:
				# Sprawdź, czy można zastosować dwukafelkową niszową formację dodającą głębi ścianom
				# Para modułów: (MOD_CRNR_NW_IN + nad nim CRNR_SE_IN) z lewej oraz (MOD_CRNR_NE_IN + nad nim CRNR_SW_IN) z prawej
				# ZASADA: nie generuj nisz, jeśli sąsiad z lewej/prawej jest na innej wysokości, ściana schodzi w dół, lub jest to strefa portalu!
				var can_niche := false
				var pos_next := Vector2i(x + 1, y)
				var is_in_portal := portal_zone.has(pos + Vector2i(0, 1)) or portal_zone.has(pos_next + Vector2i(0, 1))

				if flags.enable_decorative_niches and not is_in_portal and facade_cols.has(x + 1) and facade_cols[x + 1].has(y):
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

				var can_place_out_niche := true
				for existing_out_pos in out_niche_positions:
					var distance_sq := Vector2(pos).distance_squared_to(Vector2(existing_out_pos))
					if distance_sq < OUT_NICHE_MIN_DISTANCE * OUT_NICHE_MIN_DISTANCE:
						can_place_out_niche = false
						break

				if can_niche and can_place_out_niche and rng.randf() < flags.secret_niche_spawn_chance:
					# Nisza odwrócona: lewy = MOD_CRNR_NE_OUT, prawy = MOD_CRNR_NW_OUT
					# Razem tworzą wgłębienie skierowane do wewnątrz (ściana-NE_OUT-NW_OUT-ściana)
					var l_crown := CRNR_SW_IN if not use_roots else ROOT_CRNR_SW_IN# (5,1) – korona nad MOD_CRNR_NE_OUT
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
					var r_crown := CRNR_SE_IN if not use_roots else ROOT_CRNR_SE_IN  # (0,1) – korona nad MOD_CRNR_NW_OUT
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

					# Rejestrujemy lewy bok pary OUT + OUT jako punkt sekretu.
					out_niche_positions.append(pos)
					continue

				if can_niche and rng.randf() < flags.niche_spawn_chance:
					# Nisza standardowa lewy = MOD_CRNR_NE_IN, prawy = MOD_CRNR_NW_IN
					var l_crown := CRNR_SW_IN if not use_roots else ROOT_CRNR_SW_IN
					var l_top := MOD_CRNR_NE_IN_TOP if not use_roots else ROOT_MOD_CRNR_NE_IN_TOP
					var l_mid := MOD_CRNR_NE_IN_MID if not use_roots else ROOT_MOD_CRNR_NE_IN_MID
					var l_base := MOD_CRNR_NE_IN_BASE if not use_roots else ROOT_MOD_CRNR_NE_IN_BASE

					walls_layer.set_cell(pos + Vector2i(0, -3), 0, l_crown)
					walls_layer.set_cell(pos + Vector2i(0, -2), 0, l_top)
					walls_layer.set_cell(pos + Vector2i(0, -1), 0, l_mid)
					walls_layer.set_cell(pos, 0, l_base)
					placed_tiles[pos + Vector2i(0, -3)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -2)] = "FACADE"
					placed_tiles[pos + Vector2i(0, -1)] = "FACADE"
					placed_tiles[pos] = "FACADE"

					# Prawy moduł: MOD_CRNR_NW_OUT – patrzy w lewo, domyka wgłębienie od prawej
					var r_crown := CRNR_SE_IN if not use_roots else ROOT_CRNR_SE_IN  # (0,1) – korona nad MOD_CRNR_NW_OUT
					var r_top := MOD_CRNR_NW_IN_TOP if not use_roots else ROOT_MOD_CRNR_NW_IN_TOP
					var r_mid := MOD_CRNR_NW_IN_MID if not use_roots else ROOT_MOD_CRNR_NW_IN_MID
					var r_base := MOD_CRNR_NW_IN_BASE if not use_roots else ROOT_MOD_CRNR_NW_IN_BASE

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

				# Zakończenie lewe litym murem: ściana zachodnia B i wewnętrzny narożnik SW_IN
				if not _is_walkable(grid, pos + Vector2i(-1, 0)) and left_y == -1:
					var side_b := WALL_SIDE_WEST[1] if not use_roots else ROOT_WALL_SIDE_WEST[1]
					var corner_t := CRNR_SW_IN
					var p_corner := Vector2i(pos.x - 1, pos.y - 2)
					if not _is_walkable(grid, p_corner) and (not placed_tiles.has(p_corner) or placed_tiles[p_corner] == "ROCK"):
						walls_layer.set_cell(p_corner, 0, corner_t)
						placed_tiles[p_corner] = "CORNER"
					for cy in range(pos.y - 1, pos.y + 1):
						var p_side := Vector2i(pos.x - 1, cy)
						if not _is_walkable(grid, p_side) and (not placed_tiles.has(p_side) or placed_tiles[p_side] == "ROCK"):
							walls_layer.set_cell(p_side, 0, side_b)
							placed_tiles[p_side] = "SIDE_FIXED"

				# Zakończenie prawe litym murem: ściana wschodnia B i wewnętrzny narożnik SE_IN
				if not _is_walkable(grid, pos + Vector2i(1, 0)) and right_y == -1:
					var side_b := WALL_SIDE_EAST[1] if not use_roots else ROOT_WALL_SIDE_EAST[1]
					var corner_t := CRNR_SE_IN
					var p_corner := Vector2i(pos.x + 1, pos.y - 2)
					if not _is_walkable(grid, p_corner) and (not placed_tiles.has(p_corner) or placed_tiles[p_corner] == "ROCK"):
						walls_layer.set_cell(p_corner, 0, corner_t)
						placed_tiles[p_corner] = "CORNER"
					for cy in range(pos.y - 1, pos.y + 1):
						var p_side := Vector2i(pos.x + 1, cy)
						if not _is_walkable(grid, p_side) and (not placed_tiles.has(p_side) or placed_tiles[p_side] == "ROCK"):
							walls_layer.set_cell(p_side, 0, side_b)
							placed_tiles[p_side] = "SIDE_FIXED"

	# FAZA 2.5: Ściany pionowe B obok kończącego się schodka w dół
	for s in step_downs:
		var sx: int = s.x
		var sy: int = s.y
		var sdir: int = s.dir
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

	# FAZA 3: Szczyty ścian bocznych i ściany pionowe
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not _is_walkable(grid, pos):
				var n_floor := _is_walkable(grid, pos + Vector2i(0, -1))
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


	# Czyszczenie kafelków na polach portali
	for p in portal_zone:
		walls_layer.erase_cell(p)


static func _is_walkable(grid: Dictionary, pos: Vector2i) -> bool:
	return GridUtils.is_walkable(grid, pos)
## Tworzy obraz (Image) ostatecznej maski binarnej do celów debugowania
## Czarny/Szary = WALL, Biały = FLOOR, Zielony = ENTRANCE, Czerwony = EXIT
static func get_grid_mask_image(result: GenerationResult) -> Image:
	var img := Image.create(result.width, result.height, false, Image.FORMAT_RGBA8)
	var col_wall := Color(0.12, 0.12, 0.15, 1.0)
	var col_floor := Color(0.88, 0.88, 0.90, 1.0)
	var col_entrance := Color(0.2, 0.85, 0.3, 1.0)
	var col_exit := Color(0.9, 0.25, 0.2, 1.0)

	for y in range(result.height):
		for x in range(result.width):
			var p := Vector2i(x, y)
			var type: int = result.grid.get(p, CellType.VOID)
			match type:
				CellType.WALL:
					img.set_pixel(x, y, col_wall)
				CellType.FLOOR:
					img.set_pixel(x, y, col_floor)
				CellType.ENTRANCE:
					img.set_pixel(x, y, col_entrance)
				CellType.EXIT:
					img.set_pixel(x, y, col_exit)
				_:
					img.set_pixel(x, y, Color.BLACK)
	return img


## Wypisuje wycinek siatki wokół danego punktu do konsoli Output
static func print_grid_mask_ascii(grid: Dictionary, center: Vector2i, radius: int = 10) -> void:
	print("--- PODGLĄD MASKI GRIDU (%d, %d) ---" % [center.x, center.y])
	for y in range(center.y - radius, center.y + radius + 1):
		var line := ""
		for x in range(center.x - radius, center.x + radius + 1):
			var p := Vector2i(x, y)
			var t: int = grid.get(p, CellType.VOID)
			match t:
				CellType.WALL:
					line += "#"
				CellType.FLOOR:
					line += "."
				CellType.ENTRANCE:
					line += "S"
				CellType.EXIT:
					line += "E"
				_:
					line += " "
		print(line)
