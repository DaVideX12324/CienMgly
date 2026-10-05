class_name StructuredLayoutGenerator
extends RefCounted

## Uniwersalny generator układów strukturalnych (structured).
## Odpowiada za orkiestrację pipeline'u opartego o:
## 1. Sieć liniową (LinearNetworkGenerator)
## 2. Strefowanie i wielokąty sal (StructuredZoning)
## 3. Pakowanie pomieszczeń i korytarzy A* (StructuredRoomPacker)
## 4. Wybór wejścia i wyjścia (PortalGenerator)
## 5. Przejścia czyszczące i kształt ścian
## 6. Obiekty, dekoracje i spawny

const GenProgress = preload("../core/gen_progress.gd")
const LinearNetworkGeneratorScript = preload("linear_network_generator.gd")
const StructuredZoningScript = preload("structured_zoning.gd")
const StructuredRoomPackerScript = preload("structured_room_packer.gd")
const StructuredReservationsScript = preload("structured_reservations.gd")
const LinearFeatureLayoutScript = preload("core/linear_feature_layout.gd")
const CanalLayoutScript = preload("../core/canal_layout.gd")
const Wall3HPassScript = preload("../preprocess/wall_3h_pass.gd")
const WallTopAlignPassScript = preload("../preprocess/wall_top_align_pass.gd")
const DiagonalTouchPassScript = preload("../preprocess/diagonal_touch_pass.gd")
const SlopeThicknessPassScript = preload("../preprocess/slope_thickness_pass.gd")
const WallDecorPlannerScript = preload("../objects/wall_decor_planner.gd")
const FacadeRhythmScript = preload("facade_rhythm.gd")
const CanalDressingScript = preload("canal_dressing.gd")
const VignettePlannerScript = preload("vignette_planner.gd")
const GeometryCheckScript = preload("geometry_check.gd")
const BridgeConnectivityResolverScript = preload("bridge_connectivity_resolver.gd")


static func generate_layout(
	width: int,
	height: int,
	seed_val: int,
	min_room_size: int,
	max_room_size: int,
	max_rooms: int,
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

	# Inicjalizacja siatki ścianami
	for y in range(height):
		for x in range(width):
			ctx.grid[Vector2i(x, y)] = CellType.WALL

	var reservations = StructuredReservationsScript.new()
	var canal_layout = CanalLayoutScript.new()
	result.canals = canal_layout
	ctx.canals = canal_layout

	var cfg_struct: Dictionary = flags.structured_config if flags != null else {}
	var linear_w: int = int(cfg_struct.get("linear_width", 4))
	var linear_clear: int = int(cfg_struct.get("linear_clear_margin", 16))
	var lane_w: int = int(cfg_struct.get("lane_width", 3))
	var wall_th_h: int = int(cfg_struct.get("wall_thickness_h", 5))
	var wall_th_v: int = int(cfg_struct.get("wall_thickness_v", 2))
	var dry_chance: float = float(flags.canal_dry_chance) if flags != null else 0.4

	# 1. Sieć liniowa (LinearNetworkGenerator)
	LinearNetworkGeneratorScript.generate_network(width, height, ctx.rng, canal_layout, linear_w, linear_clear, lane_w, dry_chance)
	GenProgress.end(&"rooms")

	# 2. Strefowanie (StructuredZoning)
	GenProgress.begin(&"corridors")
	var zoning_data: Dictionary = StructuredZoningScript.build_zoning(
		width, height, ctx.rng, canal_layout, reservations, linear_w, lane_w, wall_th_h, wall_th_v, dry_chance
	)

	# 3. Pokoje, korytarze, kładki (StructuredRoomPacker)
	var rooms: Array[Rect2i] = StructuredRoomPackerScript.pack_rooms_and_corridors(
		ctx, result, canal_layout, reservations, zoning_data, corridor_width
	)
	ctx.rooms = rooms
	result.rooms = rooms
	GenProgress.end(&"corridors")

	# 4. Portale (wejście / wyjście)
	GenProgress.begin(&"portals")
	var entrance_room_idx := 0
	var exit_room_idx: int = maxi(0, rooms.size() - 1)
	if not rooms.is_empty():
		var portal_indices := PortalGenerator.place_portals_in_rooms(ctx, result, rooms, flags, corridor_width)
		entrance_room_idx = int(portal_indices["entrance_room_idx"])
		exit_room_idx = int(portal_indices["exit_room_idx"])

	# 5. Pre-processing ścian
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

	# Gwarancja ciągłości koryt i braku ścian stykających się z brzegami
	_ensure_canal_clearance(ctx, canal_layout, lane_w)

	# Gwarancja przejścia do każdego fragmentu przez kładkę (Bridge Connectivity Resolver)
	BridgeConnectivityResolverScript.resolve(ctx, canal_layout)

	# Przywrócenie podłogi na kładkach po pre-processingu ścian
	for b in canal_layout.crossings:
		for p in b.get("cells", []):
			ctx.grid[p] = CellType.FLOOR

	GenProgress.end(&"portals")

	# 4. Rytm lica (FacadeRhythm)
	FacadeRhythmScript.apply_rhythm(ctx, result, reservations, flags)

	# 5. Dressing kanałów i barierki (CanalDressing)
	CanalDressingScript.apply_dressing(ctx, result, canal_layout, reservations, flags)

	# 6. Winiety (VignettePlanner)
	var default_vigs := VignettePlannerScript.get_default_vignettes()
	for room in rooms:
		var anchor := room.position + Vector2i(2, 2)
		if VignettePlannerScript.try_place_vignette(ctx, result, reservations, anchor, default_vigs["stacked_crates"]):
			break

	# 7. Kontrola geometrii B (GeometryCheck)
	var geo_report := GeometryCheckScript.verify_geometry(ctx, result, reservations)
	result.set_meta("geometry_check", geo_report)

	# 8. Płaskowyże (jeśli włączone)
	if flags.enable_platforms:
		GenProgress.begin(&"plateaus")
		ctx.plateau = PlateauPass.run(ctx, flags)
		result.plateau = ctx.plateau
		GenProgress.end()

	# 7. Obiekty i dekoracje
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

	# 8. Spawny wrogów i skrzyń
	GenProgress.begin(&"spawns")
	if not rooms.is_empty():
		SpawnPlanner.plan_spawns(ctx, result, entrance_room_idx, exit_room_idx)
	GenProgress.end(&"spawns")

	result.portal_zone = ctx.portal_zone
	result.preprocess_stats = ctx.preprocess_stats
	return ctx


static func _run_wall_shape_passes(ctx: GenerationContext, flags: GenerationFlags) -> void:
	if flags.enforce_3h_walls:
		GridPreprocessor.run(ctx, [Wall3HPassScript.new()])
	if flags.align_wall_tops:
		GridPreprocessor.run(ctx, [WallTopAlignPassScript.new()])
		if flags.enforce_3h_walls:
			GridPreprocessor.run(ctx, [Wall3HPassScript.new()])


## Gwarantuje, że koryta kanałów mają ciągłą strefę podłogi po bokach i nie stykają się ze ścianami.
static func _ensure_canal_clearance(ctx: GenerationContext, canal_layout, lane_w: int = 2) -> void:
	var width := ctx.width
	var height := ctx.height
	var grid: Dictionary = ctx.grid
	var water: Dictionary = canal_layout.cells

	# 1. Ciągły pas podłogi po obu stronach każdego segmentu kanału
	for st in canal_layout.segments:
		var r: Rect2i = st["rect"]
		var horiz: bool = (st["axis"] == "h")
		if horiz:
			for x in range(r.position.x, r.end.x):
				for dy in range(1, lane_w + 1):
					var pn := Vector2i(x, r.position.y - dy)
					var ps := Vector2i(x, r.end.y + dy - 1)
					if pn.x >= 2 and pn.x < width - 2 and pn.y >= 2 and pn.y < height - 2:
						if not water.has(pn):
							grid[pn] = CellType.FLOOR
					if ps.x >= 2 and ps.x < width - 2 and ps.y >= 2 and ps.y < height - 2:
						if not water.has(ps):
							grid[ps] = CellType.FLOOR
		else:
			for y in range(r.position.y, r.end.y):
				for dx in range(1, lane_w + 1):
					var pw := Vector2i(r.position.x - dx, y)
					var pe := Vector2i(r.end.x + dx - 1, y)
					if pw.x >= 2 and pw.x < width - 2 and pw.y >= 2 and pw.y < height - 2:
						if not water.has(pw):
							grid[pw] = CellType.FLOOR
					if pe.x >= 2 and pe.x < width - 2 and pe.y >= 2 and pe.y < height - 2:
						if not water.has(pe):
							grid[pe] = CellType.FLOOR

	# 2. Likwidacja wąskich szczelin ściany (<= 3 kratek) wciśniętych między sąsiednie kanały
	for p in water:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			for dist in range(1, 5):
				var check_p: Vector2i = p + d * dist
				if water.has(check_p):
					for mid_i in range(1, dist):
						var mid_p: Vector2i = p + d * mid_i
						if mid_p.x >= 2 and mid_p.x < width - 2 and mid_p.y >= 2 and mid_p.y < height - 2:
							if not water.has(mid_p):
								grid[mid_p] = CellType.FLOOR
					break

