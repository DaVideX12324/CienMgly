extends Resource
class_name QuizRpgEnemySkill

## Umiejętność wroga w walce (lista `battle_skills` wroga / QuizRpgEnemyData). W turze wroga umiejętności sprawdzane
## po kolei: dostępna (cooldown, pierwsza tura) i wylosowana z `use_chance` -> użyta zamiast zwykłego ataku; żadna ->
## zwykły atak. Obrażenia: mnożnik zwykłego ataku albo stała wartość, `hits` ataków w serii; status (np. trucizna,
## PlayerStats.add_status) z szansą raz na serię albo przy każdym trafieniu.

enum DamageMode { MULTIPLIER, FIXED, NONE }
enum Target { LEADER, RANDOM_MEMBER, ALL_PARTY }

@export var skill_name: String = "Umiejętność"
## Tekst w logu walki: {enemy} = nazwa wroga, {skill} = nazwa umiejętności. Pusty -> „{enemy} używa: {skill}!”.
@export var log_text: String = ""
@export_range(0.0, 1.0, 0.05) var use_chance: float = 0.3
## Tur wroga, przez które po użyciu umiejętność nie wraca (0 = może być co turę).
@export_range(0, 20, 1) var cooldown_turns: int = 0
## Najwcześniejsza tura walki, w której wróg może jej użyć.
@export_range(1, 50, 1) var first_turn: int = 1

@export_group("Obrażenia")
@export var damage_mode: DamageMode = DamageMode.MULTIPLIER
## Mnożnik zwykłego ataku wroga (DamageMode.MULTIPLIER), na każde trafienie.
@export_range(0.0, 10.0, 0.05) var damage_multiplier: float = 1.0
## Stałe obrażenia na trafienie (DamageMode.FIXED).
@export_range(0, 999, 1) var fixed_damage: int = 10
## Ataków w serii.
@export_range(1, 10, 1) var hits: int = 1
## Odstęp między atakami serii (s).
@export_range(0.05, 2.0, 0.05) var hit_interval: float = 0.35
@export var target: Target = Target.LEADER
## Obrona z poprawną odpowiedzią blokuje (0), z błędną — połowa; false = obrona nie działa.
@export var can_be_blocked: bool = true
## Pancerz (obrona ekwipunku) nie zmniejsza obrażeń.
@export var ignore_armor: bool = false

@export_group("Status")
## Status nadawany celowi ("none" = brak); id jak PlayerStats.STATUS_* (np. "poison").
@export_enum("none", "poison") var inflict_status: String = "none"
@export_range(0.0, 1.0, 0.05) var status_chance: float = 1.0
## Status losowany przy każdym trafieniu (inaczej raz po serii, gdy cokolwiek trafiło).
@export var status_per_hit: bool = false

@export_group("Wygląd")
@export var color: Color = Color(1.0, 0.55, 0.2)


func has_status() -> bool:
	return inflict_status != "" and inflict_status != "none"
