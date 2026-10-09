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

## Dźwięk wysunięcia (metaliczny „szczęk”); przy schowaniu bramy ten sam, niżej. Pozycyjny i o krótkim zasięgu:
## kolce z czasomierzem cykają co ~2,4 s, z całej mapy naraz byłby szum.
const RISE_SFX := "res://assets/audio/sfx/RPG Sound Pack/battle/sword-unsheathe2.wav"
const SFX_RANGE := 240.0   # px (~15 kratek)
const SFX_DB := -6.0

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
var _sfx: AudioStreamPlayer2D

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
		_set_up(false)   # brama otwarta w zapisie — bez dźwięku przy wczytaniu


func open() -> void:
	if is_up:
		_play_sfx(0.75)
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
	_spike.visible = up   # otwory w posadzce zostają, rysowane pod kolcami
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
	_play_sfx(1.0)
	if _leader_inside:
		_hurt()


func _play_sfx(pitch: float) -> void:
	if _sfx == null:
		_sfx = AudioStreamPlayer2D.new()
		_sfx.bus = "SFX"
		_sfx.max_distance = SFX_RANGE
		_sfx.attenuation = 1.5
		_sfx.volume_db = SFX_DB
		if ResourceLoader.exists(RISE_SFX):
			_sfx.stream = load(RISE_SFX)
		add_child(_sfx)
	if _sfx.stream != null:
		_sfx.pitch_scale = pitch * randf_range(0.92, 1.08)
		_sfx.play()


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
