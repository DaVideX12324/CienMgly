extends CanvasLayer

## Ekran ładowania generowania mapy: pasek postępu + nazwa etapu.
## Czyta obiekt GenProgress (fraction/label) co klatkę — generator pisze do niego z wątku roboczego
## przez znaczniki GenProgress.begin(&"etap") / GenProgress.sub(0..1).

const FADE_TIME := 0.25

var _progress = null  # GenProgress
var _bar: ProgressBar
var _stage: Label
var _percent: Label
var _root: Control
var _shown := 0.0
var _closing := false


func _init(title: String = "Generowanie jaskini…") -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.045, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	box.add_child(title_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.58, 0.32)
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.16, 0.14, 0.12)
	back.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)

	var row := HBoxContainer.new()
	box.add_child(row)
	_stage = Label.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.modulate = Color(1, 1, 1, 0.75)
	row.add_child(_stage)
	_percent = Label.new()
	_percent.modulate = Color(1, 1, 1, 0.75)
	row.add_child(_percent)


## Podpina obiekt postępu (GenProgress) — od tej chwili pasek za nim podąża.
func track(progress) -> void:
	_progress = progress


func _process(delta: float) -> void:
	if _progress == null:
		return
	var target: float = _progress.fraction()
	# Płynnie za postępem, ale bez zostawania w tyle przy dużych skokach.
	_shown = minf(target, lerpf(_shown, target, clampf(delta * 12.0, 0.0, 1.0)) + delta * 0.05)
	_bar.value = _shown * 100.0
	_percent.text = "%d%%" % int(round(_shown * 100.0))
	var l: String = _progress.label()
	if l != "":
		_stage.text = l + "…"


## Pasek na 100% i zanik; węzeł usuwa się sam.
func close() -> void:
	if _closing:
		return
	_closing = true
	_shown = 1.0
	_bar.value = 100.0
	_percent.text = "100%"
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
