class_name SeededNoise
extends RefCounted

static func create(seed_val: int, frequency: float, noise_type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = frequency
	noise.noise_type = noise_type as FastNoiseLite.NoiseType
	return noise
