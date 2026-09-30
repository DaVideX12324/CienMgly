class_name QuizTheme
extends RefCounted

## Wspólny wygląd modułu quiz_rpg (czcionka, później tło okien) — w jednym miejscu, żeby wszystkie
## ekrany były spójne. Projekt ma jedną czcionkę dla wszystkich modułów (gui/theme/custom_font =
## ThemeDB.fallback_font i czcionka domyślnego motywu), więc na czas działania modułu podmieniamy obie,
## a przy wyjściu przywracamy poprzednie (BitBomber i menu hosta bez zmian).
## Wywołania: module_root (_ready / _exit_tree) i narzędzia uruchamiane bez modułu (eksplorator map).

const FONT_PATH := "res://assets/fonts/Jersey15-Regular.ttf"
## Siatka pikseli Jersey 15: piksel litery = 1/27 em (współrzędne co 50 przy 1350 na em), więc równe
## piksele dają rozmiary 27 / 54 / 81… (przy 27 wielka litera ma 15 px). Zwykły tekst = 27.
const PX := 27
## Mnożnik przed zaokrągleniem: dotychczasowe rozmiary (Inter) 13–28 -> 27, 29–48 -> 54 itd.
const SIZE_SCALE := 1.4

## Typy motywu (theme_type_variation) — okna i pozycje menu w stylu RPG Makera. Wygląd tylko tutaj:
## asset UI (tło okien) podmieni window_style() i wszystkie okna modułu zmienią się naraz.
const WINDOW := &"QuizWindow"          # PanelContainer: okno (status, komendy, log, pytanie)
const MENU_ITEM := &"QuizMenuItem"     # Button: pozycja menu — bez tła, zaznaczona linią pod spodem
const LABEL_COLOR := Color(0.55, 0.70, 1.0)   # etykiety LP / SP / TP (jak w RPG Makerze)
const TEXT_DIM := Color(0.62, 0.64, 0.74)

static var _depth := 0
static var _prev_fallback: Font = null
static var _prev_default: Font = null
static var _prev_size := -1


## Tło okna — placeholder (ciemne, półprzezroczyste, cienka ramka) do czasu assetu UI.
static func window_style() -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.06, 0.82)
	sb.border_color = Color(0.32, 0.32, 0.45, 0.9)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	return sb


## Pasek logu bitwy / pytania u góry ekranu (jak w RPG Makerze: ciemny, półprzezroczysty, bez ramki).
static func log_style() -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	return sb


## Pozycja menu: zaznaczona (biała linia pod tekstem) albo zwykła (bez tła); te same marginesy.
static func menu_item_style(selected: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 8
	if selected:
		sb.border_color = Color.WHITE
		sb.border_width_bottom = 3
	return sb


## Zaznaczenie pozycji menu (styl „normal” i „hover” — mysz nad inną pozycją nie rysuje drugiej linii).
static func set_menu_item_selected(btn: Button, selected: bool) -> void:
	var sb := menu_item_style(selected)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		btn.add_theme_stylebox_override(st, sb if st != "focus" else StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE if selected else Color(0.86, 0.88, 0.94))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


static func _register_types(th: Theme) -> void:
	th.set_type_variation(WINDOW, &"PanelContainer")
	th.set_stylebox(&"panel", WINDOW, window_style())
	th.set_type_variation(MENU_ITEM, &"Button")
	for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		th.set_stylebox(st, MENU_ITEM, menu_item_style(false))
	th.set_stylebox(&"focus", MENU_ITEM, StyleBoxEmpty.new())
	th.set_color(&"font_color", MENU_ITEM, Color(0.86, 0.88, 0.94))
	th.set_color(&"font_hover_color", MENU_ITEM, Color.WHITE)
	th.set_color(&"font_disabled_color", MENU_ITEM, Color(0.45, 0.46, 0.52))
	th.set_constant(&"outline_size", MENU_ITEM, 6)
	th.set_color(&"font_outline_color", MENU_ITEM, Color.BLACK)


## Rozmiar tekstu UI (dotychczasowy, po skalowaniu UI) -> najbliższa wielokrotność siatki czcionki.
## Tekst w świecie gry (draw_string, liczby obrażeń) zostaje w pikselach mapy — bez snap.
static func snap(size: int) -> int:
	return PX * maxi(1, roundi(size * SIZE_SCALE / PX))


## Czcionka modułu (pikselowa: bez wygładzania i subpikseli — ustawiane tu, bo pliki .import nie są
## w repozytorium i ustawienia importu nie przechodzą między komputerami).
static func font() -> Font:
	var f := load(FONT_PATH) as FontFile
	if f != null:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.generate_mipmaps = false
	return f


## Włącza wygląd modułu; wywołania można zagnieżdżać (każde apply() -> jedno restore()).
static func apply() -> void:
	_depth += 1
	if _depth > 1:
		return
	var f := font()
	if f == null:
		push_warning("QuizTheme: brak czcionki %s" % FONT_PATH)
		return
	var th := ThemeDB.get_default_theme()
	_prev_fallback = ThemeDB.fallback_font
	_prev_default = th.default_font
	_prev_size = th.default_font_size
	ThemeDB.fallback_font = f
	th.default_font = f
	th.default_font_size = PX
	_register_types(th)


static func restore() -> void:
	if _depth == 0:
		return
	_depth -= 1
	if _depth > 0 or _prev_fallback == null:
		return
	var th := ThemeDB.get_default_theme()
	ThemeDB.fallback_font = _prev_fallback
	th.default_font = _prev_default
	th.default_font_size = _prev_size
	th.remove_type(WINDOW)
	th.remove_type(MENU_ITEM)
	_prev_fallback = null
	_prev_default = null
