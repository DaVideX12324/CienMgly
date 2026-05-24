extends Node2D

signal set_spawn(spawn: Vector2)

const INITIAL_LEVEL_PATH := "res://modules/quiz_rpg/scenes/maps/tutorial_area.tscn"
const DEFAULT_SPAWN_NAME := "Spawn"

var current_level: Node = null
var current_level_path: String = ""
var current_spawn_name: String = DEFAULT_SPAWN_NAME


func _ready() -> void:
	await get_tree().process_frame
	var save_manager := _get_save_manager()
	if save_manager and save_manager.has_method("has_pending_level_load") and bool(save_manager.call("has_pending_level_load")) and save_manager.has_method("consume_pending_level_load"):
		var pending: Dictionary = save_manager.call("consume_pending_level_load")
		var pending_level := str(pending.get("level_path", INITIAL_LEVEL_PATH))
		var pending_spawn := str(pending.get("spawn_name", DEFAULT_SPAWN_NAME))
		load_level_direct(pending_level, pending_spawn)
		return
	load_level_direct(INITIAL_LEVEL_PATH, DEFAULT_SPAWN_NAME)


func change_level(level_path: String, spawn_name: String = DEFAULT_SPAWN_NAME) -> void:
	load_level_direct(level_path, spawn_name)


func load_level_direct(level_path: String, spawn_name: String = DEFAULT_SPAWN_NAME) -> void:
	if level_path == "":
		level_path = INITIAL_LEVEL_PATH
	if spawn_name == "":
		spawn_name = DEFAULT_SPAWN_NAME

	_clear_transient_nodes()
	if is_instance_valid(current_level):
		current_level.queue_free()
		await get_tree().process_frame

	var packed := load(level_path) as PackedScene
	if packed == null:
		push_warning("[QuizRpgLevelManager] Cannot load level: %s" % level_path)
		return

	current_level = packed.instantiate()
	add_child(current_level)
	current_level_path = level_path
	current_spawn_name = spawn_name

	await get_tree().process_frame
	_place_player_at_spawn(spawn_name)


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
