extends Area2D

## Płyta naciskowa (paczka Sewer: Props (5,13) podniesiona = off, (5,14) wciśnięta = on). Lider wchodzi na płytę ->
## wciśnięta na stałe (zapis: brama otwarta), kolce bramy gate_id chowają się (GateState).

const GateStateScript = preload("gate_state.gd")

@export var gate_id: String = ""
@export var unique_id: String = ""

var pressed := false

@onready var _off: Sprite2D = $Off
@onready var _on: Sprite2D = $On


func _ready() -> void:
	# płaska płyta: punkt sortowania przy górnej krawędzi kratki (grafika i kształt +7 px w scenie) — postać na
	# płycie rysuje się nad nią
	position.y -= 7.0
	add_to_group("pressure_plates")
	body_entered.connect(_on_body_entered)
	_show(false)
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


func _show(on: bool) -> void:
	pressed = on
	_off.visible = not on
	_on.visible = on


func _on_body_entered(body: Node2D) -> void:
	if pressed or not GateStateScript.is_player(body):
		return
	_show(true)
	if not gate_id.is_empty():
		GateStateScript.open_gate(self, gate_id)
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_sfx_by_name"):
		audio.play_sfx_by_name("chest_open")
