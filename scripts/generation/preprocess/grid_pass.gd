class_name GridPass
extends RefCounted


## Stabilny identyfikator do statystyk i logów.
func get_id() -> StringName:
	return &"grid_pass"


func is_enabled(_ctx: GenerationContext) -> bool:
	return true


## Zwraca liczbę zmienionych komórek.
func apply(_ctx: GenerationContext) -> int:
	return 0


## Raster chodliwości siatki (W × H, 1 = GridUtils.is_walkable) do szybkiego odrzucania kratek w pętlach po całej
## mapie. Pass, który pisze do ctx.grid, aktualizuje go (raster_set) albo buduje od nowa.
static func walk_raster(ctx: GenerationContext) -> PackedByteArray:
	var w := ctx.width
	var h := ctx.height
	var out := PackedByteArray()
	out.resize(w * h)
	var keys: Array = ctx.grid.keys()
	var vals: Array = ctx.grid.values()
	for k in range(keys.size()):
		var t: int = vals[k]
		if t == CellType.FLOOR or t == CellType.DOOR or t == CellType.ENTRANCE or t == CellType.EXIT:  # GridUtils.is_walkable
			var p: Vector2i = keys[k]
			if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
				out[p.y * w + p.x] = 1
	return out


## Chodliwość (x, y) z rastra; poza mapą false (jak GridUtils.is_walkable dla brakującej kratki).
static func raster_walk(r: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and r[y * w + x] == 1


static func raster_set(r: PackedByteArray, w: int, h: int, p: Vector2i, walkable: bool) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
		r[p.y * w + p.x] = 1 if walkable else 0
