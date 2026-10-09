extends CanvasLayer

## Ekran śmierci drużyny (decyzje usera 2026-10-09): po przegranej walce, gdy wszyscy członkowie drużyny mają 0 HP
## (PlayerStats.is_party_defeated). Wygląd w scenie `scenes/ui/death_screen.tscn` (edytowalna w edytorze — teksty,
## kolory, rozmiary); skrypt tylko wprowadza ekran (zaciemnienie i napisy od zera do wartości ze sceny) i obsługuje
## przyciski. Pauzuje grę (sam działa w pauzie) i ustawia stan GameManagera MENU — gracz się nie rusza, menu pauzy
## (Esc) się nie otwiera. „Wczytaj zapis”: bieżący slot, a bez niego najnowszy; nieaktywny bez zapisu. Postęp od
## ostatniego zapisu przepada (zapis ręczny w menu pauzy).

@export var fade_time := 1.2
@export var leave_immunity := 3.0   ## s: żaden wróg nie zaczyna walki w czasie przejścia sceny

var _buttons: Array[Button] = []
var _selected := 0
var _ready_for_input := false
var _leaving := false

@onready var _dim: ColorRect = %Dim
@onready var _box: Control = %Box
@onready var _load_button: Button = %LoadButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	var gm := _singleton("GameManager")
	if gm and gm.has_method("change_state"):
		gm.call("change_state", 0)   # GameState.MENU
	get_tree().paused = true
	_buttons = [_load_button, _menu_button]
	_load_button.pressed.connect(_on_load)
	_menu_button.pressed.connect(_on_main_menu)
	for b in _buttons:
		b.mouse_entered.connect(_on_hover.bind(b))
	_load_button.disabled = _load_slot() < 0
	if _load_button.disabled:
		_load_button.tooltip_text = "Brak zapisu"
	_selected = 1 if _load_button.disabled else 0
	_refresh_selection()
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("stop_music"):
		audio.call("stop_music", fade_time)
	var dim_a := _dim.color.a
	_dim.color.a = 0.0
	_box.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", dim_a, fade_time)
	tw.tween_property(_box, "modulate:a", 1.0, fade_time).set_delay(fade_time * 0.4)
	tw.chain().tween_callback(func() -> void: _ready_for_input = true)


func _on_hover(b: Button) -> void:
	if not b.disabled:
		_selected = _buttons.find(b)
		_refresh_selection()


func _refresh_selection() -> void:
	for i in range(_buttons.size()):
		QuizTheme.set_menu_item_selected(_buttons[i], i == _selected)
		_buttons[i].modulate.a = 0.45 if _buttons[i].disabled else 1.0


func _input(event: InputEvent) -> void:
	# Ekran zabiera całe wejście (menu pauzy i inne nasłuchujące _input nie reagują).
	get_viewport().set_input_as_handled()
	if not _ready_for_input or _leaving:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var step := -1 if event.is_action_pressed("ui_up") else 1
		for _i in range(_buttons.size()):
			_selected = posmod(_selected + step, _buttons.size())
			if not _buttons[_selected].disabled:
				break
		_refresh_selection()
		_click()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if not _buttons[_selected].disabled:
			_buttons[_selected].pressed.emit()


## Slot do wczytania: bieżący, gdy ma zapis, inaczej najnowszy; -1 = brak zapisu.
func _load_slot() -> int:
	var sm := _singleton("SaveManager")
	if sm == null:
		return -1
	var cur := int(sm.get("current_save_slot"))
	if cur >= 0 and bool(sm.call("save_exists", cur)):
		return cur
	return int(sm.call("find_latest_save_slot"))


func _on_load() -> void:
	var slot := _load_slot()
	var gm := _singleton("GameManager")
	if not _ready_for_input or _leaving or slot < 0 or gm == null:
		return
	_leave()
	gm.call("load_game", slot)


func _on_main_menu() -> void:
	var gm := _singleton("GameManager")
	if not _ready_for_input or _leaving or gm == null:
		return
	_leave()
	gm.call("return_to_main_menu")


## Wyjście: odpauzowanie (przejście sceny GameManagera to tween, w pauzie stoi), nietykalność gracza na czas
## zaciemnienia, ekran znika po chwili (przejście zasłania już ekran).
func _leave() -> void:
	_leaving = true
	_click()
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("grant_encounter_immunity"):
			p.call("grant_encounter_immunity", leave_immunity)
	get_tree().paused = false
	get_tree().create_timer(0.6, true).timeout.connect(queue_free)


func _click() -> void:
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_sfx_by_name"):
		audio.call("play_sfx_by_name", "click")


func _singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var s: Variant = core_manager.call("get_singleton", singleton_name)
		if s is Node:
			return s
	return get_node_or_null("/root/%s" % singleton_name)
