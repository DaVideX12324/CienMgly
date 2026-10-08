extends RefCounted

## Obiekty na licu ściany (ObjectDef.mount == "facade"): lampy, kratki, łuki odpływów… Kotwica = dolna
## kratka lica w kolumnie, pod którą jest podłoga (z flagą facade_base_on_wall — ostatnia kratka ściany,
## bez niej — pierwsza kratka podłogi, na której stoi lico). Obiekt o szerokości `size.x` kratek wymaga
## ciągłego lica (ściana >= MIN_FACE_H kratek) na tej samej wysokości w swoich kolumnach i w MARGIN
## kolumnach po bokach (bez końców lica). Bez kolizji i bez zajętości podłogi — tylko odstępy między sobą.
## Tagi kontekstu (context / avoid / require): "over_floor" / "over_canal" — co leży pod licem.
## Wynik dopisywany do ObjectPlan (ten sam realizer: wypieczona scena, y-sort tuż nad podłogą).

const MIN_FACE_H := 3
const MARGIN := 1
const PORTAL_MARGIN := 2


static func plan(result, defs: Array[ObjectDef], seed_v: int, flags: GenerationFlags, objects: ObjectPlan) -> ObjectPlan:
	var t0 := Time.get_ticks_usec()
	if objects == null:
		objects = ObjectPlan.new()
		objects.width = result.width
		objects.height = result.height
		objects.occupancy.resize(result.width * result.height)
	if defs.is_empty():
		return objects
	var on_wall: bool = flags != null and flags.facade_base_on_wall
	var slots := _face_slots(result, on_wall)  # Vector2i kotwicy -> tag ("over_floor" / "over_canal")
	var used := {}                              # kratki rzędu kotwic zajęte przez dekoracje
	var rhythm_defs: Array[ObjectDef] = []
	for def in defs:
		if not def.rhythm.is_empty():
			rhythm_defs.append(def)
	if not rhythm_defs.is_empty():
		_place_rhythm(result, rhythm_defs, slots, used, seed_v, flags, on_wall, objects)
	for def in defs:
		if not def.rhythm.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_v, String(def.id), "wall"])
		var w := maxi(def.size.x, 1)
		var cands: Array[Vector2i] = []
		for a: Vector2i in slots:
			if _fits(slots, a, w, def):
				cands.append(a)
		cands.sort()  # słownik ma kolejność wstawiania, ale sort = niezależność od niej
		var target := _target(def, cands.size(), rng)
		if target <= 0:
			continue
		_shuffle(cands, rng)
		var placed := 0
		for a in cands:
			if placed >= target:
				break
			if not _free(used, a, w, def.spacing):
				continue
			var pl := ObjectPlacement.new()
			pl.def = def
			pl.cell = a
			pl.variant = rng.randi() % maxi(def.variant_count(), 1)
			pl.flip = def.flip_h and rng.randi() % 2 == 0
			objects.placements.append(pl)
			for k in range(w):
				used[a + Vector2i(k, 0)] = true
			placed += 1
		if placed > 0:
			objects.stats[def.id] = objects.count(def.id) + placed
	objects.time_usec += Time.get_ticks_usec() - t0
	return objects


## Filary w rytmie (def.rhythm — odstępy do wyboru): na każdym odcinku lica (ciąg kotwic w jednym rzędzie)
## przęsła po `sp` kratek oddzielone filarem szerokim na 1, wyśrodkowane — filary nie na końcach lica, odcinek
## krótszy niż 2 przęsła bez filarów. Odcinek z licem 4H (FacadePlacer: ten sam seed i siatka co kafelkowanie)
## dostaje obiekt z facade_h 4, pozostałe — z facade_h 3 (0 = każdy). Przed resztą dekoracji (one omijają filary).
static func _place_rhythm(result, defs: Array[ObjectDef], slots: Dictionary, used: Dictionary, seed_v: int,
		flags: GenerationFlags, on_wall: bool, objects: ObjectPlan) -> void:
	var bases_4h := {}
	if flags != null and flags.enable_4h_facades:
		var c := GenerationContext.new()
		c.grid = result.grid
		c.width = result.width
		c.height = result.height
		c.flags = flags
		c.seed_value = seed_v
		FacadePlacer._plan_4h_segments(c)
		bases_4h = c.facade_4h_bases
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, "wall_rhythm"])
	var rows := {}
	for a: Vector2i in slots:
		if not rows.has(a.y):
			rows[a.y] = []
		(rows[a.y] as Array).append(a.x)
	var ys: Array = rows.keys()
	ys.sort()
	for y: int in ys:
		var xs: Array = rows[y]
		xs.sort()
		var i := 0
		while i < xs.size():
			var j := i
			while j + 1 < xs.size() and int(xs[j + 1]) == int(xs[j]) + 1:
				j += 1
			var x0: int = xs[i]
			var x1: int = xs[j]
			i = j + 1
			var base := Vector2i(x0, y + 1) if on_wall else Vector2i(x0, y)
			var h := 4 if bases_4h.has(base) else 3
			var def: ObjectDef = null
			for d in defs:
				if d.facade_h == 0 or d.facade_h == h:
					def = d
					break
			if def == null:
				continue
			var sp: int = def.rhythm[rng.randi() % def.rhythm.size()]
			var n := x1 - x0 + 1
			var spans := (n + 1) / (sp + 1)
			if spans < 2:
				continue
			var e := (n - (spans * sp + spans - 1)) / 2
			var placed := 0
			for k in range(spans - 1):
				var a := Vector2i(x0 + e + sp + k * (sp + 1), y)
				if not _fits(slots, a, 1, def) or used.has(a):
					continue
				var pl := ObjectPlacement.new()
				pl.def = def
				pl.cell = a
				objects.placements.append(pl)
				used[a] = true
				placed += 1
			if placed > 0:
				objects.stats[def.id] = objects.count(def.id) + placed


## Kolumny z licem: kratka ściany z podłogą na S i ścianą >= MIN_FACE_H w górę. Poza strefą portali
## (+PORTAL_MARGIN) i barierami płaskowyżu.
static func _face_slots(result, on_wall: bool) -> Dictionary:
	var grid: Dictionary = result.grid
	var water: Dictionary = result.canals.water if result.canals != null else {}
	var pl_blocked: Dictionary = result.plateau.blocked if result.plateau != null else {}
	var near_portal := {}
	for p: Vector2i in result.portal_zone:
		for dy in range(-PORTAL_MARGIN, PORTAL_MARGIN + 1):
			for dx in range(-PORTAL_MARGIN, PORTAL_MARGIN + 1):
				near_portal[p + Vector2i(dx, dy)] = true
	var out := {}
	for y in range(1, result.height - 1):
		for x in range(result.width):
			var below := Vector2i(x, y + 1)
			if GridUtils.is_walkable(grid, Vector2i(x, y)) or not GridUtils.is_walkable(grid, below):
				continue
			if near_portal.has(below) or pl_blocked.has(below):
				continue
			var tall := true
			for k in range(1, MIN_FACE_H):
				if GridUtils.is_walkable(grid, Vector2i(x, y - k)):
					tall = false
					break
			if not tall:
				continue
			var anchor := Vector2i(x, y) if on_wall else below
			out[anchor] = &"over_canal" if water.has(below) else &"over_floor"
	return out


## Lico ciągłe w kolumnach obiektu i marginesie, reguły tagów dla kolumn obiektu.
static func _fits(slots: Dictionary, a: Vector2i, w: int, def: ObjectDef) -> bool:
	for k in range(-MARGIN, w + MARGIN):
		if not slots.has(a + Vector2i(k, 0)):
			return false
	for k in range(w):
		var tag: StringName = slots[a + Vector2i(k, 0)]
		if not def.context.is_empty() and not tag in def.context:
			return false
		if tag in def.avoid:
			return false
		for r in def.require:
			if r != tag:
				return false
	return true


## Wolne kolumny obiektu + odstęp `spacing` (min. 1 kratka przerwy od innych dekoracji).
static func _free(used: Dictionary, a: Vector2i, w: int, spacing: int) -> bool:
	var gap := maxi(spacing, 1)
	for k in range(-gap, w + gap):
		if used.has(a + Vector2i(k, 0)):
			return false
	return true


## Liczba sztuk: count [min, max] albo gęstość na 100 kandydatów (zaokrąglana losowo).
static func _target(def: ObjectDef, n: int, rng: RandomNumberGenerator) -> int:
	if def.count_min >= 0:
		return rng.randi_range(def.count_min, def.count_max)
	var f := def.density * n / 100.0
	var t := int(floor(f))
	if rng.randf() < f - t:
		t += 1
	return t


static func _shuffle(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
