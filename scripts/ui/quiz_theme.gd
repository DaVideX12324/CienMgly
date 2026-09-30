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

static var _depth := 0
static var _prev_fallback: Font = null
static var _prev_default: Font = null
static var _prev_size := -1


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
	_prev_fallback = null
	_prev_default = null
