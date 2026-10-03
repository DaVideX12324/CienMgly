class_name SlopeThicknessPass
extends "grid_pass.gd"

## Ukośna ściana (skos) o grubości 3 -> 4. Stopa F = (x, y) z dokładnie 3 kratkami ściany nad sobą, leżąca
## w ukośnym ciągu >= MIN_RUN stóp schodzących po 1 rząd, dostaje ścianę w (x, y-4) — o ile to zwykła
## podłoga z co najmniej 2 kratkami podłogi nad nią i nowy szczyt nie wystaje ponad szczyt sąsiada po wyższej
## stronie skosu (bez „zębów” nad pojedynczym schodkiem). Decyzja usera 2026-10-03: schodki skosu mają mieć
## 4 kratki ściany, nie 3. Seed 119 160×160 (71–72, 56–57): dół klina skręca w prawo, więc okno 100/000/001
## (DiagonalTouchPass) go nie łapie. Uruchamiany po DiagonalTouchPass (P11a).

const MAX_ROUNDS := 4
const MIN_RUN := 3


func get_id() -> StringName:
	return &"slope_thickness"


func is_enabled(ctx: GenerationContext) -> bool:
	return ctx.flags == null or ctx.flags.enable_slope_thickness


func apply(ctx: GenerationContext) -> int:
	var total := 0
	for _round in MAX_ROUNDS:
		var fills: Array[Vector2i] = []
		for y in range(5, ctx.height - 1):
			for x in range(1, ctx.width - 1):
				var top := _thin_step_top(ctx.grid, Vector2i(x, y))
				if top != Vector2i(-1, -1):
					fills.append(top)
		for c in fills:
			ctx.grid[c] = CellType.WALL
		total += fills.size()
		if fills.is_empty():
			break
	return total


## Kratka do zasypania nad stopą skosu o grubości 3 albo (-1, -1).
static func _thin_step_top(grid: Dictionary, f: Vector2i) -> Vector2i:
	if not _is_foot(grid, f) or _depth(grid, f) != 3:
		return Vector2i(-1, -1)
	var top := f + Vector2i(0, -4)
	if not _floor(grid, top) or not _floor(grid, top + Vector2i(0, -1)) or not _floor(grid, top + Vector2i(0, -2)):
		return Vector2i(-1, -1)
	for down in [-1, 1]:
		if _run_len(grid, f, down) < MIN_RUN:
			continue
		# sąsiad po wyższej stronie: jego szczyt ściany (wiersz) nie może być niżej niż nowy szczyt F (y-4)
		var hi := f + Vector2i(-down, -1)
		if _is_foot(grid, hi) and hi.y - _depth(grid, hi) > top.y:
			continue
		return top
	return Vector2i(-1, -1)


## Liczba stóp w ukośnym ciągu przez `f` (down: +1 = stopy coraz niżej w prawo, -1 = w lewo).
static func _run_len(grid: Dictionary, f: Vector2i, down: int) -> int:
	var n := 1
	var p := f + Vector2i(-down, -1)
	while _is_foot(grid, p):
		n += 1
		p += Vector2i(-down, -1)
	p = f + Vector2i(down, 1)
	while _is_foot(grid, p):
		n += 1
		p += Vector2i(down, 1)
	return n


## Stopa fasady: podłoga z co najmniej 2 kratkami ściany nad sobą.
static func _is_foot(grid: Dictionary, p: Vector2i) -> bool:
	return GridUtils.is_walkable(grid, p) and not GridUtils.is_walkable(grid, p + Vector2i(0, -1)) \
		and not GridUtils.is_walkable(grid, p + Vector2i(0, -2))


## Liczba kratek ściany nad stopą (do 8).
static func _depth(grid: Dictionary, f: Vector2i) -> int:
	var d := 0
	while d < 8 and not GridUtils.is_walkable(grid, f + Vector2i(0, -(d + 1))):
		d += 1
	return d


static func _floor(grid: Dictionary, p: Vector2i) -> bool:
	return int(grid.get(p, CellType.WALL)) == CellType.FLOOR
