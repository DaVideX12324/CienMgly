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
	LinearNetworkGeneratorScript.run(st, seed_used, float(flags.canal_dry_chance))
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

	# Przejścia czyszczące — układ ma już być z nimi zgodny (R7: < 1 % zmienionych kratek).
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
	stats["prepass_changed"] = _grid_diff(ctx, before)
	_drop_walled_canal_cells(ctx, canals)
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
		var r: Rect2i
		if b.vertical:      # przez kanał poziomy: 2 kolumny, od brzegu do brzegu
			var x0: int = mn.x + (mx.x - mn.x + 1 - 2) / 2
			r = Rect2i(x0, mn.y - 1, 2, mx.y - mn.y + 3)
		else:
			var y0: int = mn.y + (mx.y - mn.y + 1 - 2) / 2
			r = Rect2i(mn.x - 1, y0, mx.x - mn.x + 3, 2)
		var under: Array[Vector2i] = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if st.in_map(x, y) and st.water[y * w + x]:
					under.append(Vector2i(x, y))
		layout.bridges.append({"rect": r, "vertical": b.vertical, "cells": under, "crossing": b.get("crossing", false)})
	for cid in st.complexes:
		var cells := {}
		for c in st.complexes[cid].get("cells", PackedInt32Array()):
			cells[Vector2i(c % w, c / w)] = true
		layout.complexes[cid] = {"cells": cells}
	layout.segments = st.segs
	layout.lines = st.lines
	layout.rebuild_blocked()
	return layout


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
