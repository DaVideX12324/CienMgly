class_name NamedTileSetDefinition
extends Resource

## Definicja jednego KONKRETNIE nazwanego zestawu generatora (np. caves_rock).
## Mapuje role logiczne na kafelki atlasu. Nie decyduje GDZIE stawiać kafelek.

@export_category("Identyfikacja")
@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_category("Źródło kafelków")
@export var tile_set: TileSet
@export var enabled: bool = true

@export_category("Mapowanie ról")
@export var tile_entries: Array[TileRoleEntry] = []

## Zwraca wpis roli (z legacy tile i/lub variants) lub null.
func get_entry(role: TileRole.Id) -> TileRoleEntry:
	for entry in tile_entries:
		if entry != null and entry.role == role:
			return entry
	return null

## Zwraca TileRef dla roli lub null, gdy nie zdefiniowano.
func get_tile(role: TileRole.Id) -> TileRef:
	var entry := get_entry(role)
	return entry.tile if entry != null else null

## Czy zestaw ma poprawnie zdefiniowany kafelek dla roli.
func has_role(role: TileRole.Id) -> bool:
	var tile := get_tile(role)
	return tile != null and tile.is_valid()
