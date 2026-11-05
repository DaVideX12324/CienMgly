extends VBoxContainer

## Ustawienia rozgrywki przy nowej grze (po imieniu, przed startem): poziom trudności, losowe spotkania, tempo walki,
## tryb bez quizów. To te same ustawienia co w Opcjach (moduł quiz_rpg / globalne) — zapis od razu po „Rozpocznij”.
## Wygląd w scenes/ui/new_game_setup.tscn.

signal confirmed
signal cancelled

const MODULE_ID := "quiz_rpg"
## id -> [klucz i18n nazwy, zapas, klucz opisu, zapas opisu]
const DIFFICULTIES := [
	["easy", "setup.diff.easy", "Łatwy", "setup.diff.easy_desc", "Słabsi przeciwnicy — dla tych, którzy chcą się skupić na pytaniach."],
	["normal", "setup.diff.normal", "Normalny", "setup.diff.normal_desc", "Zbalansowana rozgrywka."],
	["hard", "setup.diff.hard", "Trudny", "setup.diff.hard_desc", "Silniejsi przeciwnicy — każda pomyłka boli."],
]
const SPEEDS := [["1", "setup.speed.1", "Normalne"], ["1.5", "setup.speed.15", "Szybkie (×1,5)"], ["2", "setup.speed.2", "Bardzo szybkie (×2)"]]

@onready var _difficulty: OptionButton = %Difficulty
@onready var _encounters: CheckButton = %Encounters
@onready var _speed: OptionButton = %Speed
@onready var _quizless: CheckButton = %Quizless
@onready var _description: Label = %Description
@onready var _start: Button = %StartButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	_start.pressed.connect(_on_start)
	_back.pressed.connect(func() -> void: cancelled.emit())
	_difficulty.item_selected.connect(func(_i: int) -> void: _refresh_description())
	_start.text = QuizRpgI18n.t("setup.start", _start.text)
	_back.text = QuizRpgI18n.t("setup.back", _back.text)
	for path: String in ["Prompt", "Grid/DifficultyLabel", "Grid/EncountersLabel", "Grid/SpeedLabel", "Grid/QuizlessLabel", "Hint"]:
		var l := get_node(path) as Label
		l.text = QuizRpgI18n.t("setup." + path.get_file().to_snake_case(), l.text)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()


func open() -> void:
	var s := _settings()
	_difficulty.clear()
	for d: Array in DIFFICULTIES:
		_difficulty.add_item(QuizRpgI18n.t(d[1], d[2]))
	var diff := str(s.get_module(MODULE_ID, "difficulty", "normal")) if s else "normal"
	_difficulty.select(maxi(DIFFICULTIES.map(func(d: Array) -> String: return d[0]).find(diff), 0))
	_speed.clear()
	for sp: Array in SPEEDS:
		_speed.add_item(QuizRpgI18n.t(sp[1], sp[2]))
	var speed := str(s.get_module(MODULE_ID, "battle_speed", "1")) if s else "1"
	_speed.select(maxi(SPEEDS.map(func(sp: Array) -> String: return sp[0]).find(speed), 0))
	_encounters.button_pressed = (str(s.get_module(MODULE_ID, "random_encounters", "on")) if s else "on") != "off"
	_quizless.button_pressed = bool(s.is_quizless_mode_enabled()) if s else false
	_refresh_description()
	visible = true
	_start.grab_focus.call_deferred()


func _refresh_description() -> void:
	var d: Array = DIFFICULTIES[maxi(_difficulty.selected, 0)]
	_description.text = QuizRpgI18n.t(d[3], d[4])


func _on_start() -> void:
	var s := _settings()
	if s:
		s.set_module(MODULE_ID, "difficulty", DIFFICULTIES[maxi(_difficulty.selected, 0)][0], false)
		s.set_module(MODULE_ID, "battle_speed", SPEEDS[maxi(_speed.selected, 0)][0], false)
		s.set_module(MODULE_ID, "random_encounters", "on" if _encounters.button_pressed else "off", false)
		s.set_quizless_mode_enabled(_quizless.button_pressed, false)
		s.save_settings()
	confirmed.emit()


func _settings() -> Node:
	return get_node_or_null("/root/SettingsService")
