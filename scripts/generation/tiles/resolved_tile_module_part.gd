class_name ResolvedTileModulePart
extends RefCounted

## Pośredni wynik resolvera dla jednej kratki modułu. Placer buduje z tego finalne
## TilePlacement, dokładając własne category / priority / tie_breaker.

var offset: Vector2i = Vector2i.ZERO
var tile: TileRef = null
var layer: StringName = &"Walls"
var variant_id: StringName = &""
var source_tileset_id: StringName = &""

func final_pos(anchor_pos: Vector2i) -> Vector2i:
	return anchor_pos + offset
