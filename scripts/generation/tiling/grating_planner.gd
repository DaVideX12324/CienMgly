extends RefCounted

## Kratownice w posadzce (tiling.grating w companion-JSON): plamy terenu `terrain` (terrain_set 0) na podłodze
## kompleksów i pokoi (canals.areas) — prostokąt z `sizes` ([w, h]), z szansą `shape_chance` suma dwóch
## nachodzących prostokątów (L / T / krzyż); liczba `per_1000` na 1000 kratek tych obszarów. Kratownica + `margin`
## kratek dookoła (odstęp od ściany i krawędzi podłogi) musi leżeć na podłodze bez wody, chodników,
## korytarzy serwisowych, kładek z prześwitem, barierek, portali i ścian szer. 1; odstęp `spacing` od innych.
## Teren malowany na Floor po podłodze (maska = sama kratownica — krawędzie na jej obwodzie).
##
## JSON: "grating": {"terrain": 5, "per_1000": 1.5, "sizes": [[2, 2], [3, 2], [4, 3], [6, 3]], "shape_chance": 0.6,
##        "margin": 1, "spacing": 4}


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
	var shape_chance := float(cfg.get("shape_chance", 0.6))
	var placed: Array[Rect2i] = []  # obrysy (bbox) postawionych kratownic
	for p in cands:
		if placed.size() >= target:
			break
		# kształt: prostokąt albo suma dwóch nachodzących prostokątów (L / T / krzyż / schodek)
		var sz: Array = sizes[rng.randi() % sizes.size()]
		var r1 := Rect2i(p, Vector2i(int(sz[0]), int(sz[1])))
		var cells := _rect_cells(r1)
		if rng.randf() < shape_chance:
			var sz2: Array = sizes[rng.randi() % sizes.size()]
			var s2 := Vector2i(int(sz2[1]), int(sz2[0])) if rng.randi() % 2 == 0 else Vector2i(int(sz2[0]), int(sz2[1]))
			var off := Vector2i(rng.randi_range(-(s2.x - 1), r1.size.x - 1), rng.randi_range(-(s2.y - 1), r1.size.y - 1))
			for c in _rect_cells(Rect2i(r1.position + off, s2)):
				cells[c] = true
		var bbox := Rect2i(cells.keys()[0], Vector2i.ONE)
		for c: Vector2i in cells:
			bbox = bbox.expand(c).expand(c + Vector2i.ONE)
		if _fits(ctx, canals, bad, cells, bbox, margin, placed, spacing):
			placed.append(bbox)
			var arr: Array[Vector2i] = []
			for c: Vector2i in cells:
				arr.append(c)
			arr.sort()
			terrain.add_batch(&"Floor", arr, 0, t_idx, 2, true, arr)


static func _rect_cells(r: Rect2i) -> Dictionary:
	var out := {}
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out[Vector2i(x, y)] = true
	return out


## Kratownica + `margin` kratek dookoła każdej jej kratki na podłodze kompleksu / pokoju bez przeszkód (odstęp od ściany
## i krawędzi podłogi), obrys z dala o `spacing` od innych kratownic.
static func _fits(ctx: GenerationContext, canals, bad: Dictionary, cells: Dictionary, bbox: Rect2i, margin: int, placed: Array[Rect2i], spacing: int) -> bool:
	for q in placed:
		if q.grow(spacing).intersects(bbox):
			return false
	var seen := {}
	for c0: Vector2i in cells:
		for dy in range(-margin, margin + 1):
			for dx in range(-margin, margin + 1):
				var c := c0 + Vector2i(dx, dy)
				if seen.has(c):
					continue
				seen[c] = true
				if bad.has(c) or not canals.areas.has(c) or not GridUtils.is_walkable(ctx.grid, c):
					return false
	return true
