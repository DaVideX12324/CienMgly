extends Node

signal save_completed(slot_index: int)
signal load_completed(slot_index: int)
signal save_failed(message: String)
signal save_slots_changed

const SAVE_VERSION := 1
const SAVE_DIR := "user://quiz_rpg_saves"
const SLOT_CONFIG_PATH := "user://quiz_rpg_saves/slots.json"
const DEFAULT_SAVE_SLOT_COUNT := 3
const MAX_SAVE_SLOT_COUNT := 20
const GAME_SCENE_PATH := "res://modules/quiz_rpg/scenes/game.tscn"
const INITIAL_LEVEL_PATH := "res://modules/quiz_rpg/scenes/maps/tutorial_area.tscn"
const LEGACY_WORLD_MAP_SCENE_PATH := "res://modules/quiz_rpg/scenes/maps/world_map.tscn"

var current_save_slot: int = -1
var is_loading: bool = false
var _has_pending_level_load: bool = false
var _pending_level_path: String = INITIAL_LEVEL_PATH
var _pending_spawn_name: String = "Spawn"


func _ready() -> void:
	_ensure_slot_config()


func save_game(slot_index: int = -1) -> bool:
	if slot_index < 0:
		slot_index = current_save_slot
	if slot_index < 0:
		save_failed.emit("Najpierw wybierz slot zapisu.")
		return false
	current_save_slot = slot_index

	var save_data: Dictionary = _build_save_data(slot_index)
	var file := FileAccess.open(_get_slot_path(slot_index), FileAccess.WRITE)
	if file == null:
		var message := "Nie mozna otworzyc pliku zapisu."
		save_failed.emit(message)
		push_warning("[QuizRpgSaveManager] %s" % message)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	save_completed.emit(slot_index)
	save_slots_changed.emit()
	return true


func load_game(slot_index: int = -1) -> bool:
	if slot_index < 0:
		slot_index = find_latest_save_slot()
	if slot_index < 0:
		save_failed.emit("Brak zapisu do wczytania.")
		return false

	var slot_data: Dictionary = load_slot_file(slot_index)
	if slot_data.is_empty():
		save_failed.emit("Pusty albo uszkodzony zapis.")
		return false

	is_loading = true
	current_save_slot = slot_index
	_restore_global_state(slot_data)
	_has_pending_level_load = true
	_pending_level_path = str(slot_data.get("current_level", slot_data.get("level_path", INITIAL_LEVEL_PATH)))
	_pending_spawn_name = str(slot_data.get("spawn_point", "Spawn"))

	var gm := _get_game_manager()
	if gm:
		gm.set("total_play_time_seconds", float(slot_data.get("play_time_seconds", 0)))
		var scene_path: String = _normalize_scene_path(str(slot_data.get("current_scene", slot_data.get("current_map", GAME_SCENE_PATH))))
		if scene_path != "":
			gm.call("change_state", 1)
			gm.call("transition_to_scene", scene_path)

	load_completed.emit(slot_index)
	is_loading = false
	return true


func start_new_game(slot_index: int = 0) -> void:
	current_save_slot = -1
	_has_pending_level_load = false
	_pending_level_path = INITIAL_LEVEL_PATH
	_pending_spawn_name = "Spawn"
	_reset_global_state()
	var gm := _get_game_manager()
	if gm:
		gm.set("total_play_time_seconds", 0.0)
		gm.call("change_state", 1)
		gm.call("transition_to_scene", GAME_SCENE_PATH)


func has_pending_level_load() -> bool:
	return _has_pending_level_load


func consume_pending_level_load() -> Dictionary:
	var pending := {
		"level_path": _pending_level_path,
		"spawn_name": _pending_spawn_name,
	}
	_has_pending_level_load = false
	_pending_level_path = INITIAL_LEVEL_PATH
	_pending_spawn_name = "Spawn"
	return pending


func save_exists(slot_index: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot_index))


func has_any_save() -> bool:
	for slot_summary: Dictionary in get_save_slots_summary():
		if bool(slot_summary.get("exists", false)):
			return true
	return false


func get_slot_count() -> int:
	var config: Dictionary = _load_slot_config()
	return clampi(int(config.get("slot_count", DEFAULT_SAVE_SLOT_COUNT)), 1, MAX_SAVE_SLOT_COUNT)


func add_save_slot() -> int:
	var slot_count: int = mini(get_slot_count() + 1, MAX_SAVE_SLOT_COUNT)
	_save_slot_config({"slot_count": slot_count})
	save_slots_changed.emit()
	return slot_count - 1


func delete_save_slot(slot_index: int) -> bool:
	var slot_count: int = get_slot_count()
	if slot_count <= 1 or slot_index < 0 or slot_index >= slot_count:
		return false
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	var removed_path: String = _get_slot_path(slot_index)
	if FileAccess.file_exists(removed_path):
		dir.remove(_get_slot_file_name(slot_index))
	for move_index: int in range(slot_index + 1, slot_count):
		var from_path: String = _get_slot_path(move_index)
		if FileAccess.file_exists(from_path):
			dir.rename(_get_slot_file_name(move_index), _get_slot_file_name(move_index - 1))
	_save_slot_config({"slot_count": slot_count - 1})
	if current_save_slot >= 0:
		current_save_slot = clampi(current_save_slot, 0, get_slot_count() - 1)
	save_slots_changed.emit()
	return true


func get_save_slots_summary() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_index: int in range(get_slot_count()):
		var slot_data: Dictionary = load_slot_file(slot_index)
		summaries.append(_build_slot_summary(slot_index, slot_data))
	return summaries


func get_save_metadata(slot_index: int) -> Dictionary:
	var slot_data: Dictionary = load_slot_file(slot_index)
	if slot_data.is_empty():
		return {}
	return _build_slot_summary(slot_index, slot_data)


func find_latest_save_slot() -> int:
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


func load_slot_file(slot_index: int) -> Dictionary:
	var slot_path: String = _get_slot_path(slot_index)
	if not FileAccess.file_exists(slot_path):
		return {}
	var file := FileAccess.open(slot_path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {}
	if json.data is Dictionary:
		return (json.data as Dictionary).duplicate(true)
	return {}


func _build_save_data(slot_index: int) -> Dictionary:
	var gm := _get_game_manager()
	var ps := _get_singleton("PlayerStats")
	var dm := _get_singleton("DifficultyManager")
	var level_state_manager := _get_singleton("LevelStateManager")
	var level_manager := _get_level_manager()
	var current_scene: String = GAME_SCENE_PATH
	var current_level: String = INITIAL_LEVEL_PATH
	var spawn_point: String = "Spawn"
	var play_time_seconds: int = 0
	if gm:
		current_scene = _normalize_scene_path(str(gm.get("current_map_path")))
		if current_scene == "":
			current_scene = GAME_SCENE_PATH
		play_time_seconds = int(gm.get("total_play_time_seconds"))
	if level_manager:
		current_level = str(level_manager.get("current_level_path"))
		if current_level == "":
			current_level = INITIAL_LEVEL_PATH
		spawn_point = str(level_manager.get("current_spawn_name"))
		if spawn_point == "":
			spawn_point = "Spawn"

	return {
		"version": SAVE_VERSION,
		"slot": slot_index,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"saved_at_text": Time.get_datetime_string_from_system(false, true),
		"play_time_seconds": play_time_seconds,
		"current_scene": current_scene,
		"current_level": current_level,
		"spawn_point": spawn_point,
		"player": ps.get_save_data() if ps and ps.has_method("get_save_data") else {},
		"player_stats": ps.get_save_data() if ps and ps.has_method("get_save_data") else {},
		"quiz_progress": QuizManager.get_save_data(),
		"difficulty": dm.get_save_data() if dm and dm.has_method("get_save_data") else {},
		"level_states": level_state_manager.serialize() if level_state_manager and level_state_manager.has_method("serialize") else {},
		"inventory": _serialize_inventory_placeholder(ps),
		"equipment": _serialize_equipment_placeholder(ps),
		"quests": {},
		"currency": {},
		"world": {},
	}


func _restore_global_state(save_data: Dictionary) -> void:
	var ps := _get_singleton("PlayerStats")
	var dm := _get_singleton("DifficultyManager")
	var level_state_manager := _get_singleton("LevelStateManager")
	if level_state_manager:
		if save_data.has("level_states") and level_state_manager.has_method("deserialize"):
			level_state_manager.deserialize(save_data.get("level_states", {}))
		elif level_state_manager.has_method("reset"):
			level_state_manager.reset()
	if ps and ps.has_method("load_save_data"):
		ps.load_save_data(save_data.get("player_stats", save_data.get("player", {})))
	QuizManager.load_save_data(save_data.get("quiz_progress", {}))
	if dm and dm.has_method("load_save_data"):
		dm.load_save_data(save_data.get("difficulty", {}))


func _reset_global_state() -> void:
	var ps := _get_singleton("PlayerStats")
	var dm := _get_singleton("DifficultyManager")
	var level_state_manager := _get_singleton("LevelStateManager")
	if ps and ps.has_method("reset"):
		ps.reset()
	QuizManager.reset()
	if dm and dm.has_method("reset"):
		dm.reset()
	if level_state_manager and level_state_manager.has_method("reset"):
		level_state_manager.reset()


func _serialize_inventory_placeholder(ps: Node) -> Dictionary:
	if ps == null:
		return {}
	var inventory_value: Variant = ps.get("inventory")
	return {
		"items": inventory_value.duplicate(true) if inventory_value is Array else [],
	}


func _serialize_equipment_placeholder(ps: Node) -> Dictionary:
	if ps == null:
		return {}
	var party_value: Variant = ps.get("party")
	if not (party_value is Array):
		return {}
	var party: Array = party_value as Array
	if party.is_empty() or not (party[0] is Dictionary):
		return {}
	return (party[0] as Dictionary).get("equipment", {}).duplicate(true)


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
	var player_stats: Dictionary = slot_data.get("player_stats", slot_data.get("player", {}))
	var player_name: String = str(player_stats.get("player_name", "Bohater"))
	var level: int = int(player_stats.get("level", 1))
	var map_name: String = _format_map_name(str(slot_data.get("current_level", slot_data.get("current_scene", slot_data.get("current_map", "")))))
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
	scene_path = _normalize_scene_path(scene_path)
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


func _get_slot_path(slot_index: int) -> String:
	return "%s/%s" % [SAVE_DIR, _get_slot_file_name(slot_index)]


func _get_slot_file_name(slot_index: int) -> String:
	return "slot_%02d.json" % (slot_index + 1)


func _ensure_slot_config() -> void:
	_ensure_save_dir()
	if not FileAccess.file_exists(SLOT_CONFIG_PATH):
		_save_slot_config({"slot_count": DEFAULT_SAVE_SLOT_COUNT})


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func _load_slot_config() -> Dictionary:
	_ensure_save_dir()
	if not FileAccess.file_exists(SLOT_CONFIG_PATH):
		return {"slot_count": DEFAULT_SAVE_SLOT_COUNT}
	var file := FileAccess.open(SLOT_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {"slot_count": DEFAULT_SAVE_SLOT_COUNT}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"slot_count": DEFAULT_SAVE_SLOT_COUNT}
	if json.data is Dictionary:
		return json.data as Dictionary
	return {"slot_count": DEFAULT_SAVE_SLOT_COUNT}


func _save_slot_config(config: Dictionary) -> void:
	_ensure_save_dir()
	var file := FileAccess.open(SLOT_CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()


func _get_game_manager() -> Node:
	return _get_singleton("GameManager")


func _get_level_manager() -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_active_module"):
		var module_root: Variant = core_manager.call("get_active_module")
		if module_root is Node:
			var level_manager := (module_root as Node).find_child("level_manager", true, false)
			if level_manager is Node:
				return level_manager
	var scene := get_tree().current_scene
	if scene:
		var level_manager := scene.find_child("level_manager", true, false)
		if level_manager is Node:
			return level_manager
	return null


func _get_singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var singleton: Variant = core_manager.call("get_singleton", singleton_name)
		if singleton is Node:
			return singleton
	return get_node_or_null("/root/%s" % singleton_name)


func _normalize_scene_path(scene_path: String) -> String:
	if scene_path == LEGACY_WORLD_MAP_SCENE_PATH:
		return GAME_SCENE_PATH
	return scene_path
