class_name ConnectorPlacer
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

static func _queue(plan: TilePlacementPlan, pos: Vector2i, atlas_coords: Vector2i, category: StringName, table: Dictionary) -> void:
	var p := TilePlacement.new()
	p.pos = pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Ścieżka modułowa (tie_breaker = 0 jak legacy connector). true jeśli coś położono.
static func _try_module(ctx: GenerationContext, plan: TilePlacementPlan, anchor: Vector2i, module_role: TileModuleRole.Id, table: Dictionary) -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, anchor, module_role)
	if parts.is_empty():
		return false
	for rp in parts:
		var p := TilePlacement.new()
		p.pos = anchor + rp.offset
		p.layer = rp.layer if rp.layer != &"" else &"Walls"
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"CONNECTOR"
		PlacementPriority.assign(p, table)
		plan.queue(p)
	return true


static func place(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var pos := edge.pos
	var x := pos.x
	var y := pos.y
	var grid := ctx.grid
	var table := ctx.priority_table

	var check_2h_col := func(cx: int, fy: int) -> bool:
		return GridUtils.is_walkable(grid, Vector2i(cx, fy)) \
			and not GridUtils.is_walkable(grid, Vector2i(cx, fy - 1)) \
			and not GridUtils.is_walkable(grid, Vector2i(cx, fy - 2)) \
			and GridUtils.is_walkable(grid, Vector2i(cx, fy - 3))

	var left_is_2h_same: bool = check_2h_col.call(x - 1, y)
	var right_is_2h_same: bool = check_2h_col.call(x + 1, y)
	var right_has_room_for_3h: bool = not check_2h_col.call(x + 1, y) and not check_2h_col.call(x + 2, y) and not check_2h_col.call(x + 3, y)
	var left_has_room_for_3h: bool = not check_2h_col.call(x - 1, y) and not check_2h_col.call(x - 2, y) and not check_2h_col.call(x - 3, y)
	var right_is_2h_step: bool = check_2h_col.call(x + 1, y - 1)
	var left_is_2h_step: bool = check_2h_col.call(x - 1, y - 1)

	var left_is_2h_any := left_is_2h_same or left_is_2h_step
	var right_is_2h_any := right_is_2h_same or right_is_2h_step

	# Anchor = stopa; części: base @ (0,0), mid @ (0,-1), top @ (0,-2).
	if (left_is_2h_any and right_has_room_for_3h) or (left_is_2h_any and not right_is_2h_any):
		if not _try_module(ctx, plan, pos, TileModuleRole.Id.CONNECTOR_LEFT, table):
			_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.CONNECTOR_2H_TO_3H_TOP, &"CONNECTOR", table)
			_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.CONNECTOR_2H_TO_3H_MID, &"CONNECTOR", table)
			_queue(plan, pos, CaveTileConstants.CONNECTOR_2H_TO_3H_BASE, &"CONNECTOR", table)
		state.mark(pos + Vector2i(0, -2), &"FACADE")
		state.mark(pos + Vector2i(0, -1), &"FACADE")
		state.mark(pos, &"FACADE")
	elif (right_is_2h_any and left_has_room_for_3h) or (right_is_2h_any and not left_is_2h_any):
		if not _try_module(ctx, plan, pos, TileModuleRole.Id.CONNECTOR_RIGHT, table):
			_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.CONNECTOR_3H_TO_2H_TOP, &"CONNECTOR", table)
			_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.CONNECTOR_3H_TO_2H_MID, &"CONNECTOR", table)
			_queue(plan, pos, CaveTileConstants.CONNECTOR_3H_TO_2H_BASE, &"CONNECTOR", table)
		state.mark(pos + Vector2i(0, -2), &"FACADE")
		state.mark(pos + Vector2i(0, -1), &"FACADE")
		state.mark(pos, &"FACADE")
