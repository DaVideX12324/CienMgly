class_name FacadePlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")
const TileResolver = preload("res://modules/quiz_rpg/scripts/generation/tiles/tile_resolver.gd")
const TileModuleRole = preload("res://modules/quiz_rpg/scripts/generation/tiles/tile_module_role.gd")

static func _get_variant_noise(ctx: GenerationContext) -> FastNoiseLite:
	if ctx.variant_noise != null:
		return ctx.variant_noise
	var n := FastNoiseLite.new()
	n.seed = ctx.seed_value + 777
	n.frequency = 0.45
	ctx.variant_noise = n
	return n


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
	p.tie_breaker = 10 if (origin == Vector2i.ZERO or target_pos.x == origin.x) else 1
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Kolejkuje część modułu (z resolvera) zachowując konwencję tie_breaker jak _queue.
static func _queue_part(
	plan: TilePlacementPlan,
	target_pos: Vector2i,
	rp,
	category: StringName,
	table: Dictionary,
	origin: Vector2i = Vector2i.ZERO
) -> void:
	var p := TilePlacement.new()
	p.pos = target_pos
	p.layer = rp.layer if rp.layer != &"" else &"Walls"
	p.source_id = rp.tile.source_id
	p.atlas_coords = rp.tile.atlas_coords
	p.alternative_tile = rp.tile.alternative_tile
	p.category = category
	p.origin = origin
	p.tie_breaker = 10 if (origin == Vector2i.ZERO or target_pos.x == origin.x) else 1
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Próbuje ścieżki modułowej (wymuszony wariant). Zwraca true, jeśli coś położono.
static func _try_module(
	ctx: GenerationContext,
	plan: TilePlacementPlan,
	anchor: Vector2i,
	module_role: TileModuleRole.Id,
	variant_id: StringName,
	table: Dictionary
) -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, anchor, module_role, [], -1, variant_id)
	if parts.is_empty():
		return false
	for rp in parts:
		_queue_part(plan, anchor + rp.offset, rp, &"FACADE", table)
	return true


## Stawia prostą fasadę o wysokości 2 kratek (2H). Zawsze motyw rock.
static func place_2h(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var pos := edge.pos
	var grid := ctx.grid
	var table := ctx.priority_table

	var is_west_end: bool = GridUtils.is_walkable(grid, pos + Vector2i(-1, -1)) or GridUtils.is_walkable(grid, pos + Vector2i(-1, -2))
	var is_east_end: bool = GridUtils.is_walkable(grid, pos + Vector2i(1, -1)) or GridUtils.is_walkable(grid, pos + Vector2i(1, -2))

	# Wariant wyznaczany geometrią (końce WEST/EAST) lub A/B z variant_noise — identycznie
	# jak legacy. Ścieżka modułowa dostaje wymuszony wariant; bez profilu -> stałe.
	var variant_id: StringName
	var top_2h := Vector2i.ZERO
	var base_2h := Vector2i.ZERO

	if is_west_end and not is_east_end:
		variant_id = &"WEST"
		top_2h = CaveTileConstants.WALL_2H_WEST_TOP
		base_2h = CaveTileConstants.WALL_2H_WEST_BASE
	elif is_east_end and not is_west_end:
		variant_id = &"EAST"
		top_2h = CaveTileConstants.WALL_2H_EAST_TOP
		base_2h = CaveTileConstants.WALL_2H_EAST_BASE
	else:
		var v_noise := _get_variant_noise(ctx)
		var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
		variant_id = &"B" if is_b else &"A"
		top_2h = CaveTileConstants.WALL_2H_TOP[1] if is_b else CaveTileConstants.WALL_2H_TOP[0]
		base_2h = CaveTileConstants.WALL_2H_BASE[1] if is_b else CaveTileConstants.WALL_2H_BASE[0]

	# Anchor = stopa (pos): część base @ (0,0), top @ (0,-1).
	if not _try_module(ctx, plan, pos, TileModuleRole.Id.FACADE_2H, variant_id, table):
		_queue(plan, pos, base_2h, &"FACADE", table)
		_queue(plan, pos + Vector2i(0, -1), top_2h, &"FACADE", table)
	state.mark(pos, &"FACADE")
	state.mark(pos + Vector2i(0, -1), &"FACADE")


## Stawia standardową prostą fasadę o wysokości 3 kratek (3H) z koroną.
static func place_3h(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan,
	use_roots: bool,
	left_y: int = -1,
	right_y: int = -1,
	edges: Dictionary = {}
) -> void:
	var pos := edge.pos
	var grid := ctx.grid
	var table := ctx.priority_table
	var v_noise := _get_variant_noise(ctx)

	var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
	var top_t := CaveTileConstants.WALL_BOTTOM_TOP[1] if is_b else CaveTileConstants.WALL_BOTTOM_TOP[0]
	var mid_t := CaveTileConstants.WALL_BOTTOM_MID[1] if is_b else CaveTileConstants.WALL_BOTTOM_MID[0]
	var base_t := CaveTileConstants.WALL_BOTTOM_BASE[1] if is_b else CaveTileConstants.WALL_BOTTOM_BASE[0]
	if use_roots:
		top_t = CaveTileConstants.ROOT_BOTTOM_TOP[1] if is_b else CaveTileConstants.ROOT_BOTTOM_TOP[0]
		mid_t = CaveTileConstants.ROOT_BOTTOM_MID[1] if is_b else CaveTileConstants.ROOT_BOTTOM_MID[0]
		base_t = CaveTileConstants.ROOT_BOTTOM_BASE[1] if is_b else CaveTileConstants.ROOT_BOTTOM_BASE[0]

	var p_crown := pos + Vector2i(0, -3)
	var has_floor_above := GridUtils.is_walkable(grid, p_crown + Vector2i(0, -1))
	var edge_crown: EdgeContext = edges.get(p_crown) if not edges.is_empty() else null
	var crown_free: bool = edge_crown == null or edge_crown.edge_kind == EdgeKind.Kind.SOLID_FILL or edge_crown.edge_kind == EdgeKind.Kind.NONE
	if not has_floor_above and not GridUtils.is_walkable(grid, p_crown) and crown_free and state.is_empty_or_rock(p_crown):
		var crown_t := Vector2i(3, 4) if is_b else Vector2i(2, 4)
		if use_roots:
			crown_t = Vector2i(3, 13) if is_b else Vector2i(2, 13)
		_queue(plan, p_crown, crown_t, &"CORNER", table, pos)
		state.mark(p_crown, &"CORNER")

	# Wariant zależny od motywu (roots) + A/B z variant_noise — jak legacy. Anchor = stopa;
	# base @ (0,0), mid @ (0,-1), top @ (0,-2). Korona wyżej zostaje osobnym CORNER-em.
	var variant_id: StringName
	if use_roots:
		variant_id = &"ROOT_B" if is_b else &"ROOT_A"
	else:
		variant_id = &"B" if is_b else &"A"
	if not _try_module(ctx, plan, pos, TileModuleRole.Id.FACADE_3H, variant_id, table):
		_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table)
		_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table)
		_queue(plan, pos, base_t, &"FACADE", table)

	state.mark(pos + Vector2i(0, -2), &"FACADE")
	state.mark(pos + Vector2i(0, -1), &"FACADE")
	state.mark(pos, &"FACADE")
