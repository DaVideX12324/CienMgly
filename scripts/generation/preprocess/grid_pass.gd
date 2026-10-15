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


## Typ kratki z siatki do rastra typów; MISSING = brak kratki w ctx.grid (domyślna wartość zależy od wywołania).
const MISSING := 255


## Raster typów kratek (W × H, wartość CellType, MISSING = brak w ctx.grid). Pass aktualizuje go przy zapisie.
static func type_raster(ctx: GenerationContext) -> PackedByteArray:
	var w := ctx.width
	var h := ctx.height
	var out := PackedByteArray()
	out.resize(w * h)
	out.fill(MISSING)
	var keys: Array = ctx.grid.keys()
	var vals: Array = ctx.grid.values()
	for k in range(keys.size()):
		var p: Vector2i = keys[k]
		if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
			out[p.y * w + p.x] = int(vals[k])
	return out


## Tablice wartości rastra typów (indeks = CellType albo MISSING): 1 = chodliwy (jak walkable_type), 1 = „ściana” w
## sensie grid.get(p, WALL) == WALL (WALL albo brak kratki). W gorących pętlach odczyt z tablicy zamiast wywołania
## funkcji — wywołanie w GDScript kosztuje kilka razy więcej niż cała reszta sprawdzenia kratki.
static var WALK_LUT: PackedByteArray = _lut([CellType.FLOOR, CellType.DOOR, CellType.ENTRANCE, CellType.EXIT])
static var WALL_LUT: PackedByteArray = _lut([CellType.WALL, MISSING])


static func _lut(types: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	for t in types:
		out[t] = 1
	return out


## Typ chodliwy (jak GridUtils.is_walkable; MISSING = VOID).
static func walkable_type(t: int) -> bool:
	return t == CellType.FLOOR or t == CellType.DOOR or t == CellType.ENTRANCE or t == CellType.EXIT


## Chodliwość (x, y) z rastra; poza mapą false (jak GridUtils.is_walkable dla brakującej kratki).
static func raster_walk(r: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and r[y * w + x] == 1


static func raster_set(r: PackedByteArray, w: int, h: int, p: Vector2i, walkable: bool) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
		r[p.y * w + p.x] = 1 if walkable else 0
