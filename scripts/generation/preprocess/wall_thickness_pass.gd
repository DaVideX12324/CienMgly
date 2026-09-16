class_name WallThicknessPass
extends "res://modules/quiz_rpg/scripts/generation/preprocess/grid_pass.gd"

func get_id() -> StringName:
	return &"wall_thickness"


func apply(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height

	var changed := true
	var passes := 0
	var total_changed := 0

	while changed and passes < 4:
		changed = false
		passes += 1

		# 1. Pozioma grubość ścian (ściana dzieląca dwie przestrzenie musi mieć >= 2 kratki szerokości)
		for y in range(height):
			var x := 0
			while x < width:
				if grid.get(Vector2i(x, y), CellType.WALL) == CellType.WALL:
					var x_start := x
					while x < width and grid.get(Vector2i(x, y), CellType.WALL) == CellType.WALL:
						x += 1
					var x_end := x - 1
					var wall_len := x_end - x_start + 1

					var has_floor_left := (x_start > 0 and GridUtils.is_walkable(grid, Vector2i(x_start - 1, y)))
					var has_floor_right := (x_end < width - 1 and GridUtils.is_walkable(grid, Vector2i(x_end + 1, y)))

					if has_floor_left and has_floor_right and wall_len < 2:
						for cx in range(x_start, x_end + 1):
							grid[Vector2i(cx, y)] = CellType.FLOOR
							total_changed += 1
						changed = true
				else:
					x += 1

		# 2. Usuwanie samotnych, pojedynczych klocków ściany 1x1 otoczonych podłogą z 3 lub 4 stron
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var p := Vector2i(x, y)
				if grid.get(p, CellType.WALL) == CellType.WALL:
					var floor_count := 0
					if GridUtils.is_walkable(grid, p + Vector2i(1, 0)): floor_count += 1
					if GridUtils.is_walkable(grid, p + Vector2i(-1, 0)): floor_count += 1
					if GridUtils.is_walkable(grid, p + Vector2i(0, 1)): floor_count += 1
					if GridUtils.is_walkable(grid, p + Vector2i(0, -1)): floor_count += 1

					if floor_count >= 3:
						grid[p] = CellType.FLOOR
						total_changed += 1
						changed = true

		# 3. Eliminacja skośnych styków podłóg przez litą ścianę
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var p := Vector2i(x, y)
				if grid.get(p, CellType.WALL) == CellType.WALL:
					if grid.get(p + Vector2i(0, -1), CellType.WALL) == CellType.WALL \
					and grid.get(p + Vector2i(0, 1), CellType.WALL) == CellType.WALL \
					and grid.get(p + Vector2i(-1, 0), CellType.WALL) == CellType.WALL \
					and grid.get(p + Vector2i(1, 0), CellType.WALL) == CellType.WALL:
						var nw := GridUtils.is_walkable(grid, p + Vector2i(-1, -1))
						var ne := GridUtils.is_walkable(grid, p + Vector2i(1, -1))
						var sw := GridUtils.is_walkable(grid, p + Vector2i(-1, 1))
						var se := GridUtils.is_walkable(grid, p + Vector2i(1, 1))

						# Wzorzec 1: 100 / 000 / 001 -> górny narożnik NW staje się 0
						if nw and se and not ne and not sw:
							grid[p + Vector2i(-1, -1)] = CellType.WALL
							total_changed += 1
							changed = true
						# Wzorzec 2: 001 / 000 / 100 -> górny narożnik NE staje się 0
						elif ne and sw and not nw and not se:
							grid[p + Vector2i(1, -1)] = CellType.WALL
							total_changed += 1
							changed = true

	return total_changed
