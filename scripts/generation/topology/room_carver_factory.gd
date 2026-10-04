class_name RoomCarverFactory
extends RefCounted

const PolyRoomCarverScript = preload("poly_room_carver.gd")


## carver_id = flaga GenerationFlags.room_shape: organic (domyślnie) | rect | round | mixed | poly.
static func create(carver_id: StringName) -> RoomCarver:
	match carver_id:
		&"rect":
			return RectRoomCarver.new()
		&"round":
			return RoundRoomCarver.new()
		&"mixed":
			return MixedRoomCarver.new()
		&"poly":
			return PolyRoomCarverScript.new()
		_:  # organic, organic_cave, nieznane
			return OrganicCaveRoomCarver.new()
