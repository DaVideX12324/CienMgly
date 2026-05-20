extends RefCounted

const SKY_TOP := Color(0.015, 0.012, 0.028)
const SKY_BOTTOM := Color(0.055, 0.045, 0.080)
const TABLE := Color(0.28, 0.27, 0.31)
const TABLE_EDGE := Color(0.12, 0.12, 0.15)
const CHAIR := Color(0.035, 0.035, 0.045)
const FLOOR_A := Color(0.10, 0.055, 0.070)
const FLOOR_B := Color(0.045, 0.040, 0.065)


func draw_background(canvas: Control, _context: Dictionary) -> void:
	_draw_sky(canvas)
	_draw_floor(canvas)
	_draw_party_table(canvas, Vector2(canvas.size.x * 0.18, canvas.size.y * 0.55), 1.05)
	_draw_party_table(canvas, Vector2(canvas.size.x * 0.62, canvas.size.y * 0.52), 1.00)
	_draw_party_table(canvas, Vector2(canvas.size.x * 0.42, canvas.size.y * 0.66), 0.92)
	_draw_vignette(canvas)


func _draw_sky(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), SKY_BOTTOM)
	for i in range(18):
		var t := float(i) / 17.0
		var color := SKY_TOP.lerp(SKY_BOTTOM, t)
		canvas.draw_rect(Rect2(0, canvas.size.y * t, canvas.size.x, canvas.size.y / 17.0 + 2.0), color)


func _draw_floor(canvas: Control) -> void:
	var floor_top := canvas.size.y * 0.60
	var tile_w := 68.0
	var tile_h := 34.0
	for y in range(8):
		for x in range(18):
			var px := float(x) * tile_w - 40.0
			var py := floor_top + float(y) * tile_h
			var color := FLOOR_A if (x + y) % 2 == 0 else FLOOR_B
			canvas.draw_polygon(PackedVector2Array([
				Vector2(px, py),
				Vector2(px + tile_w, py + 6.0),
				Vector2(px + tile_w, py + tile_h),
				Vector2(px, py + tile_h - 6.0),
			]), PackedColorArray([color, color, color, color]))


func _draw_party_table(canvas: Control, center: Vector2, scale_value: float) -> void:
	var table_size := Vector2(280, 82) * scale_value
	var table_rect := Rect2(center - table_size * 0.5, table_size)
	canvas.draw_rect(table_rect.grow(5.0 * scale_value), TABLE_EDGE)
	canvas.draw_rect(table_rect, TABLE)
	for i in range(9):
		var x := table_rect.position.x + 16.0 * scale_value + float(i) * 28.0 * scale_value
		var hat_base := Vector2(x, table_rect.position.y + 14.0 * scale_value)
		_draw_hat(canvas, hat_base, 0.34 * scale_value, Color(0.92, 0.92, 0.96))
	for side in [-1, 1]:
		for i in range(5):
			_draw_chair(canvas, Vector2(
				table_rect.position.x + 20.0 * scale_value + float(i) * 55.0 * scale_value,
				table_rect.position.y + table_size.y * 0.5 + float(side) * 54.0 * scale_value
			), scale_value)


func _draw_chair(canvas: Control, pos: Vector2, scale_value: float) -> void:
	var w := 22.0 * scale_value
	var h := 52.0 * scale_value
	canvas.draw_rect(Rect2(pos.x - w * 0.5, pos.y - h * 0.5, w, h), CHAIR)
	canvas.draw_rect(Rect2(pos.x - w * 0.35, pos.y - h * 0.42, w * 0.7, h * 0.18), Color(0.12, 0.12, 0.16))


func _draw_hat(canvas: Control, base: Vector2, scale_value: float, base_color: Color) -> void:
	var h := 70.0 * scale_value
	var w := 52.0 * scale_value
	var points := PackedVector2Array([
		base + Vector2(-w * 0.5, h * 0.5),
		base + Vector2(w * 0.5, h * 0.5),
		base + Vector2(0, -h * 0.5),
	])
	canvas.draw_polygon(points, PackedColorArray([base_color, base_color, base_color]))
	for i in range(4):
		var c = [
			Color(0.95, 0.10, 0.10),
			Color(0.25, 0.65, 1.00),
			Color(1.00, 0.86, 0.15),
			Color(0.70, 0.35, 0.95),
		][i]
		var y := base.y + h * (0.34 - float(i) * 0.17)
		canvas.draw_line(Vector2(base.x - w * 0.35, y), Vector2(base.x + w * 0.30, y - h * 0.10), c, 3.0 * scale_value)


func _draw_vignette(canvas: Control) -> void:
	var vignette := Color(0, 0, 0, 0.20)
	canvas.draw_rect(Rect2(0, 0, canvas.size.x, canvas.size.y * 0.18), vignette)
	canvas.draw_rect(Rect2(0, 0, canvas.size.x * 0.05, canvas.size.y), vignette)
	canvas.draw_rect(Rect2(canvas.size.x * 0.95, 0, canvas.size.x * 0.05, canvas.size.y), vignette)
