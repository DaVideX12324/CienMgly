extends "grid_pass.gd"

## Wypustki ściany (tilesety bez lica 2H — ścieki): odcinek ściany grubości 1 kratki wysunięty z lica / boku
## ściany w stronę podłogi (za nim masa ściany, po obu końcach ściana cofa się o kratkę) zamienia się w
## podłogę. Kafle ścieków nie mają na to narożników (lico szerokie na 1 / uskok lica o 1). Zagłębienia
## (podłoga wcięta w ścianę) zostają. Tylko ściana -> podłoga: spójność może jedynie wzrosnąć.

const DIRS := {"S": Vector2i(0, 1), "N": Vector2i(0, -1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}


func get_id() -> StringName:
	return &"wall_protrusion"


func apply(ctx: GenerationContext) -> int:
	var grid := ctx.grid
	var carve := {}
	for dn in DIRS:
		var d: Vector2i = DIRS[dn]
		var along := Vector2i(absi(d.y), absi(d.x))
		var seen := {}
		for y in range(2, ctx.height - 2):
			for x in range(2, ctx.width - 2):
				var p := Vector2i(x, y)
				if seen.has(p) or not _wall(grid, p) or _wall(grid, p + d) or not _wall(grid, p - d):
					continue
				var a := p
				while _edge(grid, a - along, d):
					a -= along
				var b := p
				while _edge(grid, b + along, d):
					b += along
				var cells: Array[Vector2i] = []
				var c := a
				while true:
					seen[c] = true
					cells.append(c)
					if c == b:
						break
					c += along
				var ea := a - along
				var eb := b + along
				if not _wall(grid, ea) and _wall(grid, ea - d) and not _wall(grid, eb) and _wall(grid, eb - d):
					for q in cells:
						carve[q] = true
	for q in carve:
		grid[q] = CellType.FLOOR
	return carve.size()


func _wall(grid: Dictionary, p: Vector2i) -> bool:
	return not GridUtils.is_walkable(grid, p)


## Kratka krawędzi wypustki: ściana, przed nią podłoga, za nią ściana.
func _edge(grid: Dictionary, p: Vector2i, d: Vector2i) -> bool:
	return _wall(grid, p) and not _wall(grid, p + d) and _wall(grid, p - d)
