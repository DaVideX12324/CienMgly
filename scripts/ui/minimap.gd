extends Control

## Minimapa z fog of war (scena scenes/ui/minimap.tscn w HUD): w rogu wycinek mapy wokół gracza, pod klawiszem
## akcji `minimap` (domyślnie M) cała mapa. Dane: QuizRpgMinimapData z bieżącego poziomu (level_manager obok gracza);
## odkrywanie w promieniu reveal_radius z linią wzroku przy każdej zmianie kratki gracza. Maska odkrycia per mapa
## w zapisie gry (LevelStateManager: stan poziomu, klucz "fog"), zapisywana co FLUSH_INTERVAL i przy zmianie mapy.
## Widoczna tylko w eksploracji.

const ACTION := "minimap"
const FLUSH_INTERVAL := 1.0
const STATE_KEY := "fog"

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

@onready var _corner: Control = $Corner
@onready var _corner_clip: Control = $Corner/Clip
@onready var _corner_map: TextureRect = $Corner/Clip/Map
@onready var _corner_dot: Control = $Corner/Clip/PlayerDot
@onready var _full: Control = $Full
@onready var _full_area: Control = $Full/Box/Area
@onready var _full_map: TextureRect = $Full/Box/Area/Map
@onready var _full_dot: Control = $Full/Box/Area/PlayerDot

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.visible = false
	_corner.visible = false
	for tr: TextureRect in [_corner_map, _full_map]:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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
	_flush_left -= delta
	if _flush_left <= 0.0:
		_flush_left = FLUSH_INTERVAL
		_flush()
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if data == null or not InputMap.has_action(ACTION):
		return
	if event.is_action_pressed(ACTION) and (_exploring() or _full.visible):
		_full.visible = not _full.visible
		get_viewport().set_input_as_handled()
	elif _full.visible and event.is_action_pressed("ui_cancel"):
		_full.visible = false
		get_viewport().set_input_as_handled()


func _exploring() -> bool:
	var gm := CoreManager.get_singleton("GameManager")
	return gm == null or int(gm.get("current_state")) == int(gm.GameState.EXPLORING)


func _set_shown(on: bool) -> void:
	_corner.visible = on
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
	_image.fill(Color(0, 0, 0, 0))
	for i in data.revealed.size():
		if data.revealed[i] != 0:
			_image.set_pixel(i % data.width, i / data.width, _color(data.kinds[i]))
	_tex = ImageTexture.create_from_image(_image)
	_corner_map.texture = _tex
	_full_map.texture = _tex
	_mask_dirty = false


func _paint(p: Vector2i) -> void:
	var q := p - data.origin
	_image.set_pixel(q.x, q.y, _color(data.kind_at(p)))


## Kolory rodzajów kratek: podłoga i ściany ze średniej tekstur mapy (QuizRpgMinimapData), góra płaskowyżu i uskok
## pochodne podłogi; bez kolorów mapy — eksporty sceny.
func _color(kind: int) -> Color:
	var fl := data.floor_color if data != null and data.has_colors else color_floor
	match kind:
		QuizRpgMinimapData.FLOOR:
			return fl
		QuizRpgMinimapData.HIGH:
			return fl.lightened(0.22) if data != null and data.has_colors else color_high
		QuizRpgMinimapData.WALL:
			return data.wall_color if data != null and data.has_colors else color_wall
		QuizRpgMinimapData.CLIFF:
			return fl.darkened(0.35) if data != null and data.has_colors else color_cliff
		QuizRpgMinimapData.ENTRANCE:
			return color_entrance
		QuizRpgMinimapData.EXIT:
			return color_exit
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
		var s := minf(avail.x / float(data.width), avail.y / float(data.height))
		var sz := Vector2(data.width, data.height) * s
		_full_map.size = sz
		_full_map.position = (avail - sz) * 0.5
		_full_dot.position = _full_map.position + rel * s - _full_dot.size * 0.5
