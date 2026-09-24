class_name OutCornerPlacer
extends RefCounted


static func _queue(
	plan: TilePlacementPlan,
	target_pos: Vector2i,
	atlas_coords: Vector2i,
	category: StringName,
	table: Dictionary,
	origin: Vector2i = Vector2i.ZERO
) -> void:
	var p := TilePlacement.new()
	p.pos = target_pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	p.origin = origin
	p.out_corner = true
	# Na własnej kolumnie tie_breaker = 10; na kolumnie sąsiedniej = 1 (§10.4).
	p.tie_breaker = 10 if (origin == Vector2i.ZERO or target_pos.x == origin.x) else 1
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Ścieżka modułowa (origin = anchor, tie_breaker jak _queue). true jeśli położono.
static func _try_out(ctx: GenerationContext, plan: TilePlacementPlan, anchor: Vector2i, module_role: TileModuleRole.Id, variant_id: StringName, table: Dictionary, force_id: StringName = &"") -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, anchor, module_role, [], -1, variant_id, force_id)
	if parts.is_empty():
		return false
	for rp in parts:
		var p := TilePlacement.new()
		p.pos = anchor + rp.offset
		p.layer = rp.layer if rp.layer != &"" else &"Walls"
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"FACADE"
		p.origin = anchor
		p.out_corner = true
		p.tie_breaker = 10 if (anchor == Vector2i.ZERO or p.pos.x == anchor.x) else 1
		PlacementPriority.assign(p, table)
		plan.queue(p)
	return true


static func place(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan,
	use_roots: bool,
	w_open: bool,
	e_open: bool
) -> void:
	var pos := edge.pos
	var table := ctx.priority_table

	if w_open and not e_open:
		if edge.facade_height == 2:
			# 2H reużywa końcówkę FACADE_2H WEST (te same kafle/kategoria).
			if not _try_out(ctx, plan, pos, TileModuleRole.Id.FACADE_2H, &"WEST", table):
				_queue(plan, pos, CaveTileConstants.WALL_2H_WEST_BASE, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_WEST_TOP, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		else:
			var vid: StringName = &"A"
			if not _try_out(ctx, plan, pos, TileModuleRole.Id.OUT_CORNER_WEST, vid, table, &"caves_roots" if use_roots else &""):
				var top_t := CaveTileConstants.MOD_CRNR_NW_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_TOP
				var mid_t := CaveTileConstants.MOD_CRNR_NW_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_MID
				var base_t := CaveTileConstants.MOD_CRNR_NW_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_BASE
				_queue(plan, pos, base_t, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")

	elif e_open and not w_open:
		if edge.facade_height == 2:
			if not _try_out(ctx, plan, pos, TileModuleRole.Id.FACADE_2H, &"EAST", table):
				_queue(plan, pos, CaveTileConstants.WALL_2H_EAST_BASE, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_EAST_TOP, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		else:
			var vid: StringName = &"A"
			if not _try_out(ctx, plan, pos, TileModuleRole.Id.OUT_CORNER_EAST, vid, table, &"caves_roots" if use_roots else &""):
				var top_t := CaveTileConstants.MOD_CRNR_NE_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_TOP
				var mid_t := CaveTileConstants.MOD_CRNR_NE_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_MID
				var base_t := CaveTileConstants.MOD_CRNR_NE_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_BASE
				_queue(plan, pos, base_t, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
			state.mark(pos + Vector2i(0, -2), &"FACADE")
