class_name PlateauRenderer
extends RefCounted

const GenProgress = preload("res://modules/quiz_rpg/scripts/generation/core/gen_progress.gd")

## Renderuje płaskowyże istniejącym pipeline'em ścian w trybie płaskowyżu (fasady 2H, moduły IN).
## Region płaskowyżu P = maska M (podłoga) + krawędzie prawdziwych ścian patrzące na M (E_M):
## płaskowyż „rysuje maksymalnie do wykrytych krawędzi, przy voidzie przestaje". Syntetyczna
## bryła = P ∪ void; zostają tylko kafle w P i w stopach lica P — nic w voidzie.

const TILESET_ID := &"caves_platform"
const LAYER := &"Platforms"
const WINDOW_MARGIN := 6
# Poszerzenie bboxa kawałka P do prostokąta skanu (kafle zostają tylko w P i stopach lica, a analiza
# kratki sięga kilka kratek dalej — głębokość bryły max 6).
const SCAN_GROW := 10
const DIRS4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const DIAG4: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
const FOOT_SEARCH := 3  # fasada ściany: stopa najwyżej 3 kratki niżej


## Zwraca {"tiles": pos -> TilePlacement (warstwa Platforms), "region": P, "missing": liczba kafli,
## które pipeline wziąłby ze stałych ścian (brak roli w rodzinie platform — odrzucone)}.
## mask: komórki PODŁOGI płaskowyżu. wall_cells: warstwa Walls planu mapy (pos -> TilePlacement).
## focus (opcjonalnie): rysuj tylko okolicę tych kratek — dla „ziemi nad zagłębieniem” (maska = cała
## podłoga poza dołem), gdzie krawędzie są wyłącznie wokół dołów; okna skanu z kawałków focus.
static func render(real_ctx: GenerationContext, mask: Dictionary, wall_cells: Dictionary, focus: Dictionary = {}) -> Dictionary:
	var result := {"tiles": {}, "region": {}, "missing": 0}
	if mask.is_empty() or real_ctx.map_tile_profile == null:
		return result
	var platform_set = real_ctx.map_tile_profile.get_tileset(TILESET_ID)
	if platform_set == null:
		push_warning("PlateauRenderer: brak zestawu '%s' w profilu" % TILESET_ID)
		return result

	var focus_scans: Array[Rect2i] = []
	if not focus.is_empty():
		# Maska przycięta do okien skanu wokół dołów (+ margines): w oknie maska jest pełna, a jej
		# sztuczny brzeg leży poza oknem, gdzie syntetyczny grid i tak jest bryłą.
		focus_scans = _scan_windows(real_ctx, focus)
		var near := {}
		for r in focus_scans:
			var g := r.grow(WINDOW_MARGIN)
			for y in range(g.position.y, g.end.y):
				for x in range(g.position.x, g.end.x):
					var q := Vector2i(x, y)
					if mask.has(q):
						near[q] = true
		mask = near
	var region := build_region(real_ctx, mask, wall_cells)
	result.region = region
	# Okno całości (bbox P + margines) wyznacza syntetyczny grid; pipeline skanuje jednak tylko
	# rozłączne okna skupisk płaskowyżów (współrzędne globalne — hashe pozycji bez zmian).
	var box := _window(region)
	var scans := focus_scans if not focus.is_empty() else _scan_windows(real_ctx, region)
	var sgrid := _synthetic_grid(real_ctx, region, wall_cells, box, scans)
	var sctx := _synthetic_ctx(real_ctx, sgrid, platform_set)

	var plan := TilePlacementPlan.new()
	var state := LegacyPlacementState.new()
	for i in scans.size():
		GenProgress.sub(float(i) / scans.size())
		sctx.scan_rect = scans[i]
		var analysis = EdgeAnalyzer.analyze(sctx)
		FacadePhasePlanner.plan(sctx, analysis, state, plan)
		SideWallPlacer.plan(sctx, analysis.edges, state, plan)
		RimPlacer.plan(sctx, analysis.edges, state, plan)
		CornerPlacer.plan(sctx, analysis.edges, state, plan)

	# Wchłanianie przez ściany główne (kafle płaskowyżu pod krawędzią ściany nakładałyby się z nią):
	# void zawsze; lico płaskowyżu, gdy jego baza wypada na bazie lica ściany albo tuż pod nią
	# — cała kolumna; rim/bok/narożnik płaskowyżu pod górą modułu ściany. Nie pod narożnikiem
	# out ściany — jego przezroczysty koniec pokazuje, co jest za nim.
	var tiles: Dictionary = result.tiles
	var absorbed_feet := {}  # stopy wchłoniętych kolumn lica
	for layer_name in plan.by_layer:
		var cells: Dictionary = plan.by_layer[layer_name]
		for pos in cells:
			if not _keep(pos, region, sgrid):
				continue
			var p: TilePlacement = cells[pos]
			if _absorbed(real_ctx, wall_cells, region, pos, p):
				if p.category == &"FACADE":
					absorbed_feet[pos if not region.has(pos) else pos + Vector2i(0, 1)] = true
				continue
			if layer_name != LAYER:
				# Placer użył stałej ściany (rola nieobecna w rodzinie platform) — nie mieszamy sztuki.
				result.missing += 1
				continue
			tiles[pos] = p
	_end_facades_at_absorbed(sctx, tiles, region, absorbed_feet)
	return result


## Lico płaskowyżu urwane przy wchłoniętej kolumnie: kolumna obok dostaje zakończenie lica 2H (jak
## narożnik out pipeline'u: FACADE_2H WEST/EAST) zamiast środka lica. Stopa sąsiada: kratka poza P
## z P nad sobą, w wierszu stopy wchłoniętej kolumny ±1.
static func _end_facades_at_absorbed(sctx: GenerationContext, tiles: Dictionary, region: Dictionary, absorbed_feet: Dictionary) -> void:
	for f in absorbed_feet:
		for side in [-1, 1]:
			var n := Vector2i(-1, -1)
			for dy in [0, 1, -1]:
				var c: Vector2i = f + Vector2i(side, dy)
				var cur_c: TilePlacement = tiles.get(c)
				if not region.has(c) and region.has(c + Vector2i(0, -1)) and cur_c != null and cur_c.category == &"FACADE":
					n = c
					break
			if n.x < 0 or absorbed_feet.has(n):
				continue
			var cur: TilePlacement = tiles[n]
			# Wchłonięta kolumna po zachodniej stronie -> lico otwarte na zachód (WEST) i odwrotnie.
			var variant: StringName = &"WEST" if side == 1 else &"EAST"
			var parts := TileResolver.resolve_module_parts(sctx, n, TileModuleRole.Id.FACADE_2H, [], -1, variant)
			for rp in parts:
				var p := TilePlacement.new()
				p.pos = n + rp.offset
				p.layer = LAYER
				p.source_id = rp.tile.source_id
				p.atlas_coords = rp.tile.atlas_coords
				p.alternative_tile = rp.tile.alternative_tile
				p.category = &"FACADE"
				p.origin = n
				p.tie_breaker = cur.tie_breaker
				tiles[p.pos] = p


## Czy ściana główna wchłania kafel płaskowyżu `p` w kratce pos:
## - void (prawdziwa ściana bez kafla albo z litym wypełnieniem) — zawsze,
## - lico płaskowyżu (cała kolumna) — gdy jego baza wypada na bazie lica ściany (base-base: lico
##   płaskowyżu przegrywa) albo tuż pod nią (top kolumny na bazie ściany); kolumna: top = kratka w P,
##   dla stopy kratka nad nią. Pod ścianą boczną lico zostaje,
## - rim, bok, narożnik płaskowyżu — pod górą modułu ściany (jej rim albo najwyższa część lica);
##   pod bazą i środkiem lica ściany wchodzą głębiej,
## - nigdy pod narożnikiem out ściany (przezroczysty koniec).
static func _absorbed(real_ctx: GenerationContext, wall_cells: Dictionary, region: Dictionary, pos: Vector2i, p: TilePlacement) -> bool:
	var w: TilePlacement = wall_cells.get(pos)
	var no_tile: bool = w == null or w.atlas_coords.x < 0 or w.category == &"SOLID_FILL"
	if no_tile and not GridUtils.is_walkable(real_ctx.grid, pos):
		return true
	if p.category == &"FACADE":
		var t: Vector2i = pos if region.has(pos) else pos + Vector2i(0, -1)
		return _on_wall_base(real_ctx, wall_cells, t) or _on_wall_base(real_ctx, wall_cells, t + Vector2i(0, 1))
	if no_tile or w.out_corner:
		return false
	return _is_module_top(wall_cells, w)


## Baza lica ściany głównej (część lica na podłodze — stopa), nie narożnik out.
static func _on_wall_base(real_ctx: GenerationContext, wall_cells: Dictionary, c: Vector2i) -> bool:
	var w: TilePlacement = wall_cells.get(c)
	return GridUtils.is_walkable(real_ctx.grid, c) and w != null and w.category == &"FACADE" and not w.out_corner


## Najwyższa część modułu ściany: rim (moduł 1-kaflowy) albo część lica bez części tego samego
## modułu (origin) nad sobą.
static func _is_module_top(wall_cells: Dictionary, w: TilePlacement) -> bool:
	if String(w.category).begins_with("RIM"):
		return true
	if w.category != &"FACADE":
		return false
	var above: TilePlacement = wall_cells.get(w.pos + Vector2i(0, -1))
	return above == null or above.category != &"FACADE" or above.origin != w.origin


## Void = komórki ścian z kafelkiem SOLID_FILL (lite, nieprzezroczyste) albo bez kafla.
static func is_void(real_ctx: GenerationContext, wall_cells: Dictionary, pos: Vector2i) -> bool:
	if GridUtils.is_walkable(real_ctx.grid, pos):
		return false
	var p: TilePlacement = wall_cells.get(pos)
	return p == null or p.category == &"SOLID_FILL"


## P = M ∪ E_M. E_M = komórki krawędzi ścian (nie-void), które PATRZĄ na podłogę z M:
## sąsiad ortogonalny (bok, rim), a gdy go brak — diagonalny (narożnik), plus stopa fasady pod spodem.
static func build_region(real_ctx: GenerationContext, mask: Dictionary, wall_cells: Dictionary) -> Dictionary:
	# Kandydaci: sąsiedzi M (8 kierunków) oraz komórki nad M do FOOT_SEARCH (fasady ścian).
	var candidates := {}
	for m in mask:
		for d in DIRS4 + DIAG4:
			candidates[m + d] = true
		for k in range(2, FOOT_SEARCH + 1):
			candidates[m + Vector2i(0, -k)] = true
	var region := mask.duplicate()
	for w in candidates:
		if region.has(w) or GridUtils.is_walkable(real_ctx.grid, w) or is_void(real_ctx, wall_cells, w):
			continue
		if _faces_mask(real_ctx, w, mask):
			region[w] = true
	return region


static func _faces_mask(real_ctx: GenerationContext, w: Vector2i, mask: Dictionary) -> bool:
	var any_orth := false
	for d in DIRS4:
		var n: Vector2i = w + d
		if GridUtils.is_walkable(real_ctx.grid, n):
			any_orth = true
			if mask.has(n):
				return true
	if not any_orth:
		for d in DIAG4:
			if mask.has(w + d):
				return true
	# Fasada: stopa pod komórką ściany (przez komórki ściany, najwyżej FOOT_SEARCH w dół).
	var c := w
	for _i in range(FOOT_SEARCH):
		c += Vector2i(0, 1)
		if GridUtils.is_walkable(real_ctx.grid, c):
			return mask.has(c)
	return false


## Okno wokół P: bbox regionu + WINDOW_MARGIN. Poza oknem syntetyczny grid to bryła.
static func _window(region: Dictionary) -> Rect2i:
	var box := Rect2i()
	var first := true
	for c in region:
		if first:
			box = Rect2i(c, Vector2i.ONE)
			first = false
		else:
			box = box.expand(c)
	return box.grow(WINDOW_MARGIN)


## Rozłączne prostokąty skanu: bbox każdego kawałka P poszerzony o SCAN_GROW,
## nachodzące na siebie scalone (skupisko liczone razem, jak przy skanie całej mapy).
static func _scan_windows(real_ctx: GenerationContext, region: Dictionary) -> Array[Rect2i]:
	var map_rect := Rect2i(0, 0, real_ctx.width, real_ctx.height)
	var rects: Array[Rect2i] = []
	var seen := {}
	for start in region:
		if seen.has(start):
			continue
		var box := Rect2i(start, Vector2i.ONE)
		seen[start] = true
		var stack: Array[Vector2i] = [start]
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			box = box.expand(c)
			for d in DIRS4 + DIAG4:
				var n: Vector2i = c + d
				if region.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		rects.append(box.grow(SCAN_GROW).intersection(map_rect))
	var merged := true
	while merged:
		merged = false
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					rects[i] = rects[i].merge(rects[j])
					rects.remove_at(j)
					merged = true
					break
			if merged:
				break
	return rects


## Syntetyczny grid: bryła (WALL) = P ∪ void ∪ wszystko poza oknem wokół P; reszta = FLOOR.
## Zapisuje tylko prostokąty skanu — brak wpisu = niechodliwe, tak samo jak WALL (analiza pyta
## wyłącznie o chodliwość), więc każde okno widzi dokładnie ten grid co skan całej mapy.
static func _synthetic_grid(real_ctx: GenerationContext, region: Dictionary, wall_cells: Dictionary, box: Rect2i, scans: Array[Rect2i]) -> Dictionary:
	var sgrid := {}
	for win in scans:
		for y in range(win.position.y, win.end.y):
			for x in range(win.position.x, win.end.x):
				var c := Vector2i(x, y)
				var solid: bool = not box.has_point(c) or region.has(c) or is_void(real_ctx, wall_cells, c)
				sgrid[c] = CellType.WALL if solid else CellType.FLOOR
	return sgrid


static func _synthetic_ctx(real_ctx: GenerationContext, sgrid: Dictionary, platform_set) -> GenerationContext:
	var sctx := GenerationContext.new()
	sctx.grid = sgrid
	sctx.width = real_ctx.width
	sctx.height = real_ctx.height
	sctx.seed_value = real_ctx.seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([real_ctx.seed_value, "plateau_tiles"])
	sctx.rng = rng
	sctx.tile_rng = rng
	var f := GenerationFlags.new()
	f.enable_decorative_niches = false
	f.enable_pillars = false
	sctx.flags = f
	sctx.theme_override = 0  # rock — bez korzeni
	sctx.plateau_mode = true
	sctx.priority_table = real_ctx.priority_table if not real_ctx.priority_table.is_empty() \
		else PlacementPriority.get_table(&"legacy_facade_wins", {})
	# Profil tylko z rodziną platform: resolver nie ma dokąd spaść (brak fallbacku do ścian).
	var profile := MapTileProfile.new()
	profile.tilesets = [platform_set]
	profile.default_tileset_id = TILESET_ID
	sctx.map_tile_profile = profile
	sctx.tileset_field = TileSetField.new()
	return sctx


## Zostają kafle w P i w stopie lica P (komórka nie-bryły, nad którą jest P).
static func _keep(pos: Vector2i, region: Dictionary, sgrid: Dictionary) -> bool:
	if region.has(pos):
		return true
	return int(sgrid.get(pos, CellType.WALL)) == CellType.FLOOR and region.has(pos + Vector2i(0, -1))
