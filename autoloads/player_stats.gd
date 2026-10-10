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
## Członek drużyny poznał umiejętność z poziomu (learn_level) — komunikat w walce po awansie.
signal skill_learned(member_index: int, skill_name: String)
## Obrażenia od statusu (trucizna): członek drużyny, status, utracone HP — świat (co POISON_WORLD_INTERVAL) i walka.
signal status_tick(member_index: int, status_id: String, amount: int)

## Maks. HP bohatera rośnie liniowo od BASE_HP (poziom 1) do HP_AT_MAX_LEVEL (MAX_LEVEL); z hero_party_data[0] — jego pola.
## Wzór: FNaFB1 — Freddy 334 HP na lv 1, 1402 na lv 20; MAX_LEVEL podnieść, gdy pojawi się więcej map.
const MAX_LEVEL        := 20
const BASE_HP          := 334
const HP_AT_MAX_LEVEL  := 1402
const ATK_PER_LEVEL    := 2.0   # domyślne, gdy postać nie ma własnych atk_per_level / def_per_level
const DEF_PER_LEVEL    := 1.5
const BASE_XP_TO_LEVEL := 100
## XP do następnego poziomu: BASE_XP_TO_LEVEL × poziom^XP_EXPONENT (lv 1->2: 100, 5->6: 1118, 19->20: ~8300; razem do lv 20 ~67 tys.).
## Wrogowie wyższych tierów dają wielokrotnie więcej XP niż 35–85 dzisiejszych — stroić przy kolejnych mapach.
const XP_EXPONENT      := 1.5
## Statusy członków drużyny: member["statuses"] = {id: true} (zapisywane razem z drużyną). Trucizna (decyzje usera
## 2026-10-09): nada ją umiejętność użyta w walce (add_status; do zrobienia), trwa także w eksploracji, dopóki nie użyje się przedmiotu
## leczącego statusy (cure_statuses). Poza walką 1 HP co 3 s, najwyżej do 1 HP; w walce co turę ułamek maks. HP,
## może zbić do 0.
const STATUS_POISON := "poison"
const STATUS_NAMES := {"poison": "Zatrucie"}
const POISON_WORLD_INTERVAL := 3.0
const POISON_WORLD_DAMAGE := 1
const POISON_COMBAT_FRACTION := 0.05
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "shield", "head", "body", "accessory"]
const EQUIPMENT_LABELS := {
	"weapon": "Broń",
	"shield": "Tarcza",
	"head": "Głowa",
	"body": "Ciało",
	"accessory": "Akcesorium",
}

@export var hero_party_data: Array[QuizRpgHeroData] = []
## Bohater, gdy hero_party_data puste (autoload bez module_root.tscn — testy).
const DEFAULT_HERO_PATH := "resources/heroes/hero_bohater.tres"
const QuizRpgPaths = preload("../scripts/quiz_rpg_paths.gd")

var _status_clock := 0.0

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
	_ensure_default_hero()
	_recalculate_max_hp()
	_normalize_inventory()
	_ensure_party_defaults()
	_sync_primary_party_member()
	learn_level_skills()


func xp_to_next_level() -> int:
	return int(BASE_XP_TO_LEVEL * pow(level, XP_EXPONENT))


func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		xp = 0
		xp_changed.emit(xp, xp_to_next_level())
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		_recalculate_max_hp()
		hp = max_hp
		_sync_primary_party_member()
		learn_level_skills()
		level_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0
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
	if _god_mode():
		return
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	_sync_primary_party_member()
	party_changed.emit()


## Obrażenia procentowe całej drużyny (np. kolce w posadzce): każdy członek traci `fraction` swojego maks. HP
## (co najmniej 1). keep_alive: HP nie spada poniżej 1 (pułapka nie zabija).
func damage_party_percent(fraction: float, keep_alive := true) -> void:
	if _god_mode():
		return
	_ensure_party_defaults()
	var floor_hp := 1 if keep_alive else 0
	var lead_dmg := maxi(ceili(max_hp * fraction), 1)
	hp = maxi(hp - lead_dmg, mini(floor_hp, hp))
	for i in range(1, party.size()):
		var m: Dictionary = party[i]
		var mx := int(m.get("max_hp", 1))
		var cur := int(m.get("hp", mx))
		m["hp"] = maxi(cur - maxi(ceili(mx * fraction), 1), mini(floor_hp, cur))
		party[i] = m
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


# --- Umiejętności --------------------------------------------------------------------------

## Dane postaci członka drużyny (hero_id), inaczej pierwsza z hero_party_data (miniaturki, umiejętności).
func hero_for_member(member: Dictionary) -> QuizRpgHeroData:
	_ensure_default_hero()
	var hid := str(member.get("hero_id", ""))
	for h: QuizRpgHeroData in hero_party_data:
		if h != null and h.hero_id == hid:
			return h
	return hero_party_data[0]


## Odblokowane umiejętności członka w kolejności puli postaci — słowniki QuizRpgSkillData.to_entry().
func get_member_skills(member_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if member_index < 0 or member_index >= party.size():
		return out
	var member: Dictionary = party[member_index]
	var unlocked: Array = member.get("skills", [])
	var hero := hero_for_member(member)
	if hero == null:
		return out
	for sk: QuizRpgSkillData in hero.skills:
		if sk != null and unlocked.has(sk.skill_id):
			out.append(sk.to_entry())
	return out


## Pula umiejętności postaci członka (także zablokowane) — sklep NPC, podgląd.
func get_member_skill_pool(member_index: int) -> Array[QuizRpgSkillData]:
	var out: Array[QuizRpgSkillData] = []
	if member_index < 0 or member_index >= party.size():
		return out
	var hero := hero_for_member(party[member_index])
	if hero:
		for sk: QuizRpgSkillData in hero.skills:
			if sk != null:
				out.append(sk)
	return out


## Umiejętność użyta w menu pauzy (Occasion ALWAYS / MENU): koszt SP / TP użytkownika, leczenie celu jak po dobrej
## odpowiedzi (bez quizu). Bez efektu (pełne HP, brak zasobów) nic nie pobiera. Zwraca {success, message}.
func use_skill_on_member(user_index: int, skill_id: String, target_index: int) -> Dictionary:
	if user_index < 0 or user_index >= party.size() or target_index < 0 or target_index >= party.size():
		return {"success": false, "message": "Nieprawidłowy cel."}
	var skill: Dictionary = {}
	for e in get_member_skills(user_index):
		if e.get("skill_id") == skill_id:
			skill = e
	if skill.is_empty() or not bool(skill.get("usable_in_menu", false)):
		return {"success": false, "message": "Tej umiejętności używa się tylko w walce."}
	var user: Dictionary = party[user_index]
	var sp_cost := int(skill.get("sp_cost", 0))
	var tp_cost := int(skill.get("tp_cost", 0))
	if int(user.get("sp", 0)) < sp_cost or int(user.get("tp", 0)) < tp_cost:
		return {"success": false, "message": "Za mało SP / TP."}
	if str(skill.get("effect", "")) != "heal":
		return {"success": false, "message": "Ta umiejętność nic tu nie da."}
	var hp_now := _member_hp(target_index)
	var hp_max := _member_max_hp(target_index)
	if hp_now >= hp_max:
		return {"success": false, "message": "HP jest pełne."}
	var amount := mini(maxi(ceili(hp_max * float(skill.get("heal_ratio_correct", 0.3))), 1), hp_max - hp_now)
	user = party[user_index]
	user["sp"] = int(user.get("sp", 0)) - sp_cost
	user["tp"] = int(user.get("tp", 0)) - tp_cost
	party[user_index] = user
	_set_member_hp(target_index, hp_now + amount)
	party_changed.emit()
	var target_name := str((party[target_index] as Dictionary).get("name", "Bohater"))
	return {"success": true, "message": "%s: %s +%d HP" % [skill.get("name", ""), target_name, amount]}


## Umiejętności z poziomu (learn_level 1..poziom członka), których członek jeszcze nie zna -> odblokowane
## (sygnał skill_learned). Zwraca nazwy nowych umiejętności. Wołane po awansie, wczytaniu i starcie.
func learn_level_skills() -> Array[String]:
	var out: Array[String] = []
	for i in range(party.size()):
		var member: Dictionary = party[i]
		var lvl := int(member.get("level", 1))
		var unlocked: Array = member.get("skills", [])
		for sk in get_member_skill_pool(i):
			if sk.learn_level > 0 and sk.learn_level <= lvl and not unlocked.has(sk.skill_id):
				unlocked.append(sk.skill_id)
				out.append(sk.display_name)
				skill_learned.emit(i, sk.display_name)
		member["skills"] = unlocked
		party[i] = member
	if not out.is_empty():
		party_changed.emit()
	return out


## Odblokowuje umiejętność z puli postaci (zakup u NPC). false = brak w puli albo już jest.
func unlock_skill(member_index: int, skill_id: String) -> bool:
	if member_index < 0 or member_index >= party.size():
		return false
	var in_pool := false
	for sk in get_member_skill_pool(member_index):
		if sk.skill_id == skill_id:
			in_pool = true
	var member: Dictionary = party[member_index]
	var unlocked: Array = member.get("skills", [])
	if not in_pool or unlocked.has(skill_id):
		return false
	unlocked.append(skill_id)
	member["skills"] = unlocked
	party[member_index] = member
	party_changed.emit()
	return true


# --- Statusy -----------------------------------------------------------------------------

func has_status(member_index: int, status_id: String) -> bool:
	if member_index < 0 or member_index >= party.size():
		return false
	return ((party[member_index] as Dictionary).get("statuses", {}) as Dictionary).has(status_id)


func get_statuses(member_index: int) -> Array:
	if member_index < 0 or member_index >= party.size():
		return []
	return ((party[member_index] as Dictionary).get("statuses", {}) as Dictionary).keys()


## params: parametry statusu zapisywane z nim (trucizna: {"mode": "percent" | "fixed", "amount": float}); puste = domyślne.
func add_status(member_index: int, status_id: String, params: Dictionary = {}) -> bool:
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size() or has_status(member_index, status_id):
		return false
	var member: Dictionary = party[member_index]
	var st: Dictionary = member.get("statuses", {})
	st[status_id] = params.duplicate() if not params.is_empty() else true
	member["statuses"] = st
	party[member_index] = member
	party_changed.emit()
	return true


## Zdejmuje podane statusy; zwraca zdjęte.
func cure_statuses(member_index: int, status_ids: Array) -> Array:
	var out: Array = []
	if member_index < 0 or member_index >= party.size():
		return out
	var member: Dictionary = party[member_index]
	var st: Dictionary = member.get("statuses", {})
	for sid in status_ids:
		if st.erase(String(sid)):
			out.append(String(sid))
	if not out.is_empty():
		member["statuses"] = st
		party[member_index] = member
		party_changed.emit()
	return out


func any_status(status_id: String) -> bool:
	for i in range(party.size()):
		if has_status(i, status_id):
			return true
	return false


## Trucizna w walce (wywołuje ekran walki raz na turę): każdy zatruty członek traci POISON_COMBAT_FRACTION maks. HP
## (co najmniej 1), może spaść do 0. Zwraca [[indeks, obrażenia], …].
func tick_poison_combat() -> Array:
	var out: Array = []
	if _god_mode():
		return out
	for i in range(party.size()):
		if has_status(i, STATUS_POISON) and _member_hp(i) > 0:
			var dmg := mini(_poison_combat_damage(i), _member_hp(i))
			_set_member_hp(i, _member_hp(i) - dmg)
			out.append([i, dmg])
			status_tick.emit(i, STATUS_POISON, dmg)
	if not out.is_empty():
		party_changed.emit()
	return out


## Obrażenia trucizny członka na turę walki: z parametrów nadanych przez umiejętność (procent maks. HP albo stała),
## domyślnie POISON_COMBAT_FRACTION maks. HP; co najmniej 1.
func _poison_combat_damage(i: int) -> int:
	var p: Variant = ((party[i] as Dictionary).get("statuses", {}) as Dictionary).get(STATUS_POISON)
	if p is Dictionary:
		var amount := float((p as Dictionary).get("amount", 0.0))
		if amount > 0.0:
			if String((p as Dictionary).get("mode", "percent")) == "fixed":
				return maxi(roundi(amount), 1)
			return maxi(ceili(_member_max_hp(i) * amount / 100.0), 1)
	return maxi(ceili(_member_max_hp(i) * POISON_COMBAT_FRACTION), 1)


## Trucizna w eksploracji: co POISON_WORLD_INTERVAL s (tylko w stanie EXPLORING — pauza, walka, menu wstrzymują)
## POISON_WORLD_DAMAGE HP, najwyżej do 1 HP (poza walką nie zabija).
func _process(delta: float) -> void:
	if not any_status(STATUS_POISON) or not _is_exploring() or _god_mode():
		return
	_status_clock += delta
	if _status_clock < POISON_WORLD_INTERVAL:
		return
	_status_clock -= POISON_WORLD_INTERVAL
	var hit := false
	for i in range(party.size()):
		var cur := _member_hp(i)
		if has_status(i, STATUS_POISON) and cur > 1:
			var dmg := mini(POISON_WORLD_DAMAGE, cur - 1)
			_set_member_hp(i, cur - dmg)
			status_tick.emit(i, STATUS_POISON, dmg)
			hit = true
	if hit:
		party_changed.emit()


func _god_mode() -> bool:
	var cheat_service := get_node_or_null("/root/CheatService")
	return cheat_service != null and "god_mode" in cheat_service and bool(cheat_service.god_mode)


## Nazwa statusu do wyświetlenia (STATUS_NAMES), inaczej sam identyfikator.
func status_name(id: String) -> String:
	return str(STATUS_NAMES.get(id, id))


func _member_hp(i: int) -> int:
	return hp if i == 0 else int((party[i] as Dictionary).get("hp", 0))


func _member_max_hp(i: int) -> int:
	return max_hp if i == 0 else int((party[i] as Dictionary).get("max_hp", 1))


func _set_member_hp(i: int, v: int) -> void:
	if i == 0:
		hp = v
		hp_changed.emit(hp, max_hp)
		_sync_primary_party_member()
	else:
		var m: Dictionary = party[i]
		m["hp"] = v
		party[i] = m


func _is_exploring() -> bool:
	var core_manager: Node = get_node_or_null("/root/CoreManager")
	var gm: Variant = null
	if core_manager and core_manager.has_method("get_singleton"):
		gm = core_manager.call("get_singleton", "GameManager")
	if not (gm is Node):
		gm = get_node_or_null("/root/GameManager")
	return gm is Node and (gm as Node).has_method("is_exploring") and bool((gm as Node).call("is_exploring"))


## Obrażenia członka drużyny (umiejętności wrogów celujące w drużynę); lider przez take_damage (tryb boga).
func damage_member(member_index: int, amount: int) -> void:
	if member_index == 0:
		take_damage(amount)
		return
	if member_index < 0 or member_index >= party.size():
		return
	_set_member_hp(member_index, maxi(_member_hp(member_index) - amount, 0))
	party_changed.emit()


## Cała drużyna bez przytomności — warunek ekranu śmierci (decyzja usera: wszyscy członkowie 0 HP, nie sam lider).
func is_party_defeated() -> bool:
	if hp > 0:
		return false
	for i in range(1, party.size()):
		if int((party[i] as Dictionary).get("hp", 0)) > 0:
			return false
	return true


func _recalculate_max_hp() -> void:
	var first := BASE_HP
	var last := HP_AT_MAX_LEVEL
	if not hero_party_data.is_empty() and hero_party_data[0] != null:
		first = hero_party_data[0].base_hp
		last = hero_party_data[0].hp_at_max_level
	max_hp = QuizRpgHeroData.linear_hp(first, last, level, MAX_LEVEL)


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
		"inventory": inventory.duplicate(true),
		"party": party.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	player_name   = data.get("player_name", "Bohater")
	level         = data.get("level", 1)
	xp            = data.get("xp", 0)
	hp            = data.get("hp", BASE_HP)
	max_hp        = data.get("max_hp", BASE_HP)
	# stary zapis (HP 100 + 20 / poziom): nowa skala, zachowany stosunek hp / max_hp
	var saved_max := maxi(max_hp, 1)
	_recalculate_max_hp()
	hp = clampi(roundi(float(hp) * float(max_hp) / float(saved_max)), 0, max_hp)
	points        = data.get("points", 0)
	streak        = data.get("streak", 0)
	best_streak   = data.get("best_streak", 0)
	total_correct = data.get("total_correct", 0)
	total_wrong   = data.get("total_wrong", 0)
	rewards.assign(data.get("rewards", []))
	rng_bonus     = data.get("rng_bonus", 0.0)
	inventory = _to_dictionary_array(data.get("inventory", inventory.duplicate(true)))
	party = _to_dictionary_array(data.get("party", party.duplicate(true)))
	_normalize_inventory()
	_ensure_party_defaults()
	_sync_primary_party_member()
	learn_level_skills()


func reset() -> void:
	player_name = "Bohater" ; level = 1 ; xp = 0
	_recalculate_max_hp()
	hp = max_hp ; points = 0 ; streak = 0
	best_streak = 0 ; total_correct = 0 ; total_wrong = 0
	rewards.clear() ; rng_bonus = 0.0
	inventory = [
		{"item_id": "potion", "count": 2},
		{"item_id": "ether", "count": 1},
		{"item_id": "antidote", "count": 1},
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


func _to_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry: Variant in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


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
		return {"success": false, "message": "InventoryService niedostępny."}
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size():
		return {"success": false, "message": "Nieprawidłowy cel."}
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
	var cured: Array = []
	if not item_data.cure_statuses.is_empty():
		var st: Dictionary = member.get("statuses", {})
		for sid in item_data.cure_statuses:
			if st.erase(String(sid)):
				cured.append(String(sid))
		member["statuses"] = st
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
		"cured_statuses": cured,
		"usable_in_menu": item_data.usable_in_menu,
		"usable_in_combat": item_data.usable_in_combat,
		"message": "%s: %s" % [item_data.display_name, item_data.get_effect_summary()] if item_data.get_effect_summary() != "" else "Użyto %s." % item_data.display_name,
	}
	if bool(result.get("success", false)):
		_sync_primary_party_member()
		result["member_name"] = str(member.get("name", "Bohater"))
		result["member_hp"] = int(member.get("hp", 0))
		result["member_sp"] = int(member.get("sp", 0))
		result["member_tp"] = int(member.get("tp", 0))
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
	var total_atk: int = int(member.get("base_atk", 0)) + _get_member_level_bonus(member, float(member.get("atk_per_level", ATK_PER_LEVEL)))
	for slot_name: String in EQUIPMENT_SLOTS:
		total_atk += int(_get_equipped_stat_bonus(member, slot_name, "atk_bonus"))
	return total_atk


func get_member_total_def(member_index: int) -> int:
	if member_index < 0 or member_index >= party.size():
		return 0
	var member: Dictionary = party[member_index]
	var total_def: int = int(member.get("base_def", 0)) + _get_member_level_bonus(member, float(member.get("def_per_level", DEF_PER_LEVEL)))
	for slot_name: String in EQUIPMENT_SLOTS:
		total_def += int(_get_equipped_stat_bonus(member, slot_name, "def_bonus"))
	return total_def


## Obrażenia członka drużyny jak w FNAfB: (moc ataku − DEF × 2) × mnożnik obrony, co najmniej 1. `attack_power` to ATK
## wroga × 4 (× mnożnik umiejętności) albo stała z umiejętności.
func calculate_incoming_damage(attack_power: int, defending_multiplier: float = 1.0, member_index: int = 0) -> int:
	var after_armor := float(attack_power) - 2.0 * float(get_member_total_def(member_index))
	return maxi(int(floor(after_armor * maxf(defending_multiplier, 0.0))), 1)


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
		"description": "Zdejmij wyposażenie z tego slotu.",
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


func _ensure_default_hero() -> void:
	if hero_party_data.is_empty():
		var hero := load(QuizRpgPaths.path(DEFAULT_HERO_PATH)) as QuizRpgHeroData
		hero_party_data.append(hero if hero != null else QuizRpgHeroData.new())


func _ensure_party_defaults() -> void:
	_ensure_default_hero()
	if party.is_empty():
		for hero_data: QuizRpgHeroData in hero_party_data:
			if hero_data:
				party.append(hero_data.build_member_data())
	for index: int in range(party.size()):
		var member: Dictionary = party[index]
		if not (member.get("skills") is Array):
			member["skills"] = []
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
		if not member.has("actor_scene"):
			member["actor_scene"] = null
		if not member.has("sprite_frames"):
			member["sprite_frames"] = null
		if not member.has("body_color"):
			member["body_color"] = Color(0.2, 0.6, 1.0)
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


func _get_member_level_bonus(member: Dictionary, per_level: float) -> int:
	return roundi(maxi(int(member.get("level", 1)) - 1, 0) * per_level)


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
