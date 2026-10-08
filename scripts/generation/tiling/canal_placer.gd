extends RefCounted

## Kafle kanałów ścieków (CanalLayout). Role z profilu, wariant = układ sąsiedztwa:
## - Floor:      CANAL_FACE (lico brzegu w górnym rzędzie kanału pod podłogą i pod ścianą: M, L / R przy
##               podłodze, DL / DR / DLR przy ścianie, narożnik zewnętrzny OUT_NW / OUT_NE, środek M; wersje
##               _B / _C losowo; część modułu z własną warstwą w profilu, np. rim (0,-1) na
##               FloorDecor nad licem — wtedy profil nie ma obrzeży S* na tej kratce), CANAL_WATER (kwas, 9-slice: C, N, S, E, W, NE, NW, SE, SW
##               + narożniki wewnętrzne IN_NE / IN_NW / IN_SE / IN_SW; ściana obok = brzeg koryta);
##               puste koryto (canals.dry) — CANAL_BED z tymi samymi wariantami; doły w pustym korycie
##               (canals.pit_cells) — CANAL_PIT: VOID, TOP / TOP_B, BOTTOM (brak roli = zwykłe dno).
## - FloorDecor: CANAL_BANK na podłodze przy kanale (strona kanału: N / S / E / W, rogi wypukłe NE / NW /
##               SE / SW, wklęsłe IN_* tylko po skosie, ciemne końce przy ścianie S_DL / S_DR / N_DL /
##               N_DR / E_DT / E_DB / W_DT / W_DB; brak w profilu = wariant bez końca, np. N_DL -> N), wersje
##               _B / _C losowo. Pod końcami kładek wariant <nazwa>_OPEN (ten sam rysunek, kafel alternatywny
##               bez kolizji — przejście na kładkę); brak go w profilu = zwykły wariant (obrzeża bez kolizji).
## - Bridges:    kładki BRIDGE_V / BRIDGE_H (moduły na cały ślad: kanał + kratka brzegu z obu stron) na
##               osobnej warstwie nad FloorDecor.
## - Rails:      barierki CANAL_RAIL (canals.rail_cells: L, M, R, CL, CR; na brzegu północnym <v>_N, gdy jest
##               w profilu) — y-sort razem z postaciami.
## Brak roli w profilu = kratka pominięta (kanały to dodatek ścieków, bez stałych legacy).


static func plan(ctx: GenerationContext, placement_plan: TilePlacementPlan) -> void:
	var canals = ctx.canals
	if canals == null or canals.is_empty():
		return
	var table := ctx.priority_table
	var water: Dictionary = canals.water

	# 1. Kanał: lico brzegu i kwas (warstwa Floor). Wariant lica wg sąsiedztwa (lista od najlepszego —
	# brak w profilu = następny), wersje _B / _C wariantu losowane z hasha kratki (te, które są w profilu).
	var alts := {}
	for p: Vector2i in water:
		if _is_face(ctx, water, p):
			for fv in _face_variants(ctx, water, p):
				if _place_alt(ctx, placement_plan, p, TileModuleRole.Id.CANAL_FACE, fv, &"Floor", table, alts):
					break
		elif canals.pit_cells.has(p) and _place(ctx, placement_plan, p, TileModuleRole.Id.CANAL_PIT, canals.pit_cells[p], &"Floor", table):
			pass
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
				# kolejność: <v>_OPEN pod końcem kładki, <v>, wariant bez ciemnego końca (N_DL -> N)
				var tries: Array[StringName] = [v]
				if bridge_ends.has(q):
					tries.push_front(StringName(String(v) + "_OPEN"))
				var cut := String(v).find("_D")
				if cut > 0:
					tries.append(StringName(String(v).substr(0, cut)))
				for t in tries:
					if _place_alt(ctx, placement_plan, q, TileModuleRole.Id.CANAL_BANK, t, &"FloorDecor", table, alts):
						break

	# 4. Barierki (Rails — y-sort z postaciami jak Walls; kratka może mieć też lico muru). Brzeg północny (woda pod kratką barierki): wariant <v>_N, gdy
	# profil go ma (inny rysunek — barierka niżej, przy licu), inaczej zwykły.
	for p: Vector2i in canals.rail_cells:
		var rv: StringName = canals.rail_cells[p]
		if water.has(p + Vector2i(0, 1)) and _place(ctx, placement_plan, p, TileModuleRole.Id.CANAL_RAIL, StringName(String(rv) + "_N"), &"Rails", table):
			continue
		_place(ctx, placement_plan, p, TileModuleRole.Id.CANAL_RAIL, rv, &"Rails", table)


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


## Górny rząd kanału pod podłogą albo ścianą = lico brzegu (widok z południa); pod ścianą też — miedziane
## zagłębienie biegnie ciągle wzdłuż kanału (wzór: sewer-gen-v2 951b847).
static func _is_face(_ctx: GenerationContext, water: Dictionary, p: Vector2i) -> bool:
	return not water.has(p + Vector2i(0, -1))


## Warianty lica od najlepszego: koniec przy podłodze L / R, przy murze DL / DR / DLR (z obu stron),
## narożnik zewnętrzny OUT_NW / OUT_NE (podłoga nad licem kończy się — woda z boku i po skosie u góry),
## środek M. Placer bierze pierwszy, który jest w profilu.
static func _face_variants(ctx: GenerationContext, water: Dictionary, p: Vector2i) -> Array[StringName]:
	var wl := p + Vector2i(-1, 0)
	var wr := p + Vector2i(1, 0)
	if not water.has(wl):
		if GridUtils.is_walkable(ctx.grid, wl):
			return [&"L"]
		if not water.has(wr) and not GridUtils.is_walkable(ctx.grid, wr):
			return [&"DLR", &"DL"]
		return [&"DL"]
	if not water.has(wr):
		return [&"R"] if GridUtils.is_walkable(ctx.grid, wr) else [&"DR"]
	if water.has(p + Vector2i(-1, -1)):
		return [&"OUT_NW", &"M"]
	if water.has(p + Vector2i(1, -1)):
		return [&"OUT_NE", &"M"]
	return [&"M"]


## Wariant `base` albo jego wersja _B / _C / _D (losowo z hasha kratki spośród obecnych w profilu).
## `alts` — pamięć podręczna listy wersji na (rola, wariant).
static func _place_alt(ctx: GenerationContext, plan: TilePlacementPlan, p: Vector2i, role: int, base: StringName,
		layer: StringName, table: Dictionary, alts: Dictionary) -> bool:
	var key := [role, base]
	if not alts.has(key):
		var found: Array[StringName] = []
		var entry: TileRoleEntry = null
		var ts := ctx.map_tile_profile.get_default_tileset() if ctx.map_tile_profile else null
		if ts:
			entry = ts.get_entry(TileModuleRole.to_storage_role(role))
		for suffix in ["", "_B", "_C", "_D"]:
			var id := StringName(String(base) + suffix)
			if entry != null and entry.variants.any(func(v: TileVariant) -> bool: return v != null and v.variant_id == id):
				found.append(id)
		alts[key] = found
	var ids: Array = alts[key]
	if ids.is_empty():
		return _place(ctx, plan, p, role, base, layer, table)
	var pick: StringName = ids[hash([ctx.seed_value, p, base]) % ids.size()] if ids.size() > 1 else ids[0]
	return _place(ctx, plan, p, role, pick, layer, table)


## Kwas sąsiada: kanał (nie lico). Ściana obok nie jest kwasem — koryto ma prosty brzeg także przy murze,
## zamiast „wpływać” w fasadę bez krawędzi (wzór: sewer-gen-v2).
static func _acid(ctx: GenerationContext, water: Dictionary, q: Vector2i) -> bool:
	return water.has(q) and not _is_face(ctx, water, q)


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


## Kafle modułu roli `role` (wariant `variant`) od kotwicy; false, gdy profil nie ma tej roli / wariantu.
static func _place(ctx: GenerationContext, plan: TilePlacementPlan, anchor: Vector2i, role: int, variant: StringName, layer: StringName, table: Dictionary) -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, anchor, role, [], -1, variant)
	for rp in parts:
		var p := TilePlacement.new()
		p.pos = anchor + rp.offset
		# warstwa części z profilu, gdy inna niż domyślna (np. rim lica kanału na FloorDecor nad licem na Floor)
		p.layer = layer if rp.layer == &"" or rp.layer == &"Walls" else rp.layer
		p.source_id = rp.tile.source_id
		p.atlas_coords = rp.tile.atlas_coords
		p.alternative_tile = rp.tile.alternative_tile
		p.category = &"CANAL"
		PlacementPriority.assign(p, table)
		plan.queue(p)
	return not parts.is_empty()
