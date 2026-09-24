class_name OrganicCorridorCarver
extends "res://modules/quiz_rpg/scripts/generation/topology/corridor_carver.gd"

func carve(ctx: GenerationContext, from: Vector2i, to: Vector2i, width: int) -> void:
	var grid := ctx.grid
	var rng := ctx.rng
	var map_w := ctx.width
	var map_h := ctx.height
	var flags := ctx.flags

	if flags != null and flags.enable_meandering:
		var v_from := Vector2(from)
		var v_to := Vector2(to)
		var total_dist := v_from.distance_to(v_to)
		if total_dist < 1.0:
			return

		var path_noise := FastNoiseLite.new()
		path_noise.seed = rng.seed + int(from.x * 13 + from.y * 37)
		path_noise.frequency = 0.04
		path_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

		var width_noise := FastNoiseLite.new()
		width_noise.seed = rng.seed + int(to.x * 31 + to.y * 17)
		width_noise.frequency = 0.08

		var dir := (v_to - v_from).normalized()
		var normal := Vector2(-dir.y, dir.x)

		var num_control_pts := clampi(int(total_dist / 6.0), 3, 14)
		var control_points: Array[Vector2] = []
		control_points.append(v_from)

		var max_amplitude := clampf(total_dist * 0.22, 3.0, 10.0)

		for i in range(1, num_control_pts):
			var t := float(i) / float(num_control_pts)
			var base_pt := v_from.lerp(v_to, t)
			var envelope := sin(t * PI)
			var offset_val := path_noise.get_noise_1d(t * 120.0) * max_amplitude * envelope
			var pt := base_pt + normal * offset_val
			pt.x = clampf(pt.x, 4.0, float(map_w - 5))
			pt.y = clampf(pt.y, 4.0, float(map_h - 5))
			control_points.append(pt)

		control_points.append(v_to)

		var total_steps := int(total_dist * 2.5)
		var min_w := maxi(2, width - 1)
		var max_w := width + 2

		for s in range(total_steps + 1):
			var t_global := float(s) / maxf(float(total_steps), 1.0)
			var pt_index_float := t_global * float(control_points.size() - 1)
			var idx0 := clampi(int(floor(pt_index_float)), 0, control_points.size() - 1)
			var idx1 := clampi(idx0 + 1, 0, control_points.size() - 1)
			var local_t := pt_index_float - float(idx0)
			var cur_pos := control_points[idx0].lerp(control_points[idx1], local_t)

			var dynamic_width := float(width)
			if flags.enable_variable_width:
				var w_noise_val := (width_noise.get_noise_1d(t_global * 100.0) + 1.0) * 0.5
				dynamic_width = lerpf(float(min_w), float(max_w), w_noise_val)

			var funnel_factor := 0.0
			if flags.enable_funnels:
				funnel_factor = pow(1.0 - sin(t_global * PI), 2.0) * 2.2

			var final_radius := int((dynamic_width + funnel_factor) / 2.0) + 1
			GridUtils.carve_circle(grid, Vector2i(int(cur_pos.x), int(cur_pos.y)), final_radius, map_w, map_h, CellType.FLOOR)
	else:
		var mid := Vector2i(floori((from.x + to.x) / 2.0), floori((from.y + to.y) / 2.0))
		var dir := Vector2(to - from).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var jitter := normal * rng.randf_range(-3.0, 3.0)
		var mid_curved := Vector2i(mid + Vector2i(int(jitter.x), int(jitter.y)))
		mid_curved.x = clampi(mid_curved.x, 3, map_w - 4)
		mid_curved.y = clampi(mid_curved.y, 3, map_h - 4)

		var points = [from, mid_curved, to]
		for seg in range(points.size() - 1):
			var p0: Vector2 = Vector2(points[seg])
			var p1: Vector2 = Vector2(points[seg + 1])
			var dist := p0.distance_to(p1)
			var steps := int(dist * 2.0)
			for s in range(steps + 1):
				var t := float(s) / maxf(float(steps), 1.0)
				var cur := p0.lerp(p1, t)
				GridUtils.carve_circle(grid, Vector2i(int(cur.x), int(cur.y)), floori(width / 2.0) + 1, map_w, map_h, CellType.FLOOR)
