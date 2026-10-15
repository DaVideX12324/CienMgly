extends CanvasLayer

## Okno rozmowy z NPC (dolny pasek, scena scenes/ui/dialog_box.tscn): imię, tekst, migający wskaźnik „dalej”.
## Enter / interakcja / klik — kolejna linia; po ostatniej sygnał finished i okno znika. Na czas rozmowy gra w stanie
## CUTSCENE (wrogowie i gracz stoją), potem z powrotem EXPLORING.

signal finished

const SCENE := "scenes/ui/dialog_box.tscn"
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
## Pierwsze wciśnięcie po otwarciu (ten sam klawisz, który otworzył rozmowę) nie przewija.
const INPUT_GRACE := 0.15

@onready var _name: Label = %Name
@onready var _text: Label = %Text
@onready var _next: Label = %Next

var _lines := PackedStringArray()
var _index := 0
var _age := 0.0
var _gm: Node = null


## Otwiera rozmowę pod węzłem `host` (np. NPC). Zwraca okno — `await box.finished`.
static func open(host: Node, speaker: String, lines: PackedStringArray) -> CanvasLayer:
	var box: CanvasLayer = (load(QuizRpgPaths.path(SCENE)) as PackedScene).instantiate()
	box.set("_lines", lines)
	host.add_child(box)
	box.call("_begin", speaker)
	return box


func _begin(speaker: String) -> void:
	UiLayerScale.attach(self)  # skala UI z opcji na całą warstwę
	_name.text = speaker
	_name.visible = speaker != ""
	var cm := get_node_or_null("/root/CoreManager")
	_gm = cm.get_singleton("GameManager") if cm and cm.has_method("get_singleton") else null
	if _gm and _gm.has_method("change_state"):
		_gm.change_state(_gm.GameState.CUTSCENE)
	_show_line()


func _process(delta: float) -> void:
	_age += delta
	_next.modulate.a = 0.35 + 0.65 * absf(sin(_age * 4.0))


func _unhandled_input(event: InputEvent) -> void:
	if _age < INPUT_GRACE:
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


func _close() -> void:
	if _gm and _gm.has_method("change_state"):
		_gm.change_state(_gm.GameState.EXPLORING)
	finished.emit()
	queue_free()
