@tool
extends Control

## Edytor pól walki (WYSIWYG): scenes/tools/battle_layout_preview.tscn.
## 1. Przeciągnij plik `<grafika>_layout.tres` (obok grafiki tła) do „layout”.
## 2. Każde pole walki to prostokąt „Field…” — obszar stóp wrogów: dolna krawędź = rząd przedni,
##    górna = rząd najdalszy. Przesuwaj / rozciągaj myszą (uchwyty edytora 2D).
##    Nowe pole (np. platforma): zaznacz prostokąt i Ctrl+D. Usunięcie pola: Delete na prostokącie.
## 3. Rzędy, pojemność rzędu, skale i wcięcie tylnego rzędu: inspektor pliku układu → fields → pole.
## Zmiany trafiają do pliku układu (zapis po chwili bez ruchu); zmiana w inspektorze przesuwa prostokąty.
## Tło, dolny pasek i przykładowi wrogowie liczone funkcjami BattleBackgroundLayout — jak w grze
## (1920×1080, dolny pasek UI 250 px).

## Pola walki do edycji (plik obok grafiki tła).
@export var layout: BattleBackgroundLayout:
	set(v):
		if layout and layout.changed.is_connected(_on_layout_changed):
			layout.changed.disconnect(_on_layout_changed)
		layout = v
		if layout:
			layout.changed.connect(_on_layout_changed)
		_rebuild_nodes()
## Przykładowi wrogowie w każdym rzędzie (najwyżej pojemność rzędu).
@export_range(1, 8) var preview_per_row := 2:
	set(v):
		preview_per_row = v
		queue_redraw()
## Grafika wroga do podglądu (pierwsza klatka).
@export var enemy_frames: SpriteFrames:
	set(v):
		enemy_frames = v
		queue_redraw()

const SAVE_DELAY := 0.6          # s bez zmian po przeciągnięciu -> zapis pliku układu
const BAND := 250.0              # dolny pasek UI walki (obszar bitwy = REF_AREA)
const COLORS: Array[Color] = [Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 1.0), Color(1.0, 0.45, 0.8), Color(0.5, 1.0, 0.5)]

var _nodes: Array[ReferenceRect] = []   # prostokąt pola i (ta sama kolejność co layout.fields)
var _dirty_time := -1.0
var _syncing := false


func _ready() -> void:
	_rebuild_nodes()


## Prostokąty = pola z pliku (po wczytaniu pliku albo zmianie listy pól w inspektorze).
func _rebuild_nodes() -> void:
	queue_redraw()
	if not is_inside_tree():
		return
	for c in get_children():
		if c is ReferenceRect and str(c.name).begins_with("Field"):
			remove_child(c)
			c.queue_free()
	_nodes.clear()
	if layout == null:
		return
	for i in range(layout.fields.size()):
		_nodes.append(_make_node(i))
	_apply_rects()


func _make_node(i: int) -> ReferenceRect:
	var r := ReferenceRect.new()
	r.name = "Field%d" % (i + 1)
	r.border_color = COLORS[i % COLORS.size()]
	r.border_width = 3.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		r.owner = get_tree().edited_scene_root
	return r


## Plik -> prostokąty (bez przebudowy węzłów).
func _apply_rects() -> void:
	if layout == null:
		return
	_syncing = true
	for i in range(mini(_nodes.size(), layout.fields.size())):
		if is_instance_valid(_nodes[i]):
			_nodes[i].position = layout.fields[i].rect.position
			_nodes[i].size = layout.fields[i].rect.size
	_syncing = false


func _on_layout_changed() -> void:
	queue_redraw()
	if _syncing or layout == null:
		return
	if layout.fields.size() != _nodes.size():
		_rebuild_nodes()
	else:
		_apply_rects()


## Prostokąty -> plik: przeciąganie, nowe pole (Ctrl+D), usunięte pole (Delete).
func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or layout == null:
		return
	var changed := false
	var fields: Array[BattleField] = layout.fields.duplicate()
	# Usunięte prostokąty -> usuń pola (od końca, żeby indeksy się zgadzały).
	for i in range(_nodes.size() - 1, -1, -1):
		if not is_instance_valid(_nodes[i]) or _nodes[i].get_parent() != self:
			_nodes.remove_at(i)
			fields.remove_at(i)
			changed = true
	# Nowe prostokąty (zduplikowane) -> nowe pola z kopią ustawień pola źródłowego.
	for c in get_children():
		if c is ReferenceRect and str(c.name).begins_with("Field") and not _nodes.has(c):
			var src: BattleField = fields[fields.size() - 1] if not fields.is_empty() else BattleField.new()
			var f := src.duplicate() as BattleField
			f.rect = Rect2(c.position, c.size)
			fields.append(f)
			_nodes.append(c)
			(c as ReferenceRect).border_color = COLORS[(fields.size() - 1) % COLORS.size()]
			changed = true
	# Przesunięte / rozciągnięte prostokąty.
	for i in range(_nodes.size()):
		var r := Rect2(_nodes[i].position.round(), _nodes[i].size.round())
		if fields[i].rect != r:
			fields[i].rect = r
			changed = true
	if changed:
		_syncing = true
		layout.fields = fields
		_syncing = false
		_dirty_time = SAVE_DELAY
		queue_redraw()
	elif _dirty_time > 0.0:
		_dirty_time -= delta
		if _dirty_time <= 0.0 and layout.resource_path != "":
			ResourceSaver.save(layout, layout.resource_path)


func _draw() -> void:
	var view := BattleBackgroundLayout.REF_SIZE
	var area := BattleBackgroundLayout.REF_AREA
	var l: BattleBackgroundLayout = layout if layout else BattleBackgroundLayout.new()
	# Tło jak w grze: wypełnia obszar bitwy (skala „cover”, wyśrodkowane).
	draw_rect(Rect2(Vector2.ZERO, area), Color(0.08, 0.07, 0.11))
	if l.texture:
		var ts := l.texture.get_size()
		var k := maxf(area.x / ts.x, area.y / ts.y)
		var origin := (area - ts * k) * 0.5
		draw_texture_rect_region(l.texture, Rect2(Vector2.ZERO, area), Rect2(-origin / k, area / k))
	draw_rect(Rect2(0.0, area.y, view.x, BAND), Color(0.02, 0.02, 0.05))
	# Rzędy pól i przykładowi wrogowie (miejsca liczone jak w grze).
	var fl := l.active_fields()
	var spots: Array = []
	for fi in range(fl.size()):
		var f: BattleField = fl[fi]
		var n := mini(preview_per_row, f.row_capacity)
		for r in range(f.rows - 1, -1, -1):  # od tyłu — przedni rząd rysowany na wierzchu
			for k in range(n):
				var sp := BattleBackgroundLayout.Spot.new()
				sp.field = fi
				sp.row = r
				sp.k = k
				sp.n = n
				spots.append(sp)
	var total := spots.size()
	for fi in range(fl.size()):
		var f: BattleField = fl[fi]
		var col := COLORS[fi % COLORS.size()]
		for r in range(f.rows):
			var a := BattleBackgroundLayout.Spot.new()
			a.field = fi
			a.row = r
			a.k = 0
			a.n = 1
			var y := l.foot(a, area, view).y
			var inset := f.back_row_inset * f.row_t(r)
			draw_line(Vector2(f.rect.position.x + inset, y), Vector2(f.rect.end.x - inset, y), Color(col, 0.7), 2.0)
	for sp in spots:
		var col := COLORS[sp.field % COLORS.size()]
		var sc := BattleBackgroundLayout.enemy_scale(total, view) * l.spot_scale(sp)
		_draw_enemy(l.foot(sp, area, view), sc, col)


func _draw_enemy(foot: Vector2, sc: float, col: Color) -> void:
	var tex: Texture2D = null
	if enemy_frames:
		var anims := enemy_frames.get_animation_names()
		if anims.size() > 0 and enemy_frames.get_frame_count(anims[0]) > 0:
			tex = enemy_frames.get_frame_texture(anims[0], 0)
	if tex:
		# Jak EnemyBattleDisplay: dolny nieprzezroczysty wiersz grafiki na linii stóp.
		var sz := tex.get_size() * sc
		var bottom := float(_visible_bottom(tex)) * sc
		draw_texture_rect(tex, Rect2(foot - Vector2(sz.x * 0.5, bottom), sz), false)
	else:
		var w := BattleBackgroundLayout.ENEMY_BASE_PX * sc
		draw_rect(Rect2(foot - Vector2(w * 0.5, w), Vector2(w, w)), Color(col, 0.5))
	draw_circle(foot, 5.0, col)


var _bottom_cache := {}


func _visible_bottom(tex: Texture2D) -> int:
	if _bottom_cache.has(tex):
		return _bottom_cache[tex]
	var h := tex.get_height()
	var img := tex.get_image()
	if img:
		for y in range(img.get_height() - 1, -1, -1):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.05:
					h = y + 1
					_bottom_cache[tex] = h
					return h
	_bottom_cache[tex] = h
	return h
