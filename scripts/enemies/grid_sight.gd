class_name GridSight
extends RefCounted

## Widoczność po siatce mapy (zamiast promienia fizyki): linia z punktu A do B przechodzi przez
## kolejne kratki (Amanatides–Woo, każda kratka, przez którą linia faktycznie przechodzi);
## niechodliwa kratka zasłania. Na dokładnym narożniku (przejście po skosie) zasłaniają dwie ściany
## stykające się rogiem (obie kratki po bokach) — między nimi nie da się zajrzeć; róg jednej ściany nie.
## Kolizje ścian w TileSecie są tylko na krawędziach (lita skała ich nie ma), więc promień fizyki
## przeciekał przez skałę — siatka jest pełna z definicji.

const CELL := 16.0


## Czy z punktu `a` widać punkt `b` (px, świat) na siatce `grid` (Vector2i -> CellType).
static func has_line(grid: Dictionary, a: Vector2, b: Vector2, cell: float = CELL) -> bool:
	var ca := Vector2i(floori(a.x / cell), floori(a.y / cell))
	var cb := Vector2i(floori(b.x / cell), floori(b.y / cell))
	if not GridUtils.is_walkable(grid, ca) or not GridUtils.is_walkable(grid, cb):
		return false
	if ca == cb:
		return true
	var d := b - a
	var step := Vector2i(int(signf(d.x)), int(signf(d.y)))
	var t_delta := Vector2(INF if d.x == 0.0 else absf(cell / d.x), INF if d.y == 0.0 else absf(cell / d.y))
	var next_x := (ca.x + (1 if step.x > 0 else 0)) * cell
	var next_y := (ca.y + (1 if step.y > 0 else 0)) * cell
	var t_max := Vector2(INF if d.x == 0.0 else (next_x - a.x) / d.x, INF if d.y == 0.0 else (next_y - a.y) / d.y)
	var c := ca
	# Przejście odwiedza najwyżej |dx| + |dy| kolejnych kratek.
	for _i in range(absi(cb.x - ca.x) + absi(cb.y - ca.y)):
		if absf(t_max.x - t_max.y) < 1e-9:
			# Dokładnie przez narożnik: szczelina między dwiema ścianami stykającymi się rogiem zasłania.
			if not GridUtils.is_walkable(grid, c + Vector2i(step.x, 0)) and not GridUtils.is_walkable(grid, c + Vector2i(0, step.y)):
				return false
			c += step
			t_max += t_delta
		elif t_max.x < t_max.y:
			c.x += step.x
			t_max.x += t_delta.x
		else:
			c.y += step.y
			t_max.y += t_delta.y
		if not GridUtils.is_walkable(grid, c):
			return false
		if c == cb:
			return true
	return c == cb


## Siatka mapy dla węzła: pierwszy przodek z `last_result` (ProceduralLevel) — {} gdy brak.
static func grid_for(node: Node) -> Dictionary:
	var n := node
	while n != null:
		if "last_result" in n:
			var r = n.get("last_result")
			if r != null and "grid" in r:
				return r.grid
		n = n.get_parent()
	return {}
