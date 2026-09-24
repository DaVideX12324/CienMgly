class_name GenerationFlags
extends RefCounted

# --- Topologia ---
var enable_meandering: bool = true
var enable_variable_width: bool = true
var enable_funnels: bool = true
var enable_junction_smoothing: bool = true

# --- Pre-processing ---
var enable_grid_cleanup: bool = true

# --- Tiling ---
var enable_terrain_smoothing: bool = true
var enable_decorative_niches: bool = true
var enable_pillars: bool = true
var enable_2h_facades: bool = true
var enable_3h_facades: bool = true
var enable_floor_decorations: bool = true

# --- Płaskowyże (jeden poziom) — maska z szumu na podłodze; domyślnie WYŁĄCZONE (parytet) ---
var enable_platforms: bool = false
var plateau_noise_frequency: float = 0.02   # wielkość plam: MNIEJSZA = większe płaskowyże (0.02 ≈ plamy ~50 kratek, map-wide)
var plateau_threshold: float = 0.1         # próg szumu -1..1: NIŻSZY = więcej płaskowyżu (0.1 ≈ ~40% mapy)
var plateau_noise_octaves: int = 3         # szczegółowość brzegów: mniej = gładsze, większe plamy
var plateau_min_area: int = 40             # mniejsze komponenty odpadają
var plateau_coverage: float = 0.0          # >0: docelowy udział podłogi na wysokości >= 1 (próg z kwantyla szumu mapy; zastępuje plateau_threshold)
var plateau_high_coverage: float = 0.0     # >0: docelowy udział podłogi na wysokości >= 2 (przed zwężeniem o ring)
var plateau_pit_coverage: float = 0.0      # >0: docelowy udział podłogi w dołach (zastępuje plateau_pit_threshold)
var plateau_smooth: int = 1                # promień wygładzania brzegów (1 = drobne; 2–3 = gładkie, regularne kształty)
var plateau_block: int = 1                 # próbkowanie szumu w blokach N×N (1 = wył.; 3–5 = proste krawędzie, tarasy)
var plateau_levels: int = 1                # poziomy wzniesień (1 = płaskowyże, 2 = płaskowyże na płaskowyżach…)
var plateau_level_step: float = 0.12       # o ile wyższy próg szumu na każdy kolejny poziom (i głębiej dla dołów)
var plateau_level_ring: int = 3            # min. półka niższego poziomu wokół wyższego (bez klifów o 2 poziomy)
var plateau_pit_levels: int = 0            # poziomy zagłębień (0 = brak, 1 = doły -1…)
var plateau_pit_threshold: float = 0.3     # doły tam, gdzie szum < -próg (NIŻSZY = więcej dołów)
var platform_max_stairs: int = 4           # maks. schodów „z wyglądu” na płaskowyż — liczba losowana 0..max (S, potem N, E, W); schody dla osiągalności ponad to
var stair_max_width: int = 3               # schody: min. 2 ([L][R]), szersze dokładają MID

# --- Prawdopodobieństwa (nadpisują profil, gdy >= 0.0) ---
var niche_spawn_chance: float = 0.15
var secret_niche_spawn_chance: float = 0.3

# --- Debug ---
var force_theme: int = -1
var debug_log_edge_kinds: bool = false

## Mapowanie klucza cechy profilu na flagę runtime.
func get_feature(key: StringName) -> bool:
	match key:
		&"allow_pillars":             return enable_pillars
		&"allow_niches":              return enable_decorative_niches
		&"allow_secret_niches":       return enable_decorative_niches
		&"allow_2h_facades":          return enable_2h_facades
		&"allow_3h_facades":          return enable_3h_facades
		&"allow_floor_decorations":   return enable_floor_decorations
		_:                            return true
