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
			if edge == null or edge.edge_kind != EdgeKind.Kind.INNER_CORNER or edge.is_protected_solid:
				continue

			if not state.is_empty_or_rock(pos):
				continue

			var wall_cells: Dictionary = plan.by_layer.get(&"Walls", {})
			var placement_under: TilePlacement = wall_cells.get(pos + Vector2i(0, 1))
			var tile_under: Vector2i = placement_under.atlas_coords if placement_under != null else Vector2i(-1, -1)

			var tile := Vector2i(-1, -1)

			match edge.orientation:
				EdgeKind.Orientation.NORTH_WEST:
					tile = Vector2i(1, 1)
				EdgeKind.Orientation.NORTH_EAST:
					tile = Vector2i(4, 1)
				EdgeKind.Orientation.SOUTH_WEST:
					if tile_under == CaveTileConstants.ROOT_MOD_CRNR_NE_IN_TOP:
						tile = CaveTileConstants.ROOT_CRNR_SW_IN
					else:
						tile = CaveTileConstants.CRNR_SW_IN
				EdgeKind.Orientation.SOUTH_EAST:
					if tile_under == CaveTileConstants.ROOT_MOD_CRNR_NW_IN_TOP:
						tile = CaveTileConstants.ROOT_CRNR_SE_IN
					else:
						tile = CaveTileConstants.CRNR_SE_IN

			if tile != Vector2i(-1, -1):
				_queue(plan, pos, tile, &"CORNER", table)
				state.mark(pos, &"CORNER")
