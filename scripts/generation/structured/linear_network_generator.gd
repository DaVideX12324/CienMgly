class_name LinearNetworkGenerator
extends RefCounted

## R1 — sieć elementów liniowych (kanałów): wędrowcy ze skrętami + odnogi od dowolnego odcinka
## (plan: docs/plan_generator_sciekow.md, wzorzec proto_layout.py krok 1).
## - odcinki proste segment_length (domyślnie 20–40; krótsze 12–20 / 10, gdy dłuższy się nie mieści), po
##   odcinku skręt (pień 0,35, odnogi 0,6); zablokowany — próba skrętu, inaczej koniec;
## - pień od lewej krawędzi (środkowa 1/3 wysokości), odnogi z dowolnego odcinka (≥ 8 od jego końców,
##   prostopadle), liczba ≈ max(4, W·H / 2300), branch_segments odcinków (domyślnie 3–7), pień trunk_segments;
## - odstęp od innych kanałów ≥ clear poza złączem; kanał nigdy szerszy niż cw (kwadrat (cw+1)² wody = odrzut);
## - mokre / puste koryta rozdzielone szumem (strefa 0 = ścieki, 1 = puste): odcinek w całości w strefie
##   swojego typu, odnoga dziedziczy typ, w odstępie clear brak kratek drugiego typu; gdy pień nie
##   pokrywa obu typów — dodatkowy pień w strefie brakującego typu.

const State = preload("core/structured_state.gd")
const SeededNoise = preload("../core/seeded_noise.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ZONE_BUF := 4

var st: State
var rng: RandomNumberGenerator
var noise: FastNoiseLite
var dry_chance := 0.0
var threshold := 0.0
var seg_len := [20, 40]          # długość odcinka (pierwsza próba)
var trunk_segs := 14
var branch_segs := [3, 7]


static func run(state: State, seed_val: int, canal_dry_chance: float, cfg: Dictionary = {}) -> void:
	var g := LinearNetworkGenerator.new()
	g.st = state
	g.rng = RandomNumberGenerator.new()
	g.rng.seed = hash([seed_val, "structured_network"])
	g.dry_chance = canal_dry_chance
	g.seg_len = cfg.get("segment_length", g.seg_len)
	g.trunk_segs = int(cfg.get("trunk_segments", g.trunk_segs))
	g.branch_segs = cfg.get("branch_segments", g.branch_segs)
	g.noise = SeededNoise.create(hash([seed_val, "canal_zones"]), float(cfg.get("zone_frequency", 0.003)))
	g.noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	g.noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	g.noise.fractal_octaves = 2
	g.threshold = lerpf(0.4, -0.4, clampf(canal_dry_chance, 0.0, 1.0))
	g._generate()


## Strefa kratki: true = puste koryto.
func _zone_dry(x: int, y: int) -> bool:
	if dry_chance <= 0.0:
		return false
	if dry_chance >= 1.0:
		return true
	return noise.get_noise_2d(float(x), float(y)) >= threshold


func _zone_ok(r: Array, is_dry: bool) -> bool:
	if dry_chance <= 0.0 or dry_chance >= 1.0:
		return is_dry == (dry_chance >= 1.0)
	var x0: int = r[0] - ZONE_BUF
	var y0: int = r[1] - ZONE_BUF
	var x1: int = r[2] + ZONE_BUF
	var y1: int = r[3] + ZONE_BUF
	var mx := (x0 + x1) / 2
	var my := (y0 + y1) / 2
	var pts: Array[Vector2i] = [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x0, y1), Vector2i(x1, y1), Vector2i(mx, my)]
	if x1 - x0 > 16:
		pts.append(Vector2i(mx, y0)); pts.append(Vector2i(mx, y1))
	if y1 - y0 > 16:
		pts.append(Vector2i(x0, my)); pts.append(Vector2i(x1, my))
	for p in pts:
		if _zone_dry(p.x, p.y) != is_dry:
			return false
	return true


func _seg_rect(hx: int, hy: int, d: Vector2i, L: int) -> Array:
	var cw: int = st.cw
	if d == Vector2i(1, 0):
		return [hx, hy, hx + L + cw - 1, hy + cw - 1, hx + L, hy]
	if d == Vector2i(-1, 0):
		return [hx - L, hy, hx + cw - 1, hy + cw - 1, hx - L, hy]
	if d == Vector2i(0, 1):
		return [hx, hy, hx + cw - 1, hy + L + cw - 1, hx, hy + L]
	return [hx, hy - L, hx + cw - 1, hy + cw - 1, hx, hy - L]


## Po dodaniu odcinka nigdzie w okolicy nie może powstać kwadrat (cw+1)² samej wody.
func _too_wide(r: Array) -> bool:
	var k: int = st.cw + 1
	var x0 := maxi(0, r[0] - 6)
	var y0 := maxi(0, r[1] - 6)
	var x1 := mini(st.w - 1, r[2] + 6)
	var y1 := mini(st.h - 1, r[3] + 6)
	var sw := x1 - x0 + 1
	var sh := y1 - y0 + 1
	if sw < k or sh < k:
		return false
	var W1 := sw + 1
	var p := PackedInt32Array()
	p.resize(W1 * (sh + 1))
	for y in range(sh):
		var run := 0
		var gy := y0 + y
		for x in range(sw):
			var gx := x0 + x
			var v: int = st.water[gy * st.w + gx]
			if gx >= r[0] and gx <= r[2] and gy >= r[1] and gy <= r[3]:
				v = 1
			run += v
			p[(y + 1) * W1 + x + 1] = p[y * W1 + x + 1] + run
	for y in range(sh - k + 1):
		for x in range(sw - k + 1):
			var s := p[(y + k) * W1 + x + k] - p[y * W1 + x + k] - p[(y + k) * W1 + x] + p[y * W1 + x]
			if s == k * k:
				return true
	return false


## Odstęp ≥ clear od kanałów poza złączem (otoczenie głowy); kratki drugiego typu — nigdzie w odstępie.
func _clear_ok(r: Array, hx: int, hy: int, is_dry: bool) -> bool:
	var c: int = st.clear
	var cw: int = st.cw
	var nx0 := hx - c - cw
	var ny0 := hy - c - cw
	var nx1 := hx + c + 2 * cw
	var ny1 := hy + c + 2 * cw
	for y in range(maxi(0, r[1] - c), mini(st.h - 1, r[3] + c) + 1):
		var row: int = y * st.w
		for x in range(maxi(0, r[0] - c), mini(st.w - 1, r[2] + c) + 1):
			if not st.water[row + x]:
				continue
			if bool(st.dry[row + x]) != is_dry:
				return false
			if x < nx0 or x > nx1 or y < ny0 or y > ny1:
				return false
	return true


func _fits(r: Array, hx: int, hy: int, is_dry: bool) -> bool:
	return st.inside(r[0], r[1], r[2], r[3], st.margin + 1) and _zone_ok(r, is_dry) \
		and _clear_ok(r, hx, hy, is_dry) and not _too_wide(r)


func _walk(hx: int, hy: int, d: Vector2i, line: int, max_segs: int, turn_p: float, is_dry: bool) -> int:
	var idx := 0
	for _s in range(max_segs):
		var placed := false
		for L in [rng.randi_range(int(seg_len[0]), int(seg_len[1])), rng.randi_range(12, 20), 10]:
			var r := _seg_rect(hx, hy, d, L)
			if _fits(r, hx, hy, is_dry):
				var seg := {"x0": r[0], "y0": r[1], "x1": r[2], "y1": r[3], "axis": "h" if d.y == 0 else "v",
					"line": line, "idx": idx, "dry": is_dry, "kind": "tunnel", "cid": -1, "junction": false}
				st.segs.append(seg)
				st.fill(st.water, r[0], r[1], r[2], r[3])
				if is_dry:
					st.fill(st.dry, r[0], r[1], r[2], r[3])
				idx += 1
				hx = r[4]
				hy = r[5]
				placed = true
				break
		if not placed:
			var opts := _perp(d)
			_shuffle(opts)
			var ok := false
			for nd in opts:
				var r := _seg_rect(hx, hy, nd, 12)
				if _fits(r, hx, hy, is_dry):
					d = nd
					ok = true
					break
			if not ok:
				return idx
			continue
		if rng.randf() < turn_p:
			var opts := _perp(d)
			d = opts[rng.randi() % opts.size()]
	return idx


func _perp(d: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for nd in DIRS:
		if nd.x * d.x + nd.y * d.y == 0:
			out.append(nd)
	return out


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _generate() -> void:
	var m: int = st.margin
	# Pień: od lewej krawędzi w prawo, skręca rzadko; typ = strefa w punkcie startu.
	var sy := rng.randi_range(st.h / 3, 2 * st.h / 3)
	_walk(m + 1, sy, Vector2i(1, 0), 0, trunk_segs, 0.35, _zone_dry(m + 1, sy))
	var line := 1
	# Drugi typ bez pnia (strefa szumu) — dodatkowy pień w strefie brakującego typu.
	if dry_chance > 0.0 and dry_chance < 1.0:
		for want_dry in [false, true]:
			if _has_type(want_dry):
				continue
			for _a in range(40):
				var x := rng.randi_range(m + 8, st.w - m - 8)
				var y := rng.randi_range(m + 8, st.h - m - 8)
				if _zone_dry(x, y) != want_dry:
					continue
				var d := DIRS[rng.randi() % 4]
				if _walk(x, y, d, line, trunk_segs, 0.35, want_dry) > 0:
					line += 1
					break
	# Odnogi od dowolnego odcinka (też odnóg), dziedziczą typ.
	var n_branch := maxi(4, st.w * st.h / 2300)
	var attempts := 0
	while line <= n_branch and attempts < 200 and not st.segs.is_empty():
		attempts += 1
		var p: Dictionary = st.segs[rng.randi() % st.segs.size()]
		var hx := 0
		var hy := 0
		var d := Vector2i.ZERO
		if p.axis == "h":
			if p.x1 - p.x0 < 20:
				continue
			hx = rng.randi_range(p.x0 + 8, p.x1 - 8 - st.cw)
			hy = p.y0
			d = Vector2i(0, 1) if rng.randi() % 2 == 0 else Vector2i(0, -1)
		else:
			if p.y1 - p.y0 < 20:
				continue
			hy = rng.randi_range(p.y0 + 8, p.y1 - 8 - st.cw)
			hx = p.x0
			d = Vector2i(1, 0) if rng.randi() % 2 == 0 else Vector2i(-1, 0)
		var before: int = st.segs.size()
		_walk(hx, hy, d, line, rng.randi_range(int(branch_segs[0]), int(branch_segs[1])), 0.6, bool(p.dry))
		if st.segs.size() > before:
			p.junction = true
			st.segs[before].junction = true
			line += 1
	st.lines.clear()
	for s in st.segs:
		if not st.lines.has(s.line):
			st.lines[s.line] = []
		st.lines[s.line].append(s)


func _has_type(want_dry: bool) -> bool:
	for s in st.segs:
		if bool(s.dry) == want_dry:
			return true
	return false
