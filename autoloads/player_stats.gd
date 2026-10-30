extends Node

## PlayerStats — moduł QuizRPG
## Przechowuje statystyki gracza: HP, XP, poziom, punkty, nagrody.
## Dostępny przez: CoreManager.get_singleton("PlayerStats")

signal hp_changed(new_hp: int, max_hp: int)
signal xp_changed(new_xp: int, xp_to_next: int)
signal level_up(new_level: int)
signal points_changed(new_points: int)
signal gold_changed(new_gold: int)
signal reward_earned(reward_name: String)
signal inventory_changed()
signal party_changed()
## Awans członka drużyny poza liderem (lider: level_up).
signal member_level_up(member_index: int, new_level: int)
## Nowy członek drużyny (recruit).
signal member_recruited(member_index: int, hero_id: String)
## Członek drużyny poznał umiejętność z poziomu (learn_level) — komunikat w walce po awansie.
signal skill_learned(member_index: int, skill_name: String)
## Obrażenia od statusu (trucizna): członek drużyny, status, utracone HP — świat (co POISON_WORLD_INTERVAL) i walka.
signal status_tick(member_index: int, status_id: String, amount: int)
## Dziennik zadań NPC zmieniony (przyjęte / oddane zadanie, nowy pokonany wróg).
signal quests_changed()

## Maks. HP bohatera: QuizRpgHeroData.hp_for_level (z hero_party_data[0] — jego pola).
## 100 poziomów = 15 map (wyczyszczenie 120 % wrogów z każdej mapy daje razem lv 100, QuizRpgEnemyXp). HP: lv 1 334, lv 20 1402
## (jak FNaFB1), lv 100 50000 (QuizRpgHeroData.hp_for_level).
const MAX_LEVEL        := 100
## Aktualny limit poziomu (rośnie z rozwojem gry: kolejne mapy podnoszą go, np. cmentarz = limit dla 3 map) — XP ponad limit przepada.
const LEVEL_CAP        := 20
const BASE_HP          := 334
## XP do następnego poziomu: krzywa z QuizRpgHeroData (xp_base, xp_extra, xp_acc_a, xp_acc_b — jak klasa w FNaFB1: lv 1->2 90, 2->3 204,
## 19->20 12 532; razem do lv 20 ~87 tys.). Wrogowie wyższych tierów dają wielokrotnie więcej XP — stroić przy kolejnych mapach.
## Statusy członków drużyny: member["statuses"] = {id: {turns, …parametry}} (zapisywane razem z drużyną; definicje
## w resources/statuses/ — QuizRpgStatusCatalog). turns 0 = do wyleczenia. Trucizna (decyzje usera 2026-10-09): trwa
## także w eksploracji, dopóki nie użyje się przedmiotu leczącego statusy (cure_statuses); poza walką co 3 s tyle HP co w rundzie walki,
## najwyżej do 1 HP; w walce co rundę część maks. HP (może zbić do 0). Inne statusy znikają z końcem walki.
const STATUS_POISON := "poison"
const POISON_WORLD_INTERVAL := 3.0
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
## Postacie drużyny: hero_id -> plik danych (względem modułu). Towarzysze dołączają przez recruit().
const HERO_PATHS := {
	"bohater": DEFAULT_HERO_PATH,
	"lotrzyk": "resources/heroes/hero_lotrzyk.tres",
	"mag": "resources/heroes/hero_mag.tres",
	"kaplan": "resources/heroes/hero_kaplan.tres",
}
## Udział w XP członka bez przytomności na koniec walki (decyzja usera: 50 %).
const DOWNED_XP_SHARE := 0.5
const QuizRpgPaths = preload("../scripts/quiz_rpg_paths.gd")

var _status_clock := 0.0

var player_name: String    = "Bohater"
var level: int             = 1
var xp: int                = 0
var hp: int                = BASE_HP
var max_hp: int            = BASE_HP
var points: int            = 0
## Złoto z walk (QuizRpgEnemyGold); wydatki: mikstury, sprzęt, ulepszenia (sklep po odblokowaniu miasta). docs/kontekst/ekwipunek_szkic.md
var gold: int              = 0
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
## Zadania towarzyszy (NPC rekrutacji): hero_id -> {"state": "active" / "done", "start": licznik przy przyjęciu}.
var companion_quests: Dictionary = {}
## Zadania NPC (QuizRpgNpcQuest): quest_id -> wpis dziennika (QuizRpgQuestLog: stan, cel, licznik przy przyjęciu).
var quests: Dictionary = {}
## Pokonani wrogowie: id wroga (nazwa pliku danych, np. rat_base) -> liczba; klucz ALL_KILLS = wszyscy.
var enemy_kills: Dictionary = {}
const ALL_KILLS := "*"


func _ready() -> void:
	_ensure_default_hero()
	_recalculate_max_hp()
	_normalize_inventory()
	_ensure_party_defaults()
	_sync_primary_party_member()
	learn_level_skills()


func xp_to_next_level() -> int:
	if not hero_party_data.is_empty() and hero_party_data[0] != null:
		return hero_party_data[0].xp_to_next(level)
	return QuizRpgHeroData.new().xp_to_next(level)


## XP dla całej drużyny: każdy członek dostaje pełną kwotę do własnej puli (jak FNaFB, bez dzielenia), członek bez
## przytomności DOWNED_XP_SHARE. Bohater: PlayerStats.level / xp (sygnał level_up), pozostali: member["level"] / ["xp"]
## (sygnał member_level_up).
func add_xp(amount: int) -> void:
	var hi := hero_index()
	for i in range(party.size()):
		if i == hi:
			continue
		var m: Dictionary = party[i]
		var share := amount if int(m.get("hp", 0)) > 0 else int(amount * DOWNED_XP_SHARE)
		_add_member_xp(i, share)
	_add_hero_xp(amount if hp > 0 else int(amount * DOWNED_XP_SHARE))


func _add_hero_xp(amount: int) -> void:
	if level >= mini(MAX_LEVEL, LEVEL_CAP):
		xp = 0
		xp_changed.emit(xp, xp_to_next_level())
		return
	xp += amount
	while level < mini(MAX_LEVEL, LEVEL_CAP) and xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		_recalculate_max_hp()
		_sync_primary_party_member()
		learn_level_skills()
		level_up.emit(level)
	if level >= mini(MAX_LEVEL, LEVEL_CAP):
		xp = 0
	xp_changed.emit(xp, xp_to_next_level())


## XP członka (nie bohatera) do jego puli; awanse wg krzywej jego postaci: maks. HP i SP rosną, bieżące HP / SP bez
## zmian (jak u bohatera), nowe umiejętności z poziomu.
func _add_member_xp(member_index: int, amount: int) -> void:
	if member_index < 0 or member_index >= party.size() or member_index == hero_index() or amount <= 0:
		return
	var m: Dictionary = party[member_index]
	var hero := hero_for_member(m)
	var cap := mini(MAX_LEVEL, LEVEL_CAP)
	var lvl := int(m.get("level", 1))
	var x := int(m.get("xp", 0)) + amount
	var gained: Array[int] = []
	while lvl < cap and x >= hero.xp_to_next(lvl):
		x -= hero.xp_to_next(lvl)
		lvl += 1
		gained.append(lvl)
	if lvl >= cap:
		x = 0
	m["xp"] = x
	m["level"] = lvl
	if not gained.is_empty():
		m["max_hp"] = hero.hp_for_level(lvl, MAX_LEVEL)
	party[member_index] = m
	if not gained.is_empty():
		_sync_member_max_sp(member_index)
		learn_level_skills()
		for g in gained:
			member_level_up.emit(member_index, g)
		party_changed.emit()


## Indeks głównego bohatera (hero_party_data[0]) w drużynie. Jego HP / poziom / XP / imię są też w polach hp / level /
## xp / player_name. Szyk (kolejność drużyny) jest dowolny — party[0] to lider (postać na mapie, cel ataków w lidera).
func hero_index() -> int:
	_ensure_default_hero()
	var pid: String = hero_party_data[0].hero_id if hero_party_data[0] != null else ""
	for i in range(party.size()):
		if str((party[i] as Dictionary).get("hero_id", "")) == pid:
			return i
	return 0


func is_hero(member_index: int) -> bool:
	return member_index == hero_index()


## HP członka (bohater z pola hp).
func member_hp(member_index: int) -> int:
	return _member_hp(member_index) if member_index >= 0 and member_index < party.size() else 0


## SP członka drużyny (party[member_index]["sp"]).
func member_sp(member_index: int) -> int:
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size():
		return 0
	return int((party[member_index] as Dictionary).get("sp", 0))


## Maksymalne SP członka drużyny (party[member_index]["max_sp"]).
func member_max_sp(member_index: int) -> int:
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size():
		return 1
	return maxi(int((party[member_index] as Dictionary).get("max_sp", 1)), 1)


## Zużycie SP członka drużyny (umiejętności w walce / menu). Zwraca faktycznie zużyte SP.
func consume_member_sp(member_index: int, amount: int) -> int:
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size() or amount <= 0:
		return 0
	var m: Dictionary = party[member_index]
	var cur: int = int(m.get("sp", 0))
	var spent: int = mini(cur, amount)
	m["sp"] = cur - spent
	party[member_index] = m
	party_changed.emit()
	return spent


## Odnowienie SP członka drużyny (mikstury, umiejętności). Zwraca faktycznie odnowione SP.
func restore_member_sp(member_index: int, amount: int) -> int:
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size() or amount <= 0:
		return 0
	var m: Dictionary = party[member_index]
	var cur: int = int(m.get("sp", 0))
	var max_val: int = int(m.get("max_sp", cur))
	var restored: int = mini(amount, maxi(max_val - cur, 0))
	m["sp"] = cur + restored
	party[member_index] = m
	party_changed.emit()
	return restored


## Ustawienie SP członka drużyny (z ograniczeniem 0..max_sp).
func set_member_sp(member_index: int, value: int) -> void:
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size():
		return
	var m: Dictionary = party[member_index]
	var max_val: int = int(m.get("max_sp", value))
	m["sp"] = clampi(value, 0, max_val)
	party[member_index] = m
	party_changed.emit()


## Zamienia miejscami dwóch członków drużyny (szyk; party[0] = lider). false = zły indeks albo ten sam.
func swap_members(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= party.size() or b >= party.size():
		return false
	_sync_primary_party_member()
	var tmp: Dictionary = party[a]
	party[a] = party[b]
	party[b] = tmp
	party_changed.emit()
	return true


## Postacie z HERO_PATHS, których nie ma w drużynie (menu deweloperskie, przyszłe zadania towarzyszy).
func recruitable_heroes() -> Array[String]:
	var out: Array[String] = []
	for id: String in HERO_PATHS:
		if not has_member(id) and hero_by_id(id) != null:
			out.append(id)
	return out


func has_member(hero_id: String) -> bool:
	for m: Dictionary in party:
		if str(m.get("hero_id", "")) == hero_id:
			return true
	return false


## Dołącza postać do drużyny (zadanie towarzysza, menu deweloperskie). at_level <= 0: własny poziom postaci z danych
## (QuizRpgHeroData.base_level — ustawiany w Inspektorze), nie poziom gracza. Pełne HP / SP, ekwipunek startowy postaci założony, umiejętności z poziomu. false = już w drużynie
## albo nieznana postać.
func recruit(hero_id: String, at_level: int = 0) -> bool:
	if has_member(hero_id):
		return false
	var hero := hero_by_id(hero_id)
	if hero == null:
		return false
	var m := hero.build_member_data()
	var lvl := clampi(at_level if at_level > 0 else hero.base_level, 1, mini(MAX_LEVEL, LEVEL_CAP))
	m["level"] = lvl
	m["xp"] = 0
	m["max_hp"] = hero.hp_for_level(lvl, MAX_LEVEL)
	m["hp"] = m["max_hp"]
	party.append(m)
	var idx := party.size() - 1
	_ensure_party_defaults()
	_sync_member_max_sp(idx)
	var mm: Dictionary = party[idx]
	mm["sp"] = int(mm.get("max_sp", 0))
	party[idx] = mm
	learn_level_skills()
	member_recruited.emit(idx, hero_id)
	party_changed.emit()
	return true


## Usuwa towarzysza z drużyny (menu deweloperskie). Założony ekwipunek wraca do plecaka; zadanie towarzysza
## (companion_quests) zostaje, więc NPC rekrutacji w mieście znów go przyjmie. Głównego bohatera nie usuwa —
## false = nie ma go w drużynie albo to bohater.
func dismiss(hero_id: String) -> bool:
	for i in range(party.size()):
		if str((party[i] as Dictionary).get("hero_id", "")) != hero_id:
			continue
		if is_hero(i):
			return false
		_sync_primary_party_member()
		for item_id in ((party[i] as Dictionary).get("equipment", {}) as Dictionary).values():
			if str(item_id) != "":
				add_item(str(item_id), 1)
		party.remove_at(i)
		inventory_changed.emit()
		party_changed.emit()
		return true
	return false


## Imię bohatera (ekran nowej gry): pole player_name i wpis bohatera w drużynie.
func set_player_name(value: String) -> void:
	player_name = value
	_sync_primary_party_member()
	party_changed.emit()


## Towarzysze w drużynie (bez głównego bohatera) — hero_id w kolejności szyku.
func companion_ids() -> Array[String]:
	var out: Array[String] = []
	for i in range(party.size()):
		if not is_hero(i):
			out.append(str((party[i] as Dictionary).get("hero_id", "")))
	return out


func add_points(amount: int) -> void:
	points += amount
	points_changed.emit(points)


func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold = maxi(gold + amount, 0)
	gold_changed.emit(gold)


## Wydatek: false (bez zmian), gdy brakuje złota.
func spend_gold(amount: int) -> bool:
	if amount < 0 or amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


## Zwraca XP za odpowiedź (15 + 3 × seria). grant_xp = false — walka: XP trafia do puli walki i przepada przy
## ucieczce / porażce (wcześniej wpadało od razu, także przy ucieczce).
func on_correct_answer(grant_xp: bool = true) -> int:
	total_correct += 1
	streak += 1
	if streak > best_streak:
		best_streak = streak
	rng_bonus = clampf(rng_bonus + 0.05 + (streak * 0.02), 0.0, 0.5)
	add_points(10 + streak * 5)
	var answer_xp := 15 + streak * 3
	if grant_xp:
		add_xp(answer_xp)
	_check_rewards()
	return answer_xp


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
	var hi := hero_index()
	for i in range(party.size()):
		if i == hi:
			continue
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
	var h := hero_by_id(str(member.get("hero_id", "")))
	return h if h != null else hero_party_data[0]


var _hero_cache := {}  # hero_id -> QuizRpgHeroData (null = brak)


## Dane postaci po hero_id: hero_party_data, potem HERO_PATHS.
func hero_by_id(hero_id: String) -> QuizRpgHeroData:
	for h: QuizRpgHeroData in hero_party_data:
		if h != null and h.hero_id == hero_id:
			return h
	if not _hero_cache.has(hero_id):
		var p := str(HERO_PATHS.get(hero_id, ""))
		var full := QuizRpgPaths.path(p) if p != "" else ""
		_hero_cache[hero_id] = load(full) as QuizRpgHeroData if full != "" and ResourceLoader.exists(full) else null
	return _hero_cache[hero_id]


## Odblokowane umiejętności członka w kolejności puli postaci — słowniki QuizRpgSkillData.to_entry() z zasobem na
## tierze ze slotu (nieaktywne: tier startowy) i polami slotów: tier (0 = poza slotem), active, free (skan), tier_min / tier_max.
func get_member_skills(member_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if member_index < 0 or member_index >= party.size():
		return out
	var member: Dictionary = party[member_index]
	var unlocked: Array = member.get("skills", [])
	var loadout: Dictionary = member.get("loadout", {})
	var hero := hero_for_member(member)
	if hero == null:
		return out
	for sk: QuizRpgSkillData in hero.skills:
		if sk != null and unlocked.has(sk.skill_id):
			var free := QuizRpgSkillSlots.is_free(sk)
			var tier := int(loadout.get(sk.skill_id, 0))
			var e := sk.at_tier(tier).to_entry(int(member.get("max_sp", 0)))
			e["tier"] = tier
			e["active"] = free or tier > 0
			e["free"] = free
			e["tier_min"] = sk.tier_min
			e["tier_max"] = sk.tier_max
			out.append(e)
	return out


## Umiejętności dostępne w walce i w menu: tylko aktywne (w slotach) i poza budżetem (skan).
func get_member_battle_skills(member_index: int) -> Array[Dictionary]:
	return get_member_skills(member_index).filter(func(e: Dictionary) -> bool: return bool(e.active))


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


## Umiejętność użyta w menu pauzy (Occasion ALWAYS / MENU): koszt SP / TP użytkownika, leczenie jak po dobrej
## odpowiedzi (QuizRpgSkillMath.heal, bez quizu). Cel wg umiejętności: ja / wskazany sojusznik / cała drużyna /
## nieprzytomny (wskrzeszenie). Bez efektu (pełne HP, brak zasobów) nic nie pobiera. Zwraca {success, message}.
func use_skill_on_member(user_index: int, skill_id: String, target_index: int) -> Dictionary:
	if user_index < 0 or user_index >= party.size() or target_index < 0 or target_index >= party.size():
		return {"success": false, "message": QuizRpgI18n.t("party.invalid_target", "Nieprawidłowy cel.")}
	var skill: QuizRpgSkillBase = null
	var entry: Dictionary = {}
	for e in get_member_skills(user_index):
		if e.get("skill_id") == skill_id:
			entry = e
			skill = e.get("resource") as QuizRpgSkillBase
	if skill != null and not bool(entry.get("active", false)):
		return {"success": false, "message": QuizRpgI18n.t("party.skill_not_slotted", "Umiejętność nie jest w slocie.")}
	if skill == null or not bool(entry.get("usable_in_menu", false)):
		return {"success": false, "message": QuizRpgI18n.t("party.skill_combat_only", "Tej umiejętności używa się tylko w walce.")}
	if not skill.is_heal():
		return {"success": false, "message": QuizRpgI18n.t("party.skill_no_effect", "Ta umiejętność nic tu nie da.")}
	var user: Dictionary = party[user_index]
	var sp_cost := int(entry.get("sp_cost", 0))
	var tp_cost := int(entry.get("tp_cost", 0))
	if int(user.get("sp", 0)) < sp_cost or int(user.get("tp", 0)) < tp_cost:
		return {"success": false, "message": QuizRpgI18n.t("party.not_enough_sp_tp", "Za mało SP / TP.")}
	if not member_meets_weapon_requirement(user_index, entry):
		return {"success": false, "message": QuizRpgI18n.t("party.requires_other_weapon", "Wymaga innej broni.")}
	var targets: Array[int] = []
	match skill.target:
		QuizRpgSkillBase.Target.SELF:
			targets = [user_index]
		QuizRpgSkillBase.Target.ALL_ALLIES:
			for i in range(party.size()):
				if _member_hp(i) > 0:
					targets.append(i)
		_:
			targets = [target_index]
	var revive := skill.target == QuizRpgSkillBase.Target.DEAD_ALLY
	if revive and _member_hp(target_index) > 0:
		return {"success": false, "message": QuizRpgI18n.t("party.skill_revive_only", "Ta umiejętność wskrzesza tylko nieprzytomnych.")}
	var parts: Array[String] = []
	for t in targets:
		var healed := heal_member(t, QuizRpgSkillMath.heal(skill, _member_max_hp(t), int(get_member_total_stat(user_index, "mat"))), revive)
		if healed > 0:
			parts.append("%s +%d HP" % [str((party[t] as Dictionary).get("name", "Bohater")), healed])
	if parts.is_empty():
		return {"success": false, "message": QuizRpgI18n.t("party.hp_full", "HP jest pełne.")}
	user = party[user_index]
	user["sp"] = int(user.get("sp", 0)) - sp_cost
	user["tp"] = int(user.get("tp", 0)) - tp_cost
	party[user_index] = user
	party_changed.emit()
	return {"success": true, "message": "%s: %s" % [skill.localized_name(), ", ".join(parts)]}


## Leczy członka drużyny o amount (najwyżej do maks. HP); nieprzytomnego tylko z allow_revive (wskrzeszenie).
## Zwraca wyleczone HP.
func heal_member(member_index: int, amount: int, allow_revive: bool = false) -> int:
	if member_index < 0 or member_index >= party.size() or amount <= 0:
		return 0
	var now := _member_hp(member_index)
	if now <= 0 and not allow_revive:
		return 0
	var healed := mini(amount, _member_max_hp(member_index) - now)
	if healed <= 0:
		return 0
	_set_member_hp(member_index, now + healed)
	party_changed.emit()
	return healed


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
				out.append(sk.localized_name())
				member["skills"] = unlocked
				_try_activate(i, sk)  # ten sam słownik członka: dopisuje "loadout"
				skill_learned.emit(i, sk.localized_name())
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
	_try_activate(member_index, _pool_skill(member_index, skill_id))
	party_changed.emit()
	return true


# --- Sloty umiejętności (QuizRpgSkillSlots, docs/kontekst/sloty_umiejetnosci_szkic.md) ----------------------

## Aktywne skille członka: {skill_id: tier}. Skan (poza budżetem) tu nie trafia — jest zawsze dostępny.
func get_member_loadout(member_index: int) -> Dictionary:
	if member_index < 0 or member_index >= party.size():
		return {}
	return ((party[member_index] as Dictionary).get("loadout", {}) as Dictionary).duplicate()


## Stan slotów członka: {budget, used, active, max_active, max_tier} (budżet i maks. tier z poziomu + sprzętu).
func get_member_slot_info(member_index: int) -> Dictionary:
	if member_index < 0 or member_index >= party.size():
		return {}
	var lvl := int((party[member_index] as Dictionary).get("level", 1))
	var loadout := get_member_loadout(member_index)
	var used := 0
	for id: String in loadout:
		used += QuizRpgSkillSlots.cost(int(loadout[id]))
	return {
		"budget": QuizRpgSkillSlots.budget(lvl, _member_slot_bonus(member_index, "slot_budget")),
		"used": used,
		"active": loadout.size(),
		"max_active": QuizRpgSkillSlots.MAX_ACTIVE,
		"max_tier": QuizRpgSkillSlots.max_tier(lvl, _member_slot_bonus(member_index, "max_tier_bonus")),
	}


## Ustawia tier skilla w slocie (0 = zdejmuje ze slotu). false = skill nieznany albo poza budżetem, poza zakresem
## tierów [tier_min, maks. tier członka], ponad limit aktywnych albo skan (poza budżetem).
func set_member_skill_tier(member_index: int, skill_id: String, tier: int) -> bool:
	if member_index < 0 or member_index >= party.size():
		return false
	var member: Dictionary = party[member_index]
	var sk := _pool_skill(member_index, skill_id)
	if sk == null or QuizRpgSkillSlots.is_free(sk) or not (member.get("skills", []) as Array).has(skill_id):
		return false
	var loadout: Dictionary = (member.get("loadout", {}) as Dictionary).duplicate()
	if tier <= 0:
		if not loadout.has(skill_id):
			return false
		loadout.erase(skill_id)
	else:
		var info := get_member_slot_info(member_index)
		var r := QuizRpgSkillSlots.tier_range(sk, int(info.max_tier))
		var used := int(info.used) - QuizRpgSkillSlots.cost(int(loadout.get(skill_id, 0))) + QuizRpgSkillSlots.cost(tier)
		if tier < r.x or tier > r.y or used > int(info.budget):
			return false
		if not loadout.has(skill_id) and loadout.size() >= QuizRpgSkillSlots.MAX_ACTIVE:
			return false
		loadout[skill_id] = tier
	member["loadout"] = loadout
	party[member_index] = member
	party_changed.emit()
	return true


## Nowo nauczony skill wchodzi do slotu na tierze startowym, jeśli się mieści (inaczej czeka w menu Umiejętności).
func _try_activate(member_index: int, sk: QuizRpgSkillData) -> void:
	if sk != null and not QuizRpgSkillSlots.is_free(sk):
		set_member_skill_tier(member_index, sk.skill_id, sk.tier_min)


## Stary zapis bez slotów: znane skille po kolei w sloty, ile się zmieści.
func _autofill_loadout(member_index: int) -> void:
	var known: Array = (party[member_index] as Dictionary).get("skills", [])
	for sk in get_member_skill_pool(member_index):
		if known.has(sk.skill_id):
			_try_activate(member_index, sk)


## Po zmianie sprzętu (mniejszy budżet / maks. tier): tiery ponad limit w dół, a nadmiar od końca puli ze slotów.
func _fit_loadout(member_index: int) -> void:
	var member: Dictionary = party[member_index]
	var loadout: Dictionary = (member.get("loadout", {}) as Dictionary).duplicate()
	var info := get_member_slot_info(member_index)
	var pool := get_member_skill_pool(member_index)
	pool.reverse()
	var used := 0
	for sk in pool:
		if loadout.has(sk.skill_id):
			var t := mini(int(loadout[sk.skill_id]), int(info.max_tier))
			if t < sk.tier_min:
				loadout.erase(sk.skill_id)
			else:
				loadout[sk.skill_id] = t
				used += QuizRpgSkillSlots.cost(t)
	for sk in pool:
		if used <= int(info.budget) and loadout.size() <= QuizRpgSkillSlots.MAX_ACTIVE:
			break
		if loadout.has(sk.skill_id):
			used -= QuizRpgSkillSlots.cost(int(loadout[sk.skill_id]))
			loadout.erase(sk.skill_id)
	member["loadout"] = loadout
	party[member_index] = member


func _pool_skill(member_index: int, skill_id: String) -> QuizRpgSkillData:
	for sk in get_member_skill_pool(member_index):
		if sk.skill_id == skill_id:
			return sk
	return null


## Suma pola sprzętu członka ("slot_budget" / "max_tier_bonus").
func _member_slot_bonus(member_index: int, field: String) -> int:
	var sum := 0
	for slot_name: String in EQUIPMENT_SLOTS:
		sum += _get_equipped_stat_bonus(party[member_index], slot_name, field)
	return sum


# --- Statusy -----------------------------------------------------------------------------

func has_status(member_index: int, status_id: String) -> bool:
	if member_index < 0 or member_index >= party.size():
		return false
	return ((party[member_index] as Dictionary).get("statuses", {}) as Dictionary).has(status_id)


func get_statuses(member_index: int) -> Array:
	if member_index < 0 or member_index >= party.size():
		return []
	return ((party[member_index] as Dictionary).get("statuses", {}) as Dictionary).keys()


## params: parametry statusu zapisywane z nim (trucizna: {"mode": "percent" | "fixed", "amount": float}); czas w turach
## losowany z definicji statusu. Już nałożony status nie zmienia się (false).
func add_status(member_index: int, status_id: String, params: Dictionary = {}) -> bool:
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size() or has_status(member_index, status_id):
		return false
	var member: Dictionary = party[member_index]
	var st: Dictionary = member.get("statuses", {})
	var data: Dictionary = params.duplicate()
	var def := QuizRpgStatusCatalog.get_status(status_id)
	data["turns"] = def.roll_turns() if def else 0
	st[status_id] = data
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


## Odpoczynek (karczma NPC): cała drużyna do pełna — HP (także nieprzytomni), SP, bez statusów. TP bez zmian.
func rest_party() -> void:
	_ensure_party_defaults()
	for i in range(party.size()):
		_set_member_hp(i, _member_max_hp(i))
		var m: Dictionary = party[i]
		m["sp"] = int(m.get("max_sp", 0))
		m["statuses"] = {}
		party[i] = m
	party_changed.emit()


## Wszystkie znane statusy {id, name} posortowane po nazwie (menu deweloperskie).
func get_status_catalog() -> Array:
	var out: Array = []
	for sid in QuizRpgStatusCatalog.all_ids():
		out.append({"id": String(sid), "name": QuizRpgStatusCatalog.name_of(String(sid))})
	out.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
	return out


func any_status(status_id: String) -> bool:
	for i in range(party.size()):
		if has_status(i, status_id):
			return true
	return false


## Koniec rundy walki: zmiana HP od statusów (trucizna, regeneracja — QuizRpgStatusData.turn_hp_percent; trucizna
## może zbić do 0) i odliczanie tur (wygasłe znikają). Zwraca zdarzenia {member, status, hp (zmiana)} i
## {member, status, expired: true}.
func tick_statuses_combat() -> Array:
	var out: Array = []
	for i in range(party.size()):
		var st: Dictionary = (party[i] as Dictionary).get("statuses", {})
		for sid in st.keys():
			var def := QuizRpgStatusCatalog.get_status(String(sid))
			if def == null or _member_hp(i) <= 0:
				continue
			var delta := 0
			if def.turn_hp_percent < 0.0 and not _god_mode():
				var dmg := _poison_combat_damage(i) if sid == STATUS_POISON else maxi(ceili(_member_max_hp(i) * -def.turn_hp_percent), 1)
				delta = -mini(dmg, _member_hp(i))
			elif def.turn_hp_percent > 0.0:
				delta = mini(maxi(ceili(_member_max_hp(i) * def.turn_hp_percent), 1), _member_max_hp(i) - _member_hp(i))
			if delta != 0:
				_set_member_hp(i, _member_hp(i) + delta)
				out.append({"member": i, "status": String(sid), "hp": delta})
				if delta < 0:
					status_tick.emit(i, String(sid), -delta)
		for sid in st.keys():
			var data: Variant = st[sid]
			if data is Dictionary and int((data as Dictionary).get("turns", 0)) > 0:
				data["turns"] = int(data["turns"]) - 1
				if int(data["turns"]) <= 0:
					st.erase(sid)
					out.append({"member": i, "status": String(sid), "expired": true})
		var member: Dictionary = party[i]
		member["statuses"] = st
		party[i] = member
	if not out.is_empty():
		party_changed.emit()
	return out


## Koniec walki: znikają statusy bez persists_after_battle (zostaje np. trucizna).
func clear_battle_statuses() -> void:
	var changed := false
	for i in range(party.size()):
		var st: Dictionary = (party[i] as Dictionary).get("statuses", {})
		for sid in st.keys():
			var def := QuizRpgStatusCatalog.get_status(String(sid))
			if def == null or not def.persists_after_battle:
				st.erase(sid)
				changed = true
	if changed:
		party_changed.emit()


## Iloczyn mnożników statu (atk / def / mat / mdf) ze statusów członka (buffy, debuffy).
func member_status_mult(member_index: int, stat: String) -> float:
	var m := 1.0
	for sid in get_statuses(member_index):
		var def := QuizRpgStatusCatalog.get_status(String(sid))
		if def:
			m *= def.stat_mult(stat)
	return m


func member_hit_mult(member_index: int) -> float:
	var m := 1.0
	for sid in get_statuses(member_index):
		var def := QuizRpgStatusCatalog.get_status(String(sid))
		if def:
			m *= def.hit_mult
	return m


## Czy członek ma status z ograniczeniem (QuizRpgStatusData.Restriction) — np. sen pomija turę, cisza blokuje umiejętności.
func member_has_restriction(member_index: int, restriction: int) -> bool:
	for sid in get_statuses(member_index):
		var def := QuizRpgStatusCatalog.get_status(String(sid))
		if def and def.restriction == restriction:
			return true
	return false


## Obrażenia mogą zdjąć status (sen zawsze, zamroczenie w połowie przypadków). Zwraca zdjęte.
func on_member_damaged(member_index: int) -> Array:
	var gone: Array = []
	for sid in get_statuses(member_index):
		var def := QuizRpgStatusCatalog.get_status(String(sid))
		if def and def.remove_on_damage_chance > 0.0 and randf() < def.remove_on_damage_chance:
			gone.append(String(sid))
	if not gone.is_empty():
		cure_statuses(member_index, gone)
	return gone


## Obrażenia trucizny członka na rundę walki: z parametrów nadanych przez umiejętność (procent maks. HP albo stała),
## domyślnie turn_hp_percent statusu trucizny; co najmniej 1.
func _poison_combat_damage(i: int) -> int:
	var p: Variant = ((party[i] as Dictionary).get("statuses", {}) as Dictionary).get(STATUS_POISON)
	if p is Dictionary:
		var amount := float((p as Dictionary).get("amount", 0.0))
		if amount > 0.0:
			if String((p as Dictionary).get("mode", "percent")) == "fixed":
				return maxi(roundi(amount), 1)
			return maxi(ceili(_member_max_hp(i) * amount / 100.0), 1)
	var def := QuizRpgStatusCatalog.get_status(STATUS_POISON)
	return maxi(ceili(_member_max_hp(i) * (absf(def.turn_hp_percent) if def else 0.05)), 1)


## Trucizna w eksploracji: co POISON_WORLD_INTERVAL s (tylko w stanie EXPLORING — pauza, walka, menu wstrzymują)
## tyle HP co w rundzie walki (_poison_combat_damage), najwyżej do 1 HP (poza walką nie zabija).
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
			var dmg := mini(_poison_combat_damage(i), cur - 1)
			_set_member_hp(i, cur - dmg)
			status_tick.emit(i, STATUS_POISON, dmg)
			hit = true
	if hit:
		party_changed.emit()


func _god_mode() -> bool:
	var cheat_service := get_node_or_null("/root/CheatService")
	return cheat_service != null and "god_mode" in cheat_service and bool(cheat_service.god_mode)


## Nazwa statusu do wyświetlenia (resources/statuses/), inaczej sam identyfikator.
func status_name(id: String) -> String:
	return QuizRpgStatusCatalog.name_of(id)


func _member_hp(i: int) -> int:
	return hp if i == hero_index() else int((party[i] as Dictionary).get("hp", 0))


func _member_max_hp(i: int) -> int:
	return max_hp if i == hero_index() else int((party[i] as Dictionary).get("max_hp", 1))


func _set_member_hp(i: int, v: int) -> void:
	if i == hero_index():
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


## Obrażenia członka drużyny (umiejętności wrogów celujące w drużynę); bohater przez take_damage (tryb boga).
func damage_member(member_index: int, amount: int) -> void:
	if member_index == hero_index():
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
	var hi := hero_index()
	for i in range(party.size()):
		if i != hi and int((party[i] as Dictionary).get("hp", 0)) > 0:
			return false
	return true


func _recalculate_max_hp() -> void:
	var hero: QuizRpgHeroData = hero_party_data[0] if not hero_party_data.is_empty() and hero_party_data[0] != null else QuizRpgHeroData.new()
	max_hp = hero.hp_for_level(level, MAX_LEVEL)


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
		"hp": hp, "max_hp": max_hp, "points": points, "gold": gold,
		"streak": streak, "best_streak": best_streak,
		"total_correct": total_correct, "total_wrong": total_wrong,
		"rewards": rewards.duplicate(), "rng_bonus": rng_bonus,
		"inventory": inventory.duplicate(true),
		"party": party.duplicate(true),
		"companion_quests": companion_quests.duplicate(true),
		"quests": quests.duplicate(true),
		"enemy_kills": enemy_kills.duplicate(),
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
	gold          = maxi(int(data.get("gold", 0)), 0)
	streak        = data.get("streak", 0)
	best_streak   = data.get("best_streak", 0)
	total_correct = data.get("total_correct", 0)
	total_wrong   = data.get("total_wrong", 0)
	rewards.assign(data.get("rewards", []))
	rng_bonus     = data.get("rng_bonus", 0.0)
	inventory = _to_dictionary_array(data.get("inventory", inventory.duplicate(true)))
	party = _to_dictionary_array(data.get("party", party.duplicate(true)))
	var no_slots: Array[int] = []  # zapis sprzed slotów umiejętności
	for i in range(party.size()):
		if not party[i].has("loadout"):
			no_slots.append(i)
	var cq: Variant = data.get("companion_quests", {})
	companion_quests = (cq as Dictionary).duplicate(true) if cq is Dictionary else {}
	var qs: Variant = data.get("quests", {})
	quests = (qs as Dictionary).duplicate(true) if qs is Dictionary else {}
	var kills: Variant = data.get("enemy_kills", {})
	enemy_kills = (kills as Dictionary).duplicate() if kills is Dictionary else {}
	_normalize_inventory()
	_ensure_party_defaults()
	_sync_primary_party_member()
	for i in no_slots:
		_autofill_loadout(i)
	learn_level_skills()


func reset() -> void:
	player_name = "Bohater" ; level = 1 ; xp = 0
	_recalculate_max_hp()
	hp = max_hp ; points = 0 ; gold = 0 ; streak = 0
	best_streak = 0 ; total_correct = 0 ; total_wrong = 0
	rewards.clear() ; rng_bonus = 0.0
	inventory = [
		{"item_id": "potion", "count": 2},
		{"item_id": "ether", "count": 1},
		{"item_id": "antidote", "count": 1},
	]
	party.clear()
	companion_quests.clear()
	quests.clear()
	enemy_kills.clear()
	_normalize_inventory()
	_ensure_party_defaults()
	_sync_primary_party_member()
	learn_level_skills()  # skille z lv 1 (Skan, Uleczenie, Ciężki Cios) od startu nowej gry, nie po pierwszym awansie


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


## Pokonany wróg (po wygranej walce, każdy wróg grupy) — liczniki dla zadań NPC.
func record_kill(enemy_id: String) -> void:
	if enemy_id != "":
		enemy_kills[enemy_id] = int(enemy_kills.get(enemy_id, 0)) + 1
	enemy_kills[ALL_KILLS] = int(enemy_kills.get(ALL_KILLS, 0)) + 1
	quests_changed.emit()


## Ilu wrogów pokonano: `target` = id (rat_base), prefiks z gwiazdką (rat_* — wszystkie szczury) albo pusty = wszyscy.
func kill_count(target: String = "") -> int:
	if target == "" or target == ALL_KILLS:
		return int(enemy_kills.get(ALL_KILLS, 0))
	if not target.ends_with("*"):
		return int(enemy_kills.get(target, 0))
	var prefix := target.trim_suffix("*")
	var n := 0
	for id: String in enemy_kills:
		if id != ALL_KILLS and id.begins_with(prefix):
			n += int(enemy_kills[id])
	return n


## Liczba sztuk przedmiotu w ekwipunku (0 = brak / nieznany).
func get_item_count(item_ref: String) -> int:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("resolve_item_id"):
		return 0
	var item_id: String = inventory_service.call("resolve_item_id", item_ref)
	for entry: Dictionary in inventory_service.call("normalize_inventory", inventory):
		if str(entry.get("item_id", "")) == item_id:
			return int(entry.get("count", 0))
	return 0


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
	return use_item_on_member(item_ref, hero_index())


## Powód blokady przedmiotu dla członka ("" = można użyć): przedmiot odnawiający HP / SP / TP albo leczący status, który
## nic by nie dał — wszystko, co odnawia, jest pełne, a statusu do wyleczenia brak. Przedmioty bez takich efektów — "".
## values: wartości z walki ("sp", "max_sp", "tp", "max_tp" — walka trzyma SP / TP u siebie); reszta z drużyny.
func item_block_reason(item_ref: String, member_index: int, values: Dictionary = {}) -> String:
	var inventory_service: Node = _get_inventory_service()
	var item: QuizRpgItemData = inventory_service.call("get_item", item_ref) if inventory_service else null
	if item == null or member_index < 0 or member_index >= party.size():
		return ""
	var heals := item.heal_amount > 0 or item.heal_percent > 0.0
	var sp := item.sp_restore > 0 or item.sp_percent > 0.0
	var tp := item.tp_restore > 0
	var cures := not item.cure_statuses.is_empty()
	if not (heals or sp or tp or cures):
		return ""
	var m: Dictionary = party[member_index]
	var max_hp_m := max_hp if is_hero(member_index) else int(m.get("max_hp", 1))
	if heals and member_hp(member_index) < max_hp_m:
		return ""
	if sp and int(values.get("sp", m.get("sp", 0))) < int(values.get("max_sp", m.get("max_sp", 1))):
		return ""
	if tp and int(values.get("tp", m.get("tp", 0))) < int(values.get("max_tp", m.get("max_tp", 1))):
		return ""
	if cures:
		var have := get_statuses(member_index)
		for sid in item.cure_statuses:
			if have.has(String(sid)):
				return ""
	var who := {"name": str(m.get("name", player_name))}
	if heals and not (sp or tp or cures):
		return QuizRpgI18n.tf("party.item_full_hp", who, "{name}: HP jest pełne.")
	if sp and not (heals or tp or cures):
		return QuizRpgI18n.tf("party.item_full_sp", who, "{name}: SP jest pełne.")
	if tp and not (heals or sp or cures):
		return QuizRpgI18n.tf("party.item_full_tp", who, "{name}: TP jest pełne.")
	if cures and not (heals or sp or tp):
		return QuizRpgI18n.tf("party.item_nothing_to_cure", who, "{name}: nie ma czego leczyć.")
	return QuizRpgI18n.tf("party.item_no_effect", who, "{name}: przedmiot nic by nie dał.")


## Użycie przedmiotu na członku. Przedmiot, który nic by nie dał (item_block_reason), nie jest zużywany —
## {"success": false, "blocked": true, "message": powód}. values — jak w item_block_reason (walka).
func use_item_on_member(item_ref: String, member_index: int, values: Dictionary = {}) -> Dictionary:
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("use_item"):
		return {"success": false, "message": QuizRpgI18n.t("inventory.service_unavailable", "InventoryService niedostępny.")}
	_ensure_party_defaults()
	if member_index < 0 or member_index >= party.size():
		return {"success": false, "message": QuizRpgI18n.t("party.invalid_target", "Nieprawidłowy cel.")}
	var item_data: QuizRpgItemData = inventory_service.call("get_item", item_ref)
	if item_data == null:
		return {"success": false, "message": QuizRpgI18n.t("inventory.unknown_item", "Nieznany przedmiot.")}
	var block := item_block_reason(item_ref, member_index, values)
	if block != "":
		return {"success": false, "blocked": true, "message": block}
	var consume_result: Dictionary = inventory_service.call("consume_item_from_inventory", inventory, item_ref, 1)
	if not bool(consume_result.get("success", false)):
		return {"success": false, "message": QuizRpgI18n.t("inventory.no_item", "Brak przedmiotu.")}
	inventory = consume_result.get("inventory", inventory)
	var member: Dictionary = party[member_index]
	# Ile faktycznie (stałe + procent od maks.; SP w walce od maks. SP walki — values).
	var hp_gain := item_data.hp_restore_for(int(member.get("max_hp", 1)))
	var sp_gain := item_data.sp_restore_for(int(values.get("max_sp", member.get("max_sp", 1))))
	if hp_gain > 0:
		member["hp"] = mini(int(member.get("hp", 0)) + hp_gain, int(member.get("max_hp", 1)))
	if sp_gain > 0:
		member["sp"] = mini(int(member.get("sp", 0)) + sp_gain, int(member.get("max_sp", 1)))
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
	if member_index == hero_index():
		hp = int(member.get("hp", hp))
		max_hp = int(member.get("max_hp", max_hp))
		hp_changed.emit(hp, max_hp)
	inventory_changed.emit()
	party_changed.emit()
	var result: Dictionary = {
		"success": true,
		"inventory": inventory.duplicate(true),
		"item_id": item_data.item_id,
		"name": item_data.localized_name(),
		"description": item_data.localized_description(),
		"heal_amount": hp_gain,
		"sp_restore": sp_gain,
		"tp_restore": item_data.tp_restore,
		"cured_statuses": cured,
		"usable_in_menu": item_data.usable_in_menu,
		"usable_in_combat": item_data.usable_in_combat,
		"message": "%s: %s" % [item_data.localized_name(), item_data.get_effect_summary()] if item_data.get_effect_summary() != "" else QuizRpgI18n.tf("inventory.used_item", {"item": item_data.localized_name()}, "Użyto {item}."),
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
	var fallback := str(EQUIPMENT_LABELS.get(slot_name, slot_name.capitalize()))
	return QuizRpgI18n.t("equip.slot." + slot_name, fallback)


## Staty członka: wartość z poziomu (ATK / DEF / MAT / MDF — skala FNaFB, QuizRpgStatScale.stat; AGI — baza + poziom × przyrost)
## + bonusy ekwipunku (<stat>_bonus przedmiotów).
const STATS: Array[String] = ["atk", "def", "mat", "mdf", "agi"]


func get_member_total_stat(member_index: int, stat: String) -> int:
	if member_index < 0 or member_index >= party.size():
		return 0
	var member: Dictionary = party[member_index]
	var per_level := float(member.get(stat + "_per_level", 0.0))
	var total: int
	if stat == "agi":
		total = int(member.get("base_" + stat, 0)) + _get_member_level_bonus(member, per_level)
	else:
		total = roundi(QuizRpgStatScale.stat(float(member.get("base_" + stat, 0)), per_level, int(member.get("level", 1))))
	for slot_name: String in EQUIPMENT_SLOTS:
		total += int(_get_equipped_stat_bonus(member, slot_name, stat + "_bonus"))
	return total


func get_member_total_atk(member_index: int) -> int:
	return get_member_total_stat(member_index, "atk")


func get_member_total_def(member_index: int) -> int:
	return get_member_total_stat(member_index, "def")


func get_member_total_mat(member_index: int) -> int:
	return get_member_total_stat(member_index, "mat")


func get_member_total_mdf(member_index: int) -> int:
	return get_member_total_stat(member_index, "mdf")


func get_member_total_agi(member_index: int) -> int:
	return get_member_total_stat(member_index, "agi")


## Klasa członka (starsze zapisy bez pola: z danych jego postaci).
func get_member_class(member_index: int) -> String:
	if member_index < 0 or member_index >= party.size():
		return "warrior"
	var member: Dictionary = party[member_index]
	var c := str(member.get("character_class", ""))
	return c if c != "" else hero_for_member(member).character_class


## Czy członek może założyć przedmiot (allowed_classes pusta = każdy).
func member_can_equip(member_index: int, allowed_classes: PackedStringArray) -> bool:
	return allowed_classes.is_empty() or allowed_classes.has(get_member_class(member_index))


func get_equippable_entries_for_slot(member_index: int, slot_name: String) -> Array[Dictionary]:
	var inventory_entries: Array[Dictionary] = get_inventory_entries()
	var options: Array[Dictionary] = []
	var worn_id := ""  # założony przedmiot jest na liście osobno — ta sama rzecz z plecaka byłaby zamianą na identyczną kopię
	var spare := 0     # ile takich samych sztuk leży w plecaku (pokazane przy założonym)
	if member_index >= 0 and member_index < party.size():
		worn_id = str(((party[member_index] as Dictionary).get("equipment", {}) as Dictionary).get(slot_name, ""))
	for entry: Dictionary in inventory_entries:
		if str(entry.get("item_id", "")) == worn_id:
			spare = int(entry.get("count", 0))
			continue
		if str(entry.get("equip_slot", "")) == slot_name and member_can_equip(member_index, entry.get("allowed_classes", PackedStringArray())):
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
						"name": item_data.localized_name(),
						"description": item_data.localized_description(),
						"count": 1,
						"category": item_data.category,
						"equip_slot": item_data.equip_slot,
						"icon": item_data.icon,
						"atk_bonus": item_data.atk_bonus,
						"def_bonus": item_data.def_bonus,
						"mat_bonus": item_data.mat_bonus,
						"mdf_bonus": item_data.mdf_bonus,
						"agi_bonus": item_data.agi_bonus,
						"equipped": true,
						"spare_count": spare,
					})
	var empty_entry: Dictionary = {
		"item_id": "",
		"name": QuizRpgI18n.t("equip.empty_slot_name", "(puste)"),
		"description": QuizRpgI18n.t("equip.empty_slot_desc", "Zdejmij wyposażenie z tego slotu."),
		"count": 1,
		"equip_slot": slot_name,
		"atk_bonus": 0,
		"def_bonus": 0,
		"mat_bonus": 0,
		"mdf_bonus": 0,
		"agi_bonus": 0,
	}
	options.insert(0, empty_entry)
	return options


## Rodzaj broni założonej przez członka ("" = brak broni albo broń bez rodzaju).
func get_member_weapon_type(member_index: int) -> String:
	if member_index < 0 or member_index >= party.size():
		return ""
	var weapon_id: String = str(((party[member_index] as Dictionary).get("equipment", {}) as Dictionary).get("weapon", ""))
	if weapon_id == "":
		return ""
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("get_item"):
		return ""
	var item_data: QuizRpgItemData = inventory_service.call("get_item", weapon_id)
	return item_data.weapon_type if item_data and item_data.weapon_type != "none" else ""


## Czy członek spełnia wymaganie broni umiejętności (wpis z QuizRpgSkillData.to_entry): brak wymagania albo pasujący rodzaj.
func member_meets_weapon_requirement(member_index: int, entry: Dictionary) -> bool:
	var required := str(entry.get("required_weapon_type", "none"))
	return required == "" or required == "none" or get_member_weapon_type(member_index) == required


## Użycie umiejętności z consumes_weapon: założona broń znika (nie wraca do plecaka). Zwraca true, gdy coś zniszczono.
func consume_member_weapon(member_index: int) -> bool:
	if member_index < 0 or member_index >= party.size():
		return false
	var member: Dictionary = party[member_index]
	var equipment: Dictionary = (member.get("equipment", {}) as Dictionary).duplicate(true)
	if str(equipment.get("weapon", "")) == "":
		return false
	equipment["weapon"] = ""
	member["equipment"] = equipment
	party[member_index] = member
	party_changed.emit()
	return true


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
		if item_data == null or item_data.equip_slot != slot_name or not member_can_equip(member_index, item_data.effective_classes()):
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
	_fit_loadout(member_index)  # akcesorium mogło zmienić budżet slotów
	inventory_changed.emit()
	party_changed.emit()
	return true


## Zamienia założony przedmiot na inny bez przechodzenia przez ekwipunek (ulepszenie broni u kowala: etap N -> N+1).
func replace_equipped_item(member_index: int, slot_name: String, new_item_id: String) -> bool:
	if member_index < 0 or member_index >= party.size() or not EQUIPMENT_SLOTS.has(slot_name):
		return false
	var member: Dictionary = party[member_index]
	var equipment: Dictionary = member.get("equipment", {}).duplicate(true)
	if str(equipment.get(slot_name, "")) == "":
		return false
	equipment[slot_name] = new_item_id
	member["equipment"] = equipment
	party[member_index] = member
	_fit_loadout(member_index)
	party_changed.emit()
	return true


## Ocena przedmiotu przy automatycznym doborze: główna statystyka ataku klasy (ATK dla wojownika i łotrzyka,
## MAT dla maga i kapłana) liczy się w całości, druga w połowie; DEF i MDF w całości, AGI w połowie.
func _equipment_score(entry: Dictionary, magic_class: bool) -> float:
	var atk := float(entry.get("atk_bonus", 0))
	var mat := float(entry.get("mat_bonus", 0))
	var offense := (mat + 0.5 * atk) if magic_class else (atk + 0.5 * mat)
	return offense + float(entry.get("def_bonus", 0)) + float(entry.get("mdf_bonus", 0)) + 0.5 * float(entry.get("agi_bonus", 0))


func optimize_member_equipment(member_index: int) -> void:
	if member_index < 0 or member_index >= party.size():
		return
	var char_class: String = str(party[member_index].get("character_class", ""))
	if char_class == "":
		char_class = hero_for_member(party[member_index]).character_class
	var magic_class: bool = char_class == "mage" or char_class == "priest"
	for slot_name: String in EQUIPMENT_SLOTS:
		var best_item_id: String = ""
		var best_score: float = -999999.0
		var options: Array[Dictionary] = get_equippable_entries_for_slot(member_index, slot_name)
		for entry: Dictionary in options:
			var score: float = _equipment_score(entry, magic_class)
			if score > best_score:
				best_score = score
				best_item_id = str(entry.get("item_id", ""))
		set_member_equipment(member_index, slot_name, best_item_id)


func clear_member_equipment(member_index: int) -> void:
	if member_index < 0 or member_index >= party.size():
		return
	for slot_name: String in EQUIPMENT_SLOTS:
		set_member_equipment(member_index, slot_name, "")


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
		var loadout := {}  # sloty: tiery jako int (JSON zapisuje liczby jako float)
		for id in (member.get("loadout") if member.get("loadout") is Dictionary else {}):
			loadout[str(id)] = int(member.loadout[id])
		member["loadout"] = loadout
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
		# brakujące staty (stary zapis, nowe staty jak MAT / MDF) — z danych postaci
		var hero := hero_for_member(member)
		for stat in STATS:
			if not member.has("base_" + stat) and hero:
				member["base_" + stat] = int(hero.get("base_" + stat))
			if not member.has(stat + "_per_level") and hero:
				member[stat + "_per_level"] = float(hero.get(stat + "_per_level"))
		# Pola wizualne z danych postaci — zapis (JSON) zamienia zasoby i Vector2 na napisy.
		if not (member.get("portrait") is Texture2D):
			member["portrait"] = hero.portrait if hero else null
		if not (member.get("actor_scene") is PackedScene):
			member["actor_scene"] = hero.actor_scene if hero else null
		if not (member.get("sprite_frames") is SpriteFrames):
			member["sprite_frames"] = hero.sprite_frames if hero else null
		if not (member.get("sprite_offset") is Vector2):
			member["sprite_offset"] = hero.sprite_offset if hero else Vector2.ZERO
		if not member.has("xp"):
			member["xp"] = 0
		if not (member.get("body_color") is Color):
			member["body_color"] = hero.body_color if hero else Color(0.2, 0.6, 1.0)
		party[index] = member
		_sync_member_max_sp(index)


func _sync_primary_party_member() -> void:
	_ensure_party_defaults()
	if party.is_empty():
		return
	var hi := hero_index()
	var member: Dictionary = party[hi]
	member["name"] = player_name
	member["level"] = level
	member["hp"] = hp
	member["max_hp"] = max_hp
	party[hi] = member
	_sync_member_max_sp(hi)


## Maks. SP członka z krzywej postaci (hero.sp_for_level); awans zwiększa tylko maksimum (bieżące SP bez zmian).
func _sync_member_max_sp(index: int) -> void:
	if index < 0 or index >= party.size():
		return
	var member: Dictionary = party[index]
	var hero := hero_for_member(member)
	if hero == null:
		return
	var new_max := hero.sp_for_level(int(member.get("level", 1)), MAX_LEVEL)
	var old_max := int(member.get("max_sp", new_max))
	if new_max == old_max and member.has("sp"):
		return
	member["max_sp"] = new_max
	member["sp"] = clampi(int(member.get("sp", new_max)), 0, new_max)
	party[index] = member


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
