class_name CorridorCarverFactory
extends RefCounted


static func create(carver_id: StringName) -> CorridorCarver:
	match carver_id:
		&"organic_meandering":
			return OrganicCorridorCarver.new()
		_:
			return OrganicCorridorCarver.new()
