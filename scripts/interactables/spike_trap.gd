extends StaticBody2D
class_name SpikeTrap

## Kolce w posadzce (paczka Sewer: otwory Props (4,14), kolumna kolca: grot (3,9), pręt (0,13), podstawa (1,13)).
## Tryb TRAP: lider (postać gracza) wchodzi na kratkę -> po rise_delay kolce się wysuwają; jeśli lider nadal na
## kratce, cała drużyna traci damage_fraction maks. HP (PlayerStats.damage_party_percent, bez zabijania); po up_time
## kolce się chowają, potem cooldown.
## Tryb BARRIER: kolce wysunięte z kolizją (blokują przejście); open() chowa je na stałe (dźwignia / klucz),
## close() wysuwa z powrotem.

enum Mode { TRAP, BARRIER }

@export var mode: Mode = Mode.TRAP
@export_range(0.0, 1.0, 0.01) var damage_fraction := 0.1
@export var rise_delay := 0.35
@export var up_time := 0.8
@export var cooldown := 0.6

var is_up := false
var _busy := false
var _leader_inside := false

@onready var _holes: Sprite2D = $Holes
@onready var _spike: Node2D = $Spike
@onready var _blocker: CollisionShape2D = $BlockShape


func _ready() -> void:
	add_to_group("spike_traps")
	_set_up(mode == Mode.BARRIER)
	$Trigger.body_entered.connect(_on_body_entered)
	$Trigger.body_exited.connect(_on_body_exited)


func open() -> void:
	_set_up(false)


func close() -> void:
	_set_up(true)


func _set_up(up: bool) -> void:
	is_up = up
	_spike.visible = up
	_holes.visible = not up
	# blokada tylko w trybie BARRIER (pułapka nie zamyka drogi — rani)
	_blocker.set_deferred("disabled", not (up and mode == Mode.BARRIER))


func _is_leader(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "Player"


func _on_body_entered(body: Node2D) -> void:
	if not _is_leader(body):
		return
	_leader_inside = true
	if mode == Mode.TRAP and not _busy and not is_up:
		_trigger()


func _on_body_exited(body: Node2D) -> void:
	if _is_leader(body):
		_leader_inside = false


func _trigger() -> void:
	_busy = true
	await get_tree().create_timer(rise_delay).timeout
	if not is_inside_tree():
		return
	_set_up(true)
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_sfx_by_name"):
		audio.play_sfx_by_name("spikes")
	if _leader_inside:
		var ps := _get_module_singleton("PlayerStats")
		if ps and ps.has_method("damage_party_percent"):
			ps.damage_party_percent(damage_fraction)
	await get_tree().create_timer(up_time).timeout
	if not is_inside_tree():
		return
	_set_up(false)
	await get_tree().create_timer(cooldown).timeout
	_busy = false
	if _leader_inside and is_inside_tree():
		_trigger()


func _get_module_singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var singleton: Variant = core_manager.call("get_singleton", singleton_name)
		if singleton is Node:
			return singleton
	return get_node_or_null("/root/%s" % singleton_name)
