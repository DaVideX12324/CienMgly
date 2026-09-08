extends Node2D

## Interaktywne narzedzie podgladu i testowania generatora map.
## Pozwala na latanie kamera, zoom, regeneracje pod Spacja oraz testowanie postacia gracza.

const ProceduralLevelScript = preload("res://modules/quiz_rpg/scripts/maps/procedural_level.gd")
const MapGeneratorBaseScript = preload("res://modules/quiz_rpg/scripts/generation/map_generator_base.gd")

@onready var camera: Camera2D = $Camera2D
@onready var level_container: Node2D = $LevelContainer
@onready var hud: CanvasLayer = $CanvasLayer

# UI Nodes
@onready var info_label: RichTextLabel = $CanvasLayer/Panel/MarginContainer/VBoxContainer/InfoLabel
@onready var btn_generate: Button = $CanvasLayer/Panel/MarginContainer/VBoxContainer/HBoxButtons/BtnGenerate
@onready var btn_type_forest: Button = $CanvasLayer/Panel/MarginContainer/VBoxContainer/HBoxTypes/BtnForest
@onready var btn_type_dungeon: Button = $CanvasLayer/Panel/MarginContainer/VBoxContainer/HBoxTypes/BtnDungeon
@onready var opt_size: OptionButton = $CanvasLayer/Panel/MarginContainer/VBoxContainer/HBoxSize/OptSize
@onready var btn_toggle_player: Button = $CanvasLayer/Panel/MarginContainer/VBoxContainer/BtnPlayer

var current_level_type: int = 0 # 0: FOREST, 1: DUNGEON
var current_seed: int = 12345
var current_size: int = 60
var is_player_mode: bool = false
var player_instance: Node2D = null

# Drag kamery
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _cam_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_setup_ui()
	_generate_current_map()


func _setup_ui() -> void:
	btn_generate.pressed.connect(_on_btn_generate_pressed)
	btn_type_forest.pressed.connect(func(): _set_type(0))
	btn_type_dungeon.pressed.connect(func(): _set_type(1))
	btn_toggle_player.pressed.connect(_toggle_player_mode)
	
	opt_size.clear()
	opt_size.add_item("Maly (40x40)", 40)
	opt_size.add_item("Sredni (60x60)", 60)
	opt_size.add_item("Duzy (80x80)", 80)
	opt_size.select(1)
	opt_size.item_selected.connect(_on_size_selected)


func _unhandled_input(event: InputEvent) -> void:
	# Skroty klawiszowe
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_generate_new_random_map()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1:
			_set_type(0)
		elif event.keycode == KEY_F2:
			_set_type(1)
		elif event.keycode == KEY_P:
			_toggle_player_mode()
			
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
	# Przesuwanie kamery klawiszami (gdy nie w trybie gracza)
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
			camera.position += move.normalized() * (500.0 * delta / camera.zoom.x)
	elif is_instance_valid(player_instance):
		camera.position = player_instance.global_position


func _zoom_camera(factor: float) -> void:
	var new_zoom: float = clampf(camera.zoom.x * factor, 0.2, 3.5)
	camera.zoom = Vector2(new_zoom, new_zoom)


func _set_type(type: int) -> void:
	current_level_type = type
	_generate_current_map()


func _on_size_selected(index: int) -> void:
	current_size = opt_size.get_item_id(index)
	_generate_current_map()


func _on_btn_generate_pressed() -> void:
	_generate_new_random_map()


func _generate_new_random_map() -> void:
	current_seed = int(randi() % 1000000)
	_generate_current_map()


func _generate_current_map() -> void:
	# Czyszczenie poprzedniego poziomu
	if is_instance_valid(player_instance):
		player_instance.queue_free()
		player_instance = null
		is_player_mode = false
		btn_toggle_player.text = "🏃 Tryb Gracza (P)"

	for child in level_container.get_children():
		child.queue_free()
		
	var t_start := Time.get_ticks_msec()
	
	# Tworzenie poziomu proceduralnego
	var proc_level: Node2D = ProceduralLevelScript.new()
	proc_level.set("level_type", current_level_type)
	proc_level.set("map_seed", current_seed)
	proc_level.set("map_width", current_size)
	proc_level.set("map_height", current_size)
	level_container.add_child(proc_level)
	
	var t_gen: int = Time.get_ticks_msec() - t_start
	
	var res: Variant = proc_level.get("last_result")
	if res:
		var spawn_p: Vector2i = res.player_spawn
		var spawn_px := Vector2(spawn_p.x * 16.0 + 8.0, spawn_p.y * 16.0 + 8.0)
		camera.position = spawn_px
		
		var type_name := "Las (Open World)" if current_level_type == 0 else "Zamek (Wnetrze)"
		var rooms_or_clearings: int = res.clearings.size() if current_level_type == 0 else res.rooms.size()
		var rooms_label := "Polany" if current_level_type == 0 else "Pokoje"
		
		info_label.text = """[b]Typ:[/b] %s
[b]Seed:[/b] %d
[b]Rozmiar:[/b] %dx%d
[b]Czas:[/b] %d ms
[b]%s:[/b] %d
[b]Wrogowie:[/b] %d
[b]Skrzynie:[/b] %d""" % [
			type_name,
			current_seed,
			current_size,
			current_size,
			t_gen,
			rooms_label,
			rooms_or_clearings,
			res.enemy_spawns.size(),
			res.chest_spawns.size()
		]


func _toggle_player_mode() -> void:
	if is_player_mode:
		if is_instance_valid(player_instance):
			player_instance.queue_free()
			player_instance = null
		is_player_mode = false
		btn_toggle_player.text = "🏃 Tryb Gracza (P)"
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
			
		var spawn_marker := proc_level.find_child("Spawn", true, false) as Marker2D
		var spawn_pos := spawn_marker.global_position if spawn_marker else Vector2.ZERO
		
		player_instance = p_packed.instantiate() as Node2D
		player_instance.global_position = spawn_pos
		level_container.add_child(player_instance)
		
		is_player_mode = true
		btn_toggle_player.text = "🕊️ Tryb Wolnej Kamery (P)"
		camera.zoom = Vector2(2.0, 2.0)
		camera.position = spawn_pos
