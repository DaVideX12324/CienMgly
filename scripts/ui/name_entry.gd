extends VBoxContainer

## Imię bohatera po „Nowa gra” (ekran treści menu głównego). Wygląd w scenie `scenes/ui/name_entry.tscn`; skrypt
## sprawdza imię, pokazuje reakcje na wybrane imiona (easter eggi) i wysyła sygnały. Imię z reakcją wymaga drugiego
## potwierdzenia (przycisk zmienia się na „Tak, to ja”); imiona zajęte (towarzysze, NPC miasta) nie przechodzą.
## Puste pole = domyślne imię (placeholder). Menu deweloperskie („Easter eggi imion”, CheatService.name_eggs_revealed)
## odsłania sekcję DevEggs: przycisk na każde imię z EGGS (czerwone = zajęte), kliknięcie wpisuje je i zatwierdza.

signal confirmed(player_name: String)
signal cancelled

## Reakcje: imię (małe litery, bez ogonków) -> [klucz i18n, tekst PL, zajęte]. {name} = imię jak wpisane.
const EGGS := {
	"kael": ["name_entry.egg.companion", "{name}? To imię nosi już ktoś, kogo spotkasz w drodze.", true],
	"eldon": ["name_entry.egg.companion", "{name}? To imię nosi już ktoś, kogo spotkasz w drodze.", true],
	"selene": ["name_entry.egg.companion", "{name}? To imię nosi już ktoś, kogo spotkasz w drodze.", true],
	"fenna": ["name_entry.egg.townsfolk", "{name} czeka na ciebie w mieście. Wymyśl własne imię.", true],
	"brann": ["name_entry.egg.townsfolk", "{name} czeka na ciebie w mieście. Wymyśl własne imię.", true],
	"kastor": ["name_entry.egg.townsfolk", "{name} czeka na ciebie w mieście. Wymyśl własne imię.", true],
	"greta": ["name_entry.egg.townsfolk", "{name} czeka na ciebie w mieście. Wymyśl własne imię.", true],
	"corvus": ["name_entry.egg.townsfolk", "{name} czeka na ciebie w mieście. Wymyśl własne imię.", true],
	"lina": ["name_entry.egg.townsfolk", "{name} czeka na ciebie w mieście. Wymyśl własne imię.", true],
	"quiz": ["name_entry.egg.quiz", "Pytanie kontrolne: a jak masz naprawdę na imię?", true],
	"pytanie": ["name_entry.egg.quiz", "Pytanie kontrolne: a jak masz naprawdę na imię?", true],
	"bohater": ["name_entry.egg.hero", "Skromnie. Niech będzie.", false],
	"hero": ["name_entry.egg.hero", "Skromnie. Niech będzie.", false],
	"freddy": ["name_entry.egg.freddy", "Freddy? Tym razem walczysz wiedzą, nie mikrofonem.", false],
	"claude": ["name_entry.egg.claude", "Brzmi znajomo… Powodzenia na teście.", false],
	"admin": ["name_entry.egg.admin", "Dostęp przyznany. Żart — zaczynasz od zera jak wszyscy.", false],
	"root": ["name_entry.egg.admin", "Dostęp przyznany. Żart — zaczynasz od zera jak wszyscy.", false],
	"mgla": ["name_entry.egg.mist", "Mgła nie ma imienia. Ty możesz je mieć — na pewno to?", false],
	"cien": ["name_entry.egg.mist", "Mgła nie ma imienia. Ty możesz je mieć — na pewno to?", false],
	"cien mgly": ["name_entry.egg.mist", "Mgła nie ma imienia. Ty możesz je mieć — na pewno to?", false],
	"artefakt": ["name_entry.egg.artifact", "Artefakt Wiedzy się zdobywa, nie nosi. Na pewno?", false],
	"promotor": ["name_entry.egg.promoter", "Promotor? Zaliczenie i tak trzeba zdobyć pytaniami.", false],
	"profesor": ["name_entry.egg.promoter", "Promotor? Zaliczenie i tak trzeba zdobyć pytaniami.", false],
}
const PL_PLAIN := {"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s", "ź": "z", "ż": "z"}

@onready var _edit: LineEdit = %NameEdit
@onready var _reaction: Label = %Reaction
@onready var _confirm: Button = %ConfirmButton
@onready var _back: Button = %BackButton
@onready var _dev_eggs: Control = %DevEggs
@onready var _egg_list: HFlowContainer = %EggList

## Imię, dla którego pokazano reakcję — drugie potwierdzenie tego samego imienia rozpoczyna grę.
var _pending := ""
var _confirm_text := ""


func _ready() -> void:
	_confirm_text = _confirm.text
	_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	_edit.text_changed.connect(func(_t: String) -> void: _reset_prompt())
	_confirm.pressed.connect(_submit)
	_back.pressed.connect(func() -> void: cancelled.emit())
	_build_egg_buttons()
	var cheats := get_node_or_null("/root/CheatService")
	if cheats and cheats.has_signal("name_eggs_toggled"):
		cheats.name_eggs_toggled.connect(func(revealed: bool) -> void: _dev_eggs.visible = revealed)
		_dev_eggs.visible = bool(cheats.get("name_eggs_revealed"))


func _build_egg_buttons() -> void:
	for key: String in EGGS:
		var b := Button.new()
		b.text = " ".join(Array(key.split(" ")).map(func(w: String) -> String: return w.capitalize()))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5) if bool(EGGS[key][2]) else Color(0.95, 0.85, 0.45))
		b.tooltip_text = str(EGGS[key][1])
		b.pressed.connect(func() -> void:
			_edit.text = b.text
			_reset_prompt()
			_submit())
		_egg_list.add_child(b)


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
	var egg: Array = EGGS.get(normalize(entered), [])
	if egg.is_empty() or entered == _pending:
		confirmed.emit(entered)
		return
	_reaction.text = QuizRpgI18n.tf(egg[0], {"name": entered}, egg[1])
	if bool(egg[2]):
		_edit.select_all()
		_edit.grab_focus()
		return
	_pending = entered
	_confirm.text = QuizRpgI18n.t("name_entry.confirm_again", "✔ Tak, to ja")


## Imię do porównań: małe litery, bez ogonków i zbędnych spacji.
static func normalize(value: String) -> String:
	var s := value.strip_edges().to_lower()
	for k: String in PL_PLAIN:
		s = s.replace(k, PL_PLAIN[k])
	return " ".join(s.split(" ", false))
