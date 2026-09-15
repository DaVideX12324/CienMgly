class_name TilePlacement
extends RefCounted

var pos: Vector2i
var layer: StringName = &"Walls"
var source_id: int = 0
var atlas_coords: Vector2i = Vector2i(-1, -1)   # (-1,-1) = WYMAZANIE (erase_cell)
var alternative_tile: int = 0
var category: StringName = &""                  # klucz do presetu priorytetów
var priority: int = 0                           # wypełniane z presetu, nie z palca
var origin: Vector2i = Vector2i.ZERO            # komórka, która wygenerowała placement (debug)
var tie_breaker: int = 0                        # rozstrzyganie remisów (§10.4)

func is_erase() -> bool:
	return atlas_coords == Vector2i(-1, -1)
