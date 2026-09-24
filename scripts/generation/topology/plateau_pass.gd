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
## przy ścianach), schody na prostych odcinkach lica, naprawa spójności przez usuwanie
## komponentów. Grid zostaje FLOOR — płaskowyż to nakładka. Własne ziarna z seeda mapy.

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const CLEAN_ITERS := 3
const HOLE_MAX := 40          # zamknięte kieszenie podłogi do tej wielkości są zasypywane
const MAX_REPAIR_ITERS := 16
const STAIR_FLANK := 2        # od końca biegu lica: kolumna końca + ≥1 kolumna fasady
const STAIR_SITE_W := 6       # okno rzeźbionego miejsca na schody: 2*STAIR_FLANK + 2 stopnie
const MAX_PASSAGE_ITERS := 24 # ile przełęczy maksymalnie przekopać przez płaskowyże


static func run(ctx: GenerationContext, flags: GenerationFlags) -> PlateauLayout:
	if flags == null or not flags.enable_platforms or ctx.entrance_pos == Vector2i.ZERO:
		return null

	var allowed := _allowed_cells(ctx, flags.plateau_portal_margin)
	var mask := _noise_mask(ctx, flags, allowed)
	mask = _clean(ctx, mask, allowed, flags.plateau_min_area)
	if mask.is_empty():
		return _with_field(PlateauLayout.new(), ctx, flags)

	var baseline := _bfs(ctx, ctx.entrance_pos, {})

	var comps := _components(mask, DIRS8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "plateau_stairs"])
	var comp_stairs_south: Array = []
	var comp_stairs_north: Array = []
	var comp_stairs_east: Array = []
	var comp_stairs_west: Array = []
	for comp in comps:
		var ss := _pick_stairs(ctx, comp, rng, flags, false)
		var sn := _pick_stairs_north(ctx, comp, rng, flags, false)
		var se := _pick_stairs_side(ctx, comp, rng, true, flags, false)
		var sw := _pick_stairs_side(ctx, comp, rng, false, flags, false)
		comp_stairs_south.append(ss)
		comp_stairs_north.append(sn)
		comp_stairs_east.append(se)
		comp_stairs_west.append(sw)

	var alive: Array[bool] = []
	alive.resize(comps.size())
	alive.fill(true)

	var test_layout := _assemble(ctx, comps, comp_stairs_south, comp_stairs_north, comp_stairs_east, comp_stairs_west, alive, flags.plateau_min_area)
	var initial_reach := _bfs(ctx, ctx.entrance_pos, test_layout.blocked)
	var initial_cut := {}
	for c in baseline:
		if not initial_reach.has(c) and not test_layout.blocked.has(c) and not test_layout.mask.has(c):
			initial_cut[c] = true

	for i in range(comps.size()):
		var ss: Array = comp_stairs_south[i]
		var sn: Array = comp_stairs_north[i]
		var se: Array = comp_stairs_east[i]
		var sw: Array = comp_stairs_west[i]
		var has_any := not ss.is_empty() or not sn.is_empty() or not se.is_empty() or not sw.is_empty()
		var touches_cut := not initial_cut.is_empty() and _touches(comps[i], test_layout, initial_cut)

		# Schody 1 width (i 1H boku) tworzą się tylko gdy 2W się nie mieszczą,
		# a bez nich przejście byłoby niemożliwe (komponent odcina ziemię).
		if not has_any and touches_cut:
			if ss.is_empty(): ss = _pick_stairs(ctx, comps[i], rng, flags, true)
			if ss.is_empty() and sn.is_empty(): sn = _pick_stairs_north(ctx, comps[i], rng, flags, true)
			if ss.is_empty() and sn.is_empty() and se.is_empty(): se = _pick_stairs_side(ctx, comps[i], rng, true, flags, true)
			if ss.is_empty() and sn.is_empty() and se.is_empty() and sw.is_empty(): sw = _pick_stairs_side(ctx, comps[i], rng, false, flags, true)
			if ss.is_empty() and sn.is_empty() and se.is_empty() and sw.is_empty():
				if _carve_stair_site(ctx, comps[i], mask, allowed):
					ss = _pick_stairs(ctx, comps[i], rng, flags, false)
				if ss.is_empty() and _carve_stair_site_north(ctx, comps[i], mask, allowed):
					sn = _pick_stairs_north(ctx, comps[i], rng, flags, false)
			comp_stairs_south[i] = ss
			comp_stairs_north[i] = sn
			comp_stairs_east[i] = se
			comp_stairs_west[i] = sw
		elif has_any and touches_cut:
			if ss.is_empty(): ss = _pick_stairs(ctx, comps[i], rng, flags, true)
			if sn.is_empty(): sn = _pick_stairs_north(ctx, comps[i], rng, flags, true)
			if se.is_empty(): se = _pick_stairs_side(ctx, comps[i], rng, true, flags, true)
			if sw.is_empty(): sw = _pick_stairs_side(ctx, comps[i], rng, false, flags, true)
			comp_stairs_south[i] = ss
			comp_stairs_north[i] = sn
			comp_stairs_east[i] = se
			comp_stairs_west[i] = sw

	var layout: PlateauLayout = null
	for _iter in range(MAX_REPAIR_ITERS):
		layout = _assemble(ctx, comps, comp_stairs_south, comp_stairs_north, comp_stairs_east, comp_stairs_west, alive, flags.plateau_min_area)
		var reach := _bfs(ctx, ctx.entrance_pos, layout.blocked)
		# Ziemia odcięta przez płaskowyż (była osiągalna, nie jest barierą ani płaskowyżem).
		var cut_ground := {}
		for c in baseline:
			if not reach.has(c) and not layout.blocked.has(c) and not layout.mask.has(c):
				cut_ground[c] = true
		var blockers: Array[int] = []
		var unreachable_top: Array[int] = []
		for i in range(comps.size()):
			if not alive[i]:
				continue
			if not cut_ground.is_empty() and _touches(comps[i], layout, cut_ground):
				blockers.append(i)
			elif ((comp_stairs_south[i] as Array).is_empty() and (comp_stairs_north[i] as Array).is_empty() and (comp_stairs_east[i] as Array).is_empty() and (comp_stairs_west[i] as Array).is_empty()) or not _top_reached(comps[i], layout, reach):
				unreachable_top.append(i)
		# Najpierw usuwamy blokujących — odblokowanie może naprawić resztę.
		var drop: Array[int] = blockers if not blockers.is_empty() else unreachable_top
		if drop.is_empty():
			# Resztki góry bez dojścia (np. za wąskim przesmykiem) -> bariera: żadnych spawnów tam.
			for c in layout.top.keys():
				if not reach.has(c):
					layout.top.erase(c)
					layout.blocked[c] = true
			return _with_field(layout, ctx, flags)
		for i in drop:
			alive[i] = false
	layout = _assemble(ctx, comps, comp_stairs_south, comp_stairs_north, comp_stairs_east, comp_stairs_west, alive, flags.plateau_min_area)
	return _with_field(layout, ctx, flags)


## Dopisuje parametry mapy wysokości (także do pustego układu — pole istnieje bez płaskowyżu).
static func _with_field(layout: PlateauLayout, ctx: GenerationContext, flags: GenerationFlags) -> PlateauLayout:
	layout.noise_seed = noise_seed_for(ctx.seed_value)
	layout.noise_frequency = flags.plateau_noise_frequency
	layout.noise_octaves = flags.plateau_noise_octaves
	layout.threshold = flags.plateau_threshold
	return layout


# --- Maska --------------------------------------------------------------------------------

## Zwykła podłoga (bez portali/drzwi) dalej niż `margin` od strefy portali.
static func _allowed_cells(ctx: GenerationContext, margin: int) -> Dictionary:
	var forbidden := {}
	for p in ctx.portal_zone:
		for dy in range(-margin, margin + 1):
			for dx in range(-margin, margin + 1):
				forbidden[p + Vector2i(dx, dy)] = true
	var allowed := {}
	for c in ctx.grid:
		if int(ctx.grid[c]) == CellType.FLOOR and not forbidden.has(c):
			allowed[c] = true
	return allowed


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


# --- Przełęcze ----------------------------------------------------------------------------

## Płaskowyż od północy ma tylko rim (bez zejścia), więc ziemia musi pozostać spójna BEZ płaskowyżów.
## Gdy jakaś podłoga jest odcięta, przekopujemy najtańszą przełęcz (BFS 0-1: wejście w płaskowyż
## lub jego stopę kosztuje 1) z osiągalnej ziemi do odciętej — pas szerokości 3 — i czyścimy resztki.
static func _open_passages(ctx: GenerationContext, mask: Dictionary, allowed: Dictionary, baseline: Dictionary, min_area: int) -> Dictionary:
	var m := mask
	for _iter in range(MAX_PASSAGE_ITERS):
		var walls := _mask_with_feet(ctx, m)
		var reach := _bfs(ctx, ctx.entrance_pos, walls)
		var cut := {}
		for c in baseline:
			if not reach.has(c) and not walls.has(c):
				cut[c] = true
		if cut.is_empty():
			return m
		var crossing := _cheapest_crossing(ctx, reach, cut, walls)
		if crossing.is_empty():
			return m
		for p in crossing:
			for d in DIRS8 + [Vector2i.ZERO]:
				m.erase(p + d)
		m = _drop_small(_dilate(_erode(ctx, m), allowed), min_area)
	return m


## Płaskowyż + stopy lica (ziemia bezpośrednio pod płaskowyżem).
static func _mask_with_feet(ctx: GenerationContext, m: Dictionary) -> Dictionary:
	var out := m.duplicate()
	for c in m:
		var foot: Vector2i = c + Vector2i(0, 1)
		if not m.has(foot) and GridUtils.is_walkable(ctx.grid, foot):
			out[foot] = true
	return out


## BFS 0-1 po podłodze: start = osiągalna ziemia, cel = dowolna odcięta komórka; wejście w `walls`
## kosztuje 1. Zwraca komórki `walls` na najtańszej ścieżce (do usunięcia).
static func _cheapest_crossing(ctx: GenerationContext, reach: Dictionary, cut: Dictionary, walls: Dictionary) -> Array[Vector2i]:
	var parent := {}
	var cur: Array[Vector2i] = []
	for c in reach:
		parent[c] = c
		cur.append(c)
	var goal := Vector2i(-1, -1)
	while not cur.is_empty() and goal == Vector2i(-1, -1):
		var nxt: Array[Vector2i] = []
		var head := 0
		while head < cur.size():
			var p := cur[head]
			head += 1
			if cut.has(p):
				goal = p
				break
			for d in DIRS4:
				var n: Vector2i = p + d
				if parent.has(n) or not GridUtils.is_walkable(ctx.grid, n):
					continue
				parent[n] = p
				if walls.has(n):
					nxt.append(n)   # koszt +1 -> następna warstwa
				else:
					cur.append(n)   # koszt 0 -> ta sama warstwa
		cur = nxt
	var out: Array[Vector2i] = []
	if goal == Vector2i(-1, -1):
		return out
	var c := goal
	while parent[c] != c:
		if walls.has(c):
			out.append(c)
		c = parent[c]
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
static func _pick_stairs(ctx: GenerationContext, comp: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, allow_1w: bool = false) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var max_w := maxi(flags.stair_max_width, 2)
	for require_two_deep in [true, false]:
		if not out.is_empty():
			break
		var rows := {}  # y -> Array[x]
		for c in comp:
			if not _is_face(ctx, comp, c, require_two_deep):
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
				if out.size() >= maxi(flags.platform_max_stairs, 1):
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
					var s: int = 1
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
static func _pick_stairs_north(ctx: GenerationContext, comp: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, allow_1w: bool = false) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var max_w := maxi(flags.stair_max_width, 2)
	for require_two_deep in [true, false]:
		if not out.is_empty():
			break
		var rows := {}  # y -> Array[x]
		for c in comp:
			if not _is_rim_face(ctx, comp, c, require_two_deep):
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
				if out.size() >= maxi(flags.platform_max_stairs, 1):
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
					var s: int = 1
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
static func _pick_stairs_side(ctx: GenerationContext, comp: Dictionary, rng: RandomNumberGenerator, is_east: bool, flags: GenerationFlags, allow_1h: bool = false) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var limit := maxi(flags.platform_max_stairs / 2, 1)
	for require_two_deep in [true, false]:
		if not out.is_empty():
			break
		var cols := {}  # x -> Array[y]
		for c in comp:
			var ok := _is_east_face(ctx, comp, c, require_two_deep) if is_east else _is_west_face(ctx, comp, c, require_two_deep)
			if not ok:
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
					var height := 1
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
static func _carve_stair_site(ctx: GenerationContext, comp: Dictionary, all_mask: Dictionary, allowed: Dictionary) -> bool:
	var best_cost := 1 << 30
	var best_add: Array = []
	var best_del: Array = []
	for c in comp:
		var foot: Vector2i = c + Vector2i(0, 1)
		if comp.has(foot) or not GridUtils.is_walkable(ctx.grid, foot):
			continue
		for k in range(STAIR_SITE_W):
			var add: Array = []
			var del: Array = []
			var ok := true
			for x in range(c.x - k, c.x - k + STAIR_SITE_W):
				for dy in [-2, -1, 0]:
					var p := Vector2i(x, c.y + dy)
					if comp.has(p) or (dy == -2 and not GridUtils.is_walkable(ctx.grid, p)):
						continue
					if not allowed.has(p) or _near_other(all_mask, comp, p):
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
						del.append(p)
				if not ok:
					break
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
static func _carve_stair_site_north(ctx: GenerationContext, comp: Dictionary, all_mask: Dictionary, allowed: Dictionary) -> bool:
	var best_cost := 1 << 30
	var best_add: Array = []
	var best_del: Array = []
	for c in comp:
		var head: Vector2i = c + Vector2i(0, -1)
		if comp.has(head) or not GridUtils.is_walkable(ctx.grid, head):
			continue
		for k in range(STAIR_SITE_W):
			var add: Array = []
			var del: Array = []
			var ok := true
			for x in range(c.x - k, c.x - k + STAIR_SITE_W):
				for dy in [0, 1, 2]:
					var p := Vector2i(x, c.y + dy)
					if comp.has(p) or (dy == 2 and not GridUtils.is_walkable(ctx.grid, p)):
						continue
					if not allowed.has(p) or _near_other(all_mask, comp, p):
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
						del.append(p)
				if not ok:
					break
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
