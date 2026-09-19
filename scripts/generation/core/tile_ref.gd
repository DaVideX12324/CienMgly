class_name TileRef
extends Resource

## Minimalna referencja do jednego kafelka TileSet — dokładnie w formie wymaganej
## przez TileMapLayer.set_cell(source_id, atlas_coords, alternative_tile).

@export var source_id: int = 0
@export var atlas_coords: Vector2i = Vector2i(-1, -1)
@export var alternative_tile: int = 0

func is_valid() -> bool:
	return source_id >= 0 \
		and atlas_coords.x >= 0 \
		and atlas_coords.y >= 0

## Czy referencja celowo oznacza wymazanie komórki (konwencja placementów: (-1,-1)).
func is_erase() -> bool:
	return atlas_coords == Vector2i(-1, -1)

static func make(coords: Vector2i, src: int = 0, alt: int = 0) -> TileRef:
	var r := TileRef.new()
	r.source_id = src
	r.atlas_coords = coords
	r.alternative_tile = alt
	return r
