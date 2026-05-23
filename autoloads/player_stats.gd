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

const BASE_HP          := 100
const HP_PER_LEVEL     := 20
const BASE_XP_TO_LEVEL := 100
const XP_GROWTH        := 1.5

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
]


func _ready() -> void:
	_recalculate_max_hp()
	_normalize_inventory()


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


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


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
	_normalize_inventory()


func reset() -> void:
	player_name = "Bohater" ; level = 1 ; xp = 0
	_recalculate_max_hp()
	hp = max_hp ; points = 0 ; streak = 0
	best_streak = 0 ; total_correct = 0 ; total_wrong = 0
	rewards.clear() ; rng_bonus = 0.0


func get_inventory_entries() -> Array[Dictionary]:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service and inventory_service.has_method("get_menu_entries"):
		return inventory_service.call("get_menu_entries", inventory)
	return []


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
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("use_item"):
		return {"success": false, "message": "InventoryService niedostepny."}
	var result: Dictionary = inventory_service.call("use_item", self, inventory, item_ref)
	if bool(result.get("success", false)):
		inventory = result.get("inventory", inventory)
		inventory_changed.emit()
	return result


func _normalize_inventory() -> void:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service and inventory_service.has_method("normalize_inventory"):
		inventory = inventory_service.call("normalize_inventory", inventory)


func _get_inventory_service() -> Node:
	var core_manager: Node = get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var service: Variant = core_manager.call("get_singleton", "InventoryService")
		if service is Node:
			return service
	return get_node_or_null("/root/InventoryService")
