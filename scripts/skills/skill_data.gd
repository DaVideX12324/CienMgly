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
@export_range(0, 100, 1) var tp_cost: int = 0
@export var occasion: Occasion = Occasion.BATTLE
## Poziom, od którego postać zna umiejętność sama (0 = nie z poziomu: uczy NPC albo zdarzenie).
@export_range(0, 100, 1) var learn_level: int = 0
## Umiejętność combo (5. slot, za TP — game_design „System skilli”).
@export var combo: bool = false


func to_entry() -> Dictionary:
	return {
		"skill_id": skill_id,
		"name": display_name,
		"description": description,
		"sp_cost": sp_cost,
		"tp_cost": tp_cost,
		"effect": "heal" if is_heal() else "attack",
		"combo": combo,
		"usable_in_battle": occasion == Occasion.ALWAYS or occasion == Occasion.BATTLE,
		"usable_in_menu": occasion == Occasion.ALWAYS or occasion == Occasion.MENU,
		"resource": self,
	}
