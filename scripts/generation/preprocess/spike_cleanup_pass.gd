class_name SpikeCleanupPass
extends "res://modules/quiz_rpg/scripts/generation/preprocess/grid_pass.gd"

func get_id() -> StringName:
	return &"spike_cleanup"


func should_carve_wall(_ctx: GenerationContext, _pos: Vector2i, _w_n: bool, w_s: bool, w_w: bool, w_e: bool, wall_cardinal: int) -> bool:
	# REGUŁA 1: Wiszący ząbek / pojedyncza wypustka
	if wall_cardinal <= 1:
		return true

	# REGUŁA 3A: Ząbek ściany wysunięty na południe w pokój (między dwoma polami podłogi)
	if not w_s and not w_w and not w_e:
		return true

	return false
