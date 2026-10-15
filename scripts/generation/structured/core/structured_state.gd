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
var chambers: Array = []              # komnaty za ścianami działowymi kompleksów: PackedInt32Array kratek

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
	var i := 0
	var o := W1 + 1
	for y in range(h):
		var run := 0
		for x in range(w):
			run += m[i]
			p[o] = p[o - W1] + run
			i += 1
			o += 1
		o += 1
	return p


## Liczba kratek w prostokącie (włącznie, przycinany do mapy) z sum prefiksowych `p`.
func box(p: PackedInt32Array, x0: int, y0: int, x1: int, y1: int) -> int:
	x0 = maxi(0, x0); y0 = maxi(0, y0); x1 = mini(w - 1, x1); y1 = mini(h - 1, y1)
	if x0 > x1 or y0 > y1:
		return 0
	var W1 := w + 1
	return p[(y1 + 1) * W1 + x1 + 1] - p[y0 * W1 + x1 + 1] - p[(y1 + 1) * W1 + x0] + p[y0 * W1 + x0]


## Dylatacja prostokątem (2rx + 1) × (2ry + 1): 1 tam, gdzie w oknie (przyciętym do mapy) jest niezerowa
## kratka. Bez sum na kratkę — przesunięcia całej maski (slice w silniku) i OR po 8 kratek naraz
## (_or_window); okno wierszy liczone na płaskiej tablicy, więc kolumny przy brzegach (rx od krawędzi),
## które złapały kratki sąsiedniego wiersza, liczone osobno wprost.
func dilate(m: PackedByteArray, rx: int, ry: int) -> PackedByteArray:
	if rx == 0 and ry == 0:
		return m.duplicate()
	var n := w * h
	var src := m
	if m.count(0) + m.count(1) != n:   # wartości > 1 (np. bity osi) -> 0/1
		src = new_mask()
		for i in range(n):
			if m[i]:
				src[i] = 1
	var out := src
	if rx > 0:
		out = _or_window(src, rx, 1)
		# Brzegi wierszy: okno nie wychodzi poza wiersz.
		var e := mini(rx, w)
		for y in range(h):
			var row := y * w
			for x in range(e):
				out[row + x] = 1 if _row_any(src, row, 0, mini(w - 1, x + rx)) else 0
			for x in range(maxi(e, w - rx), w):
				out[row + x] = 1 if _row_any(src, row, maxi(0, x - rx), w - 1) else 0
	if ry > 0:
		out = _or_window(out, ry, w)
	return out


## OR okna [-r, r] kroków `step` bajtów (1 = w wierszu, w = w kolumnie) na płaskiej masce 0/1; poza tablicą 0.
## Okno 2r + 1 z podwajania (okna 1, 2, 4, …) — log2 przebiegów OR zamiast 2r.
func _or_window(m: PackedByteArray, r: int, step: int) -> PackedByteArray:
	var L := 2 * r + 1
	# win[i] = OR m[i - r .. i - r + (p - 1)] (kroki `step`): maska z r * step zerami z przodu (bez obcinania
	# końca — okno kratek przy końcu sięga za nią), wynik = pierwsze n bajtów.
	var win := PackedByteArray()
	win.resize(r * step)
	win.append_array(m)
	var p := 1
	while p * 2 <= L:
		win = _or_bytes(win, _shift(win, p * step))
		p *= 2
	if p < L:
		win = _or_bytes(win, _shift(win, (L - p) * step))
	return win.slice(0, m.size())


## out[i] = m[i + k] (poza tablicą 0).
static func _shift(m: PackedByteArray, k: int) -> PackedByteArray:
	var n := m.size()
	if k == 0:
		return m
	var z := PackedByteArray()
	z.resize(mini(absi(k), n))
	if k > 0:
		var out := m.slice(mini(k, n))
		out.append_array(z)
		return out
	var out2 := z
	out2.append_array(m.slice(0, maxi(0, n + k)))
	return out2


func _row_any(m: PackedByteArray, row: int, x0: int, x1: int) -> bool:
	for x in range(x0, x1 + 1):
		if m[row + x]:
			return true
	return false


## Maska jako int64 po 8 bajtów (dopełniona zerami).
static func _q(m: PackedByteArray) -> PackedInt64Array:
	var pad := (8 - m.size() % 8) % 8
	if pad == 0:
		return m.to_int64_array()
	var b := m.duplicate()
	b.resize(m.size() + pad)
	return b.to_int64_array()


static func _unq(q: PackedInt64Array, n: int) -> PackedByteArray:
	var b := q.to_byte_array()
	b.resize(n)
	return b


static func _or_bytes(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var qa := _q(a)
	var qb := _q(b)
	for i in range(qa.size()):
		qa[i] |= qb[i]
	return _unq(qa, a.size())


func m_and(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var qa := _q(a)
	var qb := _q(b)
	for i in range(qa.size()):
		qa[i] &= qb[i]
	return _unq(qa, w * h)


func m_or(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	return _or_bytes(a, b)


## a i nie b; `a` to maska 0/1 (wynik jak a & (1 - b) na kratkę).
func m_andnot(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	const ONES := 0x0101010101010101
	var qa := _q(a)
	var qb := _q(b)
	for i in range(qa.size()):
		qa[i] &= ~qb[i] & ONES
	return _unq(qa, w * h)


func m_any(a: PackedByteArray) -> bool:
	return a.has(1)


## Odległość Manhattana do najbliższej kratki maski (dwa przebiegi); brak maski = duża liczba.
func distance_to(m: PackedByteArray) -> PackedInt32Array:
	const BIG := 1 << 20
	var n := w * h
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(BIG)
	var i := m.find(1)
	while i >= 0:
		d[i] = 0
		i = m.find(1, i + 1)
	if m.count(0) + m.count(1) != n:   # wartości > 1 — rzadkie, wprost
		for j in range(n):
			if m[j]:
				d[j] = 0
	# Przebieg w przód: min(sam, lewy + 1, górny + 1); `left` = już poprawiony lewy sąsiad.
	i = 0
	for y in range(h):
		var left := BIG
		if y == 0:
			for x in range(w):
				var v := d[i]
				if left + 1 < v: v = left + 1
				d[i] = v
				left = v
				i += 1
		else:
			for x in range(w):
				var v := d[i]
				var u := d[i - w] + 1
				if u < v: v = u
				if left + 1 < v: v = left + 1
				d[i] = v
				left = v
				i += 1
	# Przebieg wstecz: min(sam, prawy + 1, dolny + 1).
	i = n - 1
	for y in range(h - 1, -1, -1):
		var right := BIG
		if y == h - 1:
			for x in range(w):
				var v := d[i]
				if right + 1 < v: v = right + 1
				d[i] = v
				right = v
				i -= 1
		else:
			for x in range(w):
				var v := d[i]
				var u := d[i + w] + 1
				if u < v: v = u
				if right + 1 < v: v = right + 1
				d[i] = v
				right = v
				i -= 1
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


## Suma `all` bez `sub` (kratki sub ⊆ all, np. wszystkie pokoje bez jednego) — bez sum osobno dla każdego wariantu.
class DiffSum extends LocalSum:
	var all: LocalSum
	var sub: LocalSum

	func _init(a: LocalSum, b: LocalSum) -> void:
		all = a
		sub = b
		empty = false

	func count(ax0: int, ay0: int, ax1: int, ay1: int) -> int:
		return all.count(ax0, ay0, ax1, ay1) - sub.count(ax0, ay0, ax1, ay1)
