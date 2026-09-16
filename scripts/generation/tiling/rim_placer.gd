class_name RimPlacer
extends RefCounted

const CaveTileConstants = preload("res://modules/quiz_rpg/scripts/generation/tiling/cave_tile_constants.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const LegacyPlacementState = preload("res://modules/quiz_rpg/scripts/generation/tiling/legacy_placement_state.gd")
const ThemeResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/theme_resolver.gd")
const TilePlacementPlan = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement_plan.gd")
const TilePlacement = preload("res://modules/quiz_rpg/scripts/generation/core/tile_placement.gd")
const PlacementPriority = preload("res://modules/quiz_rpg/scripts/generation/core/placement_priority.gd")

static func _get_variant_noise(ctx: GenerationContext) -> FastNoiseLite:
	if ctx.variant_noise != null:
		return ctx.variant_noise
	var n := FastNoiseLite.new()
	n.seed = ctx.seed_value + 777
	n.frequency = 0.45
	ctx.variant_noise = n
	return n


static func _queue(plan: TilePlacementPlan, pos: Vector2i, atlas_coords: Vector2i, category: StringName, table: Dictionary) -> void:
	var p := TilePlacement.new()
	p.pos = pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Planuje górny szczyt ściany (TOP_RIM), misy i dekoracje tips w porządku kanonicznym (y, x).
static func plan(
	ctx: GenerationContext,
	edges: Dictionary,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var width := ctx.width
	var height := ctx.height
	var grid := ctx.grid
	var table := ctx.priority_table
	var v_noise := _get_variant_noise(ctx)

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not GridUtils.is_walkable(grid, pos):
				var n_floor := GridUtils.is_walkable(grid, pos + Vector2i(0, -1))
				if not n_floor:
					continue

				if state.has(pos) and (state.get_category(pos) == &"FACADE" or state.get_category(pos) == &"SIDE_FIXED"):
					continue

				# Jeśli pod ścianą jest podłoga (tylko 1 kratka ściany w pionie), pomiń
				if GridUtils.is_walkable(grid, pos + Vector2i(0, 1)):
					continue

				var w_floor := GridUtils.is_walkable(grid, pos + Vector2i(-1, 0))
				var e_floor := GridUtils.is_walkable(grid, pos + Vector2i(1, 0))
				var se_floor := GridUtils.is_walkable(grid, pos + Vector2i(1, 1))
				var sw_floor := GridUtils.is_walkable(grid, pos + Vector2i(-1, 1))
				var nw_floor := GridUtils.is_walkable(grid, pos + Vector2i(-1, -1))
				var ne_floor := GridUtils.is_walkable(grid, pos + Vector2i(1, -1))

				# Edge case skośnego styku ściany:
				# 011 / 000 / 100 -> narożnik NW
				# 110 / 000 / 001 -> narożnik NE
				var is_edge_diag_left: bool = (not nw_floor and ne_floor) and (not w_floor and not e_floor) and (sw_floor and not se_floor)
				var is_edge_diag_right: bool = (nw_floor and not ne_floor) and (not w_floor and not e_floor) and (se_floor and not sw_floor)

				var use_roots: bool = ThemeResolver.resolve(ctx, pos, ThemeResolver.RefPoint.NORTH_FLOOR) == &"roots"

				var is_2h_touch_left: bool = state.has(pos + Vector2i(-1, 0)) and (state.get_category(pos + Vector2i(-1, 0)) == &"FACADE" or state.get_category(pos + Vector2i(-1, 0)) == &"CORNER")
				var is_2h_touch_right: bool = state.has(pos + Vector2i(1, 0)) and (state.get_category(pos + Vector2i(1, 0)) == &"FACADE" or state.get_category(pos + Vector2i(1, 0)) == &"CORNER")

				var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0

				if not use_roots:
					# Motyw rock (1-kafelkowy)
					var rim_t := Vector2i(2, 0)
					if e_floor and not w_floor:
						rim_t = CaveTileConstants.CRNR_SE_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SE_OUT_BASE_A
					elif w_floor and not e_floor:
						rim_t = CaveTileConstants.CRNR_SW_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SW_OUT_BASE_A
					elif is_edge_diag_left:
						rim_t = CaveTileConstants.CRNR_SW_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SW_OUT_BASE_A
					elif is_edge_diag_right:
						rim_t = CaveTileConstants.CRNR_SE_OUT_BASE_B if is_b else CaveTileConstants.CRNR_SE_OUT_BASE_A
					elif is_2h_touch_left or is_2h_touch_right:
						rim_t = Vector2i(3, 0) if is_b else Vector2i(2, 0)
					else:
						rim_t = Vector2i(3, 0) if is_b else Vector2i(2, 0)

					_queue(plan, pos, rim_t, &"RIM_BASE", table)
					state.mark(pos, &"RIM")

				else:
					# Motyw roots (2-kafelkowy kompletny moduł TOP + BASE)
					var p_top := pos + Vector2i(0, -1)
					var can_place_top: bool = not (state.has(p_top) and state.get_category(p_top) == &"FACADE")
					var t_base := Vector2i(2, 9)
					var t_tips := Vector2i(2, 8)

					if e_floor and not w_floor:
						t_base = CaveTileConstants.CRNR_SE_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_BASE
						t_tips = CaveTileConstants.CRNR_SE_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_TIPS
					elif w_floor and not e_floor:
						t_base = CaveTileConstants.CRNR_SW_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_BASE
						t_tips = CaveTileConstants.CRNR_SW_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_TIPS
					elif is_edge_diag_left:
						t_base = CaveTileConstants.CRNR_SW_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_BASE
						t_tips = CaveTileConstants.CRNR_SW_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SW_OUT_DECORATED_A_TIPS
					elif is_edge_diag_right:
						t_base = CaveTileConstants.CRNR_SE_OUT_DECORATED_B_BASE if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_BASE
						t_tips = CaveTileConstants.CRNR_SE_OUT_DECORATED_B_TIPS if is_b else CaveTileConstants.CRNR_SE_OUT_DECORATED_A_TIPS
					elif is_2h_touch_left or is_2h_touch_right:
						t_base = CaveTileConstants.ROOT_TOP_BASE[1] if is_b else CaveTileConstants.ROOT_TOP_BASE[0]
						t_tips = CaveTileConstants.ROOT_TOP_TIPS[1] if is_b else CaveTileConstants.ROOT_TOP_TIPS[0]
					else:
						t_base = CaveTileConstants.ROOT_TOP_BASE[1] if is_b else CaveTileConstants.ROOT_TOP_BASE[0]
						t_tips = CaveTileConstants.ROOT_TOP_TIPS[1] if is_b else CaveTileConstants.ROOT_TOP_TIPS[0]

					_queue(plan, pos, t_base, &"RIM_BASE", table)
					state.mark(pos, &"RIM")
					if can_place_top:
						_queue(plan, p_top, t_tips, &"RIM_TIP", table)
						state.mark(p_top, &"RIM")
