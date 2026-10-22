class_name QuizRpgGroundItem
extends Area2D

## Przedmiot leżący na ziemi (zawartość niszy out — NicheContentPlanner): ikona przedmiotu z lekkim unoszeniem i błyskiem,
## klawisz interakcji (gracz, grupa "interactable") dodaje go do ekwipunku. Podniesiony nie wraca — stan w
## LevelStateManager (picked_items, po unique_id). item_id / count ustawia poziom (ProceduralLevel, tabela łupu nisz).

@export var item_id: String = "potion":
	set(v):
		item_id = v
		if is_node_ready():
			_apply_icon()
@export_range(1, 99, 1) var count: int = 1
@export var unique_id: String = ""

var _picked := false

@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ground_items")
	_apply_icon()
	var tw := create_tween().set_loops()
	tw.tween_property(_icon, "position:y", _icon.position.y - 1.5, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_icon, "position:y", _icon.position.y, 0.8).set_trans(Tween.TRANS_SINE)
	call_deferred("_check_if_picked")


func _apply_icon() -> void:
	var data := _item_data()
	if _icon != null and data != null:
		_icon.texture = data.icon


func _item_data() -> QuizRpgItemData:
	var inv := _singleton("InventoryService")
	if inv and inv.has_method("get_item"):
		return inv.call("get_item", item_id) as QuizRpgItemData
	return null


func _check_if_picked() -> void:
	var lsm := _singleton("LevelStateManager")
	var level_path := _level_path()
	if level_path.is_empty():
		await get_tree().process_frame
		if is_instance_valid(self) and not is_queued_for_deletion():
			_check_if_picked()
		return
	if lsm and lsm.is_item_picked(level_path, unique_id):
		queue_free()


func can_interact() -> bool:
	return not _picked


func interaction_prompt_text() -> String:
	return QuizRpgI18n.t("prompt.pick_up", "Podnieś")


func interaction_prompt_offset() -> Vector2:
	return Vector2(0, -16)


func interact(_player: Node2D = null) -> void:
	if _picked:
		return
	_picked = true
	var ps := _singleton("PlayerStats")
	if ps and ps.has_method("add_item"):
		ps.call("add_item", item_id, count)
	var level_path := _level_path()
	var lsm := _singleton("LevelStateManager")
	if lsm and level_path != "":
		lsm.mark_item_picked(level_path, unique_id)
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("coin")
	var loot := _singleton("LootManager")
	if loot and loot.has_method("show_loot_toast"):
		var data := _item_data()
		loot.call("show_loot_toast", {"found": true, "items": [{
			"item_id": item_id, "count": count,
			"item_name": data.localized_name() if data != null else item_id,
			"icon": data.icon if data != null else null,
		}]})
	queue_free()


func _singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var s: Variant = core_manager.call("get_singleton", singleton_name)
		if s is Node:
			return s
	return get_node_or_null("/root/%s" % singleton_name)


func _level_path() -> String:
	var game_root := get_tree().current_scene
	if game_root:
		var lm := game_root.find_child("level_manager", true, false)
		if lm:
			return str(lm.get("current_level_path"))
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_active_module"):
		var module_root: Variant = core_manager.call("get_active_module")
		if module_root is Node:
			var lm := (module_root as Node).find_child("level_manager", true, false)
			if lm:
				return str(lm.get("current_level_path"))
	return ""
