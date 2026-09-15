class_name GridPass
extends RefCounted

const CellType = preload("res://modules/quiz_rpg/scripts/generation/core/cell_type.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")

## Stabilny identyfikator do statystyk i logów.
func get_id() -> StringName:
	return &"grid_pass"


func is_enabled(_ctx: GenerationContext) -> bool:
	return true


## Zwraca liczbę zmienionych komórek.
func apply(_ctx: GenerationContext) -> int:
	return 0
