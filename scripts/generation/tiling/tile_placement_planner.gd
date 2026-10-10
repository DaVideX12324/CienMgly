class_name TilePlacementPlanner
extends RefCounted

const CanalPlacerScript = preload("canal_placer.gd")
const Wall1WPlacerScript = preload("wall_1w_placer.gd")
const CurbPlacerScript = preload("curb_placer.gd")
const GratingPlannerScript = preload("grating_planner.gd")


const GenProgress = preload("../core/gen_progress.gd")

## Główny orkiestrator planowania kafelkowania (Etap 5).
## Koordynuje sekwencję placerów i generuje plany:
## {"tiles": TilePlacementPlan, "terrain": TerrainPaintPlan}.
static func plan(ctx: GenerationContext, analysis: EdgeAnalysisResult) -> Dictionary:
	if ctx.priority_table.is_empty():
		ctx.priority_table = PlacementPriority.get_table(&"legacy_facade_wins", {})

	var tiles := TilePlacementPlan.new()
	var terrain := TerrainPaintPlan.new()
	var state := LegacyPlacementState.new()

	# 1. Solid fill (zewnętrzny void padding oraz lita skała)
	GenProgress.begin(&"rock")
	SolidFillPlacer.plan(ctx, analysis.edges, state, tiles)
	GenProgress.end(&"rock")

	# 2. Baza podłogi (Floor)
	GenProgress.begin(&"floor")
	var ground_cells: Array[Vector2i] = FloorPlacer.plan(ctx, tiles)
	GenProgress.sub(0.5)

	# 3. Maski terenu: błoto na Floor oraz mech/trawa na FloorDecor (bez barier i schodów
	# płaskowyżu — baza podłogi pod nimi zostaje, bo rimy są półprzezroczyste)
	var terrain_cells := terrain_cells(ctx, ground_cells)
	TerrainMaskPlanner.plan_masks(ctx, terrain, terrain_cells)
	# Kanały ścieków: kwas / lico (Floor), obrzeża i kładki (FloorDecor).
	CanalPlacerScript.plan(ctx, tiles)
	# Kratownice w posadzce (teren na Floor)
	GratingPlannerScript.plan(ctx, terrain)
	# Krawężniki na progach korytarz -> pokój / kompleks (FloorDecor)
	CurbPlacerScript.plan(ctx, tiles)
	if CanalPlacerScript.bed_terrain(ctx) >= 0:
		var bed: Dictionary = CanalPlacerScript.bed_terrain_cells(ctx)
		terrain.add_batch(&"Floor", bed.cells, 0, CanalPlacerScript.bed_terrain(ctx), 1, true, bed.mask)
	GenProgress.end(&"floor")

	# 4. Fasady południowe (2H, 3H, łączniki, narożniki OUT, schodki, nisze i FAZA 2.5)
	GenProgress.begin(&"walls")
	FacadePhasePlanner.plan(ctx, analysis, state, tiles)
	GenProgress.sub(0.4)

	# 5. Ściany pionowe zachodnie i wschodnie
	SideWallPlacer.plan(ctx, analysis.edges, state, tiles)
	GenProgress.sub(0.6)

	# 6. Rimy północne, misy skał i korzeni oraz tipsy
	RimPlacer.plan(ctx, analysis.edges, state, tiles)
	GenProgress.sub(0.8)

	# 7. Diagonalne narożniki wewnętrzne (NW i NE)
	CornerPlacer.plan(ctx, analysis.edges, state, tiles)
	# 7b. Ściany szerokości 1 (wolnostojące występy muru na podłodze)
	Wall1WPlacerScript.plan(ctx, tiles)

	# 8. Czyszczenie kafelków ścian na strefach portali
	PortalClearPlacer.plan(ctx, tiles)
	NichePlacer.mark_passages(ctx, tiles)
	GenProgress.end(&"walls")

	# 9. Płaskowyże na osobnej warstwie Platforms (po ścianach — renderer czyta plan Walls)
	GenProgress.begin(&"plateau_tiles")
	PlateauPlacer.plan(ctx, tiles)
	GenProgress.end(&"plateau_tiles")

	return {
		"tiles": tiles,
		"terrain": terrain,
	}


## Komórki terenu bez barier i schodów płaskowyżu. Bez płaskowyżu zwraca wejście bez zmian (parytet).
## Lico na kratkach maski (ścieki, face_down 0): bez samego lica S i schodów S (nieprzezroczyste); rim, boki
## i przejścia schodów N / E / W dostają teren — cień podłogi przy linii krawędzi (TerrainMaskPlanner dzieli
## teren na górę platformy i resztę).
static func terrain_cells(ctx: GenerationContext, cells: Array[Vector2i]) -> Array[Vector2i]:
	if ctx.canals != null and not ctx.canals.is_empty():
		var dry: Array[Vector2i] = []
		for c in cells:
			if not ctx.canals.water.has(c):
				dry.append(c)
		cells = dry
	if ctx.plateau == null or ctx.plateau.is_empty():
		return cells
	var covered: Dictionary
	if ctx.plateau.face_down == 0:
		covered = plateau_opaque(ctx.plateau, ctx.grid)
	else:
		covered = ctx.plateau.blocked.duplicate()
		for c in ctx.plateau.stair_cells():
			covered[c] = true
	var out: Array[Vector2i] = []
	for c in cells:
		if not covered.has(c):
			out.append(c)
	return out


## Kratki pod nieprzezroczystym licem S platformy (lico na kratkach maski): w kolumnie nad krawędzią S (niżej
## chodliwa kratka spoza maski) krawędź + face_up - 1 rzędów (bez rzędu krawędzi krzyża), oraz schody S (bez górnego rzędu).
static func plateau_opaque(pl, grid: Dictionary) -> Dictionary:
	var out := {}
	for c in pl.mask:
		var below: Vector2i = c + Vector2i(0, 1)
		if pl.mask.has(below) or not GridUtils.is_walkable(grid, below) or pl.height_of(below) >= pl.height_of(c):
			continue
		for k in range(pl.face_up):  # górny rząd (krawędź krzyża) półprzezroczysty — teren pod nim, cień przy krawędzi
			out[c - Vector2i(0, k)] = true
	# Schody S: rzędy lica; górny rząd (stopnie zaczynają się niżej, nad licem wystają tylko poręcze) dostaje teren.
	for st in pl.stairs:
		for x in range(st.x, st.x + st.y):
			for y in range(st.z - pl.face_up + 1, st.z + pl.face_down + 1):
				out[Vector2i(x, y)] = true
	return out
