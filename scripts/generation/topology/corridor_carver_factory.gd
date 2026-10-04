class_name CorridorCarverFactory
extends RefCounted


const StraightCorridorCarverScript = preload("straight_corridor_carver.gd")


## carver_id = flaga GenerationFlags.corridor_shape: organic (domyślnie) | straight (L, osiowo;
## skosy o stałym kącie wg flag corridor_diagonal_45 / corridor_diagonal_30_60).
static func create(carver_id: StringName, flags: GenerationFlags = null) -> CorridorCarver:
	match carver_id:
		&"organic_meandering":
			return OrganicCorridorCarver.new()
		&"straight":
			var carver := StraightCorridorCarverScript.new()
			if flags != null:
				carver.diagonal_45 = flags.corridor_diagonal_45
				carver.diagonal_30_60 = flags.corridor_diagonal_30_60
				carver.corner_room_chance = flags.corridor_corner_room_chance
				carver.room_carver = RoomCarverFactory.create(StringName(flags.room_shape))
			return carver
		_:
			return OrganicCorridorCarver.new()
