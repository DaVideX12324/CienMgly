class_name GridUtils
extends RefCounted

const CellType = preload("res://modules/quiz_rpg/scripts/generation/core/cell_type.gd")

## Zwraca true jeśli komórka jest przechodnia (podłoga, drzwi, wejście lub wyjście).
## Zgodnie z doktryną §6.8, stan siatki logicznej jest binarny.
static func is_walkable(grid: Dictionary, pos: Vector2i) -> bool:
	var t: int = grid.get(pos, CellType.VOID)
	return t == CellType.FLOOR or t == CellType.DOOR or t == CellType.ENTRANCE or t == CellType.EXIT


static func in_bounds(pos: Vector2i, w: int, h: int) -> bool:
	return pos.x >= 0 and pos.x < w and pos.y >= 0 and pos.y < h


static func get_4_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		pos + Vector2i.RIGHT,
		pos + Vector2i.LEFT,
		pos + Vector2i.DOWN,
		pos + Vector2i.UP
	]


static func get_8_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		pos + Vector2i.UP,
		pos + Vector2i(1, -1),
		pos + Vector2i.RIGHT,
		pos + Vector2i(1, 1),
		pos + Vector2i.DOWN,
		pos + Vector2i(-1, 1),
		pos + Vector2i.LEFT,
		pos + Vector2i(-1, -1)
	]


static func carve_circle(grid: Dictionary, center: Vector2i, radius: int, w: int, h: int, cell_type: int = CellType.FLOOR) -> void:
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= r2:
				var p := center + Vector2i(dx, dy)
				if in_bounds(p, w, h):
					grid[p] = cell_type


static func get_reachable_cells(grid: Dictionary, start: Vector2i, w: int, h: int) -> Dictionary:
	var reachable: Dictionary = {}
	if not is_walkable(grid, start):
		return reachable

	var queue: Array[Vector2i] = [start]
	reachable[start] = true

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for n in get_4_neighbors(curr):
			if in_bounds(n, w, h) and is_walkable(grid, n) and not reachable.has(n):
				reachable[n] = true
				queue.append(n)

	return reachable
