class_name PlateauPlacer
extends RefCounted

const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")
const TileResolver = preload("res://modules/quiz_rpg/scripts/generation/tiles/tile_resolver.gd")
const TileModuleRole = preload("res://modules/quiz_rpg/scripts/generation/tiles/tile_module_role.gd")
const PlateauRenderer = preload("res://modules/quiz_rpg/scripts/generation/tiling/plateau_renderer.gd")

## Kafle płaskowyżów na warstwie Platforms: kształt z PlateauRenderera (pipeline ścian w trybie
## płaskowyżu), potem schody [LEFT][MID…][RIGHT] w miejscu lica (kategoria STAIR > FACADE).
## Musi iść PO ścianach — PlateauRenderer dzieli prawdziwe ściany na krawędzie i void z planu Walls.

const LAYER := &"Platforms"


static func plan(ctx: GenerationContext, plan: TilePlacementPlan) -> void:
	if ctx.plateau == null or ctx.plateau.is_empty() or ctx.map_tile_profile == null:
		return
	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})

	var res: Dictionary = PlateauRenderer.render(ctx, ctx.plateau.mask, plan.by_layer.get(&"Walls", {}))
	if int(res.missing) > 0:
		push_warning("PlateauPlacer: %d kafli bez roli w '%s' (pominięte)" % [res.missing, PlateauRenderer.TILESET_ID])
	for pos in res.tiles:
		var src: TilePlacement = res.tiles[pos]
		var p := TilePlacement.new()
		p.pos = pos
		p.layer = LAYER
		p.source_id = src.source_id
		p.atlas_coords = src.atlas_coords
		p.alternative_tile = src.alternative_tile
		p.category = src.category
		p.origin = src.origin
		p.tie_breaker = src.tie_breaker
		PlacementPriority.assign(p, table)
		plan.queue(p)

	for st in ctx.plateau.stairs:
		if st.y == 1:
			_put_stair(ctx, plan, Vector2i(st.x, st.z + 1), TileModuleRole.Id.STAIR_SINGLE, table)
		else:
			for x in range(st.x, st.x + st.y):
				var role: int = TileModuleRole.Id.STAIR_MID
				if x == st.x:
					role = TileModuleRole.Id.STAIR_LEFT
				elif x == st.x + st.y - 1:
					role = TileModuleRole.Id.STAIR_RIGHT
				_put_stair(ctx, plan, Vector2i(x, st.z + 1), role, table)

	for st in ctx.plateau.stairs_north:
		if st.y == 1:
			_put_stair(ctx, plan, Vector2i(st.x, st.z), TileModuleRole.Id.STAIR_NORTH_SINGLE, table)
		else:
			for x in range(st.x, st.x + st.y):
				var role: int = TileModuleRole.Id.STAIR_NORTH_MID
				if x == st.x:
					role = TileModuleRole.Id.STAIR_NORTH_LEFT
				elif x == st.x + st.y - 1:
					role = TileModuleRole.Id.STAIR_NORTH_RIGHT
				_put_stair(ctx, plan, Vector2i(x, st.z), role, table)

	for st in ctx.plateau.stairs_east:
		var role: int = TileModuleRole.Id.STAIR_EAST_1H if st.z == 1 else TileModuleRole.Id.STAIR_EAST_3H
		_put_stair(ctx, plan, Vector2i(st.x, st.y), role, table)

	for st in ctx.plateau.stairs_west:
		var role: int = TileModuleRole.Id.STAIR_WEST_1H if st.z == 1 else TileModuleRole.Id.STAIR_WEST_3H
		_put_stair(ctx, plan, Vector2i(st.x, st.y), role, table)


static func _put_stair(ctx: GenerationContext, plan: TilePlacementPlan, anchor: Vector2i, role: int, table: Dictionary) -> void:
	var parts := TileResolver.resolve_strict(ctx, PlateauRenderer.TILESET_ID, anchor, role)
	if parts.is_empty():
		push_warning("PlateauPlacer: brak %s w '%s'" % [TileModuleRole.name_of(role), PlateauRenderer.TILESET_ID])
		return
	for rp in parts:
		var p := TilePlacement.new()
		p.pos = anchor + rp.offset
		p.layer = LAYER
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"STAIR"
		p.origin = anchor
		p.tie_breaker = 10
		PlacementPriority.assign(p, table)
		plan.queue(p)
