class_name WallThicknessPass
extends "grid_pass.gd"

func get_id() -> StringName:
	return &"wall_thickness"


func apply(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height

	var changed := true
	var passes := 0
	var total_changed := 0
	# Raster typów kratek (aktualizowany przy każdym zapisie): „ściana” = grid.get(p, WALL) == WALL, czyli WALL
	# albo brak kratki; „podłoga” = GridUtils.is_walkable.
	var t := type_raster(ctx)
	const W := CellType.WALL
	const F := CellType.FLOOR

	while changed and passes < 4:
		changed = false
		passes += 1

		# 1. Pozioma grubość ścian (ściana dzieląca dwie przestrzenie musi mieć >= 2 kratki szerokości)
		for y in range(height):
			var row := y * width
			var x := 0
			while x < width:
				var tv: int = t[row + x]
				if tv == W or tv == MISSING:
					var x_start := x
					while x < width and (t[row + x] == W or t[row + x] == MISSING):
						x += 1
					var x_end := x - 1
					var wall_len := x_end - x_start + 1

					var has_floor_left := x_start > 0 and walkable_type(t[row + x_start - 1])
					var has_floor_right := x_end < width - 1 and walkable_type(t[row + x_end + 1])

					if has_floor_left and has_floor_right and wall_len < 2:
						for cx in range(x_start, x_end + 1):
							grid[Vector2i(cx, y)] = F
							t[row + cx] = F
							total_changed += 1
						changed = true
				else:
					x += 1

		# 2. Usuwanie samotnych, pojedynczych klocków ściany 1x1 otoczonych podłogą z 3 lub 4 stron
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var i := y * width + x
				if t[i] == W or t[i] == MISSING:
					var floor_count := int(walkable_type(t[i + 1])) + int(walkable_type(t[i - 1])) \
							+ int(walkable_type(t[i + width])) + int(walkable_type(t[i - width]))
					if floor_count >= 3:
						grid[Vector2i(x, y)] = F
						t[i] = F
						total_changed += 1
						changed = true

		# 3. Eliminacja skośnych styków podłóg przez litą ścianę
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var i := y * width + x
				if (t[i] == W or t[i] == MISSING) and (t[i - width] == W or t[i - width] == MISSING) \
						and (t[i + width] == W or t[i + width] == MISSING) and (t[i - 1] == W or t[i - 1] == MISSING) \
						and (t[i + 1] == W or t[i + 1] == MISSING):
					var nw := walkable_type(t[i - width - 1])
					var ne := walkable_type(t[i - width + 1])
					var sw := walkable_type(t[i + width - 1])
					var se := walkable_type(t[i + width + 1])

					# Wzorzec 1: 100 / 000 / 001 -> górny narożnik NW staje się 0
					if nw and se and not ne and not sw:
						grid[Vector2i(x - 1, y - 1)] = W
						t[i - width - 1] = W
						total_changed += 1
						changed = true
					# Wzorzec 2: 001 / 000 / 100 -> górny narożnik NE staje się 0
					elif ne and sw and not nw and not se:
						grid[Vector2i(x + 1, y - 1)] = W
						t[i - width + 1] = W
						total_changed += 1
						changed = true

	return total_changed
