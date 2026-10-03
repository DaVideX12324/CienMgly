class_name MixedRoomCarver
extends "res://modules/quiz_rpg/scripts/generation/topology/room_carver.gd"

## Kształt losowany per pokój spośród organicznego, prostokątnego i okrągłego
## (flaga room_shape = "mixed"; los z ctx.rng — powtarzalny dla seeda).

var _carvers: Array[RoomCarver] = [OrganicCaveRoomCarver.new(), RectRoomCarver.new(), RoundRoomCarver.new()]


func carve(ctx: GenerationContext, rect: Rect2i) -> void:
	_carvers[ctx.rng.randi() % _carvers.size()].carve(ctx, rect)
