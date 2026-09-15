class_name CorridorCarver
extends RefCounted

const CellType = preload("res://modules/quiz_rpg/scripts/generation/core/cell_type.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")

func carve(_ctx: GenerationContext, _from: Vector2i, _to: Vector2i, _width: int) -> void:
	push_error("CorridorCarver.carve() must be overridden")
