class_name SlopePlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const EdgeKind = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_kind.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")

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


static func place(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var pos := edge.pos
	var table := ctx.priority_table

	if edge.orientation == EdgeKind.Orientation.WEST:
		_queue(plan, pos, CaveTileConstants.WALL_2H_SLOPE_LEFT_BASE, &"FACADE", table, pos)
		_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_SLOPE_LEFT_MID, &"FACADE", table, pos)
		_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.WALL_2H_SLOPE_LEFT_TOP, &"FACADE", table, pos)
	else:
		_queue(plan, pos, CaveTileConstants.WALL_2H_SLOPE_RIGHT_BASE, &"FACADE", table, pos)
		_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.WALL_2H_SLOPE_RIGHT_MID, &"FACADE", table, pos)
		_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.WALL_2H_SLOPE_RIGHT_TOP, &"FACADE", table, pos)

	state.mark(pos, &"FACADE")
	state.mark(pos + Vector2i(0, -1), &"FACADE")
	state.mark(pos + Vector2i(0, -2), &"FACADE")
