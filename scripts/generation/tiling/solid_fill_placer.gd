class_name SolidFillPlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const LegacyTileHash = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_tile_hash.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")
const TileResolver = preload("res://modules/quiz_rpg/scripts/generation/tiles/tile_resolver.gd")
const TileModuleRole = preload("res://modules/quiz_rpg/scripts/generation/tiles/tile_module_role.gd")

## Planuje wypełnienie pustki poza mapą oraz litej skały wewnątrz mapy.
static func plan(
	ctx: GenerationContext,
	edges: Dictionary,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var width := ctx.width
	var height := ctx.height
	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})

	# Krok A: Tło litej skały poza granicami logicznej siatki (-4..width+4, -4..height+4)
	for y in range(-4, height + 4):
		for x in range(-4, width + 4):
			var pos := Vector2i(x, y)
			var outside: bool = (pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height)
			if outside:
				var p := TilePlacement.new()
				p.pos = pos
				p.layer = &"Walls"
				p.atlas_coords = CaveTileConstants.WALL_INSIDE
				p.category = &"SOLID_FILL"
				PlacementPriority.assign(p, table)
				plan.queue(p)

	# Krok B: Właściwe komórki litej skały w granicach mapy
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if GridUtils.is_walkable(ctx.grid, pos):
				continue
			# Legacy roll 0..99 służy jako deterministyczny wybór wariantu (progi 45/92).
			# Ten sam roll trafia do resolvera -> jeśli SOLID_FILL ma warianty A/B/C o wagach
			# 45/47/8, wynik jest 1:1 z legacy. Bez profilu -> stara logika progów.
			var roll := LegacyTileHash.rock_fill_roll(pos, ctx.seed_value)
			var parts := TileResolver.resolve_module_parts(ctx, pos, TileModuleRole.Id.SOLID_FILL, [], roll)

			var p := TilePlacement.new()
			p.pos = pos
			p.layer = &"Walls"
			p.category = &"SOLID_FILL"
			if parts.is_empty():
				var coords := CaveTileConstants.WALL_INSIDE_ALT
				if roll < 45:
					coords = CaveTileConstants.WALL_INSIDE
				elif roll < 92:
					coords = CaveTileConstants.WALL_INSIDE_ALT
				else:
					coords = CaveTileConstants.WALL_INSIDE_ALT2
				p.atlas_coords = coords
			else:
				var rp = parts[0]
				p.source_id = rp.tile.source_id
				p.atlas_coords = rp.tile.atlas_coords
				p.alternative_tile = rp.tile.alternative_tile
			PlacementPriority.assign(p, table)
			plan.queue(p)
			state.mark(pos, &"ROCK")
