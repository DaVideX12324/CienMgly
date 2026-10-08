extends RefCounted

## Kafle kanałów ścieków (CanalLayout). Role z profilu, wariant = układ sąsiedztwa:
## - Floor:      CANAL_FACE (lico brzegu w górnym rzędzie kanału pod podłogą: M, L / R przy podłodze,
##               DL / DR przy ścianie), CANAL_WATER (kwas, 9-slice: C, N, S, E, W, NE, NW, SE, SW
##               + narożniki wewnętrzne IN_NE / IN_NW / IN_SE / IN_SW; ściana obok = kwas płynie pod mur);
##               puste koryto (canals.dry) — CANAL_BED z tymi samymi wariantami.
## - FloorDecor: CANAL_BANK na podłodze przy kanale (strona kanału: N / S / E / W, rogi wypukłe NE / NW /
##               SE / SW, wklęsłe IN_* tylko po skosie, ciemne końce przy ścianie S_DL / S_DR / N_DL /
##               N_DR / E_DT / E_DB / W_DT / W_DB). Pod końcami kładek wariant <nazwa>_OPEN (ten sam
##               rysunek, kafel alternatywny bez kolizji — przejście na kładkę); brak go w profilu = kratka
##               bez obrzeża (też bez kolizji).
## - Bridges:    kładki BRIDGE_V / BRIDGE_H (moduły na cały ślad: kanał + kratka brzegu z obu stron) na
##               osobnej warstwie nad FloorDecor.
## Brak roli w profilu = kratka pominięta (kanały to dodatek ścieków, bez stałych legacy).


static func plan(ctx: GenerationContext, placement_plan: TilePlacementPlan) -> void:
	var canals = ctx.canals
	if canals == null or canals.is_empty():
		return
	var table := ctx.priority_table
	var water: Dictionary = canals.water

	# 1. Kanał: lico brzegu i kwas (warstwa Floor).
	for p: Vector2i in water:
		if _is_face(ctx, water, p):
			_place(ctx, placement_plan, p, TileModuleRole.Id.CANAL_FACE, _face_variant(ctx, water, p), &"Floor", table)
		else:
			var role: int = TileModuleRole.Id.CANAL_BED if canals.dry.has(p) else TileModuleRole.Id.CANAL_WATER
			_place(ctx, placement_plan, p, role, _water_variant(ctx, water, p), &"Floor", table)

	# 2. Kładki (Bridges) — cały ślad; kratki brzegu pod końcami zapamiętane dla obrzeży bez kolizji.
	var bridge_ends := {}
	for b in canals.bridges:
		var r := bridge_rect(b)
		var role: int = TileModuleRole.Id.BRIDGE_V if b.get("vertical", true) else TileModuleRole.Id.BRIDGE_H
		_place(ctx, placement_plan, r.position, role, &"A", &"Bridges", table)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if not water.has(Vector2i(x, y)):
					bridge_ends[Vector2i(x, y)] = true

	# 3. Obrzeża na podłodze przy kanale (FloorDecor); pod końcami kładek wersja bez kolizji.
	var seen := {}
	for p: Vector2i in water:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := p + Vector2i(dx, dy)
				if seen.has(q) or water.has(q) or canals.bridge_cells.has(q) or not GridUtils.is_walkable(ctx.grid, q):
					continue
				seen[q] = true
				var v := _bank_variant(ctx, water, q)
				if v == &"":
					continue
				if bridge_ends.has(q):
					v = StringName(String(v) + "_OPEN")
				_place(ctx, placement_plan, q, TileModuleRole.Id.CANAL_BANK, v, &"FloorDecor", table)


## Ślad modułu kładki: `rect` z nakładki albo prostokąt otaczający jej kratki.
static func bridge_rect(b: Dictionary) -> Rect2i:
	var r: Rect2i = b.get("rect", Rect2i())
	if r == Rect2i() and b.has("cells") and not b.cells.is_empty():
		var min_p: Vector2i = b.cells[0]
		var max_p: Vector2i = b.cells[0]
		for p in b.cells:
			min_p.x = mini(min_p.x, p.x)
			min_p.y = mini(min_p.y, p.y)
			max_p.x = maxi(max_p.x, p.x)
			max_p.y = maxi(max_p.y, p.y)
		r = Rect2i(min_p, max_p - min_p + Vector2i(1, 1))
	return r


## Górny rząd kanału pod podłogą = lico brzegu (widok z południa).
static func _is_face(ctx: GenerationContext, water: Dictionary, p: Vector2i) -> bool:
	var n := p + Vector2i(0, -1)
	return not water.has(n) and GridUtils.is_walkable(ctx.grid, n)


static func _face_variant(ctx: GenerationContext, water: Dictionary, p: Vector2i) -> StringName:
	var wl := p + Vector2i(-1, 0)
	var wr := p + Vector2i(1, 0)
	if not water.has(wl):
		return &"L" if GridUtils.is_walkable(ctx.grid, wl) else &"DL"
	if not water.has(wr):
		return &"R" if GridUtils.is_walkable(ctx.grid, wr) else &"DR"
	return &"M"


## Kwas sąsiada: kanał (nie lico) albo ściana (kanał wpływa pod mur).
static func _acid(ctx: GenerationContext, water: Dictionary, q: Vector2i) -> bool:
	if water.has(q):
		return not _is_face(ctx, water, q)
	return not GridUtils.is_walkable(ctx.grid, q)


static func _water_variant(ctx: GenerationContext, water: Dictionary, p: Vector2i) -> StringName:
	var n := _acid(ctx, water, p + Vector2i(0, -1))
	var s := _acid(ctx, water, p + Vector2i(0, 1))
	var e := _acid(ctx, water, p + Vector2i(1, 0))
	var w := _acid(ctx, water, p + Vector2i(-1, 0))
	if not n and not w: return &"NW"
	if not n and not e: return &"NE"
	if not s and not w: return &"SW"
	if not s and not e: return &"SE"
	if not n: return &"N"
	if not s: return &"S"
	if not w: return &"W"
	if not e: return &"E"
	if not _acid(ctx, water, p + Vector2i(1, 1)): return &"IN_SE"
	if not _acid(ctx, water, p + Vector2i(-1, 1)): return &"IN_SW"
	if not _acid(ctx, water, p + Vector2i(1, -1)): return &"IN_NE"
	if not _acid(ctx, water, p + Vector2i(-1, -1)): return &"IN_NW"
	return &"C"


## Obrzeże kratki podłogi `q` wg kanału obok. Ciemny koniec, gdy obrzeże dochodzi do ściany, a kanał
## płynie dalej pod nią.
static func _bank_variant(ctx: GenerationContext, water: Dictionary, q: Vector2i) -> StringName:
	var n := water.has(q + Vector2i(0, -1))
	var s := water.has(q + Vector2i(0, 1))
	var e := water.has(q + Vector2i(1, 0))
	var w := water.has(q + Vector2i(-1, 0))
	var wall := func(d: Vector2i) -> bool:
		var c := q + d
		return not water.has(c) and not GridUtils.is_walkable(ctx.grid, c)
	if s and e: return &"SE"
	if s and w: return &"SW"
	if n and e: return &"NE"
	if n and w: return &"NW"
	if s:
		if wall.call(Vector2i(-1, 0)) and water.has(q + Vector2i(-1, 1)): return &"S_DL"
		if wall.call(Vector2i(1, 0)) and water.has(q + Vector2i(1, 1)): return &"S_DR"
		return &"S"
	if n:
		if wall.call(Vector2i(-1, 0)) and water.has(q + Vector2i(-1, -1)): return &"N_DL"
		if wall.call(Vector2i(1, 0)) and water.has(q + Vector2i(1, -1)): return &"N_DR"
		return &"N"
	if e:
		if wall.call(Vector2i(0, -1)) and water.has(q + Vector2i(1, -1)): return &"E_DT"
		if wall.call(Vector2i(0, 1)) and water.has(q + Vector2i(1, 1)): return &"E_DB"
		return &"E"
	if w:
		if wall.call(Vector2i(0, -1)) and water.has(q + Vector2i(-1, -1)): return &"W_DT"
		if wall.call(Vector2i(0, 1)) and water.has(q + Vector2i(-1, 1)): return &"W_DB"
		return &"W"
	if water.has(q + Vector2i(1, 1)): return &"IN_SE"
	if water.has(q + Vector2i(-1, 1)): return &"IN_SW"
	if water.has(q + Vector2i(1, -1)): return &"IN_NE"
	if water.has(q + Vector2i(-1, -1)): return &"IN_NW"
	return &""


static func _place(ctx: GenerationContext, plan: TilePlacementPlan, anchor: Vector2i, role: int, variant: StringName, layer: StringName, table: Dictionary) -> void:
	var parts := TileResolver.resolve_module_parts(ctx, anchor, role, [], -1, variant)
	for rp in parts:
		var p := TilePlacement.new()
		p.pos = anchor + rp.offset
		p.layer = layer
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"CANAL"
		PlacementPriority.assign(p, table)
		plan.queue(p)
