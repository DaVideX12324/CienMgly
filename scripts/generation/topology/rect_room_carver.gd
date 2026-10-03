class_name RectRoomCarver
extends "res://modules/quiz_rpg/scripts/generation/topology/room_carver.gd"

## Pokój prostokątny: cały prostokąt podłogi (flaga room_shape = "rect").


func carve(ctx: GenerationContext, rect: Rect2i) -> void:
	var grid := ctx.grid
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			grid[Vector2i(x, y)] = CellType.FLOOR
