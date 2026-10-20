class_name QuizRpgSecretPassage
extends Area2D

## Przejście do sekretnego pokoju w niszy out (NicheContentPlanner, rodzaj "secret_room"): ciemny prześwit w głębi niszy
## i mgła ciągnąca z niego. Klawisz interakcji (gracz, grupa "interactable") woła on_enter — ustawia je ProceduralLevel
## (_apply_niche_content): zmiana poziomu na osobną mapę z argumentem (ten poziom i kratka niszy). Powrót: wejście
## sekretnego pokoju prowadzi do markera przed niszą.

@export var unique_id: String = ""
## Wywoływane przy interakcji; puste = przejście nieczynne (brak podpowiedzi).
var on_enter: Callable = Callable()

## Kratka niszy (kotwica obiektu) z unique_id "<id>_<x>_<y>" (ObjectRealizer).
var niche_cell: Vector2i:
	get:
		var p := unique_id.split("_")
		return Vector2i(int(p[-2]), int(p[-1])) if p.size() >= 3 else Vector2i.ZERO


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("secret_passages")


func can_interact() -> bool:
	return on_enter.is_valid()


func interaction_prompt_text() -> String:
	return QuizRpgI18n.t("prompt.enter_secret", "Wejdź")


func interaction_prompt_offset() -> Vector2:
	return Vector2(0, -20)


func interact(_player: Node2D = null) -> void:
	if on_enter.is_valid():
		on_enter.call()
