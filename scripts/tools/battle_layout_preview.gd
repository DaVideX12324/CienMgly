@tool
extends Control

## Edytor pól walki (WYSIWYG): scenes/tools/battle_layout_preview.tscn.
## 1. Przeciągnij plik `<grafika>_layout.tres` (obok grafiki tła) do „layout”.
## 2. Każde pole walki to czworobok „Field…” (Polygon2D, zwykle trapez): przednia krawędź (niżej) =
##    rząd przedni, tylna = rząd najdalszy. Zaznacz pole i przeciągaj narożniki (edycja wielokąta
##    w edytorze 2D); kolejność punktów dowolna. Punkty pośrednie na bokach (dodaj punkt na krawędzi
##    w edytorze wielokąta, np. bok wzdłuż schodów) — rzędy idą przez te punkty: rząd k łączy k-ty punkt
##    lewego boku z k-tym prawego (3 rzędy przy jednym punkcie na boku = rząd środkowy na punktach);
##    przednia / tylna krawędź = najniższa / najwyższa krawędź wielokąta.
##    Nowe pole (np. platforma): zaznacz pole i Ctrl+D. Usunięcie pola: Delete.
##    Pola są pod węzłem „Fields” w punkcie (0, 0) = prawy dolny róg obszaru walki nad kreską cienia
##    z miejscem na pasek HP (1920, 765 px ekranu); po otwarciu sceny Position pola = jego prawy dolny
##    róg względem tego punktu — y > 0 oznacza, że paski HP przedniego rzędu wejdą w cień. W trakcie
##    edycji węzeł nie jest przepisywany (kolejność punktów, zaczepienie), żeby działało cofanie (Ctrl+Z).
## 3. Rzędy, pojemność (też per rząd), skale wrogów: inspektor pliku układu → fields → pole.
## Zmiany trafiają do pliku układu (zapis po chwili bez ruchu); zmiana kształtu w inspektorze przesuwa pola.
## Tło, dolny pasek, linie rzędów i przykładowi wrogowie liczone funkcjami BattleBackgroundLayout —
## jak w grze (1920×1080, dolny pasek UI 250 px).
## Przykładowi wrogowie: grafiki z „enemy_sprites” po kolei; domyślnie pełne rzędy (pojemność z pola),
## konkretna liczba wrogów na polu — „field_counts”.

## Pola walki do edycji (plik obok grafiki tła).
@export var layout: BattleBackgroundLayout:
	set(v):
		if layout and layout.changed.is_connected(_on_layout_changed):
			layout.changed.disconnect(_on_layout_changed)
		layout = v
		if layout:
			layout.changed.connect(_on_layout_changed)
		_rebuild_nodes()
## Ilu wrogów na polu 1, 2, … (rozdzieleni po rzędach od przedniego, najwyżej pojemność pola) — do
## sprawdzenia konkretnej walki. Pole bez wpisu albo z -1 — pełne rzędy; 0 — pole puste.
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
const FolderBackground := preload("../quiz/background_generators/folder_battle_background.gd")
const ZONE_LINE := Color(1.0, 0.35, 0.35, 0.95)
const ZONE_TEXT := Color(1.0, 0.8, 0.8)
## Pasek HP wroga w walce: 12 px pod linią stóp (slot 8 px niżej + odstęp), 96 px szerokości; wysokość
## zależy od stylu pasków (8–16 px) — rysowany najwyższy, żeby było widać najgorszy przypadek.
const HP_BAR_OFFSET := 12.0
const HP_BAR_SIZE := Vector2(96.0, 16.0)
const COLORS: Array[Color] = [Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 1.0), Color(1.0, 0.45, 0.8), Color(0.5, 1.0, 0.5)]

var _nodes: Array[Polygon2D] = []   # czworobok pola i (ta sama kolejność co layout.fields)
var _dirty_time := -1.0
var _syncing := false
var _bottom_cache := {}


func _ready() -> void:
	_rebuild_nodes()


## Punkt (0, 0) pól w edytorze: prawy dolny róg obszaru walki, tak wysoko nad kreską cienia, żeby pasek HP
## wroga stojącego na tej linii (12 px pod stopami, do 16 px wysoki) + 2 px zapasu kończył się nad cieniem
## — y = 830 − 35 − 28 − 2 = 765 (przedni rząd obecnych układów). Pozycja pola w inspektorze = jego prawy
## dolny róg względem tego punktu (w lewo / w górę = ujemne; dodatnie y = pasek HP wejdzie w cień).
const HP_MARGIN := 2.0
static func fields_origin() -> Vector2:
	var area := BattleBackgroundLayout.REF_AREA
	return Vector2(area.x, area.y - FolderBackground.SHADOW_HEIGHT - HP_BAR_OFFSET - HP_BAR_SIZE.y - HP_MARGIN)


## Kontener „Fields” w punkcie fields_origin() — rodzic czworoboków pól (tworzony, gdy go brak).
func _holder() -> Node2D:
	var h := get_node_or_null("Fields") as Node2D
	if h == null:
		h = Node2D.new()
		h.name = "Fields"
		add_child(h)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			h.owner = get_tree().edited_scene_root
	return h


## Czworoboki = pola z pliku (po wczytaniu pliku albo zmianie listy pól w inspektorze).
func _rebuild_nodes() -> void:
	queue_redraw()
	if not is_inside_tree():
		return
	var h := _holder()
	for parent in [self, h]:
		for c in parent.get_children():
			if str(c.name).begins_with("Field") and c != h:
				parent.remove_child(c)
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
	_holder().add_child(p)
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		p.owner = get_tree().edited_scene_root
	return p


## Plik -> czworoboki (bez przebudowy węzłów). `only_changed` — tylko węzły, których kształt różni się od
## pliku (zmiana kształtu z inspektora); węzeł z tym samym kształtem zostaje nietknięty, bo przepisanie
## punktów / pozycji poza historią edytora psuje cofanie (Ctrl+Z przywraca punkty przy nowej pozycji).
func _apply_quads(only_changed := false) -> void:
	if layout == null:
		return
	_syncing = true
	if not only_changed:
		_holder().transform = Transform2D(0.0, fields_origin())
	for i in range(mini(_nodes.size(), layout.fields.size())):
		if is_instance_valid(_nodes[i]):
			if only_changed and _node_quad(_nodes[i]) == layout.fields[i].quad:
				continue
			# Punkt zaczepienia węzła = prawy dolny róg pola (prawy koniec przedniej krawędzi): Position
			# w inspektorze = ten narożnik względem fields_origin(), skalowanie uchwytem — wokół niego.
			# Skala / obrót zawsze 1 / 0, narożniki względem zaczepienia (na ekranie = quad z pliku).
			var q: PackedVector2Array = layout.fields[i].quad
			var pivot: Vector2 = q[1] if q.size() >= 4 else Vector2.ZERO
			var local := PackedVector2Array()
			for v in q:
				local.append(v - pivot)
			_nodes[i].transform = Transform2D(0.0, pivot - fields_origin())
			_nodes[i].polygon = local
	_syncing = false


func _on_layout_changed() -> void:
	queue_redraw()
	if _syncing or layout == null:
		return
	if layout.fields.size() != _nodes.size():
		_rebuild_nodes()
	else:
		_apply_quads(true)


## Punkty pola w px wzorcowych (z przesunięciem węzła), w kolejności pola; pusto, gdy mniej niż 4.
func _node_quad(p: Polygon2D) -> PackedVector2Array:
	if p.polygon.size() < 4:
		return PackedVector2Array()
	var out := PackedVector2Array()
	var parent_xf: Transform2D = (p.get_parent() as Node2D).transform if p.get_parent() is Node2D else Transform2D.IDENTITY
	for v in p.polygon:
		var w: Vector2 = parent_xf * (p.transform * v)
		if not w.is_finite():
			return PackedVector2Array()  # zły odczyt w trakcie edycji — pomiń klatkę
		out.append(w.round())
	return BattleField.normalized(out)


## Czworoboki -> plik: przeciąganie narożników, nowe pole (Ctrl+D), usunięte pole (Delete).
func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or layout == null:
		return
	if layout.fields.has(null):
		layout.fields = layout.fields  # setter zamienia pusty wpis („Add Element”) na nowe pole
		_dirty_time = SAVE_DELAY
		return
	# Zmiany z węzłów idą tylko do pliku — blokada PRZED zapisem do pól, inaczej sygnał `changed` pola
	# nadpisywał wielokąt w trakcie przeciągania narożnika (edytor wielokąta liczył na podmienionej
	# tablicy -> NaN).
	_syncing = true
	var changed := false
	var fields: Array[BattleField] = layout.fields.duplicate()
	for i in range(_nodes.size() - 1, -1, -1):
		if not is_instance_valid(_nodes[i]) or _nodes[i].get_parent() != _holder():
			_nodes.remove_at(i)
			fields.remove_at(i)
			changed = true
	for c in _holder().get_children():
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
		if q.is_empty():
			continue
		if fields[i].quad != q:
			fields[i].quad = q
			changed = true
	if changed:
		layout.fields = fields
		_dirty_time = SAVE_DELAY
		queue_redraw()
	_syncing = false
	if not changed and _dirty_time > 0.0:
		_dirty_time -= delta
		if _dirty_time <= 0.0:
			# węzeł bez zmian (kolejność punktów, zaczepienie, skala) — inaczej cofanie w edytorze przestawia pole
			if layout.resource_path != "":
				ResourceSaver.save(layout, layout.resource_path)


func _draw() -> void:
	var view := BattleBackgroundLayout.REF_SIZE
	var area := BattleBackgroundLayout.REF_AREA
	var l: BattleBackgroundLayout = layout if layout else BattleBackgroundLayout.new()
	# Tło jak w grze: wypełnia całe okno 16:9 (skala „cover”, wyśrodkowane).
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.08, 0.07, 0.11))
	if l.texture:
		var ts := l.texture.get_size()
		var k := maxf(view.x / ts.x, view.y / ts.y)
		var origin := (view - ts * k) * 0.5
		draw_texture_rect_region(l.texture, Rect2(Vector2.ZERO, view), Rect2(-origin / k, view / k))
	_draw_ui_zones(view, area)
	var fl := l.active_fields()
	# Obrys pól i linie rzędów.
	for fi in range(fl.size()):
		var f: BattleField = fl[fi]
		var col := COLORS[fi % COLORS.size()]
		if f.quad.size() >= 4:
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
	var battle_sc := l.battle_scale(spots, view)
	var order: Array = range(spots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return feet[a].y < feet[b].y)
	for i in order:
		var sp: BattleBackgroundLayout.Spot = spots[i]
		var sc := battle_sc * l.spot_scale(sp)
		var frames: SpriteFrames = enemy_sprites[i % enemy_sprites.size()] if not enemy_sprites.is_empty() else null
		_draw_enemy(feet[i], sc, COLORS[sp.field % COLORS.size()], frames)


## Ilu przykładowych wrogów w każdym rzędzie pola (indeks 0 = przedni).
func _row_counts(f: BattleField, fi: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(f.rows)
	var total := field_counts[fi] if fi < field_counts.size() else -1
	if total < 0:
		for r in range(f.rows):
			out[r] = f.capacity(r)  # domyślnie pełne rzędy
		return out
	out.fill(0)
	total = mini(total, f.total_capacity())
	var r := 0
	while total > 0:  # po kolei do rzędów od przedniego, pełne rzędy pomijane
		if out[r] < f.capacity(r):
			out[r] += 1
			total -= 1
		r = (r + 1) % f.rows
	return out


## Strefy zasłonięte w walce: cień nad paskiem UI (jak w grze, FolderBackground.SHADOW_*) i dolny pasek
## UI walki — z obrysem i podpisem, żeby pola walki stawiać nad nimi.
func _draw_ui_zones(view: Vector2, area: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var shadow := Rect2(0.0, area.y - FolderBackground.SHADOW_HEIGHT, view.x, FolderBackground.SHADOW_HEIGHT)
	draw_rect(shadow, FolderBackground.SHADOW_COLOR)
	draw_dashed_line(shadow.position, Vector2(view.x, shadow.position.y), ZONE_LINE, 2.0, 12.0)
	draw_string(font, Vector2(view.x - 330.0, shadow.position.y + 25.0), "Cień nad UI (%d px)" % FolderBackground.SHADOW_HEIGHT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ZONE_TEXT)
	var band := Rect2(0.0, area.y, view.x, BAND)
	draw_rect(band, Color(0.02, 0.02, 0.05, 0.55))
	draw_rect(band.grow(-2.0), ZONE_LINE, false, 3.0)
	draw_string(font, band.position + Vector2(24.0, 44.0), "Dolny pasek UI walki (%d px) — tu nie stawiaj wrogów" % BAND,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ZONE_TEXT)


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
	var bar := Rect2(foot + Vector2(-HP_BAR_SIZE.x * 0.5, HP_BAR_OFFSET), HP_BAR_SIZE)
	draw_rect(bar, Color(0.06, 0.06, 0.08, 0.9))
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2(bar.size.x * 0.7, bar.size.y - 4)), Color(0.85, 0.15, 0.2))
	draw_rect(bar, Color(0, 0, 0), false, 2.0)


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
