@tool
class_name QuizRpgSkillLesson
extends Resource

## Lekcja u nauczyciela umiejętności: odblokowanie skill_id (z puli postaci, learn_level 0 — uczą NPC) za złoto
## i / albo przedmiot-żeton (np. „Skill Slip” z FNaFB za lv 5 / 10 / 15), od poziomu i flagi fabularnej.
## Waluta to dane — decyzja (złoto / żeton / sama flaga) nie wymaga zmian w kodzie.

@export var skill_id: String = ""
## Postać, której dotyczy (hero_id); pusta = każdy członek drużyny, który ma tę umiejętność w puli.
@export var hero_id: String = ""
@export var gold: int = 0
@export var item_id: String = ""
@export var item_count: int = 1
@export var min_level: int = 0
@export var required_flag: String = ""
