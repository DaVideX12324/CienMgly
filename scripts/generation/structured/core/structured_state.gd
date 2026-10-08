extends RefCounted

## Stan generatora układu structured (wzorzec: docs/prototypy/structured_layout/proto_layout.py, v11).
## Maski W × H jako PackedByteArray (indeks y * w + x, 1 = tak), prostokąty włącznie (x0, y0, x1, y1)
## jak w prototypie. Parametry z sekcji "structured_layout" konfiguracji mapy.

var w := 0
var h := 0
var margin := 3        # M: ramka mapy bez podłogi
var top_extra := 1     # górna ramka grubsza (lico na ścianie: kap + 3 rzędy nad podłogą)
var cw := 4            # szerokość kanału
var lane := 3          # chodnik tunelu
var wall_h := 5        # ściana z podłogą nad i pod (lico 3H + grzbiet)
var wall_v := 2        # ściana boczna (też najcieńsza ściana wielokąta)
var clear := 16        # odstęp kanałów (krawędź – krawędź)

var floor_m := PackedByteArray()
var water := PackedByteArray()
var dry := PackedByteArray()
var lanes := PackedByteArray()
var service := PackedByteArray()
var hallm := PackedByteArray()
var roomm := PackedByteArray()
var corrm := PackedByteArray()
var bridge_m := PackedByteArray()
var hall_cid := PackedInt32Array()   # -1 = nie hala

## Odcinki sieci: {x0, y0, x1, y1, axis ("h" / "v"), line, idx, dry, kind ("tunnel" / "hall"), cid,
## junction, bridge_t}.
var segs: Array[Dictionary] = []
var lines: Dictionary = {}           # line -> Array[Dictionary] (odcinki w kolejności)
## Kompleksy: cid -> {segs, cells (PackedInt32Array indeksów), pinch ({seg, k, p0, p1} albo {}), bbox}.
var complexes: Dictionary = {}
var halls: Array[Vector4i] = []      # bbox kompleksów (x0, y0, x1, y1)
var rooms: Array[Vector4i] = []      # pokoje (x0, y0, x1, y1)
## Kładki: {cells: Array[Vector2i] (kratki wody pod kładką), vertical: bool (przez kanał poziomy), crossing}.
var bridges: Array[Dictionary] = []
var lane_chains: Array[Dictionary] = []
var water_axis := PackedByteArray()   # kratka wody: 1 = odcinek poziomy, 2 = pionowy, 3 = oba (blok węzła / zakrętu)   # odcinki zastępcze łańcuchów (chodniki, przerwy chodnika)
var gates: Array = []                # [Vector2i × 3]
var levers: Array[Vector2i] = []

# Strefy przecięć (po strefowaniu): kanał poziomy przechodzi się tylko pionowo, pionowy tylko poziomo.
var cross_h := PackedByteArray()
var cross_v := PackedByteArray()
var cross_any := PackedByteArray()
var zh := PackedByteArray()          # dilate(cross_h, wall_v + 2, wall_h + 2)
var zv := PackedByteArray()
var jz_c := PackedByteArray()        # środki korytarza nie na wodzie przy zakręcie / węźle
var jz := PackedByteArray()          # strefa zakrętów / węzłów (kładki tu nie stają)
## Liczba kratek (podłoga, poza strefami przecięć) w oknie (wall_v + 2, wall_h + 2) — zakaz środka korytarza
## przy obcej podłodze; aktualizowana przy każdym dodaniu podłogi (add_floor).
var fcnt := PackedInt32Array()
var fcnt_ready := false


func setup(width: int, height: int, cfg: Dictionary) -> void:
	w = width
	h = height
	cw = int(cfg.get("linear_width", cw))
	clear = int(cfg.get("linear_clear_margin", clear))
	lane = int(cfg.get("lane_width", lane))
	wall_h = int(cfg.get("wall_thickness_h", wall_h))
	wall_v = int(cfg.get("wall_thickness_v", wall_v))
	top_extra = int(cfg.get("frame_top_extra", top_extra))
	floor_m = new_mask(); water = new_mask(); dry = new_mask(); lanes = new_mask(); service = new_mask()
	hallm = new_mask(); roomm = new_mask(); corrm = new_mask(); bridge_m = new_mask()
	hall_cid = PackedInt32Array()
	hall_cid.resize(w * h)
	hall_cid.fill(-1)


func new_mask() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(w * h)
	return m


func idx(x: int, y: int) -> int:
	return y * w + x


func in_map(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


## Prostokąt (włącznie) na masce, przycięty do mapy.
func fill(m: PackedByteArray, x0: int, y0: int, x1: int, y1: int, v := 1) -> void:
	for y in range(maxi(0, y0), mini(h - 1, y1) + 1):
		var row := y * w
		for x in range(maxi(0, x0), mini(w - 1, x1) + 1):
			m[row + x] = v


## Czy w prostokącie jest kratka maski — poza mapą też true (jak any_in prototypu).
func any_in(m: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> bool:
	if x0 < 0 or y0 < 0 or x1 >= w or y1 >= h:
		return true
	for y in range(y0, y1 + 1):
		var row := y * w
		for x in range(x0, x1 + 1):
			if m[row + x]:
				return true
	return false


func inside(x0: int, y0: int, x1: int, y1: int, mm := -1) -> bool:
	var k := margin if mm < 0 else mm
	return x0 >= k and y0 >= k + top_extra and x1 < w - k and y1 < h - k


## Sumy prefiksowe maski: P[(y + 1) * (w + 1) + x + 1] = liczba kratek w [0..x] × [0..y].
func prefix(m: PackedByteArray) -> PackedInt32Array:
	var W1 := w + 1
	var p := PackedInt32Array()
	p.resize(W1 * (h + 1))
	for y in range(h):
		var run := 0
		var row := y * w
		var o := (y + 1) * W1
		var o0 := y * W1
		for x in range(w):
			run += m[row + x]
			p[o + x + 1] = p[o0 + x + 1] + run
	return p


## Liczba kratek w prostokącie (włącznie, przycinany do mapy) z sum prefiksowych `p`.
func box(p: PackedInt32Array, x0: int, y0: int, x1: int, y1: int) -> int:
	x0 = maxi(0, x0); y0 = maxi(0, y0); x1 = mini(w - 1, x1); y1 = mini(h - 1, y1)
	if x0 > x1 or y0 > y1:
		return 0
	var W1 := w + 1
	return p[(y1 + 1) * W1 + x1 + 1] - p[y0 * W1 + x1 + 1] - p[(y1 + 1) * W1 + x0] + p[y0 * W1 + x0]


## Dylatacja prostokątem (2rx + 1) × (2ry + 1).
func dilate(m: PackedByteArray, rx: int, ry: int) -> PackedByteArray:
	if rx == 0 and ry == 0:
		return m.duplicate()
	var p := prefix(m)
	var out := new_mask()
	for y in range(h):
		var row := y * w
		for x in range(w):
			if box(p, x - rx, y - ry, x + rx, y + ry) > 0:
				out[row + x] = 1
	return out


func m_and(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out := new_mask()
	for i in range(w * h):
		out[i] = a[i] & b[i]
	return out


func m_or(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out := new_mask()
	for i in range(w * h):
		out[i] = a[i] | b[i]
	return out


func m_andnot(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out := new_mask()
	for i in range(w * h):
		out[i] = a[i] & (1 - b[i])
	return out


func m_any(a: PackedByteArray) -> bool:
	return a.has(1)


## Odległość Manhattana do najbliższej kratki maski (dwa przebiegi); brak maski = duża liczba.
func distance_to(m: PackedByteArray) -> PackedInt32Array:
	const BIG := 1 << 20
	var d := PackedInt32Array()
	d.resize(w * h)
	for i in range(w * h):
		d[i] = 0 if m[i] else BIG
	for y in range(h):
		for x in range(w):
			var i := y * w + x
			var v := d[i]
			if x > 0 and d[i - 1] + 1 < v: v = d[i - 1] + 1
			if y > 0 and d[i - w] + 1 < v: v = d[i - w] + 1
			d[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := d[i]
			if x < w - 1 and d[i + 1] + 1 < v: v = d[i + 1] + 1
			if y < h - 1 and d[i + w] + 1 < v: v = d[i + w] + 1
			d[i] = v
	return d


## Oś kanału na kratkach wody (z prostokątów odcinków) — ścieżki korytarzy przechodzą przez wodę tylko w poprzek.
func build_water_axis() -> void:
	water_axis = new_mask()
	for s in segs:
		var bit: int = 1 if s.axis == "h" else 2
		for y in range(maxi(0, s.y0), mini(h - 1, s.y1) + 1):
			for x in range(maxi(0, s.x0), mini(w - 1, s.x1) + 1):
				water_axis[y * w + x] |= bit


# --- Zakaz obcej podłogi (fcnt) ---

## Licznik fcnt od zera z bieżącej podłogi (po strefowaniu).
func build_fcnt() -> void:
	var base := new_mask()
	for i in range(w * h):
		base[i] = floor_m[i] & (1 - cross_any[i])
	var p := prefix(base)
	var rx := wall_v + 2
	var ry := wall_h + 2
	fcnt = PackedInt32Array()
	fcnt.resize(w * h)
	for y in range(h):
		for x in range(w):
			fcnt[y * w + x] = box(p, x - rx, y - ry, x + rx, y + ry)
	fcnt_ready = true


## Nowa kratka podłogi (aktualizuje fcnt).
func add_floor(x: int, y: int) -> void:
	var i := y * w + x
	if floor_m[i]:
		return
	floor_m[i] = 1
	if not fcnt_ready or cross_any[i]:
		return
	var rx := wall_v + 2
	var ry := wall_h + 2
	for yy in range(maxi(0, y - ry), mini(h - 1, y + ry) + 1):
		for xx in range(maxi(0, x - rx), mini(w - 1, x + rx) + 1):
			fcnt[yy * w + xx] += 1


## Cofnięcie kratki podłogi (aktualizuje fcnt).
func remove_floor(x: int, y: int) -> void:
	var i := y * w + x
	if not floor_m[i]:
		return
	floor_m[i] = 0
	if not fcnt_ready or cross_any[i]:
		return
	var rx := wall_v + 2
	var ry := wall_h + 2
	for yy in range(maxi(0, y - ry), mini(h - 1, y + ry) + 1):
		for xx in range(maxi(0, x - rx), mini(w - 1, x + rx) + 1):
			fcnt[yy * w + xx] -= 1


## Prostokąt podłogi (np. pokój) z aktualizacją fcnt.
func add_floor_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(0, y0), mini(h - 1, y1) + 1):
		for x in range(maxi(0, x0), mini(w - 1, x1) + 1):
			add_floor(x, y)


## Sumy kratek maski w ograniczonym prostokącie (bbox + zapas) — szybkie zapytania o okno i kratkę dla
## małych masek (pokój, część kompleksu) bez sum na całej mapie.
class LocalSum:
	var x0 := 0
	var y0 := 0
	var lw := 0
	var lh := 0
	var p := PackedInt32Array()
	var empty := true

	## Z listy indeksów kratek mapy o szerokości `mw`.
	static func from_cells(cells: PackedInt32Array, mw: int) -> LocalSum:
		var s := LocalSum.new()
		if cells.is_empty():
			return s
		var minx := 1 << 30
		var miny := 1 << 30
		var maxx := -1
		var maxy := -1
		for c in cells:
			var x := c % mw
			var y := c / mw
			minx = mini(minx, x); miny = mini(miny, y); maxx = maxi(maxx, x); maxy = maxi(maxy, y)
		s.x0 = minx
		s.y0 = miny
		s.lw = maxx - minx + 1
		s.lh = maxy - miny + 1
		var grid := PackedByteArray()
		grid.resize(s.lw * s.lh)
		for c in cells:
			grid[(c / mw - miny) * s.lw + (c % mw - minx)] = 1
		var W1 := s.lw + 1
		s.p.resize(W1 * (s.lh + 1))
		for y in range(s.lh):
			var run := 0
			for x in range(s.lw):
				run += grid[y * s.lw + x]
				s.p[(y + 1) * W1 + x + 1] = s.p[y * W1 + x + 1] + run
		s.empty = false
		return s

	## Z maski całej mapy.
	static func from_mask(m: PackedByteArray, mw: int) -> LocalSum:
		var cells := PackedInt32Array()
		for i in range(m.size()):
			if m[i]:
				cells.append(i)
		return from_cells(cells, mw)

	func count(ax0: int, ay0: int, ax1: int, ay1: int) -> int:
		if empty:
			return 0
		ax0 = maxi(ax0, x0); ay0 = maxi(ay0, y0)
		ax1 = mini(ax1, x0 + lw - 1); ay1 = mini(ay1, y0 + lh - 1)
		if ax0 > ax1 or ay0 > ay1:
			return 0
		var W1 := lw + 1
		var a := ax0 - x0
		var b := ay0 - y0
		var c := ax1 - x0
		var d := ay1 - y0
		return p[(d + 1) * W1 + c + 1] - p[b * W1 + c + 1] - p[(d + 1) * W1 + a] + p[b * W1 + a]

	func has(x: int, y: int) -> bool:
		return count(x, y, x, y) > 0
