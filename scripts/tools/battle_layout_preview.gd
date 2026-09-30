@tool
extends Control

## Edytor wymiarów pola walki (WYSIWYG): scenes/tools/battle_layout_preview.tscn.
## 1. Przeciągnij plik `<grafika>_layout.tres` (obok grafiki tła) do „layout”.
## 2. Przesuwaj / rozciągaj myszą prostokąty (uchwyty edytora 2D):
##    - Field (żółty) — górna i dolna krawędź pola walki (wysokość, odstęp od dolnego paska UI),
##    - BackRowMargin / FrontRowMargin — szerokość = margines rzędu tylnego / przedniego od krawędzi
##      ekranu (prawa strona lustrzanie).
##    Wartości od razu trafiają do pliku układu (zapis po chwili bez ruchu); działa też odwrotnie —
##    zmiana w inspektorze przesuwa prostokąty.
## Tło, dolny pasek i przykładowi wrogowie liczone funkcjami BattleBackgroundLayout — jak w grze.

## Wymiary pola walki do edycji (plik obok grafiki tła).
@export var layout: BattleBackgroundLayout:
	set(v):
		if layout and layout.changed.is_connected(_on_layout_changed):
			layout.changed.disconnect(_on_layout_changed)
		layout = v
		if layout:
			layout.changed.connect(_on_layout_changed)
		_on_layout_changed()
## Wysokość dolnego paska UI walki (jak BattleWindow w scenie walki).
@export var band_height := 250.0:
	set(v):
		band_height = v
		_on_layout_changed()
## Wrogowie w rzędzie przednim / tylnym (w grze przydział jest losowy).
@export_range(0, 5) var front_count := 2:
	set(v):
		front_count = v
		queue_redraw()
@export_range(0, 5) var back_count := 1:
	set(v):
		back_count = v
		queue_redraw()
## Grafika wroga do podglądu (pierwsza klatka).
@export var enemy_frames: SpriteFrames:
	set(v):
		enemy_frames = v
		queue_redraw()

const SAVE_DELAY := 0.6  # s bez zmian po przeciągnięciu -> zapis pliku układu

var _last := Vector4(-1, -1, -1, -1)   # wysokość, odstęp od dołu, margines przedni, margines tylny
var _dirty_time := -1.0


func _ref_size() -> Vector2:
	return size if size.x > 0.0 and size.y > 0.0 else BattleBackgroundLayout.REF_SIZE


func _field_bottom() -> float:
	return _ref_size().y - band_height


func _nodes() -> Array:
	return [get_node_or_null("Field") as Control, get_node_or_null("BackRowMargin") as Control, get_node_or_null("FrontRowMargin") as Control]


## Prostokąty istnieją (przy wczytywaniu sceny `layout` ustawia się przed dziećmi).
func _nodes_ready(n: Array) -> bool:
	for x in n:
		if not is_instance_valid(x):
			return false
	return true


func _ready() -> void:
	_on_layout_changed()


## Układ -> prostokąty (po wczytaniu pliku albo zmianie w inspektorze).
func _on_layout_changed() -> void:
	queue_redraw()
	var n := _nodes()
	if layout == null or not _nodes_ready(n):
		return
	var field: Control = n[0]
	var bottom := _field_bottom() - layout.field_bottom_margin
	field.position = Vector2(0.0, bottom - layout.field_height)
	field.size = Vector2(_ref_size().x, layout.field_height)
	_place_rows(layout.back_row_side_margin, layout.front_row_side_margin)
	_last = Vector4(layout.field_height, layout.field_bottom_margin, layout.front_row_side_margin, layout.back_row_side_margin)


## Paski marginesów rzędów: górna / dolna połowa pola walki, od lewej krawędzi.
func _place_rows(back_margin: float, front_margin: float) -> void:
	var n := _nodes()
	var field: Control = n[0]
	var half := field.size.y * 0.5
	(n[1] as Control).position = Vector2(0.0, field.position.y)
	(n[1] as Control).size = Vector2(back_margin, half)
	(n[2] as Control).position = Vector2(0.0, field.position.y + half)
	(n[2] as Control).size = Vector2(front_margin, half)


## Prostokąty -> układ (przeciąganie w edytorze), zapis pliku po chwili bez zmian.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or layout == null:
		return
	var n := _nodes()
	if not _nodes_ready(n):
		return
	var field: Control = n[0]
	var cur := Vector4(roundf(field.size.y), roundf(_field_bottom() - field.position.y - field.size.y),
		roundf((n[2] as Control).size.x), roundf((n[1] as Control).size.x))
	if cur != _last:
		_last = cur
		if layout.changed.is_connected(_on_layout_changed):
			layout.changed.disconnect(_on_layout_changed)
		layout.field_height = cur.x
		layout.field_bottom_margin = cur.y
		layout.front_row_side_margin = cur.z
		layout.back_row_side_margin = cur.w
		layout.changed.connect(_on_layout_changed)
		_place_rows(cur.w, cur.z)
		_dirty_time = SAVE_DELAY
		queue_redraw()
	elif _dirty_time > 0.0:
		_dirty_time -= delta
		if _dirty_time <= 0.0 and layout.resource_path != "":
			ResourceSaver.save(layout, layout.resource_path)


func _draw() -> void:
	var view := _ref_size()
	var field := Rect2(Vector2.ZERO, Vector2(view.x, _field_bottom()))
	var l: BattleBackgroundLayout = layout if layout else BattleBackgroundLayout.new()
	# Tło jak w grze: wypełnia obszar bitwy (skala „cover”, wyśrodkowane).
	draw_rect(field, Color(0.08, 0.07, 0.11))
	if l.texture:
		var ts := l.texture.get_size()
		var k := maxf(field.size.x / ts.x, field.size.y / ts.y)
		var origin := (field.size - ts * k) * 0.5
		draw_texture_rect_region(l.texture, field, Rect2(-origin / k, field.size / k))
	draw_rect(Rect2(0.0, field.end.y, view.x, band_height), Color(0.02, 0.02, 0.05))
	# Pole walki i przykładowi wrogowie (górna połowa — rząd tylny, dolna — przedni).
	var offs := l.section_offsets(view)
	var sec := Rect2(0.0, field.end.y + offs.x, view.x, offs.y - offs.x)
	draw_rect(sec, Color(1.0, 0.85, 0.2, 0.08))
	var total := front_count + back_count
	var front_scale := BattleBackgroundLayout.enemy_scale(total, false, view)
	for row in [[true, back_count, sec.position.y + sec.size.y * 0.5], [false, front_count, sec.end.y]]:
		var back: bool = row[0]
		var cnt: int = row[1]
		var row_bottom: float = row[2]
		var m := float(l.row_margin(back, front_scale, view.x))
		var col := Color(0.4, 0.8, 1.0, 0.9) if back else Color(0.4, 1.0, 0.5, 0.9)
		# Linia, od której zaczynają się sloty wrogów (margines + połowa wroga), obie strony.
		for x in [m, view.x - m]:
			draw_line(Vector2(x, row_bottom - sec.size.y * 0.5), Vector2(x, row_bottom), Color(col, 0.5), 1.0)
		for i in range(cnt):
			var cx := m + (view.x - 2.0 * m) * (i + 0.5) / cnt
			_draw_enemy(Vector2(cx, row_bottom - 8.0), BattleBackgroundLayout.enemy_scale(total, back, view), col)


func _draw_enemy(foot: Vector2, sc: float, col: Color) -> void:
	var tex: Texture2D = null
	if enemy_frames:
		var anims := enemy_frames.get_animation_names()
		if anims.size() > 0 and enemy_frames.get_frame_count(anims[0]) > 0:
			tex = enemy_frames.get_frame_texture(anims[0], 0)
	if tex:
		var sz := tex.get_size() * sc
		draw_texture_rect(tex, Rect2(foot - Vector2(sz.x * 0.5, sz.y), sz), false)
	else:
		var w := BattleBackgroundLayout.ENEMY_BASE_PX * sc
		draw_rect(Rect2(foot - Vector2(w * 0.5, w), Vector2(w, w)), Color(col, 0.5))
	draw_circle(foot, 5.0, col)
