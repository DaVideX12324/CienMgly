extends Node2D

const NEXT_LEVEL_PATH := "res://modules/quiz_rpg/scenes/maps/world_map.tscn"
const NEXT_SPAWN_NAME := "Spawn"

var _transitioning: bool = false


func _ready() -> void:
	var next_level_area := get_node_or_null("enter_next_level")
	if next_level_area is Area2D and not next_level_area.body_entered.is_connected(_on_enter_next_level_body_entered):
		next_level_area.body_entered.connect(_on_enter_next_level_body_entered)


func _on_enter_next_level_body_entered(body: Node2D) -> void:
	if _transitioning:
		return
	if not (body.is_in_group("player") or body.name == "Player"):
		return
	var level_manager := _get_level_manager()
	if level_manager == null or not level_manager.has_method("change_level"):
		push_warning("[TutorialArea] Missing level manager.")
		return
	_transitioning = true
	await level_manager.call("change_level", NEXT_LEVEL_PATH, NEXT_SPAWN_NAME)


func _get_level_manager() -> Node:
	var scene := get_tree().current_scene
	if scene:
		var level_manager := scene.find_child("level_manager", true, false)
		if level_manager is Node:
			return level_manager
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_active_module"):
		var module_root: Variant = core_manager.call("get_active_module")
		if module_root is Node:
			var level_manager := (module_root as Node).find_child("level_manager", true, false)
			if level_manager is Node:
				return level_manager
	return null
