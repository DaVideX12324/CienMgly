extends QuizRpgSkillBase
class_name QuizRpgSkillData

## Umiejętność postaci drużyny (obrażenia, cel, leczenie, status — QuizRpgSkillBase). Pula postaci:
## QuizRpgHeroData.skills (kolejność = kolejność w menu); odblokowane — id w member["skills"]. Podstawowe postać zna
## sama od learn_level; zaawansowane (learn_level 0) uczą NPC-e, którym wracają wspomnienia, albo zdarzenia
## (PlayerStats.unlock_skill). W walce i menu umiejętność to słownik z to_entry() (z zasobem pod "resource").

## Kiedy można użyć (jak „Occasion” w RPG Makerze / FNaFB: leczenie zwykle „zawsze” — także w menu pauzy).
enum Occasion { ALWAYS, BATTLE, MENU, NEVER }

@export var skill_id: String = ""
@export_range(0, 999, 1) var sp_cost: int = 0
## Koszt jako część maks. SP użytkownika (np. 0.24 jak „Custom MP Cost” w FNaFB CC); gdy > 0, zastępuje sp_cost.
@export_range(0.0, 1.0, 0.01) var sp_cost_percent: float = 0.0
@export_range(0, 100, 1) var tp_cost: int = 0
@export var occasion: Occasion = Occasion.BATTLE
## Poziom, od którego postać zna umiejętność sama (0 = nie z poziomu: uczy NPC albo zdarzenie).
@export_range(0, 100, 1) var learn_level: int = 0
## Wymagany rodzaj broni w slocie "weapon" (QuizRpgItemData.weapon_type; "none" = bez wymagań) i czy użycie niszczy tę broń.
@export_enum("none", "sword", "dagger", "axe", "spear", "mace", "staff", "bow") var required_weapon_type: String = "none"
@export var consumes_weapon: bool = false
## Skan (jak w FNaFB CC): bez quizu i bez zużywania tury — pokazuje HP, statystyki i opis wybranego wroga w logu.
@export var scan: bool = false

@export_group("Tiery (sloty)")
## Tier startowy i najwyższy (QuizRpgSkillSlots): skill wolno ustawić na tierze od tier_min do min(tier_max, maks. tier
## członka z poziomu). Wyższy tier = mocniejsza wersja, droższa w budżecie slotów.
@export_range(1, 4, 1) var tier_min: int = 1
@export_range(1, 4, 1) var tier_max: int = 1
## Zmiany pól na wyższych tierach: {tier: {"pole": wartość}}, kumulatywnie od tier_min + 1 (np. {2: {"damage_multiplier": 1.8}}).
@export var tier_overrides: Dictionary = {}

## Pola opisywane w podsumowaniu tieru (tier_summary): procenty, mnożniki i liczby.
const _PERCENT_FIELDS := ["status_chance", "success_rate", "heal_percent"]
const _MULT_FIELDS := ["damage_multiplier", "bonus_multiplier", "heal_mat_coeff", "mat_coeff", "atk_coeff"]
static var _tier_cache := {}  # "ścieżka#tier" -> kopia z nałożonymi zmianami


## Wersja skilla na tierze (kopia z tier_overrides; tier_min i niżej albo bez zmian = ten sam zasób). Kopia pamięta
## ścieżkę źródła (meta source_path) — klucze tłumaczeń z nazwy pliku; at_tier na kopii liczy od źródła.
func at_tier(tier: int) -> QuizRpgSkillData:
	if resource_path == "" and has_meta(&"source_path"):
		var src := load(str(get_meta(&"source_path"))) as QuizRpgSkillData
		if src != null:
			return src.at_tier(tier)
	if tier <= tier_min or tier_overrides.is_empty():
		return self
	var key := "%s#%d" % [resource_path if resource_path != "" else str(get_instance_id()), tier]
	if _tier_cache.has(key):
		return _tier_cache[key]
	var copy := duplicate() as QuizRpgSkillData
	copy.set_meta(&"source_path", resource_path)
	for t in range(tier_min + 1, tier + 1):
		var changes: Dictionary = tier_overrides.get(t, {})
		for field: String in changes:
			copy.set(field, changes[field])
	_tier_cache[key] = copy
	return copy


## Krótki opis tego, co daje tier (np. „T2: obrażenia ×1,8 · trafienia 6”); pusty dla tier_min.
func tier_summary(tier: int) -> String:
	if tier <= tier_min:
		return ""
	var t := at_tier(tier)
	var parts: Array[String] = []
	var seen := {}
	for lvl in range(tier_min + 1, tier + 1):
		for field: String in tier_overrides.get(lvl, {}):
			seen[field] = true
	for field: String in seen:
		var v: Variant = t.get(field)
		var label := QuizRpgI18n.t("skill.tier_field." + field, field)
		if field == "target":
			parts.append(QuizRpgI18n.t("skill.tier_target.%d" % int(v), str(v)))
		elif _PERCENT_FIELDS.has(field):
			parts.append("%s %d%%" % [label, roundi(float(v) * 100.0)])
		elif _MULT_FIELDS.has(field):
			parts.append("%s ×%s" % [label, String.num(float(v), 2).replace(".", QuizRpgI18n.t("skill.decimal_separator", ","))])
		else:
			parts.append("%s %d" % [label, int(v)])
	return "T%d: %s" % [tier, " · ".join(parts)]


## Koszt SP dla użytkownika o maks. SP max_sp (sp_cost_percent × max_sp w górę, inaczej sp_cost).
func sp_cost_for(max_sp: int) -> int:
	if sp_cost_percent > 0.0 and max_sp > 0:
		return maxi(ceili(max_sp * sp_cost_percent), 1)
	return sp_cost


func to_entry(max_sp: int = 0) -> Dictionary:
	return {
		"skill_id": skill_id,
		"name": localized_name(),
		"description": localized_description() + (" " + QuizRpgI18n.t("skill.requires_weapon", "Wymaga broni: %s%s.") % [QuizRpgItemData.weapon_type_name(required_weapon_type), QuizRpgI18n.t("skill.destroys_weapon", ", niszczy ją") if consumes_weapon else ""] if required_weapon_type != "none" else ""),
		"required_weapon_type": required_weapon_type,
		"consumes_weapon": consumes_weapon,
		"sp_cost": sp_cost_for(max_sp),
		"tp_cost": tp_cost,
		"effect": "heal" if is_heal() else "attack",
		"scan": scan,
		"usable_in_battle": occasion == Occasion.ALWAYS or occasion == Occasion.BATTLE,
		"usable_in_menu": occasion == Occasion.ALWAYS or occasion == Occasion.MENU,
		"resource": self,
	}
