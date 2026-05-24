extends CharacterBody2D

## Gracz — ruch top-down 8-kierunkowy, interakcja.
## Programmer art: rysowany kodem jeśli brak AnimatedSprite2D/sprite frames.

@export var speed: float = 200.0
@export var is_party_follower: bool = false
@export var follow_spacing: float = 28.0
@export var follow_stop_distance: float = 6.0

var facing_direction: Vector2 = Vector2.DOWN
var can_move: bool = true
var nearby_interactables: Array = []
var _use_programmer_art: bool = true
var _gm: Node  # GameManager
var _follow_target: CharacterBody2D = null
var _trail_points: Array[Vector2] = []
var _body_color: Color = Color(0.2, 0.6, 1.0)
var _outline_color: Color = Color(0.1, 0.3, 0.6)
var _direction_color: Color = Color(1.0, 1.0, 0.3)

# Programmer art
const BODY_SIZE := Vector2(16, 20)
const TRAIL_RECORD_DISTANCE := 4.0
const MAX_TRAIL_POINTS := 96

# Bobbing animation
var _bob_time: float = 0.0
var _is_moving: bool = false


func _ready() -> void:
	_gm = CoreManager.get_singleton("GameManager")

	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite is AnimatedSprite2D and sprite.sprite_frames:
		if sprite.sprite_frames.get_animation_names().size() > 0:
			_use_programmer_art = false

	if _use_programmer_art:
		if sprite:
			sprite.visible = false
	_record_trail_position()
	if is_party_follower:
		_setup_as_follower()


func _physics_process(delta: float) -> void:
	if not can_move or not (_gm and _gm.is_exploring()):
		velocity = Vector2.ZERO
		_is_moving = false
		if not _use_programmer_art:
			_update_sprite_animation("idle")
		else:
			queue_redraw()
		return

	var input := Vector2.ZERO
	if is_party_follower and _follow_target != null:
		input = _get_follow_input()
	else:
		input = _get_input()
	velocity = input * speed

	if input != Vector2.ZERO:
		facing_direction = input.normalized()
		_is_moving = true
		_bob_time += delta * 10.0
		if not _use_programmer_art:
			_update_sprite_animation("walk")
	else:
		_is_moving = false
		_bob_time = 0.0
		if not _use_programmer_art:
			_update_sprite_animation("idle")

	if _use_programmer_art:
		queue_redraw()

	move_and_slide()
	_record_trail_position()


func _draw() -> void:
	if not _use_programmer_art:
		return

	var bob_offset = sin(_bob_time) * 2.0 if _is_moving else 0.0

	_draw_ellipse(Vector2(0, BODY_SIZE.y * 0.4), Vector2(BODY_SIZE.x * 0.5, 4), Color(0, 0, 0, 0.3))

	var body_rect = Rect2(-BODY_SIZE / 2 + Vector2(0, bob_offset - 8), BODY_SIZE)
	draw_rect(body_rect, _body_color)
	draw_rect(body_rect, _outline_color, false, 2.0)

	var head_center = Vector2(0, -BODY_SIZE.y * 0.5 + bob_offset - 12)
	draw_circle(head_center, 7.0, _body_color)
	draw_arc(head_center, 7.0, 0, TAU, 24, _outline_color, 2.0)

	var eye_offset = facing_direction.normalized() * 2.5
	var left_eye = head_center + Vector2(-2.5, -1) + eye_offset
	var right_eye = head_center + Vector2(2.5, -1) + eye_offset
	draw_circle(left_eye, 1.5, Color.WHITE)
	draw_circle(right_eye, 1.5, Color.WHITE)
	draw_circle(left_eye + eye_offset * 0.3, 0.8, Color(0.1, 0.1, 0.2))
	draw_circle(right_eye + eye_offset * 0.3, 0.8, Color(0.1, 0.1, 0.2))

	var dir_start = Vector2(0, bob_offset - 8) + facing_direction.normalized() * 14
	var dir_perp = Vector2(-facing_direction.y, facing_direction.x).normalized() * 4
	var triangle = PackedVector2Array([
		dir_start + facing_direction.normalized() * 6,
		dir_start + dir_perp,
		dir_start - dir_perp,
	])
	draw_colored_polygon(triangle, _direction_color)

	if _is_moving:
		var leg_swing = sin(_bob_time) * 4.0
		var hip = Vector2(0, BODY_SIZE.y * 0.3 + bob_offset - 8)
		draw_line(hip + Vector2(-3, 0), hip + Vector2(-3 + leg_swing, 8), _outline_color, 2.0)
		draw_line(hip + Vector2(3, 0), hip + Vector2(3 - leg_swing, 8), _outline_color, 2.0)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, segments: int = 16) -> void:
	var points = PackedVector2Array()
	for i in range(segments + 1):
		var angle = (float(i) / segments) * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	if points.size() > 2:
		draw_colored_polygon(points, color)


func _input(event: InputEvent) -> void:
	if is_party_follower:
		return
	if event.is_action_pressed("interact") and _gm and _gm.is_exploring():
		_try_interact()


func _get_input() -> Vector2:
	var input = Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	return input.normalized()


func _update_sprite_animation(state: String) -> void:
	var sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return
	var dir_name = _direction_name()
	var anim_name = state + "_" + dir_name
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	elif sprite.sprite_frames.has_animation(state):
		sprite.play(state)


func _direction_name() -> String:
	if abs(facing_direction.x) > abs(facing_direction.y):
		return "right" if facing_direction.x > 0 else "left"
	else:
		return "down" if facing_direction.y > 0 else "up"


func _try_interact() -> void:
	if nearby_interactables.is_empty():
		return
	var closest = nearby_interactables[0]
	if closest.has_method("interact"):
		closest.interact(self)


func set_can_move(value: bool) -> void:
	can_move = value
	if not value:
		velocity = Vector2.ZERO
		_is_moving = false


func apply_hero_data(hero_data: Dictionary) -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var custom_frames: SpriteFrames = hero_data.get("sprite_frames") as SpriteFrames
	if sprite and custom_frames:
		sprite.sprite_frames = custom_frames
		sprite.visible = true
		_use_programmer_art = false
	_body_color = hero_data.get("body_color", _body_color)
	queue_redraw()


func set_follow_target(target: CharacterBody2D, spacing: float = 28.0) -> void:
	_follow_target = target
	follow_spacing = spacing
	is_party_follower = true
	_setup_as_follower()


func get_trail_position(distance_back: float) -> Vector2:
	if _trail_points.is_empty():
		return global_position
	var remaining: float = maxf(distance_back, 0.0)
	for point_index: int in range(_trail_points.size() - 1, 0, -1):
		var current_point: Vector2 = _trail_points[point_index]
		var previous_point: Vector2 = _trail_points[point_index - 1]
		var segment_length: float = current_point.distance_to(previous_point)
		if segment_length >= remaining and segment_length > 0.0:
			var t: float = remaining / segment_length
			return current_point.lerp(previous_point, t)
		remaining -= segment_length
	return _trail_points[0]


func _setup_as_follower() -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.enabled = false
	var interaction_area := get_node_or_null("InteractionArea") as Area2D
	if interaction_area:
		interaction_area.monitoring = false
		interaction_area.monitorable = false


func _get_follow_input() -> Vector2:
	if _follow_target == null:
		return Vector2.ZERO
	var target_position: Vector2 = _follow_target.global_position
	if _follow_target.has_method("get_trail_position"):
		target_position = _follow_target.call("get_trail_position", follow_spacing)
	var delta: Vector2 = target_position - global_position
	if delta.length() <= follow_stop_distance:
		return Vector2.ZERO
	return delta.normalized()


func _record_trail_position() -> void:
	if _trail_points.is_empty() or _trail_points[_trail_points.size() - 1].distance_to(global_position) >= TRAIL_RECORD_DISTANCE:
		_trail_points.append(global_position)
		if _trail_points.size() > MAX_TRAIL_POINTS:
			_trail_points.pop_front()


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("interactable"):
		nearby_interactables.append(body)


func _on_interaction_area_body_exited(body: Node2D) -> void:
	nearby_interactables.erase(body)


func _on_interaction_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable"):
		nearby_interactables.append(area)


func _on_interaction_area_area_exited(area: Area2D) -> void:
	nearby_interactables.erase(area)
