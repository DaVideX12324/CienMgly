class_name TileVariant
extends Resource

## Jeden kompletny wariant graficzny roli/modułu. Wybór następuje RAZ na cały moduł
## (nigdy osobno per część). weight <= 0 => wariant wyłączony.

@export var variant_id: StringName = &"A"
@export var weight: float = 1.0
@export var parts: Array[TileModulePart] = []

## Czy wariant jest aktywny i ma co najmniej jedną poprawną część.
func is_active() -> bool:
	if weight <= 0.0:
		return false
	for p in parts:
		if p != null and p.is_valid():
			return true
	return false

## Poprawne części (pomija null / puste).
func valid_parts() -> Array:
	var out: Array = []
	for p in parts:
		if p != null and p.is_valid():
			out.append(p)
	return out
