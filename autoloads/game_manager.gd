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


func _ready() -> void:
	_ensure_slot_config()
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

func save_game(slot_index: int = 0) -> bool:
	var ps  := CoreManager.get_singleton("PlayerStats")
	var dm  := CoreManager.get_singleton("DifficultyManager")
	var save_data = {
		"player_stats": ps.get_save_data()  if ps else {},
		"quiz_progress": QuizManager.get_save_data(),
		"difficulty": dm.get_save_data()    if dm else {},
		"current_map": current_map_path,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"saved_at_text": Time.get_datetime_string_from_system(false, true),
		"play_time_seconds": int(total_play_time_seconds),
	}
	var file = FileAccess.open(_get_slot_path(slot_index), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		save_slots_changed.emit()
		return true
	return false


func load_game(slot_index: int = -1) -> bool:
	if slot_index < 0:
		slot_index = _find_latest_save_slot()
	if slot_index < 0:
		return false
	var slot_data: Dictionary = _load_slot_file(slot_index)
	if slot_data.is_empty():
		return false
	var ps := CoreManager.get_singleton("PlayerStats")
	var dm := CoreManager.get_singleton("DifficultyManager")
	if ps:
		ps.load_save_data(slot_data.get("player_stats", {}))
	QuizManager.load_save_data(slot_data.get("quiz_progress", {}))
	if dm:
		dm.load_save_data(slot_data.get("difficulty", {}))
	total_play_time_seconds = float(slot_data.get("play_time_seconds", 0))
	if slot_data.has("current_map") and slot_data["current_map"] != "":
		transition_to_scene(slot_data["current_map"])
	return true


func has_any_save() -> bool:
	for slot_summary: Dictionary in get_save_slots_summary():
		if bool(slot_summary.get("exists", false)):
			return true
	return false


func get_slot_count() -> int:
	var config: Dictionary = _load_slot_config()
	return maxi(int(config.get("slot_count", DEFAULT_SAVE_SLOT_COUNT)), 1)


func add_save_slot() -> int:
	var slot_count: int = get_slot_count() + 1
	_save_slot_config({"slot_count": slot_count})
	save_slots_changed.emit()
	return slot_count - 1


func delete_save_slot(slot_index: int) -> bool:
	var slot_count: int = get_slot_count()
	if slot_count <= 1 or slot_index < 0 or slot_index >= slot_count:
		return false
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return false
	var removed_path: String = _get_slot_path(slot_index)
	if FileAccess.file_exists(removed_path):
		dir.remove(removed_path)
	for move_index: int in range(slot_index + 1, slot_count):
		var from_path: String = _get_slot_path(move_index)
		var to_path: String = _get_slot_path(move_index - 1)
		if FileAccess.file_exists(from_path):
			dir.rename(from_path, to_path)
	_save_slot_config({"slot_count": slot_count - 1})
	save_slots_changed.emit()
	return true


func get_save_slots_summary() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_index: int in range(get_slot_count()):
		var slot_data: Dictionary = _load_slot_file(slot_index)
		summaries.append(_build_slot_summary(slot_index, slot_data))
	return summaries


func _find_latest_save_slot() -> int:
	var latest_slot_index: int = -1
	var latest_saved_at: int = -1
	for slot_summary: Dictionary in get_save_slots_summary():
		if not bool(slot_summary.get("exists", false)):
			continue
		var saved_at: int = int(slot_summary.get("saved_at_unix", 0))
		if saved_at > latest_saved_at:
			latest_saved_at = saved_at
			latest_slot_index = int(slot_summary.get("slot_index", -1))
	return latest_slot_index


func _load_slot_file(slot_index: int) -> Dictionary:
	var slot_path: String = _get_slot_path(slot_index)
	if not FileAccess.file_exists(slot_path):
		return {}
	var file = FileAccess.open(slot_path, FileAccess.READ)
	if not file:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	return json.data if json.data is Dictionary else {}


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
	var file_name: String = scene_path.get_file().get_basename().replace("_", " ")
	return file_name.capitalize()


func _format_play_time(play_time_seconds: int) -> String:
	var total_seconds: int = maxi(play_time_seconds, 0)
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _format_saved_at(saved_at_unix: int) -> String:
	if saved_at_unix <= 0:
		return "brak daty"
	return Time.get_datetime_string_from_unix_time(saved_at_unix, true)


func _get_slot_path(slot_index: int) -> String:
	return "%s/slot_%02d.json" % [SAVE_DIR, slot_index + 1]


func _ensure_slot_config() -> void:
	_ensure_save_dir()
	if not FileAccess.file_exists(SLOT_CONFIG_PATH):
		_save_slot_config({"slot_count": DEFAULT_SAVE_SLOT_COUNT})


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func _load_slot_config() -> Dictionary:
	_ensure_slot_config()
	var file = FileAccess.open(SLOT_CONFIG_PATH, FileAccess.READ)
	if not file:
		return {"slot_count": DEFAULT_SAVE_SLOT_COUNT}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {"slot_count": DEFAULT_SAVE_SLOT_COUNT}
	file.close()
	return json.data if json.data is Dictionary else {"slot_count": DEFAULT_SAVE_SLOT_COUNT}


func _save_slot_config(config: Dictionary) -> void:
	_ensure_save_dir()
	var file = FileAccess.open(SLOT_CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()


func new_game() -> void:
	var ps := CoreManager.get_singleton("PlayerStats")
	var dm := CoreManager.get_singleton("DifficultyManager")
	if ps: ps.reset()
	QuizManager.reset()
	if dm: dm.reset()
	total_play_time_seconds = 0.0
	change_state(GameState.EXPLORING)
	transition_to_scene("res://modules/quiz_rpg/scenes/maps/world_map.tscn")


func return_to_main_menu() -> void:
	change_state(GameState.MENU)
	transition_to_scene("res://modules/quiz_rpg/scenes/ui/main_menu.tscn")


func log_debug(message: Variant, category: String = "GENERAL") -> void:
	if OS.is_debug_build():
		print("[RPG][%s] %s" % [category.to_upper(), str(message)])
