class_name TileResolver
extends RefCounted

## Jedyne miejsce decydujące, z którego zestawu i z jakiej reguły pochodzi kafelek.
## NIE zmienia topologii ani klasyfikacji krawędzi — dostaje gotową rolę z placera.
##
## Zwraca null, gdy dynamiczny system nie jest aktywny (brak profilu / pola / definicji)
## — wtedy placer używa swojego dotychczasowego fallbacku na stałych CaveTileConstants.

const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const TileRef = preload("res://modules/quiz_rpg/scripts/generation/core/tile_ref.gd")
const TileRole = preload("res://modules/quiz_rpg/scripts/generation/core/tile_role.gd")
const MapTileProfile = preload("res://modules/quiz_rpg/scripts/generation/tiles/map_tile_profile.gd")
const NamedTileSetDefinition = preload("res://modules/quiz_rpg/scripts/generation/tiles/named_tileset_definition.gd")
const TileSetPairRule = preload("res://modules/quiz_rpg/scripts/generation/tiles/tileset_pair_rule.gd")
const TileRoleEntry = preload("res://modules/quiz_rpg/scripts/generation/core/tile_role_entry.gd")
const TileVariant = preload("res://modules/quiz_rpg/scripts/generation/core/tile_variant.gd")
const TileModuleRole = preload("res://modules/quiz_rpg/scripts/generation/tiles/tile_module_role.gd")
const VariantSelector = preload("res://modules/quiz_rpg/scripts/generation/tiles/variant_selector.gd")
const ResolvedTileModulePart = preload("res://modules/quiz_rpg/scripts/generation/tiles/resolved_tile_module_part.gd")
const MixedPool = preload("res://modules/quiz_rpg/scripts/generation/tiles/mixed_pool.gd")


## MIXED: deterministycznie wybiera JEDEN kompatybilny source z puli dla danego anchor.
## Pusta pula -> degradacja do default. Jeden set na cały moduł (spójność).
static func _pick_mixed_source(profile: MapTileProfile, pool: MixedPool, anchor: Vector2i, world_seed: int) -> StringName:
	var valid: Array = []
	for sid in pool.sources:
		if profile.get_tileset(sid) != null:
			valid.append(sid)
	if valid.is_empty():
		return profile.default_tileset_id
	var idx := VariantSelector.hash_index([world_seed, anchor.x, anchor.y, int(String(pool.id).hash())], valid.size())
	return valid[idx]


## Czy dynamiczny resolver jest aktywny dla tego kontekstu.
static func is_active(ctx: GenerationContext) -> bool:
	return ctx != null and ctx.map_tile_profile != null and ctx.tileset_field != null


static func resolve(
	ctx: GenerationContext,
	pos: Vector2i,
	role: TileRole.Id,
	neighbor_positions: Array[Vector2i] = []
) -> TileRef:
	if not is_active(ctx):
		return null

	var profile: MapTileProfile = ctx.map_tile_profile
	var default_id: StringName = profile.default_tileset_id

	var own_id: StringName = ctx.tileset_field.get_tileset_id(pos, default_id)
	var own_set: NamedTileSetDefinition = profile.get_tileset(own_id)

	if own_set == null:
		push_warning("TileResolver: nieznany TileSet ID '%s' @ %s" % [own_id, pos])
		own_set = profile.get_tileset(default_id)

	if own_set == null:
		push_error("TileResolver: brak prawidłowego domyślnego TileSet ID '%s'" % default_id)
		return null

	var neighbor_id: StringName = _find_relevant_neighbor_id(ctx, pos, neighbor_positions, own_id)

	if neighbor_id == StringName() or neighbor_id == own_id:
		return _tile_or_fallback(profile, own_set, role)

	var rule: TileSetPairRule = profile.get_pair_rule(own_id, neighbor_id)
	if rule == null:
		push_warning("TileResolver: brak reguły pary '%s' <-> '%s', rola %s @ %s"
			% [own_id, neighbor_id, TileRole.name_of(role), pos])
		return _tile_or_fallback(profile, own_set, role)

	match rule.mode:
		TileSetPairRule.Mode.ALLOWED:
			return _tile_or_fallback(profile, own_set, role)
		TileSetPairRule.Mode.TRANSITION:
			var transition: TileRef = rule.get_transition_tile(role)
			if transition != null and transition.is_valid():
				return transition
			return _apply_fallback_mode(profile, rule.fallback_mode, own_set, neighbor_id, role)
		TileSetPairRule.Mode.USE_FIRST:
			return _tile_or_fallback(profile, own_set, role)
		TileSetPairRule.Mode.USE_SECOND:
			var neighbor_set: NamedTileSetDefinition = profile.get_tileset(neighbor_id)
			if neighbor_set != null:
				return _tile_or_fallback(profile, neighbor_set, role)
			return _tile_or_fallback(profile, own_set, role)
		TileSetPairRule.Mode.FORBIDDEN:
			return _apply_forbidden_policy(ctx, profile, own_set, neighbor_id, role)
		TileSetPairRule.Mode.OVERLAY:
			# OVERLAY wymaga osobnej warstwy placementów (Etap 4+). Na razie własny zestaw.
			return _tile_or_fallback(profile, own_set, role)

	return _tile_or_fallback(profile, own_set, role)


# =====================================================================
# FAZA 2 — API modułowe (warianty + części z offsetami)
# =====================================================================

## Zwraca części wybranego modułu dla roli modułowej w danej kotwicy.
## Pusta tablica => moduł nierozwiązany (placer używa swojego legacy fallbacku).
## NIE buduje TilePlacement — to robi placer (zachowuje category/priority/tie_breaker).
## variant_roll >= 0: deterministyczny całkowity roll (np. legacy hash pozycji) do
## wyboru wariantu 1:1 z legacy (solid_fill). -1: domyślnie stabilny hash kotwicy.
## forced_variant_id != "": placer wymusza KONKRETNY wariant (geometria: WEST/EAST,
## motyw roots, A/B z variant_noise) — resolver zwraca części tego wariantu. To zachowuje
## legacy wybór wariantu sterowany geometrią; hash/roll dotyczy tylko wariantów równoważnych.
## force_tileset_id != "": placer wymusza KONKRETNY named set (np. caves_roots gdy
## use_roots), zamiast brać go z TileSetField. Poza tym normalna ścieżka (wariant, części).
static func resolve_module_parts(
	ctx: GenerationContext,
	anchor_pos: Vector2i,
	module_role: TileModuleRole.Id,
	neighbor_positions: Array[Vector2i] = [],
	variant_roll: int = -1,
	forced_variant_id: StringName = &"",
	force_tileset_id: StringName = &""
) -> Array:
	if not is_active(ctx):
		return []

	var profile: MapTileProfile = ctx.map_tile_profile
	var default_id: StringName = profile.default_tileset_id
	var storage_role: int = TileModuleRole.to_storage_role(module_role)

	# MIXED z pola ma priorytet nad force_tileset_id (region MIXED nadpisuje motyw placera).
	var field_id: StringName = ctx.tileset_field.get_tileset_id(anchor_pos, default_id)
	var was_mixed := false
	var own_id: StringName
	var mixed_pool: MixedPool = profile.get_mixed_pool(field_id)
	if mixed_pool != null:
		own_id = _pick_mixed_source(profile, mixed_pool, anchor_pos, ctx.seed_value)
		was_mixed = true
	else:
		own_id = force_tileset_id if force_tileset_id != &"" else field_id
	var own_set: NamedTileSetDefinition = profile.get_tileset(own_id)
	if own_set == null:
		push_warning("TileResolver.module: nieznany TileSet ID '%s' @ %s" % [own_id, anchor_pos])
		own_set = profile.get_tileset(default_id)
		own_id = default_id
	if own_set == null:
		return []

	var neighbor_id: StringName = _find_relevant_neighbor_id(ctx, anchor_pos, neighbor_positions, own_id)

	# 1) Styk zestawów — reguła pary (transition / forbidden / use_*).
	# Pomijamy przy wymuszonym secie (placer wybrał rodzinę) i przy MIXED (źródła są ALLOWED).
	if force_tileset_id == &"" and not was_mixed and neighbor_id != StringName() and neighbor_id != own_id:
		var rule: TileSetPairRule = profile.get_pair_rule(own_id, neighbor_id)
		if rule != null:
			match rule.mode:
				TileSetPairRule.Mode.TRANSITION:
					var tparts := _transition_parts(rule, storage_role, anchor_pos, ctx.seed_value, own_id, module_role)
					if not tparts.is_empty():
						return tparts
					# brak przejścia dla roli -> fallback_mode
					if rule.fallback_mode == TileSetPairRule.Mode.USE_SECOND:
						own_set = profile.get_tileset(neighbor_id)
						own_id = neighbor_id
				TileSetPairRule.Mode.USE_SECOND:
					own_set = profile.get_tileset(neighbor_id)
					own_id = neighbor_id
				TileSetPairRule.Mode.FORBIDDEN:
					var fset := _forbidden_set(ctx, profile, own_set, neighbor_id)
					if fset != null:
						own_set = fset
						own_id = fset.id
				_:
					pass

	# 2) Własny zestaw: wariant -> legacy tile.
	var parts := _entry_parts(own_set.get_entry(storage_role), anchor_pos, ctx.seed_value, own_id, module_role, variant_roll, forced_variant_id)
	if not parts.is_empty():
		return parts

	# 3) Zestaw domyślny.
	var default_set: NamedTileSetDefinition = profile.get_default_tileset()
	if default_set != null and default_set != own_set:
		parts = _entry_parts(default_set.get_entry(storage_role), anchor_pos, ctx.seed_value, default_set.id, module_role, variant_roll, forced_variant_id)
		if not parts.is_empty():
			return parts

	# 4) Geometryczny fallback zostawiamy placerowi (pusta tablica -> legacy stała).
	return []


## Buduje części z wpisu: wybrany wariant (ważony hash) LUB legacy tile jako 1 część (0,0).
static func _entry_parts(
	entry: TileRoleEntry,
	anchor_pos: Vector2i,
	world_seed: int,
	tileset_id: StringName,
	module_role: int,
	variant_roll: int = -1,
	forced_variant_id: StringName = &""
) -> Array:
	if entry == null:
		return []

	if entry.has_variants():
		var variant: TileVariant
		if forced_variant_id != &"":
			variant = _find_variant(entry.variants, forced_variant_id)
		elif variant_roll >= 0:
			variant = VariantSelector.choose_variant_by_int_roll(entry.variants, variant_roll)
		else:
			variant = VariantSelector.choose_variant_for_anchor(
				entry.variants, anchor_pos, world_seed, tileset_id, module_role
			)
		if variant != null:
			var out: Array = []
			for p in variant.valid_parts():
				var rp := ResolvedTileModulePart.new()
				rp.offset = p.offset
				rp.tile = p.tile
				rp.layer = p.layer
				rp.variant_id = variant.variant_id
				rp.source_tileset_id = tileset_id
				out.append(rp)
			if not out.is_empty():
				return out

	# Legacy: pojedynczy kafelek w (0,0). Warstwa nieokreślona (&"") -> placer użyje własnej.
	if entry.tile != null and (entry.tile.is_valid() or entry.tile.is_erase()):
		var rp := ResolvedTileModulePart.new()
		rp.offset = Vector2i.ZERO
		rp.tile = entry.tile
		rp.layer = &""
		rp.variant_id = &"legacy"
		rp.source_tileset_id = tileset_id
		return [rp]

	return []


static func _find_variant(variants: Array, variant_id: StringName) -> TileVariant:
	for v in variants:
		if v != null and (v as TileVariant).variant_id == variant_id and (v as TileVariant).is_active():
			return v
	return null


static func _transition_parts(
	rule: TileSetPairRule,
	storage_role: int,
	anchor_pos: Vector2i,
	world_seed: int,
	tileset_id: StringName,
	module_role: int
) -> Array:
	# Przejście jako pojedynczy kafelek (legacy transition_entries). Moduły wielokaflowe
	# w przejściach: gdy pojawi się potrzeba, transition_entries można rozszerzyć o warianty.
	var t: TileRef = rule.get_transition_tile(storage_role)
	if t != null and t.is_valid():
		var rp := ResolvedTileModulePart.new()
		rp.offset = Vector2i.ZERO
		rp.tile = t
		rp.layer = &"Walls"
		rp.variant_id = &"transition"
		rp.source_tileset_id = tileset_id
		return [rp]
	return []


static func _forbidden_set(
	ctx: GenerationContext,
	profile: MapTileProfile,
	own_set: NamedTileSetDefinition,
	neighbor_id: StringName
) -> NamedTileSetDefinition:
	var policy: String = "use_default"
	if ctx.generator_behaviour.has("tilesets"):
		policy = String(ctx.generator_behaviour["tilesets"].get("forbidden_contact_policy", "use_default"))
	match policy:
		"use_second":
			return profile.get_tileset(neighbor_id)
		"use_first":
			return own_set
		_:
			return profile.get_default_tileset()


# --- pomocnicze ---

## Kafelek zestawu dla roli; przy braku -> kafelek zestawu domyślnego; przy braku -> null.
static func _tile_or_fallback(
	profile: MapTileProfile,
	tileset: NamedTileSetDefinition,
	role: TileRole.Id
) -> TileRef:
	if tileset != null:
		var t: TileRef = tileset.get_tile(role)
		if t != null and t.is_valid():
			return t
	var default_set: NamedTileSetDefinition = profile.get_default_tileset()
	if default_set != null and default_set != tileset:
		var dt: TileRef = default_set.get_tile(role)
		if dt != null and dt.is_valid():
			return dt
	return null


static func _apply_fallback_mode(
	profile: MapTileProfile,
	fallback_mode: TileSetPairRule.Mode,
	own_set: NamedTileSetDefinition,
	neighbor_id: StringName,
	role: TileRole.Id
) -> TileRef:
	match fallback_mode:
		TileSetPairRule.Mode.USE_SECOND:
			var neighbor_set: NamedTileSetDefinition = profile.get_tileset(neighbor_id)
			if neighbor_set != null:
				return _tile_or_fallback(profile, neighbor_set, role)
		_:
			pass
	return _tile_or_fallback(profile, own_set, role)


static func _apply_forbidden_policy(
	ctx: GenerationContext,
	profile: MapTileProfile,
	own_set: NamedTileSetDefinition,
	neighbor_id: StringName,
	role: TileRole.Id
) -> TileRef:
	var policy: String = "use_default"
	if ctx.generator_behaviour.has("tilesets"):
		policy = String(ctx.generator_behaviour["tilesets"].get("forbidden_contact_policy", "use_default"))
	match policy:
		"use_second":
			var neighbor_set: NamedTileSetDefinition = profile.get_tileset(neighbor_id)
			if neighbor_set != null:
				return _tile_or_fallback(profile, neighbor_set, role)
			return _tile_or_fallback(profile, own_set, role)
		"use_first":
			return _tile_or_fallback(profile, own_set, role)
		_: # use_default, insert_buffer (obsługa przy budowie pola), warn_only
			var default_set: NamedTileSetDefinition = profile.get_default_tileset()
			if default_set != null:
				return _tile_or_fallback(profile, default_set, role)
			return _tile_or_fallback(profile, own_set, role)


## Znajdź istotne ID sąsiada różne od własnego (pierwsze inne). Pusty -> brak granicy.
static func _find_relevant_neighbor_id(
	ctx: GenerationContext,
	pos: Vector2i,
	neighbor_positions: Array[Vector2i],
	own_id: StringName
) -> StringName:
	var default_id: StringName = ctx.map_tile_profile.default_tileset_id
	for npos in neighbor_positions:
		var nid: StringName = ctx.tileset_field.get_tileset_id(npos, default_id)
		if nid != own_id:
			return nid
	return StringName()
