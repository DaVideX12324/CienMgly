extends CanvasLayer

## Wskazówki samouczka: okno przy pierwszym zetknięciu z mechaniką (mapa startowa, jaskinia, miasto, pierwsza walka,
## skrzynia, awans). Wygląd w scenes/ui/tutorial_hint.tscn.
##  - „OK” — wskazówka nie wraca w tej grze (flaga zapisu HINT_FLAG_PREFIX + id; w nowej grze pokaże się znowu),
##  - „Nie pokazuj tej wskazówki” — nigdy więcej (ustawienie modułu SKIPPED_KEY, wspólne dla wszystkich zapisów),
##  - „Wyłącz wszystkie wskazówki” — opcja modułu ENABLED_KEY = "off" (włącza się z powrotem w Opcjach).
## Okno pauzuje grę (jeśli nie była spauzowana) i zjada klawiaturę, żeby nie sterowała walką ani postacią pod nim.

signal closed

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const SCENE := "scenes/ui/tutorial_hint.tscn"
const MODULE_ID := "quiz_rpg"
const ENABLED_KEY := "hints"
const SKIPPED_KEY := "hints_skipped"
const HINT_FLAG_PREFIX := "hint:"
const GROUP := &"quiz_rpg_tutorial_hint"

## id -> [tytuł, treść] (zapas PL; klucze i18n hint.<id>.title / hint.<id>.body). {interact}, {map} = klawisze akcji.
const HINTS := {
	"welcome": ["Witaj w Cieniu Mgły", "Ruszasz się klawiszami ruchu, a {interact} służy do interakcji: skrzynie, drzwi, rozmowy. Esc otwiera menu (zapis, drużyna, przedmioty, zadania), {map} pełną mapę. Twój bieżący cel widać w lewym górnym rogu."],
	"combat": ["Walka", "Wybierz akcję (atak, obrona, umiejętność, przedmiot), a potem odpowiedz na pytanie. Dobra odpowiedź = pełny efekt akcji, zła = słabszy. Seria dobrych odpowiedzi podnosi szansę na trafienie krytyczne."],
	"chest": ["Skrzynia", "Zamkniętą skrzynię otworzysz kluczem albo wytrychem. Wytrych to quiz: im wyższy poziom skrzyni, tym więcej pytań. Skrzynie widać na minimapie, a te w niszach dopiero po odkryciu."],
	"cave": ["Jaskinie", "Mapy poza ruinami są generowane. Szukaj skrzyń i przejść w niszach ścian, a wyjście prowadzi dalej. Za pierwsze przejście mapy dostajesz złoto i doświadczenie."],
	"town": ["Miasto", "W mieście są sklepy, nauczyciel umiejętności, karczma i mieszkańcy z zadaniami. Podejdź i naciśnij {interact}, żeby porozmawiać. Przyjęte zadania znajdziesz w menu Esc."],
	"level_up": ["Nowy poziom!", "Drużyna rośnie w siłę: więcej HP i lepsze statystyki. Na niektórych poziomach dostajesz żetony umiejętności, które wymienisz u nauczyciela w mieście."],
}

var hint_id := ""
var _was_paused := false

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _ok: Button = %OkButton
@onready var _skip_this: Button = %SkipThisButton
@onready var _skip_all: Button = %SkipAllButton


## Pokazuje wskazówkę, jeśli jeszcze się należy; zwraca okno (można czekać na `closed`) albo null.
static func show_hint(tree: SceneTree, id: String) -> CanvasLayer:
	if tree == null or not HINTS.has(id) or not should_show(id) or not tree.get_nodes_in_group(GROUP).is_empty():
		return null
	var hint := (load(QuizRpgPaths.path(SCENE)) as PackedScene).instantiate() as CanvasLayer
	hint.set("hint_id", id)
	tree.root.add_child(hint)
	return hint


static func should_show(id: String) -> bool:
	var s := _settings()
	if s and str(s.get_module(MODULE_ID, ENABLED_KEY, "on")) == "off":
		return false
	if s and (s.get_module(MODULE_ID, SKIPPED_KEY, []) as Array).has(id):
		return false
	var lsm := _lsm()
	return not (lsm and lsm.has_story_flag(HINT_FLAG_PREFIX + id))


func _ready() -> void:
	add_to_group(GROUP)
	UiLayerScale.attach(self)  # skala UI z opcji
	var h: Array = HINTS[hint_id]
	_title.text = QuizRpgI18n.t("hint.%s.title" % hint_id, h[0])
	var body := QuizRpgI18n.t("hint.%s.body" % hint_id, h[1])
	_body.text = body.format({"interact": _key("interact"), "map": _key("minimap")})
	_ok.text = QuizRpgI18n.t("hint.ok", _ok.text)
	_skip_this.text = QuizRpgI18n.t("hint.skip_this", _skip_this.text)
	_skip_all.text = QuizRpgI18n.t("hint.skip_all", _skip_all.text)
	_ok.pressed.connect(_close.bind(""))
	_skip_this.pressed.connect(_close.bind("this"))
	_skip_all.pressed.connect(_close.bind("all"))
	_was_paused = get_tree().paused
	get_tree().paused = true
	_ok.grab_focus.call_deferred()


## Klawiatura / pad tylko dla okna: strzałki między przyciskami, zatwierdzenie, Esc = OK.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	var buttons: Array[Button] = [_ok, _skip_this, _skip_all]
	var i := maxi(buttons.find(get_viewport().gui_get_focus_owner()), 0)
	if event.is_action_pressed("ui_cancel"):
		_close("")
	elif event.is_action_pressed("ui_accept"):
		buttons[i].pressed.emit()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		buttons[(i + 1) % buttons.size()].grab_focus()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		buttons[(i + buttons.size() - 1) % buttons.size()].grab_focus()


func _close(mode: String) -> void:
	var s := _settings()
	match mode:
		"this":
			if s:
				var skipped: Array = (s.get_module(MODULE_ID, SKIPPED_KEY, []) as Array).duplicate()
				if not skipped.has(hint_id):
					skipped.append(hint_id)
				s.set_module(MODULE_ID, SKIPPED_KEY, skipped)
		"all":
			if s:
				s.set_module(MODULE_ID, ENABLED_KEY, "off")
	var lsm := _lsm()
	if lsm:
		lsm.set_story_flag(HINT_FLAG_PREFIX + hint_id)
	if not _was_paused:
		get_tree().paused = false
	closed.emit()
	queue_free()


## Nazwa pierwszego klawisza akcji (po zmianie w ustawieniach): „E”, „M”.
static func _key(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: Key = ev.keycode
			if code == KEY_NONE and DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
			if code == KEY_NONE:
				code = ev.physical_keycode
			return OS.get_keycode_string(code)
	return "?"


static func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/SettingsService") if tree else null


static func _lsm() -> Node:
	return CoreManager.get_singleton("LevelStateManager")
