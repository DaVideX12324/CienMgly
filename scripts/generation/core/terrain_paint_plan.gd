class_name TerrainPaintPlan
extends RefCounted

class TerrainBatch:
	extends RefCounted
	var layer: StringName          # &"Floor" | &"FloorDecor"
	var cells: Array[Vector2i] = []
	var terrain_set: int = 0
	var terrain: int = 0
	var ignore_empty_terrains: bool = true
	var order: int = 0             # kolejność wykonania batchy na tej samej warstwie

var batches: Array[TerrainBatch] = []

func add_batch(layer_name: StringName, cells_arr: Array[Vector2i], t_set: int, t_idx: int, order_idx: int = 0, ignore_empty: bool = true) -> void:
	var b := TerrainBatch.new()
	b.layer = layer_name
	b.cells = cells_arr
	b.terrain_set = t_set
	b.terrain = t_idx
	b.order = order_idx
	b.ignore_empty_terrains = ignore_empty
	batches.append(b)
