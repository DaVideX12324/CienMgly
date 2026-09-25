class_name NavOutlines
extends RefCounted

## Siatka nawigacji z wyniku generacji (zamiast prostokąta mapy, przez który agent prowadził w ściany).
## Obszar chodliwy = podłoga bez barier płaskowyżów (rimy, boki, lico i jego stopa) i bez kratek
## przeszkód z kolizją (ObjectPlan.SOLID). Krawędzie między kratką chodliwą a niechodliwą łączone
## w pętle: obrysy (obszar w środku) -> traversable, dziury (filary, przeszkody) -> obstruction;
## NavigationServer2D wypieka z tego NavigationPolygon z promieniem agenta.
##
## Kierunek krawędzi: obszar chodliwy po lewej przy patrzeniu wzdłuż krawędzi (współrzędne ekranu,
## y w dół) — obrys ma pole ujemne (shoelace), dziura dodatnie. Styk dwóch kratek tylko rogiem:
## w wierzchołku skręt w lewo względem kierunku dojścia, więc pętle się nie sklejają.

const CELL := 16.0


## Maska chodliwa (W×H, 1 = agent może tu stać).
static func walkable_mask(result) -> PackedByteArray:
	var w: int = result.width
	var h: int = result.height
	var m := PackedByteArray()
	m.resize(w * h)
	for y in range(h):
		for x in range(w):
			if GridUtils.is_walkable(result.grid, Vector2i(x, y)):
				m[y * w + x] = 1
	var pl = result.plateau
	if pl != null and not pl.is_empty():
		for c in pl.blocked:
			if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
				m[c.y * w + c.x] = 0
	var objs = result.objects
	if objs != null:
		for i in range(objs.occupancy.size()):
			if objs.occupancy[i] & ObjectPlan.SOLID:
				m[i] = 0
	return m


## Pętle krawędzi maski w kratkach (Vector2 wierzchołków siatki), bez punktów współliniowych.
static func trace(mask: PackedByteArray, w: int, h: int) -> Array[PackedVector2Array]:
	var vw := w + 1
	var out_edges := {}   # wierzchołek -> Array[int] wierzchołków końcowych
	var add := func(ax: int, ay: int, bx: int, by: int) -> void:
		var a := ay * vw + ax
		if not out_edges.has(a):
			out_edges[a] = []
		(out_edges[a] as Array).append(by * vw + bx)
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 0:
				continue
			if y == 0 or mask[(y - 1) * w + x] == 0:
				add.call(x + 1, y, x, y)          # góra: w lewo
			if y == h - 1 or mask[(y + 1) * w + x] == 0:
				add.call(x, y + 1, x + 1, y + 1)  # dół: w prawo
			if x == 0 or mask[y * w + x - 1] == 0:
				add.call(x, y, x, y + 1)          # lewo: w dół
			if x == w - 1 or mask[y * w + x + 1] == 0:
				add.call(x + 1, y + 1, x + 1, y)  # prawo: w górę
	var loops: Array[PackedVector2Array] = []
	var starts := out_edges.keys()
	starts.sort()
	for s in starts:
		while not (out_edges[s] as Array).is_empty():
			var pts := PackedVector2Array()
			var cur: int = s
			var nxt: int = (out_edges[s] as Array).pop_back()
			var guard := 0
			while true:
				pts.append(Vector2(cur % vw, cur / vw))
				var d := Vector2i(nxt % vw - cur % vw, nxt / vw - cur / vw)
				cur = nxt
				if cur == s:
					break
				var cand: Array = out_edges.get(cur, [])
				if cand.is_empty():
					break
				var pick := 0
				if cand.size() > 1:
					# skręt w lewo względem kierunku dojścia (ekran, y w dół): (dx, dy) -> (dy, -dx)
					var want := Vector2i(d.y, -d.x)
					for k in range(cand.size()):
						var e: int = cand[k]
						if Vector2i(e % vw - cur % vw, e / vw - cur / vw) == want:
							pick = k
							break
				nxt = cand[pick]
				cand.remove_at(pick)
				guard += 1
				if guard > w * h * 4:
					break
			loops.append(_simplify(pts))
	return loops


## Usuwa wierzchołki leżące na prostej między sąsiadami.
static func _simplify(pts: PackedVector2Array) -> PackedVector2Array:
	var n := pts.size()
	if n < 4:
		return pts
	var out := PackedVector2Array()
	for i in range(n):
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		if (b - a).cross(c - b) != 0.0:
			out.append(b)
	return out


static func signed_area(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


## Wypieczony NavigationPolygon dla wyniku generacji (czyste dane — można w wątku roboczym).
static func build_polygon(result, agent_radius: float = 6.0) -> NavigationPolygon:
	var mask := walkable_mask(result)
	var loops := trace(mask, result.width, result.height)
	var geo := NavigationMeshSourceGeometryData2D.new()
	for loop in loops:
		var px := PackedVector2Array()
		for p in loop:
			px.append(p * CELL)
		if signed_area(loop) < 0.0:
			geo.add_traversable_outline(px)
		else:
			geo.add_obstruction_outline(px)
	var np := NavigationPolygon.new()
	np.agent_radius = agent_radius
	NavigationServer2D.bake_from_source_geometry_data(np, geo)
	return np
