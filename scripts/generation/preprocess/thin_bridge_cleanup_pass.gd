class_name ThinBridgeCleanupPass
extends "res://modules/quiz_rpg/scripts/generation/preprocess/grid_pass.gd"

func get_id() -> StringName:
	return &"thin_bridge_cleanup"


func should_carve_wall(_ctx: GenerationContext, _pos: Vector2i, w_n: bool, w_s: bool, w_w: bool, w_e: bool, _wall_cardinal: int) -> bool:
	# REGUŁA 2: Wąski pionowy mostek ściany
	return w_n and w_s and not w_w and not w_e
