extends RefCounted

## Krawężniki (tiling.curbs): całe jednostki posadzki podniesione o stopień — spójnie, jak płaskowyże.
## 1. Jednostki: pokój (canals.areas "room:i"), kompleks ("hall:i") oraz spójne kawałki korytarzy, korytarzy
##    serwisowych i chodników przy kanale (bez wody, kładek, portali i ścian szer. 1).
## 2. Granica dwóch jednostek jest „czysta”, gdy każdy jej odcinek to prosty przekrój od ściany (albo wody) do
##    ściany o długości do MAX_LEN — najkrótszy możliwy krawężnik, w jednym kierunku.
## 3. Jednostki w losowej kolejności (hash seeda) podnoszone z szansą `chance`, tylko gdy wszystkie granice
##    z niepodniesionymi sąsiadami są czyste (granica z podniesionym sąsiadem znika — ta sama wysokość).
##    Chodniki przy kanale nie są podnoszone (`raise_lanes`: false).
## 4. Krawężnik na każdej granicy podniesiony | niski: pozioma -> H_L / H_M / H_R na kratce od północy,
##    pionowa -> V_T / V_M / V_B na kratce od zachodu (pojedyncza kratka = środek). Warstwa z profilu (FloorDecor).
##    Linia cofnięta w głąb przejścia (_inset, do INSET_MAX kratek wzdłuż przekroju): krawężnik leży między kaflami
##    ścian — kratka, na której jest rysowany (od północy / zachodu linii), ma na obu końcach odcinka ścianę albo
##    wodę — a nie u wylotu, na otwartym (decyzja usera). Wylot południowy / wschodni zostaje na linii wylotu (kafel
##    na ostatniej kratce przejścia, równo ze stopą lica — user: tak było dobrze), północny / zachodni wchodzi kratkę
##    w głąb. Bez takiego miejsca zostaje na granicy jednostek.
##
## JSON: "curbs": {"chance": 0.35, "raise_lanes": false}

const MAX_LEN := 5
const INSET_MAX := 3
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]


static func plan(ctx: GenerationContext, plan: TilePlacementPlan) -> void:
	var cfg: Dictionary = ctx.generator_behaviour.get("tiling", {}).get("curbs", {})
	var canals = ctx.canals
	if cfg.is_empty() or canals == null or not "areas" in canals or canals.areas.is_empty():
		return
	var g: Dictionary = ctx.grid
	var areas: Dictionary = canals.areas
	var bad := {}
	for d in [canals.water, canals.crossing_cells, ctx.portal_zone, canals.walls_1w, canals.stair_cells]:
		bad.merge(d)

	# 1. jednostki
	var cat := func(p: Vector2i) -> String:
		var a := String(areas[p])
		if a.begins_with("room:") or a.begins_with("hall:"):
			return a
		if canals.lanes.has(p):
			return "lane"
		if canals.service.has(p):
			return "service"
		return "corridor"
	var unit := {}             # kratka -> id
	var unit_cat: Array[String] = []
	var keys: Array = areas.keys()
	keys.sort()
	for start: Vector2i in keys:
		if unit.has(start) or bad.has(start) or not GridUtils.is_walkable(g, start):
			continue
		var uid := unit_cat.size()
		var c0: String = cat.call(start)
		unit_cat.append(c0)
		var stack: Array[Vector2i] = [start]
		unit[start] = uid
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			for d in DIRS:
				var q: Vector2i = c + d
				if unit.has(q) or not areas.has(q) or bad.has(q) or not GridUtils.is_walkable(g, q) or cat.call(q) != c0:
					continue
				unit[q] = uid
				stack.append(q)

	# 2. granice: para jednostek -> {"h": {y: [x]}, "v": {x: [y]}} (kratka od północy / zachodu)
	var bounds := {}
	for p: Vector2i in unit:
		for d in [Vector2i(0, 1), Vector2i(1, 0)]:
			var q: Vector2i = p + d
			if not unit.has(q) or unit[q] == unit[p]:
				continue
			var key := Vector2i(mini(unit[p], unit[q]), maxi(unit[p], unit[q]))
			if not bounds.has(key):
				bounds[key] = {"h": {}, "v": {}}
			var side: Dictionary = bounds[key]["h" if d.y == 1 else "v"]
			var line: int = p.y if d.y == 1 else p.x
			if not side.has(line):
				side[line] = []
			side[line].append(p.x if d.y == 1 else p.y)
	var clean := {}     # para -> bool
	var nbrs := {}      # jednostka -> [sąsiedzi]
	for key: Vector2i in bounds:
		clean[key] = _clean(g, canals, bounds[key])
		for k in [[key.x, key.y], [key.y, key.x]]:
			if not nbrs.has(k[0]):
				nbrs[k[0]] = []
			nbrs[k[0]].append(k[1])

	# 3. podnoszenie
	var chance := float(cfg.get("chance", 0.35))
	var raise_lanes := bool(cfg.get("raise_lanes", false))
	var order: Array[int] = []
	for i in unit_cat.size():
		order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "curbs"])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t := order[i]
		order[i] = order[j]
		order[j] = t
	var raised := {}
	for u in order:
		if rng.randf() >= chance or not nbrs.has(u) or (unit_cat[u] == "lane" and not raise_lanes):
			continue
		var ok := true
		for v: int in nbrs[u]:
			if not raised.has(v) and not clean[Vector2i(mini(u, v), maxi(u, v))]:
				ok = false
				break
		if ok:
			raised[u] = true

	# 4. krawężniki
	var table := ctx.priority_table
	for key: Vector2i in bounds:
		if raised.has(key.x) == raised.has(key.y):
			continue
		var b: Dictionary = bounds[key]
		for y: int in b.h:
			for run in _runs(b.h[y]):
				var cells: Array = run.map(func(x): return Vector2i(x, y))
				_place(ctx, plan, table, _inset(g, canals, bad, cells, Vector2i(0, 1), Vector2i(1, 0)), [&"H_L", &"H_M", &"H_R"])
		for x: int in b.v:
			for run in _runs(b.v[x]):
				var cells: Array = run.map(func(y): return Vector2i(x, y))
				_place(ctx, plan, table, _inset(g, canals, bad, cells, Vector2i(1, 0), Vector2i(0, 1)), [&"V_T", &"V_M", &"V_B"])


## Granica czysta: każdy odcinek do MAX_LEN, na obu końcach ściana albo woda.
static func _clean(g: Dictionary, canals, b: Dictionary) -> bool:
	for y: int in b.h:
		for run in _runs(b.h[y]):
			if run.size() > MAX_LEN or not _edge(g, canals, Vector2i(run[0] - 1, y), Vector2i(run[0] - 1, y + 1)) \
					or not _edge(g, canals, Vector2i(run[-1] + 1, y), Vector2i(run[-1] + 1, y + 1)):
				return false
	for x: int in b.v:
		for run in _runs(b.v[x]):
			if run.size() > MAX_LEN or not _edge(g, canals, Vector2i(x, run[0] - 1), Vector2i(x + 1, run[0] - 1)) \
					or not _edge(g, canals, Vector2i(x, run[-1] + 1), Vector2i(x + 1, run[-1] + 1)):
				return false
	return true


static func _place(ctx: GenerationContext, plan: TilePlacementPlan, table: Dictionary, cells: Array, vids: Array) -> void:
	for i in cells.size():
		var vid: StringName = vids[1]
		if cells.size() > 1 and i == 0:
			vid = vids[0]
		elif cells.size() > 1 and i == cells.size() - 1:
			vid = vids[2]
		var pos: Vector2i = cells[i]
		for rp in TileResolver.resolve_module_parts(ctx, pos, TileModuleRole.Id.CURB, [], -1, vid):
			FacadePlacer._queue_part(plan, pos + rp.offset, rp, &"FLOOR_DECOR", table)


## Linia krawężnika (`cells` = kratki od północy / zachodu linii, `across` = w stronę drugiej kratki, `along` = wzdłuż
## odcinka) przesunięta o najmniejsze s w [0, ±1 … ±INSET_MAX], przy którym kratki linii i kratki za nią są wolne
## (podłoga, nie woda / kładka / portal), a na obu końcach odcinka kratek linii jest ściana albo woda.
## Kratki pomiędzy starą a nową linią też muszą być przejściem tej samej szerokości. Brak -> linia bez zmian.
static func _inset(g: Dictionary, canals, bad: Dictionary, cells: Array, across: Vector2i, along: Vector2i) -> Array:
	var shifts: Array[int] = [0]
	for k in range(1, INSET_MAX + 1):
		shifts.append(k)
		shifts.append(-k)
	for sft in shifts:
		var ok := true
		var lo := mini(0, sft)
		var hi := maxi(0, sft) + 1   # wiersze lo..hi (linia + kratka za nią) — całe przejście
		for k in range(lo, hi + 1):
			var row: Array = cells.map(func(c: Vector2i) -> Vector2i: return c + across * k)
			for c: Vector2i in row:
				if not GridUtils.is_walkable(g, c) or bad.has(c):
					ok = false
					break
			if not ok:
				break
			if k == sft:
				var a: Vector2i = row[0] - along
				var b: Vector2i = row[-1] + along
				if not (_solid(g, canals, a) and _solid(g, canals, b)):
					ok = false
					break
		if ok:
			return cells.map(func(c: Vector2i) -> Vector2i: return c + across * sft)
	return cells


static func _solid(g: Dictionary, canals, c: Vector2i) -> bool:
	return not GridUtils.is_walkable(g, c) or (canals.water.has(c) and not canals.crossing_cells.has(c))


## Koniec przekroju: ściana albo woda (bez kładki) w jednej z dwóch kratek.
static func _edge(g: Dictionary, canals, a: Vector2i, b: Vector2i) -> bool:
	for c in [a, b]:
		if not GridUtils.is_walkable(g, c) or (canals.water.has(c) and not canals.crossing_cells.has(c)):
			return true
	return false


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
