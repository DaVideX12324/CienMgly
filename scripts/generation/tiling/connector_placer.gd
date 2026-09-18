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

static func _queue(plan: TilePlacementPlan, pos: Vector2i, atlas_coords: Vector2i, category: StringName, table: Dictionary) -> void:
	var p := TilePlacement.new()
	p.pos = pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
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

	if edge.orientation == EdgeKind.Orientation.EAST:
		_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.CONNECTOR_2H_TO_3H_TOP, &"CONNECTOR", table)
		_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.CONNECTOR_2H_TO_3H_MID, &"CONNECTOR", table)
		_queue(plan, pos, CaveTileConstants.CONNECTOR_2H_TO_3H_BASE, &"CONNECTOR", table)
	else:
		_queue(plan, pos + Vector2i(0, -2), CaveTileConstants.CONNECTOR_3H_TO_2H_TOP, &"CONNECTOR", table)
		_queue(plan, pos + Vector2i(0, -1), CaveTileConstants.CONNECTOR_3H_TO_2H_MID, &"CONNECTOR", table)
		_queue(plan, pos, CaveTileConstants.CONNECTOR_3H_TO_2H_BASE, &"CONNECTOR", table)

	state.mark(pos + Vector2i(0, -2), &"FACADE")
	state.mark(pos + Vector2i(0, -1), &"FACADE")
	state.mark(pos, &"FACADE")
