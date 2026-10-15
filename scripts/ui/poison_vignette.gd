extends CanvasLayer

## Winieta zatrucia na cały ekran (wygląd w scenie `scenes/ui/poison_vignette.tscn`, fioletowy gradient od brzegów).
## Dopóki ktokolwiek z drużyny jest zatruty, a gra jest w eksploracji, delikatnie świeci (BASE_ALPHA); każdy ubytek HP
## od trucizny (PlayerStats.status_tick) daje mocniejszy błysk (PULSE_ALPHA), który gaśnie do poziomu bazowego.

const BASE_ALPHA := 0.25
const PULSE_ALPHA := 0.9
const PULSE_FADE := 0.9
const FOLLOW_SPEED := 4.0

var _ps: Node
var _gm: Node
var _pulse := 0.0
var _current := 0.0

@onready var _edge: Control = $Edge


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	_gm = CoreManager.get_singleton("GameManager")
	if _ps and _ps.has_signal("status_tick"):
		_ps.status_tick.connect(_on_status_tick)


func _on_status_tick(_member_index: int, status_id: String, _amount: int) -> void:
	if status_id == "poison" and _exploring():
		_pulse = 1.0


func _exploring() -> bool:
	return _gm != null and _gm.is_exploring()


func _process(delta: float) -> void:
	var poisoned: bool = _ps != null and _ps.any_status("poison") and _exploring()
	var base := BASE_ALPHA if poisoned else 0.0
	_pulse = maxf(_pulse - delta / PULSE_FADE, 0.0) if poisoned else 0.0
	var target := maxf(base, _pulse * PULSE_ALPHA)
	_current = move_toward(_current, target, delta * FOLLOW_SPEED * (3.0 if target > _current else 1.0))
	_edge.modulate.a = _current
