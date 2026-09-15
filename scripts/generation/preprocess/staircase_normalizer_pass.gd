class_name StaircaseNormalizerPass
extends "res://modules/quiz_rpg/scripts/generation/preprocess/grid_pass.gd"

func get_id() -> StringName:
	return &"staircase_normalizer"


func should_carve_wall(ctx: GenerationContext, pos: Vector2i, _w_n: bool, w_s: bool, w_w: bool, w_e: bool, _wall_cardinal: int) -> bool:
	# REGUŁA 3B: Anomalia grubości 2H vs 3H od północy
	if not w_w and not w_e:
		var floor_sw := GridUtils.is_walkable(ctx.grid, pos + Vector2i(-1, 1))
		var floor_se := GridUtils.is_walkable(ctx.grid, pos + Vector2i(1, 1))
		if w_s and not floor_sw and not floor_se:
			return true
	return false
