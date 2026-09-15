class_name LegacyTileHash
extends RefCounted

## Oblicza deterministyczny roll (0..99) dla wypełnienia litej skały (Rock Fill).
## Dokładne odwzorowanie legacy formuły z cave_generator.gd.
static func rock_fill_roll(pos: Vector2i, seed_value: int) -> int:
	return (int(hash(Vector2i(pos.x, pos.y + seed_value))) & 0x7fffffff) % 100
