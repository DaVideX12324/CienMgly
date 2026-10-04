class_name PolyRoomCarver
extends "room_carver.gd"

## Pokój wielokątny o prostych ścianach (flaga room_shape = "poly"): prostokąt z wyciętymi narożnikami —
## L (jeden narożnik), T / schodek (dwa), plus (cztery) albo zwykły prostokąt. Wycięcia są mniejsze niż
## połowa boku, więc środek pokoju (cel korytarzy i portali) zawsze zostaje podłogą, a każde ramię
## ma co najmniej MIN_ARM kratek szerokości. Wycięcia nie ruszają kratek przechodnich sprzed rzeźbienia.

const MIN_ARM := 5
const MIN_CUT := 3
## Wagi kształtów: prostokąt, jeden narożnik, dwa narożniki, cztery narożniki.
const SHAPE_WEIGHTS: Array[float] = [0.2, 0.35, 0.3, 0.15]


func carve(ctx: GenerationContext, rect: Rect2i) -> void:
	var grid := ctx.grid
	# Kratki już przechodnie (np. korytarz pod pokojem na zakręcie) — wycięcia ich nie zamurowują.
	var kept := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := Vector2i(x, y)
			if GridUtils.is_walkable(grid, p):
				kept[p] = true
			grid[p] = CellType.FLOOR
	var max_cut := Vector2i(mini(rect.size.x / 2 - 1, rect.size.x - MIN_ARM), mini(rect.size.y / 2 - 1, rect.size.y - MIN_ARM))
	if max_cut.x < MIN_CUT or max_cut.y < MIN_CUT:
		return  # za mały na wycięcia
	var corners: Array[int] = [0, 1, 2, 3]  # NW, NE, SW, SE
	_shuffle(corners, ctx.rng)
	var count: int = [0, 1, 2, 4][_pick_weighted(ctx.rng)]
	for i in count:
		var cut := Vector2i(ctx.rng.randi_range(MIN_CUT, max_cut.x), ctx.rng.randi_range(MIN_CUT, max_cut.y))
		var c := corners[i]
		var x0 := rect.position.x if c % 2 == 0 else rect.end.x - cut.x
		var y0 := rect.position.y if c < 2 else rect.end.y - cut.y
		for y in range(y0, y0 + cut.y):
			for x in range(x0, x0 + cut.x):
				if not kept.has(Vector2i(x, y)):
					grid[Vector2i(x, y)] = CellType.WALL


static func _pick_weighted(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in SHAPE_WEIGHTS:
		total += w
	var r := rng.randf() * total
	for i in SHAPE_WEIGHTS.size():
		r -= SHAPE_WEIGHTS[i]
		if r < 0.0:
			return i
	return SHAPE_WEIGHTS.size() - 1


static func _shuffle(arr: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := arr[i]
		arr[i] = arr[j]
		arr[j] = t
