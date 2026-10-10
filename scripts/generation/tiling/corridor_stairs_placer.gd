extends RefCounted

## Kafle korytarzy-schodów (canals.stair_corridors, StructuredStairs) na warstwie Platforms: stopnie modułu schodów
## platform (generator_behaviour.platform_tiles.stairs: kolumny poręcz, L, M, R, poręcz; rzędy góra / środek / dół) —
## bez poręczy, bo korytarz ma ściany. Kolumny: 1 -> M, 2 -> L R, więcej -> L M… R; rzędy: górny rząd korytarza = góra
## modułu, dolny = dół, pomiędzy powtarzany środek.

const LAYER := &"Platforms"


static func plan(ctx: GenerationContext, tiles: TilePlacementPlan) -> void:
	var canals = ctx.canals
	if canals == null or not "stair_corridors" in canals or canals.stair_corridors.is_empty():
		return
	var cfg: Dictionary = ctx.generator_behaviour.get("platform_tiles", {}).get("stairs", {})
	if cfg.is_empty():
		push_warning("CorridorStairsPlacer: brak platform_tiles.stairs — korytarze-schody bez kafli")
		return
	var src := int(cfg.get("source", 0))
	var org: Array = cfg.get("origin", [0, 0])
	var sz: Array = cfg.get("size", [5, 3])
	var o := Vector2i(int(org[0]), int(org[1]))
	var last_col := int(sz[0]) - 2   # kolumna R (przed prawą poręczą)
	var last_row := int(sz[1]) - 1
	var table: Dictionary = ctx.priority_table
	if table.is_empty():
		table = PlacementPriority.get_table(&"legacy_facade_wins", {})
	for sc in canals.stair_corridors:
		var r: Rect2i = sc.rect
		for y in range(r.position.y, r.end.y):
			var row := 0 if y == r.position.y else (last_row if y == r.end.y - 1 else 1)
			for x in range(r.position.x, r.end.x):
				var col := 2
				if r.size.x >= 2 and x == r.position.x:
					col = 1
				elif r.size.x >= 2 and x == r.end.x - 1:
					col = last_col
				var p := TilePlacement.new()
				p.pos = Vector2i(x, y)
				p.layer = LAYER
				p.source_id = src
				p.atlas_coords = o + Vector2i(col, row)
				p.category = &"STAIR"
				p.origin = r.position
				p.tie_breaker = 10
				PlacementPriority.assign(p, table)
				tiles.queue(p)
