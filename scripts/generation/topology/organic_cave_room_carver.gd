class_name OrganicCaveRoomCarver
extends "res://modules/quiz_rpg/scripts/generation/topology/room_carver.gd"

const MapGeneratorBase = preload("res://modules/quiz_rpg/scripts/generation/map_generator_base.gd")

func carve(ctx: GenerationContext, rect: Rect2i) -> void:
	var grid := ctx.grid
	var rng := ctx.rng
	var map_w := ctx.width
	var map_h := ctx.height

	var center := rect.get_center()
	var rx_rad := rect.size.x / 2.0
	var ry_rad := rect.size.y / 2.0

	# 1. Główny rdzeń eliptyczny
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var dx := (x - center.x) / rx_rad
			var dy := (y - center.y) / ry_rad
			if dx * dx + dy * dy <= 1.0:
				grid[Vector2i(x, y)] = CellType.FLOOR

	# 2. Dodatkowe organiczne wybrzuszenia (lobes)
	var num_lobes := rng.randi_range(3, 5)
	for i in range(num_lobes):
		var angle := rng.randf_range(0.0, TAU)
		var dist_x := rng.randf_range(0.2, 0.6) * rx_rad
		var dist_y := rng.randf_range(0.2, 0.6) * ry_rad
		var lobe_center := center + Vector2i(int(cos(angle) * dist_x), int(sin(angle) * dist_y))
		var lobe_radius := rng.randi_range(2, int(min(rx_rad, ry_rad) * 0.6))
		MapGeneratorBase.carve_circle(grid, lobe_center, lobe_radius, CellType.FLOOR, map_w, map_h)

