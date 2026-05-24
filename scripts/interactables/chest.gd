extends AnimatedSprite2D
class_name Chest

@export var lock_id: String = "dungeon_1"
@export var unique_id: String = ""
@export var chest_item_id: String = "potion"
@export_range(1, 99, 1) var chest_item_count: int = 1

var is_locked: bool = true
var opened: bool = false
var was_already_opened: bool = false
var _player_in_interaction_range: bool = false


func _ready() -> void:
	add_to_group("chests")
	add_to_group("interactable")
	if unique_id.is_empty():
		unique_id = _generate_unique_id()
	call_deferred("_check_if_opened")


func _unhandled_input(event: InputEvent) -> void:
	if opened or not _player_in_interaction_range:
		return
	if event.is_action_pressed("interact"):
		unlock()
		get_viewport().set_input_as_handled()


func _check_if_opened() -> void:
	var level_path := _get_current_level_path()
	if level_path.is_empty():
		await get_tree().process_frame
		_check_if_opened()
		return

	var level_state_manager := _get_level_state_manager()
	if level_state_manager and level_state_manager.is_chest_opened(level_path, unique_id):
		was_already_opened = true
		opened = true
		is_locked = false
		play("open")


func _generate_unique_id() -> String:
	var id_parts: Array[String] = ["chest"]
	if name != "Chest" and not name.begins_with("@"):
		id_parts.append(name.replace("@", "").strip_edges().to_lower())
	var pos_x := int(global_position.x / 10.0) * 10
	var pos_y := int(global_position.y / 10.0) * 10
	id_parts.append(str(pos_x))
	id_parts.append(str(pos_y))
	if not lock_id.is_empty() and lock_id != "dungeon_1":
		id_parts.append(lock_id)
	return "_".join(id_parts)


func unlock() -> void:
	if opened:
		return

	is_locked = false
	play("open")

	var level_path := _get_current_level_path()
	if level_path != "":
		var level_state_manager := _get_level_state_manager()
		if level_state_manager:
			level_state_manager.mark_chest_opened(level_path, unique_id)


func _on_animation_finished() -> void:
	if animation != "open":
		return
	if not was_already_opened:
		drop_item()
	opened = true


func drop_item() -> void:
	var player_stats := _get_module_singleton("PlayerStats")
	if player_stats and player_stats.has_method("add_item"):
		player_stats.call("add_item", chest_item_id, chest_item_count)

	var loot_manager := _get_module_singleton("LootManager")
	if loot_manager and loot_manager.has_method("show_loot_popup"):
		var item_name := chest_item_id
		var inventory_service := _get_module_singleton("InventoryService")
		if inventory_service and inventory_service.has_method("get_item"):
			var item_data := inventory_service.call("get_item", chest_item_id) as QuizRpgItemData
			if item_data != null:
				item_name = item_data.display_name
		loot_manager.call("show_loot_popup", {
			"found": true,
			"title": "Zawartosc skrzyni",
			"message": "%s x%d trafia do ekwipunku." % [item_name, chest_item_count],
			"detail": "Nacisnij E albo Enter, aby kontynuowac.",
		})


func _get_level_state_manager() -> Node:
	return _get_module_singleton("LevelStateManager")


func _get_module_singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var singleton: Variant = core_manager.call("get_singleton", singleton_name)
		if singleton is Node:
			return singleton
	return get_node_or_null("/root/%s" % singleton_name)


func _get_level_manager() -> Node:
	var game_root := get_tree().current_scene
	if game_root:
		var level_manager := game_root.find_child("level_manager", true, false)
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


func _get_current_level_path() -> String:
	var level_manager := _get_level_manager()
	if level_manager:
		return str(level_manager.get("current_level_path"))
	return ""


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_interaction_range = true


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_interaction_range = false
