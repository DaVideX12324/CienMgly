extends Node2D

## Zaawansowany Eksplorator Generatora Map Proceduralnych dla modulu Quiz RPG.
## Umozliwia testowanie seedow, wymiarow (od 50x50 do 500x500 z asymetria),
## przelaczanie typow (Jaskinia, Las, Zamek), kamere swobodna, skoki i spacer graczem.

const ProceduralLevelScript = preload("res://modules/quiz_rpg/scripts/maps/procedural_level.gd")
const MapGeneratorBaseScript = preload("res://modules/quiz_rpg/scripts/generation/map_generator_base.gd")
const CaveGeneratorScript = preload("res://modules/quiz_rpg/scripts/generation/cave_generator.gd")
@onready var camera: Camera2D = $Camera2D
@onready var level_container: Node2D = $LevelContainer
@onready var hud: CanvasLayer = $CanvasLayer

# UI Nodes
@onready var panel: PanelContainer = $CanvasLayer/Panel
@onready var btn_hide_hud: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxTitle/BtnHideHUD
@onready var btn_show_hud: Button = $CanvasLayer/BtnShowHUD

@onready var opt_type: OptionButton = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/OptType
@onready var spin_seed: SpinBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeed/SpinSeed
@onready var btn_prev_seed: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeed/BtnPrevSeed
@onready var btn_next_seed: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeed/BtnNextSeed
@onready var btn_random_seed: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeedActions/BtnRandomSeed
@onready var btn_copy_seed: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeedActions/BtnCopySeed

@onready var opt_size_preset: OptionButton = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/OptSizePreset
@onready var spin_width: SpinBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxDimensions/SpinWidth
@onready var spin_height: SpinBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxDimensions/SpinHeight
@onready var opt_ratio: OptionButton = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/OptRatio

@onready var spin_rooms: SpinBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxRooms/SpinRooms
@onready var check_entities: CheckBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckEntities
@onready var check_nav: CheckBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckNav
@onready var check_gen_mask: CheckBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckGenMask
@onready var check_edge_mask: CheckBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckEdgeMask
var check_height_mask: CheckBox = null  # tworzony w kodzie pod CheckEdgeMask (_ensure_height_mask_check)
var check_bulge: CheckBox = null  # flaga generatora enable_bulge_flatten (_ensure_flag_checks)
@onready var btn_generate: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/BtnGenerate

@onready var btn_fit_all: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera1/BtnFitAll
@onready var btn_center: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera1/BtnCenter
@onready var btn_entrance: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera2/BtnEntrance
@onready var btn_exit: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera2/BtnExit
@onready var btn_player: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/BtnPlayer

@onready var inspector_label: RichTextLabel = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/InspectorLabel
@onready var spin_coord_x: SpinBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordInputs/SpinCoordX
@onready var spin_coord_y: SpinBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordInputs/SpinCoordY
@onready var btn_jump_coord: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordInputs/BtnJumpCoord
@onready var btn_copy_coords: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordActions/BtnCopyCoords
@onready var btn_clear_selection: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordActions/BtnClearSelection
@onready var check_tile_highlight: CheckBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckTileHighlight
@onready var check_cursor_tooltip: CheckBox = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckCursorTooltip

@onready var info_label: RichTextLabel = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/InfoLabel
@onready var tile_hud: PanelContainer = $CanvasLayer/TileHUD
@onready var tile_hud_label: RichTextLabel = $CanvasLayer/TileHUD/MarginContainer/TileHUDLabel

# Stan
var current_type: int = 2 # 2: CAVE_DUNGEON, 0: FOREST, 1: DUNGEON
var current_seed: int = 119
var _gen_busy := false     # generowanie w toku (w tle, z ekranem ładowania)
var _gen_pending := false  # prośba o nową mapę w trakcie — wykonana po zakończeniu bieżącej
var current_width: int = 100
var current_height: int = 100
var is_player_mode: bool = false
var player_instance: Node2D = null
var _prev_game_state: int = -1  # stan GameManagera sprzed spaceru graczem (przywracany po wyjściu)
var _own_game_manager: Node = null  # GameManager podglądu, gdy moduł quiz_rpg nie jest aktywny (F6)

# Ostatnie dane generacji
var last_entrance_pos: Vector2i = Vector2i.ZERO
var last_exit_pos: Vector2i = Vector2i.ZERO

# Inspektor koordynatów kafelków
var _hovered_tile: Vector2i = Vector2i(-9999, -9999)
var _selected_tile: Vector2i = Vector2i(-9999, -9999)
var _tile_overlay: Node2D = null

# Drag kamery
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _cam_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_ensure_nodes()
	_setup_tile_overlay()
	_setup_ui()
	_apply_size_preset(1) # Start na Średnim (100x100)
	_generate_current_map()
	fit_to_screen()


func _ensure_nodes() -> void:
	if not level_container:
		level_container = get_node_or_null("LevelContainer") as Node2D
	if not camera:
		camera = get_node_or_null("Camera2D") as Camera2D
	if not hud:
		hud = get_node_or_null("CanvasLayer") as CanvasLayer
	if not panel:
		panel = get_node_or_null("CanvasLayer/Panel") as PanelContainer
	if not info_label:
		info_label = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/InfoLabel") as RichTextLabel
	if not inspector_label:
		inspector_label = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/InspectorLabel") as RichTextLabel
	if not spin_coord_x:
		spin_coord_x = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordInputs/SpinCoordX") as SpinBox
	if not spin_coord_y:
		spin_coord_y = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordInputs/SpinCoordY") as SpinBox
	if not btn_jump_coord:
		btn_jump_coord = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordInputs/BtnJumpCoord") as Button
	if not btn_copy_coords:
		btn_copy_coords = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordActions/BtnCopyCoords") as Button
	if not btn_clear_selection:
		btn_clear_selection = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCoordActions/BtnClearSelection") as Button
	if not check_tile_highlight:
		check_tile_highlight = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckTileHighlight") as CheckBox
	if not check_cursor_tooltip:
		check_cursor_tooltip = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckCursorTooltip") as CheckBox
	if not tile_hud:
		tile_hud = get_node_or_null("CanvasLayer/TileHUD") as PanelContainer
	if not tile_hud_label:
		tile_hud_label = get_node_or_null("CanvasLayer/TileHUD/MarginContainer/TileHUDLabel") as RichTextLabel
	if not spin_seed:
		spin_seed = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeed/SpinSeed") as SpinBox
	if not btn_prev_seed:
		btn_prev_seed = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeed/BtnPrevSeed") as Button
	if not btn_next_seed:
		btn_next_seed = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeed/BtnNextSeed") as Button
	if not btn_random_seed:
		btn_random_seed = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeedActions/BtnRandomSeed") as Button
	if not btn_copy_seed:
		btn_copy_seed = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxSeedActions/BtnCopySeed") as Button
	if not spin_width:
		spin_width = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxDimensions/SpinWidth") as SpinBox
	if not spin_height:
		spin_height = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxDimensions/SpinHeight") as SpinBox
	if not spin_rooms:
		spin_rooms = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxRooms/SpinRooms") as SpinBox
	if not check_entities:
		check_entities = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckEntities") as CheckBox
	if not check_nav:
		check_nav = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckNav") as CheckBox
	if not check_gen_mask:
		check_gen_mask = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckGenMask") as CheckBox
	if not check_edge_mask:
		check_edge_mask = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/CheckEdgeMask") as CheckBox
	if not opt_type:
		opt_type = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/OptType") as OptionButton
	if not opt_size_preset:
		opt_size_preset = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/OptSizePreset") as OptionButton
	if not opt_ratio:
		opt_ratio = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/OptRatio") as OptionButton
	if not btn_generate:
		btn_generate = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/BtnGenerate") as Button
	if not btn_fit_all:
		btn_fit_all = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera1/BtnFitAll") as Button
	if not btn_center:
		btn_center = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera1/BtnCenter") as Button
	if not btn_entrance:
		btn_entrance = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera2/BtnEntrance") as Button
	if not btn_exit:
		btn_exit = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera2/BtnExit") as Button
	if not btn_player:
		btn_player = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/BtnPlayer") as Button
	if not btn_show_hud:
		btn_show_hud = get_node_or_null("CanvasLayer/BtnShowHUD") as Button
	if not btn_hide_hud:
		btn_hide_hud = get_node_or_null("CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxTitle/BtnHideHUD") as Button

# Wewnątrz map_generator_preview.gd:
var _mask_sprite: Sprite2D = null
var _edge_mask_sprite: Sprite2D = null
var _height_mask_sprite: Sprite2D = null

# Mapa wysokości: pole szumu > próg na CAŁEJ mapie (też nad ścianami/voidem) jako półprzezroczyste
# wypełnienie z gładkim konturem; na nim faktyczny płaskowyż (mocniej) i schody (żółte).
const PlateauPassScript = preload("res://modules/quiz_rpg/scripts/generation/topology/plateau_pass.gd")
const HEIGHT_MASK_PX := 4  # próbki na kratkę w każdą stronę (gładki kontur)
const HEIGHT_FIELD_FILL := Color(0.25, 0.85, 1.0, 0.18)
const HEIGHT_FIELD_EDGE := Color(0.35, 0.9, 1.0, 0.95)
const HEIGHT_PLATEAU_FILL := Color(0.25, 0.85, 1.0, 0.45)
const HEIGHT_STAIR_FILL := Color(1.0, 0.85, 0.2, 0.7)
const HEIGHT_HIGH_FILL := Color(0.15, 0.45, 1.0, 0.6)   # poziom 2 i wyżej
const HEIGHT_BASE_FILL := Color(0.6, 0.6, 0.55, 0.12)      # pasmo pola: wysokość bazowa (0)
const HEIGHT_HIGH_FIELD_FILL := Color(0.15, 0.45, 1.0, 0.22) # pasmo pola: poziom 2+
const HEIGHT_PIT_FIELD_FILL := Color(0.95, 0.45, 0.2, 0.2)   # pasmo pola: doły
const HEIGHT_PIT_EDGE := Color(1.0, 0.55, 0.25, 0.95)        # kontur pasma dołów
const HEIGHT_PIT_FILL := Color(0.95, 0.4, 0.2, 0.5)     # zagłębienia (poziom < 0)


func _toggle_grid_mask() -> void:
	var should_show := not is_instance_valid(_mask_sprite)

	if check_gen_mask:
		check_gen_mask.button_pressed = should_show
	else:
		if should_show:
			_show_grid_mask()
		else:
			_hide_grid_mask()


func _toggle_edge_mask() -> void:
	var should_show := not is_instance_valid(_edge_mask_sprite)

	if check_edge_mask:
		check_edge_mask.button_pressed = should_show
	else:
		if should_show:
			_show_edge_mask()
		else:
			_hide_edge_mask()


func _on_grid_mask_toggled(enabled: bool) -> void:
	if enabled:
		_show_grid_mask()
	else:
		_hide_grid_mask()


func _on_edge_mask_toggled(enabled: bool) -> void:
	if enabled:
		_show_edge_mask()
	else:
		_hide_edge_mask()


func _show_grid_mask() -> void:
	if is_instance_valid(_mask_sprite):
		_mask_sprite.visible = true
		return

	if not level_container or level_container.get_child_count() == 0:
		return

	var proc_level := level_container.get_child(0)
	var res: Variant = proc_level.get("last_result") if proc_level else null

	if not res:
		return

	var img: Image = CaveGeneratorScript.get_grid_mask_image(res)

	if img == null or img.is_empty():
		push_warning("Nie udało się utworzyć obrazu maski.")
		return

	var tex := ImageTexture.create_from_image(img)

	_mask_sprite = Sprite2D.new()
	_mask_sprite.name = "GridMask"
	_mask_sprite.texture = tex
	_mask_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mask_sprite.scale = Vector2.ONE
	_mask_sprite.centered = false
	_mask_sprite.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_mask_sprite.z_index = 100

	level_container.add_child(_mask_sprite)


func _hide_grid_mask() -> void:
	if is_instance_valid(_mask_sprite):
		_mask_sprite.queue_free()

	_mask_sprite = null


func _show_edge_mask() -> void:
	if is_instance_valid(_edge_mask_sprite):
		_edge_mask_sprite.visible = true
		return

	if not level_container or level_container.get_child_count() == 0:
		return

	var proc_level := level_container.get_child(0)
	var res: Variant = proc_level.get("last_result") if proc_level else null

	if not res:
		return

	var img: Image = CaveGeneratorScript.get_edge_detection_mask_image(res)

	if img == null or img.is_empty():
		push_warning("Nie udało się utworzyć obrazu maski Edge Detection.")
		return

	var tex := ImageTexture.create_from_image(img)

	_edge_mask_sprite = Sprite2D.new()
	_edge_mask_sprite.name = "EdgeDetectionMask"
	_edge_mask_sprite.texture = tex
	_edge_mask_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_edge_mask_sprite.scale = Vector2.ONE
	_edge_mask_sprite.centered = false
	_edge_mask_sprite.modulate = Color(1.0, 1.0, 1.0, 0.95)
	_edge_mask_sprite.z_index = 105

	level_container.add_child(_edge_mask_sprite)


func _hide_edge_mask() -> void:
	if is_instance_valid(_edge_mask_sprite):
		_edge_mask_sprite.queue_free()

	_edge_mask_sprite = null


## Checkbox maski wysokości pod CheckEdgeMask (w kodzie, żeby nie zależeć od zapisu sceny).
func _ensure_height_mask_check() -> void:
	if check_height_mask or not check_edge_mask:
		return
	check_height_mask = CheckBox.new()
	check_height_mask.name = "CheckHeightMask"
	check_height_mask.text = "Pokaż mapę wysokości (płaskowyże)"
	var box := check_edge_mask.get_parent()
	box.add_child(check_height_mask)
	box.move_child(check_height_mask, check_edge_mask.get_index() + 1)


## Checkboxy flag generatora pod CheckNav (w kodzie). Stan początkowy z caves.json.
func _ensure_flag_checks() -> void:
	if check_bulge or not check_nav:
		return
	check_bulge = CheckBox.new()
	check_bulge.name = "CheckBulgeFlatten"
	check_bulge.text = "Spłaszczanie wybrzuszeń ścian"
	check_bulge.tooltip_text = "Flaga enable_bulge_flatten (ShortBulgeFlattenPass): wyrównuje wąskie ściany 3H+ przy 2H. Zmiana przegenerowuje mapę."
	var cfg = GeneratorBehaviourConfig.load_from_json_path("res://modules/quiz_rpg/resources/maps/config/caves.json")
	check_bulge.button_pressed = cfg.build_flags().enable_bulge_flatten
	var box := check_nav.get_parent()
	box.add_child(check_bulge)
	box.move_child(check_bulge, check_nav.get_index() + 1)


func _toggle_height_mask() -> void:
	var should_show := not is_instance_valid(_height_mask_sprite)
	if check_height_mask:
		check_height_mask.button_pressed = should_show
	elif should_show:
		_show_height_mask()
	else:
		_hide_height_mask()


func _on_height_mask_toggled(enabled: bool) -> void:
	if enabled:
		_show_height_mask()
	else:
		_hide_height_mask()


func _show_height_mask() -> void:
	if is_instance_valid(_height_mask_sprite):
		_height_mask_sprite.visible = true
		return
	if not level_container or level_container.get_child_count() == 0:
		return
	var proc_level := level_container.get_child(0)
	var res: Variant = proc_level.get("last_result") if proc_level else null
	if not res:
		return
	var img := _build_height_mask_image(res)
	if img == null:
		push_warning("Mapa wysokości niedostępna (płaskowyże wyłączone albo inny typ mapy).")
		return

	_height_mask_sprite = Sprite2D.new()
	_height_mask_sprite.name = "HeightMask"
	_height_mask_sprite.texture = ImageTexture.create_from_image(img)
	_height_mask_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_height_mask_sprite.scale = Vector2.ONE * (16.0 / HEIGHT_MASK_PX)  # kratka = 16 px
	_height_mask_sprite.centered = false
	_height_mask_sprite.z_index = 102
	level_container.add_child(_height_mask_sprite)


func _hide_height_mask() -> void:
	if is_instance_valid(_height_mask_sprite):
		_height_mask_sprite.queue_free()
	_height_mask_sprite = null


## Obraz HEIGHT_MASK_PX px / kratkę: pole mapy wysokości na całej mapie podzielone na pasma — doły
## (-1, -2…), wysokość bazowa (0, tam gdzie szum nie przekracza żadnego progu), poziom 1, 2… — każde
## z półprzezroczystym kolorem i konturem na granicy. Na wierzchu faktyczne kratki wysokości i schody.
func _build_height_mask_image(res) -> Image:
	var pl = res.plateau if "plateau" in res else null
	if pl == null or pl.noise_frequency <= 0.0:
		return null
	var s := HEIGHT_MASK_PX
	var w: int = res.width * s
	var h: int = res.height * s
	var noise: FastNoiseLite = PlateauPassScript.make_noise(pl.noise_seed, pl.noise_frequency, pl.noise_octaves)

	# Pasmo pola w każdym podpikselu (próbka szumu jak w generatorze, z blokami).
	var band := PackedInt32Array()
	band.resize(w * h)
	var block: int = pl.noise_block
	for py in range(h):
		var fy := (py + 0.5) / s
		for px in range(w):
			var v: float
			if block > 1:
				v = PlateauPassScript.sample_height(noise, Vector2i(int(float(px) / s), int(float(py) / s)), block)
			else:
				v = noise.get_noise_2d((px + 0.5) / s, fy)
			band[py * w + px] = _field_band(pl, v)

	var data := PackedByteArray()
	data.resize(w * h * 4)
	var colors := {}
	for i in range(w * h):
		var bnd: int = band[i]
		if not colors.has(bnd):
			colors[bnd] = _rgba8(_band_color(bnd))
		_put(data, i, colors[bnd])
	# Faktyczne kratki (po czyszczeniu, schodach i naprawie) mocniejszymi kolorami.
	var plateau := _rgba8(HEIGHT_PLATEAU_FILL)
	for c in pl.mask:
		_put_cell(data, w, c, s, plateau)
	var high := _rgba8(HEIGHT_HIGH_FILL)
	var pit := _rgba8(HEIGHT_PIT_FILL)
	for c in pl.heights:
		var hc: int = int(pl.heights[c])
		if hc >= 2:
			_put_cell(data, w, c, s, high)
		elif hc < 0:
			_put_cell(data, w, c, s, pit)
	var stair := _rgba8(HEIGHT_STAIR_FILL)
	for c in pl.stair_cells():
		_put_cell(data, w, c, s, stair)
	# Kontury pasm na wierzchu: podpiksel z sąsiadem z innego pasma (rysowany po stronie wyższego
	# pasma dla wzniesień, niższego dla dołów — kontur leży na krawędzi „wzniesienia” / „dołu”).
	var edge := _rgba8(HEIGHT_FIELD_EDGE)
	var pit_edge := _rgba8(HEIGHT_PIT_EDGE)
	for py in range(h):
		for px in range(w):
			var i := py * w + px
			var b0: int = band[i]
			if b0 == 0:
				continue
			var nbs := [
				band[i - 1] if px > 0 else b0, band[i + 1] if px < w - 1 else b0,
				band[i - w] if py > 0 else b0, band[i + w] if py < h - 1 else b0]
			for nb in nbs:
				if (b0 > 0 and nb < b0) or (b0 < 0 and nb > b0):
					_put(data, i, edge if b0 > 0 else pit_edge)
					break
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


## Pasmo pola dla wartości szumu v: 0 = wysokość bazowa, 1..level_count = wzniesienia, -1..-pit_count = doły.
static func _field_band(pl, v: float) -> int:
	var step: float = maxf(pl.level_step, 0.0001)
	if pl.pit_count > 0 and v < pl.pit_threshold:
		return -mini(pl.pit_count, 1 + int(floor((pl.pit_threshold - v) / step)))
	if v <= pl.threshold:
		return 0
	if pl.level_count < 2 or v <= pl.high_threshold:
		return 1
	return mini(pl.level_count, 2 + int(floor((v - pl.high_threshold) / step)))


static func _band_color(bnd: int) -> Color:
	if bnd == 0:
		return HEIGHT_BASE_FILL
	if bnd < 0:
		return HEIGHT_PIT_FIELD_FILL
	if bnd == 1:
		return HEIGHT_FIELD_FILL
	return HEIGHT_HIGH_FIELD_FILL


static func _rgba8(c: Color) -> PackedByteArray:
	return PackedByteArray([c.r8, c.g8, c.b8, c.a8])


static func _put(data: PackedByteArray, i: int, rgba: PackedByteArray) -> void:
	data[i * 4] = rgba[0]
	data[i * 4 + 1] = rgba[1]
	data[i * 4 + 2] = rgba[2]
	data[i * 4 + 3] = rgba[3]


static func _put_cell(data: PackedByteArray, w: int, c: Vector2i, s: int, rgba: PackedByteArray) -> void:
	if c.x < 0 or c.y < 0 or (c.x + 1) * s > w or (c.y + 1) * s * w * 4 > data.size():
		return
	for dy in range(s):
		for dx in range(s):
			_put(data, (c.y * s + dy) * w + c.x * s + dx, rgba)
	
func _setup_ui() -> void:
	# 1. Typy generatora
	opt_type.clear()
	opt_type.add_item("🦇 Jaskinie (Caves)", 2)
	opt_type.add_item("🌲 Las (Overworld)", 0)
	opt_type.add_item("🏰 Zamek (Dungeon)", 1)
	opt_type.select(0) # Jaskinie
	opt_type.item_selected.connect(_on_type_selected)

	# 2. Seed
	spin_seed.value = current_seed
	spin_seed.value_changed.connect(func(val: float): current_seed = int(val))
	btn_prev_seed.pressed.connect(func():
		spin_seed.value = maxi(1, int(spin_seed.value) - 1)
		_generate_current_map()
	)
	btn_next_seed.pressed.connect(func():
		spin_seed.value = int(spin_seed.value) + 1
		_generate_current_map()
	)
	btn_random_seed.pressed.connect(_on_random_seed_pressed)
	btn_copy_seed.pressed.connect(func():
		DisplayServer.clipboard_set(str(int(spin_seed.value)))
		btn_copy_seed.text = "✓ Skopiowano"
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(btn_copy_seed):
				btn_copy_seed.text = "📋 Kopiuj"
		)
	)

	# 3. Presety rozmiaru
	opt_size_preset.clear()
	opt_size_preset.add_item("Kompaktowy (50 x 50)", 50)
	opt_size_preset.add_item("Średni (100 x 100)", 100)
	opt_size_preset.add_item("Duży (250 x 250)", 250)
	opt_size_preset.add_item("Ogromny (500 x 500)", 500)
	opt_size_preset.add_item("Własny (Custom)", -1)
	opt_size_preset.select(1) # 100x100 domyslnie
	opt_size_preset.item_selected.connect(_on_size_preset_selected)

	spin_width.value = current_width
	spin_height.value = current_height
	spin_width.value_changed.connect(_on_custom_dimensions_changed)
	spin_height.value_changed.connect(_on_custom_dimensions_changed)

	# 4. Proporcje / Aspect Ratio
	opt_ratio.clear()
	opt_ratio.add_item("Kwadrat (1:1)", 0)
	opt_ratio.add_item("Lekka asymetria (±15%)", 15)
	opt_ratio.add_item("Umiarkowana (±25%)", 25)
	opt_ratio.add_item("Mocna asymetria (±50%)", 50)
	opt_ratio.add_item("Własne (Wg pól W x H)", -1)
	opt_ratio.select(0)
	opt_ratio.item_selected.connect(_on_ratio_selected)

	# 5. Generuj i Opcje
	btn_generate.pressed.connect(_generate_current_map)
	if check_gen_mask:
		check_gen_mask.toggled.connect(_on_grid_mask_toggled)
	if check_edge_mask:
		check_edge_mask.toggled.connect(_on_edge_mask_toggled)
	_ensure_height_mask_check()
	if check_height_mask:
		check_height_mask.toggled.connect(_on_height_mask_toggled)
	_ensure_flag_checks()
	if check_bulge:
		check_bulge.toggled.connect(func(_on: bool) -> void: _generate_current_map())

	# 6. Kamera
	btn_fit_all.pressed.connect(fit_to_screen)
	btn_center.pressed.connect(jump_to_center)
	btn_entrance.pressed.connect(jump_to_entrance)
	btn_exit.pressed.connect(jump_to_exit)
	btn_player.pressed.connect(_toggle_player_mode)

	# 7. Zwijanie HUD
	btn_hide_hud.pressed.connect(_toggle_hud)
	btn_show_hud.pressed.connect(_toggle_hud)

	# 8. Inspektor kafelków
	if btn_jump_coord:
		btn_jump_coord.pressed.connect(_jump_to_custom_coord)
	if btn_copy_coords:
		btn_copy_coords.pressed.connect(_copy_current_tile_coords)
	if btn_clear_selection:
		btn_clear_selection.pressed.connect(_clear_tile_selection)
	if check_tile_highlight:
		check_tile_highlight.toggled.connect(func(_enabled: bool):
			if is_instance_valid(_tile_overlay):
				_tile_overlay.queue_redraw()
		)
	if check_cursor_tooltip:
		check_cursor_tooltip.toggled.connect(func(enabled: bool):
			if is_instance_valid(tile_hud):
				tile_hud.visible = enabled
			if is_instance_valid(_tile_overlay):
				_tile_overlay.queue_redraw()
		)


func _on_type_selected(index: int) -> void:
	current_type = opt_type.get_item_id(index)
	_generate_current_map()


func _on_size_preset_selected(index: int) -> void:
	var base_s: int = opt_size_preset.get_item_id(index)
	if base_s > 0:
		_apply_size_with_ratio(base_s)
		_generate_current_map()


func _apply_size_preset(index: int) -> void:
	opt_size_preset.select(index)
	var base_s: int = opt_size_preset.get_item_id(index)
	if base_s > 0:
		_apply_size_with_ratio(base_s)


func _on_ratio_selected(_index: int) -> void:
	var preset_idx := opt_size_preset.selected
	var base_s: int = opt_size_preset.get_item_id(preset_idx)
	if base_s > 0:
		_apply_size_with_ratio(base_s)
		_generate_current_map()


func _on_custom_dimensions_changed(_val: float) -> void:
	current_width = int(spin_width.value)
	current_height = int(spin_height.value)
	# Jezeli recznie zmieniono, ustaw na Wlasny
	for i in range(opt_size_preset.item_count):
		if opt_size_preset.get_item_id(i) == -1:
			opt_size_preset.select(i)
			break


func _apply_size_with_ratio(base_size: int) -> void:
	var ratio_variance: int = opt_ratio.get_selected_id()
	if ratio_variance <= 0:
		current_width = base_size
		current_height = base_size
	else:
		# Losowa wariancja wymiarow w zakresie podanego procentu
		var rng := RandomNumberGenerator.new()
		rng.seed = current_seed + 999
		var delta_percent := float(ratio_variance) / 100.0
		var mult_w: float = 1.0 + rng.randf_range(-delta_percent, delta_percent)
		var mult_h: float = 1.0 + rng.randf_range(-delta_percent, delta_percent)
		current_width = int(clampf(round(float(base_size) * mult_w), 20.0, 600.0))
		current_height = int(clampf(round(float(base_size) * mult_h), 20.0, 600.0))

	spin_width.set_value_no_signal(current_width)
	spin_height.set_value_no_signal(current_height)


func _on_random_seed_pressed() -> void:
	current_seed = int(randi() % 1000000)
	spin_seed.value = current_seed
	var base_s: int = opt_size_preset.get_selected_id()
	if base_s > 0:
		_apply_size_with_ratio(base_s)
	_generate_current_map()


func _toggle_hud() -> void:
	panel.visible = not panel.visible
	btn_show_hud.visible = not panel.visible


func _unhandled_input(event: InputEvent) -> void:
	# Skróty klawiszowe
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_random_seed_pressed()
				get_viewport().set_input_as_handled()
			KEY_C:
				_copy_current_tile_coords()
				get_viewport().set_input_as_handled()
			KEY_G:
				_jump_to_custom_coord()
				get_viewport().set_input_as_handled()
			KEY_F:
				fit_to_screen()
			KEY_1:
				jump_to_entrance()
			KEY_2:
				jump_to_exit()
			KEY_3:
				jump_to_center()
			KEY_P:
				_toggle_player_mode()
			KEY_H:
				_toggle_hud()
			KEY_F1:
				opt_type.select(1) # Las
				_on_type_selected(1)
			KEY_M:
				_toggle_grid_mask()
			KEY_E:
				_toggle_edge_mask()
			KEY_L:
				_toggle_height_mask()
			KEY_F2:
				opt_type.select(2) # Zamek
				_on_type_selected(2)
			KEY_F3:
				opt_type.select(0) # Jaskinia
				_on_type_selected(0)

	# Kliknięcie i Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_world := get_global_mouse_position()
			var clicked_tile := Vector2i(int(floor(mouse_world.x / 16.0)), int(floor(mouse_world.y / 16.0)))
			if _is_in_bounds(clicked_tile):
				_select_tile(clicked_tile)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(0.85)
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_dragging = true
				_drag_start = event.position
				_cam_start_pos = camera.position
			else:
				_is_dragging = false

	# Drag kamery
	if event is InputEventMouseMotion and _is_dragging and not is_player_mode:
		var delta_pos: Vector2 = event.position - _drag_start
		camera.position = _cam_start_pos - (delta_pos / camera.zoom.x)


func _process(delta: float) -> void:
	if not is_player_mode:
		var move := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move.y += 1
		if move != Vector2.ZERO:
			camera.position += move.normalized() * (600.0 * delta / camera.zoom.x)
	elif is_instance_valid(player_instance):
		camera.position = player_instance.global_position

	# Śledzenie pozycji kafelka pod kursorem
	var mouse_world := get_global_mouse_position()
	var current_tile := Vector2i(int(floor(mouse_world.x / 16.0)), int(floor(mouse_world.y / 16.0)))
	if current_tile != _hovered_tile:
		_hovered_tile = current_tile
		_update_tile_inspector_ui()
		if is_instance_valid(_tile_overlay):
			_tile_overlay.queue_redraw()


func _zoom_camera(factor: float) -> void:
	var new_zoom: float = clampf(camera.zoom.x * factor, 0.02, 4.0)
	camera.zoom = Vector2(new_zoom, new_zoom)


func fit_to_screen() -> void:
	_ensure_nodes()
	if not camera:
		return
	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1280, 720)
	var map_px := Vector2(current_width * 16.0, current_height * 16.0)
	camera.position = map_px / 2.0

	var margin_x := 380.0 if (panel and panel.visible) else 60.0
	var margin_y := 60.0
	var available_w: float = maxf(100.0, vp_size.x - margin_x)
	var available_h: float = maxf(100.0, vp_size.y - margin_y)

	var zoom_x: float = available_w / maxf(1.0, map_px.x)
	var zoom_y: float = available_h / maxf(1.0, map_px.y)
	var z: float = clampf(minf(zoom_x, zoom_y), 0.02, 3.0)
	camera.zoom = Vector2(z, z)


func jump_to_center() -> void:
	_ensure_nodes()
	if camera:
		camera.position = Vector2(current_width * 8.0, current_height * 8.0)


func jump_to_entrance() -> void:
	_ensure_nodes()
	if camera:
		camera.position = Vector2(last_entrance_pos.x * 16.0 + 8.0, last_entrance_pos.y * 16.0 + 8.0)
		camera.zoom = Vector2(1.5, 1.5)


func jump_to_exit() -> void:
	_ensure_nodes()
	if camera:
		camera.position = Vector2(last_exit_pos.x * 16.0 + 8.0, last_exit_pos.y * 16.0 + 8.0)
		camera.zoom = Vector2(1.5, 1.5)


func _generate_current_map() -> void:
	if _gen_busy:
		_gen_pending = true
		return
	_gen_busy = true
	await _generate_current_map_impl()
	_gen_busy = false
	if _gen_pending:
		_gen_pending = false
		_generate_current_map()


func _generate_current_map_impl() -> void:
	_ensure_nodes()
	if is_instance_valid(player_instance):
		player_instance.queue_free()
		player_instance = null
		is_player_mode = false
		_set_exploring(false)
		if btn_player:
			btn_player.text = "🏃 Spacer Graczem (P)"

	if not level_container:
		return

	for child in level_container.get_children():
		child.queue_free()

	_mask_sprite = null
	_edge_mask_sprite = null
	_height_mask_sprite = null

	if spin_seed:
		current_seed = int(spin_seed.value)
	if spin_width:
		current_width = int(spin_width.value)
	if spin_height:
		current_height = int(spin_height.value)

	var t_start := Time.get_ticks_msec()

	var proc_level: Node2D = ProceduralLevelScript.new()
	proc_level.set("level_type", current_type)
	proc_level.set("map_seed", current_seed)
	proc_level.set("map_width", current_width)
	proc_level.set("map_height", current_height)
	proc_level.set("cave_max_rooms", int(spin_rooms.value) if spin_rooms else 0)
	proc_level.set("spawn_entities_enabled", check_entities.button_pressed if check_entities else true)
	proc_level.set("setup_nav_enabled", check_nav.button_pressed if check_nav else true)
	if check_bulge:
		proc_level.set("flag_overrides", {"enable_bulge_flatten": check_bulge.button_pressed})
	level_container.add_child(proc_level)
	if proc_level.get("is_generating") == true:
		await proc_level.generation_finished

	var t_gen: int = Time.get_ticks_msec() - t_start

	var res: Variant = proc_level.get("last_result")
	if res:
		last_entrance_pos = res.entrance_pos if "entrance_pos" in res else res.player_spawn
		last_exit_pos = res.exit_pos if "exit_pos" in res else Vector2i.ZERO

		var type_names := {2: "🦇 Jaskinie (Caves)", 0: "🌲 Las (Overworld)", 1: "🏰 Zamek (Dungeon)"}
		var type_name: String = type_names.get(current_type, "Nieznany")

		var rooms_count: int = 0
		var rooms_label := "Pokoje"
		if current_type == 0:
			rooms_count = res.clearings.size() if "clearings" in res else 0
			rooms_label = "Polany"
		else:
			rooms_count = res.rooms.size() if "rooms" in res else 0

		var dist: float = Vector2(last_entrance_pos).distance_to(Vector2(last_exit_pos))
		var ratio: float = float(current_width) / float(maxi(1, current_height))

		var extra_stats := ""
		if current_type == 2:
			# Statystyki jaskiniowe
			var walls_layer := proc_level.find_child("Walls", true, false) as TileMapLayer
			if walls_layer:
				var total_tiles := walls_layer.get_used_cells().size()
				extra_stats = "\n[b]Kafelki ścian:[/b] %d" % total_tiles
			if "plateau" in res:
				var pl = res.plateau
				var cells: int = pl.mask.size() if pl != null else 0
				var stairs_s: int = pl.stairs.size() if pl != null else 0
				var stairs_n: int = pl.stairs_north.size() if pl != null else 0
				var stairs_e: int = pl.stairs_east.size() if pl != null else 0
				var stairs_w: int = pl.stairs_west.size() if pl != null else 0
				var total_st: int = stairs_s + stairs_n + stairs_e + stairs_w
				extra_stats += "\n[b]Płaskowyże:[/b] %d kratek, %d schodów (%d S / %d N / %d E / %d W)" % [cells, total_st, stairs_s, stairs_n, stairs_e, stairs_w]
				if pl != null and (pl.max_level >= 2 or pl.min_level < 0):
					var n_high := 0
					var n_pit := 0
					for c in pl.heights:
						if int(pl.heights[c]) >= 2:
							n_high += 1
						elif int(pl.heights[c]) < 0:
							n_pit += 1
					extra_stats += "\n[b]Poziomy:[/b] %d..%d, poziom 2+: %d kratek, zagłębienia: %d kratek" % [pl.min_level, pl.max_level, n_high, n_pit]

		info_label.text = """[b]Typ:[/b] %s
[b]Seed:[/b] [color=#ffdd66]%d[/color]
[b]Rozmiar:[/b] %dx%d (Ratio: %.2f:1)
[b]Czas gen.:[/b] [color=#66ff88]%d ms[/color]
[b]%s:[/b] %d
[b]Wejście (Start):[/b] (%d, %d)
[b]Wyjście (Koniec):[/b] (%d, %d)
[b]Dystans S-K:[/b] %.1f kratek
[b]Wrogowie / Skrzynie:[/b] %d / %d%s""" % [
			type_name,
			current_seed,
			current_width,
			current_height,
			ratio,
			t_gen,
			rooms_label,
			rooms_count,
			last_entrance_pos.x, last_entrance_pos.y,
			last_exit_pos.x, last_exit_pos.y,
			dist,
			res.enemy_spawns.size() if "enemy_spawns" in res else 0,
			_chest_cells(res).size(),
			extra_stats
		]

		if check_gen_mask and check_gen_mask.button_pressed:
			_show_grid_mask()
		if check_edge_mask and check_edge_mask.button_pressed:
			_show_edge_mask()
		if check_height_mask and check_height_mask.button_pressed:
			_show_height_mask()

	if spin_coord_x:
		spin_coord_x.max_value = float(maxi(0, current_width - 1))
	if spin_coord_y:
		spin_coord_y.max_value = float(maxi(0, current_height - 1))

	if not _is_in_bounds(_selected_tile):
		_selected_tile = Vector2i(-9999, -9999)

	_update_tile_inspector_ui()
	if is_instance_valid(_tile_overlay):
		_tile_overlay.queue_redraw()


func _toggle_player_mode() -> void:
	if is_player_mode:
		if is_instance_valid(player_instance):
			player_instance.queue_free()
			player_instance = null
		is_player_mode = false
		_set_exploring(false)
		btn_player.text = "🏃 Spacer Graczem (P)"
		camera.zoom = Vector2(0.8, 0.8)
	else:
		var player_scene_path := "res://modules/quiz_rpg/scenes/player/player.tscn"
		if not ResourceLoader.exists(player_scene_path):
			push_warning("Player scene not found")
			return
		var p_packed := load(player_scene_path) as PackedScene
		if not p_packed:
			return

		if level_container.get_child_count() == 0:
			return
		var proc_level := level_container.get_child(0)
		var res: Variant = proc_level.get("last_result") if proc_level else null
		if not res:
			return

		var spawn_px := Vector2(last_entrance_pos.x * 16.0 + 8.0, last_entrance_pos.y * 16.0 + 8.0)

		_set_exploring(true)  # przed dodaniem gracza — player.gd pobiera GameManager w _ready
		player_instance = p_packed.instantiate() as Node2D
		player_instance.global_position = spawn_px
		level_container.add_child(player_instance)

		is_player_mode = true
		btn_player.text = "🕊️ Wolna Kamera (P)"
		camera.zoom = Vector2(2.0, 2.0)
		camera.position = spawn_px


## Gracz rusza się tylko w stanie EXPLORING GameManagera (player.gd), a podgląd startuje w MENU —
## na czas spaceru przełączamy stan i przywracamy poprzedni po wyjściu. Podgląd uruchomiony sam (F6)
## nie ma modułu quiz_rpg, więc i jego singletonów — wtedy tworzy własny GameManager.
func _set_exploring(on: bool) -> void:
	# Autoload przez ścieżkę, nie identyfikator: skrypty narzędziowe (-s) preloadują podgląd przed
	# autoloadami i goły identyfikator CoreManager wywaliłby ich kompilację.
	var core := get_node_or_null("/root/CoreManager")
	if core == null:
		return
	var gm = core.get_singleton("GameManager")
	if gm == null:
		if not on:
			return
		_own_game_manager = Node.new()
		_own_game_manager.name = "GameManager"
		_own_game_manager.set_script(load("res://modules/quiz_rpg/autoloads/game_manager.gd"))
		add_child(_own_game_manager)
		core.register_singleton("GameManager", _own_game_manager)
		gm = _own_game_manager
	if on:
		if _prev_game_state < 0:
			_prev_game_state = gm.current_state
		gm.change_state(gm.GameState.EXPLORING)
	elif _prev_game_state >= 0:
		gm.change_state(_prev_game_state)
		_prev_game_state = -1


func _exit_tree() -> void:
	_set_exploring(false)
	var core := get_node_or_null("/root/CoreManager")
	if _own_game_manager and core and core.get_active_module_id() == "" 			and core.get_singleton("GameManager") == _own_game_manager:
		core.unregister_module_singletons()


# =========================================================================
# INSPEKTOR KOORDYNATÓW KAFELKÓW (Tile Inspector)
# =========================================================================

func _setup_tile_overlay() -> void:
	if not _tile_overlay:
		_tile_overlay = Node2D.new()
		_tile_overlay.name = "TileInspectorOverlay"
		_tile_overlay.z_index = 250
		_tile_overlay.draw.connect(_on_tile_overlay_draw)
		add_child(_tile_overlay)


func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < current_width and pos.y >= 0 and pos.y < current_height


func _select_tile(tile_pos: Vector2i) -> void:
	_selected_tile = tile_pos
	if spin_coord_x:
		spin_coord_x.set_value_no_signal(tile_pos.x)
	if spin_coord_y:
		spin_coord_y.set_value_no_signal(tile_pos.y)
	_update_tile_inspector_ui()
	if is_instance_valid(_tile_overlay):
		_tile_overlay.queue_redraw()


func _clear_tile_selection() -> void:
	_selected_tile = Vector2i(-9999, -9999)
	_update_tile_inspector_ui()
	if is_instance_valid(_tile_overlay):
		_tile_overlay.queue_redraw()


func _jump_to_custom_coord() -> void:
	var tx: int = int(spin_coord_x.value) if spin_coord_x else 0
	var ty: int = int(spin_coord_y.value) if spin_coord_y else 0
	var target := Vector2i(tx, ty)
	_select_tile(target)
	if camera:
		camera.position = Vector2(target.x * 16.0 + 8.0, target.y * 16.0 + 8.0)
		if camera.zoom.x < 1.0:
			camera.zoom = Vector2(1.5, 1.5)


func _copy_current_tile_coords() -> void:
	var target := _selected_tile if _is_in_bounds(_selected_tile) else _hovered_tile
	if not _is_in_bounds(target):
		return
	var coord_str := "(%d, %d)" % [target.x, target.y]
	DisplayServer.clipboard_set(coord_str)
	if is_instance_valid(btn_copy_coords):
		btn_copy_coords.text = "✓ " + coord_str
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(btn_copy_coords):
				btn_copy_coords.text = "📋 Kopiuj (X, Y)"
		)


func _get_tile_info(tile_pos: Vector2i) -> Dictionary:
	var info := {
		"in_bounds": _is_in_bounds(tile_pos),
		"tile_pos": tile_pos,
		"world_pos": Vector2(tile_pos.x * 16.0, tile_pos.y * 16.0),
		"center_pos": Vector2(tile_pos.x * 16.0 + 8.0, tile_pos.y * 16.0 + 8.0),
		"cell_type": -1,
		"cell_name": "Poza mapą",
		"tags": [] as Array[String],
		"walls_layer": "",
		"floor_layer": "",
		"decor_layer": "",
		"platforms_layer": "",
		"dist_entrance": 0.0,
		"dist_exit": 0.0,
		"manhattan_entrance": 0,
		"manhattan_exit": 0
	}

	if not info.in_bounds:
		return info

	info.dist_entrance = Vector2(tile_pos).distance_to(Vector2(last_entrance_pos))
	info.dist_exit = Vector2(tile_pos).distance_to(Vector2(last_exit_pos))
	info.manhattan_entrance = absi(tile_pos.x - last_entrance_pos.x) + absi(tile_pos.y - last_entrance_pos.y)
	info.manhattan_exit = absi(tile_pos.x - last_exit_pos.x) + absi(tile_pos.y - last_exit_pos.y)

	var proc_level := level_container.get_child(0) if level_container and level_container.get_child_count() > 0 else null
	var res: Variant = proc_level.get("last_result") if proc_level else null

	var cell_names := {
		0: "Pustka (VOID)",
		1: "Podłoga (FLOOR)",
		2: "Ściana (WALL)",
		3: "Ścieżka (PATH)",
		4: "Drzewo (TREE)",
		5: "Woda (WATER)",
		6: "Drzwi (DOOR)",
		7: "Wejście (ENTRANCE)",
		8: "Wyjście (EXIT)",
		9: "Dekoracja (DECORATION)"
	}

	if res and "grid" in res and res.grid is Dictionary:
		var ctype: int = res.grid.get(tile_pos, -1)
		info.cell_type = ctype
		info.cell_name = cell_names.get(ctype, "Nieznany (%d)" % ctype)

	# Tagi specjalne / Obiekty
	if tile_pos == last_entrance_pos:
		info.tags.append("🚪 START (Wejście)")
	if tile_pos == last_exit_pos:
		info.tags.append("🏁 META (Wyjście)")

	if res:
		if tile_pos in _chest_cells(res):
			info.tags.append("📦 Skrzynia")
		if "enemy_spawns" in res:
			for esp in res.enemy_spawns:
				if esp is Dictionary and esp.get("pos") == tile_pos:
					info.tags.append("👾 Wróg (Tier %s)" % str(esp.get("tier", 1)))
		if "doors" in res and tile_pos in res.doors:
			info.tags.append("🚪 Drzwi")
		if "entrance_zone" in res and tile_pos in res.entrance_zone:
			info.tags.append("🟢 Strefa Wejścia")
		if "exit_zone" in res and tile_pos in res.exit_zone:
			info.tags.append("🔴 Strefa Wyjścia")
		if "rooms" in res:
			for i in range(res.rooms.size()):
				var r: Rect2i = res.rooms[i]
				if r.has_point(tile_pos):
					info.tags.append("🏰 Pokój #%d (%dx%d)" % [i + 1, r.size.x, r.size.y])
					break
		if "clearings" in res:
			for i in range(res.clearings.size()):
				var cl: Dictionary = res.clearings[i]
				var c_center: Vector2i = cl.get("center", Vector2i.ZERO)
				var c_rad: int = cl.get("radius", 0)
				if Vector2(c_center).distance_to(Vector2(tile_pos)) <= float(c_rad):
					info.tags.append("🌲 Polana #%d (%s, r=%d)" % [i + 1, cl.get("type", "normal"), c_rad])
					break

	# Warstwy TileMapLayer
	if proc_level:
		var walls_l := proc_level.find_child("Walls", true, false) as TileMapLayer
		if walls_l and walls_l.get_cell_source_id(tile_pos) != -1:
			var ac: Vector2i = walls_l.get_cell_atlas_coords(tile_pos)
			info.walls_layer = "Atlas (%d, %d)" % [ac.x, ac.y]
		var floor_l := proc_level.find_child("Floor", true, false) as TileMapLayer
		if floor_l and floor_l.get_cell_source_id(tile_pos) != -1:
			var ac: Vector2i = floor_l.get_cell_atlas_coords(tile_pos)
			info.floor_layer = "Atlas (%d, %d)" % [ac.x, ac.y]
		var decor_l := proc_level.find_child("FloorDecor", true, false) as TileMapLayer
		if decor_l and decor_l.get_cell_source_id(tile_pos) != -1:
			var ac: Vector2i = decor_l.get_cell_atlas_coords(tile_pos)
			info.decor_layer = "Atlas (%d, %d)" % [ac.x, ac.y]
		var plat_l := proc_level.find_child("Platforms", true, false) as TileMapLayer
		if plat_l and plat_l.get_cell_source_id(tile_pos) != -1:
			var ac: Vector2i = plat_l.get_cell_atlas_coords(tile_pos)
			info.platforms_layer = "Atlas (%d, %d)" % [ac.x, ac.y]

	return info


func _update_tile_inspector_ui() -> void:
	var hover_info := _get_tile_info(_hovered_tile)
	var has_selection := _is_in_bounds(_selected_tile)
	var inspect_pos := _selected_tile if has_selection else _hovered_tile
	var active_info := _get_tile_info(inspect_pos)

	# 1. Floating HUD na ekranie
	if is_instance_valid(tile_hud_label):
		if hover_info.in_bounds:
			var tag_str: String = (" [" + hover_info.tags[0] + "]") if not hover_info.tags.is_empty() else ""
			tile_hud_label.text = "📍 [b]Kafelek:[/b] [color=#66ff88](%d, %d)[/color]\n📐 [b]Świat:[/b] (%d, %d) px\n🧱 [b]Typ:[/b] %s%s" % [
				hover_info.tile_pos.x, hover_info.tile_pos.y,
				int(hover_info.world_pos.x), int(hover_info.world_pos.y),
				hover_info.cell_name,
				tag_str
			]
		else:
			tile_hud_label.text = "📍 [b]Kursor poza mapą[/b]\n📐 Rozmiar: %dx%d" % [current_width, current_height]

	# 2. Inspektor w bocznym panelu UI
	if is_instance_valid(inspector_label):
		if not active_info.in_bounds:
			inspector_label.text = "[color=#888888]Najedź kursorem lub kliknij na kafelek...[/color]"
			return

		var mode_header := "[color=#ffd700][b]★ ZAZNACZONY KAFELEK[/b][/color]\n" if has_selection else "[color=#66ddff][b]👁 KURSOR NA MAPIE[/b][/color]\n"
		var tags_text := ""
		if not active_info.tags.is_empty():
			tags_text = "\n[b]Obiekty:[/b] " + ", ".join(active_info.tags)

		var layers_text := ""
		if not active_info.walls_layer.is_empty():
			layers_text += "\n[b]Warstwa Ścian:[/b] %s" % active_info.walls_layer
		if not active_info.floor_layer.is_empty():
			layers_text += "\n[b]Warstwa Podłogi:[/b] %s" % active_info.floor_layer
		if not active_info.decor_layer.is_empty():
			layers_text += "\n[b]Warstwa Dekoracji:[/b] %s" % active_info.decor_layer
		if not active_info.platforms_layer.is_empty():
			layers_text += "\n[b]Warstwa Platform:[/b] %s" % active_info.platforms_layer

		var relative_sel_text := ""
		if has_selection and hover_info.in_bounds and _hovered_tile != _selected_tile:
			var d_sel := Vector2(_selected_tile).distance_to(Vector2(_hovered_tile))
			var man_sel := absi(_hovered_tile.x - _selected_tile.x) + absi(_hovered_tile.y - _selected_tile.y)
			var dx: int = _hovered_tile.x - _selected_tile.x
			var dy: int = _hovered_tile.y - _selected_tile.y
			relative_sel_text = "\n[color=#ffeedd][b]Odległość do kursora:[/b] %.1f kratek (ΔX: %+d, ΔY: %+d, Manh: %d)[/color]" % [d_sel, dx, dy, man_sel]

		inspector_label.text = """%s[b]Pozycja kafelka:[/b] [color=#66ff88](%d, %d)[/color]
[b]Piksele w świecie:[/b] (%d, %d) px
[b]Typ komórki:[/b] %s%s%s
[b]Od Startu (1):[/b] %.1f (Manh: %d)
[b]Do Wyjścia (2):[/b] %.1f (Manh: %d)%s""" % [
			mode_header,
			active_info.tile_pos.x, active_info.tile_pos.y,
			int(active_info.world_pos.x), int(active_info.world_pos.y),
			active_info.cell_name,
			tags_text,
			layers_text,
			active_info.dist_entrance, active_info.manhattan_entrance,
			active_info.dist_exit, active_info.manhattan_exit,
			relative_sel_text
		]


func _on_tile_overlay_draw() -> void:
	if not _tile_overlay:
		return

	var is_highlight_enabled: bool = check_tile_highlight.button_pressed if check_tile_highlight else true
	if not is_highlight_enabled:
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11

	# 1. Hover Box (Ramka podświetlająca kafelek pod myszką)
	if _is_in_bounds(_hovered_tile):
		var hover_rect := Rect2(_hovered_tile.x * 16.0, _hovered_tile.y * 16.0, 16.0, 16.0)
		_tile_overlay.draw_rect(hover_rect, Color(0.0, 0.75, 1.0, 0.25), true)
		_tile_overlay.draw_rect(hover_rect, Color(0.0, 0.95, 1.0, 0.9), false, 1.5)

		var show_tooltip: bool = check_cursor_tooltip.button_pressed if check_cursor_tooltip else true
		if show_tooltip and font:
			var txt := "(%d, %d)" % [_hovered_tile.x, _hovered_tile.y]
			var txt_size := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var pad := Vector2(4, 2)
			var txt_pos := Vector2(_hovered_tile.x * 16.0 + 18.0, _hovered_tile.y * 16.0 + 13.0)
			var bg_rect := Rect2(txt_pos.x - pad.x, txt_pos.y - txt_size.y + pad.y - 1, txt_size.x + pad.x * 2, txt_size.y + pad.y * 2)
			_tile_overlay.draw_rect(bg_rect, Color(0.05, 0.08, 0.12, 0.85), true)
			_tile_overlay.draw_rect(bg_rect, Color(0.0, 0.8, 1.0, 0.6), false, 1.0)
			_tile_overlay.draw_string(font, txt_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# 2. Selected Box & Ruler Line (Zaznaczony kafelek i linia pomiaru odległości)
	if _is_in_bounds(_selected_tile):
		var sel_rect := Rect2(_selected_tile.x * 16.0, _selected_tile.y * 16.0, 16.0, 16.0)
		_tile_overlay.draw_rect(sel_rect, Color(1.0, 0.85, 0.0, 0.35), true)
		_tile_overlay.draw_rect(sel_rect, Color(1.0, 0.9, 0.1, 1.0), false, 2.0)

		if _is_in_bounds(_hovered_tile) and _hovered_tile != _selected_tile:
			var p_sel := Vector2(_selected_tile.x * 16.0 + 8.0, _selected_tile.y * 16.0 + 8.0)
			var p_hov := Vector2(_hovered_tile.x * 16.0 + 8.0, _hovered_tile.y * 16.0 + 8.0)
			_tile_overlay.draw_line(p_sel, p_hov, Color(1.0, 0.85, 0.2, 0.75), 1.5, true)

			if font:
				var dist := Vector2(_selected_tile).distance_to(Vector2(_hovered_tile))
				var dist_txt := "%.1f" % dist
				var mid_pos := (p_sel + p_hov) / 2.0 + Vector2(0, -6)
				var d_size := font.get_string_size(dist_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var d_bg := Rect2(mid_pos.x - 3, mid_pos.y - d_size.y + 1, d_size.x + 6, d_size.y + 3)
				_tile_overlay.draw_rect(d_bg, Color(0.1, 0.1, 0.05, 0.9), true)
				_tile_overlay.draw_string(font, mid_pos, dist_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.9, 0.3))


## Skrzynie mapy: z SpawnPlanner (chest_spawns) i z generatora obiektów (INTERACTIVE "chest").
func _chest_cells(res) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if "chest_spawns" in res:
		out.append_array(res.chest_spawns)
	if "objects" in res and res.objects != null:
		out.append_array(res.objects.cells_with_scene("chest"))
	return out
