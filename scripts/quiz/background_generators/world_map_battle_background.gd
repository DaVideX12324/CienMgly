extends RefCounted

const GRASS_A := Color(0.22, 0.45, 0.18)
const GRASS_B := Color(0.25, 0.50, 0.20)
const PATH := Color(0.55, 0.48, 0.35)
const WALL := Color(0.35, 0.32, 0.28)
const WALL_TOP := Color(0.45, 0.42, 0.38)
const TREE_TRUNK := Color(0.40, 0.28, 0.15)
const TREE_LEAVES := Color(0.15, 0.50, 0.15)
const TREE_LEAVES_2 := Color(0.20, 0.55, 0.20)


func draw_background(canvas: Control, context: Dictionary) -> void:
	var map := context.get("map", null) as Node
	var seed_basis := _position_seed(context.get("enemy", null))
	_draw_grass_field(canvas, seed_basis)
	_draw_path(canvas, map)
	_draw_map_decorations(canvas, map, seed_basis)
	_draw_low_wall(canvas)
	_draw_depth_shadow(canvas)


func _draw_grass_field(canvas: Control, seed_basis: int) -> void:
	var tile := 44.0
	for y in range(int(canvas.size.y / tile) + 2):
		for x in range(int(canvas.size.x / tile) + 2):
			var color := GRASS_A if (x + y + seed_basis) % 2 == 0 else GRASS_B
			canvas.draw_rect(Rect2(x * tile, y * tile, tile, tile), color)

	for i in range(90):
		var p := _deterministic_point(canvas.size, seed_basis + i * 11)
		var blade := 5.0 + float((seed_basis + i) % 5)
		canvas.draw_line(p, p + Vector2(0, -blade), Color(0.31, 0.58, 0.25, 0.55), 1.0)
		canvas.draw_line(p, p + Vector2(-blade * 0.25, -blade * 0.70), Color(0.20, 0.43, 0.18, 0.45), 1.0)


func _draw_path(canvas: Control, map: Node) -> void:
	var points: Array = []
	if map:
		points = map.get("_path_points")
	if points.size() >= 2:
		var transformed: Array[Vector2] = []
		for p in points:
			transformed.append(_map_to_screen(p, canvas.size))
		for i in range(transformed.size() - 1):
			canvas.draw_line(transformed[i], transformed[i + 1], Color(PATH, 0.45), 58.0)
			canvas.draw_line(transformed[i], transformed[i + 1], PATH, 42.0)
	else:
		var y := canvas.size.y * 0.68
		canvas.draw_line(Vector2(-30, y), Vector2(canvas.size.x + 30, y - 80), Color(PATH, 0.45), 70.0)
		canvas.draw_line(Vector2(-30, y), Vector2(canvas.size.x + 30, y - 80), PATH, 46.0)


func _draw_map_decorations(canvas: Control, map: Node, seed_basis: int) -> void:
	var trees: Array = map.get("_trees") if map else []
	var rocks: Array = map.get("_rocks") if map else []
	var flowers: Array = map.get("_flowers") if map else []

	for i in range(min(trees.size(), 16)):
		var pos := _map_to_screen(trees[(i + seed_basis) % trees.size()], canvas.size)
		if pos.y > canvas.size.y * 0.80:
			pos.y -= canvas.size.y * 0.28
		_draw_tree(canvas, pos, 0.82 + float(i % 3) * 0.08)

	for i in range(min(rocks.size(), 12)):
		var pos := _map_to_screen(rocks[(i + seed_basis) % rocks.size()], canvas.size)
		_draw_rock(canvas, pos)

	for i in range(min(flowers.size(), 20)):
		var fl: Dictionary = flowers[(i + seed_basis) % flowers.size()]
		var pos := _map_to_screen(fl.get("pos", Vector2.ZERO), canvas.size)
		var color: Color = fl.get("color", Color(0.9, 0.8, 0.2))
		canvas.draw_circle(pos, 3.0, color)
		canvas.draw_circle(pos, 1.1, Color(1.0, 1.0, 0.72))


func _draw_tree(canvas: Control, pos: Vector2, scale_value: float) -> void:
	_draw_ellipse(canvas, pos + Vector2(0, 22) * scale_value, Vector2(17, 6) * scale_value, Color(0, 0, 0, 0.24))
	canvas.draw_rect(Rect2(pos.x - 5 * scale_value, pos.y - 7 * scale_value, 10 * scale_value, 31 * scale_value), TREE_TRUNK)
	canvas.draw_circle(pos + Vector2(0, -24) * scale_value, 22 * scale_value, TREE_LEAVES)
	canvas.draw_circle(pos + Vector2(-13, -16) * scale_value, 16 * scale_value, TREE_LEAVES_2)
	canvas.draw_circle(pos + Vector2(13, -16) * scale_value, 16 * scale_value, TREE_LEAVES_2)
	canvas.draw_circle(pos + Vector2(0, -34) * scale_value, 14 * scale_value, TREE_LEAVES_2)


func _draw_rock(canvas: Control, pos: Vector2) -> void:
	canvas.draw_circle(pos + Vector2(0, 2), 8.0, Color(0, 0, 0, 0.18))
	canvas.draw_circle(pos, 8.0, Color(0.50, 0.50, 0.48))
	canvas.draw_arc(pos + Vector2(-2, -2), 5.0, PI * 0.8, PI * 1.5, 8, Color(0.63, 0.63, 0.60), 1.5)


func _draw_low_wall(canvas: Control) -> void:
	var y := canvas.size.y * 0.78
	canvas.draw_rect(Rect2(0, y, canvas.size.x, 30), WALL)
	canvas.draw_rect(Rect2(0, y, canvas.size.x, 10), WALL_TOP)
	for x in range(0, int(canvas.size.x), 36):
		canvas.draw_line(Vector2(x, y), Vector2(x, y + 30), Color(0, 0, 0, 0.12), 1.0)


func _draw_depth_shadow(canvas: Control) -> void:
	canvas.draw_rect(Rect2(0, 0, canvas.size.x, canvas.size.y * 0.22), Color(0, 0, 0, 0.18))
	canvas.draw_rect(Rect2(0, canvas.size.y * 0.76, canvas.size.x, canvas.size.y * 0.24), Color(0, 0, 0, 0.20))


func _map_to_screen(map_pos: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(
		remap(map_pos.x, -600.0, 600.0, viewport_size.x * 0.05, viewport_size.x * 0.95),
		remap(map_pos.y, -450.0, 450.0, viewport_size.y * 0.22, viewport_size.y * 0.86)
	)


func _position_seed(enemy: Variant) -> int:
	if enemy is Node2D:
		var p = enemy.global_position
		return abs(int(p.x * 7.0 + p.y * 13.0)) % 97
	return 0


func _deterministic_point(viewport_size: Vector2, seed: int) -> Vector2:
	var x := fposmod(float(seed * 73), maxf(viewport_size.x, 1.0))
	var y := fposmod(float(seed * 41), maxf(viewport_size.y, 1.0))
	return Vector2(x, y)


func _draw_ellipse(canvas: Control, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(18):
		var angle := (float(i) / 18.0) * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		colors.append(color)
	canvas.draw_polygon(points, colors)
