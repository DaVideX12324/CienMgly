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
var platform_max_stairs: int = 4           # wspólny budżet schodów na płaskowyż (S, potem N, E, W); schody dla spójności ponad budżet
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
