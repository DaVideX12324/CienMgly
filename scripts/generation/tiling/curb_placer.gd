extends RefCounted

## Krawężniki na progach (tiling.curbs_enabled): granica kratki korytarza (canals.areas == "corridor", bez chodników
## przy kanale i korytarzy serwisowych) z kratką pokoju / kompleksu. Ciągłe odcinki granicy o długości do
## MAX_LEN (szerokość wejścia — dłuższa granica to korytarz wzdłuż sali, nie próg) dostają rolę CURB:
## granica pozioma -> H_L / H_M / H_R na kratce od północy, pionowa -> V_T / V_M / V_B na kratce od zachodu
## (pojedyncza kratka = środek). Tylko prawdziwe wejścia: na obu końcach odcinka ściana. Warstwa z profilu
## (FloorDecor). Bez wody, kładek, portali i ścian szer. 1.

const MAX_LEN := 5


static func enabled(ctx: GenerationContext) -> bool:
	return bool(ctx.generator_behaviour.get("tiling", {}).get("curbs_enabled", false))


static func plan(ctx: GenerationContext, plan: TilePlacementPlan) -> void:
	var canals = ctx.canals
	if not enabled(ctx) or canals == null or not "areas" in canals or canals.areas.is_empty():
		return
	var areas: Dictionary = canals.areas
	var bad := {}
	for d in [canals.water, canals.lanes, canals.service, canals.crossing_cells, ctx.portal_zone, canals.walls_1w]:
		bad.merge(d)
	# granice: klucz = kratka, na której leży kafel (północna / zachodnia z pary)
	var h := {}  # y -> [x...]
	var v := {}  # x -> [y...]
	for p: Vector2i in areas:
		if areas[p] != &"corridor" or bad.has(p) or not GridUtils.is_walkable(ctx.grid, p):
			continue
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var q: Vector2i = p + d
			var a := String(areas.get(q, &""))
			if not (a.begins_with("room:") or a.begins_with("hall:")) or bad.has(q) or not GridUtils.is_walkable(ctx.grid, q):
				continue
			if d.x == 0:
				var c: Vector2i = p if d.y == 1 else q
				if not h.has(c.y):
					h[c.y] = []
				h[c.y].append(c.x)
			else:
				var c: Vector2i = p if d.x == 1 else q
				if not v.has(c.x):
					v[c.x] = []
				v[c.x].append(c.y)
	var table := ctx.priority_table
	var g: Dictionary = ctx.grid
	for y: int in h:
		for run in _runs(h[y]):
			# próg = wejście: na obu końcach ściana (w rzędzie kafla albo w rzędzie pod nim)
			var x0: int = run[0]
			var x1: int = run[-1]
			if _wall2(g, Vector2i(x0 - 1, y), Vector2i(x0 - 1, y + 1)) and _wall2(g, Vector2i(x1 + 1, y), Vector2i(x1 + 1, y + 1)):
				_place_run(ctx, plan, table, run, func(k): return Vector2i(k, y), [&"H_L", &"H_M", &"H_R"])
	for x: int in v:
		for run in _runs(v[x]):
			var y0: int = run[0]
			var y1: int = run[-1]
			if _wall2(g, Vector2i(x, y0 - 1), Vector2i(x + 1, y0 - 1)) and _wall2(g, Vector2i(x, y1 + 1), Vector2i(x + 1, y1 + 1)):
				_place_run(ctx, plan, table, run, func(k): return Vector2i(x, k), [&"V_T", &"V_M", &"V_B"])


static func _wall2(g: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	return not GridUtils.is_walkable(g, a) or not GridUtils.is_walkable(g, b)


## Ciągłe odcinki posortowanych współrzędnych (bez powtórzeń).
static func _runs(vals: Array) -> Array:
	var u := {}
	for k in vals:
		u[k] = true
	var ks: Array = u.keys()
	ks.sort()
	var out: Array = []
	var cur: Array[int] = []
	for k: int in ks:
		if not cur.is_empty() and k != cur[-1] + 1:
			out.append(cur)
			cur = []
		cur.append(k)
	if not cur.is_empty():
		out.append(cur)
	return out


static func _place_run(ctx: GenerationContext, plan: TilePlacementPlan, table: Dictionary, run: Array, pos_of: Callable, vids: Array) -> void:
	if run.size() > MAX_LEN:
		return
	for i in run.size():
		var vid: StringName = vids[1]
		if run.size() > 1 and i == 0:
			vid = vids[0]
		elif run.size() > 1 and i == run.size() - 1:
			vid = vids[2]
		var pos: Vector2i = pos_of.call(run[i])
		for rp in TileResolver.resolve_module_parts(ctx, pos, TileModuleRole.Id.CURB, [], -1, vid):
			FacadePlacer._queue_part(plan, pos + rp.offset, rp, &"FLOOR_DECOR", table)
