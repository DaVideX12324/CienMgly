extends Resource
class_name QuizRpgStatusData

## Status (stan) postaci lub wroga w walce — jak „States” w RPG Makerze / FNaFB: czas w turach, ograniczenie
## działania, mnożniki statów i trafienia, zmiana HP co turę, zdejmowanie obrażeniami. Pliki w resources/statuses/
## (QuizRpgStatusCatalog); nadają umiejętności (QuizRpgSkillBase.inflict_status), zdejmują przedmioty (cure_statuses).

## Ograniczenie: pomija turę (sen, ogłuszenie, paraliż), zamroczenie (losowy cel, wróg czasem bije swoich),
## cisza (bez umiejętności).
enum Restriction { NONE, SKIP_TURN, CONFUSED, SILENCED }

@export var status_id: String = ""
@export var display_name: String = "Status"
@export var color: Color = Color(0.8, 0.8, 0.8)

@export_group("Czas")
## Tury trwania (losowo min..max); 0 / 0 = do wyleczenia (np. trucizna drużyny).
@export_range(0, 20, 1) var min_turns: int = 3
@export_range(0, 20, 1) var max_turns: int = 3
## Zostaje po walce (trucizna); inne znikają z końcem walki.
@export var persists_after_battle: bool = false
## Szansa zdjęcia przy otrzymaniu obrażeń (sen 1.0, zamroczenie 0.5).
@export_range(0.0, 1.0, 0.05) var remove_on_damage_chance: float = 0.0

@export_group("Działanie")
@export var restriction: Restriction = Restriction.NONE
@export_range(0.0, 3.0, 0.05) var atk_mult: float = 1.0
@export_range(0.0, 3.0, 0.05) var def_mult: float = 1.0
@export_range(0.0, 3.0, 0.05) var mat_mult: float = 1.0
@export_range(0.0, 3.0, 0.05) var mdf_mult: float = 1.0
## Mnożnik szansy trafienia (oślepienie 0.4).
@export_range(0.0, 2.0, 0.05) var hit_mult: float = 1.0
## Zmiana HP na koniec rundy jako część maks. HP (trucizna −0.05, regeneracja +0.05); co najmniej 1.
@export_range(-1.0, 1.0, 0.01) var turn_hp_percent: float = 0.0


func roll_turns() -> int:
	if max_turns <= 0:
		return 0
	return randi_range(mini(min_turns, max_turns), max_turns)


func stat_mult(stat: String) -> float:
	match stat:
		"atk": return atk_mult
		"def": return def_mult
		"mat": return mat_mult
		"mdf": return mdf_mult
	return 1.0
