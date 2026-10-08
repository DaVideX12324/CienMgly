extends "grid_pass.gd"

## Uzupełnianie ścian do 3H (flaga enforce_3h_walls): pionowy pas ściany niższy niż 3 kratki, z podłogą
## nad nim i pod nim (lico 2H / 1H), dostaje brakujące kratki z podłogi. Decyzja zapada dla całego odcinka
## (sąsiednie kolumny z tym samym pasem ściany): w górę albo w dół — tam, gdzie nowe kratki licują się
## ze ścianami po bokach odcinka (bez uskoku 1–2 kratek na krawędzi). Remis -> w górę. Tylko zwykła
## podłoga (bez wejścia / wyjścia). Dla tilesetów bez lica 2H (ścieki). Gdy podniesienie blokuje chroniona
## podłoga (GenerationContext.protected_floor), pas ściany znika (ściana -> podłoga).

const MIN_HEIGHT := 3


func get_id() -> StringName:
	return &"wall_3h"


func apply(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	# Lico na kratkach ściany (facade_base_on_wall): ściana min. kap + 3 rzędy lica.
	var min_h := MIN_HEIGHT + (1 if ctx.flags != null and ctx.flags.facade_base_on_wall else 0)
	# Kolumny z za niskim pasem ściany: x -> [y0, y1] (pierwsza i ostatnia kratka ściany), per rząd startu.
	var thin := {}  # Vector2i(x, y0) -> y1
	for x in range(ctx.width):
		var y := 0
		while y < ctx.height:
			if int(grid.get(Vector2i(x, y), CellType.WALL)) != CellType.WALL:
				y += 1
				continue
			var y0 := y
			while y < ctx.height and int(grid.get(Vector2i(x, y), CellType.WALL)) == CellType.WALL:
				y += 1
			if y - y0 >= min_h or y0 == 0 or y >= ctx.height:
				continue
			if GridUtils.is_walkable(grid, Vector2i(x, y0 - 1)) and GridUtils.is_walkable(grid, Vector2i(x, y)):
				thin[Vector2i(x, y0)] = y - 1

	var to_wall := {}
	var to_floor := {}
	var done := {}
	for key: Vector2i in thin:
		if done.has(key):
			continue
		# Odcinek: sąsiednie kolumny z identycznym pasem (ten sam y0 i y1).
		var y0 := key.y
		var y1: int = thin[key]
		var x0 := key.x
		while thin.has(Vector2i(x0 - 1, y0)) and thin[Vector2i(x0 - 1, y0)] == y1:
			x0 -= 1
		var x1 := key.x
		while thin.has(Vector2i(x1 + 1, y0)) and thin[Vector2i(x1 + 1, y0)] == y1:
			x1 += 1
		for x in range(x0, x1 + 1):
			done[Vector2i(x, y0)] = true
		var need := min_h - (y1 - y0 + 1)
		var up_ok := _can_fill(grid, x0, x1, y0 - need, y0 - 1, ctx.protected_floor)
		var down_ok := _can_fill(grid, x0, x1, y1 + 1, y1 + need, ctx.protected_floor)
		if not up_ok and not down_ok:
			# Podłoga, która musi zostać podłogą (protected_floor, np. chodnik / kanał), blokuje podniesienie —
			# wtedy za niski pas ściany znika (staje się podłogą); bez ochrony (jaskinia) zostaje jak było.
			if _touches_protected(ctx.protected_floor, x0, x1, y0 - need, y0 - 1) or _touches_protected(ctx.protected_floor, x0, x1, y1 + 1, y1 + need):
				for x in range(x0, x1 + 1):
					for yy in range(y0, y1 + 1):
						to_floor[Vector2i(x, yy)] = true
			continue
		var use_up := up_ok
		if up_ok and down_ok:
			use_up = _exposed_ends(grid, x0, x1, y0 - need, y0 - 1) <= _exposed_ends(grid, x0, x1, y1 + 1, y1 + need)
		var ya := y0 - need if use_up else y1 + 1
		var yb := y0 - 1 if use_up else y1 + need
		for x in range(x0, x1 + 1):
			for yy in range(ya, yb + 1):
				to_wall[Vector2i(x, yy)] = true
	for p in to_wall:
		grid[p] = CellType.WALL
	for p in to_floor:
		grid[p] = CellType.FLOOR
	return to_wall.size() + to_floor.size()


static func _touches_protected(protected: Dictionary, x0: int, x1: int, ya: int, yb: int) -> bool:
	if protected.is_empty():
		return false
	for x in range(x0, x1 + 1):
		for y in range(ya, yb + 1):
			if protected.has(Vector2i(x, y)):
				return true
	return false


## Czy prostokąt x0..x1 × ya..yb to w całości zwykła podłoga (można go zamurować), bez chronionej podłogi.
static func _can_fill(grid: Dictionary, x0: int, x1: int, ya: int, yb: int, protected: Dictionary = {}) -> bool:
	for x in range(x0, x1 + 1):
		for y in range(ya, yb + 1):
			if int(grid.get(Vector2i(x, y), CellType.WALL)) != CellType.FLOOR:
				return false
			if not protected.is_empty() and protected.has(Vector2i(x, y)):
				return false
	return true


## Ile kratek obok nowego prostokąta (lewa i prawa krawędź) to podłoga — każda to uskok na krawędzi ściany.
static func _exposed_ends(grid: Dictionary, x0: int, x1: int, ya: int, yb: int) -> int:
	var n := 0
	for y in range(ya, yb + 1):
		if GridUtils.is_walkable(grid, Vector2i(x0 - 1, y)):
			n += 1
		if GridUtils.is_walkable(grid, Vector2i(x1 + 1, y)):
			n += 1
	return n
