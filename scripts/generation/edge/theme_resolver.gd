class_name ThemeResolver
extends RefCounted


enum RefPoint {
	SELF,
	NORTH_FLOOR,
	EAST_FLOOR,
	WEST_FLOOR
}

## Czysta funkcja wyznaczająca punkt próbkowania motywu na podstawie referencji.
static func resolve_sample_position(pos: Vector2i, ref_point: int) -> Vector2i:
	match ref_point:
		RefPoint.SELF:
			return pos
		RefPoint.NORTH_FLOOR:
			return pos + Vector2i(0, -1)
		RefPoint.EAST_FLOOR:
			return pos + Vector2i(1, 0)
		RefPoint.WEST_FLOOR:
			return pos + Vector2i(-1, 0)
		_:
			return pos


## Rozstrzyga theme_id (&"rock" lub &"roots") dla komórki i punktu odniesienia (§8.6).
static func resolve(ctx: GenerationContext, pos: Vector2i, ref_point: int) -> StringName:
	var effective_theme := ctx.theme_override if ctx.theme_override != -1 else (ctx.flags.force_theme if ctx.flags != null else -1)
	if effective_theme == 0:
		return &"rock"
	if effective_theme == 1:
		return &"roots"

	var noise := _get_or_create_theme_noise(ctx)
	var sample_pos := resolve_sample_position(pos, ref_point)
	sample_pos = _resolve_portal_uniform_sample(ctx, sample_pos)

	var val := noise.get_noise_2d(float(sample_pos.x), float(sample_pos.y))
	return &"roots" if val > 0.14 else &"rock"


static func _resolve_portal_uniform_sample(ctx: GenerationContext, sample_pos: Vector2i) -> Vector2i:
	var res_entrance := ctx.entrance_pos
	var res_exit := ctx.exit_pos
	if res_entrance != Vector2i.ZERO and abs(sample_pos.x - res_entrance.x) <= 4 and abs(sample_pos.y - res_entrance.y) <= 4:
		return res_entrance
	if res_exit != Vector2i.ZERO and abs(sample_pos.x - res_exit.x) <= 4 and abs(sample_pos.y - res_exit.y) <= 4:
		return res_exit
	return sample_pos


static func _get_or_create_theme_noise(ctx: GenerationContext) -> FastNoiseLite:
	if ctx.theme_noise != null:
		return ctx.theme_noise

	var noise := FastNoiseLite.new()
	var s: int = ctx.seed_value if ctx.seed_value != 0 else (ctx.rng.seed if ctx.rng != null else 0)
	noise.seed = s + 333
	noise.frequency = 0.08
	ctx.theme_noise = noise
	return noise
