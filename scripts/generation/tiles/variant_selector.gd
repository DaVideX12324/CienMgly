class_name VariantSelector
extends RefCounted

## Deterministyczny, WAŻONY wybór wariantu na podstawie stabilnego hasza z pozycji
## kotwicy + seed + identyfikatorów (NIE z współdzielonego ctx.tile_rng). Dzięki temu
## wynik jest niezależny od kolejności iteracji komórek i stabilny dla danego seeda.

const TileVariant = preload("res://modules/quiz_rpg/scripts/generation/core/tile_variant.gd")

## Wybiera aktywny wariant ważony wagą, lub null gdy brak aktywnych.
static func choose_variant_for_anchor(
	variants: Array,
	anchor_pos: Vector2i,
	world_seed: int,
	tileset_id: StringName,
	module_role: int,
	salt: int = 0
) -> TileVariant:
	var active: Array = []
	var total: float = 0.0
	for v in variants:
		if v == null:
			continue
		if not (v as TileVariant).is_active():
			continue
		active.append(v)
		total += (v as TileVariant).weight
	if active.is_empty() or total <= 0.0:
		return null

	var h: int = _stable_hash([
		world_seed, anchor_pos.x, anchor_pos.y,
		int(String(tileset_id).hash()), module_role, salt,
	])
	var r: float = (float(h) / 4294967296.0) * total # h in [0, 2^32) -> [0, total)

	var acc: float = 0.0
	for v in active:
		acc += (v as TileVariant).weight
		if r < acc:
			return v
	return active[active.size() - 1]


## Stabilny 32-bit hash (FNV-1a na sekwencji intów). Deterministyczny między uruchomieniami.
static func _stable_hash(values: Array) -> int:
	var h: int = 2166136261
	for value in values:
		var v: int = int(value) & 0xffffffff
		# miksujemy po 4 bajty
		for shift in [0, 8, 16, 24]:
			var byte: int = (v >> shift) & 0xff
			h = (h ^ byte) & 0xffffffff
			h = (h * 16777619) & 0xffffffff
	return h & 0xffffffff
