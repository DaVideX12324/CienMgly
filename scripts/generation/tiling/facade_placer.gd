class_name FacadePlacer
extends RefCounted


static func _get_variant_noise(ctx: GenerationContext) -> FastNoiseLite:
	if ctx.variant_noise != null:
		return ctx.variant_noise
	# Wariant A/B per kratka (decyzja usera 2026-10-03: inny wariant praktycznie co kratkę czy dwie): szum
	# wartości z częstotliwością 1 bez fraktala = niezależna losowa wartość w każdej kratce (siatka szumu
	# pokrywa się z siatką mapy), zamiast gładkich plam (dawniej simplex, frequency 0.45).
	var n := FastNoiseLite.new()
	n.seed = ctx.seed_value + 777
	n.noise_type = FastNoiseLite.TYPE_VALUE
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.frequency = 1.0
	ctx.variant_noise = n
	return n


static func _queue(
	plan: TilePlacementPlan,
	target_pos: Vector2i,
	atlas_coords: Vector2i,
	category: StringName,
	table: Dictionary,
	origin: Vector2i = Vector2i.ZERO,
	out_corner: bool = false
) -> void:
	var p := TilePlacement.new()
	p.pos = target_pos
	p.layer = &"Walls"
	p.atlas_coords = atlas_coords
	p.category = category
	p.origin = origin
	p.out_corner = out_corner
	p.tie_breaker = 10 if (origin == Vector2i.ZERO or target_pos.x == origin.x) else 1
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Kolejkuje część modułu (z resolvera) zachowując konwencję tie_breaker jak _queue.
static func _queue_part(
	plan: TilePlacementPlan,
	target_pos: Vector2i,
	rp,
	category: StringName,
	table: Dictionary,
	origin: Vector2i = Vector2i.ZERO,
	out_corner: bool = false
) -> void:
	var p := TilePlacement.new()
	p.pos = target_pos
	p.layer = rp.layer if rp.layer != &"" else &"Walls"
	p.source_id = rp.tile.source_id
	p.atlas_coords = rp.tile.atlas_coords
	p.alternative_tile = rp.tile.alternative_tile
	p.category = category
	p.origin = origin
	p.out_corner = out_corner
	p.tie_breaker = 10 if (origin == Vector2i.ZERO or target_pos.x == origin.x) else 1
	PlacementPriority.assign(p, table)
	plan.queue(p)


## Próbuje ścieżki modułowej (wymuszony wariant). Zwraca true, jeśli coś położono.
static func _try_module(
	ctx: GenerationContext,
	plan: TilePlacementPlan,
	anchor: Vector2i,
	module_role: TileModuleRole.Id,
	variant_id: StringName,
	table: Dictionary,
	force_id: StringName = &"",
	out_corner: bool = false
) -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, anchor, module_role, [], -1, variant_id, force_id)
	if parts.is_empty():
		return false
	for rp in parts:
		_queue_part(plan, anchor + rp.offset, rp, &"FACADE", table, Vector2i.ZERO, out_corner)
	return true


## Stawia prostą fasadę o wysokości 2 kratek (2H). Zawsze motyw rock.
static func place_2h(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan
) -> void:
	var pos := edge.pos
	var grid := ctx.grid
	var table := ctx.priority_table

	var is_west_end: bool = GridUtils.is_walkable(grid, pos + Vector2i(-1, -1)) or GridUtils.is_walkable(grid, pos + Vector2i(-1, -2))
	var is_east_end: bool = GridUtils.is_walkable(grid, pos + Vector2i(1, -1)) or GridUtils.is_walkable(grid, pos + Vector2i(1, -2))

	# Wariant wyznaczany geometrią (końce WEST/EAST) lub A/B z variant_noise — identycznie
	# jak legacy. Ścieżka modułowa dostaje wymuszony wariant; bez profilu -> stałe.
	var variant_id: StringName
	var top_2h := Vector2i.ZERO
	var base_2h := Vector2i.ZERO

	if is_west_end and not is_east_end:
		variant_id = &"WEST"
		top_2h = CaveTileConstants.WALL_2H_WEST_TOP
		base_2h = CaveTileConstants.WALL_2H_WEST_BASE
	elif is_east_end and not is_west_end:
		variant_id = &"EAST"
		top_2h = CaveTileConstants.WALL_2H_EAST_TOP
		base_2h = CaveTileConstants.WALL_2H_EAST_BASE
	else:
		var v_noise := _get_variant_noise(ctx)
		var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
		variant_id = &"B" if is_b else &"A"
		top_2h = CaveTileConstants.WALL_2H_TOP[1] if is_b else CaveTileConstants.WALL_2H_TOP[0]
		base_2h = CaveTileConstants.WALL_2H_BASE[1] if is_b else CaveTileConstants.WALL_2H_BASE[0]

	# Anchor = stopa (pos): część base @ (0,0), top @ (0,-1). Końce WEST/EAST = narożnik out
	# (przezroczysty koniec lica — PlateauRenderer nie wchłania pod nim płaskowyżu).
	var is_end: bool = variant_id == &"WEST" or variant_id == &"EAST"
	if not _try_module(ctx, plan, pos, TileModuleRole.Id.FACADE_2H, variant_id, table, &"", is_end):
		_queue(plan, pos, base_2h, &"FACADE", table, Vector2i.ZERO, is_end)
		_queue(plan, pos + Vector2i(0, -1), top_2h, &"FACADE", table, Vector2i.ZERO, is_end)
	state.mark(pos, &"FACADE")
	state.mark(pos + Vector2i(0, -1), &"FACADE")


## Flaga facade_base_on_wall: lico na kratkach ściany (przesunięte o rząd w górę) — 1, inaczej 0.
static func facade_row_offset(ctx: GenerationContext) -> int:
	return 1 if facade_on_wall(ctx) else 0


static func facade_on_wall(ctx: GenerationContext) -> bool:
	return ctx != null and ctx.flags != null and ctx.flags.facade_base_on_wall


## Cień zagłębienia na kolumnie lica w stopie `pos`: sąsiedni mur wystaje dalej do przodu (w rzędzie
## podłogi pod licem stoi ściana, nie kanał) albo w sąsiedniej kolumnie stoi filar -> &"SHADE_L" / &"SHADE_R" /
## &"SHADE_LR"; w kolumnie filara (lico za filarem) zawsze &"SHADE_LR"; inaczej &"".
## Filar liczy się tylko w rzędach, do których sięga: `part_dy` = rząd części względem stopy (domyślnie 0 = stopa,
## każdy filar); zniszczony, niski filar nie cieniuje szczytu lica.
## Wariant z cieniem bierze się z profilu, gdy go ma (lico, narożniki: &"SHADE"); bez niego — zwykły.
static func recess_shade(ctx: GenerationContext, pos: Vector2i, part_dy: int = 0) -> StringName:
	# rząd podłogi pod licem: przy licu na murze kotwica modułu to już kratka podłogi (części -1..-n), w jaskiniach
	# kotwica = stopa lica, podłoga rząd niżej
	var row := pos.y + (0 if facade_on_wall(ctx) else 1)
	var water: Dictionary = ctx.canals.water if ctx.canals != null else {}
	# lico bezpośrednio za filarem ma cień z obu stron (stopy filarów: ctx.pillar_feet)
	if _pillar_reaches(ctx, pos, part_dy):
		return &"SHADE_LR"
	# filar w sąsiedniej kolumnie też rzuca cień na lico obok
	var l := _protrudes(ctx, Vector2i(pos.x - 1, row), water) or _pillar_reaches(ctx, pos + Vector2i(-1, 0), part_dy)
	var r := _protrudes(ctx, Vector2i(pos.x + 1, row), water) or _pillar_reaches(ctx, pos + Vector2i(1, 0), part_dy)
	if l and r:
		return &"SHADE_LR"
	if l:
		return &"SHADE_L"
	if r:
		return &"SHADE_R"
	return &""


static func _pillar_reaches(ctx: GenerationContext, foot: Vector2i, part_dy: int) -> bool:
	return ctx.pillar_feet.has(foot) and int(ctx.pillar_feet[foot]) <= part_dy


## Lico (moduł `module_role`, wariant `variant_id`) z cieniem wybieranym osobno dla każdej części: część bierze
## kafel z tym samym przesunięciem z wariantu cienia danego rzędu (recess_shade), gdy profil go ma.
## Z `tiling.facade_top_independent` (companion-JSON) najwyższa część (top lica) bez cienia bierze kafel z wariantu
## A albo B losowanego osobno (hash pozycji) — szew grzbietu nie powtarza kolumn lica.
static func _try_shaded_module(
	ctx: GenerationContext,
	plan: TilePlacementPlan,
	anchor: Vector2i,
	module_role: TileModuleRole.Id,
	variant_id: StringName,
	table: Dictionary,
	force_id: StringName = &""
) -> bool:
	var parts := TileResolver.resolve_module_parts(ctx, anchor, module_role, [], -1, variant_id, force_id)
	if parts.is_empty():
		return false
	var shaded := {}  # wariant cienia -> {przesunięcie: część}
	var top_part = null  # część topu z wariantu wylosowanego osobno (null = jak lico)
	if (variant_id == &"A" or variant_id == &"B") and bool(ctx.generator_behaviour.get("tiling", {}).get("facade_top_independent", false)):
		var top_vid: StringName = &"B" if hash([ctx.seed_value, anchor, "facade_top"]) % 2 == 1 else &"A"
		if top_vid != variant_id:
			var top_y := 0
			for rp in parts:
				top_y = mini(top_y, rp.offset.y)
			for tp in TileResolver.resolve_module_parts(ctx, anchor, module_role, [], -1, top_vid, force_id):
				if tp.offset.y == top_y:
					top_part = tp
	for rp in parts:
		var use = rp
		var shade := recess_shade(ctx, anchor, rp.offset.y)
		if shade != &"" and has_variant(ctx, module_role, shade):
			if not shaded.has(shade):
				var by_off := {}
				for sp in TileResolver.resolve_module_parts(ctx, anchor, module_role, [], -1, shade, force_id):
					by_off[sp.offset] = sp
				shaded[shade] = by_off
			use = shaded[shade].get(rp.offset, rp)
		elif top_part != null and rp.offset == top_part.offset:
			use = top_part
		_queue_part(plan, anchor + use.offset, use, &"FACADE", table, Vector2i.ZERO, false)
	return true


## Czy domyślny zestaw profilu ma wariant `vid` roli `module_role` — wymuszony brakujący wariant dałby
## legacy kafel wpisu (resolver), a nie pusty wynik.
static func has_variant(ctx: GenerationContext, module_role: int, vid: StringName) -> bool:
	if ctx.map_tile_profile == null:
		return false
	var ts := ctx.map_tile_profile.get_default_tileset()
	var e: TileRoleEntry = ts.get_entry(TileModuleRole.to_storage_role(module_role)) if ts else null
	if e == null:
		return false
	for v in e.variants:
		if v != null and v.variant_id == vid:
			return true
	return false


static func _protrudes(ctx: GenerationContext, c: Vector2i, water: Dictionary) -> bool:
	return ctx.grid.has(c) and not water.has(c) and not GridUtils.is_walkable(ctx.grid, c)


## Lico 4H w stopie `pos` (flaga enable_4h_facades): stopa należy do odcinka wybranego na 4H.
static func wants_4h(ctx: GenerationContext, pos: Vector2i, _state: LegacyPlacementState = null, _edges: Dictionary = {}) -> bool:
	if ctx.flags == null or not ctx.flags.enable_4h_facades:
		return false
	if not ctx.facade_4h_planned:
		_plan_4h_segments(ctx)
	return ctx.facade_4h_bases.has(pos)


## Odcinki lica = ciągi sąsiednich kolumn ze stopą (podłoga, nad nią ściana) w tym samym rzędzie. Odcinek
## nadaje się na 4H, gdy w każdej kolumnie ściana ma > 3 kratki (rzędy -1..-4 bez podłogi), a górna kratka
## lica (rząd -3) nie ma podłogi obok; wybór stabilny z seeda (facade_4h_chance), cały odcinek naraz.
static func _plan_4h_segments(ctx: GenerationContext) -> void:
	ctx.facade_4h_planned = true
	var grid := ctx.grid
	for y in range(4, ctx.height):
		var x := 0
		while x < ctx.width:
			if not _is_facade_base(grid, Vector2i(x, y)):
				x += 1
				continue
			var x0 := x
			var ok := true
			var off := facade_row_offset(ctx)
			while x < ctx.width and _is_facade_base(grid, Vector2i(x, y)):
				var top := Vector2i(x, y - 3 - off)
				for dy in range(1, 5 + off):
					if GridUtils.is_walkable(grid, Vector2i(x, y - dy)):
						ok = false
				if GridUtils.is_walkable(grid, top + Vector2i(-1, 0)) or GridUtils.is_walkable(grid, top + Vector2i(1, 0)):
					ok = false
				x += 1
			# eksperyment dry_end_4h: odcinek nad zamurowanym końcem pustego koryta zawsze 4H
			var forced: bool = ctx.canals != null and "force_4h_bases" in ctx.canals and ctx.canals.force_4h_bases.has(Vector2i(x0, y))
			if not ok and not forced:
				continue
			var roll := float(hash([ctx.seed_value, y, x0, "facade_4h"]) & 0xFFFF) / 65536.0
			if forced or roll < ctx.flags.facade_4h_chance:
				for cx in range(x0, x):
					ctx.facade_4h_bases[Vector2i(cx, y)] = true


static func _is_facade_base(grid: Dictionary, p: Vector2i) -> bool:
	return GridUtils.is_walkable(grid, p) and not GridUtils.is_walkable(grid, p + Vector2i(0, -1))


## Oznacza 4 kratki modułu 4H (stopa `pos`) i zapamiętuje górną dla narożnika wewnętrznego.
static func mark_4h(ctx: GenerationContext, pos: Vector2i, state: LegacyPlacementState) -> void:
	for dy in range(0, 4):
		state.mark(pos + Vector2i(0, -dy), &"FACADE")
	ctx.facade_4h_tops[pos + Vector2i(0, -3)] = true


## Czy nad licem 3H w stopie `pos` jest miejsce na koronę (rząd -3): ściana głębsza niż 3 (nad koroną
## nie ma podłogi), kratka wolna od innych krawędzi i jeszcze nie zajęta.
static func _crown_allowed(ctx: GenerationContext, pos: Vector2i, state: LegacyPlacementState, edges: Dictionary) -> bool:
	var grid := ctx.grid
	var p_crown := pos + Vector2i(0, -3)
	var has_floor_above := GridUtils.is_walkable(grid, p_crown + Vector2i(0, -1))
	var edge_crown: EdgeContext = edges.get(p_crown) if not edges.is_empty() else null
	var crown_free: bool = edge_crown == null or edge_crown.edge_kind == EdgeKind.Kind.SOLID_FILL or edge_crown.edge_kind == EdgeKind.Kind.NONE
	return not has_floor_above and not GridUtils.is_walkable(grid, p_crown) and crown_free and state.is_empty_or_rock(p_crown)


## Stawia standardową prostą fasadę o wysokości 3 kratek (3H) z koroną.
## Korona lica 3H (kafel nad górą lica, rząd -3) — tylko gdy ściana jest głębsza niż 3 (nad koroną skała).
## Przy głębokości 3 rząd -3 to szczyt ściany — kładzie go RimPlacer.
static func place_3h_crown(
	ctx: GenerationContext,
	pos: Vector2i,
	state: LegacyPlacementState,
	plan: TilePlacementPlan,
	use_roots: bool,
	edges: Dictionary = {}
) -> void:
	var is_b: bool = _get_variant_noise(ctx).get_noise_2d(float(pos.x), float(pos.y)) > 0.0
	var p_crown := pos + Vector2i(0, -3)
	if _crown_allowed(ctx, pos, state, edges):
		var parts := TileResolver.resolve_module_parts(ctx, p_crown, TileModuleRole.Id.FACADE_CROWN_3H, [], -1,
			&"B" if is_b else &"A", &"caves_roots" if use_roots else &"")
		if not parts.is_empty():
			for rp in parts:
				_queue_part(plan, p_crown + rp.offset, rp, &"CORNER", ctx.priority_table, pos)
		else:
			var crown_t := Vector2i(3, 4) if is_b else Vector2i(2, 4)
			if use_roots:
				crown_t = Vector2i(3, 13) if is_b else Vector2i(2, 13)
			_queue(plan, p_crown, crown_t, &"CORNER", ctx.priority_table, pos)
		state.mark(p_crown, &"CORNER")


static func place_3h(
	ctx: GenerationContext,
	edge: EdgeContext,
	state: LegacyPlacementState,
	plan: TilePlacementPlan,
	use_roots: bool,
	_left_y: int = -1,
	_right_y: int = -1,
	edges: Dictionary = {}
) -> void:
	var pos := edge.pos
	var table := ctx.priority_table
	var v_noise := _get_variant_noise(ctx)

	var is_b: bool = v_noise.get_noise_2d(float(pos.x), float(pos.y)) > 0.0
	var top_t := CaveTileConstants.WALL_BOTTOM_TOP[1] if is_b else CaveTileConstants.WALL_BOTTOM_TOP[0]
	var mid_t := CaveTileConstants.WALL_BOTTOM_MID[1] if is_b else CaveTileConstants.WALL_BOTTOM_MID[0]
	var base_t := CaveTileConstants.WALL_BOTTOM_BASE[1] if is_b else CaveTileConstants.WALL_BOTTOM_BASE[0]
	if use_roots:
		top_t = CaveTileConstants.ROOT_BOTTOM_TOP[1] if is_b else CaveTileConstants.ROOT_BOTTOM_TOP[0]
		mid_t = CaveTileConstants.ROOT_BOTTOM_MID[1] if is_b else CaveTileConstants.ROOT_BOTTOM_MID[0]
		base_t = CaveTileConstants.ROOT_BOTTOM_BASE[1] if is_b else CaveTileConstants.ROOT_BOTTOM_BASE[0]

	# Lico 4H (enable_4h_facades + rola FACADE_4H w profilu): tam, gdzie 3H dostałoby koronę.
	var variant_id4: StringName = &"B" if is_b else &"A"
	var force4: StringName = &"caves_roots" if use_roots else &""
	if wants_4h(ctx, pos, state, edges) and _try_shaded_module(ctx, plan, pos, TileModuleRole.Id.FACADE_4H, variant_id4, table, force4):
		mark_4h(ctx, pos, state)
		return

	if not facade_on_wall(ctx):
		place_3h_crown(ctx, pos, state, plan, use_roots, edges)

	# A′: motyw roots = wybór RODZINY (force caves_roots), wariant A/B niezależnie.
	# Anchor = stopa; base @ (0,0), mid @ (0,-1), top @ (0,-2). Korona = osobny CORNER.
	var variant_id: StringName = &"B" if is_b else &"A"
	var force_id: StringName = &"caves_roots" if use_roots else &""
	if not _try_shaded_module(ctx, plan, pos, TileModuleRole.Id.FACADE_3H, variant_id, table, force_id):
		_queue(plan, pos + Vector2i(0, -2), top_t, &"FACADE", table)
		_queue(plan, pos + Vector2i(0, -1), mid_t, &"FACADE", table)
		_queue(plan, pos, base_t, &"FACADE", table)

	state.mark(pos + Vector2i(0, -2), &"FACADE")
	state.mark(pos + Vector2i(0, -1), &"FACADE")
	state.mark(pos, &"FACADE")
