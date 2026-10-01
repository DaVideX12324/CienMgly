extends Node2D

signal set_spawn(spawn: Vector2)

const INITIAL_LEVEL_PATH := "res://modules/quiz_rpg/scenes/maps/tutorial_area.tscn"
const DEFAULT_SPAWN_NAME := "Spawn"
const LoadingScreenScene = preload("res://modules/quiz_rpg/scenes/ui/loading_screen.tscn")
## Nazwa lokacji na ekranie ładowania (duży napis nad paskiem) wg nazwy pliku sceny mapy; brak = bez
## napisu (ProceduralLevel ma własną: location_name / typ poziomu).
const LOCATION_NAMES := {
	"tutorial_area": "Starożytne Ruiny",
}

var current_level: Node = null
var current_level_path: String = ""
var current_spawn_name: String = DEFAULT_SPAWN_NAME
var _loading_screen: Node = null


func _ready() -> void:
	var level_path := INITIAL_LEVEL_PATH
	var spawn_name := DEFAULT_SPAWN_NAME
	var save_manager := _get_save_manager()
	if save_manager and save_manager.has_method("has_pending_level_load") and bool(save_manager.call("has_pending_level_load")) and save_manager.has_method("consume_pending_level_load"):
		var pending: Dictionary = save_manager.call("consume_pending_level_load")
		level_path = str(pending.get("level_path", INITIAL_LEVEL_PATH))
		spawn_name = str(pending.get("spawn_name", DEFAULT_SPAWN_NAME))
	# Ekran ładowania już w pierwszej klatce sceny gry — inaczej przed wczytaniem mapy widać pustą scenę.
	_show_loading_screen(level_path)
	await get_tree().process_frame
	await load_level_direct(level_path, spawn_name)


func change_level(level_path: String, spawn_name: String = DEFAULT_SPAWN_NAME) -> void:
	await load_level_direct(level_path, spawn_name)


func load_level_direct(level_path: String, spawn_name: String = DEFAULT_SPAWN_NAME) -> void:
	if level_path == "":
		level_path = INITIAL_LEVEL_PATH
	if spawn_name == "":
		spawn_name = DEFAULT_SPAWN_NAME

	var overlay := _show_loading_screen(level_path)
	# Gracz czeka zamrożony, aż mapa (i przy ProceduralLevel spawny) będzie gotowa.
	var player := _get_player()
	var player_mode := player.process_mode if player else Node.PROCESS_MODE_INHERIT
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED

	_clear_transient_nodes()
	if is_instance_valid(current_level):
		current_level.queue_free()
		await get_tree().process_frame

	var packed := await _load_level_scene(level_path, overlay)
	if packed == null:
		push_warning("[QuizRpgLevelManager] Cannot load level: %s" % level_path)
		if is_instance_valid(player):
			player.process_mode = player_mode
		_close_loading_screen()
		return

	current_level = packed.instantiate()
	add_child(current_level)
	current_level_path = level_path
	current_spawn_name = spawn_name

	# Poziom generowany w tle (ProceduralLevel) pokazuje własny ekran z postępem generowania — od razu
	# go zastępuje (bez zanikania, żeby nie mieszały się dwa ekrany).
	if current_level.get("is_generating") == true:
		_close_loading_screen(true)
	await get_tree().process_frame
	if current_level.get("is_generating") == true:
		await current_level.generation_finished
	if is_instance_valid(player):
		player.process_mode = player_mode
	_place_player_at_spawn(spawn_name)
	_play_level_music(level_path, current_level)
	_close_loading_screen()


## Scena mapy wczytywana w tle (ResourceLoader.load_threaded_request) — pasek ekranu ładowania idzie
## za postępem, okno nie zamarza. Gdy wczytywanie w tle się nie uda, zwykłe load().
func _load_level_scene(level_path: String, overlay: Node) -> PackedScene:
	if ResourceLoader.load_threaded_request(level_path, "PackedScene") != OK:
		return load(level_path) as PackedScene
	if is_instance_valid(overlay):
		overlay.track_resource_load(level_path)
	while ResourceLoader.load_threaded_get_status(level_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(level_path) != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(level_path) as PackedScene


## Ekran ładowania nad sceną gry (jeden naraz). Tło: grafika z folderu o nazwie pliku sceny mapy
## (loading_screens/<nazwa>/, np. tutorial_area); brak grafik = ciemne tło. Napis: LOCATION_NAMES.
func _show_loading_screen(level_path: String) -> Node:
	if is_instance_valid(_loading_screen) and not _loading_screen.is_queued_for_deletion():
		return _loading_screen
	_loading_screen = LoadingScreenScene.instantiate()
	_loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	var level_key := level_path.get_file().get_basename()
	_loading_screen.location = LOCATION_NAMES.get(level_key, "")
	_loading_screen.set_background_for(level_key)
	add_child(_loading_screen)
	return _loading_screen


func _close_loading_screen(immediate: bool = false) -> void:
	if not is_instance_valid(_loading_screen):
		return
	if immediate:
		_loading_screen.queue_free()
	else:
		_loading_screen.close()
	_loading_screen = null


func _play_level_music(level_path: String, level_node: Node) -> void:
	var audio_service: Node = get_node_or_null("/root/AudioService")
	if audio_service == null or not audio_service.has_method("play_music"):
		return
	var track := "world_map"
	var p := level_path.to_lower()
	if p.contains("tutorial"):
		track = "tutorial"
	elif p.contains("desert"):
		track = "desert_town"
	elif p.contains("cave"):
		track = "cave_entrance"
	elif p.contains("castle"):
		track = "ancient_ruins"
	elif p.contains("fairy"):
		track = "fairy_forest"
	elif p.contains("forge"):
		track = "forge"
	elif p.contains("garden"):
		track = "garden"
	elif p.contains("hideout") or p.contains("sewer"):
		track = "tunnels"
	elif level_node:
		for prop in ["biome", "theme"]:
			if prop in level_node and str(level_node.get(prop)) != "":
				track = str(level_node.get(prop)).to_snake_case()
				break
	audio_service.call("play_music", track)


func _place_player_at_spawn(spawn_name: String) -> void:
	var spawn_node := _pick_spawn_marker(current_level, spawn_name)
	var spawn_pos := spawn_node.global_position if spawn_node else Vector2.ZERO
	var player := _get_player()
	if player:
		player.global_position = spawn_pos
	set_spawn.emit(spawn_pos)


func _pick_spawn_marker(level: Node, spawn_name: String) -> Node2D:
	if level == null:
		return null
	var markers := _collect_markers(level)
	for marker: Node2D in markers:
		if marker.name == spawn_name:
			return marker
	var classic := level.get_node_or_null("Spawn")
	if classic is Node2D:
		return classic
	return markers[0] if not markers.is_empty() else null


func _collect_markers(level: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var spawns := level.get_node_or_null("Spawns")
	if spawns:
		for child in spawns.get_children():
			if child is Marker2D:
				result.append(child)

	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			if child is Marker2D and not result.has(child):
				result.append(child)
	return result


func _clear_transient_nodes() -> void:
	for group_name in ["projectile", "loot"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()


func _get_player() -> Node2D:
	var game_root := get_parent()
	if game_root:
		var player := game_root.get_node_or_null("Player")
		if player is Node2D:
			return player
	var scene := get_tree().current_scene
	if scene:
		var player := scene.find_child("Player", true, false)
		if player is Node2D:
			return player
	return null


func _get_save_manager() -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var save_manager: Variant = core_manager.call("get_singleton", "SaveManager")
		if save_manager is Node:
			return save_manager
	return get_node_or_null("/root/SaveManager")
