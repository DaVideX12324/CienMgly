class_name PlateauPass
extends RefCounted

const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const GenerationFlags = preload("res://modules/quiz_rpg/scripts/generation/core/generation_flags.gd")
const CellType = preload("res://modules/quiz_rpg/scripts/generation/core/cell_type.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const SeededNoise = preload("res://modules/quiz_rpg/scripts/generation/core/seeded_noise.gd")
const PlateauLayout = preload("res://modules/quiz_rpg/scripts/generation/core/plateau_layout.gd")

## Topologia płaskowyżów (jeden poziom): maska z szumu na podłodze całej mapy, czyszczona
## morfologicznie (ściany liczą się jako lite — płaskowyż dosuwa się do ścian i zostają półki
## przy ścianach), schody na prostych odcinkach lica, potem naprawa OSIĄGALNOŚCI: każdy kawałek
## chodliwego terenu, do którego nie da się dojść z wejścia, dostaje schody do osiągalnego terenu
## sąsiedniej wysokości (patrz _solve). Grid zostaje FLOOR — płaskowyż to nakładka.

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const CLEAN_ITERS := 3
const HOLE_MAX := 40          # zamknięte kieszenie podłogi do tej wielkości są zasypywane
const MAX_REPAIR_ITERS := 32
const PICK_CANDIDATES := 8    # kandydaci schodów na kierunek przy łączeniu (pierwszy niekolidujący wygrywa)
const REGION_TRIES := 2      # ile nieudanych prób schodów dla tego samego nieosiągalnego kawałka
enum { CONNECT_ADDED, CONNECT_FAILED, CONNECT_WAITING }
const STAIR_FLANK := 2        # od końca biegu lica: kolumna końca + ≥1 kolumna fasady
const STAIR_SITE_W := 6       # okno rzeźbionego miejsca na schody: 2*STAIR_FLANK + 2 stopnie
const STAIR_SITE_W_MIN := 4   # węższe okno (flanka 1 + 2 stopnie), gdy 6 się nie mieści (wąski korytarz)
const POCKET_MAX := 8         # odcięte kieszonki ziemi do tej wielkości -> płaskowyż
const PORTAL_RING := 2        # pierścień wokół strefy portalu (bez krawędzi płaskowyżu)


static func run(ctx: GenerationContext, flags: GenerationFlags) -> PlateauLayout:
	if flags == null or not flags.enable_platforms or ctx.entrance_pos == Vector2i.ZERO:
		return null

	var allowed := _allowed_cells(ctx)
	var mask := _noise_mask(ctx, flags, allowed)
	mask = _clean(ctx, mask, allowed, flags.plateau_min_area)
	mask = _fill_wall_gaps(ctx, mask, allowed)
	mask = _portals_all_or_nothing(ctx, mask, allowed)
	mask = _strip_thin(ctx, mask)
	mask = _drop_small(mask, flags.plateau_min_area)
	return _with_field(solve_mask(ctx, flags, mask), ctx, flags)


## Schody + osiągalność dla gotowej maski płaskowyżu (bez szumu i czyszczenia) — używane przez
## run() i przez testy scenariuszowe z ręcznie zadaną maską.
static func solve_mask(ctx: GenerationContext, flags: GenerationFlags, mask: Dictionary) -> PlateauLayout:
	if mask.is_empty():
		return PlateauLayout.new()
	var allowed := _allowed_cells(ctx)
	var layout := _solve(ctx, flags, mask.duplicate(), allowed)
	# Portal na płaskowyżu, do którego nie da się dojść (brak miejsca na schody) -> wytnij jego
	# obszar (strefa + pierścień) i policz jeszcze raz. Krawędź ląduje wtedy poza pierścieniem.
	var bad := _unreached_portal_area(ctx, layout, allowed)
	if not bad.is_empty():
		var m2: Dictionary = layout.mask.duplicate()
		for c in bad:
			m2.erase(c)
		layout = _solve(ctx, flags, _drop_small(_strip_thin(ctx, m2), flags.plateau_min_area), allowed)
	return layout


## Obszary (strefa + pierścień) portali, do których nie prowadzi żadna ścieżka w układzie.
static func _unreached_portal_area(ctx: GenerationContext, layout: PlateauLayout, allowed: Dictionary) -> Dictionary:
	var reach := _bfs(ctx, ctx.entrance_pos, layout.blocked)
	var out := {}
	for zone in _portal_zones(ctx):
		var ok := false
		for c in zone:
			if reach.has(c):
				ok = true
				break
		if not ok:
			out.merge(_zone_area(zone, allowed))
	return out


## Schody + osiągalność. Zasada: po złożeniu układu cały chodliwy teren (ziemia i góry płaskowyżów)
## ma być osiągalny z wejścia po rzeczywistych zasadach ruchu — bariery (rim, bok, lico i jego
## stopa) blokują, schody są jedynym przejściem między wysokościami (_bfs po layout.blocked).
## Nie ma wymogu ścieżki po samej podłodze ani schodów na każdym płaskowyżu:
## - obszar osiągalny (np. przez schody z budżetu albo portal na górze) nie dostaje nic,
## - nieosiągalny kawałek dostaje schody do osiągalnego terenu sąsiedniej wysokości, z dowolnej
##   strony (S, N, E, W; w razie potrzeby wyrzeźbione miejsce) — _connect_region,
## - gdy schodów nie da się postawić nigdzie (jawnie, jak dotąd w generatorze): drobna kieszeń
##   ziemi -> płaskowyż, płaskowyż odcinający ziemię -> usunięty, nieosiągalna góra -> bariera
##   (wzniesienie zostaje, tylko nikt tam nie trafia). Liczniki w PlateauLayout.
static func _solve(ctx: GenerationContext, flags: GenerationFlags, mask: Dictionary, allowed: Dictionary) -> PlateauLayout:
	var comps := _components(mask, DIRS8)
	var protected := _portal_area(ctx, allowed)  # rzeźbienie schodów nie rusza portali
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "plateau_stairs"])
	# Schody „z wyglądu”: każdy płaskowyż losuje ich liczbę z 0..platform_max_stairs (S, potem N, E, W;
	# szerokość też losowa, 2..stair_max_width). Dostępność zapewnia dopiero naprawa niżej — płaskowyż,
	# który wylosował za mało (albo 0), dostaje dokładnie tyle schodów, ile trzeba do dojścia.
	var max_budget := maxi(flags.platform_max_stairs, 0)
	var comp_stairs_south: Array = []
	var comp_stairs_north: Array = []
	var comp_stairs_east: Array = []
	var comp_stairs_west: Array = []
	for comp in comps:
		var budget := rng.randi_range(0, max_budget)
		var ss := _pick_stairs(ctx, comp, rng, flags, false, budget)
		var sn := _pick_stairs_north(ctx, comp, rng, flags, false, budget - ss.size())
		var se := _pick_stairs_side(ctx, comp, rng, true, flags, false, budget - ss.size() - sn.size())
		var sw := _pick_stairs_side(ctx, comp, rng, false, flags, false, budget - ss.size() - sn.size() - se.size())
		comp_stairs_south.append(ss)
		comp_stairs_north.append(sn)
		comp_stairs_east.append(se)
		comp_stairs_west.append(sw)

	var alive: Array[bool] = []
	alive.resize(comps.size())
	alive.fill(true)
	var lists := [comp_stairs_south, comp_stairs_north, comp_stairs_east, comp_stairs_west]

	# Teren, który ma być osiągalny: spójny z wejściem w gridzie (bez wysokości) — sam grid, nie
	# warunek ścieżki; komórki odcięte już w topologii nie są problemem płaskowyżów.
	var walkable_area := _bfs(ctx, ctx.entrance_pos, {})
	var tried := {}           # klucz nieosiągalnego kawałka -> liczba prób schodów
	var connect_added := 0
	var dropped := 0
	var layout: PlateauLayout = null
	for _iter in range(MAX_REPAIR_ITERS):
		layout = _assemble(ctx, comps, comp_stairs_south, comp_stairs_north, comp_stairs_east, comp_stairs_west, alive, flags.plateau_min_area)
		var reach := _bfs(ctx, ctx.entrance_pos, layout.blocked)
		var unreached := {}
		for c in walkable_area:
			if not reach.has(c) and not layout.blocked.has(c):
				unreached[c] = true
		if unreached.is_empty():
			break

		# 1. Schody do każdego nieosiągalnego kawałka (góra -> w dół, ziemia -> z płaskowyżu obok).
		var added := 0
		for region in _components(unreached, DIRS4):
			var key := _island_key(region)
			if int(tried.get(key, 0)) >= REGION_TRIES:
				continue
			var r := _connect_region(ctx, region, comps, alive, layout, reach, mask, allowed, protected, rng, flags, lists)
			if r == CONNECT_ADDED:
				added += 1
			elif r == CONNECT_FAILED:
				tried[key] = int(tried.get(key, 0)) + 1  # próba nieudana (brak miejsca na schody)
		if added > 0:
			connect_added += added
			continue

		# 2. Schodów nie da się postawić — jawna obsługa. Ziemia odcięta przez płaskowyż:
		#    drobna kieszeń -> płaskowyż, inaczej płaskowyż usunięty (odblokowuje teren).
		var ground := {}
		for c in unreached:
			if not layout.mask.has(c):
				ground[c] = true
		var blockers: Array[int] = []
		for i in range(comps.size()):
			if alive[i] and not ground.is_empty() and _touches(comps[i], layout, ground):
				blockers.append(i)
		if blockers.is_empty():
			break  # zostały tylko nieosiągalne góry -> bariera przy domknięciu niżej
		if _absorb_pockets(ctx, comps, blockers, mask, allowed, protected, ground, layout, lists):
			continue
		for i in blockers:
			alive[i] = false
		dropped += blockers.size()

	layout = _assemble(ctx, comps, comp_stairs_south, comp_stairs_north, comp_stairs_east, comp_stairs_west, alive, flags.plateau_min_area)
	var reach_final := _bfs(ctx, ctx.entrance_pos, layout.blocked)
	if _seal_holes(ctx, comps, alive, layout, protected, lists):
		layout = _assemble(ctx, comps, comp_stairs_south, comp_stairs_north, comp_stairs_east, comp_stairs_west, alive, flags.plateau_min_area)
		reach_final = _bfs(ctx, ctx.entrance_pos, layout.blocked)
	# Góra bez dojścia, dla której nie było miejsca na schody -> bariera (żadnych spawnów tam).
	var lost := _unreached_top(layout, reach_final)
	for c in lost:
		layout.top.erase(c)
		layout.blocked[c] = true
	layout.connect_stairs = connect_added
	layout.dropped_pieces = dropped
	layout.unreachable_top = lost.size()
	return layout


## Schody dla nieosiągalnego kawałka terenu `region` (spójny kawałek nieosiągniętych, chodliwych
## kratek):
## - kawałek góry płaskowyżu -> schody z tego płaskowyżu na osiągalny teren niższego poziomu przy nim,
## - kawałek ziemi -> schody z sąsiedniego płaskowyżu, którego góra jest osiągalna, w dół do kawałka.
## Strona schodów dowolna (S, N, E, W). Zwraca CONNECT_ADDED / CONNECT_FAILED (był osiągalny sąsiad,
## ale nie ma miejsca na schody) / CONNECT_WAITING (obok nie ma jeszcze osiągalnego terenu — np. góra
## sąsiedniego płaskowyżu dopiero dostanie schody; nie zużywa próby).
static func _connect_region(ctx: GenerationContext, region: Dictionary, comps: Array, alive: Array[bool], layout: PlateauLayout, reach: Dictionary, all_mask: Dictionary, allowed: Dictionary, protected: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, lists: Array) -> int:
	var owners := {}
	for c in region:
		if layout.mask.has(c):
			var o := _owner(comps, alive, c)
			if o >= 0:
				owners[o] = true
	# Kawałek może łączyć górę i ziemię (własne schody nieosiągalnego płaskowyżu) — próbujemy obu stron.
	var candidates := 0
	# a) Z góry kawałka w dół, na osiągalny teren obok.
	var near := _near_reach(region, reach)
	if not owners.is_empty() and not near.is_empty():
		for i in owners:
			candidates += 1
			if _connect_near(ctx, comps[i], near, all_mask, allowed, protected, rng, flags, lists, i):
				return CONNECT_ADDED
	# b) Z sąsiedniego płaskowyżu o osiągalnej górze w dół, do ziemi kawałka.
	var near_region := _grow(region, 2)
	for i in range(comps.size()):
		if alive[i] and not owners.has(i) and _top_reached(comps[i], layout, reach) and _touches(comps[i], layout, region):
			candidates += 1
			if _connect_near(ctx, comps[i], near_region, all_mask, allowed, protected, rng, flags, lists, i):
				return CONNECT_ADDED
	return CONNECT_FAILED if candidates > 0 else CONNECT_WAITING


static func _unreached_top(layout: PlateauLayout, reach: Dictionary) -> Dictionary:
	var out := {}
	for c in layout.top:
		if not reach.has(c):
			out[c] = true
	return out


static func _island_key(island: Dictionary) -> Vector2i:
	var best: Vector2i = island.keys()[0]
	for c in island:
		if c.y < best.y or (c.y == best.y and c.x < best.x):
			best = c
	return best


static func _owner(comps: Array, alive: Array[bool], c: Vector2i) -> int:
	for i in range(comps.size()):
		if alive[i] and (comps[i] as Dictionary).has(c):
			return i
	return -1


## Osiągalna ziemia w promieniu 3 od `cells`, poszerzona o 2 — filtr `near` dla schodów.
static func _near_reach(cells: Dictionary, reach: Dictionary) -> Dictionary:
	var close := {}
	for c in cells:
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if reach.has(c + Vector2i(dx, dy)):
					close[c + Vector2i(dx, dy)] = true
	return _grow(close, 2)


static func _grow(cells: Dictionary, r: int) -> Dictionary:
	var out := {}
	for c in cells:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				out[c + Vector2i(dx, dy)] = true
	return out


## Dopisuje parametry mapy wysokości (także do pustego układu — pole istnieje bez płaskowyżu).
static func _with_field(layout: PlateauLayout, ctx: GenerationContext, flags: GenerationFlags) -> PlateauLayout:
	layout.noise_seed = noise_seed_for(ctx.seed_value)
	layout.noise_frequency = flags.plateau_noise_frequency
	layout.noise_octaves = flags.plateau_noise_octaves
	layout.threshold = flags.plateau_threshold
	return layout


# --- Maska --------------------------------------------------------------------------------

## Dozwolone: zwykła podłoga oraz strefy wejścia/wyjścia (portale nie ograniczają płaskowyżu —
## ale każda strefa jest na nim w całości albo wcale, patrz _portals_all_or_nothing).
static func _allowed_cells(ctx: GenerationContext) -> Dictionary:
	var allowed := {}
	for c in ctx.grid:
		var t := int(ctx.grid[c])
		if t == CellType.FLOOR or t == CellType.ENTRANCE or t == CellType.EXIT:
			allowed[c] = true
	return allowed


## Strefy portali (wejście + wyjście) z pierścieniem PORTAL_RING — obszar, którego krawędź
## płaskowyżu nie może przecinać (używany też jako ochrona przed rzeźbieniem schodów).
static func _portal_area(ctx: GenerationContext, allowed: Dictionary) -> Dictionary:
	var area := {}
	for zone in _portal_zones(ctx):
		area.merge(_zone_area(zone, allowed))
	return area


## Strefy portali jako spójne kawałki ctx.portal_zone. W topologii ctx.entrance_zone/exit_zone
## są jeszcze puste (wypełnia je dopiero apply_cave_tiles) — portal_zone jest ustawione od P9.
static func _portal_zones(ctx: GenerationContext) -> Array:
	var out: Array = []
	for comp in _components(ctx.portal_zone, DIRS8):
		out.append((comp as Dictionary).keys())
	return out


static func _zone_area(zone: Array, allowed: Dictionary) -> Dictionary:
	var area := {}
	for c in zone:
		for dy in range(-PORTAL_RING, PORTAL_RING + 1):
			for dx in range(-PORTAL_RING, PORTAL_RING + 1):
				var n: Vector2i = c + Vector2i(dx, dy)
				if allowed.has(n):
					area[n] = true
	return area


## Strefa portalu (wejście / wyjście) + pierścień PORTAL_RING: w całości na płaskowyżu albo wcale,
## żeby krawędź płaskowyżu nie przecinała wnęki portalu. Pokryta >= połowa strefy -> cała.
static func _portals_all_or_nothing(ctx: GenerationContext, mask: Dictionary, allowed: Dictionary) -> Dictionary:
	var m := mask
	for zone in _portal_zones(ctx):
		if (zone as Array).is_empty():
			continue
		var covered := 0
		for c in zone:
			if m.has(c):
				covered += 1
		var area := _zone_area(zone, allowed)
		if covered * 2 >= (zone as Array).size():
			m.merge(area)
		else:
			for c in area:
				m.erase(c)
	return m


## Ziarno mapy wysokości płaskowyżów dla seeda mapy.
static func noise_seed_for(map_seed: int) -> int:
	return hash([map_seed, "plateau"])


## Mapa wysokości płaskowyżów (FBM). Publiczne — podgląd odtwarza nią pole na całej mapie.
static func make_noise(noise_seed: int, frequency: float, octaves: int = 3) -> FastNoiseLite:
	var noise := SeededNoise.create(noise_seed, frequency)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = clampi(octaves, 1, 8)
	return noise


static func _noise_mask(ctx: GenerationContext, flags: GenerationFlags, allowed: Dictionary) -> Dictionary:
	var noise := make_noise(noise_seed_for(ctx.seed_value), flags.plateau_noise_frequency, flags.plateau_noise_octaves)
	var mask := {}
	for c in allowed:
		if noise.get_noise_2d(float(c.x), float(c.y)) > flags.plateau_threshold:
			mask[c] = true
	return mask


static func _clean(ctx: GenerationContext, mask: Dictionary, allowed: Dictionary, min_area: int) -> Dictionary:
	var m := mask
	for _i in range(CLEAN_ITERS):
		var before := m.size()
		m = _erode(ctx, _dilate(m, allowed))   # domknięcie: szczeliny < 3 (też przy ścianach)
		m = _dilate(_erode(ctx, m), allowed)   # otwarcie: wypustki < 3 w otwartym terenie
		m = _fill_holes(ctx, m, allowed)
		m = _drop_small(m, min_area)
		if m.size() == before:
			break
	return m


## Szczelina 1 kratki między płaskowyżem a ścianą (płaskowyż z jednej strony, ściana albo płaskowyż
## dokładnie naprzeciw, także po skosie) -> płaskowyż. Dwa przebiegi (drugi domyka szczeliny powstałe
## w pierwszym), każdy po masce z początku przebiegu — przejścia szersze niż 1 kratka zostają.
static func _fill_wall_gaps(ctx: GenerationContext, m: Dictionary, allowed: Dictionary) -> Dictionary:
	var out := m
	for _pass in range(2):
		var src := out
		out = src.duplicate()
		for c in allowed:
			if src.has(c):
				continue
			for d in DIRS8:
				if src.has(c + d) and (src.has(c - d) or not GridUtils.is_walkable(ctx.grid, c - d)):
					out[c] = true
					break
	# Bez cienkich wypustek (pipeline ścian ich nie narysuje): dołożona kratka zostaje, gdy nie jest cienka.
	for _i in range(3):
		var thin: Array[Vector2i] = []
		for c in out:
			if not m.has(c) and _thin(ctx, out, c):
				thin.append(c)
		if thin.is_empty():
			break
		for c in thin:
			out.erase(c)
	return out


## Kratka maski nie do narysowania: bez ortogonalnego sąsiada w masce albo z ziemią po dwóch
## przeciwnych stronach (1 kratka szerokości).
static func _thin(ctx: GenerationContext, m: Dictionary, c: Vector2i) -> bool:
	var ground := func(n: Vector2i) -> bool: return not m.has(n) and GridUtils.is_walkable(ctx.grid, n)
	if ground.call(c + Vector2i(0, -1)) and ground.call(c + Vector2i(0, 1)):
		return true
	if ground.call(c + Vector2i(-1, 0)) and ground.call(c + Vector2i(1, 0)):
		return true
	for d in DIRS4:
		if m.has(c + d):
			return false
	return true


## Ścina wypustki szerokości 1 (_thin) aż do skutku — np. resztki po wycięciu strefy portalu.
static func _strip_thin(ctx: GenerationContext, m: Dictionary) -> Dictionary:
	var out := m.duplicate()
	for _i in range(8):
		var thin: Array[Vector2i] = []
		for c in out:
			if _thin(ctx, out, c):
				thin.append(c)
		if thin.is_empty():
			break
		for c in thin:
			out.erase(c)
	return out


## Czy rzeźbienie (comp + add - del) zostawi w prostokącie r kratkę-wypustkę szerokości 1.
static func _carve_makes_thin(ctx: GenerationContext, comp: Dictionary, add: Array, del: Array, r: Rect2i) -> bool:
	var after := {}
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			var q := Vector2i(x, y)
			if comp.has(q):
				after[q] = true
	for q in add:
		after[q] = true
	for q in del:
		after.erase(q)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var q := Vector2i(x, y)
			if after.has(q) and _thin(ctx, after, q):
				return true
	return false


## Lite = płaskowyż albo prawdziwa ściana (ściany podpierają płaskowyż przy erozji).
static func _solid(ctx: GenerationContext, m: Dictionary, c: Vector2i) -> bool:
	return m.has(c) or not GridUtils.is_walkable(ctx.grid, c)


static func _erode(ctx: GenerationContext, m: Dictionary) -> Dictionary:
	var out := {}
	for c in m:
		var keep := true
		for d in DIRS8:
			if not _solid(ctx, m, c + d):
				keep = false
				break
		if keep:
			out[c] = true
	return out


static func _dilate(m: Dictionary, allowed: Dictionary) -> Dictionary:
	var out := m.duplicate()
	for c in m:
		for d in DIRS8:
			var n: Vector2i = c + d
			if allowed.has(n):
				out[n] = true
	return out


## Zamknięte kieszenie podłogi (nie największy komponent, ≤ HOLE_MAX, w całości dozwolone) -> płaskowyż.
static func _fill_holes(ctx: GenerationContext, m: Dictionary, allowed: Dictionary) -> Dictionary:
	var ground := {}
	for c in ctx.grid:
		if GridUtils.is_walkable(ctx.grid, c) and not m.has(c):
			ground[c] = true
	var comps := _components(ground, DIRS4)
	var largest := 0
	for comp in comps:
		largest = maxi(largest, (comp as Dictionary).size())
	var out := m.duplicate()
	for comp in comps:
		var size: int = (comp as Dictionary).size()
		if size == largest or size > HOLE_MAX:
			continue
		var ok := true
		for c in comp:
			if not allowed.has(c):
				ok = false
				break
		if ok:
			out.merge(comp)
	return out


static func _drop_small(m: Dictionary, min_area: int) -> Dictionary:
	var out := {}
	for comp in _components(m, DIRS8):
		if (comp as Dictionary).size() >= min_area:
			out.merge(comp)
	return out


static func _components(cells: Dictionary, dirs: Array[Vector2i]) -> Array:
	var out: Array = []
	var seen := {}
	for start in cells:
		if seen.has(start):
			continue
		var comp := {start: true}
		seen[start] = true
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size():
			var p := queue[head]
			head += 1
			for d in dirs:
				var n: Vector2i = p + d
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					comp[n] = true
					queue.append(n)
		out.append(comp)
	return out


# --- Schody ---------------------------------------------------------------------------------

## Komórka lica: płaskowyż z ziemią pod spodem (stopa) i dalej ziemią pod stopą.
static func _is_face(ctx: GenerationContext, comp: Dictionary, c: Vector2i, require_two_deep: bool = true) -> bool:
	if not comp.has(c):
		return false
	var p1 := c + Vector2i(0, 1)
	if comp.has(p1) or not GridUtils.is_walkable(ctx.grid, p1):
		return false
	if require_two_deep:
		var p2 := c + Vector2i(0, 2)
		if comp.has(p2) or not GridUtils.is_walkable(ctx.grid, p2):
			return false
	return true


## Schody na prostych odcinkach lica (biegach komórek lica w jednym wierszu). Z każdego końca
## biegu zostaje STAIR_FLANK kolumn (koniec/moduł IN + ≥1 fasada); nad każdą kolumną schodów
## musi być WNĘTRZE płaskowyżu. Najdłuższe biegi najpierw, jedne schody na bieg.
static func _pick_stairs(ctx: GenerationContext, comp: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, allow_1w: bool = false, limit: int = -1, near: Dictionary = {}) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cap: int = maxi(flags.platform_max_stairs, 1) if limit < 0 else limit
	if cap <= 0:
		return out
	var max_w := maxi(flags.stair_max_width, 2)
	for require_two_deep in [true, false]:
		if not out.is_empty():
			break
		var rows := {}  # y -> Array[x]
		for c in comp:
			if not _is_face(ctx, comp, c, require_two_deep) or not _faces_near(near, c + Vector2i(0, 1)):
				continue
			if not rows.has(c.y):
				rows[c.y] = []
			rows[c.y].append(c.x)

		var runs: Array = []  # [length, a, b, y]
		for y in rows:
			var xs: Array = rows[y]
			xs.sort()
			var a: int = xs[0]
			var prev: int = xs[0]
			for i in range(1, xs.size() + 1):
				var x: int = xs[i] if i < xs.size() else prev + 2
				if x != prev + 1:
					runs.append([prev - a + 1, a, prev, y])
					a = x
				prev = x
		runs.sort_custom(func(r1, r2): return r1[0] > r2[0] or (r1[0] == r2[0] and (r1[3] < r2[3] or (r1[3] == r2[3] and r1[1] < r2[1]))))

		for flank in [STAIR_FLANK, 1]:
			if not out.is_empty():
				break
			for r in runs:
				if out.size() >= cap:
					break
				var y: int = r[3]
				var best_lo := 0
				var best_len := 0
				var cur_lo := 0
				var cur_len := 0
				for x in range(r[1] + flank, r[2] - flank + 1):
					if _is_interior(ctx, comp, Vector2i(x, y - 1)):
						if cur_len == 0:
							cur_lo = x
						cur_len += 1
						if cur_len > best_len:
							best_len = cur_len
							best_lo = cur_lo
					else:
						cur_len = 0
				if allow_1w:
					if best_len < 1:
						continue
					var s: int = 1 if best_len < 2 else rng.randi_range(2, mini(max_w, best_len))
					out.append(Vector3i(rng.randi_range(best_lo, best_lo + best_len - s), s, y))
				else:
					if best_len < 2:
						continue
					var s: int = rng.randi_range(2, mini(max_w, best_len))
					out.append(Vector3i(rng.randi_range(best_lo, best_lo + best_len - s), s, y))
	return out


## Komórka rim lica: płaskowyż z ziemią powyżej (północ).
static func _is_rim_face(ctx: GenerationContext, comp: Dictionary, c: Vector2i, require_two_deep: bool = true) -> bool:
	if not comp.has(c):
		return false
	var p1 := c + Vector2i(0, -1)
	if comp.has(p1) or not GridUtils.is_walkable(ctx.grid, p1):
		return false
	if require_two_deep:
		var p2 := c + Vector2i(0, -2)
		if comp.has(p2) or not GridUtils.is_walkable(ctx.grid, p2):
			return false
	return true


## Schody północne na prostych odcinkach rim lica. Kotwica schodów to linia rim y, schody sięgają
## w górę do y - 1 na ziemię. Pod każdą kolumną schodów musi być WNĘTRZE płaskowyżu w y + 1.
static func _pick_stairs_north(ctx: GenerationContext, comp: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, allow_1w: bool = false, limit: int = -1, near: Dictionary = {}) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cap: int = maxi(flags.platform_max_stairs, 1) if limit < 0 else limit
	if cap <= 0:
		return out
	var max_w := maxi(flags.stair_max_width, 2)
	for require_two_deep in [true, false]:
		if not out.is_empty():
			break
		var rows := {}  # y -> Array[x]
		for c in comp:
			if not _is_rim_face(ctx, comp, c, require_two_deep) or not _faces_near(near, c + Vector2i(0, -1)):
				continue
			if not rows.has(c.y):
				rows[c.y] = []
			rows[c.y].append(c.x)

		var runs: Array = []  # [length, a, b, y]
		for y in rows:
			var xs: Array = rows[y]
			xs.sort()
			var a: int = xs[0]
			var prev: int = xs[0]
			for i in range(1, xs.size() + 1):
				var x: int = xs[i] if i < xs.size() else prev + 2
				if x != prev + 1:
					runs.append([prev - a + 1, a, prev, y])
					a = x
				prev = x
		runs.sort_custom(func(r1, r2): return r1[0] > r2[0] or (r1[0] == r2[0] and (r1[3] < r2[3] or (r1[3] == r2[3] and r1[1] < r2[1]))))

		for flank in [STAIR_FLANK, 1]:
			if not out.is_empty():
				break
			for r in runs:
				if out.size() >= cap:
					break
				var y: int = r[3]
				var best_lo := 0
				var best_len := 0
				var cur_lo := 0
				var cur_len := 0
				for x in range(r[1] + flank, r[2] - flank + 1):
					if _is_interior(ctx, comp, Vector2i(x, y + 1)):
						if cur_len == 0:
							cur_lo = x
						cur_len += 1
						if cur_len > best_len:
							best_len = cur_len
							best_lo = cur_lo
					else:
						cur_len = 0
				if allow_1w:
					if best_len < 1:
						continue
					var s: int = 1 if best_len < 2 else rng.randi_range(2, mini(max_w, best_len))
					out.append(Vector3i(rng.randi_range(best_lo, best_lo + best_len - s), s, y))
				else:
					if best_len < 2:
						continue
					var s: int = rng.randi_range(2, mini(max_w, best_len))
					out.append(Vector3i(rng.randi_range(best_lo, best_lo + best_len - s), s, y))
	return out


## Komórka boku wschodniego: płaskowyż z ziemią na wschód (+x).
static func _is_east_face(ctx: GenerationContext, comp: Dictionary, c: Vector2i, require_two_deep: bool = true) -> bool:
	if not comp.has(c):
		return false
	var p1 := c + Vector2i(1, 0)
	if comp.has(p1) or not GridUtils.is_walkable(ctx.grid, p1):
		return false
	if require_two_deep:
		var p2 := c + Vector2i(2, 0)
		if comp.has(p2) or not GridUtils.is_walkable(ctx.grid, p2):
			return false
	return true


## Komórka boku zachodniego: płaskowyż z ziemią na zachód (-x).
static func _is_west_face(ctx: GenerationContext, comp: Dictionary, c: Vector2i, require_two_deep: bool = true) -> bool:
	if not comp.has(c):
		return false
	var p1 := c + Vector2i(-1, 0)
	if comp.has(p1) or not GridUtils.is_walkable(ctx.grid, p1):
		return false
	if require_two_deep:
		var p2 := c + Vector2i(-2, 0)
		if comp.has(p2) or not GridUtils.is_walkable(ctx.grid, p2):
			return false
	return true


## Schody boczne (wschodnie lub zachodnie) na pionowych krawędziach płaskowyżu.
## Zwraca Vector3i(edge_x, top_y, height), gdzie height to 1 lub 3.
static func _pick_stairs_side(ctx: GenerationContext, comp: Dictionary, rng: RandomNumberGenerator, is_east: bool, flags: GenerationFlags, allow_1h: bool = false, cap: int = -1, near: Dictionary = {}) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var limit: int = maxi(flags.platform_max_stairs / 2, 1) if cap < 0 else cap
	if limit <= 0:
		return out
	for require_two_deep in [true, false]:
		if not out.is_empty():
			break
		var cols := {}  # x -> Array[y]
		for c in comp:
			var ok := _is_east_face(ctx, comp, c, require_two_deep) if is_east else _is_west_face(ctx, comp, c, require_two_deep)
			if not ok or not _faces_near(near, c + Vector2i(1 if is_east else -1, 0)):
				continue
			if not cols.has(c.x):
				cols[c.x] = []
			cols[c.x].append(c.y)

		var runs: Array = []  # [length, a, b, x]
		for x in cols:
			var ys: Array = cols[x]
			ys.sort()
			var a: int = ys[0]
			var prev: int = ys[0]
			for i in range(1, ys.size() + 1):
				var y: int = ys[i] if i < ys.size() else prev + 2
				if y != prev + 1:
					runs.append([prev - a + 1, a, prev, x])
					a = y
				prev = y
		runs.sort_custom(func(r1, r2): return r1[0] > r2[0] or (r1[0] == r2[0] and (r1[3] < r2[3] or (r1[3] == r2[3] and r1[1] < r2[1]))))

		var interior_dx: int = -1 if is_east else 1
		for flank in [STAIR_FLANK, 1]:
			if not out.is_empty():
				break
			for r in runs:
				if out.size() >= limit:
					break
				var x: int = r[3]
				var best_lo := 0
				var best_len := 0
				var cur_lo := 0
				var cur_len := 0
				for y in range(r[1] + flank, r[2] - flank + 1):
					if _is_interior(ctx, comp, Vector2i(x + interior_dx, y)):
						if cur_len == 0:
							cur_lo = y
						cur_len += 1
						if cur_len > best_len:
							best_len = cur_len
							best_lo = cur_lo
					else:
						cur_len = 0
				if allow_1h:
					if best_len < 1:
						continue
					var height := 1 if best_len < 3 else 3
					var top_y := rng.randi_range(best_lo, best_lo + best_len - height)
					out.append(Vector3i(x, top_y, height))
				else:
					if best_len < 3:
						continue
					var height := 3
					var top_y := rng.randi_range(best_lo, best_lo + best_len - height)
					out.append(Vector3i(x, top_y, height))
	return out


## Brak miejsca na schody -> wyrzeźbij je: najtańsze okno STAIR_SITE_W kolumn wokół komórki lica,
## wyrównane do jednego wiersza y (bryła w y-2..y, ziemia w y+1..y+2). Dodawane komórki muszą być
## dozwolone i nie dotykać innych płaskowyżów. Zwraca true, gdy komponent zmieniono.
static func _carve_stair_site(ctx: GenerationContext, comp: Dictionary, all_mask: Dictionary, allowed: Dictionary, protected: Dictionary = {}, near: Dictionary = {}) -> bool:
	var best_cost := 1 << 30
	var best_add: Array = []
	var best_del: Array = []
	for site_w in [STAIR_SITE_W, STAIR_SITE_W_MIN]:
		if best_cost != 1 << 30:
			break
		for c in comp:
			var foot: Vector2i = c + Vector2i(0, 1)
			if comp.has(foot) or not GridUtils.is_walkable(ctx.grid, foot) or not _faces_near(near, foot):
				continue
			for k in range(site_w):
				var add: Array = []
				var del: Array = []
				var ok := true
				for x in range(c.x - k, c.x - k + site_w):
					for dy in [-2, -1, 0]:
						var p := Vector2i(x, c.y + dy)
						if comp.has(p) or (dy == -2 and not GridUtils.is_walkable(ctx.grid, p)):
							continue
						if not allowed.has(p) or protected.has(p) or _near_other(all_mask, comp, p):
							ok = false
							break
						add.append(p)
					if not ok:
						break
					for dy in [1, 2]:
						var p := Vector2i(x, c.y + dy)
						if not GridUtils.is_walkable(ctx.grid, p) or (all_mask.has(p) and not comp.has(p)):
							ok = false
							break
						if comp.has(p):
							if protected.has(p):
								ok = false
								break
							del.append(p)
					if not ok:
						break
				if ok and _carve_makes_thin(ctx, comp, add, del, Rect2i(c.x - k - 1, c.y - 3, site_w + 2, 7)):
					ok = false  # okno zostawiłoby wypustkę szerokości 1 (np. kratkę obok wyciętej ziemi)
				var cost := add.size() + del.size()
				if ok and cost < best_cost:
					best_cost = cost
					best_add = add
					best_del = del
	if best_cost == 1 << 30:
		return false
	for p in best_add:
		comp[p] = true
		all_mask[p] = true
	for p in best_del:
		comp.erase(p)
		all_mask.erase(p)
	return true


## Brak miejsca na schody północne -> wyrzeźbij je w rimie: najtańsze okno STAIR_SITE_W kolumn wokół
## komórki rim lica (bryła w y..y+2, ziemia w y-2..y-1).
static func _carve_stair_site_north(ctx: GenerationContext, comp: Dictionary, all_mask: Dictionary, allowed: Dictionary, protected: Dictionary = {}, near: Dictionary = {}) -> bool:
	var best_cost := 1 << 30
	var best_add: Array = []
	var best_del: Array = []
	for site_w in [STAIR_SITE_W, STAIR_SITE_W_MIN]:
		if best_cost != 1 << 30:
			break
		for c in comp:
			var head: Vector2i = c + Vector2i(0, -1)
			if comp.has(head) or not GridUtils.is_walkable(ctx.grid, head) or not _faces_near(near, head):
				continue
			for k in range(site_w):
				var add: Array = []
				var del: Array = []
				var ok := true
				for x in range(c.x - k, c.x - k + site_w):
					for dy in [0, 1, 2]:
						var p := Vector2i(x, c.y + dy)
						if comp.has(p) or (dy == 2 and not GridUtils.is_walkable(ctx.grid, p)):
							continue
						if not allowed.has(p) or protected.has(p) or _near_other(all_mask, comp, p):
							ok = false
							break
						add.append(p)
					if not ok:
						break
					for dy in [-1, -2]:
						var p := Vector2i(x, c.y + dy)
						if not GridUtils.is_walkable(ctx.grid, p) or (all_mask.has(p) and not comp.has(p)):
							ok = false
							break
						if comp.has(p):
							if protected.has(p):
								ok = false
								break
							del.append(p)
					if not ok:
						break
				if ok and _carve_makes_thin(ctx, comp, add, del, Rect2i(c.x - k - 1, c.y - 3, site_w + 2, 7)):
					ok = false  # okno zostawiłoby wypustkę szerokości 1 (np. kratkę obok wyciętej ziemi)
				var cost := add.size() + del.size()
				if ok and cost < best_cost:
					best_cost = cost
					best_add = add
					best_del = del
	if best_cost == 1 << 30:
		return false
	for p in best_add:
		comp[p] = true
		all_mask[p] = true
	for p in best_del:
		comp.erase(p)
		all_mask.erase(p)
	return true


## Czy p (lub jego 8-sąsiad) należy do INNEGO płaskowyżu niż comp.
static func _near_other(all_mask: Dictionary, comp: Dictionary, p: Vector2i) -> bool:
	for d in DIRS8 + [Vector2i.ZERO]:
		var n: Vector2i = p + d
		if all_mask.has(n) and not comp.has(n):
			return true
	return false


## Wnętrze płaskowyżu: należy do komponentu i nie ma ortogonalnej ziemi obok.
static func _is_interior(ctx: GenerationContext, comp: Dictionary, c: Vector2i) -> bool:
	if not comp.has(c):
		return false
	for d in DIRS4:
		var n: Vector2i = c + d
		if GridUtils.is_walkable(ctx.grid, n) and not comp.has(n):
			return false
	return true


## Drobne kieszonki odciętej ziemi (≤ POCKET_MAX, np. zamknięte między barierami) przy blokującym
## komponencie -> jego płaskowyż; nie przy schodach (ich flanki muszą zostać licem) ani portalach.
static func _absorb_pockets(ctx: GenerationContext, comps: Array, blockers: Array[int], all_mask: Dictionary, allowed: Dictionary, protected: Dictionary, cut_ground: Dictionary, layout: PlateauLayout, lists: Array) -> bool:
	var absorbed := false
	for region in _components(cut_ground, DIRS4):
		if (region as Dictionary).size() > POCKET_MAX:
			continue
		for i in blockers:
			if not _touches(comps[i], layout, region):
				continue
			var guard := _stair_zone(lists, i, 1)
			var ok := true
			for c in region:
				if not allowed.has(c) or protected.has(c) or guard.has(c):
					ok = false
					break
			if ok:
				var grown: Dictionary = (comps[i] as Dictionary).duplicate()
				grown.merge(region)
				for c in region:
					if _thin(ctx, grown, c):
						ok = false
						break
			if ok:
				(comps[i] as Dictionary).merge(region)
				all_mask.merge(region)
				absorbed = true
			break
	return absorbed


## Dziury po łataniu maski: małe (≤ POCKET_MAX) grupy podłogi zamknięte ortogonalnie płaskowyżem
## lub ścianą -> płaskowyż. Były barierami/nieosiągalne, więc łączność się nie zmienia.
## Nie przy schodach ani portalach.
static func _seal_holes(ctx: GenerationContext, comps: Array, alive: Array[bool], layout: PlateauLayout, protected: Dictionary, lists: Array) -> bool:
	var sealed := false
	var seen := {}
	for start in layout.blocked.keys():
		if layout.mask.has(start) or seen.has(start):
			continue
		# Flood po podłodze spoza maski; za duże = otwarta ziemia, nie dziura.
		var hole := {start: true}
		seen[start] = true
		var queue: Array[Vector2i] = [start]
		var owner := -1
		var closed := true
		while not queue.is_empty():
			var p: Vector2i = queue.pop_back()
			for d in DIRS4:
				var n: Vector2i = p + d
				if layout.mask.has(n):
					if owner < 0:
						for k in range(comps.size()):
							if alive[k] and (comps[k] as Dictionary).has(n):
								owner = k
								break
				elif GridUtils.is_walkable(ctx.grid, n) and not hole.has(n):
					hole[n] = true
					seen[n] = true
					queue.append(n)
			if hole.size() > POCKET_MAX:
				closed = false
				break
		if not closed or owner < 0:
			continue
		var guard := _stair_zone(lists, owner, 2)
		var ok := true
		for c in hole:
			if protected.has(c) or guard.has(c):
				ok = false
				break
		if ok:
			(comps[owner] as Dictionary).merge(hole)
			sealed = true
	return sealed


## Filtr pickerów: pusty `near` = bez ograniczeń.
static func _faces_near(near: Dictionary, outer: Vector2i) -> bool:
	return near.is_empty() or near.has(outer)


## Jedne schody, których zewnętrzna strona trafia w `near`: pełne (S, N, E, W) -> wyrzeźbione miejsce
## na pełne (z dala od istniejących schodów — ich flanki muszą zostać licem) -> wąskie 1W / 1H.
static func _connect_near(ctx: GenerationContext, comp: Dictionary, near: Dictionary, all_mask: Dictionary, allowed: Dictionary, protected: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, lists: Array, i: int) -> bool:
	if _pick_any(ctx, comp, rng, flags, false, near, lists, i):
		return true
	var guard := protected.duplicate()
	guard.merge(_stair_zone(lists, i, 2))
	if _carve_stair_site(ctx, comp, all_mask, allowed, guard, near) \
			and _add_first(_pick_stairs(ctx, comp, rng, flags, false, PICK_CANDIDATES, near), lists, 0, i):
		return true
	if _carve_stair_site_north(ctx, comp, all_mask, allowed, guard, near) \
			and _add_first(_pick_stairs_north(ctx, comp, rng, flags, false, PICK_CANDIDATES, near), lists, 1, i):
		return true
	return _pick_any(ctx, comp, rng, flags, true, near, lists, i)


## Pierwsze pasujące schody w kolejności S, N, E, W (relaxed = flanka 1, dopuszczalne 1W / 1H).
static func _pick_any(ctx: GenerationContext, comp: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, relaxed: bool, near: Dictionary, lists: Array, i: int) -> bool:
	return (_add_first(_pick_stairs(ctx, comp, rng, flags, relaxed, PICK_CANDIDATES, near), lists, 0, i)
			or _add_first(_pick_stairs_north(ctx, comp, rng, flags, relaxed, PICK_CANDIDATES, near), lists, 1, i)
			or _add_first(_pick_stairs_side(ctx, comp, rng, true, flags, relaxed, PICK_CANDIDATES, near), lists, 2, i)
			or _add_first(_pick_stairs_side(ctx, comp, rng, false, flags, relaxed, PICK_CANDIDATES, near), lists, 3, i))


## Pierwszy kandydat (od najdłuższego biegu lica), który nie koliduje z istniejącymi schodami.
static func _add_first(cands: Array[Vector3i], lists: Array, dir: int, i: int) -> bool:
	for c in cands:
		var one: Array[Vector3i] = [c]
		if _add_new(one, lists, dir, i):
			return true
	return false


## Dopisuje kandydata do listy kierunku `dir` (0 S, 1 N, 2 E, 3 W) komponentu i. Schody tego samego
## kierunku: odstęp ≥ 1 kratki (ich flanki muszą zostać licem); innego kierunku (inne lico): byle
## się nie nakładały.
static func _add_new(cand: Array[Vector3i], lists: Array, dir: int, i: int) -> bool:
	if cand.is_empty():
		return false
	var one: Array = [[[]], [[]], [[]], [[]]]
	one[dir] = [[cand[0]]]
	var mine := _stair_zone(one, 0, 0)
	for k in 4:
		var only: Array = [[[]], [[]], [[]], [[]]]
		only[k] = [lists[k][i]]
		var taken := _stair_zone(only, 0, 1 if k == dir else 0)
		for c in mine:
			if taken.has(c):
				return false
	var l: Array = (lists[dir][i] as Array).duplicate()
	l.append(cand[0])
	lists[dir][i] = l
	return true


## Komórki schodów komponentu i (listy [S, N, E, W] per komponent) poszerzone o `margin`.
static func _stair_zone(lists: Array, i: int, margin: int) -> Dictionary:
	var tmp := PlateauLayout.new()
	tmp.stairs.assign(lists[0][i])
	tmp.stairs_north.assign(lists[1][i])
	tmp.stairs_east.assign(lists[2][i])
	tmp.stairs_west.assign(lists[3][i])
	var out := {}
	for c in tmp.stair_cells():
		for dy in range(-margin, margin + 1):
			for dx in range(-margin, margin + 1):
				out[c + Vector2i(dx, dy)] = true
	return out


# --- Złożenie i spójność --------------------------------------------------------------------

static func _assemble(ctx: GenerationContext, comps: Array, comp_stairs_south: Array, comp_stairs_north: Array, comp_stairs_east: Array, comp_stairs_west: Array, alive: Array[bool], min_area: int = 0) -> PlateauLayout:
	var layout := PlateauLayout.new()
	for i in range(comps.size()):
		if alive[i]:
			layout.mask.merge(comps[i])
			for st in comp_stairs_south[i]:
				layout.stairs.append(st)
			for st in comp_stairs_north[i]:
				layout.stairs_north.append(st)
			for st in comp_stairs_east[i]:
				layout.stairs_east.append(st)
			for st in comp_stairs_west[i]:
				layout.stairs_west.append(st)
	if min_area > 0:
		layout.mask = _drop_small(layout.mask, min_area)
		# Schody odrzuconych kawałków znikają razem z nimi (strona płaskowyżu musi być w masce).
		layout.stairs = layout.stairs.filter(func(st): return layout.mask.has(Vector2i(st.x, st.z)))
		layout.stairs_north = layout.stairs_north.filter(func(st): return layout.mask.has(Vector2i(st.x, st.z)))
		layout.stairs_east = layout.stairs_east.filter(func(st): return layout.mask.has(Vector2i(st.x, st.y)))
		layout.stairs_west = layout.stairs_west.filter(func(st): return layout.mask.has(Vector2i(st.x, st.y)))
	# Bariery: komórki płaskowyżu z ortogonalną ziemią obok + stopy lica.
	for c in layout.mask:
		for d in DIRS4:
			var n: Vector2i = c + d
			if GridUtils.is_walkable(ctx.grid, n) and not layout.mask.has(n):
				layout.blocked[c] = true
				if d == Vector2i(0, 1):
					layout.blocked[n] = true
	for c in layout.stair_cells():
		layout.blocked.erase(c)
	for c in layout.mask:
		if not layout.blocked.has(c):
			layout.top[c] = true
	return layout


static func _bfs(ctx: GenerationContext, start: Vector2i, blocked: Dictionary) -> Dictionary:
	var seen := {}
	if not GridUtils.is_walkable(ctx.grid, start) or blocked.has(start):
		return seen
	seen[start] = true
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = p + d
			if not seen.has(n) and not blocked.has(n) and GridUtils.is_walkable(ctx.grid, n):
				seen[n] = true
				queue.append(n)
	return seen


## Czy jakakolwiek komórka góry komponentu jest osiągalna (schody prowadzą na górę).
static func _top_reached(comp: Dictionary, layout: PlateauLayout, reach: Dictionary) -> bool:
	for c in comp:
		if layout.top.has(c) and reach.has(c):
			return true
	return false


## Czy bariery komponentu (jego komórki-bariery i stopy lica pod nim) sąsiadują z `cells`.
static func _touches(comp: Dictionary, layout: PlateauLayout, cells: Dictionary) -> bool:
	for c in comp:
		for b in [c, c + Vector2i(0, 1), c + Vector2i(0, -1), c + Vector2i(1, 0), c + Vector2i(-1, 0)]:
			if not layout.blocked.has(b):
				continue
			for d in DIRS4:
				if cells.has(b + d):
					return true
	return false
