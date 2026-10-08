extends RefCounted

## Ściany szerokości 1 (canals.walls_1w, flaga enable_1w_walls): kafle roli WALL_1W z profilu, wariant = rząd
## występu (TOP / MID / BOTTOM / FACE_TOP / BASE). Kategoria WALL_1W wygrywa z kaflami podłogi i ścian w tych kratkach.

static func plan(ctx: GenerationContext, plan: TilePlacementPlan) -> void:
	if ctx.canals == null or not "walls_1w" in ctx.canals or ctx.canals.walls_1w.is_empty():
		return
	var table: Dictionary = ctx.priority_table
	for pos: Vector2i in ctx.canals.walls_1w:
		var vid: StringName = ctx.canals.walls_1w[pos]
		var parts := TileResolver.resolve_module_parts(ctx, pos, TileModuleRole.Id.WALL_1W, [], -1, vid)
		for rp in parts:
			FacadePlacer._queue_part(plan, pos + rp.offset, rp, &"WALL_1W", table)
