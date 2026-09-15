class_name FacadeSegment
extends RefCounted

## Reprezentacja ścisłego, ciągłego odcinka poziomego fasady lub rimu.
var y: int = 0
var x_start: int = 0
var x_end: int = 0
var cells: Array[Vector2i] = []

func get_length() -> int:
	return cells.size()
