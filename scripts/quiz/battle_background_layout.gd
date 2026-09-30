@tool
class_name BattleBackgroundLayout
extends Resource

## Wymiary pola walki (gdzie stoją wrogowie) na konkretnym tle — plik obok grafiki tła
## (`<nazwa>_layout.tres`), edytowany w inspektorze; podgląd: scenes/tools/battle_layout_preview.tscn.
## Wartości w pikselach przy 1920×1080, skalowane do rozdzielczości. Liczenie położenia jest tylko tutaj
## (kontroler walki i podgląd używają tych samych funkcji), więc podgląd pokazuje to, co gra.

## Grafika tła, której dotyczy układ (podgląd w edytorze; tło w grze wybiera generator tła).
@export var texture: Texture2D:
	set(v):
		texture = v
		emit_changed()
## Wysokość pola walki (px).
@export_range(100.0, 800.0, 1.0, "suffix:px") var field_height := 340.0:
	set(v):
		field_height = v
		emit_changed()
## Odstęp dolnej krawędzi pola walki od dołu obszaru bitwy (nad dolnym paskiem UI, px).
@export_range(-100.0, 400.0, 1.0, "suffix:px") var field_bottom_margin := 35.0:
	set(v):
		field_bottom_margin = v
		emit_changed()
## Rząd przedni (bliżej gracza): margines od lewej i prawej krawędzi ekranu (px).
@export_range(0.0, 900.0, 1.0, "suffix:px") var front_row_side_margin := 240.0:
	set(v):
		front_row_side_margin = v
		emit_changed()
## Rząd tylny (dalej): margines od lewej i prawej krawędzi ekranu (px).
@export_range(0.0, 900.0, 1.0, "suffix:px") var back_row_side_margin := 460.0:
	set(v):
		back_row_side_margin = v
		emit_changed()

const LAYOUT_SUFFIX := "_layout.tres"
const REF_SIZE := Vector2(1920.0, 1080.0)
const ENEMY_BASE_PX := 36.0       # szerokość grafiki wroga przed skalą (margines + połowa wroga)


## Plik układu dla grafiki tła (`variant_1.jpg` -> `variant_1_layout.tres`) albo dla tła rysowanego
## w kodzie (ścieżka bez rozszerzenia).
static func path_for(texture_path: String) -> String:
	return texture_path.get_basename() + LAYOUT_SUFFIX


static func load_for(texture_path: String) -> BattleBackgroundLayout:
	var p := path_for(texture_path)
	return load(p) as BattleBackgroundLayout if ResourceLoader.exists(p) else null


## Pole walki w obszarze bitwy: (offset_top, offset_bottom) sekcji wrogów zakotwiczonej do jego dołu.
func section_offsets(viewport_size: Vector2) -> Vector2:
	var res_h: float = clampf(viewport_size.y / REF_SIZE.y, 0.75, 2.5) if viewport_size.y > 0.0 else 1.0
	var bottom := -field_bottom_margin * res_h
	return Vector2(bottom - field_height * res_h, bottom)


## Margines boczny rzędu wrogów (px ekranu): margines pola + połowa największego wroga.
func row_margin(back_row: bool, max_enemy_scale: float, viewport_width: float) -> int:
	var m := back_row_side_margin if back_row else front_row_side_margin
	return int((m + ENEMY_BASE_PX * max_enemy_scale * 0.5) * (viewport_width / REF_SIZE.x))


## Skala wroga na polu walki (ta sama w grze i w podglądzie): mniejsza przy większej liczbie wrogów,
## rząd tylny mniejszy (perspektywa).
static func enemy_scale(active_count: int, back_row: bool, viewport_size: Vector2) -> float:
	var res := 1.0
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		res = clampf(minf(viewport_size.x / REF_SIZE.x, viewport_size.y / REF_SIZE.y), 0.65, 2.5)
	var base := 5.2
	if active_count <= 1:
		base = 8.5
	elif active_count == 2:
		base = 7.2
	elif active_count == 3:
		base = 6.2
	elif active_count == 4:
		base = 5.6
	return base * (0.82 if back_row else 1.0) * clampf(res, 0.7, 2.5)
