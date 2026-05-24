extends Node

## GameManager — moduł QuizRPG
## Zarządza stanami gry RPG, scenami i zapisem.
## Dostępny przez: CoreManager.get_singleton("GameManager")

enum GameState { MENU, EXPLORING, QUIZ_COMBAT, QUIZ_PUZZLE, PAUSED, CUTSCENE }

signal state_changed(old_state: GameState, new_state: GameState)
signal scene_transition_started
signal scene_transition_finished
signal save_slots_changed

var current_state: GameState = GameState.MENU
var current_map_path: String = ""
var _transition_in_progress: bool = false
var total_play_time_seconds: float = 0.0

const SAVE_DIR := "user://quiz_rpg_saves"
const SLOT_CONFIG_PATH := "user://quiz_rpg_saves/slots.json"
const DEFAULT_SAVE_SLOT_COUNT := 3
const SAVE_PATH := "user://quiz_rpg_saves/slot_01.json"
const GAME_SCENE_PATH := "res://modules/quiz_rpg/scenes/game.tscn"
const LEGACY_WORLD_MAP_SCENE_PATH := "res://modules/quiz_rpg/scenes/maps/world_map.tscn"


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if current_state != GameState.MENU and not _transition_in_progress:
		total_play_time_seconds += delta


func change_state(new_state: GameState) -> void:
	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


func is_exploring() -> bool:
	return current_state == GameState.EXPLORING


func is_in_quiz() -> bool:
	return current_state in [GameState.QUIZ_COMBAT, GameState.QUIZ_PUZZLE]


func transition_to_scene(scene_path: String) -> void:
	if _transition_in_progress:
		return
	scene_path = _normalize_scene_path(scene_path)
	_transition_in_progress = true
	scene_transition_started.emit()
	var tween = create_tween()
	tween.tween_method(_set_fade, 0.0, 1.0, 0.3)
	await tween.finished
	var module_root := CoreManager.get_active_module()
	if module_root and module_root.has_method("open_scene"):
		module_root.call("open_scene", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
	current_map_path = scene_path
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_method(_set_fade, 1.0, 0.0, 0.3)
	await tween.finished
	_transition_in_progress = false
	scene_transition_finished.emit()


func _set_fade(value: float) -> void:
	var fade_rect = get_node_or_null("/root/HUD/FadeOverlay")
	if fade_rect:
		fade_rect.modulate.a = value

func save_game(slot_index: int = -1) -> bool:
	var save_manager := CoreManager.get_singleton("SaveManager")
	if save_manager and save_manager.has_method("save_game"):
		return bool(save_manager.call("save_game", slot_index))
	return false


func load_game(slot_index: int = -1) -> bool:
	var save_manager := CoreManager.get_singleton("SaveManager")
	if save_manager and save_manager.has_method("load_game"):
		return bool(save_manager.call("load_game", slot_index))
	return false


func has_any_save() -> bool:
	var save_manager := CoreManager.get_singleton("SaveManager")
	return bool(save_manager.call("has_any_save")) if save_manager and save_manager.has_method("has_any_save") else false


func get_slot_count() -> int:
	var save_manager := CoreManager.get_singleton("SaveManager")
	return int(save_manager.call("get_slot_count")) if save_manager and save_manager.has_method("get_slot_count") else DEFAULT_SAVE_SLOT_COUNT


func add_save_slot() -> int:
	var save_manager := CoreManager.get_singleton("SaveManager")
	if save_manager and save_manager.has_method("add_save_slot"):
		return int(save_manager.call("add_save_slot"))
	return -1


func delete_save_slot(slot_index: int) -> bool:
	var save_manager := CoreManager.get_singleton("SaveManager")
	return bool(save_manager.call("delete_save_slot", slot_index)) if save_manager and save_manager.has_method("delete_save_slot") else false


func get_save_slots_summary() -> Array[Dictionary]:
	var save_manager := CoreManager.get_singleton("SaveManager")
	if save_manager and save_manager.has_method("get_save_slots_summary"):
		var summaries: Array[Dictionary] = []
		var raw_summaries: Variant = save_manager.call("get_save_slots_summary")
		if raw_summaries is Array:
			for entry: Variant in raw_summaries:
				if entry is Dictionary:
					summaries.append((entry as Dictionary).duplicate(true))
		return summaries
	return []


func _find_latest_save_slot() -> int:
	var save_manager := CoreManager.get_singleton("SaveManager")
	return int(save_manager.call("find_latest_save_slot")) if save_manager and save_manager.has_method("find_latest_save_slot") else -1


func _load_slot_file(slot_index: int) -> Dictionary:
	var save_manager := CoreManager.get_singleton("SaveManager")
	var slot_data: Variant = save_manager.call("load_slot_file", slot_index) if save_manager and save_manager.has_method("load_slot_file") else {}
	if slot_data is Dictionary:
		return (slot_data as Dictionary).duplicate(true)
	return {}


func _build_slot_summary(slot_index: int, slot_data: Dictionary) -> Dictionary:
	if slot_data.is_empty():
		return {
			"slot_index": slot_index,
			"slot_name": "Slot %d" % (slot_index + 1),
			"exists": false,
			"title": "Pusty slot",
			"subtitle": "Brak zapisu",
			"detail": "",
			"time_text": "",
			"saved_text": "",
			"saved_at_unix": 0,
		}
	var player_stats: Dictionary = slot_data.get("player_stats", {})
	var player_name: String = str(player_stats.get("player_name", "Bohater"))
	var level: int = int(player_stats.get("level", 1))
	var map_name: String = _format_map_name(str(slot_data.get("current_map", "")))
	var play_time_seconds: int = int(slot_data.get("play_time_seconds", 0))
	var saved_at_unix: int = int(slot_data.get("saved_at_unix", 0))
	var play_time_text: String = _format_play_time(play_time_seconds)
	var saved_text: String = _format_saved_at(saved_at_unix)
	var total_correct: int = int(player_stats.get("total_correct", 0))
	return {
		"slot_index": slot_index,
		"slot_name": "Slot %d" % (slot_index + 1),
		"exists": true,
		"title": "%s  LV %d" % [player_name, level],
		"subtitle": map_name,
		"detail": "%s  |  %s  |  %d poprawnych" % [play_time_text, saved_text, total_correct],
		"time_text": play_time_text,
		"saved_text": saved_text,
		"saved_at_unix": saved_at_unix,
	}


func _format_map_name(scene_path: String) -> String:
	if scene_path == "":
		return "Nieznana lokacja"
	if scene_path == GAME_SCENE_PATH or scene_path == LEGACY_WORLD_MAP_SCENE_PATH:
		return "Kraina Wiedzy"
	var file_name: String = scene_path.get_file().get_basename().replace("_", " ")
	return file_name.capitalize()


func _format_play_time(play_time_seconds: int) -> String:
	var total_seconds: int = maxi(play_time_seconds, 0)
	var hours: int = int(total_seconds / 3600.0)
	var minutes: int = int((total_seconds % 3600) / 60.0)
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _format_saved_at(saved_at_unix: int) -> String:
	if saved_at_unix <= 0:
		return "brak daty"
	return Time.get_datetime_string_from_unix_time(saved_at_unix, true)


func new_game(slot_index: int = 0) -> void:
	var save_manager := CoreManager.get_singleton("SaveManager")
	if save_manager and save_manager.has_method("start_new_game"):
		save_manager.call("start_new_game", slot_index)
		return
	var ps := CoreManager.get_singleton("PlayerStats")
	var dm := CoreManager.get_singleton("DifficultyManager")
	if ps: ps.reset()
	QuizManager.reset()
	if dm: dm.reset()
	total_play_time_seconds = 0.0
	change_state(GameState.EXPLORING)
	transition_to_scene(GAME_SCENE_PATH)


func return_to_main_menu() -> void:
	change_state(GameState.MENU)
	transition_to_scene("res://modules/quiz_rpg/scenes/ui/main_menu.tscn")


func log_debug(message: Variant, category: String = "GENERAL") -> void:
	if OS.is_debug_build():
		print("[RPG][%s] %s" % [category.to_upper(), str(message)])


func _normalize_scene_path(scene_path: String) -> String:
	if scene_path == LEGACY_WORLD_MAP_SCENE_PATH:
		return GAME_SCENE_PATH
	return scene_path
