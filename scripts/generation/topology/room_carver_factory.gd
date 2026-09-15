class_name RoomCarverFactory
extends RefCounted

const RoomCarver = preload("res://modules/quiz_rpg/scripts/generation/topology/room_carver.gd")
const OrganicCaveRoomCarver = preload("res://modules/quiz_rpg/scripts/generation/topology/organic_cave_room_carver.gd")

static func create(carver_id: StringName) -> RoomCarver:
	match carver_id:
		&"organic_cave":
			return OrganicCaveRoomCarver.new()
		_:
			return OrganicCaveRoomCarver.new()
