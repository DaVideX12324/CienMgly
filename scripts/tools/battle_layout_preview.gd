@tool
extends Control

## Edytor pól walki (WYSIWYG): scenes/tools/battle_layout_preview.tscn.
## 1. Przeciągnij plik `<grafika>_layout.tres` (obok grafiki tła) do „layout”.
## 2. Każde pole walki to czworobok „Field…” (Polygon2D, zwykle trapez): przednia krawędź (niżej) =
##    rząd przedni, tylna = rząd najdalszy. Zaznacz pole i przeciągaj narożniki (edycja wielokąta
##    w edytorze 2D); kolejność punktów dowolna — pole zawsze ma 4 narożniki.
##    Nowe pole (np. platforma): zaznacz pole i Ctrl+D. Usunięcie pola: Delete.
## 3. Rzędy, pojemność rzędu, skale (auto z kształtu albo ręczne): inspektor pliku układu → fields → pole.
## Zmiany trafiają do pliku układu (zapis po chwili bez ruchu); zmiana w inspektorze przesuwa pola.
## Tło, dolny pasek, linie rzędów i przykładowi wrogowie liczone funkcjami BattleBackgroundLayout —
## jak w grze (1920×1080, dolny pasek UI 250 px).
## Przykładowi wrogowie: grafiki z „enemy_sprites” po kolei; ilu na każdym polu — „field_counts”
## (bez wpisu dla pola — „preview_per_row” w każdym rzędzie).

## Pola walki do edycji (plik obok grafiki tła).
@export var layout: BattleBackgroundLayout:
	set(v):
		if layout and layout.changed.is_connected(_on_layout_changed):
			layout.changed.disconnect(_on_layout_changed)
		layout = v
		if layout:
			layout.changed.connect(_on_layout_changed)
		_rebuild_nodes()
## Przykładowi wrogowie w każdym rzędzie pola bez wpisu w field_counts (najwyżej pojemność rzędu).
@export_range(1, 8) var preview_per_row := 2:
	set(v):
		preview_per_row = v
		queue_redraw()
## Ilu wrogów na polu 1, 2, … (rozdzieleni po rzędach od przedniego, najwyżej rzędy × pojemność).
## Pole bez wpisu albo z -1 — preview_per_row w każdym rzędzie; 0 — pole puste.
@export var field_counts := PackedInt32Array():
	set(v):
		field_counts = v
		queue_redraw()
## Grafiki wrogów do podglądu (klatka postoju jak w walce), rozdawane po kolei: pole 1 od przedniego
## rzędu od lewej, potem pole 2… Gdy lista krótsza niż liczba wrogów — od początku.
@export var enemy_sprites: Array[SpriteFrames] = []:
	set(v):
		enemy_sprites = v
		queue_redraw()

const SAVE_DELAY := 0.6          # s bez zmian po przeciągnięciu -> zapis pliku układu
const BAND := 250.0              # dolny pasek UI walki (obszar bitwy = REF_AREA)
const COLORS: Array[Color] = [Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 1.0), Color(1.0, 0.45, 0.8), Color(0.5, 1.0, 0.5)]

var _nodes: Array[Polygon2D] = []   # czworobok pola i (ta sama kolejność co layout.fields)
var _dirty_time := -1.0
var _syncing := false
var _bottom_cache := {}


func _ready() -> void:
	_rebuild_nodes()


## Czworoboki = pola z pliku (po wczytaniu pliku albo zmianie listy pól w inspektorze).
func _rebuild_nodes() -> void:
	queue_redraw()
	if not is_inside_tree():
		return
	for c in get_children():
		if str(c.name).begins_with("Field"):
			remove_child(c)
			c.queue_free()
	_nodes.clear()
	if layout == null:
		return
	for i in range(layout.fields.size()):
		_nodes.append(_make_node(i))
	_apply_quads()


func _make_node(i: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = "Field%d" % (i + 1)
	p.color = Color(COLORS[i % COLORS.size()], 0.18)
	add_child(p)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		p.owner = get_tree().edited_scene_root
	return p


## Plik -> czworoboki (bez przebudowy węzłów).
func _apply_quads() -> void:
	if layout == null:
		return
	_syncing = true
	for i in range(mini(_nodes.size(), layout.fields.size())):
		if is_instance_valid(_nodes[i]):
			_nodes[i].position = Vector2.ZERO
			_nodes[i].polygon = layout.fields[i].quad
	_syncing = false


func _on_layout_changed() -> void:
	queue_redraw()
	if _syncing or layout == null:
		return
	if layout.fields.size() != _nodes.size():
		_rebuild_nodes()
	else:
		_apply_quads()


## Narożniki czworoboku w px wzorcowych (z przesunięciem węzła), posortowane; pusto, gdy nie 4 punkty.
func _node_quad(p: Polygon2D) -> PackedVector2Array:
	if p.polygon.size() != 4:
		return PackedVector2Array()
	var out := PackedVector2Array()
	for v in p.polygon:
		var w: Vector2 = p.transform * v
		if not w.is_finite():
			return PackedVector2Array()  # zły odczyt w trakcie edycji — pomiń klatkę
		out.append(w.round())
	return BattleField.sorted_quad(out)


## Czworoboki -> plik: przeciąganie narożników, nowe pole (Ctrl+D), usunięte pole (Delete).
func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or layout == null:
		return
	# Zmiany z węzłów idą tylko do pliku — blokada PRZED zapisem do pól, inaczej sygnał `changed` pola
	# nadpisywał wielokąt w trakcie przeciągania narożnika (edytor wielokąta liczył na podmienionej
	# tablicy -> NaN).
	_syncing = true
	var changed := false
	var fields: Array[BattleField] = layout.fields.duplicate()
	for i in range(_nodes.size() - 1, -1, -1):
		if not is_instance_valid(_nodes[i]) or _nodes[i].get_parent() != self:
			_nodes.remove_at(i)
			fields.remove_at(i)
			changed = true
	for c in get_children():
		if c is Polygon2D and str(c.name).begins_with("Field") and not _nodes.has(c):
			var src: BattleField = fields[fields.size() - 1] if not fields.is_empty() else BattleField.new()
			var f := src.duplicate() as BattleField
			var q := _node_quad(c)
			if not q.is_empty():
				f.quad = q
			fields.append(f)
			_nodes.append(c)
			(c as Polygon2D).color = Color(COLORS[(fields.size() - 1) % COLORS.size()], 0.18)
			changed = true
	for i in range(_nodes.size()):
		var q := _node_quad(_nodes[i])
		if not q.is_empty() and fields[i].quad != q:
			fields[i].quad = q
			changed = true
	if changed:
		layout.fields = fields
		_dirty_time = SAVE_DELAY
		queue_redraw()
	_syncing = false
	if not changed and _dirty_time > 0.0:
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
	var fl := l.active_fields()
	# Obrys pól i linie rzędów.
	for fi in range(fl.size()):
		var f: BattleField = fl[fi]
		var col := COLORS[fi % COLORS.size()]
		if f.quad.size() == 4:
			var outline := f.quad.duplicate()
			outline.append(f.quad[0])
			draw_polyline(outline, col, 3.0)
			for r in range(f.rows):
				var line := f.row_line(r)
				draw_line(line[0], line[1], Color(col, 0.7), 2.0)
	# Przykładowi wrogowie (miejsca liczone jak w grze); grafiki po kolei od przedniego rzędu pola 1.
	var spots: Array = []
	for fi in range(fl.size()):
		var per_row := _row_counts(fl[fi], fi)
		for r in range(per_row.size()):
			for k in range(per_row[r]):
				var sp := BattleBackgroundLayout.Spot.new()
				sp.field = fi
				sp.row = r
				sp.k = k
				sp.n = per_row[r]
				spots.append(sp)
	var feet: Array[Vector2] = []
	for sp in spots:
		feet.append(l.foot(sp, area, view))
	# Rysowanie od najdalszej linii stóp (wyżej na ekranie), żeby bliżsi zasłaniali dalszych.
	var order: Array = range(spots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return feet[a].y < feet[b].y)
	for i in order:
		var sp: BattleBackgroundLayout.Spot = spots[i]
		var sc := BattleBackgroundLayout.enemy_scale(spots.size(), view) * l.spot_scale(sp)
		var frames: SpriteFrames = enemy_sprites[i % enemy_sprites.size()] if not enemy_sprites.is_empty() else null
		_draw_enemy(feet[i], sc, COLORS[sp.field % COLORS.size()], frames)


## Ilu przykładowych wrogów w każdym rzędzie pola (indeks 0 = przedni).
func _row_counts(f: BattleField, fi: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(f.rows)
	var total := field_counts[fi] if fi < field_counts.size() else -1
	if total < 0:
		out.fill(mini(preview_per_row, f.row_capacity))
		return out
	out.fill(0)
	total = mini(total, f.rows * f.row_capacity)
	for e in range(total):  # po kolei do rzędów, od przedniego
		out[e % f.rows] += 1
	return out


func _draw_enemy(foot: Vector2, sc: float, col: Color, frames: SpriteFrames) -> void:
	var tex := _idle_texture(frames)
	if tex:
		# Jak EnemyBattleDisplay: dolny nieprzezroczysty wiersz grafiki na linii stóp.
		var sz := tex.get_size() * sc
		var bottom := float(_visible_bottom(tex)) * sc
		draw_texture_rect(tex, Rect2(foot - Vector2(sz.x * 0.5, bottom), sz), false)
	else:
		var w := BattleBackgroundLayout.ENEMY_BASE_PX * sc
		draw_rect(Rect2(foot - Vector2(w * 0.5, w), Vector2(w, w)), Color(col, 0.5))
	draw_circle(foot, 5.0, col)


## Pierwsza klatka animacji postoju — wybór jak w EnemyBattleDisplay.
func _idle_texture(frames: SpriteFrames) -> Texture2D:
	if frames == null:
		return null
	var anims := frames.get_animation_names()
	if anims.is_empty():
		return null
	var anim := ""
	for candidate: String in ["idle_down", "slime_idle", "idle"]:
		if frames.has_animation(candidate):
			anim = candidate
			break
	if anim == "":
		for candidate: String in anims:
			if candidate.contains("idle"):
				anim = candidate
				break
	if anim == "":
		for candidate: String in ["walk_down", "slime_walk", "walk"]:
			if frames.has_animation(candidate):
				anim = candidate
				break
	if anim == "":
		anim = anims[0]
	return frames.get_frame_texture(anim, 0) if frames.get_frame_count(anim) > 0 else null


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
