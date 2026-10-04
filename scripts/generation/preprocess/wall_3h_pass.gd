extends "grid_pass.gd"

## Uzupełnianie ścian do 3H (flaga enforce_3h_walls): pionowy pas ściany niższy niż 3 kratki, z podłogą
## nad nim i pod nim (lico 2H / 1H), dostaje brakujące kratki z podłogi nad sobą, a gdy tam nie ma
## zwykłej podłogi (wejście / wyjście, brzeg mapy) — spod siebie. Dla tilesetów bez lica 2H (ścieki).

const MIN_HEIGHT := 3


func get_id() -> StringName:
	return &"wall_3h"


func apply(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	var to_wall: Dictionary = {}
	for x in range(ctx.width):
		var y := 0
		while y < ctx.height:
			if int(grid.get(Vector2i(x, y), CellType.WALL)) != CellType.WALL:
				y += 1
				continue
			var y0 := y
			while y < ctx.height and int(grid.get(Vector2i(x, y), CellType.WALL)) == CellType.WALL:
				y += 1
			var run := y - y0  # ściana y0 .. y-1
			if run >= MIN_HEIGHT or y0 == 0 or y >= ctx.height:
				continue
			if not GridUtils.is_walkable(grid, Vector2i(x, y0 - 1)) or not GridUtils.is_walkable(grid, Vector2i(x, y)):
				continue
			var need := MIN_HEIGHT - run
			# Najpierw w górę (pokój nad ścianą traci rząd), potem w dół — tylko zwykła podłoga.
			var up := 0
			while up < need and _plain_floor(grid, Vector2i(x, y0 - 1 - up)):
				up += 1
			var down := 0
			while up + down < need and _plain_floor(grid, Vector2i(x, y + down)):
				down += 1
			if up + down < need:
				continue
			for i in up:
				to_wall[Vector2i(x, y0 - 1 - i)] = true
			for i in down:
				to_wall[Vector2i(x, y + i)] = true
	for p in to_wall:
		grid[p] = CellType.WALL
	return to_wall.size()


static func _plain_floor(grid: Dictionary, p: Vector2i) -> bool:
	return int(grid.get(p, CellType.WALL)) == CellType.FLOOR
