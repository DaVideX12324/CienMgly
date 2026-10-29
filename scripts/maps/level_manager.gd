extends Node2D

const PartyFollowers = preload("../player/party_followers.gd")

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

signal set_spawn(spawn: Vector2)

static var INITIAL_LEVEL_PATH: String = QuizRpgPaths.path("scenes/maps/tutorial_area.tscn")
const DEFAULT_SPAWN_NAME := "Spawn"
const LoadingScreenScene = preload("../../scenes/ui/loading_screen.tscn")
const LoadingScreenScript = preload("../ui/loading_screen.gd")
## Nazwa lokacji na ekranie ładowania (duży napis nad paskiem) wg nazwy pliku sceny mapy; brak = bez
## napisu (ProceduralLevel ma własną: location_name / typ poziomu).
const LOCATION_NAMES := {
	"tutorial_area": "Starożytne Ruiny",
	"cave": "Jaskinia",
	"cave_secret": "Ukryta grota",
	"cave_relic": "Zapomniana krypta",
	"sewer": "Ścieki",
	"town": "Miasto",
}

## Ochrona startu: przy punkcie pojawienia się stoi azyl (QuizRpgSafeZone) — chyba że poziom ma już własny. Samej
## nietykalności na starcie nie ma (decyzja usera 2026-10-14): generator nie daje wrogom nawigacji w pokoju wejścia /
## wyjścia, pierwszym za wejściem i strefach portali, więc nikt tam nie dojdzie.
const DEFAULT_SAFE_ZONE_PX := Vector2(192, 192)  # 12×12 kratek (mapy ręczne bez własnego azylu)

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


func _progress_ps() -> Node:
	var core := get_node_or_null("/root/CoreManager")
	return core.call("get_singleton", "PlayerStats") as Node if core else null


func load_level_direct(level_path: String, spawn_name: String = DEFAULT_SPAWN_NAME) -> void:
	level_path = QuizRpgPaths.localize(level_path)  # ścieżki z eksportów scen / zapisów w formie hosta
	if level_path == "":
		level_path = INITIAL_LEVEL_PATH
	if spawn_name == "":
		spawn_name = DEFAULT_SPAWN_NAME

	var overlay := _show_loading_screen(level_path)
	# Gracz czeka zamrożony, aż mapa (i przy ProceduralLevel spawny) będzie gotowa; sterowanie dopiero po zaniknięciu
	# ekranu ładowania i wynurzeniu się drużyny (_unblock_input_after_fade).
	var player := _get_player()
	var player_mode := player.process_mode if player else Node.PROCESS_MODE_INHERIT
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		_set_input_blocked(player, true)

	_clear_transient_nodes()
	if is_instance_valid(current_level):
		current_level.queue_free()
		await get_tree().process_frame

	var packed := await _load_level_scene(QuizRpgPaths.level_scene(level_path), overlay)
	if packed == null:
		push_warning("[QuizRpgLevelManager] Cannot load level: %s" % level_path)
		if is_instance_valid(player):
			player.process_mode = player_mode
			_set_input_blocked(player, false)
		_close_loading_screen()
		return

	current_level = packed.instantiate()
	# Mapa spoza LOCATION_NAMES: nazwa z jej własnego location_name (jeśli ma), zanim ProceduralLevel pokaże swój ekran.
	if is_instance_valid(_loading_screen) and _loading_screen.location.is_empty() and "location_name" in current_level:
		_loading_screen.location = QuizRpgI18n.t(str(current_level.get("location_name")), str(current_level.get("location_name")))
	# ProceduralLevel zastępuje ten ekran własnym (z postępem generowania) — niech pokaże to samo tło.
	if is_instance_valid(_loading_screen) and _loading_screen.background != null and "loading_background" in current_level:
		current_level.loading_background = _loading_screen.background
	# Pełna ścieżka (z argumentem mapy, np. sekretny pokój) przed _ready — klucz seeda i stanu poziomu.
	if "level_path" in current_level:
		current_level.set("level_path", level_path)
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
	var spawn_pos := _place_player_at_spawn(spawn_name)
	_sync_party_followers(true)
	QuizRpgPortalFade.fade_in(get_tree())
	_setup_start_safety(spawn_pos)
	_play_level_music(level_path, current_level)
	QuizRpgProgressLog.map_entered(_progress_ps(), level_path)
	_close_loading_screen()
	await _unblock_input_after_fade(player)


## Oddaje sterowanie, gdy nie ma już ekranu ładowania (też ekranu ProceduralLevel) i drużyna się wynurzyła.
func _unblock_input_after_fade(player: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while is_inside_tree() and (not get_tree().get_nodes_in_group(LoadingScreenScript.GROUP).is_empty()
			or Time.get_ticks_msec() - t0 < int(QuizRpgPortalFade.FADE_IN_TIME * 1000.0)):
		await get_tree().process_frame
	if is_instance_valid(player):
		_set_input_blocked(player, false)


func _set_input_blocked(player: Node, blocked: bool) -> void:
	if "input_blocked" in player:
		player.set("input_blocked", blocked)


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
	var level_key := QuizRpgPaths.level_scene(level_path).get_file().get_basename()
	var loc_name: String = str(LOCATION_NAMES.get(level_key, ""))
	_loading_screen.location = QuizRpgI18n.t("map." + level_key + ".name", loc_name) if loc_name != "" else ""
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


func _play_level_music(_level_path: String, level_node: Node) -> void:
	var audio_service: Node = get_node_or_null("/root/AudioService")
	if audio_service == null or not audio_service.has_method("play_music"):
		return
	# Utwór mapy: pole music_track mapy (ręczne — Inspektor; generowane — companion-JSON "music"); brak = world_map.
	var own := str(level_node.get("music_track")) if level_node != null and "music_track" in level_node else ""
	audio_service.call("play_music", own if not own.is_empty() else "world_map")


## Towarzysze drużyny za graczem (PartyFollowers); snap = ustawieni na graczu (nowa mapa / spawn).
## Zmiana składu (PlayerStats.party_changed) przebudowuje ich na bieżąco.
func _sync_party_followers(snap: bool) -> void:
	var player := _get_player() as CharacterBody2D
	var ps := _player_stats()
	if player == null or ps == null:
		return
	PartyFollowers.sync(player, ps)
	if snap:
		PartyFollowers.snap_to_leader(player)
	if ps.has_signal("party_changed") and not ps.party_changed.is_connected(_on_party_changed):
		ps.party_changed.connect(_on_party_changed)


func _on_party_changed() -> void:
	_sync_party_followers(false)


func _player_stats() -> Node:
	var cm := get_node_or_null("/root/CoreManager")
	if cm and cm.has_method("get_singleton"):
		var s: Variant = cm.call("get_singleton", "PlayerStats")
		if s is Node:
			return s
	return get_node_or_null("/root/PlayerStats")


func _place_player_at_spawn(spawn_name: String) -> Vector2:
	var spawn_node := _pick_spawn_marker(current_level, spawn_name)
	var spawn_pos := spawn_node.global_position if spawn_node else Vector2.ZERO
	var player := _get_player()
	if player:
		player.global_position = spawn_pos
	set_spawn.emit(spawn_pos)
	return spawn_pos


## Azyl przy punkcie pojawienia się (ProceduralLevel: pokój z tym punktem, przycięty) i chwila ochrony gracza.
func _setup_start_safety(spawn_pos: Vector2) -> void:
	if not is_instance_valid(current_level):
		return
	var has_zone := false
	for z in get_tree().get_nodes_in_group(QuizRpgSafeZone.GROUP):
		if current_level.is_ancestor_of(z):
			has_zone = true
			break
	if not has_zone:
		var rect := Rect2()
		if current_level.has_method("start_safe_zone_rect"):
			rect = current_level.start_safe_zone_rect(spawn_pos)
		if not rect.has_area():
			rect = Rect2(spawn_pos - DEFAULT_SAFE_ZONE_PX * 0.5, DEFAULT_SAFE_ZONE_PX)
		var zone := QuizRpgSafeZone.new()
		zone.name = "StartSafeZone"
		zone.size = rect.size
		current_level.add_child(zone)
		zone.global_position = rect.get_center()


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
