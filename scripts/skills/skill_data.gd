extends Resource
class_name QuizRpgSkillData

## Umiejętność postaci drużyny. Pula postaci: QuizRpgHeroData.skills (kolejność = kolejność w menu); odblokowane
## (kupione u NPC — jak umiejętności u Balloon Boya w FNaFB) — id w member["skills"] (PlayerStats.unlock_skill).
## W walce i menu umiejętność to słownik z to_entry() (klucze jak dawne PlayerStats.skills).

enum Effect { ATTACK, HEAL, DEFEND }

@export var skill_id: String = ""
@export var display_name: String = "Umiejętność"
@export_multiline var description: String = ""
@export_range(0, 999, 1) var sp_cost: int = 0
@export_range(0, 100, 1) var tp_cost: int = 0
@export var effect: Effect = Effect.ATTACK
## Umiejętność combo (5. slot, za TP — game_design „System skilli”).
@export var combo: bool = false

@export_group("Atak")
## Mnożnik ciosu: (ATK × 4 − DEF celu × 2) × mnożnik.
@export_range(0.0, 10.0, 0.05) var damage_multiplier: float = 1.0

@export_group("Leczenie")
## Część maks. HP przywracana po dobrej / złej odpowiedzi w quizie.
@export_range(0.0, 1.0, 0.05) var heal_ratio_correct: float = 0.3
@export_range(0.0, 1.0, 0.05) var heal_ratio_wrong: float = 0.1


func to_entry() -> Dictionary:
	return {
		"skill_id": skill_id,
		"name": display_name,
		"description": description,
		"sp_cost": sp_cost,
		"tp_cost": tp_cost,
		"effect": ["attack", "heal", "defend"][effect],
		"combo": combo,
		"damage_multiplier": damage_multiplier,
		"heal_ratio_correct": heal_ratio_correct,
		"heal_ratio_wrong": heal_ratio_wrong,
	}
