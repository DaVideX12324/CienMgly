class_name RoundRoomCarver
extends "res://modules/quiz_rpg/scripts/generation/topology/room_carver.gd"

## Pokój okrągły / eliptyczny: sam rdzeń z OrganicCaveRoomCarver, bez wybrzuszeń
## (flaga room_shape = "round").


func carve(ctx: GenerationContext, rect: Rect2i) -> void:
	var grid := ctx.grid
	var center := rect.get_center()
	var rx_rad := rect.size.x / 2.0
	var ry_rad := rect.size.y / 2.0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var dx := (x - center.x) / rx_rad
			var dy := (y - center.y) / ry_rad
			if dx * dx + dy * dy <= 1.0:
				grid[Vector2i(x, y)] = CellType.FLOOR
