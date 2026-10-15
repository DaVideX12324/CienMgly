class_name GridPreprocessor
extends RefCounted


## Uruchamia passy w PODANEJ kolejności. Zapisuje statystyki do ctx.preprocess_stats (liczba zmian pod id passa,
## łączny czas w ms pod "t_" + id — diagnostyka wydajności).
static func run(ctx: GenerationContext, passes: Array[GridPass]) -> void:
	for p in passes:
		if p.is_enabled(ctx):
			var t0 := Time.get_ticks_usec()
			var changed := p.apply(ctx)
			ctx.preprocess_stats[p.get_id()] = changed
			var tk := "t_" + String(p.get_id())
			ctx.preprocess_stats[tk] = int(ctx.preprocess_stats.get(tk, 0)) + (Time.get_ticks_usec() - t0) / 1000


## Uruchamia grupę passów czyszczących w pętli zbieżnej (jak _cleanup_grid_before_tiling)
static func run_convergent(ctx: GenerationContext, passes: Array[GridPass], max_passes: int = 4) -> void:
	var active_passes: Array[GridPass] = []
	for p in passes:
		if p.is_enabled(ctx):
			active_passes.append(p)

	if active_passes.is_empty():
		return

	var carvers: Array[GridPass] = []
	var side_floor_only := true
	for p in active_passes:
		if p.has_method("should_carve_wall"):
			carvers.append(p)
			side_floor_only = side_floor_only and p.carve_needs_side_floor()

	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height
	var changed := true
	var pass_count := 0
	var total_changed := 0
	# Raster typów (aktualizowany przy wycinaniu): „ściana” = grid.get(p, WALL) == WALL, sąsiad = GridUtils.is_walkable.
	var t := GridPass.type_raster(ctx)
	var wk := GridPass.WALK_LUT
	var sl := GridPass.WALL_LUT

	while changed and pass_count < max_passes:
		changed = false
		pass_count += 1
		var to_carve: Array[Vector2i] = []

		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var i := y * width + x
				if sl[t[i]] == 0:
					continue
				var w_w: bool = wk[t[i - 1]] == 0
				var w_e: bool = wk[t[i + 1]] == 0
				if side_floor_only and w_w and w_e:
					continue
				var w_n: bool = wk[t[i - width]] == 0
				var w_s: bool = wk[t[i + width]] == 0
				var wall_cardinal := int(w_n) + int(w_s) + int(w_w) + int(w_e)

				var pos := Vector2i(x, y)
				for p in carvers:
					if p.should_carve_wall(ctx, pos, w_n, w_s, w_w, w_e, wall_cardinal):
						to_carve.append(pos)
						break

		if not to_carve.is_empty():
			for p in to_carve:
				grid[p] = CellType.FLOOR
				t[p.y * width + p.x] = CellType.FLOOR
				total_changed += 1
			changed = true

	for p in active_passes:
		ctx.preprocess_stats[p.get_id()] = total_changed
