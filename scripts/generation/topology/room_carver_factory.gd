class_name RoomCarverFactory
extends RefCounted


## carver_id = flaga GenerationFlags.room_shape: organic (domyślnie) | rect | round | mixed.
static func create(carver_id: StringName) -> RoomCarver:
	match carver_id:
		&"rect":
			return RectRoomCarver.new()
		&"round":
			return RoundRoomCarver.new()
		&"mixed":
			return MixedRoomCarver.new()
		_:  # organic, organic_cave, nieznane
			return OrganicCaveRoomCarver.new()
