class_name GenerationContext
extends RefCounted

const GenerationFlags = preload("res://modules/quiz_rpg/scripts/generation/core/generation_flags.gd")

# --- Wejście (niezmienne po konstrukcji) ---
var profile: RefCounted = null
var flags: GenerationFlags = null
var overrides: Dictionary = {}
var seed_value: int = 0
var width: int = 0
var height: int = 0

# --- Stan roboczy ---
var rng: RandomNumberGenerator
var grid: Dictionary = {}
var portal_zone: Dictionary = {}
var rooms: Array[Rect2i] = []
var entrance_pos: Vector2i = Vector2i.ZERO
var exit_pos: Vector2i = Vector2i.ZERO

# --- Szumy (deterministyczne, tworzone raz) ---
var theme_noise: FastNoiseLite
var variant_noise: FastNoiseLite
var mud_noise: FastNoiseLite
var grass_noise: FastNoiseLite

# --- Diagnostyka ---
var preprocess_stats: Dictionary = {}
var debug_pos: Vector2i = Vector2i.ZERO

## Efektywna wartość cechy: profil AND flagi runtime.
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
