class_name QuizRpgTouchControls
extends CanvasLayer

## Sterowanie dotykowe na urządzeniach mobilnych (CanvasLayer 100).
## Lewy dolny róg: wirtualny joystick (move_up, move_down, move_left, move_right).
## Prawy dolny róg: przyciski TouchScreenButton (interact, ui_accept, ui_cancel, sprint).
## Sterowanie ukrywa się automatycznie poza stanem eksploracji (walka, quiz, dialog, pauza).

const DEADZONE := 0.2
const MAX_RADIUS := 70.0
const QuizRpgI18n = preload("../quiz_rpg_paths.gd")

@onready var _joystick_zone: Control = %JoystickZone
@onready var _joystick_base: Control = %JoystickBase
@onready var _joystick_stick: Control = %JoystickStick

var _touch_index := -1
var _stick_center := Vector2.ZERO
var _gm: Node = null


func _ready() -> void:
	if not is_touch_supported():
		queue_free()
		return

	if is_instance_valid(_joystick_stick):
		_stick_center = _joystick_stick.position

	_apply_i18n_labels()

	var cm := get_node_or_null("/root/CoreManager")
	_gm = cm.get_singleton("GameManager") if cm and cm.has_method("get_singleton") else null
	if _gm and _gm.has_signal("state_changed"):
		_gm.state_changed.connect(_on_game_state_changed)

	_update_visibility()


static func is_touch_supported() -> bool:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		return true
	if ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false):
		return true
	return false


func _apply_i18n_labels() -> void:
	var i18n := _get_i18n_service()
	if i18n == null:
		return
	if has_node("%BtnInteract/Label"):
		get_node("%BtnInteract/Label").text = i18n.call("t", "touch.interact", "E")
	if has_node("%BtnAccept/Label"):
		get_node("%BtnAccept/Label").text = i18n.call("t", "touch.accept", "A")
	if has_node("%BtnCancel/Label"):
		get_node("%BtnCancel/Label").text = i18n.call("t", "touch.cancel", "ESC")
	if has_node("%BtnSprint/Label"):
		get_node("%BtnSprint/Label").text = i18n.call("t", "touch.sprint", "RUN")


func _get_i18n_service() -> Node:
	return get_node_or_null("/root/I18nService")


func _on_game_state_changed(_old_state, _new_state) -> void:
	_update_visibility()


func _update_visibility() -> void:
	var should_show := true
	if _gm != null:
		should_show = _gm.is_exploring()
	visible = should_show
	if not should_show:
		_reset_joystick()


func _process(_delta: float) -> void:
	if _gm != null:
		var is_exp: bool = _gm.is_exploring()
		if visible != is_exp:
			visible = is_exp
			if not visible:
				_reset_joystick()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _is_inside_joystick(event.position):
				_touch_index = event.index
				_update_joystick(event.position)
				get_viewport().set_input_as_handled()
		else:
			if event.index == _touch_index:
				_reset_joystick()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()


func _is_inside_joystick(touch_pos: Vector2) -> bool:
	if not is_instance_valid(_joystick_zone):
		return false
	return _joystick_zone.get_global_rect().has_point(touch_pos)


func _update_joystick(touch_pos: Vector2) -> void:
	if not is_instance_valid(_joystick_base) or not is_instance_valid(_joystick_stick):
		return
	var base_center := _joystick_base.global_position + _joystick_base.size * 0.5
	var delta: Vector2 = touch_pos - base_center
	var dist: float = delta.length()
	var clamped_delta := delta
	if dist > MAX_RADIUS:
		clamped_delta = delta.normalized() * MAX_RADIUS

	_joystick_stick.position = _stick_center + clamped_delta

	var len_norm: float = minf(1.0, dist / MAX_RADIUS)
	if len_norm < DEADZONE:
		_release_movement_actions()
		return

	var scale_factor: float = (len_norm - DEADZONE) / (1.0 - DEADZONE)
	var dir: Vector2 = delta.normalized() * scale_factor

	_set_action("move_right", maxf(0.0, dir.x))
	_set_action("move_left", maxf(0.0, -dir.x))
	_set_action("move_down", maxf(0.0, dir.y))
	_set_action("move_up", maxf(0.0, -dir.y))


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release_movement_actions() -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("move_down")
	Input.action_release("move_up")


func _reset_joystick() -> void:
	_touch_index = -1
	if is_instance_valid(_joystick_stick):
		_joystick_stick.position = _stick_center
	_release_movement_actions()


func _exit_tree() -> void:
	_release_movement_actions()
