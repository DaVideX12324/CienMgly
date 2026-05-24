extends Node

## PlayerStats — moduł QuizRPG
## Przechowuje statystyki gracza: HP, XP, poziom, punkty, nagrody.
## Dostępny przez: CoreManager.get_singleton("PlayerStats")

signal hp_changed(new_hp: int, max_hp: int)
signal xp_changed(new_xp: int, xp_to_next: int)
signal level_up(new_level: int)
signal points_changed(new_points: int)
signal reward_earned(reward_name: String)
signal inventory_changed()
signal party_changed()

const BASE_HP          := 100
const HP_PER_LEVEL     := 20
const BASE_XP_TO_LEVEL := 100
const XP_GROWTH        := 1.5
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "shield", "head", "body", "accessory"]
const EQUIPMENT_LABELS := {
	"weapon": "Bron",
	"shield": "Tarcza",
	"head": "Glowa",
	"body": "Cialo",
	"accessory": "Akcesorium",
}

var player_name: String    = "Bohater"
var level: int             = 1
var xp: int                = 0
var hp: int                = BASE_HP
var max_hp: int            = BASE_HP
var points: int            = 0
var streak: int            = 0
var best_streak: int       = 0
var total_correct: int     = 0
var total_wrong: int       = 0
var rewards: Array[String] = []
var rng_bonus: float       = 0.0
var skills: Array[Dictionary] = [
	{
		"name": "Leczenie",
		"description": "Przywroc czesc HP po poprawnym rozwiazaniu quizu.",
		"sp_cost": 20,
		"effect": "heal",
		"heal_ratio_correct": 0.30,
		"heal_ratio_wrong": 0.10,
	},
	{
		"name": "Mocny Atak",
		"description": "Szansa na ciezsze trafienie kosztem TP.",
		"tp_cost": 25,
		"effect": "attack",
		"damage_multiplier": 1.5,
	},
]
var inventory: Array[Dictionary] = [
	{
		"item_id": "potion",
		"count": 2,
	},
	{
		"item_id": "ether",
		"count": 1,
	},
	{
		"item_id": "training_sword",
		"count": 1,
	},
	{
		"item_id": "wooden_shield",
		"count": 1,
	},
	{
		"item_id": "cloth_cap",
		"count": 1,
	},
	{
		"item_id": "adventurer_tunic",
		"count": 1,
	},
	{
		"item_id": "lucky_charm",
		"count": 1,
	},
]
var party: Array[Dictionary] = []


func _ready() -> void:
	_recalculate_max_hp()
	_normalize_inventory()
	_ensure_party_defaults()
	_sync_primary_party_member()


func xp_to_next_level() -> int:
	return int(BASE_XP_TO_LEVEL * pow(XP_GROWTH, level - 1))


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		_recalculate_max_hp()
		hp = max_hp
		level_up.emit(level)
	xp_changed.emit(xp, xp_to_next_level())


func add_points(amount: int) -> void:
	points += amount
	points_changed.emit(points)


func on_correct_answer() -> void:
	total_correct += 1
	streak += 1
	if streak > best_streak:
		best_streak = streak
	rng_bonus = clampf(rng_bonus + 0.05 + (streak * 0.02), 0.0, 0.5)
	add_points(10 + streak * 5)
	add_xp(15 + streak * 3)
	_check_rewards()


func on_wrong_answer() -> void:
	total_wrong += 1
	streak = 0
	rng_bonus = maxf(rng_bonus - 0.1, 0.0)


func roll_with_bonus(base_chance: float) -> bool:
	return randf() < clampf(base_chance + rng_bonus, 0.0, 0.95)


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	_sync_primary_party_member()
	party_changed.emit()


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)
	_sync_primary_party_member()
	party_changed.emit()


func is_alive() -> bool:
	return hp > 0


func _recalculate_max_hp() -> void:
	max_hp = BASE_HP + (level - 1) * HP_PER_LEVEL


func _check_rewards() -> void:
	var new_rewards: Array[String] = []
	if total_correct >= 10  and not "Początkujący Uczeń" in rewards: new_rewards.append("Początkujący Uczeń")
	if total_correct >= 50  and not "Pilny Student"       in rewards: new_rewards.append("Pilny Student")
	if total_correct >= 100 and not "Mistrz Wiedzy"       in rewards: new_rewards.append("Mistrz Wiedzy")
	if best_streak   >= 5   and not "Seria 5"             in rewards: new_rewards.append("Seria 5")
	if best_streak   >= 10  and not "Seria 10"            in rewards: new_rewards.append("Seria 10")
	if best_streak   >= 20  and not "Nieomylny"           in rewards: new_rewards.append("Nieomylny")
	if level         >= 5   and not "Poziom 5"            in rewards: new_rewards.append("Poziom 5")
	if level         >= 10  and not "Poziom 10"           in rewards: new_rewards.append("Poziom 10")
	for r in new_rewards:
		rewards.append(r)
		reward_earned.emit(r)


func get_save_data() -> Dictionary:
	return {
		"player_name": player_name, "level": level, "xp": xp,
		"hp": hp, "max_hp": max_hp, "points": points,
		"streak": streak, "best_streak": best_streak,
		"total_correct": total_correct, "total_wrong": total_wrong,
		"rewards": rewards.duplicate(), "rng_bonus": rng_bonus,
		"skills": skills.duplicate(true), "inventory": inventory.duplicate(true),
		"party": party.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	player_name   = data.get("player_name", "Bohater")
	level         = data.get("level", 1)
	xp            = data.get("xp", 0)
	hp            = data.get("hp", BASE_HP)
	max_hp        = data.get("max_hp", BASE_HP)
	points        = data.get("points", 0)
	streak        = data.get("streak", 0)
	best_streak   = data.get("best_streak", 0)
	total_correct = data.get("total_correct", 0)
	total_wrong   = data.get("total_wrong", 0)
	rewards.assign(data.get("rewards", []))
	rng_bonus     = data.get("rng_bonus", 0.0)
	skills = data.get("skills", skills).duplicate(true)
	inventory = data.get("inventory", inventory).duplicate(true)
	party = data.get("party", party).duplicate(true)
	_normalize_inventory()
	_ensure_party_defaults()
	_sync_primary_party_member()


func reset() -> void:
	player_name = "Bohater" ; level = 1 ; xp = 0
	_recalculate_max_hp()
	hp = max_hp ; points = 0 ; streak = 0
	best_streak = 0 ; total_correct = 0 ; total_wrong = 0
	rewards.clear() ; rng_bonus = 0.0
	inventory = [
		{"item_id": "potion", "count": 2},
		{"item_id": "ether", "count": 1},
		{"item_id": "training_sword", "count": 1},
		{"item_id": "wooden_shield", "count": 1},
		{"item_id": "cloth_cap", "count": 1},
		{"item_id": "adventurer_tunic", "count": 1},
		{"item_id": "lucky_charm", "count": 1},
	]
	party.clear()
	_normalize_inventory()
	_ensure_party_defaults()
	_sync_primary_party_member()


func get_inventory_entries() -> Array[Dictionary]:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service and inventory_service.has_method("get_menu_entries"):
		return inventory_service.call("get_menu_entries", inventory)
	return []


func get_party_members() -> Array[Dictionary]:
	_sync_primary_party_member()
	return party.duplicate(true)


func get_party_member(index: int) -> Dictionary:
	_sync_primary_party_member()
	if index < 0 or index >= party.size():
		return {}
	return party[index].duplicate(true)


func add_item(item_ref: String, count: int = 1, _description: String = "") -> void:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service and inventory_service.has_method("add_item_to_inventory"):
		inventory = inventory_service.call("add_item_to_inventory", inventory, item_ref, count)
		inventory_changed.emit()


func consume_item(item_ref: String, count: int = 1) -> bool:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("consume_item_from_inventory"):
		return false
	var result: Dictionary = inventory_service.call("consume_item_from_inventory", inventory, item_ref, count)
	if not bool(result.get("success", false)):
		return false
	inventory = result.get("inventory", inventory)
	inventory_changed.emit()
	return true


func use_item(item_ref: String) -> Dictionary:
	return use_item_on_member(item_ref, 0)


func use_item_on_member(item_ref: String, member_index: int) -> Dictionary:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("use_item"):
		return {"success": false, "message": "InventoryService niedostepny."}
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size():
		return {"success": false, "message": "Nieprawidlowy cel."}
	var item_data: QuizRpgItemData = inventory_service.call("get_item", item_ref)
	if item_data == null:
		return {"success": false, "message": "Nieznany przedmiot."}
	var consume_result: Dictionary = inventory_service.call("consume_item_from_inventory", inventory, item_ref, 1)
	if not bool(consume_result.get("success", false)):
		return {"success": false, "message": "Brak przedmiotu."}
	inventory = consume_result.get("inventory", inventory)
	var member: Dictionary = party[member_index]
	if item_data.heal_amount > 0:
		member["hp"] = mini(int(member.get("hp", 0)) + item_data.heal_amount, int(member.get("max_hp", 1)))
	if item_data.sp_restore > 0:
		member["sp"] = mini(int(member.get("sp", 0)) + item_data.sp_restore, int(member.get("max_sp", 1)))
	if item_data.tp_restore > 0:
		member["tp"] = mini(int(member.get("tp", 0)) + item_data.tp_restore, int(member.get("max_tp", 1)))
	party[member_index] = member
	if member_index == 0:
		hp = int(member.get("hp", hp))
		max_hp = int(member.get("max_hp", max_hp))
		hp_changed.emit(hp, max_hp)
	inventory_changed.emit()
	party_changed.emit()
	var result: Dictionary = {
		"success": true,
		"inventory": inventory.duplicate(true),
		"item_id": item_data.item_id,
		"name": item_data.display_name,
		"description": item_data.description,
		"heal_amount": item_data.heal_amount,
		"sp_restore": item_data.sp_restore,
		"tp_restore": item_data.tp_restore,
		"usable_in_menu": item_data.usable_in_menu,
		"usable_in_combat": item_data.usable_in_combat,
		"message": "%s: %s" % [item_data.display_name, item_data.get_effect_summary()] if item_data.get_effect_summary() != "" else "Uzyto %s." % item_data.display_name,
	}
	if bool(result.get("success", false)):
		_sync_primary_party_member()
	return result


func _normalize_inventory() -> void:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service and inventory_service.has_method("normalize_inventory"):
		inventory = inventory_service.call("normalize_inventory", inventory)


func get_items_by_category(category: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = get_inventory_entries()
	var filtered: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if str(entry.get("category", "item")) == category:
			filtered.append(entry)
	return filtered


func get_equipment_slots() -> Array[String]:
	return EQUIPMENT_SLOTS.duplicate()


func get_equipment_label(slot_name: String) -> String:
	return str(EQUIPMENT_LABELS.get(slot_name, slot_name.capitalize()))


func get_member_total_atk(member_index: int) -> int:
	if member_index < 0 or member_index >= party.size():
		return 0
	var member: Dictionary = party[member_index]
	var total_atk: int = int(member.get("base_atk", 0))
	for slot_name: String in EQUIPMENT_SLOTS:
		total_atk += int(_get_equipped_stat_bonus(member, slot_name, "atk_bonus"))
	return total_atk


func get_member_total_def(member_index: int) -> int:
	if member_index < 0 or member_index >= party.size():
		return 0
	var member: Dictionary = party[member_index]
	var total_def: int = int(member.get("base_def", 0))
	for slot_name: String in EQUIPMENT_SLOTS:
		total_def += int(_get_equipped_stat_bonus(member, slot_name, "def_bonus"))
	return total_def


func get_equippable_entries_for_slot(member_index: int, slot_name: String) -> Array[Dictionary]:
	var inventory_entries: Array[Dictionary] = get_inventory_entries()
	var options: Array[Dictionary] = []
	for entry: Dictionary in inventory_entries:
		if str(entry.get("equip_slot", "")) == slot_name:
			options.append(entry)
	if member_index >= 0 and member_index < party.size():
		var member: Dictionary = party[member_index]
		var equipment: Dictionary = member.get("equipment", {})
		var equipped_item_id: String = str(equipment.get(slot_name, ""))
		if equipped_item_id != "":
			var inventory_service: Node = _get_inventory_service()
			if inventory_service and inventory_service.has_method("get_item"):
				var item_data: QuizRpgItemData = inventory_service.call("get_item", equipped_item_id)
				if item_data:
					options.append({
						"item_id": item_data.item_id,
						"name": item_data.display_name,
						"description": item_data.description,
						"count": 1,
						"category": item_data.category,
						"equip_slot": item_data.equip_slot,
						"atk_bonus": item_data.atk_bonus,
						"def_bonus": item_data.def_bonus,
						"equipped": true,
					})
	var empty_entry: Dictionary = {
		"item_id": "",
		"name": "(puste)",
		"description": "Zdejmij wyposazenie z tego slotu.",
		"count": 1,
		"equip_slot": slot_name,
		"atk_bonus": 0,
		"def_bonus": 0,
	}
	options.insert(0, empty_entry)
	return options


func set_member_equipment(member_index: int, slot_name: String, item_id: String) -> bool:
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size():
		return false
	if not EQUIPMENT_SLOTS.has(slot_name):
		return false
	var member: Dictionary = party[member_index]
	var equipment: Dictionary = member.get("equipment", {}).duplicate(true)
	var current_item_id: String = str(equipment.get(slot_name, ""))
	if current_item_id == item_id:
		return true
	if item_id != "":
		var inventory_service: Node = _get_inventory_service()
		if inventory_service == null or not inventory_service.has_method("get_item"):
			return false
		var item_data: QuizRpgItemData = inventory_service.call("get_item", item_id)
		if item_data == null or item_data.equip_slot != slot_name:
			return false
		var consume_result: Dictionary = inventory_service.call("consume_item_from_inventory", inventory, item_id, 1)
		if not bool(consume_result.get("success", false)):
			return false
		inventory = consume_result.get("inventory", inventory)
	if current_item_id != "":
		add_item(current_item_id, 1)
	equipment[slot_name] = item_id
	member["equipment"] = equipment
	party[member_index] = member
	inventory_changed.emit()
	party_changed.emit()
	return true


func optimize_member_equipment(member_index: int) -> void:
	if member_index < 0 or member_index >= party.size():
		return
	for slot_name: String in EQUIPMENT_SLOTS:
		var best_item_id: String = ""
		var best_score: int = -999999
		var options: Array[Dictionary] = get_equippable_entries_for_slot(member_index, slot_name)
		for entry: Dictionary in options:
			var score: int = int(entry.get("atk_bonus", 0)) + int(entry.get("def_bonus", 0))
			if score > best_score:
				best_score = score
				best_item_id = str(entry.get("item_id", ""))
		set_member_equipment(member_index, slot_name, best_item_id)


func clear_member_equipment(member_index: int) -> void:
	if member_index < 0 or member_index >= party.size():
		return
	var member: Dictionary = party[member_index]
	var defaults: Dictionary = member.get("default_equipment", {})
	for slot_name: String in EQUIPMENT_SLOTS:
		set_member_equipment(member_index, slot_name, str(defaults.get(slot_name, "")))


func _ensure_party_defaults() -> void:
	if party.is_empty():
		party.append(_build_default_party_member())
	for index: int in range(party.size()):
		var member: Dictionary = party[index]
		if not member.has("equipment") or not (member.get("equipment") is Dictionary):
			member["equipment"] = {}
		if not member.has("default_equipment") or not (member.get("default_equipment") is Dictionary):
			member["default_equipment"] = {}
		for slot_name: String in EQUIPMENT_SLOTS:
			if not member["equipment"].has(slot_name):
				member["equipment"][slot_name] = ""
			if not member["default_equipment"].has(slot_name):
				member["default_equipment"][slot_name] = ""
		if not member.has("max_sp"):
			member["max_sp"] = 100
		if not member.has("sp"):
			member["sp"] = int(member.get("max_sp", 100))
		if not member.has("max_tp"):
			member["max_tp"] = 100
		if not member.has("tp"):
			member["tp"] = 0
		if not member.has("base_atk"):
			member["base_atk"] = 10
		if not member.has("base_def"):
			member["base_def"] = 8
		if not member.has("portrait"):
			member["portrait"] = null
		party[index] = member


func _sync_primary_party_member() -> void:
	_ensure_party_defaults()
	if party.is_empty():
		return
	var member: Dictionary = party[0]
	member["name"] = player_name
	member["level"] = level
	member["hp"] = hp
	member["max_hp"] = max_hp
	party[0] = member


func _build_default_party_member() -> Dictionary:
	return {
		"name": player_name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"sp": 100,
		"max_sp": 100,
		"tp": 0,
		"max_tp": 100,
		"base_atk": 10,
		"base_def": 8,
		"portrait": null,
		"equipment": {
			"weapon": "",
			"shield": "",
			"head": "",
			"body": "",
			"accessory": "",
		},
		"default_equipment": {
			"weapon": "",
			"shield": "",
			"head": "",
			"body": "",
			"accessory": "",
		},
	}


func _get_equipped_stat_bonus(member: Dictionary, slot_name: String, stat_name: String) -> int:
	var equipment: Dictionary = member.get("equipment", {})
	var item_id: String = str(equipment.get(slot_name, ""))
	if item_id == "":
		return 0
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("get_item"):
		return 0
	var item_data: QuizRpgItemData = inventory_service.call("get_item", item_id)
	if item_data == null:
		return 0
	return int(item_data.get(stat_name))


func _get_inventory_service() -> Node:
	var core_manager: Node = get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var service: Variant = core_manager.call("get_singleton", "InventoryService")
		if service is Node:
			return service
	return get_node_or_null("/root/InventoryService")
