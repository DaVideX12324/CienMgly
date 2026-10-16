extends CanvasLayer
class_name ModuleTransition

## Ekran przejścia między Artefaktem Wiedzy a modułem (wejście i wyjście): ciemne tło, nazwa modułu, pasek postępu.
## Wygląd w scenie `scenes/ui/module_transition.tscn`. Musi powstać PRZED ciężką pracą (wczytanie i start modułu) i
## zostać narysowany (`await painted()`), inaczej ścinka jest widoczna na starym ekranie. Postęp: `set_progress`
## (np. z wczytywania sceny wejściowej w tle); bez źródła pasek sam płynie powoli do 90 %. `fade_out()` zdejmuje ekran.

const SCENE := preload("res://_host/scenes/ui/module_transition.tscn")
const FADE_TIME := 0.25
const DOTS_STEP := 0.4

@onready var _root: Control = %Root
@onready var _title: Label = %Title
@onready var _stage: Label = %Stage
@onready var _bar: ProgressBar = %Bar

var _target := 0.0
var _shown := 0.0
var _stage_text := "Ładowanie"
var _title_text := ""
var _t := 0.0
var _closing := false


## Dodaje ekran na korzeń drzewa (przeżywa wymianę scen i wyłączenie modułu).
static func open(tree: SceneTree, title: String, stage: String = "Ładowanie") -> ModuleTransition:
	var overlay := SCENE.instantiate() as ModuleTransition
	overlay._stage_text = stage
	overlay._title_text = title
	tree.root.add_child(overlay)
	return overlay


func _ready() -> void:
	_title.text = _title_text
	_apply_stage()


## Czeka, aż ekran zostanie narysowany (pierwsze klatki z ekranem) — dopiero potem wolno blokować wątek.
## Bez renderowania (headless, testy) frame_post_draw nie przychodzi, więc wystarczą zwykłe klatki.
static func after_draw(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
		await tree.process_frame
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func painted() -> void:
	await ModuleTransition.after_draw(get_tree())


## Ponowne użycie już widocznego ekranu (np. wyjście zaraz po wejściu).
func reset(title: String, stage: String) -> void:
	_title_text = title
	_title.text = title
	_stage_text = stage
	_target = 0.0
	_shown = 0.0


func is_active() -> bool:
	return not _closing


func set_progress(fraction: float, stage: String = "") -> void:
	_target = clampf(fraction, 0.0, 1.0)
	if stage != "":
		_stage_text = stage


func _process(delta: float) -> void:
	_t += delta
	if _closing:
		return
	# Bez źródła postępu pasek i tak się rusza (powoli do 90 %), żeby ekran nie wyglądał na zawieszony.
	_target = maxf(_target, minf(_shown + delta * 0.08, 0.9))
	_shown = minf(_target, lerpf(_shown, _target, clampf(delta * 8.0, 0.0, 1.0)) + delta * 0.03)
	_bar.value = _shown * 100.0
	_apply_stage()


func _apply_stage() -> void:
	_stage.text = "%s%s" % [_stage_text, ".".repeat(1 + int(_t / DOTS_STEP) % 3)]


## Pasek na 100 % i zanik; węzeł usuwa się sam.
func fade_out() -> void:
	if _closing:
		return
	_closing = true
	_bar.value = 100.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
