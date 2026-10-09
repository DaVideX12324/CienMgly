class_name TerrainMaskPlanner
extends RefCounted


## Kształt plam terenu pod zestaw 13 kafli (pełny, 4 krawędzie, 4 narożniki zewnętrzne,
## 4 wewnętrzne). Kafel wynika z 4 WIERZCHOŁKÓW kratki (wierzchołek = blok 2×2 terenu wokół niego);
## zestaw nie ma kafla dla 0 wierzchołków (pojedyncze kratki, plamy 1×2 / 2×1, pasy szerokości 1)
## ani dla 2 wierzchołków po przekątnej. Dlatego:
## 1. teren = suma bloków 2×2 (kratka bez bloku odpada),
## 2. przerwa (kratka podłogi poza terenem przy terenie) bez bloku 2×2 poza terenem -> teren
##    (bez dziur i przesmyków szerokości 1),
## 3. styk rogiem / przekątne wierzchołki -> dopełnienie do bloku,
## powtarzane do stabilności; na koniec tylko usuwanie kratek bez kafla (gwarancja, gdy przerwy
## nie da się zasypać — ściana, bariera płaskowyżu, portal).
const SHAPE_ROUNDS := 8
const V_TL := 1
const V_TR := 2
const V_BL := 4
const V_BR := 8


## Wierzchołki kratki `c` w zbiorze `s` (bity V_*): wierzchołek = 3 sąsiedzi + kratka w zbiorze.
static func vertices(c: Vector2i, s: Dictionary) -> int:
	var t := s.has(c + Vector2i(0, -1))
	var b := s.has(c + Vector2i(0, 1))
	var l := s.has(c + Vector2i(-1, 0))
	var r := s.has(c + Vector2i(1, 0))
	var v := 0
	if t and l and s.has(c + Vector2i(-1, -1)): v |= V_TL
	if t and r and s.has(c + Vector2i(1, -1)): v |= V_TR
	if b and l and s.has(c + Vector2i(-1, 1)): v |= V_BL
	if b and r and s.has(c + Vector2i(1, 1)): v |= V_BR
	return v


## Czy układ wierzchołków ma kafel w zestawie 13 (nie 0, nie same przekątne).
static func vertices_ok(v: int) -> bool:
	return v != 0 and v != (V_TL | V_BR) and v != (V_TR | V_BL)


## Czy kratka poza terenem leży w bloku 2×2 kratek poza terenem.
static func _gap_ok(c: Vector2i, s: Dictionary) -> bool:
	for o in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var tl: Vector2i = c + o
		if not s.has(tl) and not s.has(tl + Vector2i(1, 0)) and not s.has(tl + Vector2i(0, 1)) and not s.has(tl + Vector2i(1, 1)):
			return true
	return false


static func _touches(c: Vector2i, s: Dictionary) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and s.has(c + Vector2i(dx, dy)):
				return true
	return false


## Maska z kandydatów w obrębie `domain` (kolejność wyniku = kolejność domeny — deterministycznie).
## Płaskie tablice na prostokącie domeny (+2 kratki marginesu) — pętle bez słowników.
static func shape_mask(candidates: Dictionary, domain: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if domain.is_empty():
		return out
	var x0 := domain[0].x
	var y0 := domain[0].y
	var x1 := x0
	var y1 := y0
	for c in domain:
		x0 = mini(x0, c.x)
		y0 = mini(y0, c.y)
		x1 = maxi(x1, c.x)
		y1 = maxi(y1, c.y)
	x0 -= 2
	y0 -= 2
	var w := x1 - x0 + 3
	var h := y1 - y0 + 3
	var s := PackedByteArray()
	s.resize(w * h)
	var dom := PackedByteArray()
	dom.resize(w * h)
	var grown_at := PackedByteArray()   # 1 = kratka dodana przez kształtowanie
	grown_at.resize(w * h)
	var banned := PackedByteArray()     # dodana i znów usunięta — nie dodawaj ponownie (oscylacja)
	banned.resize(w * h)
	var dlist := PackedInt32Array()
	for c in domain:
		var i := (c.y - y0) * w + (c.x - x0)
		dom[i] = 1
		dlist.append(i)
		if candidates.has(c):
			s[i] = 1
	# Kratki domeny leżą >= 2 od brzegu prostokąta, więc sąsiedzi +-1 zawsze w tablicy.
	# Decyzja kratki (usuń / dołóż ją albo sąsiada) zależy tylko od jej okna 3×3, a obie fazy stosują
	# zmiany dopiero po przejrzeniu listy. Kratka, wokół której nic się nie zmieniło od jej poprzedniej
	# fazy, powtórzyłaby tamtą decyzję bez skutku (usunięta zmieniłaby własne okno, dołożona kratka
	# też leży w oknie, odrzucona — ban/domena — dalej odpada), więc po pierwszej rundzie przeglądane
	# są tylko kratki przy zmianach. Wynik jak przy przeglądaniu całej domeny w każdej rundzie.
	var stamp := PackedInt32Array()
	stamp.resize(w * h)
	var drop_todo := dlist
	var add_todo := dlist
	var grew := PackedInt32Array()
	for _round in range(SHAPE_ROUNDS):
		var dropped := 0
		var drop := PackedInt32Array()
		for i in drop_todo:
			if s[i] == 1 and _verts(s, i, w) == 0:
				drop.append(i)
		for i in drop:
			s[i] = 0
			if grown_at[i] == 1:
				banned[i] = 1
		dropped = drop.size()
		if _round > 0:
			add_todo = _around(grew, drop, dom, stamp, _round * 2, w)
		var add := PackedInt32Array()
		for i in add_todo:
			if s[i] == 1:
				var v := _verts(s, i, w)
				if v == (V_TL | V_BR):
					add.append(i - w + 1)
					add.append(i + w - 1)
				elif v == (V_TR | V_BL):
					add.append(i - w - 1)
					add.append(i + w + 1)
				# styk rogiem dwóch plam: dopełnij okno 2×2 do bloku
				if s[i + w + 1] == 1 and s[i + 1] == 0 and s[i + w] == 0:
					add.append(i + 1)
					add.append(i + w)
				if s[i + w - 1] == 1 and s[i - 1] == 0 and s[i + w] == 0:
					add.append(i - 1)
					add.append(i + w)
			elif _near(s, i, w) and not _gap2(s, i, w):
				add.append(i)
		grew = PackedInt32Array()
		for i in add:
			if dom[i] == 1 and s[i] == 0 and banned[i] == 0:
				s[i] = 1
				grown_at[i] = 1
				grew.append(i)
		if dropped == 0 and grew.is_empty():
			break
		drop_todo = _around(drop, grew, dom, stamp, _round * 2 + 1, w)
	# Przerwy, których nie dało się zasypać (zasypana kratka nie miałaby kafla) -> poszerz je:
	# zdejmij teren wokół (przesmyk 1-szeroki staje się >= 2).
	for i in dlist:
		if s[i] == 0 and _near(s, i, w) and not _gap2(s, i, w):
			for j in [i - w - 1, i - w, i - w + 1, i - 1, i + 1, i + w - 1, i + w, i + w + 1]:
				s[j] = 0
	# Gwarancja kafli: usuwaj kratki bez kafla do skutku (samo usuwanie — zbiega).
	while true:
		var bad := PackedInt32Array()
		for i in dlist:
			if s[i] == 1 and not vertices_ok(_verts(s, i, w)):
				bad.append(i)
		if bad.is_empty():
			break
		for i in bad:
			s[i] = 0
	for k in range(domain.size()):
		if s[dlist[k]] == 1:
			out.append(domain[k])
	return out


## Kratki domeny w oknie 3×3 wokół zmian `a` i `b`, bez powtórzeń (stamp == phase: już na liście).
static func _around(a: PackedInt32Array, b: PackedInt32Array, dom: PackedByteArray, stamp: PackedInt32Array, phase: int, w: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for src in [a, b]:
		for c in src:
			for j in [c - w - 1, c - w, c - w + 1, c - 1, c, c + 1, c + w - 1, c + w, c + w + 1]:
				if dom[j] == 1 and stamp[j] != phase:
					stamp[j] = phase
					out.append(j)
	return out


static func _verts(s: PackedByteArray, i: int, w: int) -> int:
	var t := s[i - w] == 1
	var b := s[i + w] == 1
	var l := s[i - 1] == 1
	var r := s[i + 1] == 1
	var v := 0
	if t and l and s[i - w - 1] == 1: v |= V_TL
	if t and r and s[i - w + 1] == 1: v |= V_TR
	if b and l and s[i + w - 1] == 1: v |= V_BL
	if b and r and s[i + w + 1] == 1: v |= V_BR
	return v


static func _near(s: PackedByteArray, i: int, w: int) -> bool:
	return s[i - w - 1] == 1 or s[i - w] == 1 or s[i - w + 1] == 1 or s[i - 1] == 1 or s[i + 1] == 1 \
		or s[i + w - 1] == 1 or s[i + w] == 1 or s[i + w + 1] == 1


## Czy kratka poza terenem leży w bloku 2×2 kratek poza terenem.
static func _gap2(s: PackedByteArray, i: int, w: int) -> bool:
	var t := s[i - w] == 0
	var b := s[i + w] == 0
	var l := s[i - 1] == 0
	var r := s[i + 1] == 0
	return (t and l and s[i - w - 1] == 0) or (t and r and s[i - w + 1] == 0) 		or (b and l and s[i + w - 1] == 0) or (b and r and s[i + w + 1] == 0)


## Maski terenu (błoto, trawa) dla komórek terenu — czysta funkcja seeda i komórek, więc generator
## obiektów liczy je już w topologii (GenerationResult.terrain_masks), a planer kafli używa tych
## samych masek, gdy seed się zgadza. {seed: int, mud: Array[Vector2i], grass: Array[Vector2i]}.
static func compute_masks(ctx: GenerationContext, terrain_cells: Array[Vector2i]) -> Dictionary:
	var fl: GenerationFlags = ctx.flags if ctx.flags != null else GenerationFlags.new()
	var smoothing := ctx.flags != null and ctx.flags.enable_terrain_smoothing
	# kanały (woda, puste koryto, kładki) bez plam — mech / foliage tylko na posadzce
	var cells := terrain_cells
	var canals = ctx.canals
	if canals != null and not canals.is_empty():
		cells = []
		for p in terrain_cells:
			if not canals.water.has(p) and not canals.bridge_cells.has(p):
				cells.append(p)
	return {
		"seed": ctx.seed_value,
		"mud": _mask(cells, ctx.portal_zone, ctx.seed_value + 202, fl.terrain_mud_frequency, fl.terrain_mud_threshold, smoothing),
		"grass": _mask(cells, ctx.portal_zone, ctx.seed_value, fl.terrain_grass_frequency, fl.terrain_grass_threshold, smoothing),
	}


## Maski dla wyniku generacji (bez planu kafli): komórki terenu jak w TilePlacementPlanner
## (podłoga + 2 kratki, bez barier i schodów płaskowyżu), strefa portali z wejścia i wyjścia.
static func compute_for_result(result, seed_value: int, flags: GenerationFlags) -> Dictionary:
	var ctx := GenerationContext.new()
	ctx.grid = result.grid
	ctx.width = result.width
	ctx.height = result.height
	ctx.seed_value = seed_value
	ctx.flags = flags
	ctx.plateau = result.plateau
	ctx.canals = result.canals
	for p in result.entrance_zone:
		ctx.portal_zone[p] = true
	for p in result.exit_zone:
		ctx.portal_zone[p] = true
	var cells := TilePlacementPlanner.terrain_cells(ctx, FloorPlacer.get_ground_cells(ctx))
	return compute_masks(ctx, cells)


static func _mask(cells: Array[Vector2i], portal_zone: Dictionary, noise_seed: int, frequency: float, threshold: float, smoothing: bool) -> Array[Vector2i]:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	var candidates := {}
	var domain: Array[Vector2i] = []
	for p in cells:
		if portal_zone.has(p):
			continue
		domain.append(p)
		if noise.get_noise_2d(float(p.x), float(p.y)) > threshold:
			candidates[p] = true
	if smoothing:
		return shape_mask(candidates, domain)
	var cells_set := {}
	for p in candidates.keys():
		if candidates.has(p + Vector2i(1, 0)) and candidates.has(p + Vector2i(0, 1)) and candidates.has(p + Vector2i(1, 1)):
			cells_set[p] = true
			cells_set[p + Vector2i(1, 0)] = true
			cells_set[p + Vector2i(0, 1)] = true
			cells_set[p + Vector2i(1, 1)] = true
	var out: Array[Vector2i] = []
	for p in cells_set.keys():
		out.append(p)
	return out


## Plamy błota (teren terrain_mud_index, domyślnie 1 'Mud') na Floor i mchu / trawy (terrain_grass_index,
## domyślnie 2 'Grass') na FloorDecor; indeks < 0 = bez plam. Flaga floor_terrain >= 0: najpierw cała
## podłoga malowana tym terenem (brzegi przy ścianach z kafli terenu zamiast roli FLOOR).
## Gotowe maski z ctx.terrain_masks, gdy policzone tym samym seedem; inaczej liczone tutaj.
static func plan_masks(ctx: GenerationContext, terrain_plan: TerrainPaintPlan, terrain_cells: Array[Vector2i]) -> Dictionary:
	var masks: Dictionary = ctx.terrain_masks
	if masks.is_empty() or int(masks.get("seed", 0)) != ctx.seed_value:
		masks = compute_masks(ctx, terrain_cells)
	var fl := ctx.flags
	if fl != null and fl.floor_terrain >= 0:
		var edge_mask: Array[Vector2i] = []
		if fl.floor_edges_by_walkable:
			for p in terrain_cells:
				if GridUtils.is_walkable(ctx.grid, p):
					edge_mask.append(p)
		terrain_plan.add_batch(&"Floor", terrain_cells, 0, fl.floor_terrain, 0, true, edge_mask)
	var mud_idx: int = fl.terrain_mud_index if fl != null else 1
	var grass_idx: int = fl.terrain_grass_index if fl != null else 2
	if mud_idx >= 0:
		terrain_plan.add_batch(&"Floor", masks["mud"], 0, mud_idx, 0, true)
	if grass_idx >= 0:
		terrain_plan.add_batch(&"FloorDecor", masks["grass"], 0, grass_idx, 1, true)
	return masks
