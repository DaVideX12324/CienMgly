class_name RimPlacer
extends RefCounted


## Ścieżka modułowa dla rima rock (1 kafel, kategoria RIM_BASE, tie_breaker=0).
static func _try_rim(ctx: GenerationContext, placement_plan: TilePlacementPlan, pos: Vector2i, module_role: TileModuleRole.Id, variant_id: StringName, table: Dictionary, out_corner: bool = false) -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, pos, module_role, [], -1, variant_id)
	if parts.is_empty():
		return false
	for rp in parts:
		var p := TilePlacement.new()
		p.pos = pos + rp.offset
		p.layer = rp.layer if rp.layer != &"" else &"Walls"
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"RIM_BASE"
		p.out_corner = out_corner
		PlacementPriority.assign(p, table)
		placement_plan.queue(p)
	return true


static func _get_variant_noise(ctx: GenerationContext) -> FastNoiseLite:
	if ctx.variant_noise != null:
		return ctx.variant_noise
	var n := FastNoiseLite.new()
	n.seed = ctx.seed_value + 777
	n.frequency = 0.45
	ctx.variant_noise = n
	return n


static func _queue(placement_plan: TilePlacementPlan, pos: Vector2i, atlas_coords: Vector2i, category: StringName, table: Dictionary, out_corner: bool = false) -> void:
	var p := TilePlacement.new()
	p.pos = pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	p.out_corner = out_corner
	PlacementPriority.assign(p, table)
	placement_plan.queue(p)


## Planuje górny szczyt ściany (TOP_RIM), misy i dekoracje tips w porządku kanonicznym (y, x).
static func plan(
	ctx: GenerationContext,
	edges: Dictionary,
	state: LegacyPlacementState,
	placement_plan: TilePlacementPlan
) -> void:
	var scan := ctx.scan_bounds()
	var table := ctx.priority_table
	var v_noise := _get_variant_noise(ctx)

	for y in range(scan.position.y, scan.end.y):
		for x in range(scan.position.x, scan.end.x):
			var pos := Vector2i(x, y)
			var edge: EdgeContext = edges.get(pos)
			if edge == null or edge.edge_kind != EdgeKind.Kind.TOP_RIM:
				continue

			if state.has(pos) and (state.get_category(pos) == &"FACADE" or state.get_category(pos) == &"SIDE_FIXED"):
				continue

			var use_roots: bool = ThemeResolver.resolve(ctx, pos, ThemeResolver.RefPoint.NORTH_FLOOR) == &"roots"
			var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
			# Koniec rimu (narożnik out, przezroczysty) — PlateauRenderer nie wchłania pod nim płaskowyżu.
			var corner: bool = edge.orientation == EdgeKind.Orientation.EAST or edge.orientation == EdgeKind.Orientation.WEST

			if not use_roots:
				# Motyw rock (1-kafelkowy). is_b (A/B) z variant_noise; orientacja -> rola.
				var variant_id: StringName = &"B" if is_b else &"A"
				var role: int = TileModuleRole.Id.RIM_NORTH
				var rim_t := Vector2i(2, 0)
				match edge.orientation:
					EdgeKind.Orientation.EAST:
						role = TileModuleRole.Id.RIM_EAST
						rim_t = CaveTileConstants.CRNR_SE_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SE_OUT_BASE_A
					EdgeKind.Orientation.WEST:
						role = TileModuleRole.Id.RIM_WEST
						rim_t = CaveTileConstants.CRNR_SW_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SW_OUT_BASE_A
					_:
						rim_t = Vector2i(3, 0) if is_b else Vector2i(2, 0)

				if not _try_rim(ctx, placement_plan, pos, role, variant_id, table, corner):
					_queue(placement_plan, pos, rim_t, &"RIM_BASE", table, corner)
				state.mark(pos, &"RIM")

			else:
				# Motyw roots (2-kafelkowy: base RIM_BASE + warunkowy tips RIM_TIP) -> LEGACY.
				# Dwie różne kategorie i warunkowy tips nie mieszczą się w module o jednej kategorii.
				var p_top := pos + Vector2i(0, -1)
				var can_place_top: bool = not (state.has(p_top) and state.get_category(p_top) == &"FACADE")
				var t_base := Vector2i(2, 9)
				var t_tips := Vector2i(2, 8)

				match edge.orientation:
					EdgeKind.Orientation.EAST:
						t_base = CaveTileConstants.CRNR_SE_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_BASE
						t_tips = CaveTileConstants.CRNR_SE_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_TIPS
					EdgeKind.Orientation.WEST:
						t_base = CaveTileConstants.CRNR_SW_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_BASE
						t_tips = CaveTileConstants.CRNR_SW_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_TIPS
					_:
						t_base = CaveTileConstants.ROOT_TOP_BASE[1] if is_b else CaveTileConstants.ROOT_TOP_BASE[0]
						t_tips = CaveTileConstants.ROOT_TOP_TIPS[1] if is_b else CaveTileConstants.ROOT_TOP_TIPS[0]

				_queue(placement_plan, pos, t_base, &"RIM_BASE", table, corner)
				state.mark(pos, &"RIM")
				if can_place_top:
					_queue(placement_plan, p_top, t_tips, &"RIM_TIP", table, corner)
					state.mark(p_top, &"RIM")
