class_name MapTileProfile
extends Resource

## Scala nazwane zestawy dostępne dla mapy oraz reguły ich styku.
## Reguły par należą tutaj (dotyczą grafiki: przejść, overlayów, renderu granicy).

@export_category("Zestawy dostępne w profilu")
@export var tilesets: Array[NamedTileSetDefinition] = []

@export_category("Reguły sąsiedztwa")
@export var pair_rules: Array[TileSetPairRule] = []

@export_category("Fallback")
@export var default_tileset_id: StringName

func get_tileset(id: StringName) -> NamedTileSetDefinition:
	for definition in tilesets:
		if definition != null and definition.id == id:
			return definition
	return null

## Reguła dla pary ID. Domyślnie symetryczna; kierunkowa tylko dla first->second.
func get_pair_rule(first_id: StringName, second_id: StringName) -> TileSetPairRule:
	for rule in pair_rules:
		if rule == null:
			continue

		var direct: bool = (
			rule.first_tileset_id == first_id
			and rule.second_tileset_id == second_id
		)
		var reversed: bool = (
			not rule.directional
			and rule.first_tileset_id == second_id
			and rule.second_tileset_id == first_id
		)
		if direct or reversed:
			return rule

	return null

## Domyślna definicja zestawu (fallback), lub null.
func get_default_tileset() -> NamedTileSetDefinition:
	return get_tileset(default_tileset_id)
