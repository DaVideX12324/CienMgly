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


## Ścieżka modułowa (1 kafel, kategoria CORNER, tie_breaker=0 jak legacy). true jeśli położono.
static func _try_corner(ctx: GenerationContext, plan: TilePlacementPlan, pos: Vector2i, module_role: TileModuleRole.Id, variant_id: StringName, table: Dictionary, force_id: StringName = &"") -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, pos, module_role, [], -1, variant_id, force_id)
	if parts.is_empty():
		return false
	for rp in parts:
		var p := TilePlacement.new()
		p.pos = pos + rp.offset
		p.layer = rp.layer if rp.layer != &"" else &"Walls"
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"CORNER"
		PlacementPriority.assign(p, table)
		plan.queue(p)
	return true


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
			var module_role: int = TileModuleRole.Id.NONE
			var variant_id: StringName = &"A"
			var force_id: StringName = &""

			match edge.orientation:
				EdgeKind.Orientation.NORTH_WEST:
					tile = Vector2i(1, 1)
					module_role = TileModuleRole.Id.INNER_CORNER_NW
				EdgeKind.Orientation.NORTH_EAST:
					tile = Vector2i(4, 1)
					module_role = TileModuleRole.Id.INNER_CORNER_NE
				EdgeKind.Orientation.SOUTH_WEST:
					module_role = TileModuleRole.Id.INNER_CORNER_SW
					if tile_under == CaveTileConstants.ROOT_MOD_CRNR_NE_IN_TOP:
						tile = CaveTileConstants.ROOT_CRNR_SW_IN
						force_id = &"caves_roots"
					else:
						tile = CaveTileConstants.CRNR_SW_IN
				EdgeKind.Orientation.SOUTH_EAST:
					module_role = TileModuleRole.Id.INNER_CORNER_SE
					if tile_under == CaveTileConstants.ROOT_MOD_CRNR_NW_IN_TOP:
						tile = CaveTileConstants.ROOT_CRNR_SE_IN
						force_id = &"caves_roots"
					else:
						tile = CaveTileConstants.CRNR_SE_IN

			if tile != Vector2i(-1, -1):
				if not _try_corner(ctx, plan, pos, module_role, variant_id, table, force_id):
					_queue(plan, pos, tile, &"CORNER", table)
				state.mark(pos, &"CORNER")
