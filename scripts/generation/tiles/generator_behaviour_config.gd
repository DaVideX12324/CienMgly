class_name GeneratorBehaviourConfig
extends RefCounted

## Zachowanie generatora dla konkretnej mapy, wczytane z pliku JSON o tej samej
## nazwie bazowej co główny .tres mapy (caves.tres -> caves.json).
##
## JSON NIE trzyma współrzędnych atlasu — te są w custom .tres (NamedTileSetDefinition).
## JSON wskazuje profil (.tres), aktywne zestawy, reguły zachowania i parametry generatora.

const MapTileProfile = preload("res://modules/quiz_rpg/scripts/generation/tiles/map_tile_profile.gd")
const TileRole = preload("res://modules/quiz_rpg/scripts/generation/core/tile_role.gd")
const TileSetPairRule = preload("res://modules/quiz_rpg/scripts/generation/tiles/tileset_pair_rule.gd")
const GenerationFlags = preload("res://modules/quiz_rpg/scripts/generation/core/generation_flags.gd")

# Rozpoznawane klucze bloku "generation" (parametry topologii). seed/width/height
# = 0 oznacza "auto" (bierz z UI/@export albo wbudowany default).
const GEN_KEYS := ["min_room_size", "max_room_size", "max_rooms", "corridor_width", "seed", "width", "height"]
# Rozpoznawane klucze bloku "flags" (1:1 z właściwościami GenerationFlags).
const FLAG_BOOL_KEYS := ["enable_meandering", "enable_variable_width", "enable_funnels", "enable_junction_smoothing", "enable_grid_cleanup", "enable_terrain_smoothing", "enable_decorative_niches", "enable_pillars", "enable_2h_facades", "enable_3h_facades", "enable_floor_decorations", "debug_log_edge_kinds", "enable_platforms"]
const FLAG_FLOAT_KEYS := ["niche_spawn_chance", "secret_niche_spawn_chance", "plateau_noise_frequency", "plateau_threshold"]
const FLAG_INT_KEYS := ["force_theme", "plateau_noise_octaves", "plateau_min_area", "plateau_portal_margin", "platform_max_stairs", "stair_max_width"]

## Id puli MIXED do wypełnienia pola (JSON tilesets.mixed), lub "" gdy brak.
func mixed_pool_id() -> StringName:
	return StringName(tilesets().get("mixed", &""))

const VALID_LAYERS := [&"Walls", &"Floor", &"FloorDecor", &"Platforms", &""]
# Oczekiwana liczba części dla ról-modułów (klucz przechowywania = TileRole.Id).
static func _expected_parts(role: int) -> int:
	if role == TileRole.Id.FACADE_2H: return 2
	if role == TileRole.Id.FACADE_3H: return 3
	return 0

var version: int = 1
var raw: Dictionary = {}
var profile: MapTileProfile = null
var errors: Array[String] = []
var warnings: Array[String] = []

func generation() -> Dictionary: return raw.get("generation", {})
func flags() -> Dictionary: return raw.get("flags", {})
func tilesets() -> Dictionary: return raw.get("tilesets", {})
func zones() -> Dictionary: return raw.get("zones", {})
func tiling() -> Dictionary: return raw.get("tiling", {})
func debug() -> Dictionary: return raw.get("debug", {})

## Etap tilingu (np. "connectors_enabled") — domyślnie true (włączony jak dotychczas).
func is_tiling_enabled(key: String) -> bool:
	return bool(tiling().get(key, true))


## Parametr topologii z bloku "generation" jako int (def, gdy brak klucza).
func gen_int(key: String, def: int) -> int:
	var g := generation()
	return int(g[key]) if g.has(key) else def


## Buduje GenerationFlags z bloku "flags" JSON-a. Klucze nieobecne zostają z base
## (albo z domyślnych GenerationFlags), więc JSON nadpisuje tylko to, co podaje.
func build_flags(base: GenerationFlags = null) -> GenerationFlags:
	var f: GenerationFlags = base if base != null else GenerationFlags.new()
	var fl := flags()
	for k in FLAG_BOOL_KEYS:
		if fl.has(k): f.set(k, bool(fl[k]))
	for k in FLAG_FLOAT_KEYS:
		if fl.has(k): f.set(k, float(fl[k]))
	for k in FLAG_INT_KEYS:
		if fl.has(k): f.set(k, int(fl[k]))
	return f

func default_tileset_id() -> StringName:
	return StringName(tilesets().get("default", &""))


## Companion-JSON o tej samej nazwie bazowej co .tres: maps/<nazwa>.tres -> maps/config/<nazwa>.json
## (układ po reorganizacji), z fallbackiem na sąsiedni <nazwa>.json. "" gdy żaden nie istnieje.
static func resolve_json_path(tres_path: String) -> String:
	if tres_path.is_empty() or not tres_path.ends_with(".tres"):
		return ""
	var dir := tres_path.get_base_dir()
	var base := tres_path.get_file().get_basename()
	for candidate in ["%s/config/%s.json" % [dir, base], "%s/%s.json" % [dir, base]]:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


## Ładuje config z pliku .json. Zwraca zawsze obiekt (nawet przy błędzie) — z errors/warnings.
static func load_from_json_path(json_path: String) -> GeneratorBehaviourConfig:
	var cfg := GeneratorBehaviourConfig.new()

	if json_path.is_empty() or not FileAccess.file_exists(json_path):
		cfg.warnings.append("Brak JSON-a '%s' — użyto ustawień domyślnych." % json_path)
		return cfg

	var text := FileAccess.get_file_as_string(json_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		cfg.errors.append("Niepoprawny JSON '%s' — użyto ustawień domyślnych." % json_path)
		return cfg

	cfg.raw = parsed
	cfg.version = int(parsed.get("version", 1))

	var profile_path := String(parsed.get("tile_profile", ""))
	if profile_path.is_empty():
		cfg.warnings.append("JSON '%s' nie wskazuje 'tile_profile'." % json_path)
	elif not ResourceLoader.exists(profile_path):
		cfg.errors.append("Nie znaleziono profilu '%s' wskazanego w JSON." % profile_path)
	else:
		var res := ResourceLoader.load(profile_path)
		if res is MapTileProfile:
			cfg.profile = res
		else:
			cfg.errors.append("Zasób '%s' nie jest MapTileProfile." % profile_path)

	# Walidacja profilu + zgodność 'enabled' z profilem.
	if cfg.profile != null:
		cfg.errors.append_array(validate_profile(cfg.profile))
		var enabled: Array = cfg.tilesets().get("enabled", [])
		for tid in enabled:
			if cfg.profile.get_tileset(StringName(tid)) == null:
				cfg.warnings.append("JSON 'enabled' zawiera zestaw '%s' spoza profilu." % tid)

	# Walidacja parametrów generatora (nieznane klucze -> ostrzeżenie, nie błąd).
	for k in cfg.generation():
		if not GEN_KEYS.has(k):
			cfg.warnings.append("Nieznany parametr 'generation.%s' — pominięto." % k)
	var known_flags := FLAG_BOOL_KEYS + FLAG_FLOAT_KEYS + FLAG_INT_KEYS
	for k in cfg.flags():
		if not known_flags.has(k):
			cfg.warnings.append("Nieznana flaga 'flags.%s' — pominięto." % k)

	return cfg


## Walidacja MapTileProfile (§Walidacja README). Zwraca listę błędów krytycznych.
static func validate_profile(profile: MapTileProfile) -> Array[String]:
	var out: Array[String] = []
	if profile == null:
		out.append("Profil jest null.")
		return out

	var seen_ids := {}
	for definition in profile.tilesets:
		if definition == null:
			out.append("Profil zawiera pusty wpis tileset.")
			continue
		if String(definition.id).is_empty():
			out.append("NamedTileSetDefinition ma puste id.")
		elif seen_ids.has(definition.id):
			out.append("Zduplikowane id zestawu: '%s'." % definition.id)
		else:
			seen_ids[definition.id] = true

		if definition.enabled and definition.tile_set == null:
			out.append("Zestaw '%s' jest aktywny, ale nie ma przypisanego TileSet." % definition.id)

		var seen_roles := {}
		for entry in definition.tile_entries:
			if entry == null:
				continue
			if seen_roles.has(entry.role):
				out.append("Zestaw '%s' ma zduplikowaną rolę %d." % [definition.id, entry.role])
			seen_roles[entry.role] = true
			out.append_array(_validate_entry(definition.id, entry))

	if String(profile.default_tileset_id).is_empty():
		out.append("Profil nie ma default_tileset_id.")
	elif profile.get_tileset(profile.default_tileset_id) == null:
		out.append("default_tileset_id '%s' nie istnieje w profilu." % profile.default_tileset_id)

	for rule in profile.pair_rules:
		if rule == null:
			continue
		if profile.get_tileset(rule.first_tileset_id) == null:
			out.append("Reguła pary wskazuje nieistniejące id '%s'." % rule.first_tileset_id)
		if profile.get_tileset(rule.second_tileset_id) == null:
			out.append("Reguła pary wskazuje nieistniejące id '%s'." % rule.second_tileset_id)

	# Pule MIXED: id, źródła istnieją, źródła wzajemnie ALLOWED (nie FORBIDDEN).
	for pool in profile.mixed_pools:
		if pool == null:
			continue
		if String(pool.id).is_empty():
			out.append("MixedPool ma puste id.")
		if pool.sources.is_empty():
			out.append("MixedPool '%s' nie ma źródeł." % pool.id)
		for sid in pool.sources:
			if profile.get_tileset(sid) == null:
				out.append("MixedPool '%s' -> nieistniejące źródło '%s'." % [pool.id, sid])
		for i in range(pool.sources.size()):
			for j in range(i + 1, pool.sources.size()):
				var r: TileSetPairRule = profile.get_pair_rule(pool.sources[i], pool.sources[j])
				if r == null or r.mode == TileSetPairRule.Mode.FORBIDDEN:
					out.append("MixedPool '%s' -> '%s' i '%s' nie są ALLOWED (nie mogą się mieszać)." % [pool.id, pool.sources[i], pool.sources[j]])

	return out


## Walidacja jednego wpisu roli: legacy tile (gdy brak wariantów) oraz warianty/części.
static func _validate_entry(tileset_id: StringName, entry) -> Array[String]:
	var out: Array[String] = []
	var prefix := "'%s' rola %d" % [tileset_id, entry.role]

	if entry.variants.is_empty():
		# Tryb legacy: wymagany poprawny tile (chyba że celowe wymazanie).
		if entry.tile != null and not entry.tile.is_valid() and not entry.tile.is_erase():
			out.append("%s -> niepoprawny legacy TileRef." % prefix)
		return out

	# Tryb modułowy.
	var expected: int = _expected_parts(entry.role)
	var seen_variant_ids := {}
	for variant in entry.variants:
		if variant == null:
			out.append("%s -> pusty wariant (null)." % prefix)
			continue
		var vid: String = String(variant.variant_id)
		if vid.is_empty():
			out.append("%s -> wariant ma puste variant_id." % prefix)
		elif seen_variant_ids.has(vid):
			out.append("%s -> zduplikowane variant_id '%s'." % [prefix, vid])
		else:
			seen_variant_ids[vid] = true

		if variant.weight < 0.0:
			out.append("%s -> wariant '%s' ma ujemną wagę." % [prefix, vid])

		var active_parts: Array = variant.valid_parts()
		if variant.weight > 0.0 and active_parts.is_empty():
			out.append("%s -> wariant '%s' -> brak poprawnej części." % [prefix, vid])

		var seen_offsets := {}
		for part in variant.parts:
			if part == null:
				continue
			if part.tile == null or (not part.tile.is_valid() and not part.tile.is_erase()):
				out.append("%s -> wariant '%s' -> offset %s -> niepoprawny TileRef." % [prefix, vid, part.offset])
			if seen_offsets.has(part.offset):
				out.append("%s -> wariant '%s' -> offset %s -> zduplikowany offset części." % [prefix, vid, part.offset])
			seen_offsets[part.offset] = true
			if not VALID_LAYERS.has(part.layer):
				out.append("%s -> wariant '%s' -> offset %s -> niepoprawna warstwa '%s'." % [prefix, vid, part.offset, part.layer])

		if expected > 0 and variant.weight > 0.0 and active_parts.size() != expected:
			out.append("%s -> wariant '%s' -> oczekiwano %d części, jest %d." % [prefix, vid, expected, active_parts.size()])

	return out
