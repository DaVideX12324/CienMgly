class_name SideWallPlacer
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


static func _variant_id(use_roots: bool, var_idx: int) -> StringName:
	if use_roots:
		return &"ROOT_B" if var_idx == 1 else &"ROOT_A"
	return &"B" if var_idx == 1 else &"A"


## Ścieżka modułowa dla ściany bocznej (1 kafel, wymuszony wariant). true jeśli położono.
static func _try_side(ctx: GenerationContext, plan: TilePlacementPlan, pos: Vector2i, module_role: TileModuleRole.Id, variant_id: StringName, table: Dictionary) -> bool:
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
		p.category = &"SIDE_WALL"
		PlacementPriority.assign(p, table)
		plan.queue(p)
	return true


## Planuje pionowe ściany boczne (WEST i EAST) na podstawie klasyfikacji EdgeAnalyzer (SSOT).
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
			if edge == null or edge.edge_kind != EdgeKind.Kind.SIDE_WALL:
				continue

			if not state.is_empty_or_rock(pos):
				continue

			var edge_above: EdgeContext = edges.get(pos + Vector2i(0, -1))
			var is_under_inner_corner: bool = (edge_above != null and edge_above.edge_kind == EdgeKind.Kind.INNER_CORNER)

			# var_idx (A/B) z ctx.tile_rng jest kolejność-zależny: placer MUSI konsumować
			# RNG identycznie jak legacy i wymusić wybrany wariant w resolverze.
			if edge.orientation == EdgeKind.Orientation.EAST:
				var use_roots_side: bool = ThemeResolver.resolve(ctx, pos + Vector2i(1, 0), ThemeResolver.RefPoint.SELF) == &"roots"
				var var_idx: int = 1 if is_under_inner_corner else (ctx.tile_rng.randi() % 2)
				if not _try_side(ctx, plan, pos, TileModuleRole.Id.SIDE_WALL_EAST, _variant_id(use_roots_side, var_idx), table):
					var side_t: Vector2i = CaveTileConstants.WALL_SIDE_WEST[var_idx] if not use_roots_side else CaveTileConstants.ROOT_WALL_SIDE_WEST[var_idx]
					_queue(plan, pos, side_t, &"SIDE_WALL", table)
				state.mark(pos, &"SIDE")

			elif edge.orientation == EdgeKind.Orientation.WEST:
				var use_roots_side: bool = ThemeResolver.resolve(ctx, pos + Vector2i(-1, 0), ThemeResolver.RefPoint.SELF) == &"roots"
				var var_idx: int = 1 if is_under_inner_corner else (ctx.tile_rng.randi() % 2)
				if not _try_side(ctx, plan, pos, TileModuleRole.Id.SIDE_WALL_WEST, _variant_id(use_roots_side, var_idx), table):
					var side_t: Vector2i = CaveTileConstants.WALL_SIDE_EAST[var_idx] if not use_roots_side else CaveTileConstants.ROOT_WALL_SIDE_EAST[var_idx]
					_queue(plan, pos, side_t, &"SIDE_WALL", table)
				state.mark(pos, &"SIDE")
