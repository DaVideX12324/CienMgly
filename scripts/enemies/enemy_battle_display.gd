extends Node2D
class_name EnemyBattleDisplay

## Lekka kopia wizualna przeciwnika do UI walki.
## Obsluguje AnimatedSprite2D z animacjami oraz fallback programmer art.

signal animation_action_finished(anim_name: String)

var body_color: Color = Color(0.9, 0.2, 0.2)
var shape_type: int = 0
var hp: int = 50
var max_hp: int = 50
var show_hp_bar: bool = false

var _use_programmer_art: bool = true
var _animated_sprite: AnimatedSprite2D = null
var _base_modulate: Color = Color.WHITE

var _idle_anim: String = ""
var _attack_anim: String = ""
var _hurt_anim: String = ""
var _death_anim: String = ""

var _anim_time: float = 0.0
var _flash_timer: float = 0.0
var _flash_color: Color = Color.WHITE
var _is_dying: bool = false
var _is_acting: bool = false

const OUTLINE_COLOR: Color = Color(0.15, 0.1, 0.1)
const EYE_COLOR: Color = Color(1.0, 0.9, 0.2)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup_from_source(source: Node2D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if source == null:
		return

	body_color = source.get("body_color") if "body_color" in source else Color(0.9, 0.2, 0.2)
	shape_type = int(source.get("shape_type")) if "shape_type" in source else 0
	hp = int(source.get("hp")) if "hp" in source else 50
	max_hp = int(source.get("max_hp")) if "max_hp" in source else 50

	var source_sprite: AnimatedSprite2D = source.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if source_sprite != null and source_sprite.sprite_frames != null and source_sprite.sprite_frames.get_animation_names().size() > 0:
		_setup_animated_sprite(source_sprite)
	else:
		_use_programmer_art = true
		if _animated_sprite != null:
			_animated_sprite.visible = false
		queue_redraw()


func _setup_animated_sprite(source_sprite: AnimatedSprite2D) -> void:
	_use_programmer_art = false

	if _animated_sprite == null:
		_animated_sprite = AnimatedSprite2D.new()
		_animated_sprite.name = "BattleAnimatedSprite2D"
		add_child(_animated_sprite)
		_animated_sprite.animation_finished.connect(_on_sprite_animation_finished)

	_animated_sprite.sprite_frames = source_sprite.sprite_frames
	_animated_sprite.centered = true
	_animated_sprite.position = Vector2.ZERO
	_base_modulate = source_sprite.modulate
	_animated_sprite.modulate = _base_modulate
	_animated_sprite.visible = true

	_resolve_animations(source_sprite.sprite_frames)
	play_idle()


func _resolve_animations(frames: SpriteFrames) -> void:
	var anims: PackedStringArray = frames.get_animation_names()
	if anims.is_empty():
		return

	# Idle animation selection
	_idle_anim = ""
	for candidate: String in ["idle_down", "slime_idle", "idle"]:
		if frames.has_animation(candidate):
			_idle_anim = candidate
			break
	if _idle_anim == "":
		for candidate: String in anims:
			if candidate.contains("idle"):
				_idle_anim = candidate
				break
	if _idle_anim == "":
		for candidate: String in ["walk_down", "slime_walk", "walk"]:
			if frames.has_animation(candidate):
				_idle_anim = candidate
				break
	if _idle_anim == "":
		_idle_anim = anims[0]

	# Attack animation selection
	_attack_anim = ""
	for candidate: String in ["attack_down", "attack"]:
		if frames.has_animation(candidate):
			_attack_anim = candidate
			break
	if _attack_anim == "":
		for candidate: String in anims:
			if candidate.contains("attack"):
				_attack_anim = candidate
				break

	# Hurt animation selection
	_hurt_anim = ""
	for candidate: String in ["hurt_down", "slime_hurt", "hurt"]:
		if frames.has_animation(candidate):
			_hurt_anim = candidate
			break
	if _hurt_anim == "":
		for candidate: String in anims:
			if candidate.contains("hurt"):
				_hurt_anim = candidate
				break

	# Death animation selection
	_death_anim = ""
	for candidate: String in ["death_down", "slime_death", "death"]:
		if frames.has_animation(candidate):
			_death_anim = candidate
			break
	if _death_anim == "":
		for candidate: String in anims:
			if candidate.contains("death"):
				_death_anim = candidate
				break


func play_idle() -> void:
	if _is_dying:
		return
	_is_acting = false
	if not _use_programmer_art and _animated_sprite != null and _idle_anim != "":
		if _animated_sprite.animation != _idle_anim or not _animated_sprite.is_playing():
			_animated_sprite.play(_idle_anim)


func play_attack() -> void:
	if _is_dying:
		return
	_is_acting = true

	# Dynamiczny mikroruch w strone gracza
	var start_y: float = position.y
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:y", start_y + 18.0, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", start_y, 0.18).set_ease(Tween.EASE_IN)

	if not _use_programmer_art and _animated_sprite != null and _attack_anim != "":
		_animated_sprite.play(_attack_anim)
	else:
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			if not _is_dying:
				play_idle()
				animation_action_finished.emit("attack")
		)


func play_hurt() -> void:
	flash_damage()
	if _is_dying:
		return
	if not _use_programmer_art and _animated_sprite != null and _hurt_anim != "":
		_is_acting = true
		_animated_sprite.play(_hurt_anim)


func play_death(on_complete: Callable = Callable()) -> void:
	_is_dying = true
	_is_acting = false

	if not _use_programmer_art and _animated_sprite != null and _death_anim != "":
		_animated_sprite.play(_death_anim)
		var death_tween: Tween = create_tween()
		death_tween.tween_interval(0.45)
		death_tween.tween_property(self, "modulate:a", 0.0, 0.35)
		death_tween.finished.connect(func() -> void:
			visible = false
			if on_complete.is_valid():
				on_complete.call()
		)
	else:
		var death_tween: Tween = create_tween()
		death_tween.tween_property(self, "modulate:a", 0.0, 0.4)
		death_tween.parallel().tween_property(self, "scale", scale * 0.5, 0.4)
		death_tween.finished.connect(func() -> void:
			visible = false
			if on_complete.is_valid():
				on_complete.call()
		)


func is_dying() -> bool:
	return _is_dying


func _on_sprite_animation_finished() -> void:
	if _is_dying:
		return
	var finished_anim: String = str(_animated_sprite.animation) if _animated_sprite != null else ""
	animation_action_finished.emit(finished_anim)
	play_idle()


func flash_damage() -> void:
	_flash_color = Color(1.0, 0.3, 0.3)
	_flash_timer = 0.25
	if not _use_programmer_art and _animated_sprite != null:
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(_animated_sprite, "modulate", Color(2.0, 0.4, 0.4, 1.0), 0.08)
		flash_tween.tween_property(_animated_sprite, "modulate", _base_modulate, 0.15)
	else:
		queue_redraw()


func sync_hp(new_hp: int) -> void:
	hp = new_hp


func _process(delta: float) -> void:
	if _use_programmer_art:
		_anim_time += delta
		if _flash_timer > 0.0:
			_flash_timer -= delta
		queue_redraw()


func _draw() -> void:
	if not _use_programmer_art:
		return

	var hover: float = sin(_anim_time * 2.0) * 2.0
	var draw_color: Color = body_color if _flash_timer <= 0.0 else _flash_color

	draw_circle(Vector2(0, 14), 8.0, Color(0, 0, 0, 0.25))

	match shape_type:
		0:
			_draw_diamond(Vector2(0, hover - 4.0), 12.0, 16.0, draw_color)
		1:
			draw_circle(Vector2(0, hover - 4.0), 14.0, draw_color)
			draw_arc(Vector2(0, hover - 4.0), 14.0, 0.0, TAU, 24, OUTLINE_COLOR, 2.0)
		2:
			_draw_triangle(Vector2(0, hover - 4.0), 16.0, draw_color)
		3:
			var rect: Rect2 = Rect2(-11.0, hover - 15.0, 22.0, 22.0)
			draw_rect(rect, draw_color)
			draw_rect(rect, OUTLINE_COLOR, false, 2.0)
		4:
			_draw_polygon_shape(Vector2(0, hover - 4.0), 14.0, 6, draw_color)

	var eye_y: float = hover - 7.0
	draw_circle(Vector2(-4, eye_y), 3.0, Color.WHITE)
	draw_circle(Vector2(4, eye_y), 3.0, Color.WHITE)
	draw_circle(Vector2(-4, eye_y), 1.5, EYE_COLOR)
	draw_circle(Vector2(4, eye_y), 1.5, EYE_COLOR)

	if show_hp_bar:
		var bar_y: float = hover - 22.0
		var bar_w: float = 24.0
		var bar_h: float = 3.0
		var hp_ratio: float = float(hp) / float(max(max_hp, 1))
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2))
		var hp_color: Color = Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w * hp_ratio, bar_h), hp_color)
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h), OUTLINE_COLOR, false, 1.0)


func _draw_diamond(center: Vector2, width: float, height: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -height),
		center + Vector2(width, 0),
		center + Vector2(0, height),
		center + Vector2(-width, 0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), OUTLINE_COLOR, 2.0)


func _draw_triangle(center: Vector2, size: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size, size * 0.7),
		center + Vector2(-size, size * 0.7),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), OUTLINE_COLOR, 2.0)


func _draw_polygon_shape(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(sides):
		var angle: float = (float(i) / float(sides)) * TAU - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, OUTLINE_COLOR, 2.0)
