class_name PlateauPass
extends RefCounted


## Topologia wysokości terenu: płaskowyże (1, 2…) i zagłębienia (-1…) z jednego pola szumu, maska z szumu na podłodze całej mapy, czyszczona
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
const SLOT_ITERS := 4         # w tylu pierwszych iteracjach naprawy zasypywane są szczeliny/wypustki
const STAIR_GAP := 6          # min. odstęp (kratki) między schodami — różnych kawałków i poziomów też
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
	var thr := _thresholds(ctx, flags, allowed)
	var mask := _noise_mask(ctx, flags, allowed, thr.level)
	mask = _clean(ctx, mask, allowed, flags.plateau_min_area, flags.plateau_smooth)
	mask = _fill_wall_gaps(ctx, mask, allowed)
	mask = _portals_all_or_nothing(ctx, mask, allowed)
	mask = _strip_thin(ctx, mask)
	mask = _drop_small(mask, flags.plateau_min_area)
	var levels := {}
	if not mask.is_empty():
		levels[1] = mask
	_add_upper_levels(ctx, flags, allowed, levels, thr.high)
	_add_pits(ctx, flags, allowed, levels, thr.pit)
	var layout := _with_field(solve_levels(ctx, flags, levels), ctx, flags)
	layout.threshold = thr.level  # podgląd rysuje pasma pola tymi progami
	layout.high_threshold = thr.high
	layout.pit_threshold = thr.pit
	layout.level_step = flags.plateau_level_step
	layout.level_count = flags.plateau_levels
	layout.pit_count = flags.plateau_pit_levels
	return layout


## Progi pola wysokości dla tej mapy. Udział > 0 (plateau_coverage / _high_ / _pit_) -> próg z kwantyla
## wartości szumu na podłodze tej mapy: każda mapa ma podobne proporcje, niezależnie od tego, czy
## szum (przy niskiej częstotliwości zmienia się wolniej niż rozmiar mapy) wypadł na niej wysoko,
## czy nisko. Udział 0 -> stały próg z konfiguracji (plateau_threshold itd.).
static func _thresholds(ctx: GenerationContext, flags: GenerationFlags, allowed: Dictionary) -> Dictionary:
	var out := {
		"level": flags.plateau_threshold,
		"high": flags.plateau_threshold + flags.plateau_level_step,
		"pit": -flags.plateau_pit_threshold,
	}
	if flags.plateau_coverage <= 0.0 and flags.plateau_high_coverage <= 0.0 and flags.plateau_pit_coverage <= 0.0:
		return out
	var noise := make_noise(noise_seed_for(ctx.seed_value), flags.plateau_noise_frequency, flags.plateau_noise_octaves)
	var vals := PackedFloat32Array()
	vals.resize(allowed.size())
	var i := 0
	for c in allowed:
		vals[i] = sample_height(noise, c, flags.plateau_block)
		i += 1
	vals.sort()
	if vals.is_empty():
		return out
	# Wysoki kwantyl -> próg, powyżej którego leży `share` podłogi (niski kwantyl dla dołów).
	var above := func(share: float) -> float: return vals[clampi(int((1.0 - share) * vals.size()), 0, vals.size() - 1)]
	if flags.plateau_coverage > 0.0:
		out.level = above.call(flags.plateau_coverage)
	if flags.plateau_high_coverage > 0.0:
		out.high = maxf(above.call(flags.plateau_high_coverage), out.level)
	else:
		out.high = out.level + flags.plateau_level_step
	if flags.plateau_pit_coverage > 0.0:
		out.pit = minf(vals[clampi(int(flags.plateau_pit_coverage * vals.size()), 0, vals.size() - 1)], out.level)
	return out


## Poziomy 2, 3…: wyższe pasmo tego samego szumu (próg + (k-1)·step), ale tylko wewnątrz poziomu
## niżej zwężonego o plateau_level_ring — zawsze zostaje półka niższego poziomu (bez klifów o dwa
## poziomy, kafle poziomów się nie nakładają). Portal może leżeć na dowolnym poziomie — w całości.
static func _add_upper_levels(ctx: GenerationContext, flags: GenerationFlags, allowed: Dictionary, levels: Dictionary, high_threshold: float) -> void:
	if flags.plateau_levels < 2 or not levels.has(1):
		return
	var noise := make_noise(noise_seed_for(ctx.seed_value), flags.plateau_noise_frequency, flags.plateau_noise_octaves)
	var ring := maxi(flags.plateau_level_ring, 2)
	for k in range(2, flags.plateau_levels + 1):
		var room := _erode_n(ctx, levels[k - 1], ring)
		var mk := _band(noise, room, high_threshold + (k - 2) * flags.plateau_level_step, true, flags.plateau_block)
		mk = _level_shape(ctx, mk, room, flags.plateau_min_area, flags.plateau_smooth)
		if mk.is_empty():
			return
		levels[k] = mk


## Zagłębienia -1, -2…: szum poniżej -plateau_pit_threshold (głębsze: o step niżej), z dala
## (plateau_level_ring) od płaskowyżów; głębszy dół wewnątrz płytszego zwężonego o ring. Portal może
## leżeć w dole — w całości (jak na płaskowyżu).
## Zapis jak dla płaskowyżów: levels[0] = podłoga bez dołów -1 („ziemia nad dołem”), levels[-1] =
## podłoga bez dołów -2 itd. — krawędzie dołu to krawędzie tego „płaskowyżu” ziemi.
static func _add_pits(ctx: GenerationContext, flags: GenerationFlags, allowed: Dictionary, levels: Dictionary, pit_threshold: float) -> void:
	if flags.plateau_pit_levels < 1:
		return
	var noise := make_noise(noise_seed_for(ctx.seed_value), flags.plateau_noise_frequency, flags.plateau_noise_octaves)
	var ring := maxi(flags.plateau_level_ring, 2)
	var room := allowed.duplicate()
	for c in _grow(levels.get(1, {}), ring):
		room.erase(c)
	for j in range(1, flags.plateau_pit_levels + 1):
		var dj := _band(noise, room, pit_threshold - (j - 1) * flags.plateau_level_step, false, flags.plateau_block)
		dj = _level_shape(ctx, dj, room, flags.plateau_min_area, flags.plateau_smooth)
		if dj.is_empty():
			break
		var ground := allowed.duplicate()
		for c in dj:
			ground.erase(c)
		levels[1 - j] = ground
		room = _erode_n(ctx, dj, ring)


## Kratki `cells`, gdzie szum > próg (above) albo < próg.
static func _band(noise: FastNoiseLite, cells: Dictionary, threshold: float, above: bool, block: int = 1) -> Dictionary:
	var out := {}
	for c in cells:
		var v := sample_height(noise, c, block)
		if (v > threshold) if above else (v < threshold):
			out[c] = true
	return out


## Kształt poziomu jak dla płaskowyżu 1: czyszczenie, szczeliny przy ścianach, portale w całości
## albo wcale, bez wypustek, min. pole.
static func _level_shape(ctx: GenerationContext, m: Dictionary, room: Dictionary, min_area: int, smooth: int = 1) -> Dictionary:
	var out := _clean(ctx, m, room, min_area, smooth)
	out = _fill_wall_gaps(ctx, out, room)
	out = _portals_all_or_nothing(ctx, out, room)
	out = _strip_thin(ctx, out)
	return _drop_small(out, min_area)


## Erozja n razy (ściany liczą się jako lite — wyższy poziom może dochodzić do ścian).
static func _erode_n(ctx: GenerationContext, m: Dictionary, n: int) -> Dictionary:
	var out := m
	for _i in range(n):
		out = _erode(ctx, out)
	return out


## Schody + osiągalność dla gotowej maski płaskowyżu (jeden poziom) — testy scenariuszowe.
static func solve_mask(ctx: GenerationContext, flags: GenerationFlags, mask: Dictionary) -> PlateauLayout:
	return solve_levels(ctx, flags, {1: mask} if not mask.is_empty() else {})


## Schody + osiągalność dla gotowych poziomów (levels[k] = kratki o wysokości >= k; k >= 1 płaskowyże,
## k <= 0 ziemia nad zagłębieniami) — run() i testy scenariuszowe z ręcznie zadanymi poziomami.
static func solve_levels(ctx: GenerationContext, flags: GenerationFlags, levels: Dictionary) -> PlateauLayout:
	if levels.is_empty():
		return PlateauLayout.new()
	var allowed := _allowed_cells(ctx)
	var lv := {}
	for k in levels:
		lv[k] = (levels[k] as Dictionary).duplicate()
	var layout := _solve(ctx, flags, lv, allowed)
	# Portal na płaskowyżu, do którego nie da się dojść (brak miejsca na schody) -> wytnij jego
	# obszar (strefa + pierścień) z płaskowyżów i policz jeszcze raz. Krawędź ląduje poza pierścieniem.
	var bad := _unreached_portal_area(ctx, layout, allowed)
	if not bad.is_empty():
		var lv2 := {}
		for k in layout.levels:
			var m: Dictionary = (layout.levels[k] as Dictionary).duplicate()
			for c in bad:
				if k >= 1:
					m.erase(c)
				elif allowed.has(c):
					m[c] = true  # dół nigdy nie zabiera portalu
			if k >= 1:
				m = _drop_small(_strip_thin(ctx, m), flags.plateau_min_area)
			if not m.is_empty():
				lv2[k] = m
		layout = _solve(ctx, flags, lv2, allowed)
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


## Schody + osiągalność na polu wysokości. Zasada: po złożeniu układu cały chodliwy teren (każda
## wysokość) ma być osiągalny z wejścia po rzeczywistych zasadach ruchu — bariery (kratka wyżej niż
## ortogonalny sąsiad: rim, bok, lico; plus stopa lica) blokują, schody są jedynym przejściem
## i łączą tylko SĄSIEDNIE wysokości (_bfs po layout.blocked). Kawałki („pieces”) to spójne
## obszary wysokości >= k dla każdego poziomu k; schody należą do kawałka i schodzą z k na k-1.
## Nie ma wymogu ścieżki po samej podłodze ani schodów na każdym kawałku:
## - obszar osiągalny (schody z budżetu, portal na górze, schody z wyższego poziomu) nie dostaje nic,
## - nieosiągalny kawałek terenu na wysokości h dostaje schody: ze swojego kawałka w dół na h-1 albo
##   z kawałka poziomu h+1 w dół do niego; dowolna strona (S, N, E, W; w razie potrzeby wyrzeźbione
##   miejsce) — _connect_region. Trasa 0 -> 1 -> 2 powstaje kolejnymi iteracjami.
## - gdy schodów nie da się postawić nigdzie (jawnie, jak dotąd w generatorze): drobna kieszeń
##   ziemi -> płaskowyż, płaskowyż odcinający ziemię -> usunięty, dół bez dojścia -> zasypany,
##   nieosiągalna góra -> bariera (wzniesienie zostaje, tylko nikt tam nie trafia). Liczniki w PlateauLayout.
static func _solve(ctx: GenerationContext, flags: GenerationFlags, levels: Dictionary, allowed: Dictionary) -> PlateauLayout:
	var keys: Array = levels.keys()
	keys.sort()
	var lo: int = mini(int(keys[0]) - 1, 0)
	var hi: int = maxi(int(keys.back()), 0)
	var ring := maxi(flags.plateau_level_ring, 2)
	var portal := _portal_area(ctx, allowed)  # rzeźbienie schodów nie rusza portali

	# Na poziom: gdzie kawałek może urosnąć (add_ok) i czego nie może oddać (guard: portale i pierścień
	# wokół poziomu wyżej — inaczej niższy poziom podszedłby pod wyższy o więcej niż 1).
	var add_ok := {}
	var guard := {}
	var guard_base := {}
	for k in keys:
		if k >= 2:
			add_ok[k] = _erode_n(ctx, levels[k - 1], ring)
		elif k == 1 and levels.has(0):
			var ok1 := allowed.duplicate()
			for c in allowed:
				if not (levels[0] as Dictionary).has(c):
					for q in _grow({c: true}, ring):
						ok1.erase(q)
			add_ok[k] = ok1
		else:
			add_ok[k] = allowed
		var g := portal.duplicate()
		if levels.has(k + 1):
			g.merge(_grow(levels[k + 1], ring))
		guard_base[k] = g.duplicate()
		if k <= 0:
			# Ziemia nad dołem: rzeźbienie schodów może dół zasypać (dodać ziemię), ale nie kopać
			# nowego dołu w ziemi — inaczej powstają języki ziemi i kieszenie w dole.
			g.merge(levels[k])
		guard[k] = g

	var comps: Array = []
	var comp_level: Array[int] = []
	for k in keys:
		for comp in _components(levels[k], DIRS8):
			comps.append(comp)
			comp_level.append(k)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "plateau_stairs"])
	# Schody „z wyglądu”: każdy kawałek losuje ich liczbę z 0..platform_max_stairs (S, potem N, E, W;
	# szerokość też losowa, 2..stair_max_width). Dostępność zapewnia dopiero naprawa niżej — kawałek,
	# który wylosował za mało (albo 0), dostaje dokładnie tyle schodów, ile trzeba do dojścia.
	var max_budget := maxi(flags.platform_max_stairs, 0)
	var comp_stairs_south: Array = []
	var comp_stairs_north: Array = []
	var comp_stairs_east: Array = []
	var comp_stairs_west: Array = []
	var spaced := {}  # kratki schodów wszystkich kawałków poszerzone o STAIR_GAP (rozstaw)
	for comp in comps:
		var budget := rng.randi_range(0, max_budget)
		var got: Array = [[], [], [], []]
		if budget > 0:
			# Kandydaci z każdego lica (jedni na bieg lica, najdłuższe biegi najpierw), brani na zmianę
			# S, N, E, W od losowego kierunku — schody lądują na różnych krawędziach, z odstępem.
			var picks: Array = [
				_pick_stairs(ctx, comp, rng, flags, false, budget),
				_pick_stairs_north(ctx, comp, rng, flags, false, budget),
				_pick_stairs_side(ctx, comp, rng, true, flags, false, budget),
				_pick_stairs_side(ctx, comp, rng, false, flags, false, budget),
			]
			var idx := [0, 0, 0, 0]
			var start := rng.randi() % 4
			var n := 0
			var progress := true
			while n < budget and progress:
				progress = false
				for t in 4:
					var d: int = (start + t) % 4
					while int(idx[d]) < (picks[d] as Array).size():
						var st: Vector3i = picks[d][idx[d]]
						idx[d] = int(idx[d]) + 1
						if _cells_free(_one_stair_cells(d, st), spaced):
							(got[d] as Array).append(st)
							_mark_spaced(spaced, d, st)
							n += 1
							progress = true
							break
					if n >= budget:
						break
		comp_stairs_south.append(_as_v3(got[0]))
		comp_stairs_north.append(_as_v3(got[1]))
		comp_stairs_east.append(_as_v3(got[2]))
		comp_stairs_west.append(_as_v3(got[3]))

	var alive: Array[bool] = []
	alive.resize(comps.size())
	alive.fill(true)
	var lists := [comp_stairs_south, comp_stairs_north, comp_stairs_east, comp_stairs_west]
	# Kratki, które mogą być dołem: pierwotne doły (rzeźbienie ich nie kopie) + obniżone wypustki.
	var pit_cells := {}
	if levels.has(0):
		for c in allowed:
			if not (levels[0] as Dictionary).has(c):
				pit_cells[c] = true
	var env := {"levels": levels, "add_ok": add_ok, "guard": guard, "guard_base": guard_base, "comp_level": comp_level, "lo": lo, "hi": hi, "allowed": allowed, "pit_cells": pit_cells}

	# Teren, który ma być osiągalny: spójny z wejściem w gridzie (bez wysokości) — sam grid, nie
	# warunek ścieżki; komórki odcięte już w topologii nie są problemem wysokości.
	var walkable_area := _bfs(ctx, ctx.entrance_pos, {})
	var tried := {}           # klucz nieosiągalnego kawałka -> liczba prób schodów
	var connect_added := 0
	var dropped := 0
	var layout: PlateauLayout = null
	for _iter in range(MAX_REPAIR_ITERS):
		layout = _assemble(ctx, comps, lists, alive, env, flags.plateau_min_area)
		if _iter < SLOT_ITERS and _fill_slots(ctx, comps, alive, layout, env, lists):
			layout = _assemble(ctx, comps, lists, alive, env, flags.plateau_min_area)
		var reach := _bfs(ctx, ctx.entrance_pos, layout.blocked)
		var unreached := {}
		for c in walkable_area:
			if not reach.has(c) and not layout.blocked.has(c):
				unreached[c] = true
		if unreached.is_empty():
			break

		# 1. Schody do każdego nieosiągalnego kawałka (z jego poziomu w dół albo z poziomu wyżej).
		var added := 0
		for region in _components(unreached, DIRS4):
			var key := _island_key(region)
			if int(tried.get(key, 0)) >= REGION_TRIES:
				continue
			var r := _connect_region(ctx, region, comps, alive, layout, reach, env, rng, flags, lists)
			if r == CONNECT_ADDED:
				added += 1
			elif r == CONNECT_FAILED:
				tried[key] = int(tried.get(key, 0)) + 1  # próba nieudana (brak miejsca na schody)
		if added > 0:
			connect_added += added
			continue

		# 2. Schodów nie da się postawić — jawna obsługa (jak dotąd w generatorze).
		#    Ziemia odcięta przez płaskowyż: drobna kieszeń -> płaskowyż, inaczej płaskowyż usunięty.
		var ground := {}
		var sunk := {}
		for c in unreached:
			var h := layout.height_of(c)
			if h == 0:
				ground[c] = true
			elif h < 0:
				sunk[c] = true
		var blockers: Array[int] = []
		for i in range(comps.size()):
			if alive[i] and comp_level[i] == 1 and not ground.is_empty() and _touches(comps[i], layout, ground):
				blockers.append(i)
		if not blockers.is_empty():
			if _absorb_pockets(ctx, comps, blockers, levels.get(1, {}), add_ok.get(1, allowed), guard.get(1, portal), ground, layout, lists):
				continue
			for i in blockers:
				alive[i] = false
			dropped += blockers.size()
			continue
		#    Dół bez dojścia -> zasypany (kratki dołu wchodzą do kawałka ziemi, który go otacza).
		if not sunk.is_empty() and _fill_pits(ctx, comps, alive, layout, env, sunk):
			dropped += 1
			continue
		break  # zostały tylko nieosiągalne góry -> bariera przy domknięciu niżej

	layout = _assemble(ctx, comps, lists, alive, env, flags.plateau_min_area)
	var reach_final := _bfs(ctx, ctx.entrance_pos, layout.blocked)
	if _seal_holes(ctx, comps, alive, layout, guard.get(1, portal), lists, comp_level):
		layout = _assemble(ctx, comps, lists, alive, env, flags.plateau_min_area)
		reach_final = _bfs(ctx, ctx.entrance_pos, layout.blocked)
	for _pass in range(3):
		if not _fill_slots(ctx, comps, alive, layout, env, lists, true):
			break
		layout = _assemble(ctx, comps, lists, alive, env, flags.plateau_min_area)
		reach_final = _bfs(ctx, ctx.entrance_pos, layout.blocked)
	# Teren bez dojścia, dla którego nie było miejsca na schody -> bariera (żadnych spawnów tam):
	# góry płaskowyżów oraz (gdy są doły) wszystko poza zwykłą ziemią.
	var lost := {}
	for c in walkable_area:
		if reach_final.has(c) or layout.blocked.has(c):
			continue
		var h := layout.height_of(c)
		if h != 0 or lo < 0:
			lost[c] = true
	for c in lost:
		layout.top.erase(c)
		layout.blocked[c] = true
	layout.connect_stairs = connect_added
	layout.dropped_pieces = dropped
	layout.unreachable_top = lost.size()
	return layout


## Schody dla nieosiągalnego kawałka terenu `region` (spójny kawałek nieosiągniętych, chodliwych
## kratek; może łączyć kilka wysokości przez własne schody):
## a) kratki kawałka będące górą kawałka poziomu h -> schody z niego w dół, na osiągalny teren obok,
## b) kawałek poziomu h+1 o osiągalnej górze, który dotyka kawałka -> schody z niego w dół do kawałka.
## Strona schodów dowolna (S, N, E, W). Zwraca CONNECT_ADDED / CONNECT_FAILED (był osiągalny sąsiad,
## ale nie ma miejsca na schody) / CONNECT_WAITING (obok nie ma jeszcze osiągalnego terenu — np. poziom
## niżej dopiero dostanie schody; nie zużywa próby).
static func _connect_region(ctx: GenerationContext, region: Dictionary, comps: Array, alive: Array[bool], layout: PlateauLayout, reach: Dictionary, env: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, lists: Array) -> int:
	var comp_level: Array[int] = env.comp_level
	var heights := {}
	var owners := {}
	for c in region:
		var h := layout.height_of(c)
		heights[h] = true
		if h > int(env.lo):
			var o := _owner_at(comps, comp_level, alive, c, h)
			if o >= 0:
				owners[o] = true
	var candidates := 0
	# a) Z góry kawałka w dół, na osiągalny teren obok.
	var near := _near_reach(region, reach)
	if not owners.is_empty() and not near.is_empty():
		for i in owners:
			candidates += 1
			if _connect_piece(ctx, comps, i, near, env, rng, flags, lists):
				return CONNECT_ADDED
	# b) Z sąsiedniego kawałka poziomu h+1 o osiągalnej górze w dół, do kawałka.
	var near_region := _grow(region, 2)
	for i in range(comps.size()):
		if not alive[i] or owners.has(i) or not heights.has(comp_level[i] - 1):
			continue
		if _top_reached(comps[i], layout, reach, comp_level[i]) and _touches(comps[i], layout, region):
			candidates += 1
			if _connect_piece(ctx, comps, i, near_region, env, rng, flags, lists):
				return CONNECT_ADDED
	return CONNECT_FAILED if candidates > 0 else CONNECT_WAITING


## _connect_near z parametrami poziomu kawałka i.
static func _connect_piece(ctx: GenerationContext, comps: Array, i: int, near: Dictionary, env: Dictionary, rng: RandomNumberGenerator, flags: GenerationFlags, lists: Array) -> bool:
	var k: int = (env.comp_level as Array)[i]
	return _connect_near(ctx, comps[i], near, (env.levels as Dictionary)[k], (env.add_ok as Dictionary)[k], (env.guard as Dictionary)[k], rng, flags, lists, i)


## Dół bez dojścia (brak miejsca na schody) -> zasypany: jego kratki dołączają do kawałka ziemi
## poziomu wyżej, który go otacza. True, gdy coś zasypano.
static func _fill_pits(_ctx: GenerationContext, comps: Array, alive: Array[bool], layout: PlateauLayout, env: Dictionary, sunk: Dictionary) -> bool:
	var comp_level: Array[int] = env.comp_level
	var filled := false
	for region in _components(sunk, DIRS8):
		var h := layout.height_of((region as Dictionary).keys()[0])
		for i in range(comps.size()):
			if alive[i] and comp_level[i] == h + 1 and _touches(comps[i], layout, region):
				(comps[i] as Dictionary).merge(region)
				((env.levels as Dictionary)[h + 1] as Dictionary).merge(region)
				filled = true
				break
	return filled


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


## Kawałek poziomu `level` zawierający c (-1 gdy brak).
static func _owner_at(comps: Array, comp_level: Array[int], alive: Array[bool], c: Vector2i, level: int) -> int:
	for i in range(comps.size()):
		if alive[i] and comp_level[i] == level and (comps[i] as Dictionary).has(c):
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
	layout.noise_block = flags.plateau_block
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


## Dozwolone kratki (jak _allowed_cells) w otoczeniu PORTAL_RING strefy — bez przeglądania całej mapy.
static func _allowed_near(ctx: GenerationContext, zone: Array) -> Dictionary:
	var out := {}
	for c in zone:
		for dy in range(-PORTAL_RING, PORTAL_RING + 1):
			for dx in range(-PORTAL_RING, PORTAL_RING + 1):
				var n: Vector2i = c + Vector2i(dx, dy)
				var t := int(ctx.grid.get(n, CellType.WALL))
				if t == CellType.FLOOR or t == CellType.ENTRANCE or t == CellType.EXIT:
					out[n] = true
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


## Strefa portalu (wejście / wyjście) + pierścień PORTAL_RING: w całości w masce poziomu albo wcale,
## żeby krawędź poziomu (płaskowyżu, wyższego piętra, dołu) nie przecinała wnęki portalu. Pokryta
## >= połowa strefy i cały obszar mieści się w `room` (miejscu poziomu) -> cała.
static func _portals_all_or_nothing(ctx: GenerationContext, mask: Dictionary, room: Dictionary) -> Dictionary:
	var m := mask
	for zone in _portal_zones(ctx):
		if (zone as Array).is_empty():
			continue
		var covered := 0
		for c in zone:
			if m.has(c):
				covered += 1
		var area := _zone_area(zone, _allowed_near(ctx, zone))
		var fits := true
		for c in area:
			if not room.has(c):
				fits = false
				break
		if fits and covered * 2 >= (zone as Array).size():
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


static func _noise_mask(ctx: GenerationContext, flags: GenerationFlags, allowed: Dictionary, threshold: float) -> Dictionary:
	var noise := make_noise(noise_seed_for(ctx.seed_value), flags.plateau_noise_frequency, flags.plateau_noise_octaves)
	var mask := {}
	for c in allowed:
		if sample_height(noise, c, flags.plateau_block) > threshold:
			mask[c] = true
	return mask


## Wysokość pola w kratce c. block > 1: jedna próbka na blok block×block (środek bloku) — proste
## krawędzie i kąty proste (tarasy); 1 = próbka w każdej kratce. Publiczne — podgląd mapy wysokości.
static func sample_height(noise: FastNoiseLite, c: Vector2i, block: int = 1) -> float:
	if block <= 1:
		return noise.get_noise_2d(float(c.x), float(c.y))
	var bx := floori(float(c.x) / block) * block
	var by := floori(float(c.y) / block) * block
	return noise.get_noise_2d(bx + block * 0.5, by + block * 0.5)


## Czyszczenie maski: domknięcie i otwarcie z promieniem `radius` (1 = szczeliny/wypustki < 3;
## większy = gładsze, bardziej regularne brzegi), zasypanie kieszeni, min. powierzchnia.
static func _clean(ctx: GenerationContext, mask: Dictionary, allowed: Dictionary, min_area: int, radius: int = 1) -> Dictionary:
	var m := mask
	var r := maxi(radius, 1)
	for _i in range(CLEAN_ITERS):
		var before := m.size()
		m = _erode_n(ctx, _dilate_n(m, allowed, r), r)   # domknięcie (też przy ścianach)
		m = _dilate_n(_erode_n(ctx, m, r), allowed, r)   # otwarcie (wypustki w otwartym terenie)
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
			if not after.has(q) and GridUtils.is_walkable(ctx.grid, q) and _slot(after, q):
				return true  # szczelina szerokości 1 wcięta w kawałek
	return false


## Szczelina: kratka spoza m z kratkami m po obu przeciwnych stronach (1 kratka szerokości/wysokości).
static func _slot(m: Dictionary, c: Vector2i) -> bool:
	return (m.has(c + Vector2i(0, -1)) and m.has(c + Vector2i(0, 1))) \
		or (m.has(c + Vector2i(-1, 0)) and m.has(c + Vector2i(1, 0)))


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


static func _dilate_n(m: Dictionary, allowed: Dictionary, n: int) -> Dictionary:
	var out := m
	for _i in range(n):
		out = _dilate(out, allowed)
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
				var seg := _best_segment(ctx, comp, r[1], r[2], y, false, Vector2i(0, -1), flank)
				var best_lo: int = seg.x
				var best_len: int = seg.y
				if allow_1w:
					if best_len < 1:
						continue
					var s: int = 1 if best_len < 2 else _stair_width(rng, max_w, best_len)
					out.append(Vector3i(rng.randi_range(best_lo, best_lo + best_len - s), s, y))
				else:
					if best_len < 2:
						continue
					var s: int = _stair_width(rng, max_w, best_len)
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
				var seg := _best_segment(ctx, comp, r[1], r[2], y, false, Vector2i(0, 1), flank)
				var best_lo: int = seg.x
				var best_len: int = seg.y
				if allow_1w:
					if best_len < 1:
						continue
					var s: int = 1 if best_len < 2 else _stair_width(rng, max_w, best_len)
					out.append(Vector3i(rng.randi_range(best_lo, best_lo + best_len - s), s, y))
				else:
					if best_len < 2:
						continue
					var s: int = _stair_width(rng, max_w, best_len)
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
	var limit: int = maxi(floori(flags.platform_max_stairs / 2.0), 1) if cap < 0 else cap
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
				var seg := _best_segment(ctx, comp, r[1], r[2], x, true, Vector2i(interior_dx, 0), flank)
				var best_lo: int = seg.x
				var best_len: int = seg.y
				if allow_1h:
					if best_len < 1:
						continue
					var height := 1 if best_len < 3 else _side_height(rng, flags, best_len)
					var top_y := rng.randi_range(best_lo, best_lo + best_len - height)
					out.append(Vector3i(x, top_y, height))
				else:
					if best_len < 3:
						continue
					var height := _side_height(rng, flags, best_len)
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
static func _seal_holes(ctx: GenerationContext, comps: Array, alive: Array[bool], layout: PlateauLayout, protected: Dictionary, lists: Array, comp_level: Array[int]) -> bool:
	var sealed := false
	var seen := {}
	for start in layout.blocked.keys():
		if layout.height_of(start) != 0 or seen.has(start):
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
				if layout.height_of(n) == 1:
					if owner < 0:
						owner = _owner_at(comps, comp_level, alive, n, 1)
				elif layout.height_of(n) == 0 and GridUtils.is_walkable(ctx.grid, n) and not hole.has(n):
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


## Kształt po naprawie: szczeliny i wypustki szerokości 1 między poziomami (np. wcięcie w lico po
## rzeźbieniu, kanał albo język ziemi przy dole). Kratka wysokości h
## - z wyższym terenem po obu przeciwnych stronach -> dołącza do kawałka poziomu h+1,
## - z niższym terenem po obu przeciwnych stronach -> odpada z kawałka poziomu h (obniżona o 1).
## Nie przy samych schodach (flanki, margines 1) ani w strefie ochronnej (portale, pierścień wyższego
## poziomu). True, gdy coś zmieniono.
static func _fill_slots(ctx: GenerationContext, comps: Array, alive: Array[bool], layout: PlateauLayout, env: Dictionary, _lists: Array, protect_flanks: bool = false) -> bool:
	var comp_level: Array[int] = env.comp_level
	var guard: Dictionary = env.guard_base
	var changed := false
	var cand := {}
	for c in layout.heights:
		for d in DIRS4:
			cand[c + d] = true
		cand[c] = true
	var pairs := [[Vector2i(0, -1), Vector2i(0, 1)], [Vector2i(-1, 0), Vector2i(1, 0)]]
	# Ochrona schodów (faktycznie postawionych): przy obniżaniu schody + 1 kratka dookoła (flanki
	# muszą zostać licem); przy zasypywaniu tylko same schody i kratka za stopą (zejście zostaje wolne)
	# — zasypana szczelina obok schodów to zwykle właśnie brakujący kawałek lica przy flance.
	var near_stairs := {}
	var keep_free := {}
	for sc in layout.stair_cells():
		keep_free[sc] = true
		for d in DIRS8 + [Vector2i.ZERO]:
			near_stairs[sc + d] = true
	for pair in layout.stair_pairs():
		var foot: Vector2i = pair[1]
		keep_free[foot + (foot - (pair[0] as Vector2i))] = true  # kratka za stopą, w kierunku zejścia
	if protect_flanks:
		# Końcowe domknięcie: nie psujemy już flank postawionych schodów (brak kolejnej naprawy).
		var lst := [layout.stairs, layout.stairs_north, layout.stairs_east, layout.stairs_west]
		for dir in 4:
			for st in lst[dir]:
				for fo in _stair_flanks(dir, st):
					keep_free[fo[0]] = true
					keep_free[(fo[0] as Vector2i) + (fo[1] as Vector2i)] = true
	for c in cand:
		if not GridUtils.is_walkable(ctx.grid, c):
			continue
		var h := layout.height_of(c)
		var up := -1    # kawałek poziomu h+1 do dołączenia
		var down := -1  # kawałek poziomu h, z którego kratka odpada
		for pr in pairs:
			var a: Vector2i = c + pr[0]
			var b: Vector2i = c + pr[1]
			if not (GridUtils.is_walkable(ctx.grid, a) and GridUtils.is_walkable(ctx.grid, b)):
				continue
			if layout.height_of(a) > h and layout.height_of(b) > h:
				up = _owner_at(comps, comp_level, alive, a, h + 1)
				if up < 0:
					up = _owner_at(comps, comp_level, alive, b, h + 1)
				break
			if layout.height_of(a) < h and layout.height_of(b) < h and h > int(env.lo):
				down = _owner_at(comps, comp_level, alive, c, h)
				break
		if up >= 0:
			if (guard.get(h + 1, {}) as Dictionary).has(c) or keep_free.has(c):
				continue
			(comps[up] as Dictionary)[c] = true
			((env.levels as Dictionary)[h + 1] as Dictionary)[c] = true
			changed = true
		elif down >= 0:
			if (guard.get(h, {}) as Dictionary).has(c) or near_stairs.has(c):
				continue
			(comps[down] as Dictionary).erase(c)
			((env.levels as Dictionary)[h] as Dictionary).erase(c)
			if h <= 0:
				(env.pit_cells as Dictionary)[c] = true
			changed = true
	return changed


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
	if cands.is_empty():
		return false
	# Najpierw z rozstawem STAIR_GAP od schodów wszystkich kawałków, potem (gdy trzeba dla dojścia) bliżej.
	var spaced := {}
	for k in 4:
		for j in range((lists[k] as Array).size()):
			for st in lists[k][j]:
				_mark_spaced(spaced, k, st)
	for c in cands:
		if _cells_free(_one_stair_cells(dir, c), spaced):
			var one: Array[Vector3i] = [c]
			if _add_new(one, lists, dir, i):
				return true
	for c in cands:
		var one: Array[Vector3i] = [c]
		if _add_new(one, lists, dir, i):
			return true
	return false


## Kratki jednych schodów (kierunek dir).
static func _one_stair_cells(dir: int, st: Vector3i) -> Array[Vector2i]:
	var tmp := PlateauLayout.new()
	var lst: Array = [tmp.stairs, tmp.stairs_north, tmp.stairs_east, tmp.stairs_west]
	(lst[dir] as Array).append(st)
	return tmp.stair_cells()


static func _cells_free(cells: Array[Vector2i], zone: Dictionary) -> bool:
	for c in cells:
		if zone.has(c):
			return false
	return true


## Zaznacza schody w strefie rozstawu (kratki + STAIR_GAP dookoła).
static func _mark_spaced(zone: Dictionary, dir: int, st: Vector3i) -> void:
	for c in _one_stair_cells(dir, st):
		for dy in range(-STAIR_GAP, STAIR_GAP + 1):
			for dx in range(-STAIR_GAP, STAIR_GAP + 1):
				zone[c + Vector2i(dx, dy)] = true


static func _as_v3(a: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(a)
	return out


## Najdłuższy ciąg kratek biegu lica [a..b] (wiersz/kolumna `fixed`), nad którymi (inner) jest wnętrze
## kawałka — z flanką `flank` od każdego końca (0 przy ścianie). Gdy flanka > 1, sprawdzamy też flankę 1
## i bierzemy ją, jeśli schody wyjdą co najmniej o 2 szersze (krótkie lica przy tarasach z bloków).
## Zwraca Vector2i(początek, długość).
static func _best_segment(ctx: GenerationContext, comp: Dictionary, a: int, b: int, fixed: int, vertical: bool, inner: Vector2i, flank: int) -> Vector2i:
	var best := _segment_with_flank(ctx, comp, a, b, fixed, vertical, inner, flank)
	if flank > 1:
		var alt := _segment_with_flank(ctx, comp, a, b, fixed, vertical, inner, 1)
		if alt.y >= best.y + 2:
			best = alt
	return best


static func _segment_with_flank(ctx: GenerationContext, comp: Dictionary, a: int, b: int, fixed: int, vertical: bool, inner: Vector2i, flank: int) -> Vector2i:
	var before := Vector2i(fixed, a - 1) if vertical else Vector2i(a - 1, fixed)
	var after := Vector2i(fixed, b + 1) if vertical else Vector2i(b + 1, fixed)
	var best_lo := 0
	var best_len := 0
	var cur_lo := 0
	var cur_len := 0
	for t in range(a + _end_flank(ctx, before, flank), b - _end_flank(ctx, after, flank) + 1):
		var c := Vector2i(fixed, t) if vertical else Vector2i(t, fixed)
		if _is_interior(ctx, comp, c + inner):
			if cur_len == 0:
				cur_lo = t
			cur_len += 1
			if cur_len > best_len:
				best_len = cur_len
				best_lo = cur_lo
		else:
			cur_len = 0
	return Vector2i(best_lo, best_len)


## Flanka przy końcu biegu lica: 0, gdy za końcem jest ściana jaskini (wzniesienie wchodzi w ścianę,
## lico ciągnie się pod nią — schody mogą iść od ściany do ściany), inaczej `flank` (róg/moduł IN).
static func _end_flank(ctx: GenerationContext, beyond: Vector2i, flank: int) -> int:
	return 0 if not GridUtils.is_walkable(ctx.grid, beyond) else flank


## Wysokość schodów bocznych (E/W): >= 3 (góra + środek + dół modułu), dłuższe dokładają wierszy
## środkowych — jak szerokość S/N, z górnej części tego, co mieści bok (do stair_max_width).
static func _side_height(rng: RandomNumberGenerator, flags: GenerationFlags, best_len: int) -> int:
	var hi := mini(maxi(flags.stair_max_width, 3), best_len)
	var lo := maxi(3, ceili(hi * 2.0 / 3.0))
	return rng.randi_range(mini(lo, hi), hi)


## Szerokość schodów: z górnej części tego, co mieści lico (2..stair_max_width) — szerokie schody.
static func _stair_width(rng: RandomNumberGenerator, max_w: int, best_len: int) -> int:
	var hi := mini(max_w, best_len)
	var lo := maxi(2, ceili(hi * 2.0 / 3.0))
	return rng.randi_range(mini(lo, hi), hi)


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

## Składa układ z żywych kawałków: poziomy (zagnieżdżone: poziom k tylko wewnątrz k-1), wysokości,
## schody łączące sąsiednie wysokości, bariery (kratka wyżej niż ortogonalny sąsiad + stopa lica).
static func _assemble(ctx: GenerationContext, comps: Array, lists: Array, alive: Array[bool], env: Dictionary, min_area: int = 0) -> PlateauLayout:
	var comp_level: Array[int] = env.comp_level
	var lo: int = env.lo
	var hi: int = env.hi
	var layout := PlateauLayout.new()
	layout.min_level = lo
	layout.max_level = hi
	for k in range(lo + 1, hi + 1):
		var m := {}
		for i in range(comps.size()):
			if alive[i] and comp_level[i] == k:
				m.merge(comps[i])
		if k >= 1 and min_area > 0:
			m = _drop_small(m, min_area)
		if k <= 0 and min_area > 0:
			# Dół (podłoga poza „ziemią nad dołem”) mniejszy niż min_area -> zasypany, jak małe płaskowyże.
			var sunk := {}
			for c in env.pit_cells:
				if not m.has(c):
					sunk[c] = true
			for comp in _components(sunk, DIRS8):
				if (comp as Dictionary).size() < min_area:
					m.merge(comp)
		if k > lo + 1 and layout.levels.has(k - 1):
			var nested := {}
			var below: Dictionary = layout.levels[k - 1]
			for c in m:
				if below.has(c):
					nested[c] = true
			m = nested
		layout.levels[k] = m
	layout.mask = layout.levels.get(1, {})
	for k in range(1, hi + 1):
		for c in layout.levels[k]:
			layout.heights[c] = k
	if lo < 0:
		for c in env.pit_cells:
			var h := lo
			for k in range(lo + 1, 1):
				if (layout.levels[k] as Dictionary).has(c):
					h = k
				else:
					break
			if h < 0:
				layout.heights[c] = h
	# Schody żywych kawałków, o ile nadal łączą sąsiednie wysokości (góra = stopa + 1).
	var targets := [layout.stairs, layout.stairs_north, layout.stairs_east, layout.stairs_west]
	for i in range(comps.size()):
		if not alive[i]:
			continue
		for dir in 4:
			for st in lists[dir][i]:
				if _stair_ok(ctx, layout, dir, st):
					(targets[dir] as Array).append(st)
	# Bariery: kratka wyżej niż chodliwy sąsiad ortogonalny; kratka pod nią od południa to stopa lica.
	var cand := {}
	for c in layout.heights:
		cand[c] = true
		if int(layout.heights[c]) < 0:
			for d in DIRS4:
				cand[c + d] = true
	for c in cand:
		var hc := layout.height_of(c)
		for d in DIRS4:
			var n: Vector2i = c + d
			if GridUtils.is_walkable(ctx.grid, n) and layout.height_of(n) < hc:
				layout.blocked[c] = true
				if d == Vector2i(0, 1):
					layout.blocked[n] = true
	for c in layout.stair_cells():
		layout.blocked.erase(c)
	for c in layout.mask:
		if not layout.blocked.has(c):
			layout.top[c] = true
	return layout


## Czy schody (kierunek dir: 0 S, 1 N, 2 E, 3 W) łączą górę i stopę o wysokościach różnych o 1.
static func _stair_ok(ctx: GenerationContext, layout: PlateauLayout, dir: int, st: Vector3i) -> bool:
	var tmp := PlateauLayout.new()
	var lst: Array = [tmp.stairs, tmp.stairs_north, tmp.stairs_east, tmp.stairs_west]
	(lst[dir] as Array).append(st)
	for pair in tmp.stair_pairs():
		var top: Vector2i = pair[0]
		var foot: Vector2i = pair[1]
		if not GridUtils.is_walkable(ctx.grid, foot) or layout.height_of(top) != layout.height_of(foot) + 1:
			return false
		# Za stopą (w kierunku zejścia) nie może być znów wyżej — schody nie schodzą w szczelinę.
		var landing: Vector2i = foot + (foot - top)
		if GridUtils.is_walkable(ctx.grid, landing) and layout.height_of(landing) > layout.height_of(foot):
			return false
	# Flanki (kratki lica tuż obok schodów) na tej samej wysokości co góra, z terenem o 1 niżej za nimi —
	# inaczej schody stoją w rogu (np. po zasypaniu szczeliny obok) i nie pasują do kafli lica.
	var h := layout.height_of(_stair_top(dir, st))
	for fo in _stair_flanks(dir, st):
		var f: Vector2i = fo[0]
		var out: Vector2i = fo[1]
		if not GridUtils.is_walkable(ctx.grid, f):
			continue  # schody dochodzą do ściany jaskini — lico ciągnie się pod nią, flanka zbędna
		if layout.height_of(f) != h:
			return false
		if not GridUtils.is_walkable(ctx.grid, f + out) or layout.height_of(f + out) != h - 1:
			return false
	return true


## Kratka góry schodów (dowolna z górnych) — do wysokości schodów.
static func _stair_top(dir: int, st: Vector3i) -> Vector2i:
	return Vector2i(st.x, st.z) if dir <= 1 else Vector2i(st.x, st.y)


## Flanki schodów: [kratka flanki, kierunek zejścia] dla obu końców.
static func _stair_flanks(dir: int, st: Vector3i) -> Array:
	match dir:
		0:
			return [[Vector2i(st.x - 1, st.z), Vector2i(0, 1)], [Vector2i(st.x + st.y, st.z), Vector2i(0, 1)]]
		1:
			return [[Vector2i(st.x - 1, st.z), Vector2i(0, -1)], [Vector2i(st.x + st.y, st.z), Vector2i(0, -1)]]
		2:
			return [[Vector2i(st.x, st.y - 1), Vector2i(1, 0)], [Vector2i(st.x, st.y + st.z), Vector2i(1, 0)]]
	return [[Vector2i(st.x, st.y - 1), Vector2i(-1, 0)], [Vector2i(st.x, st.y + st.z), Vector2i(-1, 0)]]


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


## Czy jakaś kratka góry kawałka poziomu `level` (wysokość == level) jest osiągalna.
static func _top_reached(comp: Dictionary, layout: PlateauLayout, reach: Dictionary, level: int) -> bool:
	for c in comp:
		if reach.has(c) and layout.height_of(c) == level:
			return true
	return false


## Czy bariery kawałka (jego kratki-bariery i stopy lica przy nim) sąsiadują z `cells`.
## Liczone od strony `cells` (kawałek poziomu 0 wokół dołów bywa całą mapą).
static func _touches(comp: Dictionary, layout: PlateauLayout, cells: Dictionary) -> bool:
	var offs := [Vector2i.ZERO, Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for r in cells:
		for d in DIRS4:
			var b: Vector2i = r + d
			if not layout.blocked.has(b):
				continue
			for o in offs:
				if comp.has(b - o):
					return true
	return false
