class_name CanalLayout
extends RefCounted

## Kanały (ścieki) jako NAKŁADKA na podłogę — grid zostaje FLOOR (ściany i lico liczą się jak dotąd).
## water   — kratki kanału (kwas i lico brzegu), także pod kładkami.
## bridges — kładki: {rect: Rect2i (cały ślad z brzegami), vertical: bool (kładka pionowa = przez kanał
##           poziomy)}.
## blocked — water bez kratek kładek: tu nie da się chodzić (nawigacja, spawny, obiekty tego unikają).

var water: Dictionary = {}
var bridges: Array[Dictionary] = []
var bridge_cells: Dictionary = {}
var blocked: Dictionary = {}


func is_empty() -> bool:
	return water.is_empty()


func is_water(p: Vector2i) -> bool:
	return water.has(p)


## Przelicza blocked po zmianie water / bridges.
func rebuild_blocked() -> void:
	bridge_cells.clear()
	for b in bridges:
		var r: Rect2i = b.rect
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				bridge_cells[Vector2i(x, y)] = true
	blocked.clear()
	for p in water:
		if not bridge_cells.has(p):
			blocked[p] = true
