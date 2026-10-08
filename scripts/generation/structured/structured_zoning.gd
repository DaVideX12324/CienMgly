class_name StructuredZoning
extends RefCounted

## R2 / R3 — odcinki: tunel (chodniki o zmiennej szerokości, też 0 z jednej strony) albo kompleks (sale przecinane kanałem, jeden wielokąt)
## (plan: docs/plan_generator_sciekow.md, wzorzec proto_layout.py kroki 2–3).
## - kompleks = ciąg 1–4 kolejnych odcinków jednej linii (najpierw najdłuższy, ciąg 1 tylko na węźle),
##   min. odstęp między kompleksami complex_min_gap, liczba ≤ max(2, W·H / complex_count_ratio);
## - brzegi budowane kawałkami 4–8 wzdłuż kanału, szerokość = błądzenie losowe (±3, start complex_bank_start,
##   0 albo 2–complex_bank_max),
##   dopasowane do miejsca (nie na obce kanały, ściana od sal innych kompleksów);
## - spójność: w kawałku ≥ 1 brzeg ≥ 2, ciągłość strony, w środku odcinka oba brzegi ≥ 2 (kładka);
## - zwężenie (R4): odcinek ≥ 18 (szansa 0,8), środek bez brzegu po stronie k, zatoki na wejścia korytarza;
## - szczeliny 1 kratki między fragmentami wielokąta -> podłoga (min. ściana 2).
## Na końcu strefy przecięć dla korytarzy (cross_h / cross_v, ZH / ZV, JZ_C) i licznik zakazu fcnt.

const State = preload("core/structured_state.gd")

var st: State
var rng: RandomNumberGenerator
var cfg: Dictionary


static func run(state: State, seed_val: int, config: Dictionary) -> void:
	var z := StructuredZoning.new()
	z.st = state
	z.cfg = config
	z.rng = RandomNumberGenerator.new()
	z.rng.seed = hash([seed_val, "structured_zoning"])
	z._pick_complexes()
	z._lanes()
	z._build_halls()
	z._cross_zones()


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


static func _rect_gap(a: Dictionary, b: Dictionary) -> int:
	var dx := maxi(0, maxi(a.x0, b.x0) - mini(a.x1, b.x1))
	var dy := maxi(0, maxi(a.y0, b.y0) - mini(a.y1, b.y1))
	return maxi(dx, dy)


func _pick_complexes() -> void:
	var gap := int(cfg.get("complex_min_gap", 20))
	var max_cplx := maxi(2, st.w * st.h / int(cfg.get("complex_count_ratio", 5500)))
	var placed_rects: Array[Dictionary] = []
	var line_ids: Array = st.lines.keys()
	var placed_any := true
	while placed_any and st.complexes.size() < max_cplx:
		placed_any = false
		_shuffle(line_ids)
		for lid in line_ids:
			if st.complexes.size() >= max_cplx:
				break
			var ln: Array = st.lines[lid]
			var starts: Array = range(ln.size())
			_shuffle(starts)
			var choice: Array = []
			for k0 in starts:
				for n in [4, 3, 2, 1]:
					if k0 + n > ln.size():
						continue
					var run_: Array = ln.slice(k0, k0 + n)
					var ok := true
					for s in run_:
						if s.kind != "tunnel":
							ok = false
					if not ok or (n == 1 and not run_[0].junction):
						continue
					for s in run_:
						for o in placed_rects:
							if _rect_gap(s, o) < gap:
								ok = false
					if not ok:
						continue
					choice = run_
					break
				if not choice.is_empty():
					break
			if choice.is_empty():
				continue
			var cid: int = st.complexes.size()
			for s in choice:
				s.kind = "hall"
				s.cid = cid
				placed_rects.append(s)
			st.complexes[cid] = {"segs": choice}
			placed_any = true


## Chodniki tuneli o zmiennej szerokości: łańcuch odcinków (kolejne odcinki linii na jednej prostej) dzielony
## na kawałki lane_chunk wzdłuż kanału, każda strona losuje szerokość z lane_width_options (0 = kanał przy
## ścianie; 1 odpada — za wąsko), z szansą lane_keep_chance zostaje poprzednia. Zawsze ≥ 1 strona ≥ 2,
## ciągłość strony (chodnik nie przeskakuje kanału bez kładki), przy przegubach (końce łańcucha, zakręty,
## węzły) obie strony ≥ 2. Szerokość nie zmienia się o 1 (2 <-> 3 tylko przez odcinek 0) i nie ma krótkiego
## ostatniego kawałka — inaczej ściana ma uskok / wypustkę o kratkę, której kafle ścieków (bez lica 2H) nie
## mają. Łańcuch zamiast pojedynczego odcinka: odcinki nachodzą na siebie blokiem kanału, a osobne
## losowanie dawało na styku chodnik 3 obok 2. Prostokąty chodnika w s.lane_rects, kawałki w s.lane_chunks
## ({k, t, t1, w}) przycięte do odcinka; przerwy strony (0 między chodnikami) w st.lane_chains[i].lane_gaps
## ({k, g0, g1, before, after}) — przejście w StructuredRoomPacker (nawias, u-turn z kładką albo kładka).
func _lanes() -> void:
	var opts: Array = cfg.get("lane_width_options", [0, 2, 3])
	var chunk: Array = cfg.get("lane_chunk", [5, 10])
	var keep := float(cfg.get("lane_keep_chance", 0.35))
	var zero_chunks: Array = cfg.get("lane_zero_chunks", [3, 5])   # odcinek bez chodnika: ile kawałków z rzędu
	var end_zone: int = st.cw + 2
	for s in st.segs:
		s.lane_rects = []
		s.lane_chunks = []
		s.lane_gaps = []
	st.lane_chains.clear()
	for chain in _chains():
		var vs := _chain_seg(chain)
		var lo: int = vs.x0 if vs.axis == "h" else vs.y0
		var hi: int = vs.x1 if vs.axis == "h" else vs.y1
		var joints := _joints(vs, chain)
		# Miejsce na chodnik do ramki mapy (stałe na prostym łańcuchu): < 2 — strona bez chodnika (kanał przy
		# ścianie), 2 — najwyżej 2 (przycięcie ramką dawało chodnik szeroki na 1 i uskok ściany).
		var room := [_lane_room(vs, 0), _lane_room(vs, 1)]
		var cur := [maxi(_pick_width(opts), 2), maxi(_pick_width(opts), 2)]
		var zero_left := [0, 0]
		var in_run := [false, false]   # strona w odcinku 0 (może sięgać do końca łańcucha)
		var prev_ok: Array = []
		var prev_w: Array = []
		var t := lo
		while t <= hi:
			var t1 := mini(hi, t + rng.randi_range(int(chunk[0]), int(chunk[1])) - 1)
			# Bez krótkiego ostatniego kawałka (1–4 kratki przy końcu = wcięcie / wypustka ściany).
			if hi - t1 < int(chunk[0]):
				t1 = hi
			var in_end := _near_joint(t, t1, joints, end_zone)
			for k in [0, 1]:
				if in_run[k]:
					if zero_left[k] > 0:
						zero_left[k] -= 1
						cur[k] = 0
					else:
						in_run[k] = false
						cur[k] = maxi(_pick_width(opts), 2)   # koniec odcinka 0 — chodnik wraca
				elif rng.randf() >= keep:
					cur[k] = _pick_width(opts)
					if cur[k] == 0:
						# Odcinek 0 nie zaczyna się przy przegubie ani gdy druga strona jest bez chodnika.
						if in_end or in_run[1 - k] or cur[1 - k] == 0:
							cur[k] = 2
						else:
							in_run[k] = true
							zero_left[k] = rng.randi_range(int(zero_chunks[0]), int(zero_chunks[1])) - 1
			var got: Array = cur.duplicate()
			for k in [0, 1]:
				# Przez cały odcinek 0 druga strona ma chodnik (tam ląduje kładka); przy przegubach (zakręty,
				# węzły, końce) chodnik ma każda strona, która nie jest w odcinku 0.
				if in_run[k]:
					got[1 - k] = maxi(got[1 - k], 2)
				elif in_end:
					got[k] = maxi(got[k], 2)
			if not prev_ok.is_empty():
				var any_prev := false
				for k in prev_ok:
					if got[k] >= 2:
						any_prev = true
				if not any_prev:
					got[prev_ok[0]] = 2
			if got[0] < 2 and got[1] < 2:
				got[rng.randi() % 2] = 2
			for k in [0, 1]:
				if room[k] < 2:
					got[k] = 0
					if room[1 - k] >= 2:
						got[1 - k] = maxi(got[1 - k], 2)
				elif got[k] > room[k]:
					got[k] = room[k]
			# Bez zmiany szerokości o 1 (2 <-> 3): szerokość zmienia się tylko przez odcinek 0.
			if not prev_w.is_empty():
				for k in [0, 1]:
					if got[k] >= 2 and prev_w[k] >= 2 and got[k] != prev_w[k]:
						got[k] = prev_w[k]
			prev_w = got.duplicate()
			prev_ok = []
			for k in [0, 1]:
				vs.lane_chunks.append({"k": k, "t": t, "t1": t1, "w": got[k]})
				if got[k] >= 2:
					prev_ok.append(k)
					in_run[k] = false
					zero_left[k] = 0
					var r := _side_rect(vs, t, t1, k, got[k])
					vs.lane_rects.append(r)
					st.fill(st.lanes, r[0], r[1], r[2], r[3])
			cur = got
			t = t1 + 1
		# Odcinki 0 strony k: {k, g0, g1, before (chodnik przed), after (chodnik za)}.
		for k in [0, 1]:
			var g0 := -1
			var seen_lane := false
			var last_t := lo
			for c in vs.lane_chunks:
				if c.k != k:
					continue
				last_t = c.t1
				if c.w >= 2:
					if g0 >= 0:
						vs.lane_gaps.append({"k": k, "g0": g0, "g1": c.t - 1, "before": seen_lane, "after": true})
					g0 = -1
					seen_lane = true
				elif g0 < 0:
					g0 = c.t
			if g0 >= 0:
				vs.lane_gaps.append({"k": k, "g0": g0, "g1": last_t, "before": seen_lane, "after": false})
		# Kawałki i prostokąty łańcucha przycięte do jego odcinków.
		for si in chain:
			var s: Dictionary = st.segs[si]
			var s_lo: int = s.x0 if s.axis == "h" else s.y0
			var s_hi: int = s.x1 if s.axis == "h" else s.y1
			for c in vs.lane_chunks:
				var ca: int = maxi(int(c.t), s_lo)
				var cb: int = mini(int(c.t1), s_hi)
				if ca > cb:
					continue
				s.lane_chunks.append({"k": c.k, "t": ca, "t1": cb, "w": c.w})
				if int(c.w) >= 2:
					s.lane_rects.append(_side_rect(s, ca, cb, c.k, c.w))
		st.lane_chains.append(vs)
	for i in range(st.w * st.h):
		if st.water[i]:
			st.lanes[i] = 0
	_lane_corners()
	# Chodnik nie wychodzi poza ramkę mapy.
	for y in range(st.h):
		for x in range(st.w):
			if not st.inside(x, y, x, y):
				st.lanes[y * st.w + x] = 0


## Łańcuchy odcinków (indeksy w st.segs): kolejne odcinki tej samej linii na jednej prostej — wędrowiec szedł
## dalej bez skrętu. Odcinki inne niż tunel (sale kompleksów) przerywają łańcuch.
func _chains() -> Array:
	var out: Array = []
	var cur: Array = []
	for si in range(st.segs.size()):
		var s: Dictionary = st.segs[si]
		if s.kind != "tunnel":
			if not cur.is_empty():
				out.append(cur)
				cur = []
			continue
		if not cur.is_empty():
			var p: Dictionary = st.segs[cur[-1]]
			var straight: bool = p.line == s.line and int(p.idx) + 1 == int(s.idx) and p.axis == s.axis
			if straight:
				if s.axis == "h":
					straight = p.y0 == s.y0 and p.y1 == s.y1 and p.x1 >= s.x0 - 1 and s.x1 >= p.x0 - 1
				else:
					straight = p.x0 == s.x0 and p.x1 == s.x1 and p.y1 >= s.y0 - 1 and s.y1 >= p.y0 - 1
			if not straight:
				out.append(cur)
				cur = []
		cur.append(si)
	if not cur.is_empty():
		out.append(cur)
	return out


## Odcinek zastępczy łańcucha (prostokąt wszystkich jego odcinków) — dla chodników i przerw.
func _chain_seg(chain: Array) -> Dictionary:
	var f: Dictionary = st.segs[chain[0]]
	var vs := {"x0": f.x0, "y0": f.y0, "x1": f.x1, "y1": f.y1, "axis": f.axis, "line": f.line, "dry": f.dry,
		"kind": "tunnel", "cid": -1, "junction": false, "lane_rects": [], "lane_chunks": [], "lane_gaps": [], "segs": chain}
	for si in chain:
		var s: Dictionary = st.segs[si]
		vs.x0 = mini(vs.x0, s.x0)
		vs.y0 = mini(vs.y0, s.y0)
		vs.x1 = maxi(vs.x1, s.x1)
		vs.y1 = maxi(vs.y1, s.y1)
	return vs


## Przeguby łańcucha jako zakresy t: oba końce oraz styki z innymi odcinkami (zakręty, węzły, sale).
func _joints(vs: Dictionary, chain: Array) -> Array:
	var horiz: bool = vs.axis == "h"
	var lo: int = vs.x0 if horiz else vs.y0
	var hi: int = vs.x1 if horiz else vs.y1
	var out: Array = [Vector2i(lo, lo), Vector2i(hi, hi)]
	for oi in range(st.segs.size()):
		if chain.has(oi):
			continue
		var o: Dictionary = st.segs[oi]
		if o.x1 < vs.x0 - 1 or o.x0 > vs.x1 + 1 or o.y1 < vs.y0 - 1 or o.y0 > vs.y1 + 1:
			continue
		var a: int = maxi(lo, o.x0 if horiz else o.y0)
		var b: int = mini(hi, o.x1 if horiz else o.y1)
		out.append(Vector2i(mini(a, b), maxi(a, b)))
	return out


## Ile kratek (0–3) od brzegu kanału w stronę k mieści się w ramce mapy (środek łańcucha).
func _lane_room(vs: Dictionary, k: int) -> int:
	var n := 0
	for e in range(1, 4):
		var r := _side_rect(vs, (vs.x0 + vs.x1) / 2 if vs.axis == "h" else (vs.y0 + vs.y1) / 2,
			(vs.x0 + vs.x1) / 2 if vs.axis == "h" else (vs.y0 + vs.y1) / 2, k, e)
		if not st.inside(r[0], r[1], r[2], r[3]):
			break
		n = e
	return n


static func _near_joint(t0: int, t1: int, joints: Array, zone: int) -> bool:
	for j: Vector2i in joints:
		if t0 <= j.y + zone and t1 >= j.x - zone:
			return true
	return false


## Zewnętrzne rogi zakrętów i węzłów: w bloku wspólnym dwóch odcinków (nakładające się prostokąty wody),
## przy każdym z 4 narożników bloku — gdy chodnik dochodzi i z boku pionowego, i z poziomego — kwadrat po
## przekątnej (szerokości obu chodników) też jest chodnikiem. Bez tego chodniki stykają się tylko rogiem
## (ruch 4-kierunkowy — brak przejścia, trzeba obchodzić).
func _lane_corners() -> void:
	for i in range(st.segs.size()):
		var a: Dictionary = st.segs[i]
		for j in range(i + 1, st.segs.size()):
			var b: Dictionary = st.segs[j]
			var bx0 := maxi(a.x0, b.x0)
			var by0 := maxi(a.y0, b.y0)
			var bx1 := mini(a.x1, b.x1)
			var by1 := mini(a.y1, b.y1)
			if bx0 > bx1 or by0 > by1:
				continue
			for sx in [-1, 1]:
				for sy in [-1, 1]:
					var cx: int = bx1 if sx > 0 else bx0
					var cy: int = by1 if sy > 0 else by0
					var wx := _lane_run(cx, cy, sx, 0)   # chodnik w bok od narożnika bloku
					var wy := _lane_run(cx, cy, 0, sy)   # chodnik w górę / dół
					if wx == 0 or wy == 0:
						continue
					var r := [mini(cx + sx, cx + sx * wx), mini(cy + sy, cy + sy * wy), maxi(cx + sx, cx + sx * wx), maxi(cy + sy, cy + sy * wy)]
					var add := false
					for y in range(r[1], r[3] + 1):
						for x in range(r[0], r[2] + 1):
							if st.inside(x, y, x, y) and not st.water[y * st.w + x] and not st.lanes[y * st.w + x]:
								st.lanes[y * st.w + x] = 1
								add = true
					if add:
						a.lane_rects.append(r)


## Ile kratek chodnika (1–4) leży od (x, y) w kierunku (dx, dy), poza samym (x, y) — tylko gdy (x, y) to woda,
## a chodnik zaczyna się tuż za nią.
func _lane_run(x: int, y: int, dx: int, dy: int) -> int:
	var n := 0
	for k in range(1, 5):
		var px := x + dx * k
		var py := y + dy * k
		if not st.in_map(px, py) or not st.lanes[py * st.w + px]:
			break
		n += 1
	return n


func _pick_width(opts: Array) -> int:
	var v := int(opts[rng.randi() % opts.size()])
	return 0 if v < 2 else v


## Pas brzegu odcinka na odcinku osi [t0, t1], strona k, szerokość e od krawędzi wody.
static func _side_rect(s: Dictionary, t0: int, t1: int, k: int, e: int) -> Array:
	if s.axis == "h":
		return [t0, s.y0 - e, t1, s.y0 - 1] if k == 0 else [t0, s.y1 + 1, t1, s.y1 + e]
	return [s.x0 - e, t0, s.x0 - 1, t1] if k == 0 else [s.x1 + 1, t0, s.x1 + e, t1]


func _build_halls() -> void:
	var wv: int = st.wall_v
	var wh: int = st.wall_h
	var hall_any := st.new_mask()
	for cid in st.complexes:
		var cx: Dictionary = st.complexes[cid]
		var run_: Array = cx.segs
		# Kanały własne: odcinki kompleksu i stykające się z nimi (skręt / węzeł w sali nie jest obcy).
		var own := st.new_mask()
		for s in run_:
			st.fill(own, s.x0, s.y0, s.x1, s.y1)
			for o in st.segs:
				if not (o.x1 < s.x0 - 1 or o.x0 > s.x1 + 1 or o.y1 < s.y0 - 1 or o.y0 > s.y1 + 1):
					st.fill(own, o.x0, o.y0, o.x1, o.y1)
		var other_water := st.m_andnot(st.water, own)
		var other_hall := st.new_mask()
		for i in range(st.w * st.h):
			if hall_any[i] and st.hall_cid[i] != cid:
				other_hall[i] = 1
		var foreign := st.m_or(st.dilate(other_water, 3, 3), st.dilate(other_hall, wv + 1, wh + 1))

		# Zwężenie z korytarzem za ścianą: odcinek ≥ 18, środek bez brzegu po stronie k.
		var pinch := {}
		var longs: Array = []
		for s in run_:
			if maxi(s.x1 - s.x0, s.y1 - s.y0) >= 18:
				longs.append(s)
		if not longs.is_empty() and rng.randf() < 0.8:
			var s: Dictionary = longs[rng.randi() % longs.size()]
			var lo: int = s.x0 if s.axis == "h" else s.y0
			var hi: int = s.x1 if s.axis == "h" else s.y1
			pinch = {"seg": s, "k": rng.randi() % 2, "p0": lo + 6, "p1": hi - 6}
		var pm := st.new_mask()
		var ext_max := int(cfg.get("complex_bank_max", 14))
		var ext_start: Array = cfg.get("complex_bank_start", [5, 10])
		var ext := [rng.randi_range(int(ext_start[0]), int(ext_start[1])), rng.randi_range(int(ext_start[0]), int(ext_start[1]))]
		var prev_ok: Array = []
		var have_prev := false
		for s in run_:
			var lo: int = s.x0 if s.axis == "h" else s.y0
			var hi: int = s.x1 if s.axis == "h" else s.y1
			var is_pinch_seg: bool = not pinch.is_empty() and is_same(pinch.seg, s)
			# Miejsce kładki: środek odcinka (poza zwężeniem) — tam oba brzegi ≥ 2.
			var mid := (lo + hi) / 2
			if is_pinch_seg and mid + 3 >= pinch.p0 and mid - 3 <= pinch.p1:
				mid = lo + st.cw + 3 if pinch.p0 - lo > hi - pinch.p1 else hi - st.cw - 4
			s.bridge_t = mid
			var t := lo
			while t <= hi:
				var t1 := mini(hi, t + rng.randi_range(4, 8) - 1)
				for k in [0, 1]:
					ext[k] = maxi(0, mini(ext_max, ext[k] + rng.randi_range(-3, 3)))
				var want: Array = ext.duplicate()
				var force := [false, false]
				if is_pinch_seg:
					var k: int = pinch.k
					if t1 >= pinch.p0 and t <= pinch.p1:
						want[k] = 0
						want[1 - k] = maxi(want[1 - k], 2)
						force[1 - k] = true
					elif t1 >= pinch.p0 - 8 and t <= pinch.p1 + 8:
						want[k] = maxi(want[k], (wh if s.axis == "h" else wv) + 4)   # zatoka na wejście korytarza
						want[1 - k] = maxi(want[1 - k], 2)
						force[1 - k] = true                                            # brzeg ciągły przez zwężenie
				if t <= mid + 1 and t1 >= mid:
					want = [maxi(want[0], 2), maxi(want[1], 2)]
					force = [true, true]
				var got := [_fit(foreign, s, t, t1, 0, want[0]), _fit(foreign, s, t, t1, 1, want[1])]
				# Ciągłość: brzeg po stronie, która była w poprzednim kawałku.
				if have_prev and not prev_ok.is_empty():
					var any_prev := false
					for k in prev_ok:
						if got[k] >= 2:
							any_prev = true
					if not any_prev:
						force[prev_ok[0]] = true
				if got[0] < 2 and got[1] < 2 and not force[0] and not force[1]:
					force[1 if want[1] >= want[0] else 0] = true
				for k in [0, 1]:
					if force[k] and got[k] < 2:
						got[k] = 2
				for k in [0, 1]:
					if got[k] > 0:
						var r := _side_rect(s, t, t1, k, got[k])
						st.fill(pm, r[0], r[1], r[2], r[3])
				prev_ok = []
				for k in [0, 1]:
					if got[k] >= 2:
						prev_ok.append(k)
				have_prev = true
				t = t1 + 1
		for i in range(st.w * st.h):
			if st.water[i]:
				pm[i] = 0
		# Najcieńsza ściana między fragmentami wielokąta = 2 kratki: szczeliny 1 kratki -> podłoga.
		for _it in range(2):
			var add := PackedInt32Array()
			for y in range(st.h):
				for x in range(1, st.w - 1):
					var i: int = y * st.w + x
					if not pm[i] and not st.water[i] and pm[i - 1] and pm[i + 1]:
						add.append(i)
			for y in range(1, st.h - 1):
				for x in range(st.w):
					var i: int = y * st.w + x
					if not pm[i] and not st.water[i] and pm[i - st.w] and pm[i + st.w]:
						add.append(i)
			for i in add:
				pm[i] = 1
		var cells := PackedInt32Array()
		var bb := Vector4i(1 << 30, 1 << 30, -1, -1)
		for i in range(st.w * st.h):
			if pm[i]:
				cells.append(i)
				st.hallm[i] = 1
				hall_any[i] = 1
				st.hall_cid[i] = cid
				var x: int = i % st.w
				var y: int = i / st.w
				bb = Vector4i(mini(bb.x, x), mini(bb.y, y), maxi(bb.z, x), maxi(bb.w, y))
		cx.cells = cells
		cx.pinch = pinch
		cx.bbox = bb
		if not cells.is_empty():
			st.halls.append(bb)
	for i in range(st.w * st.h):
		if st.water[i] or st.lanes[i] or st.hallm[i]:
			st.floor_m[i] = 1


## Szerokość brzegu po stronie k: rośnie, póki pas nie wchodzi na obce (`foreign`) i mieści się w mapie;
## brzeg 1 kratki to za mało na przejście (0).
func _fit(foreign: PackedByteArray, s: Dictionary, t0: int, t1: int, k: int, want: int) -> int:
	var e := 0
	while e < want:
		var r := _side_rect(s, t0, t1, k, e + 1)
		if st.any_in(foreign, r[0], r[1], r[2], r[3]) or not st.inside(r[0], r[1], r[2], r[3]):
			break
		e += 1
	return e if e >= 2 else 0


func _cross_zones() -> void:
	st.cross_h = st.new_mask()
	st.cross_v = st.new_mask()
	var wh_m := st.new_mask()
	var wv_m := st.new_mask()
	for s in st.segs:
		var m: PackedByteArray = st.cross_h if s.axis == "h" else st.cross_v
		st.fill(m, s.x0, s.y0, s.x1, s.y1)
		st.fill(wh_m if s.axis == "h" else wv_m, s.x0, s.y0, s.x1, s.y1)
		for b in s.get("lane_rects", []):
			st.fill(m, b[0], b[1], b[2], b[3])
	st.cross_any = st.m_or(st.cross_h, st.cross_v)
	st.zh = st.dilate(st.cross_h, st.wall_v + 2, st.wall_h + 2)
	st.zv = st.dilate(st.cross_v, st.wall_v + 2, st.wall_h + 2)
	var corner := st.m_and(wh_m, wv_m)
	st.jz = st.dilate(corner, st.cw, st.cw)
	st.jz_c = st.dilate(st.m_and(st.jz, st.water), 1, 1)
	st.build_fcnt()
