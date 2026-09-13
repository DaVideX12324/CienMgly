extends Node2D

## Zaawansowany Eksplorator Generatora Map Proceduralnych dla modulu Quiz RPG.
## Umozliwia testowanie seedow, wymiarow (od 50x50 do 500x500 z asymetria),
## przelaczanie typow (Jaskinia, Las, Zamek), kamere swobodna, skoki i spacer graczem.

const ProceduralLevelScript = preload("res://modules/quiz_rpg/scripts/maps/procedural_level.gd")
const MapGeneratorBaseScript = preload("res://modules/quiz_rpg/scripts/generation/map_generator_base.gd")

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
@onready var btn_generate: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/BtnGenerate

@onready var btn_fit_all: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera1/BtnFitAll
@onready var btn_center: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera1/BtnCenter
@onready var btn_entrance: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera2/BtnEntrance
@onready var btn_exit: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/HBoxCamera2/BtnExit
@onready var btn_player: Button = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/BtnPlayer

@onready var info_label: RichTextLabel = $CanvasLayer/Panel/ScrollContainer/MarginContainer/VBoxContainer/InfoLabel

# Stan
var current_type: int = 2 # 2: CAVE_DUNGEON, 0: FOREST, 1: DUNGEON
var current_seed: int = 119
var current_width: int = 100
var current_height: int = 100
var is_player_mode: bool = false
var player_instance: Node2D = null

# Ostatnie dane generacji
var last_entrance_pos: Vector2i = Vector2i.ZERO
var last_exit_pos: Vector2i = Vector2i.ZERO

# Drag kamery
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _cam_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_ensure_nodes()
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

	# 6. Kamera
	btn_fit_all.pressed.connect(fit_to_screen)
	btn_center.pressed.connect(jump_to_center)
	btn_entrance.pressed.connect(jump_to_entrance)
	btn_exit.pressed.connect(jump_to_exit)
	btn_player.pressed.connect(_toggle_player_mode)

	# 7. Zwijanie HUD
	btn_hide_hud.pressed.connect(_toggle_hud)
	btn_show_hud.pressed.connect(_toggle_hud)


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
			KEY_F2:
				opt_type.select(2) # Zamek
				_on_type_selected(2)
			KEY_F3:
				opt_type.select(0) # Jaskinia
				_on_type_selected(0)

	# Zoom kółkiem myszy
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
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
	_ensure_nodes()
	if is_instance_valid(player_instance):
		player_instance.queue_free()
		player_instance = null
		is_player_mode = false
		if btn_player:
			btn_player.text = "🏃 Spacer Graczem (P)"

	if not level_container:
		return

	for child in level_container.get_children():
		child.queue_free()

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
	level_container.add_child(proc_level)

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
			res.chest_spawns.size() if "chest_spawns" in res else 0,
			extra_stats
		]


func _toggle_player_mode() -> void:
	if is_player_mode:
		if is_instance_valid(player_instance):
			player_instance.queue_free()
			player_instance = null
		is_player_mode = false
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

		player_instance = p_packed.instantiate() as Node2D
		player_instance.global_position = spawn_px
		level_container.add_child(player_instance)

		is_player_mode = true
		btn_player.text = "🕊️ Wolna Kamera (P)"
		camera.zoom = Vector2(2.0, 2.0)
		camera.position = spawn_px
