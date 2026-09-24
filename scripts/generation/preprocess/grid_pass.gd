class_name GridPass
extends RefCounted


## Stabilny identyfikator do statystyk i logów.
func get_id() -> StringName:
	return &"grid_pass"


func is_enabled(_ctx: GenerationContext) -> bool:
	return true


## Zwraca liczbę zmienionych komórek.
func apply(_ctx: GenerationContext) -> int:
	return 0
