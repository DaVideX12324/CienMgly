class_name NichePlacer
extends RefCounted

## Alternatywa kafla w TileSecie dla nisz-przejść (kafle OUT z szerszym otworem, szczyt ściany z innymi
## kolizjami). Brak alternatywy = zwykły kafel.
const PASSAGE_ALT := 1


static func _queue(plan: TilePlacementPlan, pos: Vector2i, atlas_coords: Vector2i, category: StringName, table: Dictionary) -> void:
	var p := TilePlacement.new()
	p.pos = pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Moduł niszy: 8 części, 2 kolumny (offsety x=0 i x=1). Kategoria FACADE, tie_breaker=0.
## with_crown = false: bez korony (narożniki wewnętrzne w rzędzie -3).
static func _place_niche(ctx: GenerationContext, plan: TilePlacementPlan, anchor: Vector2i, module_role: TileModuleRole.Id, variant_id: StringName, table: Dictionary, force_id: StringName = &"", with_crown: bool = true) -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, anchor, module_role, [], -1, variant_id, force_id)
	if parts.is_empty():
		return false
	for rp in parts:
		if not with_crown and rp.offset.y <= -3:
			continue
		var p := TilePlacement.new()
		p.pos = anchor + rp.offset
		p.layer = rp.layer if rp.layer != &"" else &"Walls"
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"FACADE"
		PlacementPriority.assign(p, table)
		plan.queue(p)
	return true


static func _mark8(state: LegacyPlacementState, pos: Vector2i, pos_next: Vector2i, with_crown: bool = true) -> void:
	for dy in ([-3, -2, -1, 0] if with_crown else [-2, -1, 0]):
		state.mark(pos + Vector2i(0, dy), &"FACADE")
		state.mark(pos_next + Vector2i(0, dy), &"FACADE")


static func try_place_legacy(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan,
	use_roots: bool,
	facade_cols: Dictionary,
	edges: Dictionary = {}
) -> bool:
	var pos := edge.pos
	var x := pos.x
	var y := pos.y
	var pos_next := Vector2i(x + 1, y)
	var grid := ctx.grid
	var table := ctx.priority_table

	var can_niche := false
	var is_in_portal: bool = ctx.portal_zone.has(pos + Vector2i(0, 1)) or ctx.portal_zone.has(pos_next + Vector2i(0, 1))

	if ctx.flags.enable_decorative_niches and not is_in_portal and facade_cols.has(x + 1) and facade_cols[x + 1].has(y):
		if state.get_category(pos_next) != &"FACADE":
			var left_has_same_y: bool = facade_cols.has(x - 1) and facade_cols[x - 1].has(y)
			var right_has_same_y: bool = facade_cols.has(x + 2) and facade_cols[x + 2].has(y)
			var left_down_wall: bool = not GridUtils.is_walkable(grid, Vector2i(x - 1, y + 1)) or (facade_cols.has(x - 1) and facade_cols[x - 1].has(y + 1))
			var right_down_wall: bool = not GridUtils.is_walkable(grid, Vector2i(x + 2, y + 1)) or (facade_cols.has(x + 2) and facade_cols[x + 2].has(y + 1))
			var front_is_walkable: bool = GridUtils.is_walkable(grid, Vector2i(x, y + 1)) and GridUtils.is_walkable(grid, Vector2i(x + 1, y + 1))
			var left_wall_clear: bool = GridUtils.is_walkable(grid, Vector2i(x - 2, y))
			var right_wall_clear: bool = GridUtils.is_walkable(grid, Vector2i(x + 3, y))

			if left_has_same_y and right_has_same_y and not left_down_wall and not right_down_wall and front_is_walkable and left_wall_clear and right_wall_clear:
				can_niche = true

	if not can_niche:
		return false

	var vid: StringName = &"A"
	var force_id: StringName = &"caves_roots" if use_roots else &""
	# Ściana o głębokości 3 nad którąś kolumną: rząd -3 to już jej szczyt — narożniki wewnętrzne korony
	# wycinałyby w nim ząbek. Taka nisza to przejście: moduł OUT bez korony (szczyt kładzie RimPlacer,
	# głębsza kolumna dostaje zwykłą koronę lica 3H), bez sekretnego pokoju. Kafle przejścia (OUT obu kolumn,
	# szczyt nad płytszą) dostają przy wstawianiu alternatywę PASSAGE_ALT — mark_passages.
	var depth_l := EdgeAnalyzer.measure_solid_depth(ctx, pos, Vector2i(0, -1))
	var depth_r := EdgeAnalyzer.measure_solid_depth(ctx, pos_next, Vector2i(0, -1))
	if depth_l <= 3 or depth_r <= 3:
		if ctx.tile_rng.randf() >= ctx.flags.passage_niche_spawn_chance:
			return false
		if not _place_niche(ctx, plan, pos, TileModuleRole.Id.NICHE_SECRET, vid, table, force_id, false):
			_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.MOD_CRNR_NE_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_TOP, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.MOD_CRNR_NE_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_MID, &"FACADE", table)
			_queue(plan, pos, CaveTileConstants.MOD_CRNR_NE_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_BASE, &"FACADE", table)
			_queue(plan, pos_next + Vector2i(0, -2), CaveTileConstants.MOD_CRNR_NW_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_TOP, &"FACADE", table)
			_queue(plan, pos_next + Vector2i(0, -1), CaveTileConstants.MOD_CRNR_NW_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_MID, &"FACADE", table)
			_queue(plan, pos_next, CaveTileConstants.MOD_CRNR_NW_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_BASE, &"FACADE", table)
		FacadePlacer.place_3h_crown(ctx, pos, state, plan, use_roots, edges)
		FacadePlacer.place_3h_crown(ctx, pos_next, state, plan, use_roots, edges)
		_mark8(state, pos, pos_next, false)
		for dy in [-2, -1, 0]:
			ctx.passage_cells[pos + Vector2i(0, dy)] = true
			ctx.passage_cells[pos_next + Vector2i(0, dy)] = true
		if depth_l == 3:
			ctx.passage_cells[pos + Vector2i(0, -3)] = true
		if depth_r == 3:
			ctx.passage_cells[pos_next + Vector2i(0, -3)] = true
		return true

	var can_place_out_niche := state.can_place_out_niche(pos)

	# 1. Nisza sekretna (para modułów OUT + OUT)
	if can_place_out_niche and ctx.tile_rng.randf() < ctx.flags.secret_niche_spawn_chance:
		if not _place_niche(ctx, plan, pos, TileModuleRole.Id.NICHE_SECRET, vid, table, force_id):
			var l_crown := CaveTileConstants.CRNR_SW_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SW_IN
			_queue(plan, pos + Vector2i(0, -3), l_crown, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.MOD_CRNR_NE_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_TOP, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.MOD_CRNR_NE_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_MID, &"FACADE", table)
			_queue(plan, pos, CaveTileConstants.MOD_CRNR_NE_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_OUT_BASE, &"FACADE", table)
			var r_crown := CaveTileConstants.CRNR_SE_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SE_IN
			_queue(plan, pos_next + Vector2i(0, -3), r_crown, &"FACADE", table)
			_queue(plan, pos_next + Vector2i(0, -2), CaveTileConstants.MOD_CRNR_NW_OUT_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_TOP, &"FACADE", table)
			_queue(plan, pos_next + Vector2i(0, -1), CaveTileConstants.MOD_CRNR_NW_OUT_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_MID, &"FACADE", table)
			_queue(plan, pos_next, CaveTileConstants.MOD_CRNR_NW_OUT_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_OUT_BASE, &"FACADE", table)
		_mark8(state, pos, pos_next)
		state.register_out_niche(pos)
		return true

	# 2. Nisza standardowa (para modułów IN + IN)
	if ctx.tile_rng.randf() < ctx.flags.niche_spawn_chance:
		if not _place_niche(ctx, plan, pos, TileModuleRole.Id.NICHE_STANDARD, vid, table, force_id):
			var l_crown := CaveTileConstants.CRNR_SW_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SW_IN
			_queue(plan, pos + Vector2i(0, -3), l_crown, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.MOD_CRNR_NE_IN_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_TOP, &"FACADE", table)
			_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.MOD_CRNR_NE_IN_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_MID, &"FACADE", table)
			_queue(plan, pos, CaveTileConstants.MOD_CRNR_NE_IN_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NE_IN_BASE, &"FACADE", table)
			var r_crown := CaveTileConstants.CRNR_SE_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SE_IN
			_queue(plan, pos_next + Vector2i(0, -3), r_crown, &"FACADE", table)
			_queue(plan, pos_next + Vector2i(0, -2), CaveTileConstants.MOD_CRNR_NW_IN_TOP if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_TOP, &"FACADE", table)
			_queue(plan, pos_next + Vector2i(0, -1), CaveTileConstants.MOD_CRNR_NW_IN_MID if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_MID, &"FACADE", table)
			_queue(plan, pos_next, CaveTileConstants.MOD_CRNR_NW_IN_BASE if not use_roots else CaveTileConstants.ROOT_MOD_CRNR_NW_IN_BASE, &"FACADE", table)
		_mark8(state, pos, pos_next)
		return true

	return false


## Oznacza kafle Walls nisz-przejść (po wszystkich placerach — szczyt kładzie RimPlacer).
static func mark_passages(ctx: GenerationContext, plan: TilePlacementPlan) -> void:
	if ctx.passage_cells.is_empty():
		return
	var cells: Dictionary = plan.get_placements(&"Walls")
	for pos in ctx.passage_cells:
		var p: TilePlacement = cells.get(pos)
		if p != null and not p.is_erase():
			p.passage = true
