extends Resource
class_name QuizRpgSkillBase

## Wspólna część umiejętności gracza (QuizRpgSkillData) i wroga (QuizRpgEnemySkill): obrażenia jak w FNaFB
## (baza + ATK × a + MAT × m − DEF × d − MDF × md, × mnożnik — albo stałe), trafienia, szansa trafienia, cel,
## leczenie, status. Liczy QuizRpgSkillMath; cel względem użytkownika („przeciwnik” wroga to drużyna i odwrotnie).

enum DamageMode { FORMULA, FIXED, NONE }
enum Target { ONE_OPPONENT, ALL_OPPONENTS, RANDOM_OPPONENTS, SELF, ONE_ALLY, ALL_ALLIES, DEAD_ALLY }
enum HealMode { NONE, FIXED, PERCENT }
enum PoisonMode { PERCENT, FIXED }

@export var display_name: String = "Umiejętność"
@export_multiline var description: String = ""
@export var color: Color = Color(1.0, 0.55, 0.2)

@export_group("Obrażenia")
@export var damage_mode: DamageMode = DamageMode.FORMULA
## Wzór FNaFB: (base_damage + ATK × atk_coeff + MAT × mat_coeff − DEF × def_coeff − MDF × mdf_coeff) × damage_multiplier.
@export var base_damage: int = 0
@export_range(0.0, 20.0, 0.1) var atk_coeff: float = 4.0
@export_range(0.0, 20.0, 0.1) var mat_coeff: float = 0.0
@export_range(0.0, 20.0, 0.1) var def_coeff: float = 2.0
@export_range(0.0, 20.0, 0.1) var mdf_coeff: float = 0.0
@export_range(0.0, 10.0, 0.05) var damage_multiplier: float = 1.0
## Stałe obrażenia na trafienie (DamageMode.FIXED) — pancerz ich nie zmniejsza.
@export_range(0, 99999, 1) var fixed_damage: int = 10
## Rozrzut obrażeń ±(np. 0.2 = ±20 %).
@export_range(0.0, 1.0, 0.05) var variance: float = 0.1
@export_range(1, 20, 1) var hits: int = 1
## Odstęp między trafieniami serii (s).
@export_range(0.05, 2.0, 0.05) var hit_interval: float = 0.35
## Szansa trafienia każdego ciosu (jak „success rate” w RPG Makerze); u gracza mnożona z szansą z quizu.
@export_range(0.0, 1.0, 0.01) var success_rate: float = 1.0
## Obrona z dobrą odpowiedzią blokuje (0), ze złą — połowa; false = obrona nie działa.
@export var can_be_blocked: bool = true

@export_group("Cel")
@export var target: Target = Target.ONE_OPPONENT
## Liczba losowych celów (Target.RANDOM_OPPONENTS).
@export_range(1, 6, 1) var random_count: int = 1

@export_group("Leczenie")
@export var heal_mode: HealMode = HealMode.NONE
@export_range(0, 99999, 1) var heal_amount: int = 0
@export_range(0.0, 1.0, 0.05) var heal_percent: float = 0.3

@export_group("Status")
## Status nadawany celowi ("none" = brak) — status_id z resources/statuses/ (QuizRpgStatusCatalog).
@export_enum("none", "poison", "sleep", "stun", "paralysis", "blind", "confusion", "silence", "atk_up", "atk_down", "def_up", "def_down", "regen") var inflict_status: String = "none"
@export_range(0.0, 1.0, 0.05) var status_chance: float = 1.0
## Status losowany przy każdym trafieniu (inaczej raz po serii, gdy cokolwiek trafiło).
@export var status_per_hit: bool = false
## Trucizna: obrażenia na turę walki — procent maks. HP celu (PERCENT) albo stała liczba HP (FIXED).
@export var poison_mode: PoisonMode = PoisonMode.PERCENT
@export_range(0.5, 999.0, 0.5) var poison_amount: float = 5.0


func has_status() -> bool:
	return inflict_status != "" and inflict_status != "none"


func is_heal() -> bool:
	return heal_mode != HealMode.NONE


## Cel po stronie użytkownika (ja / sojusznik / drużyna / nieprzytomny) — wsparcie: leczenie i / albo status.
func targets_allies() -> bool:
	return not targets_opponents()


func targets_opponents() -> bool:
	return target == Target.ONE_OPPONENT or target == Target.ALL_OPPONENTS or target == Target.RANDOM_OPPONENTS


## Parametry nadawanego statusu dla PlayerStats.add_status (puste = domyślne).
func status_params() -> Dictionary:
	if inflict_status == "poison":
		return {"mode": "fixed" if poison_mode == PoisonMode.FIXED else "percent", "amount": poison_amount}
	return {}
