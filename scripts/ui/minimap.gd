extends Control

## Minimapa z fog of war (scena scenes/ui/minimap.tscn w HUD): w rogu wycinek mapy wokół gracza, pod klawiszem
## akcji `minimap` (domyślnie M) cała mapa. Dane: QuizRpgMinimapData z bieżącego poziomu (level_manager obok gracza);
## odkrywanie w promieniu reveal_radius z linią wzroku przy każdej zmianie kratki gracza. Maska odkrycia per mapa
## w zapisie gry (LevelStateManager: stan poziomu, klucz "fog"), zapisywana co FLUSH_INTERVAL i przy zmianie mapy.
## Widoczna tylko w eksploracji. Zoom: klawisze = / - (też + / - na klawiaturze numerycznej) albo kółko myszy nad mapą —
## w rogu zmienia skalę wycinka, na pełnej mapie przybliża wokół gracza.
## Znaczniki (MinimapMarkers na obu mapach) na odkrytych kratkach: nieotwarte skrzynie, NPC, niepokonani bossowie,
## przejścia nisz do sekretnych pokoi / krypty (przygaszone po odwiedzeniu) i niepodniesione przedmioty w niszach.
## Opcja „Minimapa” w zakładce Sterowanie (manifest control_options, klucz minimap): róg i pełna mapa / tylko pełna mapa
## pod M / wyłączona. Odkrywanie mgły działa w każdym trybie — po włączeniu mapa jest aktualna.

const ACTION := "minimap"
const FLUSH_INTERVAL := 1.0
const STATE_KEY := "fog"
const ZOOM_STEP := 1.25
const CORNER_ZOOM_RANGE := Vector2(1.0, 12.0)
const FULL_ZOOM_RANGE := Vector2(1.0, 8.0)
const MODULE_ID := "quiz_rpg"
const MODE_KEY := "minimap"
const MODE_CORNER := "corner"
const MODE_OFF := "off"
const MARKER_INTERVAL := 0.5

## Promień odkrywania w kratkach.
@export var reveal_radius := 12
## Pikseli ekranu na kratkę w rogu.
@export var corner_zoom := 4.0
@export var color_floor := Color(0.56, 0.5, 0.42)
@export var color_high := Color(0.7, 0.64, 0.52)
@export var color_wall := Color(0.12, 0.1, 0.09)
@export var color_cliff := Color(0.36, 0.3, 0.24)
@export var color_entrance := Color(0.35, 0.65, 1.0)
@export var color_exit := Color(1.0, 0.82, 0.25)
## Pustka za krawędzią mapy (koniec wnęki portalu, wypełnienie pustki).
@export var color_void := Color(0.02, 0.02, 0.03)
@export var color_chest := Color(0.95, 0.55, 0.15)
@export var color_npc := Color(0.35, 0.95, 0.45)
@export var color_boss := Color(0.8, 0.35, 1.0)
@export var color_passage := Color(0.3, 0.9, 0.95)
@export var color_passage_visited := Color(0.3, 0.5, 0.55)
@export var color_item := Color(1.0, 0.95, 0.6)

@onready var _corner: Control = $Corner
@onready var _corner_clip: Control = $Corner/Clip
@onready var _corner_map: TextureRect = $Corner/Clip/Map
@onready var _corner_dot: Control = $Corner/Clip/PlayerDot
@onready var _full: Control = $Full
@onready var _full_area: Control = $Full/Box/Area
@onready var _full_map: TextureRect = $Full/Box/Area/Map
@onready var _full_dot: Control = $Full/Box/Area/PlayerDot
@onready var _marker_layers: Array[Control] = [$Corner/Clip/Map/Markers, $Full/Box/Area/Map/Markers]

var data: QuizRpgMinimapData
var _image: Image
var _tex: ImageTexture
var _level: Node
var _level_key := ""
var _player: Node2D
var _last_cell := Vector2i(-99999, -99999)
var _tex_dirty := false
var _mask_dirty := false
var _flush_left := FLUSH_INTERVAL
var _full_zoom := 1.0   # przybliżenie pełnej mapy (1 = cała mapa w oknie)
var _mode := MODE_CORNER
## Znaczniki: [kratka, kolor] — czyta je MinimapMarkers.
var markers: Array = []
var _npcs: Array[Node2D] = []
var _marker_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.visible = false
	_corner.visible = false
	for tr: TextureRect in [_corner_map, _full_map]:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for ml in _marker_layers:
		ml.set("minimap", self)
	_load_mode()
	var settings := get_node_or_null("/root/SettingsService")
	if settings and settings.has_signal("module_setting_changed"):
		settings.module_setting_changed.connect(func(module_id: String, key: String, _value: Variant) -> void:
			if module_id == MODULE_ID and key == MODE_KEY:
				_load_mode())


func _load_mode() -> void:
	var settings := get_node_or_null("/root/SettingsService")
	_mode = str(settings.get_module(MODULE_ID, MODE_KEY, MODE_CORNER)) if settings != null else MODE_CORNER
	if _mode == MODE_OFF:
		_full.visible = false


func _exit_tree() -> void:
	_flush()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			_set_shown(false)
			return
	var lm := _player.get_parent().get_node_or_null("level_manager") if _player.get_parent() else null
	var lv: Variant = lm.get("current_level") if lm != null else null
	# w trakcie zmiany mapy stary poziom bywa już zwolniony albo w kolejce do zwolnienia
	var level: Node = lv if is_instance_valid(lv) and not (lv as Node).is_queued_for_deletion() else null
	if not is_instance_valid(_level) or level != _level:
		if data != null:
			_flush()
		_level = level
		data = null
	if data == null:
		if level == null or not is_instance_valid(level) or not level.is_inside_tree() or level.get("is_generating") == true:
			_set_shown(false)
			return
		_build(level, str(lm.get("current_level_path")))
		if data == null:
			_set_shown(false)
			return
	_set_shown(_exploring())
	var cell := QuizRpgMinimapData.cell_of(_level.to_local(_player.global_position))
	if cell != _last_cell:
		_last_cell = cell
		var newly := data.reveal(cell, reveal_radius)
		for p in newly:
			_paint(p)
		if not newly.is_empty():
			_tex_dirty = true
			_mask_dirty = true
	if _tex_dirty:
		_tex.update(_image)
		_tex_dirty = false
		_redraw_markers()
	_marker_left -= delta
	if _marker_left <= 0.0:
		_marker_left = MARKER_INTERVAL
		_collect_markers()
	_flush_left -= delta
	if _flush_left <= 0.0:
		_flush_left = FLUSH_INTERVAL
		_flush()
	_layout()


## Kółko myszy nad minimapą (róg albo pełna mapa) — przed innymi odbiorcami (kamera, listy), tylko gdy kursor nad mapą.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if data == null or mb == null or not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	var over_full := _full.visible and _mouse_over(_full_area)
	var over_corner := _corner.visible and not _full.visible and _mouse_over(_corner)
	if over_full or over_corner:
		_zoom(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()


func _mouse_over(c: Control) -> bool:
	return Rect2(Vector2.ZERO, c.size).has_point(c.get_local_mouse_position())


## Przybliżenie (+1) / oddalenie (-1) widocznej mapy: pełnej, gdy otwarta, inaczej rogu.
func _zoom(dir: int) -> void:
	var f := ZOOM_STEP if dir > 0 else 1.0 / ZOOM_STEP
	if _full.visible:
		_full_zoom = clampf(_full_zoom * f, FULL_ZOOM_RANGE.x, FULL_ZOOM_RANGE.y)
	else:
		corner_zoom = clampf(corner_zoom * f, CORNER_ZOOM_RANGE.x, CORNER_ZOOM_RANGE.y)
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if data == null or not InputMap.has_action(ACTION):
		return
	var key := event as InputEventKey
	if key != null and key.pressed and (_exploring() or _full.visible):
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			_zoom(1)
			get_viewport().set_input_as_handled()
			return
		if code in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_zoom(-1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(ACTION) and _mode != MODE_OFF and (_exploring() or _full.visible):
		_full.visible = not _full.visible
		get_viewport().set_input_as_handled()
	elif _full.visible and event.is_action_pressed("ui_cancel"):
		_full.visible = false
		get_viewport().set_input_as_handled()


func _exploring() -> bool:
	var gm := CoreManager.get_singleton("GameManager")
	return gm == null or int(gm.get("current_state")) == int(gm.GameState.EXPLORING)


func _set_shown(on: bool) -> void:
	_corner.visible = on and _mode == MODE_CORNER
	if not on:
		_full.visible = false


func _build(level: Node, level_key: String) -> void:
	data = QuizRpgMinimapData.from_level(level)
	_level_key = level_key
	_last_cell = Vector2i(-99999, -99999)
	if data == null:
		return
	var lsm := CoreManager.get_singleton("LevelStateManager")
	if lsm != null and _level_key != "":
		var saved: Variant = lsm.get_level_state(_level_key).get(STATE_KEY, "")
		if saved is String and saved != "":
			data.mask_from_string(saved)
	_image = Image.create(data.width, data.height, false, Image.FORMAT_RGBA8)
	_image.fill(color_void)  # cała mapa na starcie to pustka — odkrywanie ją nadpisuje (decyzja usera 2026-10-21)
	for i in data.revealed.size():
		if data.revealed[i] != 0:
			_image.set_pixel(i % data.width, i / data.width, _color_at(data.origin + Vector2i(i % data.width, i / data.width)))
	_tex = ImageTexture.create_from_image(_image)
	_corner_map.texture = _tex
	_full_map.texture = _tex
	_mask_dirty = false
	_npcs.clear()
	for n in level.find_children("*", "StaticBody2D", true, false):
		if n is QuizRpgNpc:
			_npcs.append(n)
	_collect_markers()


## Znaczniki z bieżącego poziomu: nieotwarte skrzynie, NPC, niepokonani bossowie, przejścia nisz, przedmioty na ziemi
## (kratki poza mapą pomijane).
func _collect_markers() -> void:
	var out: Array = []
	if data != null and is_instance_valid(_level):
		var lsm := CoreManager.get_singleton("LevelStateManager")
		for p in get_tree().get_nodes_in_group("secret_passages"):
			if _level.is_ancestor_of(p) and p.has_meta(&"target_level"):
				var visited: bool = lsm != null and (lsm.get("level_states") as Dictionary).has(str(p.get_meta(&"target_level")))
				_add_marker(out, p, color_passage_visited if visited else color_passage)
		for it in get_tree().get_nodes_in_group("ground_items"):
			if _level.is_ancestor_of(it) and not it.is_queued_for_deletion():
				_add_marker(out, it, color_item)
		for c in get_tree().get_nodes_in_group("chests"):
			if _level.is_ancestor_of(c) and not bool(c.get("opened")):
				_add_marker(out, c, color_chest)
		for n in _npcs:
			if is_instance_valid(n) and n.visible:
				_add_marker(out, n, color_npc)
		for e in get_tree().get_nodes_in_group("enemies"):
			if _level.is_ancestor_of(e) and bool(e.get("is_boss")) and not bool(e.get("defeated")) and (e as Node2D).visible:
				_add_marker(out, e, color_boss)
	if out != markers:
		markers = out
		_redraw_markers()


func _add_marker(out: Array, node: Node2D, color: Color) -> void:
	var p := QuizRpgMinimapData.cell_of(_level.to_local(node.global_position))
	if data.has_cell(p):
		out.append([p, color])


func _redraw_markers() -> void:
	for ml in _marker_layers:
		ml.queue_redraw()


func _paint(p: Vector2i) -> void:
	var q := p - data.origin
	_image.set_pixel(q.x, q.y, _color_at(p))


## Kolor kratki jak na mapie (QuizRpgMinimapData.color_at): podłoga z kafla najwyższej warstwy (trawa, ścieżki), ściana
## z kafla warstwy ścian (kafel pustki = pustka), ściana bez kafla = pustka; góra płaskowyżu nieco jaśniejsza; wejście
## i wyjście jako znaczniki.
func _color_at(p: Vector2i) -> Color:
	var kind := data.kind_at(p)
	var c := data.color_at(p)
	match kind:
		QuizRpgMinimapData.FLOOR:
			if c.a > 0.0:
				return c
		QuizRpgMinimapData.HIGH:
			if c.a > 0.0:
				return c.lightened(0.12)
		QuizRpgMinimapData.WALL, QuizRpgMinimapData.VOID:
			if data.has_colors:
				return c if c.a > 0.0 else color_void
	return _color(kind)


## Kolory rodzajów kratek bez koloru z kafli: podłoga i ściany ze średniej tekstur mapy, góra płaskowyżu i uskok pochodne
## podłogi; bez kolorów mapy — eksporty sceny.
func _color(kind: int) -> Color:
	var fl := data.floor_color if data != null and data.has_colors else color_floor
	match kind:
		QuizRpgMinimapData.FLOOR:
			return fl
		QuizRpgMinimapData.HIGH:
			return fl.lightened(0.22) if data != null and data.has_colors else color_high
		QuizRpgMinimapData.WALL:
			return color_wall
		QuizRpgMinimapData.CLIFF:
			return fl.darkened(0.35) if data != null and data.has_colors else color_cliff
		QuizRpgMinimapData.ENTRANCE:
			return color_entrance
		QuizRpgMinimapData.EXIT:
			return color_exit
		QuizRpgMinimapData.VOID:
			return color_void
	return Color(0, 0, 0, 0)


## Maska odkrycia do stanu poziomu (trafia do zapisu gry przy następnym zapisie).
func _flush() -> void:
	if not _mask_dirty or data == null or _level_key == "":
		return
	var lsm := CoreManager.get_singleton("LevelStateManager")
	if lsm != null:
		lsm.get_level_state(_level_key)[STATE_KEY] = data.mask_to_string()
	_mask_dirty = false


func _layout() -> void:
	if data == null:
		return
	var rel := Vector2(_last_cell - data.origin) + Vector2(0.5, 0.5)
	if _corner.visible:
		var z := corner_zoom
		_corner_map.size = Vector2(data.width, data.height) * z
		_corner_map.position = _corner_clip.size * 0.5 - rel * z
		_corner_dot.position = _corner_clip.size * 0.5 - _corner_dot.size * 0.5
	if _full.visible:
		var avail := _full_area.size
		var s := minf(avail.x / float(data.width), avail.y / float(data.height)) * _full_zoom
		var sz := Vector2(data.width, data.height) * s
		_full_map.size = sz
		# Bez przybliżenia mapa na środku; przybliżona — gracz na środku, ale bez wyjeżdżania mapy poza okno.
		var pos := (avail - sz) * 0.5
		if _full_zoom > 1.0:
			pos = avail * 0.5 - rel * s
			pos.x = clampf(pos.x, minf(avail.x - sz.x, 0.0), maxf(0.0, (avail.x - sz.x) * 0.5)) if sz.x > avail.x else (avail.x - sz.x) * 0.5
			pos.y = clampf(pos.y, minf(avail.y - sz.y, 0.0), maxf(0.0, (avail.y - sz.y) * 0.5)) if sz.y > avail.y else (avail.y - sz.y) * 0.5
		_full_map.position = pos
		_full_dot.position = _full_map.position + rel * s - _full_dot.size * 0.5
