class_name RoomCarverFactory
extends RefCounted


static func create(carver_id: StringName) -> RoomCarver:
	match carver_id:
		&"organic_cave":
			return OrganicCaveRoomCarver.new()
		_:
			return OrganicCaveRoomCarver.new()
