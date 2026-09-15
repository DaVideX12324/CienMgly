class_name CorridorCarverFactory
extends RefCounted

const CorridorCarver = preload("res://modules/quiz_rpg/scripts/generation/topology/corridor_carver.gd")
const OrganicCorridorCarver = preload("res://modules/quiz_rpg/scripts/generation/topology/organic_corridor_carver.gd")

static func create(carver_id: StringName) -> CorridorCarver:
	match carver_id:
		&"organic_meandering":
			return OrganicCorridorCarver.new()
		_:
			return OrganicCorridorCarver.new()
