class_name QuizRpgUiKeys
extends RefCounted

## Okna na fokusie Godota (menu główne, sklep, nauczyciel, kowal) chodzą na akcjach ui_* (strzałki / Enter / Esc).
## Klawisze akcji ruchu / zatwierdź / wstecz (domyślnie WASD / Z / X, zmienialne w Sterowaniu) zamieniane na te
## akcje — poza polem tekstowym, gdzie to zwykłe litery.
const ACTION_AS_UI := {&"move_up": &"ui_up", &"move_down": &"ui_down", &"move_left": &"ui_left", &"move_right": &"ui_right",
	&"menu_confirm": &"ui_accept", &"menu_cancel": &"ui_cancel"}


## true = zdarzenie zamienione (wołający oznacza je jako obsłużone).
static func forward(event: InputEvent, viewport: Viewport) -> bool:
	var key := event as InputEventKey
	if key == null:
		return false
	var target := &""
	for src: StringName in ACTION_AS_UI:
		if InputMap.has_action(src) and key.is_action(src):
			target = ACTION_AS_UI[src]
			break
	if target == &"" or key.is_action(target):  # klawisz już jest akcją ui_* (np. strzałka) — bez podwójnego ruchu
		return false
	var owner := viewport.gui_get_focus_owner()
	if owner is LineEdit or owner is TextEdit:
		return false
	var action := InputEventAction.new()
	action.action = target
	action.pressed = key.pressed
	Input.parse_input_event(action)
	return true
