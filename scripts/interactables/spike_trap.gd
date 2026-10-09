extends StaticBody2D
class_name SpikeTrap

## Kolce w posadzce (paczka Sewer: otwory Props (4,14), kolumna kolca: grot (3,9), pręt (0,13), podstawa (1,13)).
## Obrażenia: lider (postać gracza) na kratce przy wysunięciu albo wejście na wysunięte kolce -> cała drużyna traci
## damage_fraction maks. HP (PlayerStats.damage_party_percent, bez zabijania), najwyżej raz na jedno wysunięcie.
## Tryby:
## - TIMER: kolce chowają się i wysuwają w rytmie down_time / up_time; faza z pozycji (grupa daje „falę”).
## - PROXIMITY: jednorazowo — lider w promieniu proximity_radius -> po rise_delay wysunięcie, po up_time schowanie
##   na stałe.
## - BARRIER: kolce wysunięte z kolizją (blokują przejście); open() chowa je (dźwignia / klucz), close() wysuwa.
##   Z gate_id (brama z generatora): w grupie "gate:<id>" — zamek bramy otwiera wszystkie jej kolce; brama otwarta
##   w zapisie (GateState) -> schowane od razu.

const GateStateScript = preload("gate_state.gd")

enum Mode { TIMER, PROXIMITY, BARRIER }

@export var mode: Mode = Mode.TIMER
@export_range(0.0, 1.0, 0.01) var damage_fraction := 0.1
@export var up_time := 0.8
@export var down_time := 1.6
@export var rise_delay := 0.25
@export var proximity_radius := 28.0
@export var gate_id: String = ""

var is_up := false
var _leader_inside := false
var _hurt_this_rise := false
var _used := false
var _clock := 0.0

@onready var _spike: Node2D = $Spike
@onready var _blocker: CollisionShape2D = $BlockShape


func _ready() -> void:
	add_to_group("spike_traps")
	_set_up(mode == Mode.BARRIER)
	$Trigger.body_entered.connect(_on_trigger_entered)
	$Trigger.body_exited.connect(_on_trigger_exited)
	if mode == Mode.PROXIMITY:
		var shape := CircleShape2D.new()
		shape.radius = proximity_radius
		$Proximity/Shape.shape = shape
		$Proximity.body_entered.connect(_on_proximity_entered)
	else:
		$Proximity.monitoring = false
	# faza czasomierza z pozycji — sąsiednie kolce wysuwają się kolejno
	var cycle := up_time + down_time
	_clock = fposmod(global_position.x * 0.013 + global_position.y * 0.007, 1.0) * cycle
	set_process(mode == Mode.TIMER)
	if not gate_id.is_empty():
		add_to_group("gate:" + gate_id)
		call_deferred("_check_gate")


func _check_gate() -> void:
	if GateStateScript.level_path(self).is_empty():
		await get_tree().process_frame
		if is_inside_tree():
			_check_gate()
		return
	if GateStateScript.is_gate_open(self, gate_id):
		open()


func open() -> void:
	_set_up(false)


func close() -> void:
	_set_up(true)


func _process(delta: float) -> void:
	_clock = fposmod(_clock + delta, up_time + down_time)
	var want_up := _clock >= down_time
	if want_up != is_up:
		_set_up(want_up)
		if want_up:
			_on_rise()


func _set_up(up: bool) -> void:
	is_up = up
	_spike.visible = up   # otwory w posadzce zostają; przy wysuniętych dolny rząd (BaseShadow) = cień podstawy
	if up:
		_hurt_this_rise = false
	# kolizja tylko w trybie BARRIER (pułapki ranią, nie zamykają drogi)
	_blocker.set_deferred("disabled", not (up and mode == Mode.BARRIER))


func _is_leader(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "Player"


func _on_trigger_entered(body: Node2D) -> void:
	if not _is_leader(body):
		return
	_leader_inside = true
	if is_up and mode != Mode.BARRIER:
		_hurt()


func _on_trigger_exited(body: Node2D) -> void:
	if _is_leader(body):
		_leader_inside = false


func _on_proximity_entered(body: Node2D) -> void:
	if _used or not _is_leader(body):
		return
	_used = true
	await get_tree().create_timer(rise_delay).timeout
	if not is_inside_tree():
		return
	_set_up(true)
	_on_rise()
	await get_tree().create_timer(up_time).timeout
	if is_inside_tree():
		_set_up(false)


func _on_rise() -> void:
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_sfx_by_name"):
		audio.play_sfx_by_name("spikes")
	if _leader_inside:
		_hurt()


func _hurt() -> void:
	if _hurt_this_rise:
		return
	_hurt_this_rise = true
	var ps := _get_module_singleton("PlayerStats")
	if ps and ps.has_method("damage_party_percent"):
		ps.damage_party_percent(damage_fraction)


func _get_module_singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var singleton: Variant = core_manager.call("get_singleton", singleton_name)
		if singleton is Node:
			return singleton
	return get_node_or_null("/root/%s" % singleton_name)
