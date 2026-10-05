class_name FacadeRhythm
extends RefCounted

## Generator rytmu lica (filary, przęsła, ozdoby ścienne).
## Pass 4 w architekturze structured.

const StructuredReservations = preload("structured_reservations.gd")
const MapGeneratorBase = preload("../map_generator_base.gd")


static func apply_rhythm(
	ctx: GenerationContext,
	result: MapGeneratorBase.GenerationResult,
	reservations: StructuredReservations,
	flags: GenerationFlags
) -> Array[Dictionary]:
	var width := ctx.width
	var height := ctx.height
	var grid := ctx.grid
	var pillars: Array[Dictionary] = []

	var struct_cfg: Dictionary = flags.structured_config if flags != null else {}
	var rhythm_cfg: Dictionary = struct_cfg.get("facade_rhythm", {})
	var spacing_opts: Array = rhythm_cfg.get("pillar_spacing_options", [4, 5])
	var spacing: int = int(spacing_opts[0]) if not spacing_opts.is_empty() else 4

	# 1. Wykrycie odcinków północnego lica ścian (ściana z podłogą bezpośrednio na południu)
	for y in range(1, height - 2):
		var span_start := -1
		for x in range(1, width - 1):
			var p := Vector2i(x, y)
			var south_p := Vector2i(x, y + 1)
			var is_facade: bool = (grid.get(p) == MapGeneratorBase.CellType.WALL and grid.get(south_p) == MapGeneratorBase.CellType.FLOOR)

			if is_facade:
				if span_start < 0:
					span_start = x
			else:
				if span_start >= 0:
					_process_span(span_start, x - 1, y, spacing, reservations, pillars)
					span_start = -1

		if span_start >= 0:
			_process_span(span_start, width - 2, y, spacing, reservations, pillars)

	return pillars


static func _process_span(
	x_start: int,
	x_end: int,
	y: int,
	spacing: int,
	reservations: StructuredReservations,
	out_pillars: Array[Dictionary]
) -> void:
	var span_len := x_end - x_start + 1
	if span_len < 6:
		return

	# Wyśrodkowanie filarów w przęśle
	var usable := span_len - 2
	var count := usable / spacing
	if count <= 0:
		return

	var total_span := count * spacing
	var margin := (span_len - total_span) / 2
	var offset_x := x_start + margin

	for i in range(count + 1):
		var px := offset_x + i * spacing
		if px > x_end - 1:
			continue

		var wall_cell := Vector2i(px, y)
		var floor_cell := Vector2i(px, y + 1)

		# Rezerwacja: kratka ściany oraz kratka posadzki pod filarem/rurą
		var ok := reservations.claim(
			[wall_cell, floor_cell],
			&"facade_pillar",
			&"PILLAR",
			{"blocks_movement": false, "reserved_for_placement": true}
		)

		if ok:
			out_pillars.append({
				"wall_cell": wall_cell,
				"floor_cell": floor_cell,
				"index": i,
				"span_y": y
			})
