class_name StructuredLayoutGenerator
extends RefCounted

## Uniwersalny generator układów strukturalnych (structured) — plan: docs/plan_generator_sciekow.md,
## wzorzec: docs/prototypy/structured_layout/proto_layout.py (v11). Kolejność:
## 1. sieć liniowa (R1, LinearNetworkGenerator),
## 2. tunele / kompleksy-wielokąty, strefy przecięć (R2 / R3, StructuredZoning),
## 3. korytarze serwisowe, pokoje, łączniki, pętle, kładki, spójność (R4–R7, StructuredRoomPacker),
## 4. siatka + nakładka kanałów (CanalLayout), portale w pokojach (wejście najbliżej środka, wyjście
##    najdalej), dźwignie bram,
## 5. przejścia czyszczące i kształt ścian (cel R7: < 1 % kratek zmienionych),
## 6. obiekty, dekoracje, spawny.

const GenProgress = preload("../core/gen_progress.gd")
const State = preload("core/structured_state.gd")
## Prześwit kładki (canals.bridge_clearance): tyle kratek za każdym końcem modułu kładki bez obiektów.
const BRIDGE_CLEAR_ALONG := 2
const LinearNetworkGeneratorScript = preload("linear_network_generator.gd")
const StructuredZoningScript = preload("structured_zoning.gd")
const StructuredRoomPackerScript = preload("structured_room_packer.gd")
const CanalLayoutScript = preload("../core/canal_layout.gd")
const Wall3HPassScript = preload("../preprocess/wall_3h_pass.gd")
const WallTopAlignPassScript = preload("../preprocess/wall_top_align_pass.gd")
const DiagonalTouchPassScript = preload("../preprocess/diagonal_touch_pass.gd")
const SlopeThicknessPassScript = preload("../preprocess/slope_thickness_pass.gd")
const WallProtrusionPassScript = preload("../preprocess/wall_protrusion_pass.gd")
const WallDecorPlannerScript = preload("../objects/wall_decor_planner.gd")
const GratingPlannerScript = preload("../tiling/grating_planner.gd")
const GatePlannerScript = preload("../objects/gate_planner.gd")
const StructuredPlatformsScript = preload("structured_platforms.gd")

const PORTAL_MIN_FREE := 60


static func generate_layout(
	width: int,
	height: int,
	seed_val: int,
	_min_room_size: int,
	_max_room_size: int,
	_max_rooms: int,
	corridor_width: int,
	flags: GenerationFlags,
	result: MapGeneratorBase.GenerationResult
) -> GenerationContext:
	GenProgress.begin(&"rooms")
	var ctx := GenerationContext.new()
	ctx.flags = flags
	ctx.seed_value = seed_val
	ctx.width = width
	ctx.height = height
	ctx.rng = MapGeneratorBase.create_rng(seed_val)
	ctx.grid = result.grid
	result.seed_used = ctx.rng.seed
	var seed_used: int = result.seed_used

	var cfg: Dictionary = flags.structured_config if flags != null else {}
	var st := State.new()
	st.setup(width, height, cfg)
	LinearNetworkGeneratorScript.run(st, seed_used, float(flags.canal_dry_chance), cfg)
	GenProgress.end(&"rooms")

	GenProgress.begin(&"corridors")
	StructuredZoningScript.run(st, seed_used, cfg)
	var pre := {"segs": st.segs.size(), "lines": st.lines.size(), "dry_segs": 0, "complexes": st.complexes.size(), "cplx_cells": [], "pinches": 0}
	for s in st.segs:
		if s.dry:
			pre.dry_segs += 1
	for cid in st.complexes:
		pre.cplx_cells.append(st.complexes[cid].get("cells", PackedInt32Array()).size())
		if not st.complexes[cid].get("pinch", {}).is_empty():
			pre.pinches += 1
	var stats: Dictionary = StructuredRoomPackerScript.run(st, seed_used, cfg)
	stats.merge(pre)
	stats["partition_cells"] = StructuredZoningScript.partitions(st, seed_used, cfg)
	stats["partition_walls"] = 0
	for cid in st.complexes:
		stats["partition_walls"] += int(st.complexes[cid].get("partition_walls", 0))
	GenProgress.end(&"corridors")

	# Siatka: podłoga (z wodą — kanał to nakładka na podłogę) i ściana.
	for y in range(height):
		for x in range(width):
			ctx.grid[Vector2i(x, y)] = CellType.FLOOR if st.floor_m[y * width + x] else CellType.WALL
	var canals = _canal_layout(st)
	_canal_pits(st, canals, seed_used, cfg)
	result.canals = canals
	ctx.canals = canals

	var rooms: Array[Rect2i] = []
	for r in st.rooms:
		rooms.append(Rect2i(r.x, r.y, r.z - r.x + 1, r.w - r.y + 1))
	ctx.rooms = rooms
	result.rooms = rooms

	# Portale: wejście w pokoju najbliżej środka mapy, wyjście w pokoju najdalszym od wejścia.
	GenProgress.begin(&"portals")
	var picked := _pick_portal_rooms(st, rooms)
	var entrance_room_idx: int = picked.x
	var exit_room_idx: int = picked.y
	if entrance_room_idx >= 0:
		var ent: Dictionary = PortalGenerator.carve_portal_in_room(ctx, rooms[entrance_room_idx])
		ctx.entrance_pos = ent["center"] as Vector2i
		result.entrance_pos = ctx.entrance_pos
		result.player_spawn = ctx.entrance_pos
		result.entrance_zone = ent["cells"] as Array[Vector2i]
		for p in result.entrance_zone:
			ctx.grid[p] = CellType.ENTRANCE
			ctx.portal_zone[p] = true
		var ex: Dictionary = PortalGenerator.carve_portal_in_room(ctx, rooms[exit_room_idx])
		ctx.exit_pos = ex["center"] as Vector2i
		result.exit_pos = ctx.exit_pos
		result.exit_zone = ex["cells"] as Array[Vector2i]
		for p in result.exit_zone:
			ctx.grid[p] = CellType.EXIT
			ctx.portal_zone[p] = true
		StructuredRoomPackerScript.place_levers(st, ctx.entrance_pos)
	canals.gates = st.gates
	canals.levers = st.levers

	# Przejścia czyszczące — układ ma już być z nimi zgodny (R7: < 1 % zmienionych kratek). Kanały, chodniki,
	# korytarze i kładki chronione przed zamurowaniem (Wall3HPass potrafił zasypać przesmyk i odciąć część mapy).
	for i in range(width * height):
		if st.water[i] or st.lanes[i] or st.corrm[i] or st.service[i] or st.bridge_m[i]:
			ctx.protected_floor[Vector2i(i % width, i / width)] = true
	stats["lost_pre"] = _unreachable(ctx, canals)
	var before := _grid_snapshot(ctx)
	GridPreprocessor.run(ctx, [Remove1hWallsPass.new(), WallThicknessPass.new()])
	_run_wall_shape_passes(ctx, flags)
	if flags.enable_grid_cleanup:
		GridPreprocessor.run_convergent(ctx, [
			SpikeCleanupPass.new(),
			ThinBridgeCleanupPass.new(),
			StaircaseNormalizerPass.new()
		], 4)
	_run_wall_shape_passes(ctx, flags)
	GridPreprocessor.run(ctx, [ShortLedgeRaisePass.new(), DiagonalTouchPassScript.new(), SlopeThicknessPassScript.new()])
	stats["restored"] = _restore_cuts(ctx, canals, before)
	stats["prepass_changed"] = _grid_diff(ctx, before)
	_drop_walled_canal_cells(ctx, canals)
	stats["dead_end_slivers"] = _fill_dead_end_slivers(ctx, canals)
	stats["raised_protrusions"] = _raise_facade_protrusions(ctx, canals)
	if int(stats["raised_protrusions"]) > 0:   # zasypane kratki mogą zostawić ślepą kieszeń obok
		stats["dead_end_slivers"] = int(stats["dead_end_slivers"]) + _fill_dead_end_slivers(ctx, canals)
	if bool(cfg.get("canal_rails", true)):
		stats["rails"] = _canal_rails(st, canals, ctx, seed_used, cfg)
	if flags.enable_1w_walls:
		stats["walls_1w"] = _walls_1w(ctx, canals, seed_used, cfg)
	stats["grating"] = GratingPlannerScript.select(ctx.grid, canals, ctx.portal_zone, seed_used, flags.tiling_config.get("grating", {}))
	stats["lost_post"] = _unreachable(ctx, canals)
	GenProgress.end(&"portals")
	ctx.preprocess_stats["structured"] = stats

	if flags.enable_platforms:
		GenProgress.begin(&"plateaus")
		if cfg.has("platforms") and ctx.entrance_pos != Vector2i.ZERO:
			# Platformy pod ścianami pomieszczeń (kształt structured), schody i osiągalność — PlateauPass.
			var pm: Dictionary = StructuredPlatformsScript.mask(ctx, canals, flags, cfg["platforms"])
			ctx.plateau = PlateauPass.solve_levels(ctx, flags, {1: pm} if not pm.is_empty() else {})
			stats["platform_cells"] = pm.size()
		else:
			ctx.plateau = PlateauPass.run(ctx, flags)
		result.plateau = ctx.plateau
		GenProgress.end()

	result.portal_zone = ctx.portal_zone
	if flags.enable_objects:
		GenProgress.begin(&"terrain")
		var catalog := ObjectCatalog.load_path(flags.objects_catalog)
		if not catalog.defs.is_empty() or not catalog.wall_defs.is_empty():
			result.terrain_masks = TerrainMaskPlanner.compute_for_result(result, result.seed_used, flags)
			GenProgress.end(&"terrain")
			GenProgress.begin(&"objects")
			if not catalog.gates.is_empty():
				stats["gates"] = GatePlannerScript.select(result, flags.facade_base_on_wall, catalog.gates)
			result.objects = ObjectPlanner.plan_objects(result, catalog, result.seed_used)
			if not catalog.wall_defs.is_empty():
				result.objects = WallDecorPlannerScript.plan(result, catalog.wall_defs, result.seed_used, flags, result.objects, catalog.defs)
			GatePlannerScript.emit(result, catalog.gates, result.objects)
		GenProgress.end()

	GenProgress.begin(&"spawns")
	if not rooms.is_empty() and entrance_room_idx >= 0:
		SpawnPlanner.plan_spawns(ctx, result, entrance_room_idx, exit_room_idx)
	GenProgress.end(&"spawns")

	result.portal_zone = ctx.portal_zone
	result.preprocess_stats = ctx.preprocess_stats
	return ctx


## Nakładka kanałów dla tilingu / obiektów / nawigacji: woda, puste koryto, chodniki, korytarze serwisowe,
## kładki (prostokąt modułu kładki: 2 kratki szerokości, cały kanał + brzegi), bramy, dźwignie.
static func _canal_layout(st: State):
	var layout = CanalLayoutScript.new()
	var w: int = st.w
	for i in range(w * st.h):
		var p := Vector2i(i % w, i / w)
		if st.water[i]:
			layout.water[p] = true
			if st.dry[i]:
				layout.dry[p] = true
		if st.lanes[i]:
			layout.lanes[p] = true
		if st.service[i]:
			layout.service[p] = true
		if st.corrm[i] and not st.water[i] and not st.service[i]:
			layout.corridors[p] = true
		if st.floor_m[i] and not st.water[i]:
			layout.areas[p] = StringName("hall:%d" % st.hall_cid[i]) if st.hall_cid[i] >= 0 else &"corridor"
	for comp in st.chambers:
		var arr: Array[Vector2i] = []
		for i in comp:
			if st.floor_m[i] and not st.water[i]:
				arr.append(Vector2i(i % w, i / w))
		if not arr.is_empty():
			layout.chambers.append(arr)
	for ri in st.rooms.size():
		var r: Vector4i = st.rooms[ri]
		var key := StringName("room:%d" % ri)
		for y in range(r.y, r.w + 1):
			for x in range(r.x, r.z + 1):
				var p := Vector2i(x, y)
				if layout.areas.has(p) and st.roomm[y * w + x]:
					layout.areas[p] = key
	for b in st.bridges:
		var cells: Array = b.cells
		var mn: Vector2i = cells[0]
		var mx: Vector2i = cells[0]
		for c in cells:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
		# Orientacja z kształtu: dłuższy wymiar = w poprzek kanału (kładka pionowa = przez kanał poziomy).
		var vertical: bool = (mx.y - mn.y) >= (mx.x - mn.x)
		var r: Rect2i
		if vertical:
			var x0: int = mn.x + (mx.x - mn.x + 1 - 2) / 2
			r = Rect2i(x0, mn.y - 1, 2, mx.y - mn.y + 3)
		else:
			var y0: int = mn.y + (mx.y - mn.y + 1 - 2) / 2
			r = Rect2i(mn.x - 1, y0, mx.x - mn.x + 3, 2)
		# Przechodnie są wszystkie kratki kładki ze stanu generatora (spójność liczona na nich); `rect` to tylko
		# moduł grafiki.
		var under: Array[Vector2i] = []
		for c in cells:
			under.append(c)
		layout.bridges.append({"rect": r, "vertical": vertical, "cells": under, "crossing": b.get("crossing", false)})
		# prześwit: zejścia z kładki (BRIDGE_CLEAR_ALONG kratek za końcami, kratkę szerzej) bez obiektów
		var g := Vector2i(1, BRIDGE_CLEAR_ALONG) if vertical else Vector2i(BRIDGE_CLEAR_ALONG, 1)
		var cr := Rect2i(r.position - g, r.size + g * 2)
		for y in range(cr.position.y, cr.end.y):
			for x in range(cr.position.x, cr.end.x):
				var c := Vector2i(x, y)
				if st.in_map(x, y) and st.floor_m[y * w + x] and not st.water[y * w + x]:
					layout.bridge_clearance[c] = true
	for cid in st.complexes:
		var cells := {}
		for c in st.complexes[cid].get("cells", PackedInt32Array()):
			cells[Vector2i(c % w, c / w)] = true
		layout.complexes[cid] = {"cells": cells}
	layout.segments = st.segs
	layout.lines = st.lines
	layout.rebuild_blocked()
	return layout


## Doły w pustym korycie (makieta Extended): na suchym odcinku tunelu z szansą canal_pit_chance po jednym dole
## na każde canal_pit_every kratek długości. Dół: canal_pit_len (3–4) kratki wzdłuż kanału; w poprzek — przy
## kanale poziomym 2 rzędy pod licem (kamień zostaje w ostatnim rzędzie), przy pionowym 2 środkowe kolumny.
## Rzędy: TOP / TOP_B (pierwszy pod kamieniem), VOID, BOTTOM (ostatni nad kamieniem). Bez dołów przy kładkach
## (± 2), w blokach zakrętów / węzłów i przy końcach odcinka; tylko kratki suchego koryta.
static func _canal_pits(st: State, layout, seed_val: int, cfg: Dictionary) -> void:
	var chance := float(cfg.get("canal_pit_chance", 0.5))
	if chance <= 0.0:
		return
	var len_r: Array = cfg.get("canal_pit_len", [3, 4])
	var every := int(cfg.get("canal_pit_every", 16))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_val, "canal_pits"])
	var w: int = st.w
	var axis_n := PackedByteArray()
	axis_n.resize(w * st.h)
	for s in st.segs:
		var bit: int = 1 if s.axis == "h" else 2
		for y in range(s.y0, s.y1 + 1):
			for x in range(s.x0, s.x1 + 1):
				axis_n[y * w + x] |= bit
	for s in st.segs:
		if s.kind != "tunnel" or not s.dry or rng.randf() >= chance:
			continue
		var horiz: bool = s.axis == "h"
		var lo: int = (s.x0 if horiz else s.y0) + 2
		var hi: int = (s.x1 if horiz else s.y1) - 2
		var across: Array = [s.y0 + 1, s.y0 + 2] if horiz else [s.x0 + 1, s.x0 + 2]
		var ok_t := func(t: int) -> bool:
			for a in range(s.y0 if horiz else s.x0, (s.y1 if horiz else s.x1) + 1):
				var c := Vector2i(t, a) if horiz else Vector2i(a, t)
				if not layout.dry.has(c) or axis_n[c.y * w + c.x] == 3:
					return false
				for dd in range(-2, 3):
					var b := c + (Vector2i(dd, 0) if horiz else Vector2i(0, dd))
					if layout.bridge_cells.has(b):
						return false
			return true
		var n := maxi(1, (hi - lo + 1) / every)
		var t := lo
		for _k in range(n):
			var L := rng.randi_range(int(len_r[0]), int(len_r[1]))
			# pierwsza pozycja od t (z losowym przesunięciem), gdzie mieści się cały dół
			var start := -1
			var t0 := t + rng.randi_range(0, maxi(0, every / 2))
			for c0 in range(t0, hi - L + 2):
				var fits := true
				for tt in range(c0, c0 + L):
					if not ok_t.call(tt):
						fits = false
						break
				if fits:
					start = c0
					break
			if start < 0:
				break
			var cells := {}
			for tt in range(start, start + L):
				for a in across:
					cells[Vector2i(tt, a) if horiz else Vector2i(a, tt)] = true
			var rect := Rect2i(Vector2i(start, across[0]), Vector2i(L, 2)) if horiz else Rect2i(Vector2i(across[0], start), Vector2i(2, L))
			for c: Vector2i in cells:
				var top: int = rect.position.y
				var bot: int = rect.end.y - 1
				var v: StringName = &"VOID"
				if c.y == top:
					v = &"TOP_B" if rng.randf() < 0.3 else &"TOP"
				elif c.y == bot:
					v = &"BOTTOM"
				layout.pit_cells[c] = v
			layout.pits.append(rect)
			t = start + L + 3


## Barierki (makiety autora) wzdłuż kanałów poziomych: na północnym brzegu na kratce podłogi nad licem, na
## południowym na ostatnim rzędzie koryta (podłoga tuż pod nim; wzór: sewer-gen-v2 fbe9c09). Przerwa na
## śladzie kładki, w blokach zakrętów / węzłów (v2 92f59bc: bez barierki „w powietrzu”), przy portalach
## i dźwigniach. Brzeg nie musi mieć barierki na całej długości (decyzje usera): ciąg brzegu dostaje barierkę
## z szansą rail_run_chance, końce ciągu przycięte o 1–2 kratki (rail_trim_chance — barierka nie zawsze
## dochodzi do kładki), długi ciąg dzielony na kawałki rail_piece z przerwami rail_gap; kawałek ≥ 3 kratki.
## Końce: przy kładce zagięty (CL / CR) z szansą rail_bridge_curl_chance, przy murze bez przycięcia i bez
## słupka (przęsło M — barierka idzie dalej za ścianę); na brzegu północnym, gdy kanał biegnie dalej pod
## murem, z szansą rail_wall_front_chance barierka wychodzi kratkę przed fasadę ze słupkiem (L / R w kratce
## lica — warstwa Rails); inaczej słupek (L / R); w środku
## przęsło (M); urwanie: w kawałku ≥ rail_break_min z szansą rail_break_chance zagięte końce CR | CL w środku,
## tuż obok siebie albo z przerwą 1–2 kratek. Tylko grafika — wejście do kanału blokuje już obrzeże.
## Zwraca liczbę kratek barierek.
static func _canal_rails(st: State, layout, ctx: GenerationContext, seed_val: int, cfg: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_val, "canal_rails"])
	var break_chance := float(cfg.get("rail_break_chance", 0.35))
	var break_min := int(cfg.get("rail_break_min", 8))
	var run_chance := float(cfg.get("rail_run_chance", 0.85))
	var trim_chance := float(cfg.get("rail_trim_chance", 0.5))
	var curl_chance := float(cfg.get("rail_bridge_curl_chance", 0.5))
	var front_chance := float(cfg.get("rail_wall_front_chance", 0.5))
	var piece_r: Array = cfg.get("rail_piece", [6, 18])
	var gap_r: Array = cfg.get("rail_gap", [2, 5])
	var w: int = st.w
	var axis := st.water_axis
	if axis.is_empty():
		st.build_water_axis()
		axis = st.water_axis
	var near_bridge := {}   # ślad modułu kładki — barierka może dochodzić tuż do desek (jak w makiecie)
	for b in layout.bridges:
		var r: Rect2i = b.get("rect", Rect2i())
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				near_bridge[Vector2i(x, y)] = true
	var banned := {}
	for p in ctx.portal_zone:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				banned[p + Vector2i(dx, dy)] = true
	for l in st.levers:
		banned[l] = true
	var water: Dictionary = layout.water
	var runs := {}   # Vector3i(y, strona, 0) -> Array[int] x
	for p: Vector2i in water:
		if axis[p.y * w + p.x] != 1 or layout.bridge_cells.has(p):
			continue
		var up := p + Vector2i(0, -1)
		var down := p + Vector2i(0, 1)
		var cell := Vector2i(-1, -1)
		var side := 0
		if not water.has(up) and GridUtils.is_walkable(ctx.grid, up) and GridUtils.is_walkable(ctx.grid, up + Vector2i(0, -1)):
			cell = up        # północ: kratka brzegu nad licem (podłoga, za nią dalej podłoga)
		elif not water.has(down) and GridUtils.is_walkable(ctx.grid, down):
			cell = p         # południe: ostatni rząd koryta
			side = 1
		if cell.x < 0 or near_bridge.has(cell) or banned.has(cell) or banned.has(down):
			continue
		var key := Vector2i(cell.y, side)
		if not runs.has(key):
			runs[key] = []
		(runs[key] as Array).append(cell.x)
	var n := 0
	var keys: Array = runs.keys()
	keys.sort()   # kolejność losowań niezależna od kolejności słownika
	for key: Vector2i in keys:
		var xs: Array = runs[key]
		xs.sort()
		var i := 0
		while i < xs.size():
			var j := i
			while j + 1 < xs.size() and int(xs[j + 1]) == int(xs[j]) + 1:
				j += 1
			if j - i + 1 >= 3 and rng.randf() < run_chance:
				var y: int = key.x
				var a := i + (rng.randi_range(1, 2) if rng.randf() < trim_chance else 0)
				var e := j - (rng.randi_range(1, 2) if rng.randf() < trim_chance else 0)
				# koniec przy murze: barierka bez przycięcia i bez słupka — idzie dalej za ścianę
				var wall_l := _rail_wall(ctx, water, Vector2i(int(xs[i]) - 1, y), key.y)
				var wall_r := _rail_wall(ctx, water, Vector2i(int(xs[j]) + 1, y), key.y)
				if wall_l:
					a = i
				if wall_r:
					e = j
				# brzeg północny, kanał biegnie dalej pod murem (lico nad wodą): barierka losowo wychodzi
				# kratkę przed fasadę ze słupkiem (warstwa Rails nad licem), inaczej chowa się za ścianą
				var front_l: bool = wall_l and key.y == 0 and water.has(Vector2i(int(xs[i]) - 1, y + 1)) and rng.randf() < front_chance
				var front_r: bool = wall_r and key.y == 0 and water.has(Vector2i(int(xs[j]) + 1, y + 1)) and rng.randf() < front_chance
				var k0 := a
				while e - k0 + 1 >= 3:
					var k1 := mini(e, k0 + rng.randi_range(int(piece_r[0]), int(piece_r[1])) - 1)
					if e - k1 < 3:
						k1 = e   # bez krótkiej resztki
					n += _rail_piece(layout, xs, k0, k1, y, key.y, near_bridge, rng, curl_chance, break_chance, break_min,
						wall_l and k0 == i, wall_r and k1 == j)
					if front_l and k0 == i:
						layout.rail_cells[Vector2i(int(xs[i]) - 1, y)] = &"L"
						n += 1
					if front_r and k1 == j:
						layout.rail_cells[Vector2i(int(xs[j]) + 1, y)] = &"R"
						n += 1
					k0 = k1 + 1 + rng.randi_range(int(gap_r[0]), int(gap_r[1]))
			i = j + 1
	return n


## Kratka za końcem ciągu barierki to mur (północ: kratka w rzędzie barierki; południe: podłoga pod nią).
static func _rail_wall(ctx: GenerationContext, water: Dictionary, c: Vector2i, side: int) -> bool:
	var q := c + Vector2i(0, side)
	return ctx.grid.has(q) and not water.has(q) and not GridUtils.is_walkable(ctx.grid, q)


## Jeden kawałek barierki xs[k0..k1] w rzędzie y (strona: 0 północ, 1 południe); zwraca liczbę kratek.
## open_l / open_r: koniec przy murze — przęsło M zamiast słupka (barierka chowa się za ścianą).
static func _rail_piece(layout, xs: Array, k0: int, k1: int, y: int, side: int, near_bridge: Dictionary,
		rng: RandomNumberGenerator, curl_chance: float, break_chance: float, break_min: int,
		open_l := false, open_r := false) -> int:
	# urwanie: [b0 = CR] przerwa (0–2) [b1 = CL], każda część ≥ 3 kratki
	var b0 := -1
	var b1 := -1
	if k1 - k0 + 1 >= break_min and rng.randf() < break_chance:
		var gap := rng.randi_range(0, 2)
		b0 = rng.randi_range(k0 + 2, k1 - 3 - gap)
		b1 = b0 + gap + 1
	var left_curl: bool = near_bridge.has(Vector2i(int(xs[k0]) - 1, y)) and rng.randf() < curl_chance
	var right_curl: bool = near_bridge.has(Vector2i(int(xs[k1]) + 1, y)) and rng.randf() < curl_chance
	var n := 0
	for k in range(k0, k1 + 1):
		if b0 >= 0 and k > b0 and k < b1:
			continue
		var x: int = xs[k]
		var v: StringName = &"M"
		if k == k0 and not open_l:
			v = &"CL" if left_curl else &"L"
		elif k == k1 and not open_r:
			v = &"CR" if right_curl else &"R"
		elif k == b0:
			v = &"CR"
		elif k == b1:
			v = &"CL"
		layout.rail_cells[Vector2i(x, y)] = v
		n += 1
	layout.rail_edges.append({"cells": range(int(xs[k0]), int(xs[k1]) + 1).map(func(px): return Vector2i(px, y)),
		"dir": Vector2i(0, 1) if side == 0 else Vector2i(0, -1), "side": side})
	return n


## Pokoje portali (wzorzec: krok 8 prototypu): kandydaci z ≥ PORTAL_MIN_FREE wolnymi kratkami, wejście
## najbliżej środka mapy, wyjście najdalej od wejścia. Zwraca (wejście, wyjście) albo (-1, -1).
static func _pick_portal_rooms(st: State, rooms: Array[Rect2i]) -> Vector2i:
	var cand: Array = []
	for i in range(rooms.size()):
		var r := rooms[i]
		var n := 0
		var sx := 0.0
		var sy := 0.0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var k: int = y * st.w + x
				if st.floor_m[k] and not st.water[k] and not st.lanes[k] and not st.service[k]:
					n += 1
					sx += x
					sy += y
		if n >= PORTAL_MIN_FREE:
			cand.append([i, Vector2(sx / n, sy / n)])
	if cand.size() < 2:
		for i in range(rooms.size()):
			cand.append([i, Vector2(rooms[i].get_center())])
	if cand.size() < 2:
		return Vector2i(-1, -1)
	var mid := Vector2(st.w, st.h) * 0.5
	cand.sort_custom(func(a, b) -> bool: return (a[1] as Vector2).distance_squared_to(mid) < (b[1] as Vector2).distance_squared_to(mid))
	var ent: Vector2 = cand[0][1]
	var ex: int = cand[1][0]
	var far := -1.0
	for c in cand.slice(1):
		var d := (c[1] as Vector2).distance_squared_to(ent)
		if d > far:
			far = d
			ex = c[0]
	return Vector2i(cand[0][0], ex)


## Bezpiecznik spójności po przejściach czyszczących: gdy coś jest nieosiągalne z wejścia, kratki zamurowane
## przez przejścia (były podłogą) przy granicy nieosiągalnego obszaru wracają do podłogi; do skutku.
## Zwraca liczbę przywróconych kratek.
static func _restore_cuts(ctx: GenerationContext, canals, before: PackedByteArray) -> int:
	var restored := 0
	for _it in range(12):
		var reach := _reach_set(ctx, canals)
		var fix: Array[Vector2i] = []
		for y in range(ctx.height):
			for x in range(ctx.width):
				var p := Vector2i(x, y)
				if not GridUtils.is_walkable(ctx.grid, p) or canals.blocked.has(p) or reach.has(p):
					continue
				# p nieosiągalne: zamurowane przez przejścia kratki obok wracają
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= ctx.width or q.y >= ctx.height:
							continue
						if before[q.y * ctx.width + q.x] and not GridUtils.is_walkable(ctx.grid, q):
							fix.append(q)
		if fix.is_empty():
			break
		for q in fix:
			if not GridUtils.is_walkable(ctx.grid, q):
				ctx.grid[q] = CellType.FLOOR
				restored += 1
	return restored


static func _reach_set(ctx: GenerationContext, canals) -> Dictionary:
	var seen := {}
	var q: Array[Vector2i] = [ctx.entrance_pos]
	seen[ctx.entrance_pos] = true
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if seen.has(n) or not GridUtils.is_walkable(ctx.grid, n) or canals.blocked.has(n):
				continue
			seen[n] = true
			q.append(n)
	return seen


## Liczba kratek chodliwych (podłoga bez wody poza kładkami) nieosiągalnych z wejścia.
static func _unreachable(ctx: GenerationContext, canals) -> int:
	var seen := {}
	var q: Array[Vector2i] = [ctx.entrance_pos]
	seen[ctx.entrance_pos] = true
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if seen.has(n) or not GridUtils.is_walkable(ctx.grid, n) or canals.blocked.has(n):
				continue
			seen[n] = true
			q.append(n)
	var lost := 0
	for y in range(ctx.height):
		for x in range(ctx.width):
			var p := Vector2i(x, y)
			if GridUtils.is_walkable(ctx.grid, p) and not canals.blocked.has(p) and not seen.has(p):
				lost += 1
	return lost


static func _grid_snapshot(ctx: GenerationContext) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(ctx.width * ctx.height)
	for y in range(ctx.height):
		for x in range(ctx.width):
			out[y * ctx.width + x] = 1 if GridUtils.is_walkable(ctx.grid, Vector2i(x, y)) else 0
	return out


static func _grid_diff(ctx: GenerationContext, before: PackedByteArray) -> int:
	var n := 0
	for y in range(ctx.height):
		for x in range(ctx.width):
			if before[y * ctx.width + x] != (1 if GridUtils.is_walkable(ctx.grid, Vector2i(x, y)) else 0):
				n += 1
	return n


## Ściany szerokości 1 (flaga enable_1w_walls): wolnostojące występy muru długości wall_1w_len (kratki z północy
## na południe: TOP, [MID…], BOTTOM, FACE_TOP, BASE — lico 3H jak na makiecie autora), w kompleksach i pokojach (canals.areas), z wolnym
## pierścieniem wall_1w_margin kratek podłogi dookoła (bez wody, chodników, korytarzy serwisowych, kładek i ich
## prześwitu, barierek, portali) i odstępem wall_1w_spacing od innych. Liczba: wall_1w_per_1000 na 1000 kratek
## kompleksów / pokoi. Siatka bez zmian (podłoga pod grzbietem), ruch blokuje canals.blocked.
static func _walls_1w(ctx: GenerationContext, canals, seed_val: int, cfg: Dictionary) -> int:
	var len_r: Array = cfg.get("wall_1w_len", [4, 5])
	var margin := int(cfg.get("wall_1w_margin", 2))
	var spacing := int(cfg.get("wall_1w_spacing", 4))
	var per_1000 := float(cfg.get("wall_1w_per_1000", 3.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_val, "walls_1w"])
	var bad := {}
	for d in [canals.water, canals.lanes, canals.service, canals.crossing_cells, canals.bridge_clearance, canals.rail_cells, ctx.portal_zone]:
		bad.merge(d)
	var cands: Array[Vector2i] = []
	for p: Vector2i in canals.areas:
		var a := String(canals.areas[p])
		if (a.begins_with("hall:") or a.begins_with("room:")) and GridUtils.is_walkable(ctx.grid, p) and not bad.has(p):
			cands.append(p)
	cands.sort()
	var target := int(cands.size() * per_1000 / 1000.0)
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var placed: Array[Rect2i] = []
	for top in cands:
		if placed.size() >= target:
			break
		var n := int(len_r[0]) + rng.randi() % maxi(int(len_r[-1]) - int(len_r[0]) + 1, 1)
		var body := Rect2i(top, Vector2i(1, n))
		var ring := body.grow(margin)
		var ok := true
		for q in placed:
			if q.grow(spacing).intersects(body):
				ok = false
				break
		for y in range(ring.position.y, ring.end.y):
			for x in range(ring.position.x, ring.end.x):
				var c := Vector2i(x, y)
				if not ok:
					break
				if not GridUtils.is_walkable(ctx.grid, c) or bad.has(c) or canals.blocked.has(c) or not canals.areas.has(c):
					ok = false
		if not ok:
			continue
		placed.append(body)
		for k in range(n):
			var v: StringName = &"MID"
			if k == 0:
				v = &"TOP"
			elif k == n - 3:
				v = &"BOTTOM"
			elif k == n - 2:
				v = &"FACE_TOP"
			elif k == n - 1:
				v = &"BASE"
			canals.walls_1w[top + Vector2i(0, k)] = v
			canals.blocked[top + Vector2i(0, k)] = true
	return placed.size()


## Ślepe wnęki szerokości 1 (np. rząd podłogi wciśnięty przez przejścia czyszczące między ścianę działową a mur):
## kratka podłogi z murem z >= 3 stron -> mur, powtarzane do stabilności. Zasypuje tylko liście (spójność bez zmian);
## bez wody, kładek i strefy portali.
static func _fill_dead_end_slivers(ctx: GenerationContext, canals) -> int:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var open := func(c: Vector2i) -> bool:
		return GridUtils.is_walkable(ctx.grid, c) or canals.water.has(c)
	var cand: Array[Vector2i] = []
	for y in range(1, ctx.height - 1):
		for x in range(1, ctx.width - 1):
			cand.append(Vector2i(x, y))
	var filled := 0
	while not cand.is_empty():
		var next: Array[Vector2i] = []
		for c in cand:
			if not GridUtils.is_walkable(ctx.grid, c) or canals.water.has(c) or canals.bridge_cells.has(c) or ctx.portal_zone.has(c):
				continue
			var walls := 0
			for d in dirs:
				if not open.call(c + d):
					walls += 1
			if walls >= 3:
				ctx.grid[c] = CellType.WALL
				filled += 1
				for d in dirs:
					next.append(c + d)
		cand = next
	# przesmyki otwarte z obu stron (ciąg kratek z murem po obu bokach): zasypane, gdy końce łączą się inną drogą
	var blocked_cell := func(c: Vector2i) -> bool:
		return canals.water.has(c) or canals.bridge_cells.has(c) or ctx.portal_zone.has(c)
	for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var side := Vector2i(axis.y, axis.x)
		var seen := {}
		for y in range(1, ctx.height - 1):
			for x in range(1, ctx.width - 1):
				var c := Vector2i(x, y)
				if seen.has(c) or not GridUtils.is_walkable(ctx.grid, c) or blocked_cell.call(c) 						or open.call(c + side) or open.call(c - side) or (open.call(c - axis) and _sliver(ctx, canals, c - axis, side)):
					continue
				var run: Array[Vector2i] = []
				var q := c
				while GridUtils.is_walkable(ctx.grid, q) and not blocked_cell.call(q) and _sliver(ctx, canals, q, side):
					run.append(q)
					seen[q] = true
					q += axis
				var a := c - axis
				var b := q
				if run.is_empty() or not open.call(a) or not open.call(b):
					continue
				for r in run:
					ctx.grid[r] = CellType.WALL
				if _connected(ctx, canals, a, b, ctx.width * ctx.height):
					filled += run.size()
				else:
					for r in run:
						ctx.grid[r] = CellType.FLOOR
	return filled


## Wystająca ściana (szer. <= MAX_PROTRUSION) przyklejona bokiem do lica innej ściany, ze szczytem w rzędzie pasa
## lica (do FACADE_BAND kratek nad podłogą) — za mało miejsca na połączenie rantu z licem (decyzja usera: podnieść).
## Kratki nad wystającą ścianą zasypane, aż jej szczyt wyjdzie ponad pas lica (łączy się wtedy z bokiem muru jak
## zwykły schodek). Bez wody, kładek, portali; cofnięte, gdy rozcina podłogę.
const MAX_PROTRUSION := 3
const FACADE_BAND := 4
static func _raise_facade_protrusions(ctx: GenerationContext, canals) -> int:
	var wall := func(c: Vector2i) -> bool:
		return not GridUtils.is_walkable(ctx.grid, c) and not canals.water.has(c)
	var floor_ok := func(c: Vector2i) -> bool:
		return GridUtils.is_walkable(ctx.grid, c) and not canals.water.has(c) and not canals.bridge_cells.has(c) 				and not ctx.portal_zone.has(c) and not canals.cells.has(c)
	var in_band := func(c: Vector2i) -> bool:   # c w pasie lica: pod nim podłoga w odległości 1..FACADE_BAND
		for k in range(1, FACADE_BAND + 1):
			var b := c + Vector2i(0, k)
			if not wall.call(b):
				return GridUtils.is_walkable(ctx.grid, b)
		return false
	var filled := 0
	for _round in range(FACADE_BAND + 1):
		var changed := 0
		for y in range(2, ctx.height - 1):
			for x in range(1, ctx.width - 1):
				var c := Vector2i(x, y)
				if not wall.call(c) or not wall.call(c + Vector2i(0, -1)) or not in_band.call(c):
					continue
				for side in [Vector2i(-1, 0), Vector2i(1, 0)]:
					# szczyt wystającej ściany obok c: ściana w rzędzie y, podłoga nad nią
					var run: Array[Vector2i] = []
					var q: Vector2i = c + side
					while run.size() <= MAX_PROTRUSION and wall.call(q) and floor_ok.call(q + Vector2i(0, -1)):
						run.append(q + Vector2i(0, -1))
						q += side
					if run.is_empty() or run.size() > MAX_PROTRUSION or wall.call(q + Vector2i(0, -1)):
						continue   # nie wystająca ściana (szeroki mur albo dalej też mur u góry)
					var nb: Array[Vector2i] = []
					for f in run:
						for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
							var n: Vector2i = f + d
							if not run.has(n) and GridUtils.is_walkable(ctx.grid, n):
								nb.append(n)
					for f in run:
						ctx.grid[f] = CellType.WALL
					var ok := true
					for i in range(1, nb.size()):
						if not _connected(ctx, canals, nb[0], nb[i], 4000):
							ok = false
							break
					if ok:
						changed += run.size()
					else:
						for f in run:
							ctx.grid[f] = CellType.FLOOR
		filled += changed
		if changed == 0:
			break
	return filled


static func _sliver(ctx: GenerationContext, canals, c: Vector2i, side: Vector2i) -> bool:
	var wall := func(q: Vector2i) -> bool:
		return not GridUtils.is_walkable(ctx.grid, q) and not canals.water.has(q)
	return wall.call(c + side) and wall.call(c - side)


## Czy `b` osiągalne z `a` (4-sąsiedzi po podłodze i wodzie), najwyżej `limit` kratek.
static func _connected(ctx: GenerationContext, canals, a: Vector2i, b: Vector2i, limit: int) -> bool:
	var seen := {a: true}
	var q: Array[Vector2i] = [a]
	var h := 0
	while h < q.size() and h < limit:
		var c := q[h]
		h += 1
		if c == b:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and (GridUtils.is_walkable(ctx.grid, n) or canals.water.has(n)):
				seen[n] = true
				q.append(n)
	return false


## Kratki kanału zamurowane przez przejścia czyszczące wypadają z nakładki (woda tylko na podłodze).
static func _drop_walled_canal_cells(ctx: GenerationContext, canals) -> void:
	var gone: Array[Vector2i] = []
	for p in canals.water:
		if not GridUtils.is_walkable(ctx.grid, p):
			gone.append(p)
	if gone.is_empty():
		return
	for p in gone:
		canals.water.erase(p)
		canals.dry.erase(p)
	canals.rebuild_blocked()


static func _run_wall_shape_passes(ctx: GenerationContext, flags: GenerationFlags) -> void:
	if not flags.enable_2h_facades:
		GridPreprocessor.run(ctx, [WallProtrusionPassScript.new()])
	if flags.enforce_3h_walls:
		GridPreprocessor.run(ctx, [Wall3HPassScript.new()])
	if flags.align_wall_tops:
		GridPreprocessor.run(ctx, [WallTopAlignPassScript.new()])
		if flags.enforce_3h_walls:
			GridPreprocessor.run(ctx, [Wall3HPassScript.new()])
