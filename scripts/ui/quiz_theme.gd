class_name QuizTheme
extends RefCounted

## Wspólny wygląd modułu quiz_rpg — źródłem jest zasób motywu THEME_PATH (edytowalny w inspektorze:
## czcionka, tło okien, pozycje menu, pasek logu). Ekrany modułu mają go przypiętego do korzenia
## (`theme`), więc edytor pokazuje docelowy wygląd; asset UI (tło okien) podmienia się w tym pliku.
##
## Projekt ma jedną czcionkę dla wszystkich modułów (gui/theme/custom_font = ThemeDB.fallback_font
## i czcionka domyślnego motywu), więc na czas działania modułu apply() podmienia obie na czcionkę
## z motywu i dopisuje typy motywu (QuizWindow…) do domyślnego — dla ekranów bez przypiętego motywu;
## restore() przywraca poprzednie (BitBomber i menu hosta bez zmian).
## Wywołania: module_root (_ready / _exit_tree) i narzędzia uruchamiane bez modułu (eksplorator map).
##
## Motywy (Opcje -> Motyw): plik resources/ui/skins/<id>.tres nadpisuje style typów SKIN_TYPES
## (okna, zaznaczenie, paski); „klasyczny” = sam THEME_PATH. Jasność mnoży kolor okien i zaznaczenia.
## Wybór w ustawieniach modułu (SettingsService, klucze SETTING_SKIN / SETTING_BRIGHTNESS).

const THEME_PATH := "res://modules/quiz_rpg/resources/ui/quiz_theme.tres"
## Czcionka pikselowa (FontFile z danymi Jersey 15, bez wygładzania — zapisane w zasobie, bo pliki
## .import nie są w repozytorium). Tworzy ją build_font() z pliku TTF_PATH.
const FONT_PATH := "res://modules/quiz_rpg/resources/ui/jersey15_pixel.res"
const TTF_PATH := "res://assets/fonts/Jersey15-Regular.ttf"
## Siatka pikseli Jersey 15: piksel litery = 1/27 em (współrzędne co 50 przy 1350 na em), więc równe
## piksele dają rozmiary 27 / 54 / 81… (przy 27 wielka litera ma 15 px). Zwykły tekst = 27.
const PX := 27
## Mnożnik przed zaokrągleniem: dotychczasowe rozmiary (Inter) 13–28 -> 27, 29–48 -> 54 itd.
const SIZE_SCALE := 1.4

## Typy motywu (theme_type_variation) w stylu RPG Makera.
const WINDOW := &"QuizWindow"          # PanelContainer: okno (status, komendy, komunikaty)
const LOG := &"QuizLog"                # PanelContainer: pasek u góry (log bitwy / pytanie)
const MENU_ITEM := &"QuizMenuItem"     # Button: pozycja menu bez tła; zaznaczona = styl „selected”
const BAR_LP := &"QuizBarLP"           # ProgressBar: paski drużyny, czasu odpowiedzi, HP wrogów
const BAR_SP := &"QuizBarSP"
const BAR_TP := &"QuizBarTP"
const BAR_TIMER := &"QuizBarTimer"
const BAR_ENEMY := &"QuizBarEnemy"
const CUSTOM_TYPES: Array[StringName] = [WINDOW, LOG, MENU_ITEM, BAR_LP, BAR_SP, BAR_TP, BAR_TIMER, BAR_ENEMY]
## Typy, których kolor zmienia suwak jasności (okna i zaznaczenie; paski zostają w swoich kolorach).
const BRIGHTNESS_TYPES: Array[StringName] = [WINDOW, LOG, MENU_ITEM]

const MODULE_ID := "quiz_rpg"
const SETTING_SKIN := "ui_skin"
const SETTING_BRIGHTNESS := "ui_brightness"
const SKIN_DIR := "res://modules/quiz_rpg/resources/ui/skins/"
const DEFAULT_SKIN := "klasyczny"
## Dostępne motywy (kolejność w opcjach). Nowy motyw: plik SKIN_DIR + id + ".tres" i wpis tutaj.
## Motywy st_*: panele z assets/UI/UI Assets pack_v.1_st (pliki buduje tests/build_ui_skins.gd).
const SKINS: Array[Dictionary] = [
	{"id": "klasyczny", "name": "Klasyczny (ciemny)"},
	{"id": "st_navy_rd_flat", "name": "Granatowy, zaokrąglony"},
	{"id": "st_navy_rd_3d", "name": "Granatowy, zaokrąglony, z głębią"},
	{"id": "st_navy_sq_flat", "name": "Granatowy, kwadratowy"},
	{"id": "st_navy_sq_3d", "name": "Granatowy, kwadratowy, z głębią"},
	{"id": "st_beige_rd_flat", "name": "Jasny, zaokrąglony"},
	{"id": "st_beige_rd_3d", "name": "Jasny, zaokrąglony, z głębią"},
	{"id": "st_beige_sq_flat", "name": "Jasny, kwadratowy"},
	{"id": "st_beige_sq_3d", "name": "Jasny, kwadratowy, z głębią"},
]
const BRIGHTNESS_MIN := 0.5
const BRIGHTNESS_MAX := 1.5
const LABEL_COLOR := Color(0.55, 0.70, 1.0)   # etykiety LP / SP / TP (jak w RPG Makerze)
const TEXT_DIM := Color(0.62, 0.64, 0.74)

static var _depth := 0
static var _prev_fallback: Font = null
static var _prev_default: Font = null
static var _prev_size := -1
static var _theme: Theme = null
static var _base: Theme = null   # style „klasyczne” z THEME_PATH (przed nałożeniem motywu)
static var _skin_id := DEFAULT_SKIN
static var _brightness := 1.0
static var _selected_buttons: Array[WeakRef] = []  # zaznaczone pozycje (odświeżane po zmianie motywu)


## Motyw modułu (zasób). Brak pliku -> motyw zbudowany w kodzie (build_default_theme).
static func theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) as Theme if ResourceLoader.exists(THEME_PATH) else null
		if _theme == null:
			push_warning("QuizTheme: brak %s — motyw domyślny z kodu" % THEME_PATH)
			_theme = build_default_theme()
	return _theme


static func font() -> Font:
	return theme().default_font


## Rozmiar tekstu UI (dotychczasowy, po skalowaniu UI) -> najbliższa wielokrotność siatki czcionki.
## Tekst w świecie gry (draw_string, liczby obrażeń) zostaje w pikselach mapy — bez snap.
static func snap(size: int) -> int:
	return PX * maxi(1, roundi(size * SIZE_SCALE / PX))


## Zaznaczenie pozycji menu: styl „selected” z motywu (linia pod tekstem) na stanach normal / hover /
## pressed; odznaczenie zdejmuje nadpisania (wraca wygląd z motywu).
static func set_menu_item_selected(btn: Button, selected: bool) -> void:
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		btn.remove_theme_stylebox_override(st)
	btn.remove_theme_color_override("font_color")
	btn.set_meta(&"quiz_menu_selected", selected)
	if not selected:
		return
	_selected_buttons = _selected_buttons.filter(func(w: WeakRef) -> bool: return w.get_ref() != null and w.get_ref() != btn)
	_selected_buttons.append(weakref(btn))
	var sb := btn.get_theme_stylebox(&"selected", MENU_ITEM)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(st, sb)
	btn.add_theme_color_override("font_color", btn.get_theme_color(&"font_selected_color", MENU_ITEM))


## Włącza wygląd modułu; wywołania można zagnieżdżać (każde apply() -> jedno restore()).
static func apply() -> void:
	_depth += 1
	if _depth > 1:
		return
	var src := theme()
	var f := src.default_font
	if f == null:
		push_warning("QuizTheme: motyw bez czcionki")
		return
	apply_skin_from_settings()
	var th := ThemeDB.get_default_theme()
	_prev_fallback = ThemeDB.fallback_font
	_prev_default = th.default_font
	_prev_size = th.default_font_size
	ThemeDB.fallback_font = f
	th.default_font = f
	th.default_font_size = src.default_font_size if src.default_font_size > 0 else PX
	for t in CUSTOM_TYPES:
		_copy_type(src, th, t)


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
	for t in CUSTOM_TYPES:
		th.remove_type(t)
	_prev_fallback = null
	_prev_default = null


## Motyw i jasność z ustawień modułu (SettingsService); bez usługi — motyw domyślny.
static func apply_skin_from_settings() -> void:
	var settings := _settings_service()
	var id := DEFAULT_SKIN
	var brightness := 1.0
	if settings:
		id = str(settings.call("get_module", MODULE_ID, SETTING_SKIN, DEFAULT_SKIN))
		brightness = float(settings.call("get_module", MODULE_ID, SETTING_BRIGHTNESS, 1.0))
	apply_skin(id, brightness)


## Nakłada motyw `id` (nieznany -> klasyczny) z jasnością `brightness` na motyw modułu — ekrany
## z przypiętym motywem odświeżają się same (sygnał changed), domyślny motyw dostaje kopię typów.
static func apply_skin(id: String, brightness: float = 1.0) -> void:
	var th := theme()
	if _base == null:
		_base = Theme.new()
		for t in CUSTOM_TYPES:
			_copy_type(th, _base, t)
	var skin: Theme = null
	if id != DEFAULT_SKIN and ResourceLoader.exists(SKIN_DIR + id + ".tres"):
		skin = load(SKIN_DIR + id + ".tres") as Theme
	_skin_id = id if skin != null else DEFAULT_SKIN
	_brightness = clampf(brightness, BRIGHTNESS_MIN, BRIGHTNESS_MAX)
	for t in CUSTOM_TYPES:
		var names := _base.get_stylebox_list(t)
		if skin:
			for n in skin.get_stylebox_list(t):
				if not names.has(n):
					names.append(n)
		for n in names:
			var sb: StyleBox = skin.get_stylebox(n, t) if skin and skin.has_stylebox(n, t) else _base.get_stylebox(n, t)
			if BRIGHTNESS_TYPES.has(t) and not is_equal_approx(_brightness, 1.0):
				sb = _brightened(sb, _brightness)
			th.set_stylebox(n, t, sb)
		for n in _base.get_color_list(t):
			th.set_color(n, t, skin.get_color(n, t) if skin and skin.has_color(n, t) else _base.get_color(n, t))
	if _depth > 0:
		var dt := ThemeDB.get_default_theme()
		for t in CUSTOM_TYPES:
			_copy_type(th, dt, t)
	# Zaznaczenie ma styl wstawiony jako nadpisanie — przepisać nowym.
	for w in _selected_buttons.duplicate():
		var btn := w.get_ref() as Button
		if btn and bool(btn.get_meta(&"quiz_menu_selected", false)):
			set_menu_item_selected(btn, true)
	_selected_buttons = _selected_buttons.filter(func(w: WeakRef) -> bool: return w.get_ref() != null and bool((w.get_ref() as Button).get_meta(&"quiz_menu_selected", false)))


static func skin_id() -> String:
	return _skin_id


static func brightness() -> float:
	return _brightness


## Kopia stylu z kolorem przemnożonym przez `k` (tekstura: modulate; płaski: tło i ramka; alfa bez zmian).
static func _brightened(sb: StyleBox, k: float) -> StyleBox:
	if sb is StyleBoxTexture:
		var t := sb.duplicate() as StyleBoxTexture
		var c := t.modulate_color
		t.modulate_color = Color(c.r * k, c.g * k, c.b * k, c.a)
		return t
	if sb is StyleBoxFlat:
		var f := sb.duplicate() as StyleBoxFlat
		f.bg_color = Color(minf(f.bg_color.r * k, 1.0), minf(f.bg_color.g * k, 1.0), minf(f.bg_color.b * k, 1.0), f.bg_color.a)
		f.border_color = Color(minf(f.border_color.r * k, 1.0), minf(f.border_color.g * k, 1.0), minf(f.border_color.b * k, 1.0), f.border_color.a)
		return f
	return sb


static func _settings_service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("SettingsService") if tree else null


static func _copy_type(src: Theme, dst: Theme, t: StringName) -> void:
	var base := src.get_type_variation_base(t)
	if base != &"":
		dst.set_type_variation(t, base)
	for n in src.get_stylebox_list(t):
		dst.set_stylebox(n, t, src.get_stylebox(n, t))
	for n in src.get_color_list(t):
		dst.set_color(n, t, src.get_color(n, t))
	for n in src.get_constant_list(t):
		dst.set_constant(n, t, src.get_constant(n, t))
	for n in src.get_font_size_list(t):
		dst.set_font_size(n, t, src.get_font_size(n, t))


# --- Wartości startowe (generator zasobów: tests/build_quiz_theme.gd) --------------------------

## Czcionka pikselowa: dane TTF w FontFile, bez wygładzania, hintingu i subpikseli.
static func build_font() -> FontFile:
	var f := FontFile.new()
	f.data = FileAccess.get_file_as_bytes(TTF_PATH)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f


static func build_default_theme(font_res: Font = null) -> Theme:
	var th := Theme.new()
	th.default_font = font_res if font_res != null else build_font()
	th.default_font_size = PX
	# Tekst z czarnym obrysem (jak w RPG Makerze).
	for t in [&"Label", &"Button", &"LineEdit"]:
		th.set_color(&"font_outline_color", t, Color.BLACK)
		th.set_constant(&"outline_size", t, 6)
	th.set_color(&"font_outline_color", &"RichTextLabel", Color.BLACK)
	th.set_constant(&"outline_size", &"RichTextLabel", 6)
	# Okno — placeholder (ciemne, półprzezroczyste, cienka ramka) do czasu assetu UI.
	th.set_type_variation(WINDOW, &"PanelContainer")
	var win := StyleBoxFlat.new()
	win.bg_color = Color(0.02, 0.02, 0.06, 0.82)
	win.border_color = Color(0.32, 0.32, 0.45, 0.9)
	win.set_border_width_all(2)
	win.set_content_margin_all(18)
	th.set_stylebox(&"panel", WINDOW, win)
	# Pasek u góry (log bitwy / pytanie): ciemny, półprzezroczysty, bez ramki.
	th.set_type_variation(LOG, &"PanelContainer")
	var lg := StyleBoxFlat.new()
	lg.bg_color = Color(0, 0, 0, 0.62)
	lg.content_margin_left = 32
	lg.content_margin_right = 32
	lg.content_margin_top = 20
	lg.content_margin_bottom = 20
	th.set_stylebox(&"panel", LOG, lg)
	# Pozycja menu: bez tła; zaznaczona — biała linia pod tekstem (styl „selected”).
	th.set_type_variation(MENU_ITEM, &"Button")
	var item := _menu_item_box(false)
	for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		th.set_stylebox(st, MENU_ITEM, item)
	th.set_stylebox(&"focus", MENU_ITEM, StyleBoxEmpty.new())
	th.set_stylebox(&"selected", MENU_ITEM, _menu_item_box(true))
	th.set_color(&"font_color", MENU_ITEM, Color(0.86, 0.88, 0.94))
	th.set_color(&"font_hover_color", MENU_ITEM, Color.WHITE)
	th.set_color(&"font_pressed_color", MENU_ITEM, Color.WHITE)
	th.set_color(&"font_focus_color", MENU_ITEM, Color(0.86, 0.88, 0.94))
	th.set_color(&"font_selected_color", MENU_ITEM, Color.WHITE)
	th.set_color(&"font_disabled_color", MENU_ITEM, Color(0.45, 0.46, 0.52))
	th.set_constant(&"outline_size", MENU_ITEM, 6)
	th.set_color(&"font_outline_color", MENU_ITEM, Color.BLACK)
	return th


static func _menu_item_box(selected: bool) -> StyleBoxFlat:
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
