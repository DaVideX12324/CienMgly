extends "grid_pass.gd"

## Wyrównanie górnej krawędzi ścian (flaga align_wall_tops): uskok o 1–2 rzędy między sąsiednimi
## odcinkami szczytu ściany (kratki ściany z podłogą tuż nad nimi) — np. ściana 3H stykająca się
## z wypustką 1H. Naprawa o mniejszym polu: ścięcie wyższego odcinka (tylko gdy pod nim zostaje
## ściana >= MIN_DEPTH) albo podniesienie niższego (tylko na zwykłej podłodze). Dla ścieków.

const MIN_DEPTH := 3
const MAX_STEP := 2
const MAX_ROUNDS := 400


func get_id() -> StringName:
	return &"wall_top_align"


func apply(ctx: GenerationContext) -> int:
	var changed := 0
	for _i in MAX_ROUNDS:
		var fix := _find_fix(ctx)
		if fix.is_empty():
			break
		for p: Vector2i in fix.cells:
			ctx.grid[p] = fix.type
		changed += (fix.cells as Array).size()
	return changed


func _is_top(grid: Dictionary, p: Vector2i) -> bool:
	return not GridUtils.is_walkable(grid, p) and GridUtils.is_walkable(grid, p + Vector2i(0, -1))


## Odcinek szczytu w rzędzie p.y zawierający p: [x0, x1].
func _run(grid: Dictionary, p: Vector2i) -> Vector2i:
	var x0 := p.x
	while _is_top(grid, Vector2i(x0 - 1, p.y)):
		x0 -= 1
	var x1 := p.x
	while _is_top(grid, Vector2i(x1 + 1, p.y)):
		x1 += 1
	return Vector2i(x0, x1)


## Pierwszy uskok i jego naprawa: {cells: Array[Vector2i], type: CellType} albo {}.
func _find_fix(ctx: GenerationContext) -> Dictionary:
	var grid := ctx.grid
	for y in range(1, ctx.height - 1):
		var x := 0
		while x < ctx.width:
			if not _is_top(grid, Vector2i(x, y)):
				x += 1
				continue
			var r := _run(grid, Vector2i(x, y))
			x = r.y + 1
			for c in [r.x - 1, r.y + 1]:
				if not GridUtils.is_walkable(grid, Vector2i(c, y)):
					continue  # obok ściana na tej samej wysokości (albo wyżej) — nie ten przypadek
				for d in range(1, MAX_STEP + 1):
					var nb := Vector2i(c, y + d)
					if not _is_top(grid, nb):
						continue
					var nr := _run(grid, nb)
					var fix := _choose(ctx, r, y, nr, y + d)
					if not fix.is_empty():
						return fix
					break
	return {}


## Ścięcie wyższego odcinka (rzędy hy..ly-1) albo podniesienie niższego (rzędy hy..ly-1 nad nim).
func _choose(ctx: GenerationContext, hr: Vector2i, hy: int, lr: Vector2i, ly: int) -> Dictionary:
	var grid := ctx.grid
	var cut: Array[Vector2i] = []
	var cut_ok := true
	for cx in range(hr.x, hr.y + 1):
		for yy in range(hy, ly):
			cut.append(Vector2i(cx, yy))
		# pod nowym szczytem ściana musi mieć >= MIN_DEPTH kratek
		var min_depth := MIN_DEPTH + (1 if ctx.flags != null and ctx.flags.facade_base_on_wall else 0)
		for dd in range(min_depth):
			if GridUtils.is_walkable(grid, Vector2i(cx, ly + dd)):
				cut_ok = false
	var raise: Array[Vector2i] = []
	var raise_ok := true
	for cx in range(lr.x, lr.y + 1):
		for yy in range(hy, ly):
			var p := Vector2i(cx, yy)
			if int(grid.get(p, CellType.WALL)) != CellType.FLOOR:
				raise_ok = false
			raise.append(p)
	if cut_ok and (not raise_ok or cut.size() <= raise.size()):
		return {"cells": cut, "type": CellType.FLOOR}
	if raise_ok:
		return {"cells": raise, "type": CellType.WALL}
	return {}
