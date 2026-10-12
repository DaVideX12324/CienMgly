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
