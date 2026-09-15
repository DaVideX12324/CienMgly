class_name RoomCarver
extends RefCounted

const CellType = preload("res://modules/quiz_rpg/scripts/generation/core/cell_type.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")

func carve(_ctx: GenerationContext, _room: Rect2i) -> void:
	push_error("RoomCarver.carve() must be overridden")
