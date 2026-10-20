extends Node2D

## Dźwignia bramy z kolców (Pixel Crawler free pack: Dungeon_Props, rączka w lewo = off, w prawo = on). Gracz przy
## dźwigni + klawisz interakcji -> rączka przechodzi przez pion na prawo, kolce bramy gate_id chowają się na stałe
## (zapis, GateState). Bez kolizji — jak płyta naciskowa stoi na kratce przełącznika (canals.levers).

const GateStateScript = preload("gate_state.gd")
const InteractPromptScript = preload("../ui/interact_prompt.gd")
const SWING_STEP := 0.08   # s na klatkę ruchu rączki

@export var gate_id: String = ""
@export var unique_id: String = ""

var pulled := false
var _in_range := false

@onready var _left: Sprite2D = $Left
@onready var _up: Sprite2D = $Up
@onready var _right: Sprite2D = $Right


func _ready() -> void:
	add_to_group("gate_levers")
	add_to_group("interactable")
	_show(_left)
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	call_deferred("_check_state")


func _check_state() -> void:
	if GateStateScript.level_path(self).is_empty():
		await get_tree().process_frame
		if is_inside_tree():
			_check_state()
		return
	if not gate_id.is_empty() and GateStateScript.is_gate_open(self, gate_id):
		pulled = true
		_show(_right)
		get_tree().call_group("gate:" + gate_id, "open")


func _show(frame: Sprite2D) -> void:
	for s in [_left, _up, _right]:
		s.visible = s == frame


func _unhandled_input(event: InputEvent) -> void:
	if pulled or not _in_range or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	pulled = true
	InteractPromptScript.release(self)
	_show(_up)
	var tw := create_tween()
	tw.tween_interval(SWING_STEP)
	tw.tween_callback(_show.bind(_right))
	GateStateScript.open_gate(self, gate_id)
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_sfx_by_name"):
		audio.play_sfx_by_name("chest_open")


func _on_body_entered(body: Node2D) -> void:
	if GateStateScript.is_player(body):
		_in_range = true
		if not pulled:
			InteractPromptScript.request(self, QuizRpgI18n.t("prompt.pull_lever", "Pociągnij dźwignię"))


func _on_body_exited(body: Node2D) -> void:
	if GateStateScript.is_player(body):
		_in_range = false
		InteractPromptScript.release(self)


## Podpowiedź nad dźwignią (InteractPrompt).
func interaction_prompt_offset() -> Vector2:
	return Vector2(0, -24)
