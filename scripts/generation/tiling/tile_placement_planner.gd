class_name TilePlacementPlanner
extends RefCounted


const GenProgress = preload("res://modules/quiz_rpg/scripts/generation/core/gen_progress.gd")

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

	# 2. Baza podłogi (Floor)
	GenProgress.begin(&"floor")
	var ground_cells: Array[Vector2i] = FloorPlacer.plan(ctx, tiles)

	# 3. Maski terenu: błoto na Floor oraz mech/trawa na FloorDecor (bez barier i schodów
	# płaskowyżu — baza podłogi pod nimi zostaje, bo rimy są półprzezroczyste)
	var terrain_cells := _without_plateau_edges(ctx, ground_cells)
	TerrainMaskPlanner.plan_mud(ctx, terrain, terrain_cells)
	TerrainMaskPlanner.plan_grass(ctx, terrain, terrain_cells)

	# 4. Fasady południowe (2H, 3H, łączniki, narożniki OUT, schodki, nisze i FAZA 2.5)
	GenProgress.begin(&"walls")
	FacadePhasePlanner.plan(ctx, analysis, state, tiles)

	# 5. Ściany pionowe zachodnie i wschodnie
	SideWallPlacer.plan(ctx, analysis.edges, state, tiles)

	# 6. Rimy północne, misy skał i korzeni oraz tipsy
	RimPlacer.plan(ctx, analysis.edges, state, tiles)

	# 7. Diagonalne narożniki wewnętrzne (NW i NE)
	CornerPlacer.plan(ctx, analysis.edges, state, tiles)

	# 8. Czyszczenie kafelków ścian na strefach portali
	PortalClearPlacer.plan(ctx, tiles)

	# 9. Płaskowyże na osobnej warstwie Platforms (po ścianach — renderer czyta plan Walls)
	GenProgress.begin(&"plateau_tiles")
	PlateauPlacer.plan(ctx, tiles)

	return {
		"tiles": tiles,
		"terrain": terrain,
	}


## Komórki terenu bez barier i schodów płaskowyżu. Bez płaskowyżu zwraca wejście bez zmian (parytet).
static func _without_plateau_edges(ctx: GenerationContext, cells: Array[Vector2i]) -> Array[Vector2i]:
	if ctx.plateau == null or ctx.plateau.is_empty():
		return cells
	var covered: Dictionary = ctx.plateau.blocked.duplicate()
	for c in ctx.plateau.stair_cells():
		covered[c] = true
	var out: Array[Vector2i] = []
	for c in cells:
		if not covered.has(c):
			out.append(c)
	return out
