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
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const EdgeAnalyzer = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_analyzer.gd")
const TilePlacementPlanner = preload("res://modules/quiz_rpg/scripts/generation/tiling/tile_placement_planner.gd")
const TilePlacementExecutor = preload("res://modules/quiz_rpg/scripts/generation/tiling/tile_placement_executor.gd")
const TerrainPaintExecutor = preload("res://modules/quiz_rpg/scripts/generation/tiling/terrain_paint_executor.gd")
const ThemeResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/theme_resolver.gd")

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



## Nanosi dopasowane kafelki z caves.tres na warstwy Floor, FloorDecor i Walls (Etap 5 pipeline).
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

	var portal_zone: Dictionary = {}
	for p in result.entrance_zone:
		portal_zone[p] = true
	for p in result.exit_zone:
		portal_zone[p] = true

	var ctx := GenerationContext.new()
	ctx.grid = result.grid
	ctx.width = result.width
	ctx.height = result.height
	ctx.seed_value = rng.seed
	ctx.rng = rng
	ctx.tile_rng = rng
	ctx.flags = flags
	ctx.theme_override = theme_override
	ctx.entrance_zone = result.entrance_zone
	ctx.exit_zone = result.exit_zone
	ctx.portal_zone = portal_zone
	ctx.entrance_pos = result.entrance_pos
	ctx.exit_pos = result.exit_pos
	ctx.rooms = result.rooms

	var layers: Dictionary = {
		&"Floor": floor_layer,
		&"FloorDecor": floor_decor_layer,
		&"Walls": walls_layer,
	}

	var analysis := EdgeAnalyzer.analyze(ctx)
	var plans := TilePlacementPlanner.plan(ctx, analysis)

	TilePlacementExecutor.execute(layers[&"Floor"], plans.tiles, &"Floor")
	TerrainPaintExecutor.execute(layers, plans.terrain)
	TilePlacementExecutor.execute(layers[&"Walls"], plans.tiles, &"Walls")


static func _is_walkable(grid: Dictionary, pos: Vector2i) -> bool:
	return GridUtils.is_walkable(grid, pos)
## Tworzy szczegółowy obraz (Image) maski logicznej siatki z siatką 16x16 px na kafelek.
## Ściany: ciemne (#1e1e28), Podłoga: zielona (#3f723f), Wejście: jasna zieleń, Wyjście: czerwień, Siatka: (#32323e7f).
static func get_grid_mask_image(result: GenerationResult) -> Image:
	var img := Image.create(result.width * 16, result.height * 16, false, Image.FORMAT_RGBA8)
	var col_grid := Color.hex(0x32323e7f)
	var col_wall := Color.hex(0x1e1e28ff)
	var col_floor := Color.hex(0x3f723fff)
	var col_entrance := Color(0.2, 0.85, 0.3, 1.0)
	var col_exit := Color(0.9, 0.25, 0.2, 1.0)

	img.fill(col_grid)
	for y in range(result.height):
		for x in range(result.width):
			var p := Vector2i(x, y)
			var type: int = result.grid.get(p, CellType.VOID)
			var col: Color = col_wall
			match type:
				CellType.FLOOR:
					col = col_floor
				CellType.ENTRANCE:
					col = col_entrance
				CellType.EXIT:
					col = col_exit
				_:
					col = col_wall
			img.fill_rect(Rect2i(x * 16 + 1, y * 16 + 1, 15, 15), col)
	return img


## Tworzy obraz nakładkowy (Image) kandydatów Edge Detection z kafelkami wyciętymi bezpośrednio z atlasu Tiles.png.
static func get_edge_detection_mask_image(result: GenerationResult) -> Image:
	var img := Image.create(result.width * 16, result.height * 16, true, Image.FORMAT_RGBA8)
	var col_grid := Color.hex(0x32323e7f)
	img.fill(Color(0.05, 0.05, 0.08, 0.75))

	for y in range(result.height):
		for x in range(result.width):
			img.fill_rect(Rect2i(x * 16, y * 16, 16, 1), col_grid)
			img.fill_rect(Rect2i(x * 16, y * 16, 1, 16), col_grid)

	var tiles_tex = load("res://assets/pixel_crawler/_versions_archive/cave_v1/Pixel Crawler - Cave/Assets/Tiles.png") as Texture2D
	if not tiles_tex:
		return img

	var tiles_img := tiles_tex.get_image()

	var ctx := GenerationContext.new()
	ctx.grid = result.grid
	ctx.width = result.width
	ctx.height = result.height
	ctx.seed_value = result.seed_used
	ctx.flags = result.flags_used if result.flags_used != null else GenerationFlags.new()
	ctx.entrance_zone = result.entrance_zone
	ctx.exit_zone = result.exit_zone
	ctx.entrance_pos = result.entrance_pos
	ctx.exit_pos = result.exit_pos
	for p in result.entrance_zone: ctx.portal_zone[p] = true
	for p in result.exit_zone: ctx.portal_zone[p] = true
	var analysis := EdgeAnalyzer.analyze(ctx)

	var blit_tile := func(tile_coord: Vector2i, grid_pos: Vector2i) -> void:
		if tile_coord != Vector2i(-1, -1) and grid_pos.x >= 0 and grid_pos.x < result.width and grid_pos.y >= 0 and grid_pos.y < result.height:
			var src_rect := Rect2i(tile_coord.x * 16, tile_coord.y * 16, 16, 16)
			img.blit_rect(tiles_img, src_rect, Vector2i(grid_pos.x * 16, grid_pos.y * 16))

	for pos in analysis.edges:
		var edge: EdgeContext = analysis.edges[pos]
		match edge.edge_kind:
			EdgeKind.Kind.INNER_CORNER:
				var p_down: Vector2i = pos + Vector2i(0, 1)
				var foot_3h: EdgeContext = analysis.edges.get(p_down + Vector2i(0, 2))
				var is_dec_step_top_ne := false
				var is_dec_step_top_nw := false
				if foot_3h != null and foot_3h.edge_kind == EdgeKind.Kind.STEP and foot_3h.step_dy == 1:
					var step_use_roots: bool = ThemeResolver.resolve(ctx, p_down + Vector2i(0, 2), ThemeResolver.RefPoint.SELF) == &"roots"
					if step_use_roots:
						if foot_3h.orientation == EdgeKind.Orientation.EAST:
							is_dec_step_top_ne = true
						elif foot_3h.orientation == EdgeKind.Orientation.WEST:
							is_dec_step_top_nw = true

				var c := Vector2i(-1, -1)
				match edge.orientation:
					EdgeKind.Orientation.NORTH_WEST: c = Vector2i(1, 1)
					EdgeKind.Orientation.NORTH_EAST: c = Vector2i(4, 1)
					EdgeKind.Orientation.SOUTH_WEST:
						c = Vector2i(4, 13) if is_dec_step_top_ne else Vector2i(4, 4)
					EdgeKind.Orientation.SOUTH_EAST:
						c = Vector2i(1, 13) if is_dec_step_top_nw else Vector2i(1, 4)
				blit_tile.call(c, pos)

			EdgeKind.Kind.TOP_RIM:
				var is_roots: bool = ThemeResolver.resolve(ctx, pos, ThemeResolver.RefPoint.NORTH_FLOOR) == &"roots"
				if is_roots:
					var base_coord := Vector2i(2, 9)
					var tips_coord := Vector2i(2, 8)
					match edge.orientation:
						EdgeKind.Orientation.WEST:
							base_coord = Vector2i(1, 9)
							tips_coord = Vector2i(1, 8)
						EdgeKind.Orientation.EAST:
							base_coord = Vector2i(4, 9)
							tips_coord = Vector2i(4, 8)
						_:
							base_coord = Vector2i(2, 9)
							tips_coord = Vector2i(2, 8)
					blit_tile.call(base_coord, pos)
					blit_tile.call(tips_coord, pos + Vector2i(0, -1))
				else:
					var rock_coord := Vector2i(2, 0)
					match edge.orientation:
						EdgeKind.Orientation.WEST:
							rock_coord = Vector2i(1, 0)
						EdgeKind.Orientation.EAST:
							rock_coord = Vector2i(4, 0)
						_:
							rock_coord = Vector2i(2, 0)
					blit_tile.call(rock_coord, pos)

			EdgeKind.Kind.SIDE_WALL:
				var is_e: bool = edge.orientation == EdgeKind.Orientation.EAST
				var ref_p: Vector2i = pos + Vector2i(1, 0) if is_e else pos + Vector2i(-1, 0)
				var use_roots: bool = ThemeResolver.resolve(ctx, ref_p, ThemeResolver.RefPoint.SELF) == &"roots"
				var c := Vector2i(5, 11 if use_roots else 2) if is_e else Vector2i(0, 11 if use_roots else 2)
				blit_tile.call(c, pos)

			EdgeKind.Kind.FACADE:
				if edge.facade_height == 2:
					blit_tile.call(Vector2i(2, 21), pos)
					blit_tile.call(Vector2i(2, 20), pos + Vector2i(0, -1))
				else:
					var use_roots: bool = ThemeResolver.resolve(ctx, pos, ThemeResolver.RefPoint.SELF) == &"roots"
					blit_tile.call(Vector2i(2, 16 if use_roots else 7), pos)
					blit_tile.call(Vector2i(2, 15 if use_roots else 6), pos + Vector2i(0, -1))
					blit_tile.call(Vector2i(2, 14 if use_roots else 5), pos + Vector2i(0, -2))

			EdgeKind.Kind.STEP:
				var is_e: bool = edge.orientation == EdgeKind.Orientation.EAST
				var use_roots: bool = ThemeResolver.resolve(ctx, pos, ThemeResolver.RefPoint.SELF) == &"roots"
				if is_e:
					blit_tile.call(Vector2i(4, 16 if use_roots else 7), pos)
					blit_tile.call(Vector2i(4, 15 if use_roots else 6), pos + Vector2i(0, -1))
					blit_tile.call(Vector2i(4, 14 if use_roots else 5), pos + Vector2i(0, -2))
				else:
					blit_tile.call(Vector2i(1, 16 if use_roots else 7), pos)
					blit_tile.call(Vector2i(1, 15 if use_roots else 6), pos + Vector2i(0, -1))
					blit_tile.call(Vector2i(1, 14 if use_roots else 5), pos + Vector2i(0, -2))

			EdgeKind.Kind.SLOPE:
				var is_e: bool = edge.orientation == EdgeKind.Orientation.EAST
				blit_tile.call(Vector2i(4, 21) if is_e else Vector2i(1, 21), pos)
				blit_tile.call(Vector2i(4, 20) if is_e else Vector2i(1, 20), pos + Vector2i(0, -1))
				blit_tile.call(Vector2i(4, 19) if is_e else Vector2i(1, 19), pos + Vector2i(0, -2))

			EdgeKind.Kind.OUT_CORNER:
				var is_e: bool = edge.orientation == EdgeKind.Orientation.EAST
				if edge.facade_height == 2:
					var base_c := Vector2i(3, 21) if is_e else Vector2i(0, 21)
					var top_c := Vector2i(3, 20) if is_e else Vector2i(0, 20)
					blit_tile.call(base_c, pos)
					blit_tile.call(top_c, pos + Vector2i(0, -1))
				else:
					var use_roots: bool = ThemeResolver.resolve(ctx, pos, ThemeResolver.RefPoint.SELF) == &"roots"
					var base_c := Vector2i(5, 16 if use_roots else 7) if is_e else Vector2i(0, 16 if use_roots else 7)
					var mid_c := Vector2i(5, 15 if use_roots else 6) if is_e else Vector2i(0, 15 if use_roots else 6)
					var top_c := Vector2i(5, 14 if use_roots else 5) if is_e else Vector2i(0, 14 if use_roots else 5)
					blit_tile.call(base_c, pos)
					blit_tile.call(mid_c, pos + Vector2i(0, -1))
					blit_tile.call(top_c, pos + Vector2i(0, -2))

			EdgeKind.Kind.CONNECTOR:
				var is_e: bool = edge.orientation == EdgeKind.Orientation.EAST
				blit_tile.call(Vector2i(7, 21) if is_e else Vector2i(10, 21), pos)
				blit_tile.call(Vector2i(7, 20) if is_e else Vector2i(10, 20), pos + Vector2i(0, -1))
				blit_tile.call(Vector2i(7, 19) if is_e else Vector2i(10, 19), pos + Vector2i(0, -2))

			EdgeKind.Kind.NICHE:
				blit_tile.call(Vector2i(1, 6), pos)

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
