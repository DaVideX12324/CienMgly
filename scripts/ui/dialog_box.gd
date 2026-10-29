extends CanvasLayer

## Okno rozmowy z NPC (dolny pasek, scena scenes/ui/dialog_box.tscn): imię, tekst, migający wskaźnik „dalej”.
## Enter / interakcja / klik — kolejna linia; po ostatniej sygnał finished i okno znika. Na czas rozmowy gra w stanie
## CUTSCENE (wrogowie i gracz stoją), potem z powrotem EXPLORING — chyba że stan trzyma rozmowa NPC (manage_state
## false). ask(): pytanie z opcjami (strzałki + Enter / klik; Esc = ostatnia opcja) -> sygnał chosen(indeks).

signal finished
signal chosen(index: int)

const SCENE := "scenes/ui/dialog_box.tscn"
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const QuizTheme = preload("quiz_theme.gd")
const ChoiceScene = preload("../../scenes/ui/dialog_choice.tscn")
## Pierwsze wciśnięcie po otwarciu (ten sam klawisz, który otworzył rozmowę) nie przewija.
const INPUT_GRACE := 0.15

@onready var _name: Label = %Name
@onready var _text: Label = %Text
@onready var _next: Label = %Next
@onready var _choices: VBoxContainer = %Choices

var _lines := PackedStringArray()
var _options := PackedStringArray()
var _index := 0
var _age := 0.0
var _gm: Node = null
var _manage_state := true


## Otwiera rozmowę pod węzłem `host` (np. NPC). Zwraca okno — `await box.finished`.
static func open(host: Node, speaker: String, lines: PackedStringArray, manage_state := true) -> CanvasLayer:
	var box: CanvasLayer = (load(QuizRpgPaths.path(SCENE)) as PackedScene).instantiate()
	box.set("_lines", lines)
	box.set("_manage_state", manage_state)
	host.add_child(box)
	box.call("_begin", speaker)
	return box


## Pytanie z opcjami pod węzłem `host`. Zwraca okno — `var i: int = await box.chosen`.
static func ask(host: Node, speaker: String, question: String, options: PackedStringArray, manage_state := true) -> CanvasLayer:
	var box: CanvasLayer = (load(QuizRpgPaths.path(SCENE)) as PackedScene).instantiate()
	box.set("_lines", PackedStringArray([question]))
	box.set("_options", options)
	box.set("_manage_state", manage_state)
	host.add_child(box)
	box.call("_begin", speaker)
	return box


func _begin(speaker: String) -> void:
	UiLayerScale.attach(self)  # skala UI z opcji na całą warstwę
	_name.text = speaker
	_name.visible = speaker != ""
	var cm := get_node_or_null("/root/CoreManager")
	_gm = cm.get_singleton("GameManager") if cm and cm.has_method("get_singleton") else null
	if _manage_state and _gm and _gm.has_method("change_state"):
		_gm.change_state(_gm.GameState.CUTSCENE)
	_show_line()
	_build_choices()


func _build_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
	_choices.visible = not _options.is_empty()
	_next.visible = _options.is_empty()
	for i in _options.size():
		var b := ChoiceScene.instantiate() as Button
		b.text = _options[i]
		b.pressed.connect(_choose.bind(i))
		b.focus_entered.connect(QuizTheme.set_menu_item_selected.bind(b, true))
		b.focus_exited.connect(QuizTheme.set_menu_item_selected.bind(b, false))
		_choices.add_child(b)
	if not _options.is_empty():
		var first := _choices.get_child(0) as Button
		first.call_deferred("grab_focus")


func _process(delta: float) -> void:
	_age += delta
	_next.modulate.a = 0.35 + 0.65 * absf(sin(_age * 4.0))


func _unhandled_input(event: InputEvent) -> void:
	if _age < INPUT_GRACE:
		return
	if not _options.is_empty():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_choose(_options.size() - 1)
		elif event.is_action_pressed("interact"):
			# interakcja (E) jak Enter: wybiera opcję z fokusem
			var f := get_viewport().gui_get_focus_owner()
			if f is Button and f.get_parent() == _choices:
				get_viewport().set_input_as_handled()
				_choose(f.get_index())
		return
	var advance: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not advance:
		return
	get_viewport().set_input_as_handled()
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()


func _show_line() -> void:
	_text.text = _lines[_index] if _index < _lines.size() else ""


func _choose(i: int) -> void:
	if _age < INPUT_GRACE or is_queued_for_deletion():
		return
	chosen.emit(i)
	_close()


func _close() -> void:
	if _manage_state and _gm and _gm.has_method("change_state"):
		_gm.change_state(_gm.GameState.EXPLORING)
	finished.emit()
	queue_free()
