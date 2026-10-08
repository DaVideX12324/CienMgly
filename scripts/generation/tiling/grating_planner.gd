extends RefCounted

## Kratownice w posadzce (tiling.grating w companion-JSON): prostokąty terenu `terrain` (terrain_set 0) na
## podłodze kompleksów i pokoi (canals.areas), rozmiary losowane z `sizes` ([w, h]), liczba `per_1000` na 1000
## kratek tych obszarów. Prostokąt + `margin` kratek dookoła musi leżeć na podłodze bez wody, chodników,
## korytarzy serwisowych, kładek z prześwitem, barierek, portali i ścian szer. 1; odstęp `spacing` od innych.
## Teren malowany na Floor po podłodze (maska = sam prostokąt — krawędzie kratownicy na jego obwodzie).
##
## JSON: "grating": {"terrain": 5, "per_1000": 1.5, "sizes": [[2, 2], [3, 2], [4, 3], [6, 3]], "margin": 1, "spacing": 4}


static func plan(ctx: GenerationContext, terrain: TerrainPaintPlan) -> void:
	var cfg: Dictionary = ctx.generator_behaviour.get("tiling", {}).get("grating", {})
	var canals = ctx.canals
	if cfg.is_empty() or canals == null or not "areas" in canals or canals.areas.is_empty():
		return
	var t_idx := int(cfg.get("terrain", -1))
	if t_idx < 0:
		return
	var sizes: Array = cfg.get("sizes", [[2, 2], [4, 3]])
	var margin := int(cfg.get("margin", 1))
	var spacing := int(cfg.get("spacing", 4))
	var bad := {}
	for d in [canals.water, canals.lanes, canals.service, canals.crossing_cells, canals.bridge_clearance,
			canals.rail_cells, canals.walls_1w, ctx.portal_zone]:
		bad.merge(d)
	var cands: Array[Vector2i] = []
	for p: Vector2i in canals.areas:
		var a := String(canals.areas[p])
		if (a.begins_with("hall:") or a.begins_with("room:")) and not bad.has(p) and GridUtils.is_walkable(ctx.grid, p):
			cands.append(p)
	cands.sort()
	var target := int(cands.size() * float(cfg.get("per_1000", 1.5)) / 1000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "grating"])
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var placed: Array[Rect2i] = []
	for p in cands:
		if placed.size() >= target:
			break
		var sz: Array = sizes[rng.randi() % sizes.size()]
		var r := Rect2i(p, Vector2i(int(sz[0]), int(sz[1])))
		if _fits(ctx, canals, bad, r, margin, placed, spacing):
			placed.append(r)
	for r in placed:
		var cells: Array[Vector2i] = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				cells.append(Vector2i(x, y))
		terrain.add_batch(&"Floor", cells, 0, t_idx, 2, true, cells)


static func _fits(ctx: GenerationContext, canals, bad: Dictionary, r: Rect2i, margin: int, placed: Array[Rect2i], spacing: int) -> bool:
	for q in placed:
		if q.grow(spacing).intersects(r):
			return false
	var g := r.grow(margin)
	for y in range(g.position.y, g.end.y):
		for x in range(g.position.x, g.end.x):
			var c := Vector2i(x, y)
			if bad.has(c) or not canals.areas.has(c) or not GridUtils.is_walkable(ctx.grid, c):
				return false
	return true
