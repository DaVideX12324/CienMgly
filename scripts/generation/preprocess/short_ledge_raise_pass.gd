class_name ShortLedgeRaisePass
extends "grid_pass.gd"

## Wypustki 2H przy licu 3H+: w rzędzie stóp fasady wąski (1–MAX_LEDGE kolumn) odcinek ściany o grubości
## dokładnie 2, stykający się z kolumną 3H+ na tej samej stopie. Pipeline stawiałby na nim rim i lico 2H
## obok lica 3H.
## Naprawa: podniesienie do 3H (kratka podłogi nad wypustką -> ściana), gdy nad nią zostają co najmniej
## 2 kratki podłogi i to nie strefa portalu; inaczej wypustka jest usuwana (jej 2 kratki -> podłoga).
## Małe wolnostojące wyspy ściany (pole <= ISLAND_MAX) zostają bez zmian — mają własną regułę kafli
## (wymuszone 2H w EdgeAnalyzer.small_wall_islands), a podniesienie kolumny zmieniałoby ich kształt.

const MAX_LEDGE := 2  # najszersza wypustka (kolumny)
const MAX_ROUNDS := 3 # podniesienie może odsłonić kolejną wypustkę obok
const ISLAND_MAX := 25
const DIRS8: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


func get_id() -> StringName:
	return &"short_ledge_raise"


func apply(ctx: GenerationContext) -> int:
	if ctx.flags != null and not ctx.flags.enable_ledge_fix:
		return 0
	var total := 0
	var r := walk_raster(ctx)   # aktualizowany przy każdym zapisie do grid (wszystkie rundy)
	for _round in MAX_ROUNDS:
		var changed := _pass(ctx, r)
		total += changed
		if changed == 0:
			break
	return total


func _pass(ctx: GenerationContext, r: PackedByteArray) -> int:
	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height
	var changed := 0
	for y in range(4, height - 1):
		var x := 1
		while x < width - 1:
			if _depth(r, width, height, x, y) != 2:
				x += 1
				continue
			var start := x
			while x < width - 1 and _depth(r, width, height, x, y) == 2:
				x += 1
			var end := x - 1
			if end - start + 1 > MAX_LEDGE:
				continue
			if _depth(r, width, height, start - 1, y) != 3 and _depth(r, width, height, end + 1, y) != 3:
				continue
			if _small_island(ctx, Vector2i(start, y - 1)):
				continue
			for lx in range(start, end + 1):
				var top := Vector2i(lx, y - 3)
				var room_above: bool = raster_walk(r, width, height, lx, y - 4) and raster_walk(r, width, height, lx, y - 5)
				if room_above and not ctx.portal_zone.has(top) and grid.get(top) == CellType.FLOOR:
					grid[top] = CellType.WALL
					raster_set(r, width, height, top, false)
					changed += 1
				else:
					for c in [Vector2i(lx, y - 1), Vector2i(lx, y - 2)]:
						if not raster_walk(r, width, height, c.x, c.y):
							grid[c] = CellType.FLOOR
							raster_set(r, width, height, c, true)
							changed += 1
	return changed


## Grubość ściany nad stopą (cx, fy): 2 = dokładnie dwie kratki, 3 = trzy i więcej, 0 = brak lica.
static func _depth(r: PackedByteArray, w: int, h: int, cx: int, fy: int) -> int:
	if not raster_walk(r, w, h, cx, fy) or raster_walk(r, w, h, cx, fy - 1) or raster_walk(r, w, h, cx, fy - 2):
		return 0
	return 2 if raster_walk(r, w, h, cx, fy - 3) else 3


## Kratka ściany należy do małej wolnostojącej wyspy (komponent 8-spójny <= ISLAND_MAX, bez brzegu mapy).
## Przeszukiwanie z limitem — przy dużej bryle kończy się po ISLAND_MAX + 1 kratkach.
func _small_island(ctx: GenerationContext, c: Vector2i) -> bool:
	var seen := {c: true}
	var queue: Array[Vector2i] = [c]
	var i := 0
	while i < queue.size():
		var p: Vector2i = queue[i]
		i += 1
		if p.x <= 0 or p.y <= 0 or p.x >= ctx.width - 1 or p.y >= ctx.height - 1:
			return false
		for d in DIRS8:
			var n: Vector2i = p + d
			if seen.has(n) or GridUtils.is_walkable(ctx.grid, n):
				continue
			seen[n] = true
			queue.append(n)
			if queue.size() > ISLAND_MAX:
				return false
	return true
