extends RefCounted

## Materiał lica (np. drewno zamiast kafli w ściekach v2). Ciąg lica = kotwice w jednym rzędzie bez przerwy.
## Materiał ciągu: w kompleksie / pokoju (ctx.canals.areas) jeden na cały obszar, żeby pomieszczenie miało jeden
## styl — zestaw z JSON `facade_material.tileset` z szansą `area_ratio`; w korytarzach i na chodnikach (i poza
## znanym obszarem) — wolny szum w środku ciągu (`frequency`, próg `threshold`). Ciąg cięty na filarach
## (ctx.pillar_feet; kolumna filara należy do odcinka po lewej) — odcinek odwraca materiał z szansą
## `segment_flip_chance`.
## Wynik = pole zestawów (ctx.tileset_field) w kotwicach lica — placery lica, narożników, schodków i łączników
## biorą kafle z tego zestawu (role, których w nim nie ma, spadają do domyślnego).
##
## JSON: "facade_material": {"tileset": "sewer_wood", "area_ratio": 0.4, "frequency": 0.03, "threshold": 0.1,
##        "segment_flip_chance": 0.1}

static func apply(ctx: GenerationContext) -> void:
	var cfg: Dictionary = ctx.generator_behaviour.get("facade_material", {})
	var set_id := StringName(cfg.get("tileset", ""))
	if set_id == &"" or ctx.map_tile_profile == null or ctx.map_tile_profile.get_tileset(set_id) == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = hash([ctx.seed_value, "facade_material"])
	noise.frequency = float(cfg.get("frequency", 0.03))
	var opts := {
		"seed": ctx.seed_value,
		"noise": noise,
		"threshold": float(cfg.get("threshold", 0.1)),
		"area_ratio": float(cfg.get("area_ratio", 0.4)),
		"flip": float(cfg.get("segment_flip_chance", 0.1)),
		"areas": ctx.canals.areas if ctx.canals != null and "areas" in ctx.canals else {},
		"set_id": set_id,
	}
	var on_wall := FacadePlacer.facade_on_wall(ctx)
	opts["floor_dy"] = 0 if on_wall else 1
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
		var run: Array[int] = []
		for i in xs.size():
			var x: int = xs[i]
			if not run.is_empty() and x != run[-1] + 1:
				any = _apply_run(field, run, y, ctx.pillar_feet, opts) or any
				run = []
			run.append(x)
		any = _apply_run(field, run, y, ctx.pillar_feet, opts) or any
	if any:
		ctx.tileset_field = field


## Ciąg lica w rzędzie: materiał wybierany raz na cały ciąg (obszar albo szum w jego środku), potem cięty na
## filarach — każdy odcinek może odwrócić materiał z szansą `segment_flip_chance`.
static func _apply_run(field: TileSetField, run: Array[int], y: int, pillar_feet: Dictionary, opts: Dictionary) -> bool:
	if run.is_empty():
		return false
	var wood := _is_wood(run, y, opts)
	var any := false
	var seg: Array[int] = []
	for x in run:
		seg.append(x)
		if pillar_feet.has(Vector2i(x, y)) or x == run[-1]:
			var w := wood
			if _unit(hash([opts.seed, seg[0], y, "facade_material_flip"])) < float(opts.flip):
				w = not w
			if w:
				for sx in seg:
					field.set_tileset_id(Vector2i(sx, y), opts.set_id)
				any = true
			seg = []
	return any


static func _is_wood(run: Array[int], y: int, opts: Dictionary) -> bool:
	# obszar ciągu = najczęstszy obszar kratek podłogi pod nim
	var areas: Dictionary = opts.areas
	var count := {}
	var best: StringName = &""
	var best_n := 0
	for x in run:
		var key: StringName = areas.get(Vector2i(x, y + int(opts.floor_dy)), &"")
		count[key] = int(count.get(key, 0)) + 1
		if int(count[key]) > best_n:
			best = key
			best_n = count[key]
	if best != &"" and best != &"corridor":
		return _unit(hash([opts.seed, String(best), "facade_material_area"])) < float(opts.area_ratio)
	var mid := (run[0] + run[-1]) * 0.5
	return (opts.noise as FastNoiseLite).get_noise_2d(mid, float(y)) > float(opts.threshold)


static func _unit(h: int) -> float:
	return float(h & 0xFFFF) / 65536.0
