class_name GenerationContext
extends RefCounted


# --- Wejście (niezmienne po konstrukcji) ---
var profile: RefCounted = null
var flags: GenerationFlags = null
var overrides: Dictionary = {}
var seed_value: int = 0
var width: int = 0
var height: int = 0
var theme_override: int = -1

# --- Stan roboczy ---
var rng: RandomNumberGenerator
var tile_rng: RandomNumberGenerator
var priority_table: Dictionary = {}
var grid: Dictionary = {}
var portal_zone: Dictionary = {}
var entrance_zone: Array[Vector2i] = []
var exit_zone: Array[Vector2i] = []
var rooms: Array[Rect2i] = []
var entrance_pos: Vector2i = Vector2i.ZERO
var exit_pos: Vector2i = Vector2i.ZERO
var plateau: RefCounted = null  # PlateauLayout — płaskowyże jako nakładka (grid zostaje FLOOR)
var terrain_masks: Dictionary = {}  # {seed, mud, grass} policzone w topologii (TerrainMaskPlanner.compute_masks)
# Tryb płaskowyżu (tylko syntetyczny kontekst PlateauRenderera): fasady zawsze 2H, stopień
# lica 2H = moduł IN (STEP_LEFT/RIGHT 2-częściowy). Domyślnie false — ściany bez zmian.
var plateau_mode: bool = false
# Kratki ściany małych wolnostojących wysp (EdgeAnalyzer.small_wall_islands): fasada pod nimi zawsze 2H.
# Liczone w EdgeAnalyzer.analyze, gdy puste (flaga small_pillar_2h_max_area).
var force_2h_cells: Dictionary = {}
## Podłoga, której przejścia kształtu ścian (Wall3HPass, WallTopAlignPass) nie zamurowują — np. przesmyki układu structured
## (kanały, chodniki, korytarze), żeby nie odciąć części mapy. Pusta = bez ograniczeń (jaskinia).
var protected_floor: Dictionary = {}
# Kratki nisz-przejść (NichePlacer): kafle OUT obu kolumn i szczyt nad płytszą — przy wstawianiu
# alternatywa NichePlacer.PASSAGE_ALT (inne kolizje), gdy TileSet ją ma.
var passage_cells: Dictionary = {}
# Prostokąt skanowania EdgeAnalyzera i placerów ścian (pusty = cała mapa). PlateauRenderer
# zawęża nim drugi przebieg pipeline'u do okolicy płaskowyżów — współrzędne zostają globalne.
var scan_rect: Rect2i = Rect2i()

# --- Named TileSet System (opcjonalne; null => placery używają stałych) ---
var map_tile_profile: MapTileProfile = null
var tileset_field: TileSetField = null
var generator_behaviour: Dictionary = {}

# --- Szumy (deterministyczne, tworzone raz) ---
var theme_noise: FastNoiseLite
var variant_noise: FastNoiseLite
var mud_noise: FastNoiseLite
var grass_noise: FastNoiseLite

# --- Diagnostyka ---
var preprocess_stats: Dictionary = {}
## Kanały ścieków (CanalLayout) albo null.
var canals: RefCounted = null
## Stopy lic z filarem (kratka podłogi pod licem w kolumnie filara; filary = obiekty lica w rytmie) -> najwyższy rząd
## filara względem stopy (ujemny). Lico za filarem z cieniem LR, obok z cieniem od strony filara — w rzędach, do których filar sięga.
var pillar_feet: Dictionary = {}
## Górne kratki modułów lica 4H (Vector2i -> true) — narożnik wewnętrzny nad nimi idzie rząd wyżej.
var facade_4h_tops: Dictionary = {}
var facade_4h_connectors: Dictionary = {}  # stopy łączników 3H↔4H (CONNECTOR_4H) — bez narożnika schodka nad nimi
## Stopy lica 4H (Vector2i -> true) — wybrane odcinki lica, liczone raz (FacadePlacer.wants_4h).
var facade_4h_bases: Dictionary = {}
var facade_4h_planned := false
var debug_pos: Vector2i = Vector2i.ZERO

## Efektywna wartość cechy: profil AND flagi runtime.
## Obszar skanowania pętli (y, x): scan_rect albo cała mapa.
func scan_bounds() -> Rect2i:
	return scan_rect if scan_rect.has_area() else Rect2i(0, 0, width, height)


func feature(key: StringName) -> bool:
	var allowed: bool = true
	if profile != null and "features" in profile:
		allowed = profile.features.get(key, false)
	var enabled: bool = true
	if flags != null:
		enabled = flags.get_feature(key)
	return allowed and enabled

## Parametr topologii z uwzględnieniem override runtime.
func param(key: StringName, default_value: Variant) -> Variant:
	if overrides.has(key):
		return overrides[key]
	if profile != null and "topology" in profile:
		return profile.topology.get(key, default_value)
	return default_value

## Prawdopodobieństwo z profilu (nadpisywalne flagą).
func probability(key: StringName, default_value: float) -> float:
	if flags != null:
		match key:
			&"niche_spawn_chance":
				if flags.niche_spawn_chance >= 0.0:
					return flags.niche_spawn_chance
			&"secret_niche_spawn_chance":
				if flags.secret_niche_spawn_chance >= 0.0:
					return flags.secret_niche_spawn_chance
	if profile != null and "probabilities" in profile:
		return float(profile.probabilities.get(key, default_value))
	return default_value
