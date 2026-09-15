class_name ShortBulgeFlattenPass
extends "res://modules/quiz_rpg/scripts/generation/preprocess/grid_pass.gd"

func get_id() -> StringName:
	return &"short_bulge_flatten"


func apply(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height
	var changed_count := 0

	for y in range(3, height - 1):
		var x := 1
		while x < width - 1:
			var p := Vector2i(x, y)
			if GridUtils.is_walkable(grid, p) and not GridUtils.is_walkable(grid, p + Vector2i(0, -1)):
				var is_col_2h := func(cx: int) -> bool:
					return GridUtils.is_walkable(grid, Vector2i(cx, y)) \
						and not GridUtils.is_walkable(grid, Vector2i(cx, y - 1)) \
						and not GridUtils.is_walkable(grid, Vector2i(cx, y - 2)) \
						and GridUtils.is_walkable(grid, Vector2i(cx, y - 3))

				var is_col_3h_plus := func(cx: int) -> bool:
					return GridUtils.is_walkable(grid, Vector2i(cx, y)) \
						and not GridUtils.is_walkable(grid, Vector2i(cx, y - 1)) \
						and not GridUtils.is_walkable(grid, Vector2i(cx, y - 2)) \
						and not GridUtils.is_walkable(grid, Vector2i(cx, y - 3))

				if is_col_3h_plus.call(x):
					var bulge_start := x
					while x < width - 1 and is_col_3h_plus.call(x):
						x += 1
					var bulge_end := x - 1
					var bulge_width := bulge_end - bulge_start + 1

					var left_is_2h: bool = (bulge_start > 1 and is_col_2h.call(bulge_start - 1))
					var right_is_2h: bool = (bulge_end < width - 2 and is_col_2h.call(bulge_end + 1))

					if bulge_width < 4 and (left_is_2h or right_is_2h):
						for bx in range(bulge_start, bulge_end + 1):
							var cy := y - 3
							while cy >= 0 and not GridUtils.is_walkable(grid, Vector2i(bx, cy)):
								grid[Vector2i(bx, cy)] = CellType.FLOOR
								changed_count += 1
								cy -= 1
				else:
					x += 1
			else:
				x += 1

	return changed_count
