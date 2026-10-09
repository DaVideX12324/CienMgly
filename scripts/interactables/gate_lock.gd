extends Node2D

## Zamek na licu ściany przy bramie z kolców (paczka Sewer: Props (1,0–1) pusty, (0,0–1) z kluczem). Gracz
## przed zamkiem + klawisz interakcji: z kluczem (GateState) — klucz zostaje w zamku (grafika z kluczem),
## kolce bramy gate_id chowają się na stałe (zapis); bez klucza — podpowiedź „Brak klucza”.

const GateStateScript = preload("gate_state.gd")
const InteractPromptScript = preload("../ui/interact_prompt.gd")

@export var gate_id: String = ""
@export var unique_id: String = ""

var unlocked := false
var _in_range := false

@onready var _empty: Sprite2D = $Empty
@onready var _with_key: Sprite2D = $WithKey


func _ready() -> void:
	add_to_group("gate_locks")
	add_to_group("interactable")
	_show(false)
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
		_show(true)
		get_tree().call_group("gate:" + gate_id, "open")


func _show(with_key: bool) -> void:
	unlocked = with_key
	_empty.visible = not with_key
	_with_key.visible = with_key


func _unhandled_input(event: InputEvent) -> void:
	if unlocked or not _in_range or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	var audio := get_node_or_null("/root/AudioService")
	if GateStateScript.keys_available(self) <= 0:
		InteractPromptScript.request(self, "Brak klucza")
		return
	_show(true)
	InteractPromptScript.release(self)
	GateStateScript.open_gate(self, gate_id)
	if audio and audio.has_method("play_sfx_by_name"):
		audio.play_sfx_by_name("chest_open")


func _prompt_text() -> String:
	return "Wloz klucz" if GateStateScript.keys_available(self) > 0 else "Zamek (brak klucza)"


func _on_body_entered(body: Node2D) -> void:
	if GateStateScript.is_player(body):
		_in_range = true
		if not unlocked:
			InteractPromptScript.request(self, _prompt_text())


func _on_body_exited(body: Node2D) -> void:
	if GateStateScript.is_player(body):
		_in_range = false
		InteractPromptScript.release(self)


## Podpowiedź nad zamkiem (InteractPrompt).
func interaction_prompt_offset() -> Vector2:
	return Vector2(0, -26)
