class_name StepPlacer
extends RefCounted


static func _queue(
	plan: TilePlacementPlan,
	target_pos: Vector2i,
	atlas_coords: Vector2i,
	category: StringName,
	table: Dictionary,
	origin: Vector2i = Vector2i.ZERO,
	out_corner: bool = false
) -> void:
	var p := TilePlacement.new()
	p.pos = target_pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	p.origin = origin
	p.out_corner = out_corner
	# Na własnej kolumnie tie_breaker = 10; na kolumnie sąsiedniej = 1 (§10.4).
	p.tie_breaker = 10 if (origin == Vector2i.ZERO or target_pos.x == origin.x) else 1
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Ścieżka modułowa (kategoria FACADE, origin = anchor). true jeśli położono.
static func _try(ctx: GenerationContext, plan: TilePlacementPlan, anchor: Vector2i, module_role: TileModuleRole.Id, variant_id: StringName, table: Dictionary, force_id: StringName = &"", out_corner: bool = false) -> bool:
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
		p.out_corner = out_corner
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
	left_y: int,
	right_y: int,
	edges: Dictionary = {}
) -> void:
	var pos := edge.pos
	var y := pos.y
	var table := ctx.priority_table

	if left_y != -1 and y > left_y:
		if edge.facade_height == 2 and ctx.plateau_mode:
			# Płaskowyż: stopień lica 2H = moduł IN (2 części: base + top); narożnik wewnętrzny
			# nad nim daje EdgeAnalyzer (INNER_CORNER SE). Bez fallbacku na stałe ścian.
			_try(ctx, plan, pos, TileModuleRole.Id.STEP_LEFT, &"A", table)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		elif edge.facade_height == 2:
			# 2H reużywa końcówkę FACADE_2H WEST (te same kafle).
			if not _try(ctx, plan, pos, TileModuleRole.Id.FACADE_2H, &"WEST", table, &"", true):
				_queue(plan, pos, CaveTileConstants.WALL_2H_WEST_BASE, &"FACADE", table, pos, true)
				_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_WEST_TOP, &"FACADE", table, pos, true)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		else:
			var dy: int = y - left_y
			# Skos "1-dół-1-bok" o ścianie 4/5 (warunkowy top) zostaje ścieżką legacy —
			# nie mapuje się na moduł o stałej liczbie części. Reszta = narożnik 3H STEP_LEFT.
			if dy == 1 and (right_y == y + 1 or right_y == -1) and (edge.solid_depth == 4 or edge.solid_depth == 5):
				_queue(plan, pos, CaveTileConstants.WALL_2H_SLOPE_LEFT_BASE, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_SLOPE_LEFT_MID, &"FACADE", table, pos)
				var p_top := pos + Vector2i(0, -2)
				var e_top: EdgeContext = edges.get(p_top)
				if e_top == null or e_top.edge_kind != EdgeKind.Kind.SIDE_WALL:
					_queue(plan, p_top, CaveTileConstants.WALL_2H_SLOPE_LEFT_TOP, &"FACADE", table, pos)
					state.mark(p_top, &"FACADE")
			else:
				var step_use_roots: bool = use_roots and (dy == 1)
				var vid: StringName = &"A"
				if not _try(ctx, plan, pos, TileModuleRole.Id.STEP_LEFT, vid, table, &"caves_roots" if step_use_roots else &""):
					var base_t := CaveTileConstants.MOD_CRNR_NW_IN_BASE if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_BASE
					var mid_t := CaveTileConstants.MOD_CRNR_NW_IN_MID if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_MID
					var top_t := CaveTileConstants.MOD_CRNR_NW_IN_TOP if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_TOP
					_queue(plan, pos, base_t, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)
				state.mark(pos + Vector2i(0, -2), &"FACADE")

			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")

	elif right_y != -1 and y > right_y:
		if edge.facade_height == 2 and ctx.plateau_mode:
			_try(ctx, plan, pos, TileModuleRole.Id.STEP_RIGHT, &"A", table)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		elif edge.facade_height == 2:
			if not _try(ctx, plan, pos, TileModuleRole.Id.FACADE_2H, &"EAST", table, &"", true):
				_queue(plan, pos, CaveTileConstants.WALL_2H_EAST_BASE, &"FACADE", table, pos, true)
				_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_EAST_TOP, &"FACADE", table, pos, true)
			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
		else:
			var dy: int = y - right_y
			if dy == 1 and (left_y == y + 1 or left_y == -1) and (edge.solid_depth == 4 or edge.solid_depth == 5):
				_queue(plan, pos, CaveTileConstants.WALL_2H_SLOPE_RIGHT_BASE, &"FACADE", table, pos)
				_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_SLOPE_RIGHT_MID, &"FACADE", table, pos)
				var p_top := pos + Vector2i(0, -2)
				var e_top: EdgeContext = edges.get(p_top)
				if e_top == null or e_top.edge_kind != EdgeKind.Kind.SIDE_WALL:
					_queue(plan, p_top, CaveTileConstants.WALL_2H_SLOPE_RIGHT_TOP, &"FACADE", table, pos)
					state.mark(p_top, &"FACADE")
			else:
				var step_use_roots: bool = use_roots and (dy == 1)
				var vid: StringName = &"A"
				if not _try(ctx, plan, pos, TileModuleRole.Id.STEP_RIGHT, vid, table, &"caves_roots" if step_use_roots else &""):
					var base_t := CaveTileConstants.MOD_CRNR_NE_IN_BASE if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_BASE
					var mid_t := CaveTileConstants.MOD_CRNR_NE_IN_MID if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_MID
					var top_t := CaveTileConstants.MOD_CRNR_NE_IN_TOP if not step_use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_TOP
					_queue(plan, pos, base_t, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table, pos)
					_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table, pos)
				state.mark(pos + Vector2i(0, -2), &"FACADE")

			state.mark(pos, &"FACADE")
			state.mark(pos + Vector2i(0, -1), &"FACADE")
