extends VBoxContainer

## Imię bohatera po „Nowa gra” (ekran treści menu głównego). Wygląd w scenie `scenes/ui/name_entry.tscn`; skrypt
## sprawdza imię, pokazuje reakcje na wybrane imiona (easter eggi) i wysyła sygnały. Imię z reakcją wymaga drugiego
## potwierdzenia (przycisk zmienia się na „Tak, to ja”); imiona zajęte (taken) nie przechodzą. Puste pole = domyślne
## imię (placeholder).
##
## Easter eggi są w `resources/data/name_easter_eggs.json` (name — małe litery bez ogonków, taken, reakcja pl / en,
## {name} = imię jak wpisane). Menu deweloperskie („Easter eggi imion”, CheatService.name_eggs_revealed) odsłania
## sekcję DevEggs — edytor: lista (klik w imię wpisuje je, zajęte / reakcje PL i EN do zmiany, kosz) i wiersz dodawania.
## Zmiany zapisują się od razu: do pliku w projekcie, a gdy jest tylko do odczytu (wyeksportowana gra) — do
## user_eggs_path, który przy wczytaniu ma pierwszeństwo.

signal confirmed(player_name: String)
signal cancelled

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const PL_PLAIN := {"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s", "ź": "z", "ż": "z"}
const COLOR_TAKEN := Color(1.0, 0.5, 0.5)
const COLOR_REACTION := Color(0.95, 0.85, 0.45)

## Plik easter eggów w projekcie i zapas w user:// (testy podmieniają ścieżki, żeby nie ruszać danych gry).
static var eggs_path: String = QuizRpgPaths.path("resources/data/name_easter_eggs.json")
static var user_eggs_path: String = "user://cien_mgly_name_easter_eggs.json"

@onready var _edit: LineEdit = %NameEdit
@onready var _reaction: Label = %Reaction
@onready var _confirm: Button = %ConfirmButton
@onready var _back: Button = %BackButton
@onready var _dev_eggs: Control = %DevEggs
@onready var _egg_list: VBoxContainer = %EggList
@onready var _new_name: LineEdit = %NewName
@onready var _new_taken: CheckBox = %NewTaken
@onready var _new_pl: LineEdit = %NewPl
@onready var _new_en: LineEdit = %NewEn
@onready var _add: Button = %AddButton
@onready var _dev_status: Label = %DevStatus

## Wpisy z pliku: {name, taken, pl, en} w kolejności pliku.
var eggs: Array[Dictionary] = []
## Imię, dla którego pokazano reakcję — drugie potwierdzenie tego samego imienia rozpoczyna grę.
var _pending := ""
var _confirm_text := ""
var _opis := ""


func _ready() -> void:
	_confirm_text = _confirm.text
	_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	_edit.text_changed.connect(func(_t: String) -> void: _reset_prompt())
	_confirm.pressed.connect(_submit)
	_back.pressed.connect(func() -> void: cancelled.emit())
	_add.pressed.connect(_on_add)
	load_eggs()
	_rebuild_list()
	var cheats := get_node_or_null("/root/CheatService")
	if cheats and cheats.has_signal("name_eggs_toggled"):
		cheats.name_eggs_toggled.connect(func(revealed: bool) -> void: _dev_eggs.visible = revealed)
		_dev_eggs.visible = bool(cheats.get("name_eggs_revealed"))


## Pokazuje ekran z pustym polem i kursorem w polu.
func open() -> void:
	visible = true
	_edit.text = ""
	_reset_prompt()
	_edit.grab_focus.call_deferred()


func _reset_prompt() -> void:
	_pending = ""
	_reaction.text = ""
	_confirm.text = _confirm_text


func _submit() -> void:
	var entered := _edit.text.strip_edges()
	if entered.is_empty():
		confirmed.emit(QuizRpgI18n.t("name_entry.placeholder", _edit.placeholder_text))
		return
	var egg := find_egg(entered)
	if egg.is_empty() or entered == _pending:
		confirmed.emit(entered)
		return
	_reaction.text = reaction_text(egg, entered)
	if bool(egg.get("taken", false)):
		_edit.select_all()
		_edit.grab_focus()
		return
	_pending = entered
	_confirm.text = QuizRpgI18n.t("name_entry.confirm_again", "✔ Tak, to ja")


func find_egg(entered: String) -> Dictionary:
	var key := normalize(entered)
	for e in eggs:
		if str(e.get("name", "")) == key:
			return e
	return {}


## Reakcja w bieżącym języku (brak tłumaczenia -> PL), {name} = imię jak wpisane.
static func reaction_text(egg: Dictionary, entered: String) -> String:
	var text := str(egg.get(QuizRpgI18n.language(), ""))
	if text.is_empty():
		text = str(egg.get("pl", ""))
	return text.format({"name": entered})


## Imię do porównań: małe litery, bez ogonków i zbędnych spacji.
static func normalize(value: String) -> String:
	var s := value.strip_edges().to_lower()
	for k: String in PL_PLAIN:
		s = s.replace(k, PL_PLAIN[k])
	return " ".join(s.split(" ", false))


# --- dane -----------------------------------------------------------------------------------------------------------

func load_eggs() -> void:
	var path := user_eggs_path if FileAccess.file_exists(user_eggs_path) else eggs_path
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	eggs.clear()
	if data is Dictionary:
		_opis = str(data.get("_opis", ""))
		for e: Variant in data.get("eggs", []):
			if e is Dictionary and str(e.get("name", "")) != "":
				eggs.append(e)


## Zapis do pliku w projekcie; gdy tylko do odczytu (wyeksportowana gra) albo dane są już w user:// — do user://.
## Zwraca ścieżkę albo "".
func save_eggs() -> String:
	var text := JSON.stringify({"_opis": _opis, "eggs": eggs}, "  ", false) + "\n"
	var paths: Array[String] = [user_eggs_path]
	if not FileAccess.file_exists(user_eggs_path):
		paths.push_front(eggs_path)
	for path in paths:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()
			_dev_status.text = QuizRpgI18n.tf("name_entry.dev.saved", {"path": path}, "Zapisano: {path}")
			return path
	_dev_status.text = QuizRpgI18n.t("name_entry.dev.save_failed", "Nie udało się zapisać easter eggów.")
	return ""


# --- edytor (DevEggs) -----------------------------------------------------------------------------------------------

func _rebuild_list() -> void:
	for c in _egg_list.get_children():
		_egg_list.remove_child(c)
		c.queue_free()
	for e in eggs:
		_egg_list.add_child(_egg_row(e))


## Wiersz edytora: imię (klik = wpisz i pokaż reakcję), zajęte, reakcja PL / EN (zapis po Enter / wyjściu z pola), kosz.
func _egg_row(e: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chip := Button.new()
	chip.text = str(e["name"])
	chip.custom_minimum_size = Vector2(150, 0)
	chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	chip.focus_mode = Control.FOCUS_NONE
	chip.add_theme_font_size_override("font_size", 18)
	chip.add_theme_color_override("font_color", COLOR_TAKEN if bool(e.get("taken", false)) else COLOR_REACTION)
	chip.tooltip_text = QuizRpgI18n.t("name_entry.dev.chip_tip", "Wpisz to imię i pokaż reakcję")
	chip.pressed.connect(func() -> void:
		_edit.text = str(e["name"]).capitalize()
		_reset_prompt()
		_submit())
	row.add_child(chip)
	var taken := CheckBox.new()
	taken.text = QuizRpgI18n.t("name_entry.dev.taken", "zajęte")
	taken.button_pressed = bool(e.get("taken", false))
	taken.focus_mode = Control.FOCUS_NONE
	taken.add_theme_font_size_override("font_size", 18)
	taken.toggled.connect(func(on: bool) -> void:
		e["taken"] = on
		chip.add_theme_color_override("font_color", COLOR_TAKEN if on else COLOR_REACTION)
		save_eggs())
	row.add_child(taken)
	for lang: String in ["pl", "en"]:
		var edit := LineEdit.new()
		edit.text = str(e.get(lang, ""))
		edit.placeholder_text = lang.to_upper()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.add_theme_font_size_override("font_size", 18)
		edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var commit := func() -> void:
			if str(e.get(lang, "")) != edit.text:
				e[lang] = edit.text
				save_eggs()
		edit.text_submitted.connect(func(_t: String) -> void: commit.call())
		edit.focus_exited.connect(commit)
		row.add_child(edit)
	var del := Button.new()
	del.text = "🗑"
	del.focus_mode = Control.FOCUS_NONE
	del.tooltip_text = QuizRpgI18n.t("name_entry.dev.delete_tip", "Usuń ten easter egg")
	del.pressed.connect(func() -> void:
		eggs.erase(e)
		save_eggs()
		_rebuild_list())
	row.add_child(del)
	return row


## Nowy easter egg z wiersza dodawania (puste imię = to z pola imienia). To samo imię — nadpisuje wpis.
func _on_add() -> void:
	var key := normalize(_new_name.text if _new_name.text.strip_edges() != "" else _edit.text)
	if key.is_empty() or _new_pl.text.strip_edges().is_empty():
		_dev_status.text = QuizRpgI18n.t("name_entry.dev.need_fields", "Podaj imię i reakcję PL.")
		return
	var existing := find_egg(key)
	var e: Dictionary = existing if not existing.is_empty() else {"name": key}
	e["taken"] = _new_taken.button_pressed
	e["pl"] = _new_pl.text.strip_edges()
	e["en"] = _new_en.text.strip_edges()
	if existing.is_empty():
		eggs.append(e)
	save_eggs()
	_rebuild_list()
	_new_name.text = ""
	_new_pl.text = ""
	_new_en.text = ""
	_new_taken.button_pressed = false
