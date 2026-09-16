class_name CornerPlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeKind = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_kind.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const ThemeResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/theme_resolver.gd")
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


## Planuje wyłącznie diagonalne INNER_CORNER na podstawie klasyfikacji EdgeAnalyzer (SSOT).
static func plan(
	ctx: GenerationContext,
	edges: Dictionary,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var width := ctx.width
	var height := ctx.height
	var table := ctx.priority_table

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var edge: EdgeContext = edges.get(pos)
			if edge == null or edge.edge_kind != EdgeKind.Kind.INNER_CORNER or edge.is_protected_solid or edge.neighborhood_mask == 0:
				continue

			if not state.is_empty_or_rock(pos):
				continue

			var floor_sample := pos
			match edge.orientation:
				EdgeKind.Orientation.NORTH_WEST:
					floor_sample = pos + Vector2i(-1, -1)
				EdgeKind.Orientation.NORTH_EAST:
					floor_sample = pos + Vector2i(1, -1)
				EdgeKind.Orientation.SOUTH_WEST:
					floor_sample = pos + Vector2i(-1, 1)
				EdgeKind.Orientation.SOUTH_EAST:
					floor_sample = pos + Vector2i(1, 1)

			var use_roots: bool = ThemeResolver.resolve(ctx, floor_sample, ThemeResolver.RefPoint.SELF) == &"roots"
			var tile := Vector2i(-1, -1)

			match edge.orientation:
				EdgeKind.Orientation.NORTH_WEST:
					tile = Vector2i(1, 1) if not use_roots else Vector2i(1, 10)
				EdgeKind.Orientation.NORTH_EAST:
					tile = Vector2i(4, 1) if not use_roots else Vector2i(4, 10)
				EdgeKind.Orientation.SOUTH_WEST:
					tile = CaveTileConstants.CRNR_SW_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SW_IN
				EdgeKind.Orientation.SOUTH_EAST:
					tile = CaveTileConstants.CRNR_SE_IN if not use_roots else CaveTileConstants.ROOT_CRNR_SE_IN

			if tile != Vector2i(-1, -1):
				_queue(plan, pos, tile, &"CORNER", table)
				state.mark(pos, &"CORNER")
