class_name TilePlacementPlanner
extends RefCounted

const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeAnalysisResult = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_analysis_result.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TerrainPaintPlan = preload("res://modules/quiz_rpg/scripts/generation/core/terrain_paint_plan.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")

const SolidFillPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/solid_fill_placer.gd")
const FloorPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/floor_placer.gd")
const TerrainMaskPlanner = preload("res://modules/quiz_rpg/scripts/generation/tiling/terrain_mask_planner.gd")
const FacadePhasePlanner = preload("res://modules/quiz_rpg/scripts/generation/tiling/facade_phase_planner.gd")
const SideWallPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/side_wall_placer.gd")
const RimPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/rim_placer.gd")
const CornerPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/corner_placer.gd")
const PortalClearPlacer = preload("res://modules/quiz_rpg/scripts/generation/tiling/portal_clear_placer.gd")

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
	SolidFillPlacer.plan(ctx, analysis.edges, state, tiles)

	# 2. Baza podłogi (Floor)
	var ground_cells: Array[Vector2i] = FloorPlacer.plan(ctx, tiles)

	# 3. Maski terenu: błoto na Floor oraz mech/trawa na FloorDecor
	TerrainMaskPlanner.plan_mud(ctx, terrain, ground_cells)
	TerrainMaskPlanner.plan_grass(ctx, terrain, ground_cells)

	# 4. Fasady południowe (2H, 3H, łączniki, narożniki OUT, schodki, nisze i FAZA 2.5)
	FacadePhasePlanner.plan(ctx, analysis, state, tiles)

	# 5. Ściany pionowe zachodnie i wschodnie
	SideWallPlacer.plan(ctx, analysis.edges, state, tiles)

	# 6. Rimy północne, misy skał i korzeni oraz tipsy
	RimPlacer.plan(ctx, analysis.edges, state, tiles)

	# 7. Diagonalne narożniki wewnętrzne (NW i NE)
	CornerPlacer.plan(ctx, analysis.edges, state, tiles)

	# 8. Czyszczenie kafelków ścian na strefach portali
	PortalClearPlacer.plan(ctx, tiles)

	return {
		"tiles": tiles,
		"terrain": terrain,
	}
