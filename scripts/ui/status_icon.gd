extends PanelContainer
class_name QuizRpgStatusIcon

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

## Ikona statusu jak w RPG Makerze: zaokrąglony kwadrat w kolorze statusu (QuizRpgStatusData.color, przygaszony)
## z animowaną ikoną z paczki (pasek klatek 16×16, assets/UI/status_effects). Wygląd: scenes/ui/status_icon.tscn.

## Klatki na sekundę animacji ikony.
@export var fps := 10.0
## Przygaszenie koloru statusu na tle.
@export_range(0.0, 1.0, 0.05) var bg_darken := 0.45

@onready var _icon: TextureRect = $Icon
var _atlas: AtlasTexture
var _frames := 1
var _t := 0.0


func setup(status_id: String) -> void:
	if not is_node_ready():
		await ready
	var st := QuizRpgStatusCatalog.get_status(status_id)
	if st == null:
		return
	tooltip_text = st.localized_name()
	var box := (get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.bg_color = st.color.darkened(bg_darken)
	add_theme_stylebox_override(&"panel", box)
	if st.icon == null:
		_icon.texture = null
		set_process(false)
		return
	var h := st.icon.get_height()
	_frames = maxi(1, st.icon.get_width() / h)
	_atlas = AtlasTexture.new()
	_atlas.atlas = st.icon
	_atlas.region = Rect2(0, 0, h, h)
	_icon.texture = _atlas
	set_process(_frames > 1)


func _process(delta: float) -> void:
	_t += delta
	_atlas.region.position.x = float(int(_t * fps) % _frames) * _atlas.region.size.x


## Wypełnia kontener ikonami statusów (stare usuwa).
static func fill(box: Container, status_ids: Array) -> void:
	for c in box.get_children():
		c.queue_free()
	for sid in status_ids:
		var ic := (load(QuizRpgPaths.path("scenes/ui/status_icon.tscn")) as PackedScene).instantiate() as QuizRpgStatusIcon
		box.add_child(ic)
		ic.setup(String(sid))
