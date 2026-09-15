class_name JunctionSmoothingPass
extends "res://modules/quiz_rpg/scripts/generation/preprocess/grid_pass.gd"

func get_id() -> StringName:
	return &"junction_smoothing"


func is_enabled(ctx: GenerationContext) -> bool:
	return ctx.flags == null or ctx.flags.enable_junction_smoothing


func apply(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height
	var changed_count := 0

	var to_carve: Array[Vector2i] = []
	for y in range(2, height - 2):
		for x in range(2, width - 2):
			var p := Vector2i(x, y)
			if grid.get(p, CellType.WALL) == CellType.WALL:
				var floor_cardinal := 0
				if GridUtils.is_walkable(grid, p + Vector2i(1, 0)): floor_cardinal += 1
				if GridUtils.is_walkable(grid, p + Vector2i(-1, 0)): floor_cardinal += 1
				if GridUtils.is_walkable(grid, p + Vector2i(0, 1)): floor_cardinal += 1
				if GridUtils.is_walkable(grid, p + Vector2i(0, -1)): floor_cardinal += 1

				if floor_cardinal >= 2:
					var floor_corners := 0
					if GridUtils.is_walkable(grid, p + Vector2i(1, 1)): floor_corners += 1
					if GridUtils.is_walkable(grid, p + Vector2i(-1, 1)): floor_corners += 1
					if GridUtils.is_walkable(grid, p + Vector2i(1, -1)): floor_corners += 1
					if GridUtils.is_walkable(grid, p + Vector2i(-1, -1)): floor_corners += 1

					if floor_cardinal + floor_corners >= 4:
						to_carve.append(p)

	for p in to_carve:
		grid[p] = CellType.FLOOR
		changed_count += 1

	var to_fill: Array[Vector2i] = []
	for y in range(2, height - 2):
		for x in range(2, width - 2):
			var p := Vector2i(x, y)
			if GridUtils.is_walkable(grid, p):
				var wall_cardinal := 0
				if not GridUtils.is_walkable(grid, p + Vector2i(1, 0)): wall_cardinal += 1
				if not GridUtils.is_walkable(grid, p + Vector2i(-1, 0)): wall_cardinal += 1
				if not GridUtils.is_walkable(grid, p + Vector2i(0, 1)): wall_cardinal += 1
				if not GridUtils.is_walkable(grid, p + Vector2i(0, -1)): wall_cardinal += 1

				if wall_cardinal >= 3:
					to_fill.append(p)

	for p in to_fill:
		grid[p] = CellType.WALL
		changed_count += 1

	return changed_count
