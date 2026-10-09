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
const GatePlannerScript = preload("gate_planner.gd")


static func plan(result, defs: Array[ObjectDef], seed_v: int, flags: GenerationFlags, objects: ObjectPlan,
		floor_defs: Array[ObjectDef] = []) -> ObjectPlan:
	var t0 := Time.get_ticks_usec()
	if objects == null:
		objects = ObjectPlan.new()
		objects.width = result.width
		objects.height = result.height
		objects.occupancy.resize(result.width * result.height)
	if defs.is_empty():
		return objects
	var on_wall: bool = flags != null and flags.facade_base_on_wall
	# obiekty na rimie północnym (np. filary od tyłu): osobne miejsca i rytm, przed licem
	var rim_defs: Array[ObjectDef] = []
	var face_defs: Array[ObjectDef] = []
	for def in defs:
		if def.is_rim_mounted():
			rim_defs.append(def)
		else:
			face_defs.append(def)
	if not rim_defs.is_empty():
		_place_rhythm(result, rim_defs, _rim_slots(result), {}, {}, on_wall, seed_v, objects, "rim_rhythm")
	defs = face_defs
	if defs.is_empty():
		return objects
	var slots := _face_slots(result, on_wall)  # Vector2i kotwicy -> tag ("over_floor" / "over_canal")
	var used := {}                              # kratki rzędu kotwic zajęte przez dekoracje
	var rhythm_defs: Array[ObjectDef] = []
	var need_h := false
	for def in defs:
		if not def.rhythm.is_empty():
			rhythm_defs.append(def)
		need_h = need_h or def.facade_h != 0
	var bases_4h := _bases_4h(result, seed_v, flags) if need_h else {}
	var walls: Array = []  # ściany z filarami: {y, spans: [Vector2i(x, szerokość)]}
	if not rhythm_defs.is_empty():
		walls = _place_rhythm(result, rhythm_defs, slots, used, bases_4h, on_wall, seed_v, objects, "wall_rhythm")
	var span_defs: Array[ObjectDef] = []
	var pillar_defs: Array[ObjectDef] = []
	for def in defs:
		if def.span and def.rhythm.is_empty():
			span_defs.append(def)
		if def.on_pillar and def.rhythm.is_empty():
			pillar_defs.append(def)
	if not walls.is_empty() and not pillar_defs.is_empty():
		_place_on_pillars(walls, pillar_defs, seed_v, objects)
	var span_floor_defs: Array[ObjectDef] = []
	for d in floor_defs:
		if d.span_floor:
			span_floor_defs.append(d)
	if not walls.is_empty() and not span_floor_defs.is_empty():
		_place_span_floor(result, walls, span_floor_defs, on_wall, seed_v, objects)
	if not walls.is_empty() and not span_defs.is_empty():
		_place_spans(walls, span_defs, slots, used, bases_4h, on_wall, seed_v, flags, objects)
	for def in defs:
		if not def.rhythm.is_empty() or def.on_pillar or (def.span and not walls.is_empty()):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_v, String(def.id), "wall"])
		var w := maxi(def.size.x, 1)
		var cands: Array[Vector2i] = []
		for a: Vector2i in slots:
			if _fits(slots, a, w, def) and _height_ok(def, a, w, bases_4h, on_wall):
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


## Stopy lica 4H (FacadePlacer: ten sam seed i siatka co kafelkowanie); {} bez flagi enable_4h_facades.
static func _bases_4h(result, seed_v: int, flags: GenerationFlags) -> Dictionary:
	if flags == null or not flags.enable_4h_facades:
		return {}
	var c := GenerationContext.new()
	c.grid = result.grid
	c.width = result.width
	c.height = result.height
	c.flags = flags
	c.seed_value = seed_v
	FacadePlacer._plan_4h_segments(c)
	return c.facade_4h_bases


## Obiekt z facade_h (3 / 4) tylko na licu tej wysokości we wszystkich swoich kolumnach; 0 = każde lico.
static func _height_ok(def: ObjectDef, a: Vector2i, w: int, bases_4h: Dictionary, on_wall: bool) -> bool:
	if def.facade_h == 0:
		return true
	for k in range(w):
		var base := a + Vector2i(k, 1 if on_wall else 0)
		if (4 if bases_4h.has(base) else 3) != def.facade_h:
			return false
	return true


## Filary w rytmie (def.rhythm — odstępy do wyboru): na każdym odcinku lica (ciąg kotwic w jednym rzędzie)
## przęsła po `sp` kratek oddzielone filarem szerokim na 1, wyśrodkowane — filary nie na końcach lica, odcinek
## krótszy niż 2 przęsła bez filarów. Odcinek z licem 4H (FacadePlacer: ten sam seed i siatka co kafelkowanie)
## dostaje obiekt z facade_h 4, pozostałe — z facade_h 3 (0 = każdy). Przed resztą dekoracji (one omijają filary).
## Zwraca ściany z kompletem filarów: [{y, spans: [Vector2i(x początku przęsła, szerokość)], pillars: [filary]}].
static func _place_rhythm(_result, defs: Array[ObjectDef], slots: Dictionary, used: Dictionary, bases_4h: Dictionary,
		on_wall: bool, seed_v: int, objects: ObjectPlan, salt: String) -> Array:
	var walls: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, salt])
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
			# stany filara (pełny / zniszczony…) = kilka obiektów tej wysokości, losowanych wagą density
			var cands: Array[ObjectDef] = []
			for d in defs:
				if d.facade_h == 0 or d.facade_h == h:
					cands.append(d)
			if cands.is_empty():
				continue
			var def: ObjectDef = cands[0]
			if not def.rhythm_area_chance.is_empty() and not _area_allows(_result, def, x0, x1, y, seed_v, salt):
				continue
			var sp: int = def.rhythm[rng.randi() % def.rhythm.size()]
			var n := x1 - x0 + 1
			var spans := (n + 1) / (sp + 1)
			if spans < 2:
				continue
			var e := (n - (spans * sp + spans - 1)) / 2
			var placed := 0
			var wall_pillars: Array[ObjectPlacement] = []
			for k in range(spans - 1):
				var a := Vector2i(x0 + e + sp + k * (sp + 1), y)
				if not _fits(slots, a, 1, def) or used.has(a):
					continue
				var pl := ObjectPlacement.new()
				pl.def = _pick_weighted(cands, rng)
				pl.cell = a
				objects.placements.append(pl)
				_claim_floor(_result, pl, objects)
				wall_pillars.append(pl)
				used[a] = true
				placed += 1
			if placed > 0:
				objects.stats[def.id] = objects.count(def.id) + placed
			if placed == spans - 1:
				var sp_list: Array[Vector2i] = []
				for k in range(spans):
					sp_list.append(Vector2i(x0 + e + k * (sp + 1), sp))
				walls.append({"y": y, "spans": sp_list, "pillars": wall_pillars})
	return walls


## Ozdoby przęseł (def.span): na każdej ścianie z filarami wzór z flags.facade_rhythm.patterns ("A-B-A"…),
## litera przęsła = wzór[odległość od bliższego końca ściany % długość] — symetrycznie względem środka ściany.
## Litery to różne obiekty wylosowane na ścianę (waga density); ozdoba wyśrodkowana w przęśle, gdy pasuje
## (lico, wysokość). Przęsła ścian z filarami są potem zajęte — bez losowej drobnicy.
static func _place_spans(walls: Array, defs: Array[ObjectDef], slots: Dictionary, used: Dictionary,
		bases_4h: Dictionary, on_wall: bool, seed_v: int, flags: GenerationFlags, objects: ObjectPlan) -> void:
	var patterns: Array = flags.facade_rhythm.get("patterns", ["A-A-A", "A-B-A"]) if flags != null else ["A-A-A"]
	if patterns.is_empty():
		patterns = ["A-A-A"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, "wall_spans"])
	for wall in walls:
		var y: int = wall.y
		var spans: Array[Vector2i] = wall.spans
		var tokens: PackedStringArray = String(patterns[rng.randi() % patterns.size()]).split("-")
		var letters := {}  # litera -> ObjectDef
		var n := spans.size()
		for i in range(n):
			var letter := tokens[mini(i, n - 1 - i) % tokens.size()]
			var span: Vector2i = spans[i]
			if not letters.has(letter):
				letters[letter] = _pick_span_def(defs, span.y, letters.values(), rng)
			var def: ObjectDef = letters[letter]
			if def == null:
				continue
			var w := maxi(def.size.x, 1)
			if w > span.y:
				continue
			var a := Vector2i(span.x + (span.y - w) / 2, y)
			if not _fits(slots, a, w, def) or not _height_ok(def, a, w, bases_4h, on_wall):
				continue
			var free := true
			for k in range(w):
				free = free and not used.has(a + Vector2i(k, 0))
			if not free:
				continue
			var pl := ObjectPlacement.new()
			pl.def = def
			pl.cell = a
			pl.variant = rng.randi() % maxi(def.variant_count(), 1)
			pl.flip = def.flip_h and rng.randi() % 2 == 0
			objects.placements.append(pl)
			objects.stats[def.id] = objects.count(def.id) + 1
		for span: Vector2i in spans:
			for k in range(span.y):
				used[Vector2i(span.x + k, y)] = true


## Obiekt na licu z kolizją kafla (def.collision TILE): kratki jego kafli leżące na podłodze (np. podstawa filara
## pod licem) -> pl.cells, zajętość SOLID | USED; obiekt podłogowy, który już tam stał, zostaje zdjęty (poza skrzyniami).
static func _claim_floor(result, pl: ObjectPlacement, objects: ObjectPlan) -> void:
	if pl.def.collision != ObjectDef.Collision.TILE:
		return
	var w: int = objects.width
	var claim := {}
	for t in pl.def.tiles:
		var c: Vector2i = pl.cell + (t["off"] as Vector2i)
		if c.x >= 0 and c.y >= 0 and c.x < w and c.y < objects.height and GridUtils.is_walkable(result.grid, c):
			claim[c.y * w + c.x] = true
	if claim.is_empty():
		return
	var keep: Array[ObjectPlacement] = []
	for other in objects.placements:
		var hit := false
		# skrzynie (INTERACTIVE) zostają — cel quizu ważniejszy niż pół kratki pod filarem
		if other != pl and not other.def.is_wall_mounted() and other.def.klass != ObjectDef.Klass.INTERACTIVE:
			for j in other.cells:
				if claim.has(j):
					hit = true
					break
		if hit:
			for j in other.cells:
				objects.occupancy[j] &= ~(ObjectPlan.SOLID | ObjectPlan.USED)
			objects.stats[other.def.id] = maxi(objects.count(other.def.id) - 1, 0)
		else:
			keep.append(other)
	objects.placements = keep
	for j in claim:
		pl.cells.append(j)
		objects.occupancy[j] |= ObjectPlan.SOLID | ObjectPlan.USED


## Ozdoby filarów (def.on_pillar): na ścianie z szansą density wszystkie filary dostają jedną ozdobę (ta sama
## na całej ścianie), o ile filar sięga najwyższego kafla ozdoby (zniszczony — nie).
static func _place_on_pillars(walls: Array, defs: Array[ObjectDef], seed_v: int, objects: ObjectPlan) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, "wall_pillar_decor"])
	for wall in walls:
		var pillars: Array[ObjectPlacement] = wall.pillars
		var def: ObjectDef = defs[rng.randi() % defs.size()]
		if pillars.is_empty() or rng.randf() >= def.density:
			continue
		var need := _top_off(def)
		var placed := 0
		for p in pillars:
			if _top_off(p.def) > need:
				continue
			var pl := ObjectPlacement.new()
			pl.def = def
			pl.cell = p.cell
			objects.placements.append(pl)
			placed += 1
		if placed > 0:
			objects.stats[def.id] = objects.count(def.id) + placed


## Ozdoby posadzki w osi przęseł (def.span_floor): na ścianie z filarami z szansą density jedna ozdoba (ta sama
## na całej ścianie) pod każdym przęsłem, wyśrodkowana, w rzędzie SPAN_FLOOR_GAP kratek przed licem. Tylko na
## wolnej podłodze (bez wody, przeszkód, innych obiektów i kratownic).
const SPAN_FLOOR_GAP := 1


static func _place_span_floor(result, walls: Array, defs: Array[ObjectDef], on_wall: bool, seed_v: int, objects: ObjectPlan) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, "span_floor"])
	var w: int = objects.width
	var water: Dictionary = result.canals.water if result.canals != null else {}
	for wall in walls:
		var def: ObjectDef = defs[rng.randi() % defs.size()]
		if rng.randf() >= def.density:
			continue
		var y: int = wall.y + (1 if on_wall else 0) + SPAN_FLOOR_GAP
		var dw := maxi(def.size.x, 1)
		var placed := 0
		for span: Vector2i in wall.spans:
			if dw > span.y:
				continue
			var a := Vector2i(span.x + (span.y - dw) / 2, y)
			var cells := PackedInt32Array()
			var ok := true
			for fp in def.footprint:
				var c := a + fp
				if c.x < 0 or c.y < 0 or c.x >= w or c.y >= objects.height or water.has(c) or not GridUtils.is_walkable(result.grid, c):
					ok = false
					break
				var j := c.y * w + c.x
				if objects.occupancy[j] & (ObjectPlan.FORBID | ObjectPlan.USED | ObjectPlan.NO_DECAL):
					ok = false
					break
				cells.append(j)
			if not ok:
				continue
			var pl := ObjectPlacement.new()
			pl.def = def
			pl.cell = a
			pl.cells = cells
			pl.variant = rng.randi() % maxi(def.variant_count(), 1)
			objects.placements.append(pl)
			for j in cells:
				objects.occupancy[j] |= ObjectPlan.USED
			placed += 1
		if placed > 0:
			objects.stats[def.id] = objects.count(def.id) + placed


## Najwyższy rząd kafli obiektu względem kotwicy (0 dla obiektów bez listy kafli).
static func _top_off(def: ObjectDef) -> int:
	var top := 0
	for t in def.tiles:
		top = mini(top, (t["off"] as Vector2i).y)
	return top


## Obiekt przęsła mieszczący się w szerokości `width`, inny niż już wybrane na ścianie (gdy się da), wg density.
static func _pick_span_def(defs: Array[ObjectDef], width: int, taken: Array, rng: RandomNumberGenerator) -> ObjectDef:
	var cands: Array[ObjectDef] = []
	for d in defs:
		if maxi(d.size.x, 1) <= width and not taken.has(d):
			cands.append(d)
	if cands.is_empty():
		for d in defs:
			if maxi(d.size.x, 1) <= width:
				cands.append(d)
	if cands.is_empty():
		return null
	var total := 0.0
	for d in cands:
		total += maxf(d.density, 0.01)
	var r := rng.randf() * total
	for d in cands:
		r -= maxf(d.density, 0.01)
		if r <= 0.0:
			return d
	return cands[-1]


## Szansa filarów na odcinku x0..x1 (rząd y) wg rodzaju obszaru (canals.areas) — najczęstszy rodzaj kratek pod
## odcinkiem i w nim; losowanie hashem odcinka (bez RNG rytmu: kolejność losowań bez zmian).
static func _area_allows(result, def: ObjectDef, x0: int, x1: int, y: int, seed_v: int, salt: String) -> bool:
	var areas: Dictionary = result.canals.areas if result.canals != null and "areas" in result.canals else {}
	if areas.is_empty():
		return true
	var count := {}
	var best: StringName = &""
	var best_n := 0
	for x in range(x0, x1 + 1):
		for dy in [1, 0]:
			var key: StringName = areas.get(Vector2i(x, y + dy), &"")
			if key == &"":
				continue
			var kind := StringName(String(key).get_slice(":", 0))
			count[kind] = int(count.get(kind, 0)) + 1
			if int(count[kind]) > best_n:
				best = kind
				best_n = count[kind]
			break
	if not def.rhythm_area_chance.has(best):
		return true
	var u := float(hash([seed_v, x0, y, salt, "area"]) & 0xFFFF) / 65536.0
	return u < float(def.rhythm_area_chance[best])


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
	var locks := GatePlannerScript.lock_face_cells(result.canals)  # zamki bram na licu — bez ozdób obok
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
			if locks.has(anchor):
				continue
			out[anchor] = &"over_canal" if water.has(below) else &"over_floor"
	return out


## Obiekt z kandydatów wg wagi density (jeden kandydat — bez losowania: parytet katalogów z jednym filarem).
static func _pick_weighted(cands: Array[ObjectDef], rng: RandomNumberGenerator) -> ObjectDef:
	if cands.size() == 1:
		return cands[0]
	var total := 0.0
	for d in cands:
		total += maxf(d.density, 0.01)
	var r := rng.randf() * total
	for d in cands:
		r -= maxf(d.density, 0.01)
		if r <= 0.0:
			return d
	return cands[-1]


## Miejsca na rimie północnym: kratka muru z podłogą na północ, mur pod nią (krawędź masy ściany widziana
## z góry, nie lico); z dala od portali i płaskowyżów.
static func _rim_slots(result) -> Dictionary:
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
			var c := Vector2i(x, y)
			var up := c + Vector2i(0, -1)
			if GridUtils.is_walkable(grid, c) or not grid.has(c) or water.has(up) or not GridUtils.is_walkable(grid, up):
				continue
			if GridUtils.is_walkable(grid, c + Vector2i(0, 1)) or near_portal.has(up) or pl_blocked.has(up):
				continue
			out[c] = &"over_floor"
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
