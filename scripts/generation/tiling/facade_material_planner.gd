extends RefCounted

## Materiał lica (np. drewno zamiast kafli w ściekach v2): odcinki lica w jednym rzędzie, cięte na filarach
## (ctx.pillar_feet), dostają zestaw z JSON `facade_material.tileset`, gdy osobny szum w środku odcinka
## przekracza `threshold`. Wynik = pole zestawów (ctx.tileset_field) w kotwicach lica — placery lica, narożników,
## schodków i łączników biorą wtedy kafle z tego zestawu (role, których nie ma, spadają do domyślnego).
## Kolumna filara należy do odcinka po lewej.
##
## JSON: "facade_material": {"tileset": "sewer_wood", "frequency": 0.08, "threshold": 0.1}

static func apply(ctx: GenerationContext) -> void:
	var cfg: Dictionary = ctx.generator_behaviour.get("facade_material", {})
	var set_id := StringName(cfg.get("tileset", ""))
	if set_id == &"" or ctx.map_tile_profile == null or ctx.map_tile_profile.get_tileset(set_id) == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = hash([ctx.seed_value, "facade_material"])
	noise.frequency = float(cfg.get("frequency", 0.08))
	var threshold := float(cfg.get("threshold", 0.1))
	var on_wall := FacadePlacer.facade_on_wall(ctx)
	var water: Dictionary = ctx.canals.water if ctx.canals != null else {}

	# kotwice lica: podłoga pod murem (lico na murze) albo stopa muru nad podłogą (jaskinie)
	var rows := {}  # y -> [x...]
	for p: Vector2i in ctx.grid:
		if not GridUtils.is_walkable(ctx.grid, p) or water.has(p):
			continue
		var up := p + Vector2i(0, -1)
		if not ctx.grid.has(up) or GridUtils.is_walkable(ctx.grid, up) or water.has(up):
			continue
		var a := p if on_wall else up
		if not rows.has(a.y):
			rows[a.y] = []
		rows[a.y].append(a.x)

	# pole może być współdzielone (konfiguracja mapy) — piszemy w kopii
	var field := TileSetField.new()
	if ctx.tileset_field != null:
		field.cells = ctx.tileset_field.cells.duplicate()
	var any := false
	for y: int in rows:
		var xs: Array = rows[y]
		xs.sort()
		var seg: Array[int] = []
		for i in xs.size():
			var x: int = xs[i]
			if not seg.is_empty() and x != seg[-1] + 1:
				any = _close(field, seg, y, noise, threshold, set_id) or any
				seg = []
			seg.append(x)
			if ctx.pillar_feet.has(Vector2i(x, y)):
				any = _close(field, seg, y, noise, threshold, set_id) or any
				seg = []
		any = _close(field, seg, y, noise, threshold, set_id) or any
	if any:
		ctx.tileset_field = field


static func _close(field: TileSetField, seg: Array[int], y: int, noise: FastNoiseLite, threshold: float, set_id: StringName) -> bool:
	if seg.is_empty():
		return false
	var mid := (seg[0] + seg[-1]) * 0.5
	if noise.get_noise_2d(mid, float(y)) <= threshold:
		return false
	for x in seg:
		field.set_tileset_id(Vector2i(x, y), set_id)
	return true
