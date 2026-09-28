extends CanvasLayer

## Ekran ładowania generowania mapy: pasek postępu + nazwa etapu. Scena:
## scenes/ui/generation_loading_overlay.tscn (wygląd edytuje się tam).
## Czyta obiekt GenProgress (fraction/label) co klatkę — generator pisze do niego z wątku roboczego
## przez znaczniki GenProgress.begin(&"etap") / GenProgress.sub(0..1).

const FADE_TIME := 0.25

## Nagłówek nad paskiem (procedural_level ustawia go wg typu poziomu przed dodaniem do drzewa).
@export var title: String = "Generowanie jaskini…":
	set(value):
		title = value
		if is_node_ready():
			_title.text = value

var _progress = null  # GenProgress
var _shown := 0.0
var _closing := false

@onready var _root: Control = %Root
@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _stage: Label = %Stage
@onready var _percent: Label = %Percent


func _ready() -> void:
	_title.text = title
	_bar.value = 0.0
	_percent.text = ""
	_stage.text = ""


## Podpina obiekt postępu (GenProgress) — od tej chwili pasek za nim podąża.
func track(progress) -> void:
	_progress = progress


func _process(delta: float) -> void:
	if _progress == null or _closing:
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
