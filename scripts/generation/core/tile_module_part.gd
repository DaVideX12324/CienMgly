class_name TileModulePart
extends Resource

## Jedna kratka modułu należąca do wybranego wariantu. Pozycja jest WZGLĘDNA do kotwicy
## dostarczonej przez placer (offset), grafika w `tile`, warstwa docelowa w `layer`.

@export var offset: Vector2i = Vector2i.ZERO
@export var tile: TileRef
@export var layer: StringName = &"Walls"

func is_valid() -> bool:
	return tile != null and (tile.is_valid() or tile.is_erase())
