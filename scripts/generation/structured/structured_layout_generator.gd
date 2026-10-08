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
const LinearNetworkGeneratorScript = preload("linear_network_generator.gd")
const StructuredZoningScript = preload("structured_zoning.gd")
const StructuredRoomPackerScript = preload("structured_room_packer.gd")
const CanalLayoutScript = preload("../core/canal_layout.gd")
const Wall3HPassScript = preload("../preprocess/wall_3h_pass.gd")
const WallTopAlignPassScript = preload("../preprocess/wall_top_align_pass.gd")
const DiagonalTouchPassScript = preload("../preprocess/diagonal_touch_pass.gd")
const SlopeThicknessPassScript = preload("../preprocess/slope_thickness_pass.gd")
const WallDecorPlannerScript = preload("../objects/wall_decor_planner.gd")

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
	stats["lost_post"] = _unreachable(ctx, canals)
	GenProgress.end(&"portals")
	ctx.preprocess_stats["structured"] = stats

	if flags.enable_platforms:
		GenProgress.begin(&"plateaus")
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
			result.objects = ObjectPlanner.plan_objects(result, catalog, result.seed_used)
			if not catalog.wall_defs.is_empty():
				result.objects = WallDecorPlannerScript.plan(result, catalog.wall_defs, result.seed_used, flags, result.objects)
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
	if flags.enforce_3h_walls:
		GridPreprocessor.run(ctx, [Wall3HPassScript.new()])
	if flags.align_wall_tops:
		GridPreprocessor.run(ctx, [WallTopAlignPassScript.new()])
		if flags.enforce_3h_walls:
			GridPreprocessor.run(ctx, [Wall3HPassScript.new()])
