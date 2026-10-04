class_name SolidFillPlacer
extends RefCounted

const GenProgress = preload("../core/gen_progress.gd")


## Planuje wypełnienie pustki poza mapą oraz litej skały wewnątrz mapy.
static func plan(
	ctx: GenerationContext,
	_edges: Dictionary,
	state: LegacyPlacementState,
	placement_plan: TilePlacementPlan
) -> void:
	var width := ctx.width
	var height := ctx.height
	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})

	# Krok A: Tło litej skały poza granicami logicznej siatki (-4..width+4, -4..height+4).
	# Kafel = wariant A roli SOLID_FILL zestawu domyślnego (w caves A = WALL_INSIDE), bez profilu stała.
	var outside_t := CaveTileConstants.WALL_INSIDE
	var outside_parts: Array = TileResolver.resolve_module_parts(ctx, Vector2i(-1, -1), TileModuleRole.Id.SOLID_FILL, [], -1, &"A")
	if not outside_parts.is_empty():
		outside_t = outside_parts[0].tile.atlas_coords
	for y in range(-4, height + 4):
		if y % 16 == 0:
			GenProgress.sub_in(&"rock", 0.3 * (y + 4) / float(height + 8))
		for x in range(-4, width + 4):
			var pos := Vector2i(x, y)
			var outside: bool = (pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height)
			if outside:
				var p := TilePlacement.new()
				p.pos = pos
				p.layer = &"Walls"
				p.atlas_coords = outside_t
				p.category = &"SOLID_FILL"
				PlacementPriority.assign(p, table)
				placement_plan.queue(p)

	# Krok B: Właściwe komórki litej skały w granicach mapy
	# Wynik resolvera zależy tu tylko od (zestaw kratki, roll) — cache zamiast wywołania na kratkę.
	var resolver_on := TileResolver.is_active(ctx)
	var cache := {}  # zestaw -> Array[100] części (null = jeszcze nie liczone)
	for y in range(height):
		if y % 16 == 0:
			GenProgress.sub_in(&"rock", 0.3 + 0.7 * y / float(height))
		for x in range(width):
			var pos := Vector2i(x, y)
			if GridUtils.is_walkable(ctx.grid, pos):
				continue
			# Legacy roll 0..99 służy jako deterministyczny wybór wariantu (progi 45/92).
			# Ten sam roll trafia do resolvera -> jeśli SOLID_FILL ma warianty A/B/C o wagach
			# 45/47/8, wynik jest 1:1 z legacy. Bez profilu -> stara logika progów.
			var roll := LegacyTileHash.rock_fill_roll(pos, ctx.seed_value)
			var parts: Array = []
			if resolver_on:
				var set_id := TileResolver.own_tileset_id(ctx, pos)
				var per_roll: Array = cache.get(set_id, [])
				if per_roll.is_empty():
					per_roll.resize(100)
					cache[set_id] = per_roll
				if per_roll[roll] == null:
					per_roll[roll] = TileResolver.resolve_module_parts(ctx, pos, TileModuleRole.Id.SOLID_FILL, [], roll)
				parts = per_roll[roll]

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
			placement_plan.queue(p)
			state.mark(pos, &"ROCK")
