class_name NavOutlines
extends RefCounted

## Siatka nawigacji z wyniku generacji (zamiast prostokąta mapy, przez który agent prowadził w ściany).
## Obszar chodliwy = podłoga bez barier płaskowyżów (rimy, boki, lico i jego stopa). Krawędzie między
## kratką chodliwą a niechodliwą łączone w pętle: obrysy (obszar w środku) -> traversable, dziury
## (filary) -> obstruction. Przeszkody z generatora obiektów -> obstruction z DOKŁADNYCH kształtów
## kolizji (te same, co ObjectRealizer wkłada do fizyki) — wycinanie całych kratek zostawiało
## wystające kawałki kształtów na ścieżce i wróg się o nie zaczepiał. NavigationServer2D wypieka z tego
## NavigationPolygon z promieniem agenta.
##
## Kierunek krawędzi: obszar chodliwy po lewej przy patrzeniu wzdłuż krawędzi (współrzędne ekranu,
## y w dół) — obrys ma pole ujemne (shoelace), dziura dodatnie. Styk dwóch kratek tylko rogiem:
## w wierzchołku skręt w lewo względem kierunku dojścia, więc pętle się nie sklejają.

const CELL := 16.0
## Promień agenta = połowa szerokości kolizji wroga (prostokąt 14×8): ścieżka zostawia miejsce na ciało
## (przy 6 wróg ocierał się o przeszkodę tuż przy ścieżce i utykał), a przejścia szerokie na kratkę
## (16 px) zostają otwarte (przy 8 siatka się w nich rwała).
const AGENT_RADIUS := 7.0


## Maska chodliwa (W×H, 1 = podłoga poza barierami płaskowyżów). `with_obstacles`: także bez kratek
## przeszkód z kolizją (ObjectPlan.SOLID) — do testów; siatka używa dokładnych kształtów.
static func walkable_mask(result, with_obstacles: bool = false) -> PackedByteArray:
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
	if with_obstacles and objs != null:
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
static func build_polygon(result, agent_radius: float = AGENT_RADIUS) -> NavigationPolygon:
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
	if result.objects != null:
		for poly in obstacle_outlines(result.objects):
			# Jeden kierunek obiegu: odbity obiekt (skala x = -1) odwraca kolejność punktów, a nakładające
			# się przeszkody o przeciwnym obiegu dawały przy łączeniu dziurę w przeszkodzie.
			if signed_area(poly) < 0.0:
				poly.reverse()
			geo.add_obstruction_outline(poly)
	var np := NavigationPolygon.new()
	np.agent_radius = agent_radius
	NavigationServer2D.bake_from_source_geometry_data(np, geo)
	return np


## Obrysy kształtów kolizji przeszkód (świat, px): wypieczone sceny — ich kształty w transformacji
## originu obiektu (z odbiciem, jak ObjectRealizer); kształt z JSON-a — prostokąt / koło przy punkcie;
## scena niewypiekana (skrzynia itp.) — kratki, które zajmuje.
static func obstacle_outlines(plan: ObjectPlan) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for pl in plan.placements:
		var def := pl.def
		if not def.is_solid():
			continue
		if not def.bakes.is_empty() and def.bakes[pl.variant].static_ok:
			var b: ObjectBake = def.bakes[pl.variant]
			var oxf := Transform2D(0.0, Vector2(-1.0 if pl.flip else 1.0, 1.0), 0.0, pl.origin())
			for sh in b.shapes:
				var poly := shape_polygon(sh["shape"])
				if not poly.is_empty():
					out.append((oxf * (sh["xform"] as Transform2D)) * poly)
		elif def.klass != ObjectDef.Klass.INTERACTIVE and def.bakes.is_empty():
			var ctr := pl.point() + def.shape_offset
			if def.shape_radius > 0.0:
				out.append(_circle(ctr, def.shape_radius))
			else:
				var hs := def.shape_rect * 0.5
				out.append(PackedVector2Array([ctr + Vector2(-hs.x, -hs.y), ctr + Vector2(hs.x, -hs.y), ctr + Vector2(hs.x, hs.y), ctr + Vector2(-hs.x, hs.y)]))
		else:
			for j in pl.cells:
				var c := Vector2(j % plan.width, j / plan.width) * CELL
				out.append(PackedVector2Array([c, c + Vector2(CELL, 0), c + Vector2(CELL, CELL), c + Vector2(0, CELL)]))
	return out


## Wielokąt kształtu kolizji (lokalnie); koło i kapsuła jako wielokąt opisany.
static func shape_polygon(shape: Shape2D) -> PackedVector2Array:
	if shape is ConvexPolygonShape2D:
		return (shape as ConvexPolygonShape2D).points
	if shape is RectangleShape2D:
		var hs := (shape as RectangleShape2D).size * 0.5
		return PackedVector2Array([Vector2(-hs.x, -hs.y), Vector2(hs.x, -hs.y), Vector2(hs.x, hs.y), Vector2(-hs.x, hs.y)])
	if shape is CircleShape2D:
		return _circle(Vector2.ZERO, (shape as CircleShape2D).radius)
	var r := shape.get_rect()
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _circle(ctr: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr := radius / cos(PI / 8.0)   # ośmiokąt opisany na kole
	for k in range(8):
		pts.append(ctr + Vector2.from_angle(TAU * k / 8.0) * rr)
	return pts
