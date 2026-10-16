class_name QuizTrashIcon
extends Control
## Ikona kosza rysowana kodem (bez zależności od glifów czcionki). Kolor w `color`.

var color := Color(0.78, 0.78, 0.86, 1)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var w := maxf(1.5, s / 11.0)
	# pokrywa z uchwytem
	draw_line(o + Vector2(s * 0.15, s * 0.25), o + Vector2(s * 0.85, s * 0.25), color, w)
	draw_rect(Rect2(o + Vector2(s * 0.38, s * 0.1), Vector2(s * 0.24, s * 0.15)), color, false, w)
	# korpus
	var body := PackedVector2Array([
		o + Vector2(s * 0.22, s * 0.25), o + Vector2(s * 0.28, s * 0.9),
		o + Vector2(s * 0.72, s * 0.9), o + Vector2(s * 0.78, s * 0.25)])
	draw_polyline(body, color, w)
	for x in [0.4, 0.5, 0.6]:
		draw_line(o + Vector2(s * x, s * 0.4), o + Vector2(s * x, s * 0.75), color, w * 0.8)
