class_name GridPreprocessor
extends RefCounted


## Uruchamia passy w PODANEJ kolejności. Zapisuje statystyki do ctx.preprocess_stats.
static func run(ctx: GenerationContext, passes: Array[GridPass]) -> void:
	for p in passes:
		if p.is_enabled(ctx):
			var changed := p.apply(ctx)
			ctx.preprocess_stats[p.get_id()] = changed


## Uruchamia grupę passów czyszczących w pętli zbieżnej (jak _cleanup_grid_before_tiling)
static func run_convergent(ctx: GenerationContext, passes: Array[GridPass], max_passes: int = 4) -> void:
	var active_passes: Array[GridPass] = []
	for p in passes:
		if p.is_enabled(ctx):
			active_passes.append(p)

	if active_passes.is_empty():
		return

	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height
	var changed := true
	var pass_count := 0
	var total_changed := 0

	while changed and pass_count < max_passes:
		changed = false
		pass_count += 1
		var to_carve: Array[Vector2i] = []

		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var pos := Vector2i(x, y)
				if grid.get(pos, CellType.WALL) != CellType.WALL:
					continue

				var w_n := not GridUtils.is_walkable(grid, pos + Vector2i(0, -1))
				var w_s := not GridUtils.is_walkable(grid, pos + Vector2i(0, 1))
				var w_w := not GridUtils.is_walkable(grid, pos + Vector2i(-1, 0))
				var w_e := not GridUtils.is_walkable(grid, pos + Vector2i(1, 0))

				var wall_cardinal := 0
				if w_n: wall_cardinal += 1
				if w_s: wall_cardinal += 1
				if w_w: wall_cardinal += 1
				if w_e: wall_cardinal += 1

				for p in active_passes:
					if p.has_method("should_carve_wall"):
						if p.should_carve_wall(ctx, pos, w_n, w_s, w_w, w_e, wall_cardinal):
							to_carve.append(pos)
							break

		if not to_carve.is_empty():
			for p in to_carve:
				grid[p] = CellType.FLOOR
				total_changed += 1
			changed = true

	for p in active_passes:
		ctx.preprocess_stats[p.get_id()] = total_changed
