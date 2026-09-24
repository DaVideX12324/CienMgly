class_name PlacementPriority
extends RefCounted


const LEGACY_FACADE_WINS := {
	&"SOLID_FILL": 10, &"RIM_BOWL": 15, &"FLOOR_BASE": 20, &"FLOOR_DECOR": 30,
	&"SIDE_WALL": 40, &"RIM_BOWL_DECORATED": 42, &"CORNER": 45,
	&"RIM_BASE": 50, &"RIM_TIP": 51,
	&"SIDE_WALL_FIXED": 60, &"STEP": 65, &"FACADE": 70, &"CONNECTOR": 70,
	&"OUT_CORNER": 70, &"NICHE": 75, &"PILLAR": 80, &"PORTAL_CLEAR": 1000,
	&"PLATFORM": 70, &"STAIR": 75,
}

const README_RIM_WINS := {
	&"SOLID_FILL": 10, &"FLOOR_BASE": 20, &"FLOOR_DECOR": 30,
	&"SIDE_WALL": 40, &"SIDE_WALL_FIXED": 40, &"FACADE": 50, &"CONNECTOR": 50,
	&"CORNER": 60, &"OUT_CORNER": 60, &"STEP": 60,
	&"RIM_BASE": 70, &"RIM_BOWL": 70, &"RIM_BOWL_DECORATED": 70, &"RIM_TIP": 71,
	&"PILLAR": 80, &"NICHE": 90, &"PORTAL_CLEAR": 1000,
	&"PLATFORM": 70, &"STAIR": 75,
}

static func get_table(preset_id: StringName, overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary
	match preset_id:
		&"legacy_facade_wins": base = LEGACY_FACADE_WINS.duplicate()
		&"readme_rim_wins":    base = README_RIM_WINS.duplicate()
		_:
			push_error("Unknown priority preset: %s" % preset_id)
			base = LEGACY_FACADE_WINS.duplicate()
	for key in overrides:
		base[StringName(key)] = int(overrides[key])
	return base


static func assign(placement: TilePlacement, table: Dictionary) -> void:
	if not table.has(placement.category):
		push_error("PlacementPriority: brak priorytetu dla kategorii '%s'" % placement.category)
		placement.priority = 0
		return
	placement.priority = int(table[placement.category])
