extends Button

## Wiersz listy umiejętności / przedmiotów (walka): nazwa = tekst przycisku, koszt / liczba po prawej
## (CostLabel). Wygląd i kolory kosztów w scenie combat_list_row.tscn; zaznaczenie — QuizTheme.set_menu_item_selected.
## Szerokość: custom_minimum_size.x ze sceny to minimum; dłuższa nazwa + koszt poszerzają wiersz (koszt leży nad
## prawym brzegiem przycisku, więc nie może na niego wejść nazwa). Liczbę kolumn dobiera walka (_fit_list_columns).

enum Kind { NONE, SP, TP, COUNT }

@export var sp_color := Color(0.45, 0.75, 1.0)
@export var tp_color := Color(0.55, 0.95, 0.45)
@export var count_color := Color(0.86, 0.88, 0.94)

## Odstęp między końcem nazwy a początkiem kosztu.
@export var name_cost_gap := 24.0
## Bok ikony przedmiotu (ikony 16×16 powiększane bez wygładzania).
@export var icon_size := 32

@onready var _cost: Label = $CostLabel
@onready var _base_min_width := custom_minimum_size.x


func setup(title: String, cost_text: String, kind: Kind, is_disabled: bool, item_icon: Texture2D = null) -> void:
	text = title
	disabled = is_disabled
	icon = _scaled_icon(item_icon)
	_cost.text = cost_text
	var col: Color = {Kind.SP: sp_color, Kind.TP: tp_color, Kind.COUNT: count_color}.get(kind, count_color)
	_cost.modulate = Color(col, 0.45) if is_disabled else col
	_fit_width()


## Ikona powiększona całkowitą krotnością (najbliższy sąsiad) do ~icon_size — Button rysuje ikonę w rozmiarze tekstury.
func _scaled_icon(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	var k := maxi(1, icon_size / maxi(1, img.get_width()))
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _fit_width() -> void:
	var name_w := get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size(&"font_size")).x
	var cost_w := 0.0
	if _cost.text != "":
		cost_w = _cost.get_theme_font(&"font").get_string_size(_cost.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _cost.get_theme_font_size(&"font_size")).x
	var icon_w := float(icon.get_width() + get_theme_constant(&"h_separation")) if icon != null else 0.0
	var sb := get_theme_stylebox(&"normal")
	var pad := sb.get_content_margin(SIDE_LEFT) if sb else 12.0
	var cost_right := -_cost.offset_right  # odstęp kosztu od prawej krawędzi (ze sceny)
	custom_minimum_size.x = maxf(_base_min_width, ceilf(pad + icon_w + name_w + name_cost_gap + cost_w + cost_right))
