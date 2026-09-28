class_name ShortLedgeRaisePass
extends "res://modules/quiz_rpg/scripts/generation/preprocess/grid_pass.gd"

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
	for _round in MAX_ROUNDS:
		var changed := _pass(ctx)
		total += changed
		if changed == 0:
			break
	return total


func _pass(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	var width := ctx.width
	var height := ctx.height
	var changed := 0
	var walk := func(c: Vector2i) -> bool: return GridUtils.is_walkable(grid, c)
	# Grubość ściany nad stopą (x, y): 2 = dokładnie dwie kratki, 3 = trzy i więcej, 0 = brak lica.
	var depth := func(cx: int, fy: int) -> int:
		if not walk.call(Vector2i(cx, fy)) or walk.call(Vector2i(cx, fy - 1)) or walk.call(Vector2i(cx, fy - 2)):
			return 0
		return 2 if walk.call(Vector2i(cx, fy - 3)) else 3

	for y in range(4, height - 1):
		var x := 1
		while x < width - 1:
			if depth.call(x, y) != 2:
				x += 1
				continue
			var start := x
			while x < width - 1 and depth.call(x, y) == 2:
				x += 1
			var end := x - 1
			if end - start + 1 > MAX_LEDGE:
				continue
			if depth.call(start - 1, y) != 3 and depth.call(end + 1, y) != 3:
				continue
			if _small_island(ctx, Vector2i(start, y - 1)):
				continue
			for lx in range(start, end + 1):
				var top := Vector2i(lx, y - 3)
				var room_above: bool = walk.call(top + Vector2i(0, -1)) and walk.call(top + Vector2i(0, -2))
				if room_above and not ctx.portal_zone.has(top) and grid.get(top) == CellType.FLOOR:
					grid[top] = CellType.WALL
					changed += 1
				else:
					for c in [Vector2i(lx, y - 1), Vector2i(lx, y - 2)]:
						if not walk.call(c):
							grid[c] = CellType.FLOOR
							changed += 1
	return changed


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
