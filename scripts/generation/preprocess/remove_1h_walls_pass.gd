class_name Remove1hWallsPass
extends "res://modules/quiz_rpg/scripts/generation/preprocess/grid_pass.gd"

func get_id() -> StringName:
	return &"remove_1h_walls"


func apply(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height

	var to_expand_north: Array[Vector2i] = []
	var to_carve_floor: Array[Vector2i] = []

	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var p := Vector2i(x, y)
			if grid.get(p, CellType.WALL) != CellType.WALL:
				continue

			# Ściana 1H: podłoga bezpośrednio nad nią i pod nią
			if GridUtils.is_walkable(grid, p + Vector2i(0, -1)) and GridUtils.is_walkable(grid, p + Vector2i(0, 1)):
				var has_h_neighbor: bool = (
					int(grid.get(p + Vector2i(-1, 0), CellType.FLOOR)) == CellType.WALL
					or int(grid.get(p + Vector2i(1, 0), CellType.FLOOR)) == CellType.WALL
				)

				var north_cell := p + Vector2i(0, -1)
				var north_clear: bool = GridUtils.is_walkable(grid, north_cell)

				if has_h_neighbor and north_clear:
					to_expand_north.append(north_cell)
				else:
					to_carve_floor.append(p)

	for p in to_carve_floor:
		grid[p] = CellType.FLOOR

	for p in to_expand_north:
		grid[p] = CellType.WALL

	return to_carve_floor.size() + to_expand_north.size()
