extends CharacterBody2D
class_name EnemyBase

## Bazowa klasa przeciwnika — patroluje, wykrywa gracza, inicjuje walke quizowa.
## Programmer art: rysowany kodem jesli brak sprite frames.

const QuizRpgEnemyData = preload("res://modules/quiz_rpg/scripts/enemies/enemy_data.gd")

@export var enemy_data: QuizRpgEnemyData
@export_group("Identity")
@export var enemy_name: String = "Przeciwnik"
@export var quiz_id: String = "inf_podst"
@export var quiz_category: String = "ogolne"
@export_group("Combat")
@export var question_count: int = 3
@export var hp: int = 50
@export var max_hp: int = 50
@export var damage_on_wrong: int = 15
@export var xp_reward: int = 50
@export_range(1, 5, 1) var encounter_tier: int = 2
@export var min_encounter_size: int = 1
@export var max_encounter_size: int = 3
@export var is_boss: bool = false
@export_group("Movement")
@export var patrol_speed: float = 80.0
@export var detection_radius: float = 150.0
@export_group("AI Behavior")
@export var wander_radius: float = 100.0
@export var memory_duration: float = 3.0
@export_group("Visual")
@export var body_color: Color = Color(0.9, 0.2, 0.2)

enum State { IDLE, PATROL, CHASING, COMBAT, DEFEATED }
var state: State = State.PATROL

var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var patrol_stuck_timer: float = 0.0

var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var is_idle_pause: bool = false
var memory_timer: float = 0.0
var last_seen_player_pos: Vector2 = Vector2.ZERO

var player_ref: Node2D = null
var defeated: bool = false
var _use_programmer_art: bool = true
var _anim_time: float = 0.0
var _flash_timer: float = 0.0
var _flash_color: Color = Color.WHITE
var _uses_directional_animations: bool = false
var _last_facing_dir: String = "down"

enum EnemyShape { DIAMOND, CIRCLE, TRIANGLE, SQUARE, HEXAGON }
@export var shape_type: EnemyShape = EnemyShape.DIAMOND

const OUTLINE_COLOR := Color(0.15, 0.1, 0.1)
const EYE_COLOR    := Color(1.0, 0.9, 0.2)

# Singletony
var _ps: Node   # PlayerStats
var _dm: Node   # DifficultyManager
var _gm: Node   # GameManager

@onready var _raycast: RayCast2D = get_node_or_null("RayCast2D")
@onready var _nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")


func _ready() -> void:
	_apply_enemy_data()
	_ps = CoreManager.get_singleton("PlayerStats")
	_dm = CoreManager.get_singleton("DifficultyManager")
	_gm = CoreManager.get_singleton("GameManager")

	add_to_group("enemies")
	add_to_group("interactable")

	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite is AnimatedSprite2D and sprite.sprite_frames:
		if sprite.sprite_frames.get_animation_names().size() > 0:
			_use_programmer_art = false
		if sprite.sprite_frames.has_animation("walk_down") or sprite.sprite_frames.has_animation("idle_down"):
			_uses_directional_animations = true

	if _use_programmer_art:
		if sprite:
			sprite.visible = false

	if _raycast:
		_raycast.enabled = true

	_setup_detection_area()

	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and cheat_service.has_signal("enemies_toggled"):
		cheat_service.enemies_toggled.connect(_on_enemies_toggled)

	wander_target = global_position
	_set_new_wander_target()


func _are_enemies_disabled() -> bool:
	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and "enemies_disabled" in cheat_service:
		return bool(cheat_service.enemies_disabled)
	return false


func _on_enemies_toggled(disabled: bool) -> void:
	if disabled:
		if state == State.CHASING:
			state = State.PATROL
		velocity = Vector2.ZERO
		player_ref = null
		if _use_programmer_art:
			queue_redraw()


func _apply_enemy_data() -> void:
	if enemy_data == null:
		hp = maxi(hp, 1)
		max_hp = maxi(max_hp, 1)
		hp = mini(hp, max_hp)
		encounter_tier = clampi(encounter_tier, 1, 5)
		return
	enemy_name = enemy_data.enemy_name
	quiz_id = enemy_data.quiz_id
	quiz_category = enemy_data.quiz_category
	question_count = enemy_data.question_count
	max_hp = maxi(enemy_data.max_hp, 1)
	hp = max_hp
	damage_on_wrong = maxi(enemy_data.damage_on_wrong, 0)
	xp_reward = maxi(enemy_data.xp_reward, 0)
	encounter_tier = clampi(enemy_data.encounter_tier, 1, 5)
	min_encounter_size = maxi(enemy_data.min_encounter_size, 1)
	max_encounter_size = maxi(enemy_data.max_encounter_size, min_encounter_size)
	is_boss = enemy_data.is_boss
	patrol_speed = enemy_data.patrol_speed
	detection_radius = enemy_data.detection_radius
	body_color = enemy_data.body_color
	shape_type = enemy_data.shape_type


func _physics_process(delta: float) -> void:
	_anim_time += delta
	if _flash_timer > 0:
		_flash_timer -= delta

	if defeated or state == State.COMBAT:
		if _use_programmer_art:
			queue_redraw()
		return

	if _are_enemies_disabled():
		if state == State.CHASING:
			state = State.PATROL
		velocity = Vector2.ZERO
		if _use_programmer_art:
			queue_redraw()
		return

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASING:
			_chase(delta)
		State.IDLE:
			pass

	if not _use_programmer_art:
		_update_sprite_animation()

	if _use_programmer_art:
		queue_redraw()


func _update_sprite_animation() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return

	var moving := velocity.length() > 5.0

	if _uses_directional_animations:
		if moving:
			_last_facing_dir = _direction_name_from_velocity(velocity)
		var anim_name := ("walk_" if moving else "idle_") + _last_facing_dir
		if not sprite.sprite_frames.has_animation(anim_name):
			anim_name = "idle_" + _last_facing_dir
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
	else:
		var anim_name := "walk" if moving else "idle"
		if not sprite.sprite_frames.has_animation(anim_name):
			return
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
		sprite.flip_h = velocity.x < 0.0


func _direction_name_from_velocity(vel: Vector2) -> String:
	if abs(vel.x) > abs(vel.y):
		return "right" if vel.x > 0.0 else "left"
	return "down" if vel.y > 0.0 else "up"


func _has_line_of_sight_to_player() -> bool:
	if _raycast == null or not is_instance_valid(player_ref):
		return true

	# Bardzo blisko / w srodku wroga -- raycast moze byc niestabilny przy
	# zerowej dlugosci, wiec traktujemy to jako widoczne bez sprawdzania.
	var distance := global_position.distance_to(player_ref.global_position)
	if distance < 50.0:
		return true

	var to_player := player_ref.global_position - _raycast.global_position
	_raycast.target_position = _raycast.to_local(_raycast.global_position + to_player.limit_length(300.0))
	_raycast.force_raycast_update()
	var collider := _raycast.get_collider()

	# Brak collidera = raycast nie trafil w nic blokujace -- droga jest czysta.
	if collider == null:
		return true
	if collider == player_ref:
		return true
	if collider is Node and (collider as Node).is_in_group("player"):
		return true
	return false


func _draw() -> void:
	if not _use_programmer_art:
		return

	var hover = sin(_anim_time * 2.0) * 2.0
	var draw_color = body_color
	if _flash_timer > 0:
		draw_color = _flash_color

	draw_circle(Vector2(0, 14), 8.0, Color(0, 0, 0, 0.25))

	match shape_type:
		EnemyShape.DIAMOND:
			_draw_diamond(Vector2(0, hover - 4), 12, 16, draw_color)
		EnemyShape.CIRCLE:
			draw_circle(Vector2(0, hover - 4), 14.0, draw_color)
			draw_arc(Vector2(0, hover - 4), 14.0, 0, TAU, 24, OUTLINE_COLOR, 2.0)
		EnemyShape.TRIANGLE:
			_draw_triangle(Vector2(0, hover - 4), 16, draw_color)
		EnemyShape.SQUARE:
			var r = Rect2(-11, hover - 15, 22, 22)
			draw_rect(r, draw_color)
			draw_rect(r, OUTLINE_COLOR, false, 2.0)
		EnemyShape.HEXAGON:
			_draw_polygon_shape(Vector2(0, hover - 4), 14, 6, draw_color)

	var eye_y = hover - 7.0
	var look_dir = Vector2.ZERO
	if is_instance_valid(player_ref) and state == State.CHASING:
		look_dir = (player_ref.global_position - global_position).normalized() * 2.0

	draw_circle(Vector2(-4 + look_dir.x, eye_y + look_dir.y), 3.0, Color.WHITE)
	draw_circle(Vector2(4 + look_dir.x, eye_y + look_dir.y), 3.0, Color.WHITE)
	draw_circle(Vector2(-4 + look_dir.x * 1.3, eye_y + look_dir.y * 1.3), 1.5, EYE_COLOR)
	draw_circle(Vector2(4 + look_dir.x * 1.3, eye_y + look_dir.y * 1.3), 1.5, EYE_COLOR)

	if not defeated:
		var bar_y = hover - 22
		var bar_w = 24.0
		var bar_h = 3.0
		var hp_ratio := float(hp) / float(max_hp)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2))
		var hp_color := Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * hp_ratio, bar_h), hp_color)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), OUTLINE_COLOR, false, 1.0)

	if state == State.CHASING:
		var ex_y = hover - 28
		draw_string(ThemeDB.fallback_font, Vector2(-3, ex_y), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.RED)


func _draw_diamond(center: Vector2, w: float, h: float, color: Color) -> void:
	var pts = PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, 0),
		center + Vector2(0, h),
		center + Vector2(-w, 0),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), OUTLINE_COLOR, 2.0)


func _draw_triangle(center: Vector2, size: float, color: Color) -> void:
	var pts = PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size, size * 0.7),
		center + Vector2(-size, size * 0.7),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), OUTLINE_COLOR, 2.0)


func _draw_polygon_shape(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(sides):
		var angle = (float(i) / sides) * TAU - PI / 2.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, OUTLINE_COLOR, 2.0)


func _patrol(delta: float) -> void:
	if is_instance_valid(player_ref) and not defeated and _has_line_of_sight_to_player():
		state = State.CHASING
		last_seen_player_pos = player_ref.global_position
		memory_timer = memory_duration
		return

	if not patrol_points.is_empty():
		_follow_patrol_path(delta)
	else:
		_idle_wander(delta)


func _idle_wander(delta: float) -> void:
	wander_timer -= delta
	if is_idle_pause:
		velocity = Vector2.ZERO
		if wander_timer <= 0.0:
			_set_new_wander_target()
		return

	var to_target = wander_target - global_position
	if wander_timer <= 0.0 or to_target.length() < 12.0:
		_set_new_wander_target()
		return

	velocity = to_target.normalized() * (patrol_speed * 0.5)
	move_and_slide()

	if is_on_wall():
		_set_new_wander_target(get_wall_normal())


func _set_new_wander_target(bias_normal: Vector2 = Vector2.ZERO) -> void:
	if randf() < 0.25 and bias_normal == Vector2.ZERO:
		is_idle_pause = true
		wander_timer = randf_range(1.0, 2.5)
		velocity = Vector2.ZERO
		return

	is_idle_pause = false
	wander_timer = randf_range(2.0, 4.0)

	var random_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	if bias_normal != Vector2.ZERO:
		random_dir = (random_dir + bias_normal * 1.8).normalized()

	wander_target = global_position + random_dir * randf_range(30.0, wander_radius)


func _follow_patrol_path(delta: float) -> void:
	var target = patrol_points[current_patrol_index]
	var direction = (target - global_position).normalized()
	velocity = direction * patrol_speed
	move_and_slide()

	if is_on_wall():
		patrol_stuck_timer += delta
		if patrol_stuck_timer > 1.5:
			patrol_stuck_timer = 0.0
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	else:
		patrol_stuck_timer = 0.0

	if global_position.distance_to(target) < 12.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()


func _chase(delta: float) -> void:
	if not defeated and is_instance_valid(player_ref) and _has_line_of_sight_to_player():
		last_seen_player_pos = player_ref.global_position
		memory_timer = memory_duration
	else:
		memory_timer -= delta
		if memory_timer <= 0.0:
			state = State.PATROL
			velocity = Vector2.ZERO
			_set_new_wander_target()
			return

	var move_target := last_seen_player_pos
	if _nav_agent != null:
		_nav_agent.target_position = last_seen_player_pos
		if not _nav_agent.is_navigation_finished():
			var next_pos := _nav_agent.get_next_path_position()
			if next_pos != Vector2.ZERO:
				move_target = next_pos

	var direction := (move_target - global_position).normalized()
	velocity = direction * patrol_speed * 1.3
	move_and_slide()

	if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) < 40.0:
		start_combat(player_ref)


func _setup_detection_area() -> void:
	var det_area = get_node_or_null("DetectionArea")
	if det_area:
		det_area.monitoring = true
		det_area.monitorable = true
		det_area.collision_mask = 1
		if not det_area.body_entered.is_connected(_on_detection_area_body_entered):
			det_area.body_entered.connect(_on_detection_area_body_entered)
		if not det_area.body_exited.is_connected(_on_detection_area_body_exited):
			det_area.body_exited.connect(_on_detection_area_body_exited)
		if det_area.get_child_count() == 0:
			var shape = CircleShape2D.new()
			shape.radius = detection_radius
			var col = CollisionShape2D.new()
			col.shape = shape
			det_area.add_child(col)
		else:
			var col = det_area.get_child(0)
			if col is CollisionShape2D and col.shape is CircleShape2D:
				col.shape.radius = detection_radius


func _on_detection_area_body_entered(body: Node2D) -> void:
	if _are_enemies_disabled():
		return
	if body.is_in_group("player") and not defeated:
		player_ref = body
		if _has_line_of_sight_to_player():
			state = State.CHASING
			last_seen_player_pos = body.global_position
			memory_timer = memory_duration


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null


func interact(player: Node2D) -> void:
	if _are_enemies_disabled():
		return
	if not defeated:
		start_combat(player)


func start_combat(player: Node2D) -> void:
	if _are_enemies_disabled():
		return
	if state == State.COMBAT or defeated:
		return
	if _gm and _gm.is_in_quiz():
		return
	if get_tree().paused:
		return

	state = State.COMBAT
	velocity = Vector2.ZERO

	if player.has_method("set_can_move"):
		player.set_can_move(false)

	if _gm:
		_gm.change_state(_gm.GameState.QUIZ_COMBAT)

	var diff_range: Vector2i = Vector2i(1, 3)
	if _dm:
		diff_range = _dm.get_difficulty_range(quiz_category)
	var encounter_size_range: Vector2i = Vector2i(maxi(1, min_encounter_size), maxi(maxi(1, min_encounter_size), max_encounter_size))

	var combat_canvas: CanvasLayer = preload("res://modules/quiz_rpg/scenes/quiz/quiz_combat_ui.tscn").instantiate() as CanvasLayer
	var combat_ui: Control = combat_canvas.get_node("Root") as Control
	combat_ui.setup(self, player, quiz_id, diff_range, question_count, encounter_size_range)
	get_tree().current_scene.add_child(combat_canvas)
	get_tree().paused = true


func on_combat_finished(player_won: bool, player: Node2D) -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false
	if player.has_method("set_can_move"):
		player.set_can_move(true)

	if player_won:
		defeated = true
		state = State.DEFEATED
		if _ps:
			_ps.add_xp(xp_reward)
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.4).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
		await tween.finished
		queue_free()
	else:
		state = State.IDLE
		await get_tree().create_timer(2.0).timeout
		state = State.PATROL

	if _gm:
		_gm.change_state(_gm.GameState.EXPLORING)


func take_quiz_damage(amount: int) -> void:
	hp -= amount
	hp = maxi(hp, 0)
	_flash_color = Color(1.0, 0.3, 0.3)
	_flash_timer = 0.15
	if _use_programmer_art:
		queue_redraw()
	else:
		var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			var tween: Tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.RED, 0.1)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func is_defeated() -> bool:
	return hp <= 0
