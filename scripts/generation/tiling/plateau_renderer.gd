class_name PlateauRenderer
extends RefCounted

const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const GenerationFlags = preload("res://modules/quiz_rpg/scripts/generation/core/generation_flags.gd")
const CellType = preload("res://modules/quiz_rpg/scripts/generation/core/cell_type.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")
const EdgeAnalyzer = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_analyzer.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const FacadePhasePlanner = preload("res://modules/quiz_rpg/scripts/generation/tiling/facade_phase_planner.gd")
const SideWallPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/side_wall_placer.gd")
const RimPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/rim_placer.gd")
const CornerPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/corner_placer.gd")
const MapTileProfile = preload("res://modules/quiz_rpg/scripts/generation/tiles/map_tile_profile.gd")
const TileSetField = preload("res://modules/quiz_rpg/scripts/generation/core/tileset_field.gd")

## Renderuje płaskowyże istniejącym pipeline'em ścian w trybie płaskowyżu (fasady 2H, moduły IN).
## Region płaskowyżu P = maska M (podłoga) + krawędzie prawdziwych ścian patrzące na M (E_M):
## płaskowyż „rysuje maksymalnie do wykrytych krawędzi, przy voidzie przestaje". Syntetyczna
## bryła = P ∪ void; zostają tylko kafle w P i w stopach lica P — nic w voidzie.

const TILESET_ID := &"caves_platform"
const LAYER := &"Platforms"
const WINDOW_MARGIN := 6
const DIRS4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const DIAG4: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
const FOOT_SEARCH := 3  # fasada ściany: stopa najwyżej 3 kratki niżej


## Zwraca {"tiles": pos -> TilePlacement (warstwa Platforms), "region": P, "missing": liczba kafli,
## które pipeline wziąłby ze stałych ścian (brak roli w rodzinie platform — odrzucone)}.
## mask: komórki PODŁOGI płaskowyżu. wall_cells: warstwa Walls planu mapy (pos -> TilePlacement).
static func render(real_ctx: GenerationContext, mask: Dictionary, wall_cells: Dictionary) -> Dictionary:
	var result := {"tiles": {}, "region": {}, "missing": 0}
	if mask.is_empty() or real_ctx.map_tile_profile == null:
		return result
	var platform_set = real_ctx.map_tile_profile.get_tileset(TILESET_ID)
	if platform_set == null:
		push_warning("PlateauRenderer: brak zestawu '%s' w profilu" % TILESET_ID)
		return result

	var region := build_region(real_ctx, mask, wall_cells)
	result.region = region
	var sgrid := _synthetic_grid(real_ctx, region, wall_cells)
	var sctx := _synthetic_ctx(real_ctx, sgrid, platform_set)

	var analysis = EdgeAnalyzer.analyze(sctx)
	var plan := TilePlacementPlan.new()
	var state := LegacyPlacementState.new()
	FacadePhasePlanner.plan(sctx, analysis, state, plan)
	SideWallPlacer.plan(sctx, analysis.edges, state, plan)
	RimPlacer.plan(sctx, analysis.edges, state, plan)
	CornerPlacer.plan(sctx, analysis.edges, state, plan)

	var tiles: Dictionary = result.tiles
	for layer_name in plan.by_layer:
		var cells: Dictionary = plan.by_layer[layer_name]
		for pos in cells:
			if not _keep(pos, region, sgrid):
				continue
			var p: TilePlacement = cells[pos]
			if layer_name != LAYER:
				# Placer użył stałej ściany (rola nieobecna w rodzinie platform) — nie mieszamy sztuki.
				result.missing += 1
				continue
			tiles[pos] = p
	return result


## Void = komórki ścian z kafelkiem SOLID_FILL (lite, nieprzezroczyste) albo bez kafla.
static func is_void(real_ctx: GenerationContext, wall_cells: Dictionary, pos: Vector2i) -> bool:
	if GridUtils.is_walkable(real_ctx.grid, pos):
		return false
	var p: TilePlacement = wall_cells.get(pos)
	return p == null or p.category == &"SOLID_FILL"


## P = M ∪ E_M. E_M = komórki krawędzi ścian (nie-void), które PATRZĄ na podłogę z M:
## sąsiad ortogonalny (bok, rim), a gdy go brak — diagonalny (narożnik), plus stopa fasady pod spodem.
static func build_region(real_ctx: GenerationContext, mask: Dictionary, wall_cells: Dictionary) -> Dictionary:
	# Kandydaci: sąsiedzi M (8 kierunków) oraz komórki nad M do FOOT_SEARCH (fasady ścian).
	var candidates := {}
	for m in mask:
		for d in DIRS4 + DIAG4:
			candidates[m + d] = true
		for k in range(2, FOOT_SEARCH + 1):
			candidates[m + Vector2i(0, -k)] = true
	var region := mask.duplicate()
	for w in candidates:
		if region.has(w) or GridUtils.is_walkable(real_ctx.grid, w) or is_void(real_ctx, wall_cells, w):
			continue
		if _faces_mask(real_ctx, w, mask):
			region[w] = true
	return region


static func _faces_mask(real_ctx: GenerationContext, w: Vector2i, mask: Dictionary) -> bool:
	var any_orth := false
	for d in DIRS4:
		var n: Vector2i = w + d
		if GridUtils.is_walkable(real_ctx.grid, n):
			any_orth = true
			if mask.has(n):
				return true
	if not any_orth:
		for d in DIAG4:
			if mask.has(w + d):
				return true
	# Fasada: stopa pod komórką ściany (przez komórki ściany, najwyżej FOOT_SEARCH w dół).
	var c := w
	for _i in range(FOOT_SEARCH):
		c += Vector2i(0, 1)
		if GridUtils.is_walkable(real_ctx.grid, c):
			return mask.has(c)
	return false


## Syntetyczny grid: bryła (WALL) = P ∪ void ∪ wszystko poza oknem wokół P; reszta = FLOOR.
static func _synthetic_grid(real_ctx: GenerationContext, region: Dictionary, wall_cells: Dictionary) -> Dictionary:
	var box := Rect2i()
	var first := true
	for c in region:
		if first:
			box = Rect2i(c, Vector2i.ONE)
			first = false
		else:
			box = box.expand(c)
	box = box.grow(WINDOW_MARGIN)
	var sgrid := {}
	for y in range(real_ctx.height):
		for x in range(real_ctx.width):
			var c := Vector2i(x, y)
			var solid: bool = not box.has_point(c) or region.has(c) or is_void(real_ctx, wall_cells, c)
			sgrid[c] = CellType.WALL if solid else CellType.FLOOR
	return sgrid


static func _synthetic_ctx(real_ctx: GenerationContext, sgrid: Dictionary, platform_set) -> GenerationContext:
	var sctx := GenerationContext.new()
	sctx.grid = sgrid
	sctx.width = real_ctx.width
	sctx.height = real_ctx.height
	sctx.seed_value = real_ctx.seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([real_ctx.seed_value, "plateau_tiles"])
	sctx.rng = rng
	sctx.tile_rng = rng
	var f := GenerationFlags.new()
	f.enable_decorative_niches = false
	f.enable_pillars = false
	sctx.flags = f
	sctx.theme_override = 0  # rock — bez korzeni
	sctx.plateau_mode = true
	sctx.priority_table = real_ctx.priority_table if not real_ctx.priority_table.is_empty() \
		else PlacementPriority.get_table(&"legacy_facade_wins", {})
	# Profil tylko z rodziną platform: resolver nie ma dokąd spaść (brak fallbacku do ścian).
	var profile := MapTileProfile.new()
	profile.tilesets = [platform_set]
	profile.default_tileset_id = TILESET_ID
	sctx.map_tile_profile = profile
	sctx.tileset_field = TileSetField.new()
	return sctx


## Zostają kafle w P i w stopie lica P (komórka nie-bryły, nad którą jest P).
static func _keep(pos: Vector2i, region: Dictionary, sgrid: Dictionary) -> bool:
	if region.has(pos):
		return true
	return int(sgrid.get(pos, CellType.WALL)) == CellType.FLOOR and region.has(pos + Vector2i(0, -1))
