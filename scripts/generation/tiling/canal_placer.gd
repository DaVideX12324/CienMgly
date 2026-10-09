extends RefCounted

## Kafle kanałów ścieków (CanalLayout). Role z profilu, wariant = układ sąsiedztwa:
## - Floor:      CANAL_FACE (lico brzegu w górnym rzędzie kanału pod podłogą i pod ścianą: M, L / R przy
##               podłodze, DL / DR / DLR przy ścianie, narożnik zewnętrzny OUT_NW / OUT_NE, środek M; wersje
##               _B / _C losowo; część modułu z własną warstwą w profilu, np. rim (0,-1) na
##               FloorDecor nad licem — wtedy profil nie ma obrzeży S* na tej kratce), CANAL_WATER (kwas, 9-slice: C, N, S, E, W, NE, NW, SE, SW
##               + narożniki wewnętrzne IN_NE / IN_NW / IN_SE / IN_SW; ściana obok = brzeg koryta);
##               puste koryto (canals.dry) — CANAL_BED z tymi samymi wariantami; doły w pustym korycie
##               (canals.pit_cells) — CANAL_PIT: VOID, TOP / TOP_B, BOTTOM (brak roli = zwykłe dno). Pod kładką
##               wariant <nazwa>_OPEN (kafle bez kolizji), gdy jest w profilu.
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
	# Pod kładką najpierw wariant <v>_OPEN (kafle bez kolizji — przejście po kładce), gdy jest w profilu.
	for p: Vector2i in water:
		var under: bool = canals.bridge_cells.has(p)
		if _is_face(ctx, water, p):
			for fv in _face_variants(ctx, water, p):
				if under and _place_alt(ctx, placement_plan, p, TileModuleRole.Id.CANAL_FACE, StringName(String(fv) + "_OPEN"), &"Floor", table, alts):
					break
				if _place_alt(ctx, placement_plan, p, TileModuleRole.Id.CANAL_FACE, fv, &"Floor", table, alts):
					break
		elif canals.pit_cells.has(p) and _place_open(ctx, placement_plan, p, TileModuleRole.Id.CANAL_PIT, canals.pit_cells[p], under, table):
			pass
		elif canals.dry.has(p) and bed_terrain(ctx) >= 0:
			pass  # puste koryto terenem (TilePlacementPlanner -> bed_terrain_cells)
		else:
			var role: int = TileModuleRole.Id.CANAL_BED if canals.dry.has(p) else TileModuleRole.Id.CANAL_WATER
			_place_open(ctx, placement_plan, p, role, _water_variant(ctx, water, p), under, table)

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
				# kolejność: <v>, wariant bez ciemnego końca (N_DL -> N); pod końcem kładki najpierw ich wersje _OPEN
				var tries: Array[StringName] = [v]
				var cut := String(v).find("_D")
				if cut > 0:
					tries.append(StringName(String(v).substr(0, cut)))
				if bridge_ends.has(q):
					var opens: Array[StringName] = []
					for t0 in tries:
						opens.append(StringName(String(t0) + "_OPEN"))
					tries = opens + tries
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


## Teren pustego koryta (tiling.canal_bed_terrain w companion-JSON, id terenu w terrain_set 0); -1 = kafle CANAL_BED.
static func bed_terrain(ctx: GenerationContext) -> int:
	return int(ctx.generator_behaviour.get("tiling", {}).get("canal_bed_terrain", -1))


## Kratki pustego koryta do pomalowania terenem: suche, bez lica brzegu i dołów. Maska sąsiedztwa = całe puste
## koryto (lico i doły też), żeby krawędzie terenu wypadały tylko na brzegu koryta.
static func bed_terrain_cells(ctx: GenerationContext) -> Dictionary:
	var canals = ctx.canals
	var paint: Array[Vector2i] = []
	var mask: Array[Vector2i] = []
	if canals == null or canals.is_empty():
		return {"cells": paint, "mask": mask}
	for p: Vector2i in canals.dry:
		mask.append(p)
		if not _is_face(ctx, canals.water, p) and not canals.pit_cells.has(p):
			paint.append(p)
	paint.sort()
	mask.sort()
	return {"cells": paint, "mask": mask}


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
## zagłębienie biegnie ciągle wzdłuż kanału (wzór: sewer-gen-v2 951b847). Wyjątek: koniec kanału prostopadły do
## lica ściany (_faceless) — z szansą tiling.canal_end_face_chance zostaje z licem, inaczej kwas dochodzi do muru.
static func _is_face(ctx: GenerationContext, water: Dictionary, p: Vector2i) -> bool:
	if water.has(p + Vector2i(0, -1)):
		return false
	return ctx == null or not _faceless(ctx, water).has(p)


## Końce kanałów na ścianie: krótki ciąg (<= linear_width + 1) kratek wody wzdłuż ściany, z murem za każdą (w kierunku
## d), bez wody na końcach ciągu, z wodą przed każdą (kanał płynie od strony -d). Kanał wzdłuż ściany (długi ciąg)
## się nie liczy. Z szansą 1 - tiling.canal_end_face_chance (losowane hashem ciągu) koniec jest „otwarty":
## - północny (lico ściany nad kanałem): górny rząd bez lica kanału (wynik: kratki bez lica);
## - każdy kierunek, gdy tiling.canal_end_under_wall: kanał płynie dalej pod ścianą — kratki muru za końcem
##   trafiają do _under_wall (przy wyborze wariantów liczą się jak woda).
## Liczone raz na kontekst (meta).
static func _faceless(ctx: GenerationContext, water: Dictionary) -> Dictionary:
	if ctx.has_meta(&"canal_faceless"):
		return ctx.get_meta(&"canal_faceless")
	var out := {}
	var under := {}
	ctx.set_meta(&"canal_faceless", out)
	ctx.set_meta(&"canal_under_wall", under)
	var cont := bool(ctx.generator_behaviour.get("tiling", {}).get("canal_end_under_wall", false))
	var chance := float(ctx.generator_behaviour.get("tiling", {}).get("canal_end_face_chance", 1.0))
	# końce północne (lico ściany nad kanałem) mogą mieć własną szansę na lico kanału
	var chance_n := float(ctx.generator_behaviour.get("tiling", {}).get("canal_north_face_chance", chance))
	if chance >= 1.0 and chance_n >= 1.0:
		return out
	var max_run := int(ctx.generator_behaviour.get("structured_layout", {}).get("linear_width", 4)) + 1
	var wall := func(c: Vector2i) -> bool:
		return not water.has(c) and not GridUtils.is_walkable(ctx.grid, c)
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if d.y >= 0 and not cont:
			continue   # bez canal_end_under_wall tylko końce północne (lico kanału)
		var t := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
		var seen := {}
		for p: Vector2i in water:
			if seen.has(p) or not wall.call(p + d):
				continue
			var a := p   # początek ciągu
			while water.has(a - t) and wall.call(a - t + d):
				a -= t
			var run: Array[Vector2i] = []
			var c := a
			while water.has(c) and wall.call(c + d):
				run.append(c)
				seen[c] = true
				c += t
			if run.size() > max_run or water.has(a - t) or water.has(c):
				continue
			var flows := true
			for q in run:
				flows = flows and water.has(q - d)
			if not flows:
				continue
			var u := float(hash([ctx.seed_value, a, "canal_end_face" if d.y < 0 else "canal_end_under"]) & 0xFFFF) / 65536.0
			if u < (chance_n if d.y < 0 else chance):
				continue
			for q in run:
				if d.y < 0:
					out[q] = true
				if cont:
					under[q + d] = true
	return out


## Kratki muru nad końcami kanałów bez lica, gdy tiling.canal_end_under_wall: kanał „płynie dalej pod ścianą" —
## przy wyborze wariantów kwasu i obrzeży liczą się jak woda (bez krawędzi zamykającej kanał, ciemne końce obrzeży).
static func _under_wall(ctx: GenerationContext, water: Dictionary) -> Dictionary:
	_faceless(ctx, water)
	return ctx.get_meta(&"canal_under_wall", {})


## Warianty lica od najlepszego: koniec przy podłodze L / R, przy murze DL / DR / DLR (z obu stron),
## narożnik zewnętrzny OUT_NW / OUT_NE (podłoga nad licem kończy się — woda z boku i po skosie u góry),
## środek M. Placer bierze pierwszy, który jest w profilu.
static func _face_variants(ctx: GenerationContext, water: Dictionary, p: Vector2i) -> Array[StringName]:
	var under := _under_wall(ctx, water)   # kanał płynący pod ścianą boczną — lico ciągnie się dalej (M)
	var wl := p + Vector2i(-1, 0)
	var wr := p + Vector2i(1, 0)
	if not water.has(wl) and not under.has(wl):
		if GridUtils.is_walkable(ctx.grid, wl):
			return [&"L"]
		if not water.has(wr) and not under.has(wr) and not GridUtils.is_walkable(ctx.grid, wr):
			return [&"DLR", &"DL"]
		return [&"DL"]
	if not water.has(wr) and not under.has(wr):
		return [&"R"] if GridUtils.is_walkable(ctx.grid, wr) else [&"DR"]
	if water.has(p + Vector2i(-1, -1)):
		return [&"OUT_NW", &"M"]
	if water.has(p + Vector2i(1, -1)):
		return [&"OUT_NE", &"M"]
	return [&"M"]


## Kratka kanału na warstwie Floor: pod kładką najpierw <variant>_OPEN, potem zwykły.
static func _place_open(ctx: GenerationContext, plan: TilePlacementPlan, p: Vector2i, role: int, variant: StringName,
		under_bridge: bool, table: Dictionary) -> bool:
	if under_bridge and _place(ctx, plan, p, role, StringName(String(variant) + "_OPEN"), &"Floor", table):
		return true
	return _place(ctx, plan, p, role, variant, &"Floor", table)


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
	if ctx != null and _under_wall(ctx, water).has(q):
		return true
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
static func _bank_variant(ctx: GenerationContext, water0: Dictionary, q: Vector2i) -> StringName:
	# kanał płynący pod ścianą (_under_wall) — mur nad końcem kanału liczy się jak woda
	var under := _under_wall(ctx, water0)
	var wet := func(c: Vector2i) -> bool:
		return water0.has(c) or under.has(c)
	var n: bool = wet.call(q + Vector2i(0, -1))
	var s: bool = wet.call(q + Vector2i(0, 1))
	var e: bool = wet.call(q + Vector2i(1, 0))
	var w: bool = wet.call(q + Vector2i(-1, 0))
	var wall := func(d: Vector2i) -> bool:
		var c := q + d
		return not wet.call(c) and not GridUtils.is_walkable(ctx.grid, c)
	if s and e: return &"SE"
	if s and w: return &"SW"
	if n and e: return &"NE"
	if n and w: return &"NW"
	if s:
		if wall.call(Vector2i(-1, 0)) and wet.call(q + Vector2i(-1, 1)): return &"S_DL"
		if wall.call(Vector2i(1, 0)) and wet.call(q + Vector2i(1, 1)): return &"S_DR"
		return &"S"
	if n:
		if wall.call(Vector2i(-1, 0)) and wet.call(q + Vector2i(-1, -1)): return &"N_DL"
		if wall.call(Vector2i(1, 0)) and wet.call(q + Vector2i(1, -1)): return &"N_DR"
		return &"N"
	if e:
		if wall.call(Vector2i(0, -1)) and wet.call(q + Vector2i(1, -1)): return &"E_DT"
		if wall.call(Vector2i(0, 1)) and wet.call(q + Vector2i(1, 1)): return &"E_DB"
		return &"E"
	if w:
		if wall.call(Vector2i(0, -1)) and wet.call(q + Vector2i(-1, -1)): return &"W_DT"
		if wall.call(Vector2i(0, 1)) and wet.call(q + Vector2i(-1, 1)): return &"W_DB"
		return &"W"
	if wet.call(q + Vector2i(1, 1)): return &"IN_SE"
	if wet.call(q + Vector2i(-1, 1)): return &"IN_SW"
	if wet.call(q + Vector2i(1, -1)): return &"IN_NE"
	if wet.call(q + Vector2i(-1, -1)): return &"IN_NW"
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
