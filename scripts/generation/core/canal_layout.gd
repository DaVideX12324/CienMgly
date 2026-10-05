class_name CanalLayout
extends "../structured/core/linear_feature_layout.gd"

## Kanały (ścieki) jako NAKŁADKA na podłogę — dziedziczy po uniwersalnym LinearFeatureLayout.
## Zachowuje pola water, bridges, bridge_cells dla pełnej kompatybilności wstecznej.

var water: Dictionary = cells
var bridges: Array[Dictionary] = crossings
var bridge_cells: Dictionary = crossing_cells


func _init() -> void:
	feature_type = &"canal"
	water = cells
	bridges = crossings
	bridge_cells = crossing_cells


func is_water(p: Vector2i) -> bool:
	return cells.has(p)


func rebuild_blocked() -> void:
	super.rebuild_blocked()
	water = cells
	bridges = crossings
	bridge_cells = crossing_cells
