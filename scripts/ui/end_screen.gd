extends CanvasLayer

## Ekran końca gry (uproszczone zakończenie na inżynierkę, decyzja usera 2026-10-22): po wygranej z bossem oznaczonym
## ends_game (ścieki: "boss": {"ends_game": true} w sewer.json). Wygląd w scenie `scenes/ui/end_screen.tscn`; skrypt
## wpisuje podsumowanie (czas gry, poziom, pokonani bossowie, poprawne odpowiedzi), wprowadza ekran i obsługuje
## przyciski. Pauzuje grę i ustawia stan MENU. „Graj dalej” wraca do eksploracji, „Menu główne” — do menu.
## Zapis (flaga game:completed) robi EnemyBase przed pokazaniem ekranu; `saved` pokazuje napis o zapisie.

@export var fade_time := 1.2
@export var leave_immunity := 3.0   ## s: żaden wróg nie zaczyna walki tuż po powrocie do gry

## Czy gra została zapisana jako ukończona (ustawia wołający przed add_child).
var saved := false

var _buttons: Array[Button] = []
var _selected := 0
var _ready_for_input := false
var _leaving := false

@onready var _dim: ColorRect = %Dim
@onready var _box: Control = %Box
@onready var _continue_button: Button = %ContinueButton
@onready var _menu_button: Button = %MenuButton
@onready var _saved_label: Label = %SavedLabel


func _ready() -> void:
	UiLayerScale.attach(self)  # skala UI z opcji na całą warstwę
	var gm := _singleton("GameManager")
	if gm and gm.has_method("change_state"):
		gm.call("change_state", 0)   # GameState.MENU
	get_tree().paused = true
	_fill_stats(gm)
	_saved_label.visible = saved
	_buttons = [_continue_button, _menu_button]
	_continue_button.pressed.connect(_on_continue)
	_menu_button.pressed.connect(_on_main_menu)
	for b in _buttons:
		b.mouse_entered.connect(_on_hover.bind(b))
	_refresh_selection()
	var dim_a := _dim.color.a
	_dim.color.a = 0.0
	_box.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", dim_a, fade_time)
	tw.tween_property(_box, "modulate:a", 1.0, fade_time).set_delay(fade_time * 0.4)
	tw.chain().tween_callback(func() -> void: _ready_for_input = true)


func _fill_stats(gm: Node) -> void:
	var secs := int(gm.get("total_play_time_seconds")) if gm != null and gm.get("total_play_time_seconds") != null else 0
	%TimeValue.text = "%d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	var ps := _singleton("PlayerStats")
	%LevelValue.text = str(int(ps.get("level"))) if ps != null else "1"
	%CorrectValue.text = str(int(ps.get("total_correct"))) if ps != null else "0"
	var lsm := _singleton("LevelStateManager")
	%BossesValue.text = str(int(lsm.call("count_story_flags", "boss:"))) if lsm != null and lsm.has_method("count_story_flags") else "0"


func _on_hover(b: Button) -> void:
	_selected = _buttons.find(b)
	_refresh_selection()


func _refresh_selection() -> void:
	for i in range(_buttons.size()):
		QuizTheme.set_menu_item_selected(_buttons[i], i == _selected)


func _input(event: InputEvent) -> void:
	# Mysz idzie do GUI (przyciski); resztę wejścia ekran zabiera (menu pauzy i inni słuchacze _input nie reagują).
	if event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if not _ready_for_input or _leaving:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		_selected = posmod(_selected + (-1 if event.is_action_pressed("ui_up") else 1), _buttons.size())
		_refresh_selection()
		_click()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_buttons[_selected].pressed.emit()


func _on_continue() -> void:
	if not _ready_for_input or _leaving:
		return
	_leaving = true
	_click()
	var gm := _singleton("GameManager")
	if gm and gm.has_method("change_state"):
		gm.call("change_state", 1)   # GameState.EXPLORING
	_grant_immunity()
	get_tree().paused = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.0, 0.4)
	tw.tween_property(_box, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)


func _on_main_menu() -> void:
	var gm := _singleton("GameManager")
	if not _ready_for_input or _leaving or gm == null:
		return
	_leaving = true
	_click()
	_grant_immunity()
	get_tree().paused = false
	get_tree().create_timer(0.6, true).timeout.connect(queue_free)
	gm.call("return_to_main_menu")


func _grant_immunity() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("grant_encounter_immunity"):
			p.call("grant_encounter_immunity", leave_immunity)


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
