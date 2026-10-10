extends QuizRpgSkillBase
class_name QuizRpgEnemySkill

## Umiejętność wroga w walce (lista `battle_skills` wroga / QuizRpgEnemyData; obrażenia, cel, leczenie, status —
## QuizRpgSkillBase). W turze wroga umiejętności sprawdzane po kolei: dostępna (cooldown, pierwsza tura) i wylosowana
## z `use_chance` -> użyta zamiast zwykłego ataku; żadna -> zwykły atak. Cel „przeciwnik” = drużyna, „sojusznik” = wrogowie.

## Tekst w logu walki: {enemy} = nazwa wroga, {skill} = nazwa umiejętności. Pusty -> „{enemy} używa: {skill}!”.
@export var log_text: String = ""
@export_range(0.0, 1.0, 0.05) var use_chance: float = 0.3
## Tur wroga, przez które po użyciu umiejętność nie wraca (0 = może być co turę).
@export_range(0, 20, 1) var cooldown_turns: int = 0
## Najwcześniejsza tura walki, w której wróg może jej użyć.
@export_range(1, 50, 1) var first_turn: int = 1
