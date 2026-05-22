extends Node2D
class_name EnemyBattleDisplay

## Lekka kopia wizualna przeciwnika do UI walki.
## Nie ma fizyki, AI ani kolizji - tylko _draw i animacja.

var body_color: Color = Color(0.9, 0.2, 0.2)
var shape_type: int = 0
var hp: int = 50
var max_hp: int = 50
var show_hp_bar: bool = false

var _anim_time: float = 0.0
var _flash_timer: float = 0.0
var _flash_color: Color = Color.WHITE

const OUTLINE_COLOR := Color(0.15, 0.1, 0.1)
const EYE_COLOR := Color(1.0, 0.9, 0.2)


func _process(delta: float) -> void:
	_anim_time += delta
	if _flash_timer > 0.0:
		_flash_timer -= delta
	queue_redraw()


func flash_damage() -> void:
	_flash_color = Color(1.0, 0.3, 0.3)
	_flash_timer = 0.25


func sync_hp(new_hp: int) -> void:
	hp = new_hp


func _draw() -> void:
	var hover := sin(_anim_time * 2.0) * 2.0
	var draw_color := body_color if _flash_timer <= 0.0 else _flash_color

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
			var rect := Rect2(-11.0, hover - 15.0, 22.0, 22.0)
			draw_rect(rect, draw_color)
			draw_rect(rect, OUTLINE_COLOR, false, 2.0)
		4:
			_draw_polygon_shape(Vector2(0, hover - 4.0), 14.0, 6, draw_color)

	var eye_y := hover - 7.0
	draw_circle(Vector2(-4, eye_y), 3.0, Color.WHITE)
	draw_circle(Vector2(4, eye_y), 3.0, Color.WHITE)
	draw_circle(Vector2(-4, eye_y), 1.5, EYE_COLOR)
	draw_circle(Vector2(4, eye_y), 1.5, EYE_COLOR)

	if show_hp_bar:
		var bar_y := hover - 22.0
		var bar_w := 24.0
		var bar_h := 3.0
		var hp_ratio := float(hp) / float(max(max_hp, 1))
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2))
		var hp_color := Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w * hp_ratio, bar_h), hp_color)
		draw_rect(Rect2(-bar_w / 2.0, bar_y, bar_w, bar_h), OUTLINE_COLOR, false, 1.0)


func _draw_diamond(center: Vector2, width: float, height: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -height),
		center + Vector2(width, 0),
		center + Vector2(0, height),
		center + Vector2(-width, 0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), OUTLINE_COLOR, 2.0)


func _draw_triangle(center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size, size * 0.7),
		center + Vector2(-size, size * 0.7),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), OUTLINE_COLOR, 2.0)


func _draw_polygon_shape(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := (float(i) / sides) * TAU - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, OUTLINE_COLOR, 2.0)
