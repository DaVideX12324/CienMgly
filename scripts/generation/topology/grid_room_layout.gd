extends RefCounted

## Układ pokoi na siatce (flaga room_layout = "grid"): mapa dzielona na kwadratowe komórki
## (grid_cell_size, 0 = max_room_size + 2 * GRID_PAD + 2), w każdej pokój (szansa grid_room_chance)
## albo węzeł-skrzyżowanie korytarzy. Korytarze tylko między sąsiadami siatki: losowe drzewo
## rozpinające + pętle (grid_loop_chance). Pokoje zachodzące na siebie w osi -> korytarz prosty,
## inaczej L przez carver z flag (corridor_shape). Węzły bez pokoju będące ślepymi końcami są
## przycinane. Zwraca pokoje (bez węzłów) — dalej jak w układzie losowym (portale, spawny).

const StraightCorridorCarverScript = preload("straight_corridor_carver.gd")

## Minimalny odstęp pokoju od brzegu komórki (między pokojami sąsiednich komórek >= 2 * GRID_PAD).
const GRID_PAD := 3
const BORDER := 6


static func carve(ctx: GenerationContext, min_room_size: int, max_room_size: int, corridor_width: int, flags: GenerationFlags) -> Array[Rect2i]:
	var rng := ctx.rng
	var cell := flags.grid_cell_size if flags.grid_cell_size > 0 else max_room_size + 2 * GRID_PAD + 2
	var cols := maxi(1, (ctx.width - 2 * BORDER) / cell)
	var rows := maxi(1, (ctx.height - 2 * BORDER) / cell)
	# Siatka wyśrodkowana na mapie.
	var origin := Vector2i((ctx.width - cols * cell) / 2, (ctx.height - rows * cell) / 2)
	var max_side := maxi(3, mini(max_room_size, cell - 2 * GRID_PAD))
	var min_side := mini(min_room_size, max_side)

	# Węzły: pokój (Rect2i) albo skrzyżowanie (kwadrat corridor_width w środku komórki).
	var node_rect: Array[Rect2i] = []
	var is_room: Array[bool] = []
	for gy in rows:
		for gx in cols:
			var cell_pos := origin + Vector2i(gx * cell, gy * cell)
			if rng.randf() < flags.grid_room_chance:
				var rw := rng.randi_range(min_side, max_side)
				var rh := rng.randi_range(min_side, max_side)
				var rx := cell_pos.x + rng.randi_range(GRID_PAD, cell - GRID_PAD - rw)
				var ry := cell_pos.y + rng.randi_range(GRID_PAD, cell - GRID_PAD - rh)
				node_rect.append(Rect2i(rx, ry, rw, rh))
				is_room.append(true)
			else:
				var c := cell_pos + Vector2i(cell / 2, cell / 2)
				var lo := (corridor_width - 1) / 2
				node_rect.append(Rect2i(c - Vector2i(lo, lo), Vector2i(corridor_width, corridor_width)))
				is_room.append(false)
	# Co najmniej dwa pokoje (wejście i wyjście): brakujące z pierwszych węzłów-skrzyżowań.
	var room_count := is_room.count(true)
	for i in node_rect.size():
		if room_count >= mini(2, node_rect.size()):
			break
		if not is_room[i]:
			var c := node_rect[i].get_center()
			node_rect[i] = Rect2i(c - Vector2i(min_side / 2, min_side / 2), Vector2i(min_side, min_side))
			is_room[i] = true
			room_count += 1

	# Krawędzie między sąsiadami siatki (prawo, dół).
	var edges: Array[Vector2i] = []
	for gy in rows:
		for gx in cols:
			var i := gy * cols + gx
			if gx + 1 < cols:
				edges.append(Vector2i(i, i + 1))
			if gy + 1 < rows:
				edges.append(Vector2i(i, i + cols))
	# Losowe drzewo rozpinające (Kruskal na przetasowanych krawędziach) + pętle.
	_shuffle(edges, rng)
	var parent: Array[int] = []
	for i in node_rect.size():
		parent.append(i)
	var used: Array[Vector2i] = []
	var spare: Array[Vector2i] = []
	for e in edges:
		var ra := _find(parent, e.x)
		var rb := _find(parent, e.y)
		if ra != rb:
			parent[ra] = rb
			used.append(e)
		else:
			spare.append(e)
	for e in spare:
		if rng.randf() < flags.grid_loop_chance:
			used.append(e)

	# Przycinanie ślepych skrzyżowań (węzeł bez pokoju o stopniu <= 1), aż nic się nie zmieni.
	var alive: Array[bool] = []
	alive.resize(node_rect.size())
	alive.fill(true)
	var changed := true
	while changed:
		changed = false
		var degree: Array[int] = []
		degree.resize(node_rect.size())
		degree.fill(0)
		for e in used:
			degree[e.x] += 1
			degree[e.y] += 1
		for i in node_rect.size():
			if alive[i] and not is_room[i] and degree[i] <= 1:
				alive[i] = false
				changed = true
		var kept: Array[Vector2i] = []
		for e in used:
			if alive[e.x] and alive[e.y]:
				kept.append(e)
		used = kept

	# Rzeźbienie: pokoje, skrzyżowania, korytarze.
	var room_carver := RoomCarverFactory.create(StringName(flags.room_shape))
	var rooms: Array[Rect2i] = []
	for i in node_rect.size():
		if not alive[i]:
			continue
		if is_room[i]:
			rooms.append(node_rect[i])
			room_carver.carve(ctx, node_rect[i])
		else:
			StraightCorridorCarverScript._carve_band(ctx, node_rect[i].position, node_rect[i].end - Vector2i.ONE, 1)
	var corridor_carver := CorridorCarverFactory.create(StringName(flags.corridor_shape), flags)
	for e in used:
		_connect(ctx, node_rect[e.x], node_rect[e.y], e.y - e.x == 1, corridor_width, corridor_carver)
	return rooms


## Korytarz między węzłami sąsiednich komórek: prosty, gdy prostokąty zachodzą w osi poprzecznej
## na szerokość korytarza, inaczej carver (L) od środka do środka.
static func _connect(ctx: GenerationContext, a: Rect2i, b: Rect2i, horizontal: bool, w: int, carver: CorridorCarver) -> void:
	var lo := (w - 1) / 2
	var hi := w - 1 - lo
	if horizontal:
		var y0 := maxi(a.position.y, b.position.y) + lo
		var y1 := mini(a.end.y, b.end.y) - 1 - hi
		if y1 >= y0:
			var y := ctx.rng.randi_range(y0, y1)
			var left := a if a.position.x < b.position.x else b
			var right := b if left == a else a
			StraightCorridorCarverScript._carve_band(ctx, Vector2i(left.end.x - 1, y), Vector2i(right.position.x, y), w)
			return
	else:
		var x0 := maxi(a.position.x, b.position.x) + lo
		var x1 := mini(a.end.x, b.end.x) - 1 - hi
		if x1 >= x0:
			var x := ctx.rng.randi_range(x0, x1)
			var top := a if a.position.y < b.position.y else b
			var bottom := b if top == a else a
			StraightCorridorCarverScript._carve_band(ctx, Vector2i(x, top.end.y - 1), Vector2i(x, bottom.position.y), w)
			return
	carver.carve(ctx, a.get_center(), b.get_center(), w)


static func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _shuffle(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := arr[i]
		arr[i] = arr[j]
		arr[j] = t
