extends CanvasLayer

## Ekran śmierci drużyny (decyzje usera 2026-10-09): po przegranej walce, gdy wszyscy członkowie drużyny mają 0 HP
## (PlayerStats.is_party_defeated). Wygląd w scenie `scenes/ui/death_screen.tscn` (edytowalna w edytorze — teksty,
## kolory, rozmiary); skrypt tylko wprowadza ekran (zaciemnienie i napisy od zera do wartości ze sceny) i obsługuje
## przyciski. Pauzuje grę (sam działa w pauzie) i ustawia stan GameManagera MENU — gracz się nie rusza, menu pauzy
## (Esc) się nie otwiera. „Wczytaj zapis”: bieżący slot, a bez niego najnowszy; nieaktywny bez zapisu. Postęp od
## ostatniego zapisu przepada (zapis ręczny w menu pauzy). „Wczytaj zapis” otwiera okno z listą zapisów (slotów) do wyboru;
## Esc / „Wróć” wraca do przycisków.

@export var fade_time := 1.2
@export var leave_immunity := 3.0   ## s: żaden wróg nie zaczyna walki w czasie przejścia sceny

var _buttons: Array[Button] = []
var _selected := 0
var _ready_for_input := false
var _leaving := false
var _menu_buttons: Array[Button] = []
var _in_slots := false

@onready var _dim: ColorRect = %Dim
@onready var _box: Control = %Box
@onready var _load_button: Button = %LoadButton
@onready var _menu_button: Button = %MenuButton
@onready var _menu_panel: Control = %Panel
@onready var _slots_panel: Control = %SlotsPanel
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	UiLayerScale.attach(self)  # skala UI z opcji na całą warstwę
	var gm := _singleton("GameManager")
	if gm and gm.has_method("change_state"):
		gm.call("change_state", 0)   # GameState.MENU
	get_tree().paused = true
	_buttons = [_load_button, _menu_button]
	_menu_buttons = _buttons.duplicate()
	_load_button.pressed.connect(_open_slots)
	_back_button.pressed.connect(_close_slots)
	_back_button.mouse_entered.connect(_on_hover.bind(_back_button))
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
	# Mysz idzie dalej do GUI (przyciski: najechanie / klik); to, co pod ekranem, zasłania pełnoekranowy Root
	# (mouse_filter STOP). Resztę wejścia ekran zabiera (menu pauzy i inne nasłuchujące _input nie reagują).
	if event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if not _ready_for_input or _leaving:
		return
	if _in_slots and event.is_action_pressed("ui_cancel"):
		_close_slots()
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


## Okno wyboru zapisu: przyciski istniejących slotów (bieżący zaznaczony) + „Wróć”.
func _open_slots() -> void:
	var gm := _singleton("GameManager")
	if not _ready_for_input or _leaving or gm == null or _load_slot() < 0:
		return
	for child in _slot_list.get_children():
		child.queue_free()
	var rows: Array[Button] = []
	var current := _load_slot()
	var selected := 0
	var summaries: Array = gm.call("get_save_slots_summary")
	for summary in summaries:
		if not bool(summary.get("exists", false)):
			continue
		var slot := int(summary.get("slot_index", 0))
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.theme_type_variation = &"QuizMenuItem"
		row.custom_minimum_size = Vector2(600, 0)
		row.text = "%s — %s
%s  |  %s" % [summary.get("slot_name", "Slot"), summary.get("title", ""), summary.get("subtitle", ""), summary.get("detail", "")]
		row.pressed.connect(_on_slot_chosen.bind(slot))
		row.mouse_entered.connect(_on_hover.bind(row))
		_slot_list.add_child(row)
		if slot == current:
			selected = rows.size()
		rows.append(row)
	_click()
	_in_slots = true
	_menu_panel.visible = false
	_slots_panel.visible = true
	_buttons = rows
	_buttons.append(_back_button)
	_selected = selected
	_refresh_selection()


func _close_slots() -> void:
	if not _in_slots or _leaving:
		return
	_click()
	_in_slots = false
	_slots_panel.visible = false
	_menu_panel.visible = true
	_buttons = _menu_buttons
	_selected = 0
	_refresh_selection()


func _on_slot_chosen(slot: int) -> void:
	var gm := _singleton("GameManager")
	if not _ready_for_input or _leaving or gm == null:
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
