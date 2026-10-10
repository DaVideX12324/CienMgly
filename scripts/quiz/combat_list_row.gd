extends Button

## Wiersz listy umiejętności / przedmiotów (walka): nazwa = tekst przycisku, koszt / liczba po prawej
## (CostLabel). Wygląd i kolory kosztów w scenie combat_list_row.tscn; zaznaczenie — QuizTheme.set_menu_item_selected.

enum Kind { NONE, SP, TP, COUNT }

@export var sp_color := Color(0.45, 0.75, 1.0)
@export var tp_color := Color(0.55, 0.95, 0.45)
@export var count_color := Color(0.86, 0.88, 0.94)

@onready var _cost: Label = $CostLabel


func setup(title: String, cost_text: String, kind: Kind, is_disabled: bool) -> void:
	text = title
	disabled = is_disabled
	_cost.text = cost_text
	var col: Color = {Kind.SP: sp_color, Kind.TP: tp_color, Kind.COUNT: count_color}.get(kind, count_color)
	_cost.modulate = Color(col, 0.45) if is_disabled else col
