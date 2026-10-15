class_name DiagonalTouchPass
extends "grid_pass.gd"

## Skośny styk podłóg przez litą ścianę (okno 3×3, 1 = podłoga): 100/000/001 -> 000/000/001 i
## 001/000/100 -> 000/000/100 — górny narożnik staje się ścianą. Ta sama reguła co krok 3
## WallThicknessPass, ale na końcu preprocessingu: późniejsze passy (ShortLedgeRaisePass podnosi
## wypustkę o kratkę) potrafią taki styk odtworzyć.
## Na tym etapie są już portale i nie ma kolejnej naprawy spójności, więc zasypywana jest tylko zwykła
## podłoga, która nie łączy dwóch sąsiadów (N i W / N i E) jako jedyne przejście; gdy górnego narożnika
## nie wolno zasypać, zasypywany jest dolny.

const MAX_ROUNDS := 4


func get_id() -> StringName:
	return &"diagonal_touch"


func apply(ctx: GenerationContext) -> int:
	var total := 0
	var r := walk_raster(ctx)   # aktualizowany przy zasypaniu (wszystkie rundy)
	for _round in MAX_ROUNDS:
		var changed := _pass(ctx, r)
		total += changed
		if changed == 0:
			break
	return total


func _pass(ctx: GenerationContext, r: PackedByteArray) -> int:
	var grid := ctx.grid
	var changed := 0
	var w := ctx.width
	for y in range(1, ctx.height - 1):
		for x in range(1, ctx.width - 1):
			var i := y * w + x
			if r[i] or r[i - w] or r[i + w] or r[i - 1] or r[i + 1]:
				continue
			var nw: bool = r[i - w - 1] == 1
			var ne: bool = r[i - w + 1] == 1
			var sw: bool = r[i + w - 1] == 1
			var se: bool = r[i + w + 1] == 1
			if nw == ne or nw == sw:   # żaden wzorzec (oba wymagają nw != ne i nw != sw)
				continue
			var p := Vector2i(x, y)
			var pair: Array[Vector2i] = []
			if nw and se and not ne and not sw:
				pair = [p + Vector2i(-1, -1), p + Vector2i(1, 1)]
			elif ne and sw and not nw and not se:
				pair = [p + Vector2i(1, -1), p + Vector2i(-1, 1)]
			else:
				continue
			for c in pair:
				if _can_fill(grid, c, p):
					grid[c] = CellType.WALL
					raster_set(r, w, ctx.height, c, false)
					changed += 1
					break
	return changed


## Kratka `c` (narożnik okna wokół `p`) to zwykła podłoga, a jej zasypanie nie rozcina przejścia: jej
## dwaj chodliwi sąsiedzi od strony z dala od `p` (np. N i W dla narożnika NW) łączą się dalej przez
## kratkę po skosie za nimi.
static func _can_fill(grid: Dictionary, c: Vector2i, p: Vector2i) -> bool:
	if int(grid.get(c, CellType.WALL)) != CellType.FLOOR:
		return false
	var away := c - p  # kierunek od środka okna, np. (-1, -1) dla NW
	var a := c + Vector2i(away.x, 0)
	var b := c + Vector2i(0, away.y)
	if GridUtils.is_walkable(grid, a) and GridUtils.is_walkable(grid, b):
		return GridUtils.is_walkable(grid, c + away)
	return true
