extends Node

const HOST_ITEMS_DIR := "res://modules/quiz_rpg/resources/items"
const STANDALONE_ITEMS_DIR := "res://resources/items"

var _items_by_id: Dictionary = {}
var _display_name_to_id: Dictionary = {}


func _ready() -> void:
	_load_item_database()


func get_item(item_ref: String) -> QuizRpgItemData:
	var item_id: String = resolve_item_id(item_ref)
	if item_id == "":
		return null
	var item_value: Variant = _items_by_id.get(item_id, null)
	return item_value as QuizRpgItemData


func has_item(item_ref: String) -> bool:
	return resolve_item_id(item_ref) != ""


func resolve_item_id(item_ref: String) -> String:
	if item_ref == "":
		return ""
	if _items_by_id.has(item_ref):
		return item_ref
	var normalized_name: String = item_ref.strip_edges().to_lower()
	if _display_name_to_id.has(normalized_name):
		return str(_display_name_to_id[normalized_name])
	return ""


func get_menu_entries(raw_inventory: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var normalized_inventory: Array[Dictionary] = normalize_inventory(raw_inventory)
	for entry_value: Variant in normalized_inventory:
		var entry: Dictionary = entry_value
		var item_data: QuizRpgItemData = get_item(str(entry.get("item_id", "")))
		if item_data == null:
			continue
		entries.append({
			"item_id": item_data.item_id,
			"name": item_data.display_name,
			"description": item_data.description,
			"count": int(entry.get("count", 0)),
			"heal_amount": item_data.heal_amount,
			"sp_restore": item_data.sp_restore,
			"tp_restore": item_data.tp_restore,
			"usable_in_menu": item_data.usable_in_menu,
			"usable_in_combat": item_data.usable_in_combat,
			"effect_summary": item_data.get_effect_summary(),
		})
	return entries


func normalize_inventory(raw_inventory: Array) -> Array[Dictionary]:
	var normalized_inventory: Array[Dictionary] = []
	for entry_value: Variant in raw_inventory:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var item_id: String = resolve_item_id(str(entry.get("item_id", entry.get("name", ""))))
		if item_id == "":
			continue
		var count: int = maxi(0, int(entry.get("count", 0)))
		if count <= 0:
			continue
		_append_or_stack(normalized_inventory, item_id, count)
	return normalized_inventory


func add_item_to_inventory(raw_inventory: Array, item_ref: String, count: int = 1) -> Array[Dictionary]:
	var item_id: String = resolve_item_id(item_ref)
	var normalized_inventory: Array[Dictionary] = normalize_inventory(raw_inventory)
	if item_id == "" or count <= 0:
		return normalized_inventory
	_append_or_stack(normalized_inventory, item_id, count)
	return normalized_inventory


func consume_item_from_inventory(raw_inventory: Array, item_ref: String, count: int = 1) -> Dictionary:
	var item_id: String = resolve_item_id(item_ref)
	var normalized_inventory: Array[Dictionary] = normalize_inventory(raw_inventory)
	if item_id == "" or count <= 0:
		return {"success": false, "inventory": normalized_inventory}

	for index: int in range(normalized_inventory.size()):
		var entry: Dictionary = normalized_inventory[index]
		if str(entry.get("item_id", "")) != item_id:
			continue
		var current_count: int = int(entry.get("count", 0))
		if current_count < count:
			return {"success": false, "inventory": normalized_inventory}
		current_count -= count
		if current_count <= 0:
			normalized_inventory.remove_at(index)
		else:
			entry["count"] = current_count
			normalized_inventory[index] = entry
		return {"success": true, "inventory": normalized_inventory}

	return {"success": false, "inventory": normalized_inventory}


func use_item(user: Node, raw_inventory: Array, item_ref: String) -> Dictionary:
	var item_data: QuizRpgItemData = get_item(item_ref)
	var normalized_inventory: Array[Dictionary] = normalize_inventory(raw_inventory)
	if item_data == null:
		return {
			"success": false,
			"inventory": normalized_inventory,
			"message": "Nieznany przedmiot.",
		}

	if item_data.consumable:
		var consume_result: Dictionary = consume_item_from_inventory(normalized_inventory, item_data.item_id, 1)
		if not bool(consume_result.get("success", false)):
			return {
				"success": false,
				"inventory": normalized_inventory,
				"message": "Brak przedmiotu.",
			}
		normalized_inventory = consume_result.get("inventory", normalized_inventory)

	var heal_amount: int = item_data.heal_amount
	if heal_amount > 0 and user and user.has_method("heal"):
		user.call("heal", heal_amount)

	return {
		"success": true,
		"inventory": normalized_inventory,
		"item_id": item_data.item_id,
		"name": item_data.display_name,
		"description": item_data.description,
		"heal_amount": item_data.heal_amount,
		"sp_restore": item_data.sp_restore,
		"tp_restore": item_data.tp_restore,
		"usable_in_menu": item_data.usable_in_menu,
		"usable_in_combat": item_data.usable_in_combat,
		"message": _build_use_message(item_data),
	}


func _build_use_message(item_data: QuizRpgItemData) -> String:
	var summary: String = item_data.get_effect_summary()
	if summary == "":
		return "Uzyto %s." % item_data.display_name
	return "%s: %s" % [item_data.display_name, summary]


func _load_item_database() -> void:
	_items_by_id.clear()
	_display_name_to_id.clear()
	for dir_path: String in [HOST_ITEMS_DIR, STANDALONE_ITEMS_DIR]:
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		_load_item_directory(dir_path, dir)
		if not _items_by_id.is_empty():
			return


func _load_item_directory(dir_path: String, dir: DirAccess) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			var resource_path: String = "%s/%s" % [dir_path, file_name]
			var item_resource: Resource = load(resource_path)
			if item_resource is QuizRpgItemData:
				_register_item(item_resource as QuizRpgItemData)
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_item(item_data: QuizRpgItemData) -> void:
	if item_data.item_id == "":
		return
	_items_by_id[item_data.item_id] = item_data
	_display_name_to_id[item_data.display_name.strip_edges().to_lower()] = item_data.item_id


func _append_or_stack(inventory: Array[Dictionary], item_id: String, count: int) -> void:
	for index: int in range(inventory.size()):
		var entry: Dictionary = inventory[index]
		if str(entry.get("item_id", "")) != item_id:
			continue
		entry["count"] = int(entry.get("count", 0)) + count
		inventory[index] = entry
		return
	inventory.append({
		"item_id": item_id,
		"count": count,
	})
