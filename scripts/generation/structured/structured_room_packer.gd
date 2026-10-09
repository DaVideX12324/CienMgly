class_name StructuredRoomPacker
extends RefCounted

## R4–R7 układu structured (plan: docs/plan_generator_sciekow.md, wzorzec proto_layout.py kroki 3b–7):
## - R4 korytarz serwisowy przy zwężeniu kompleksu: z części przed zwężeniem do części za nim, po stronie
##   bez brzegu, wyłącznie przez lity mur; brama w poprzek przy wyjściu z części startowej;
##   brak drogi -> zwężenie znika (brzeg jak w reszcie kompleksu);
## - R5 pokoje wolnostojące (≥ 9 / 12 od podłogi, ≤ 30 od sieci), łączniki A* do chodników / sal,
##   połączenia pokój–pokój, pętle z kompleksu do jego dalekiej części, pokoiki doklejone do długich
##   korytarzy; przecięcia kanałów tylko prostopadle, kładka tam, gdzie środek korytarza jest na wodzie;
## - R6 kładki: nie w strefie zakrętu / węzła, podłoga po obu stronach, odstęp ≥ 2, pierwsza w środku
##   odcinka kompleksu;
## - R7 spójność: odcięte części łączone A*, awaryjnie prosty L (nie przez zakręt kanału).

const State = preload("core/structured_state.gd")
const Pathfinder = preload("structured_pathfinder.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var st: State
var rng: RandomNumberGenerator
var cfg: Dictionary
var corridors: Array[PackedInt32Array] = []
var flush_rooms := {}   # Vector4i -> true: pokoje dostawione do chodnika / sali (bez łącznika)
var cross_p := PackedInt32Array()
var stats := {}


static func run(state: State, seed_val: int, config: Dictionary) -> Dictionary:
	var p := StructuredRoomPacker.new()
	p.st = state
	p.cfg = config
	p.rng = RandomNumberGenerator.new()
	p.rng.seed = hash([seed_val, "structured_rooms"])
	p.cross_p = state.prefix(state.cross_any)
	state.build_water_axis()
	# Czasy kroków (ms) w stats["t"] — diagnostyka wydajności (preprocess_stats["structured"]).
	var times := {}
	for step in [&"_service_corridors", &"_lane_gaps", &"_rooms", &"_room_links", &"_complex_loops",
			&"_attached_rooms", &"_segment_bridges", &"_repair", &"_drop_redundant_bridges"]:
		var t0 := Time.get_ticks_usec()
		p.call(step)
		times[String(step).trim_prefix("_")] = (Time.get_ticks_usec() - t0) / 1000
	p.stats["t"] = times
	return p.stats


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _pf() -> Pathfinder:
	var pf := Pathfinder.new(st)
	pf.cross_p = cross_p
	return pf


func _rect_cells(r: Vector4i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(maxi(0, r.y), mini(st.h - 1, r.w) + 1):
		for x in range(maxi(0, r.x), mini(st.w - 1, r.z) + 1):
			out.append(y * st.w + x)
	return out


## Kratki listy, które liczą się do zakazu obcej podłogi (podłoga poza strefami przecięć).
func _sub_cells(cells: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in cells:
		if st.floor_m[c] and not st.cross_any[c]:
			out.append(c)
	return out


func _mask_cells(m: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(m.size()):
		if m[i]:
			out.append(i)
	return out


# --- Kładki przecięć i rzeźbienie ---

## Kładka tam, gdzie środek korytarza jest na wodzie: 2 kratki szerokości jak moduł kładki (środek korytarza
## i kratka obok — w prawo przez kanał poziomy, w dół przez pionowy); korytarz 3 kratki zwęża się na kładce,
## trzecia kratka zostaje wodą (grafika, kolizja i przechodniość tych samych kratek).
func _crossing_bridges(centers: PackedInt32Array) -> void:
	var wc := {}
	for c in centers:
		if not st.water[c]:
			continue
		var x: int = c % st.w
		var y: int = c / st.w
		var side := Vector2i(1, 0) if _water_run(x, y, Vector2i(1, 0)) > _water_run(x, y, Vector2i(0, 1)) else Vector2i(0, 1)
		for d in [Vector2i.ZERO, side]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if st.in_map(nx, ny) and st.water[ny * st.w + nx]:
				wc[Vector2i(nx, ny)] = true
	if wc.is_empty():
		return
	# Osobna kładka na każde przejście (spójna grupa kratek) — korytarz przecinający dwa kanały dawał jedną
	# „kładkę” z prostokątem modułu obejmującym oba przejścia (grafika w murze, przejścia bez kładki).
	var left := wc.duplicate()
	while not left.is_empty():
		var start: Vector2i = left.keys()[0]
		var cells: Array[Vector2i] = [start]
		left.erase(start)
		var head := 0
		while head < cells.size():
			var c: Vector2i = cells[head]
			head += 1
			for d in DIRS:
				var n: Vector2i = c + d
				if left.has(n):
					left.erase(n)
					cells.append(n)
		for p in cells:
			st.bridge_m[p.y * st.w + p.x] = 1
		cells.sort()
		st.bridges.append({"cells": cells, "vertical": bool(st.cross_h[cells[0].y * st.w + cells[0].x]), "crossing": true})


## Długość ciągu wody przez (x, y) wzdłuż osi `d` (do 9 kratek w każdą stronę).
func _water_run(x: int, y: int, d: Vector2i) -> int:
	var n := 1
	for sgn in [1, -1]:
		for k in range(1, 10):
			var nx: int = x + d.x * k * sgn
			var ny: int = y + d.y * k * sgn
			if not st.in_map(nx, ny) or not st.water[ny * st.w + nx]:
				break
			n += 1
	return n


## Korytarz 3 kratki wzdłuż środków (bez wody i korytarza serwisowego); kładki na przecięciach.
func _carve(path: PackedInt32Array) -> PackedInt32Array:
	var seen := {}
	var out := PackedInt32Array()
	for c in path:
		var x: int = c % st.w
		var y: int = c / st.w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var nx: int = x + dx
				var ny: int = y + dy
				if not st.in_map(nx, ny):
					continue
				var i: int = ny * st.w + nx
				if seen.has(i) or st.water[i] or st.service[i]:
					continue
				seen[i] = true
				out.append(i)
	for i in out:
		st.add_floor(i % st.w, i / st.w)
		st.corrm[i] = 1
	_crossing_bridges(path)
	return out


# --- R4: korytarz serwisowy ---

func _service_corridors() -> void:
	var n := 0
	for cid in st.complexes:
		var cx: Dictionary = st.complexes[cid]
		if cx.pinch.is_empty():
			continue
		if _carve_service(cx):
			n += 1
		else:
			_drop_pinch(cx)
	stats["service"] = n


func _carve_service(cx: Dictionary) -> bool:
	var pz: Dictionary = cx.pinch
	var s: Dictionary = pz.seg
	var k: int = pz.k
	var horiz: bool = s.axis == "h"
	var own_c := PackedInt32Array()
	var tgt_c := PackedInt32Array()
	var mid_c := PackedInt32Array()
	for c in cx.cells:
		var t: int = (c % st.w) if horiz else (c / st.w)
		if t < pz.p0 - 1:
			own_c.append(c)
		elif t > pz.p1 + 1:
			tgt_c.append(c)
		else:
			mid_c.append(c)
	if rng.randf() < 0.5:
		var tmp := own_c
		own_c = tgt_c
		tgt_c = tmp
	if own_c.is_empty() or tgt_c.is_empty():
		return false
	# Start: kratka części startowej po stronie k, nie przy wodzie.
	var starts := PackedInt32Array()
	for c in own_c:
		var x: int = c % st.w
		var y: int = c / st.w
		var side: bool = (y < s.y0 if k == 0 else y > s.y1) if horiz else (x < s.x0 if k == 0 else x > s.x1)
		if side and not st.any_in(st.water, x - 1, y - 1, x + 1, y + 1):
			starts.append(c)
	if starts.is_empty():
		return false
	var c0: int = starts[rng.randi() % starts.size()]
	var canal := Vector4i(s.x0, s.y0, s.x1, s.y1)
	var wv: int = st.wall_v
	var wh: int = st.wall_h
	var pf := _pf()
	pf.own = State.LocalSum.from_cells(own_c, st.w)
	pf.own_sub = State.LocalSum.from_cells(_sub_cells(own_c), st.w)
	pf.target = State.LocalSum.from_cells(tgt_c, st.w)
	var tgt_m := st.new_mask()
	for c in tgt_c:
		tgt_m[c] = 1
	pf.dt = st.distance_to(tgt_m)
	pf.has_bias = true
	pf.bias_rect = Vector4i(canal.x - 16, canal.y - 18, canal.z + 16, canal.w + 18)
	pf.bias_side = k
	pf.bias_horiz = horiz
	pf.bias_canal = canal
	pf.zone_skip_rect = Vector4i(canal.x - wv - 14, canal.y - wh - 14, canal.z + wv + 14, canal.w + wh + 14)
	pf.zone_skip_canal = canal
	pf.extra_rect = Vector4i(canal.x - wv - 2, canal.y - wh - 2, canal.z + wv + 2, canal.w + wh + 2)
	pf.extra_mask = State.LocalSum.from_cells(mid_c, st.w)
	var path := pf.find(c0 % st.w, c0 / st.w)
	if path.is_empty():
		return false
	var cxm := st.new_mask()
	for c in cx.cells:
		cxm[c] = 1
	var outside := PackedInt32Array()
	for c in path:
		var x: int = c % st.w
		var y: int = c / st.w
		if cxm[c]:
			continue   # środek w sali — poszerzenie dawało pas szeroki na 1 wzdłuż jej krawędzi (wypustka ściany)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var i: int = (y + dy) * st.w + x + dx
				if not cxm[i] and not st.water[i]:
					st.add_floor(x + dx, y + dy)
					st.service[i] = 1
		outside.append(c)
	_crossing_bridges(outside)
	# Brama: 3 kratki w poprzek korytarza przy pierwszej kratce poza częścią startową.
	var own_m := pf.own
	var out_own := PackedInt32Array()
	for c in path:
		if not own_m.has(c % st.w, c / st.w):
			out_own.append(c)
	if not out_own.is_empty():
		var g := Vector2i(out_own[0] % st.w, out_own[0] / st.w)
		var nxt := Vector2i(out_own[1] % st.w, out_own[1] / st.w) if out_own.size() > 1 else g
		if nxt.x != g.x:
			st.gates.append([g + Vector2i(0, -1), g, g + Vector2i(0, 1)])
		else:
			st.gates.append([g + Vector2i(-1, 0), g, g + Vector2i(1, 0)])
	return true


## Brak korytarza: zwężenie znika — brzeg 2 po stronie k w środku odcinka (kanał przy ścianie tylko
## z korytarzem obok, decyzja usera).
func _drop_pinch(cx: Dictionary) -> void:
	var pz: Dictionary = cx.pinch
	var s: Dictionary = pz.seg
	var r: Array
	if s.axis == "h":
		r = [pz.p0, s.y0 - 2, pz.p1, s.y0 - 1] if pz.k == 0 else [pz.p0, s.y1 + 1, pz.p1, s.y1 + 2]
	else:
		r = [s.x0 - 2, pz.p0, s.x0 - 1, pz.p1] if pz.k == 0 else [s.x1 + 1, pz.p0, s.x1 + 2, pz.p1]
	var add := PackedInt32Array()
	for y in range(r[1], r[3] + 1):
		for x in range(r[0], r[2] + 1):
			if st.in_map(x, y) and not st.water[y * st.w + x] and st.inside(x, y, x, y):
				add.append(y * st.w + x)
	for i in add:
		st.add_floor(i % st.w, i / st.w)
		st.hallm[i] = 1
	var cells: PackedInt32Array = cx.cells
	cells.append_array(add)
	cx.cells = cells
	cx.pinch = {}


# --- Przerwy chodnika tunelu ---

## Strona chodnika urywa się (szerokość 0), a druga strona ma chodnik. Krótka przerwa (≤ lane_gap_bracket_max)
## z chodnikiem po obu końcach: nawias wokół przerwy (powrót na tę samą stronę). Dłuższy odcinek 0: u-turn (szansa lane_gap_bypass_chance) — tunel z końca chodnika przez mur, wzdłuż kanału za
## ścianą i z powrotem do kanału dalej w odcinku 0, tam kładka na drugą stronę (gdzie jest ścieżka); albo
## zwykła kładka przy końcu chodnika. Przy końcu odcinka 0 kładka z szansą 0,5 (chodnik i tak łączy się na
## końcu odcinka kanału).
func _lane_gaps() -> void:
	var chance := float(cfg.get("lane_gap_bypass_chance", 0.5))
	var bracket_max := int(cfg.get("lane_gap_bracket_max", 14))
	var brackets := 0
	var uturn := 0
	var bridged := 0
	var lost := 0
	for s in st.lane_chains:
		var horiz: bool = s.axis == "h"
		for g in s.get("lane_gaps", []):
			var ok := false
			var before: bool = g.get("before", true)
			var after: bool = g.get("after", true)
			# Krótka przerwa z chodnikiem po obu końcach: nawias (tunel wokół przerwy, powrót na tę samą stronę).
			if before and after and int(g.g1) - int(g.g0) + 1 <= bracket_max and rng.randf() < chance and _gap_bracket(s, g):
				brackets += 1
				continue
			if rng.randf() < chance:
				var first := before if not after else (rng.randi() % 2 == 0 if before else false)
				ok = (before and first and _gap_uturn(s, g, true)) or (after and _gap_uturn(s, g, false)) \
					or (before and not first and _gap_uturn(s, g, true))
			if ok:
				uturn += 1
			elif (before and (_place_bridge(s, int(g.g0) - 2, horiz) or _place_bridge(s, int(g.g0) - 10, horiz))) \
					or (after and (_place_bridge(s, int(g.g1) + 1, horiz) or _place_bridge(s, int(g.g1) + 9, horiz))):
				bridged += 1
			else:
				lost += 1
			if before and after and rng.randf() < 0.5:
				_place_bridge(s, int(g.g1) + 1, horiz)
	stats["gap_bracket"] = brackets
	stats["gap_uturn"] = uturn
	stats["gap_bridged"] = bridged
	stats["gap_unresolved"] = lost


## Nawias: zwarty prostokątny tunel przez mur wokół krótkiej przerwy — ramię prostopadłe z końca chodnika przed
## przerwą, ramię równoległe za ścianą (min. ściana + 2 od kanału), ramię z powrotem do chodnika za przerwą.
## Grubość ramion lane_gap_arm (2–3), głębokość + lane_gap_depth_extra (0–3); ściana między ramionami = przerwa (min. wall_v + 1 przy kanale poziomym,
## wall_h + 1 przy pionowym — tam to lico). Tylko w litym murze: obca podłoga (poza siecią kanałów
## i chodników) najbliżej o ścianę + 1; kratki chodnika mogą leżeć pod ramionami.
func _gap_bracket(s: Dictionary, g: Dictionary) -> bool:
	var k: int = g.k
	var g0: int = g.g0
	var g1: int = g.g1
	var arm_r: Array = cfg.get("lane_gap_arm", [2, 3])
	var depth_r: Array = cfg.get("lane_gap_depth_extra", [0, 3])
	var arm := rng.randi_range(int(arm_r[0]), int(arm_r[1]))
	var horiz: bool = s.axis == "h"
	var inner: int = (st.wall_h if horiz else st.wall_v) + 2 + rng.randi_range(int(depth_r[0]), int(depth_r[1]))
	if g1 - g0 + 1 < (st.wall_v if horiz else st.wall_h) + 1:
		stats["br_short"] = stats.get("br_short", 0) + 1
		return false
	var a0 := g0 - arm
	var a1 := g1 + arm
	var lo: int = s.x0 if horiz else s.y0
	var hi: int = s.x1 if horiz else s.y1
	if a0 < lo or a1 > hi:
		stats["br_ends"] = stats.get("br_ends", 0) + 1
		return false
	var cells := {}
	for r in [StructuredZoning._side_rect(s, a0, g0 - 1, k, inner + arm),
			StructuredZoning._side_rect(s, g1 + 1, a1, k, inner + arm)]:
		for y in range(r[1], r[3] + 1):
			for x in range(r[0], r[2] + 1):
				cells[Vector2i(x, y)] = true
	var far := StructuredZoning._side_rect(s, a0, a1, k, inner + arm)
	var near := StructuredZoning._side_rect(s, a0, a1, k, inner)
	for y in range(far[1], far[3] + 1):
		for x in range(far[0], far[2] + 1):
			if not (x >= near[0] and x <= near[2] and y >= near[1] and y <= near[3]):
				cells[Vector2i(x, y)] = true
	for c in cells:
		if not st.inside(c.x, c.y, c.x, c.y):
			stats["br_map"] = stats.get("br_map", 0) + 1
			return false
		var i: int = c.y * st.w + c.x
		if st.lanes[i]:
			continue
		if st.floor_m[i]:
			stats["br_floor"] = stats.get("br_floor", 0) + 1
			return false
		if _near_foreign(c.x, c.y, cells, s):
			stats["br_near"] = stats.get("br_near", 0) + 1
			return false
	var out := PackedInt32Array()
	for c in cells:
		var i: int = c.y * st.w + c.x
		if st.lanes[i]:
			continue
		st.add_floor(c.x, c.y)
		st.corrm[i] = 1
		out.append(i)
	corridors.append(out)
	return true


## U-turn z kładką: ramię prostopadłe z końca chodnika przy odcinku 0 (od początku albo — `from_start`
## false — od końca odcinka), ramię równoległe za ścianą (min. ściana + 2 od kanału + lane_gap_depth_extra),
## ramię z powrotem do kanału w środku odcinka 0 i kładka w miejscu tego ramienia na drugą stronę. Ściana
## między ramionami ≥ wall_v + 1 (kanał poziomy) / wall_h + 1 (pionowy — lico). Tylko w litym murze (obca
## podłoga poza siecią najbliżej o ścianę + 1); kładka musi wejść dokładnie przy ramieniu, inaczej cofnięty.
func _gap_uturn(s: Dictionary, g: Dictionary, from_start := true) -> bool:
	var k: int = g.k
	var g0: int = g.g0
	var g1: int = g.g1
	var arm_r: Array = cfg.get("lane_gap_arm", [2, 3])
	var depth_r: Array = cfg.get("lane_gap_depth_extra", [0, 3])
	var arm := rng.randi_range(int(arm_r[0]), int(arm_r[1]))
	var horiz: bool = s.axis == "h"
	var inner: int = (st.wall_h if horiz else st.wall_v) + 2 + rng.randi_range(int(depth_r[0]), int(depth_r[1]))
	var wall_along: int = (st.wall_v if horiz else st.wall_h) + 1
	var lo: int = s.x0 if horiz else s.y0
	var hi: int = s.x1 if horiz else s.y1
	var arm1: Vector2i     # zakres wzdłuż kanału (włącznie)
	var arm2: Vector2i
	var bridge_ts: Array = []
	if from_start:
		var e_min := g0 + wall_along + arm
		var e_max := mini(g1 - 1, e_min + 8)
		if e_max < e_min or g0 - arm < lo:
			stats["u_short"] = stats.get("u_short", 0) + 1
			return false
		var e := rng.randi_range(e_min, e_max)
		arm1 = Vector2i(g0 - arm, g0 - 1)
		arm2 = Vector2i(e - arm + 1, e)
		for t in range(e - 1, e - arm, -1):
			bridge_ts.append(t)
	else:
		var e_max := g1 - wall_along - arm
		var e_min := maxi(g0 + 1, e_max - 8)
		if e_max < e_min or g1 + arm > hi:
			stats["u_short"] = stats.get("u_short", 0) + 1
			return false
		var e := rng.randi_range(e_min, e_max)
		arm1 = Vector2i(g1 + 1, g1 + arm)
		arm2 = Vector2i(e, e + arm - 1)
		for t in range(e, e + arm - 1):
			bridge_ts.append(t)
	var span := Vector2i(mini(arm1.x, arm2.x), maxi(arm1.y, arm2.y))
	var cells := {}
	for r in [StructuredZoning._side_rect(s, arm1.x, arm1.y, k, inner + arm),
			StructuredZoning._side_rect(s, arm2.x, arm2.y, k, inner + arm)]:
		for y in range(r[1], r[3] + 1):
			for x in range(r[0], r[2] + 1):
				cells[Vector2i(x, y)] = true
	var far := StructuredZoning._side_rect(s, span.x, span.y, k, inner + arm)
	var near := StructuredZoning._side_rect(s, span.x, span.y, k, inner)
	for y in range(far[1], far[3] + 1):
		for x in range(far[0], far[2] + 1):
			if not (x >= near[0] and x <= near[2] and y >= near[1] and y <= near[3]):
				cells[Vector2i(x, y)] = true
	for c in cells:
		if not st.inside(c.x, c.y, c.x, c.y):
			stats["u_map"] = stats.get("u_map", 0) + 1
			return false
		var i: int = c.y * st.w + c.x
		if st.lanes[i]:
			continue
		if st.floor_m[i]:
			stats["u_floor"] = stats.get("u_floor", 0) + 1
			return false
		if _near_foreign(c.x, c.y, cells, s):
			stats["u_near"] = stats.get("u_near", 0) + 1
			return false
	var out := PackedInt32Array()
	for c in cells:
		var i: int = c.y * st.w + c.x
		if st.lanes[i] or st.floor_m[i]:
			continue
		st.add_floor(c.x, c.y)
		st.corrm[i] = 1
		out.append(i)
	for t in bridge_ts:
		if _place_bridge(s, t, horiz, true):
			corridors.append(out)
			return true
	for i in out:
		st.remove_floor(i % st.w, i / st.w)
		st.corrm[i] = 0
	stats["u_bridge"] = stats.get("u_bridge", 0) + 1
	return false


## Obca podłoga bliżej niż ściana + 1: wszystko poza samym tunelem (`own`) oraz wodą i chodnikami własnego
## odcinka kanału `s` (chodniki innych kanałów też są obce — inaczej ściana 1 kratki, którą zjadają przejścia
## czyszczące, i ramię znika).
func _near_foreign(x: int, y: int, own: Dictionary, s: Dictionary) -> bool:
	var rx: int = st.wall_v + 1
	var ry: int = st.wall_h + 1
	for yy in range(maxi(0, y - ry), mini(st.h - 1, y + ry) + 1):
		for xx in range(maxi(0, x - rx), mini(st.w - 1, x + rx) + 1):
			var i: int = yy * st.w + xx
			if not st.floor_m[i] or own.has(Vector2i(xx, yy)) or _in_seg(s, xx, yy):
				continue
			return true
	return false


## Kratka wody albo chodnika odcinka `s`.
static func _in_seg(s: Dictionary, x: int, y: int) -> bool:
	if x >= s.x0 and x <= s.x1 and y >= s.y0 and y <= s.y1:
		return true
	for r in s.get("lane_rects", []):
		if x >= r[0] and x <= r[2] and y >= r[1] and y <= r[3]:
			return true
	return false


# --- R5: pokoje i korytarze ---

func _rooms() -> void:
	var M: int = st.margin
	var target := maxi(5, st.w * st.h / int(cfg.get("rooms_ratio", 2000)))
	var rw_r: Array = cfg.get("room_size_w", [10, 17])
	var rh_r: Array = cfg.get("room_size_h", [9, 14])
	var dmin_h := int(cfg.get("room_distance_min_h", 9))
	var dmin_v := int(cfg.get("room_distance_min_v", 12))
	var dmax := int(cfg.get("room_distance_max", 30))   # najdalej od sieci (kanały, sale, korytarze serwisowe)
	var fp: PackedInt32Array = st.prefix(st.floor_m)
	var spine := st.new_mask()
	for i in range(st.w * st.h):
		spine[i] = st.water[i] | st.lanes[i] | st.hallm[i] | st.service[i]
	var sp: PackedInt32Array = st.prefix(spine)
	var placed: Array[Vector4i] = []
	var flush_chance := float(cfg.get("room_flush_chance", 0.5))
	# Najwyżej taki udział pokoi dostawionych do sieci — reszta stoi osobno z łącznikiem (korytarzem); bez limitu
	# dostawienie wypierało pokoje z korytarzami (przy równych chodnikach udaje się częściej niż wolny pokój).
	# W ostatnich 40 % prób limit znika — dopełnienie do docelowej liczby pokoi, gdy wolne się nie mieszczą.
	var flush_max := int(ceil(float(target) * float(cfg.get("room_flush_max_share", 0.5))))
	var attempts := target * 40
	var edges := _network_edges()
	for _a in range(attempts):
		if placed.size() >= target:
			break
		var rw := rng.randi_range(int(rw_r[0]), int(rw_r[1]))
		var rh := rng.randi_range(int(rh_r[0]), int(rh_r[1]))
		if st.w - M - rw <= M or st.h - M - rh <= M + 2:
			break
		var flush_ok: bool = flush_rooms.size() < flush_max or _a >= attempts * 6 / 10
		if not edges.is_empty() and flush_ok and rng.randf() < flush_chance:
			var fr := _flush_room(edges[rng.randi() % edges.size()], rw, rh, placed, dmin_h, dmin_v)
			if fr.z >= fr.x:
				placed.append(fr)
				flush_rooms[fr] = true
			continue
		var x0 := rng.randi_range(M, st.w - M - rw)
		var y0 := rng.randi_range(M + 2, st.h - M - rh)
		var r := Vector4i(x0, y0, x0 + rw - 1, y0 + rh - 1)
		var g := Vector4i(r.x - dmin_h, r.y - dmin_v, r.z + dmin_h, r.w + dmin_v)
		if st.box(fp, g.x, g.y, g.z, g.w) > 0:
			continue
		var clash := false
		for o in placed:
			if not (o.z < g.x or o.x > g.z or o.w < g.y or o.y > g.w):
				clash = true
				break
		if clash:
			continue
		if st.box(sp, r.x - dmax, r.y - dmax, r.z + dmax, r.w + dmax) == 0:
			continue
		placed.append(r)
	for r in placed:
		st.rooms.append(r)
		st.fill(st.roomm, r.x, r.y, r.z, r.w)
		st.add_floor_rect(r.x, r.y, r.z, r.w)
	stats["rooms"] = placed.size()
	stats["rooms_flush"] = flush_rooms.size()


## Krawędzie sieci pod pokoje dostawione: (kratka chodnika / sali, kierunek w mur).
func _network_edges() -> Array:
	var out: Array = []
	for i in range(st.w * st.h):
		if st.water[i] or not (st.lanes[i] or st.hallm[i]):
			continue
		var x: int = i % st.w
		var y: int = i / st.w
		for d in DIRS:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if st.in_map(nx, ny) and not st.floor_m[ny * st.w + nx]:
				out.append([Vector2i(x, y), d])
	return out


## Pokój dostawiony do krawędzi sieci (decyzja usera: pokój nie musi być za korytarzem): pierwszy rząd tuż
## za chodnikiem / salą, ≥ 3 kratki styku; z pozostałych stron ściana jak dla zwykłej podłogi (podłoga
## w oknie ściany tylko po stronie sieci). Zwraca prostokąt albo pusty (z > x nie spełnione).
func _flush_room(edge: Array, rw: int, rh: int, placed: Array[Vector4i], dmin_h: int, dmin_v: int) -> Vector4i:
	var c: Vector2i = edge[0]
	var d: Vector2i = edge[1]
	var r: Vector4i
	if d == Vector2i(0, -1):
		var x0: int = c.x - rng.randi_range(1, rw - 2)
		r = Vector4i(x0, c.y - rh, x0 + rw - 1, c.y - 1)
	elif d == Vector2i(0, 1):
		var x0: int = c.x - rng.randi_range(1, rw - 2)
		r = Vector4i(x0, c.y + 1, x0 + rw - 1, c.y + rh)
	elif d == Vector2i(-1, 0):
		var y0: int = c.y - rng.randi_range(1, rh - 2)
		r = Vector4i(c.x - rw, y0, c.x - 1, y0 + rh - 1)
	else:
		var y0: int = c.y - rng.randi_range(1, rh - 2)
		r = Vector4i(c.x + 1, y0, c.x + rw, y0 + rh - 1)
	var bad := Vector4i(0, 0, -1, -1)
	if not st.inside(r.x, r.y, r.z, r.w):
		return bad
	# Odstęp od innych pokoi jak dla wolnostojących.
	var g := Vector4i(r.x - dmin_h, r.y - dmin_v, r.z + dmin_h, r.w + dmin_v)
	for o in placed:
		if not (o.z < g.x or o.x > g.z or o.w < g.y or o.y > g.w):
			return bad
	# Podłoga w oknie ściany wolno tylko po stronie sieci (za płaszczyzną styku); sam pokój — lity mur.
	var rx: int = st.wall_v + 1
	var ry: int = st.wall_h + 1
	var contact := 0
	for y in range(r.y - ry, r.w + ry + 1):
		for x in range(r.x - rx, r.z + rx + 1):
			if not st.in_map(x, y):
				continue
			var i: int = y * st.w + x
			if not st.floor_m[i]:
				continue
			var inr: bool = x >= r.x and x <= r.z and y >= r.y and y <= r.w
			if inr:
				return bad
			var dot: int = (x - c.x) * d.x + (y - c.y) * d.y
			if dot > 0:
				return bad
			if dot == 0 and (st.lanes[i] or st.hallm[i]) and not st.water[i]:
				# styk: kratka sieci tuż przy pierwszym rzędzie pokoju
				var along_ok: bool = (x >= r.x and x <= r.z) if d.x == 0 else (y >= r.y and y <= r.w)
				if along_ok:
					contact += 1
	if contact < 3:
		return bad
	return r


func _room_links() -> void:
	var link := st.new_mask()
	for i in range(st.w * st.h):
		link[i] = st.lanes[i] | st.hallm[i]
	var link_sum := State.LocalSum.from_mask(link, st.w)
	var link_dt: PackedInt32Array = st.distance_to(link)
	var linked := 0
	var free_rooms: Array[Vector4i] = st.rooms.duplicate()
	for r in free_rooms:
		if flush_rooms.has(r):
			continue   # dostawiony do sieci — bez łącznika
		var own_c := _rect_cells(r)
		var pf := _pf()
		pf.own = State.LocalSum.from_cells(own_c, st.w)
		pf.own_sub = State.LocalSum.from_cells(own_c, st.w)
		pf.target = link_sum
		pf.dt = link_dt
		var path := pf.find((r.x + r.z) / 2, (r.y + r.w) / 2)
		if path.is_empty():
			continue
		corridors.append(_carve(_without(path, pf.own)))
		linked += 1
	# Część pokoi łączy się z drugim pokojem (pętle).
	var room_dt: PackedInt32Array = st.distance_to(st.roomm)
	var extra := 0
	for r in free_rooms:
		if rng.randf() >= float(cfg.get("loop_chance", 0.35)):
			continue
		var own_c := _rect_cells(r)
		var others := PackedInt32Array()
		for o in free_rooms:
			if o != r:
				others.append_array(_rect_cells(o))
		if others.is_empty():
			continue
		var pf := _pf()
		pf.own = State.LocalSum.from_cells(own_c, st.w)
		pf.own_sub = State.LocalSum.from_cells(own_c, st.w)
		pf.target = State.LocalSum.from_cells(others, st.w)
		pf.dt = room_dt
		var path := pf.find((r.x + r.z) / 2, (r.y + r.w) / 2)
		if path.is_empty() or path.size() >= 70:
			continue
		var outside := _without(path, pf.own)
		var near := 0
		for c in outside:
			var x: int = c % st.w
			var y: int = c / st.w
			if x >= r.x - 9 and x <= r.z + 9 and y >= r.y - 9 and y <= r.w + 9:
				near += 1
		if float(near) / maxf(1.0, float(outside.size())) > 0.5:
			continue   # obiega własną salę
		corridors.append(_carve(outside))
		extra += 1
	stats["room_links"] = linked
	stats["room_room"] = extra


func _without(path: PackedInt32Array, own: State.LocalSum) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in path:
		if not own.has(c % st.w, c / st.w):
			out.append(c)
	return out


## Pętle: korytarz wychodzi z kompleksu przez mur i wraca do jego części oddalonej o > 26 (Manhattan).
func _complex_loops() -> void:
	var M: int = st.margin
	var max_loops := maxi(2, st.w * st.h / 7000)
	var loops := 0
	var cids: Array = st.complexes.keys()
	_shuffle(cids)
	for cid in cids:
		if loops >= max_loops:
			break
		var cx: Dictionary = st.complexes[cid]
		var cells: PackedInt32Array = cx.cells
		if cells.size() < 150:
			continue
		var pm := st.new_mask()
		for c in cells:
			pm[c] = 1
		var cand := PackedInt32Array()
		for c in cells:
			var x: int = c % st.w
			var y: int = c / st.w
			var all_pm := true
			var any_wall := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var i: int = (y + dy) * st.w + x + dx
					if not st.in_map(x + dx, y + dy):
						all_pm = false
						any_wall = true
						continue
					if not pm[i]:
						all_pm = false
					if not st.floor_m[i]:
						any_wall = true
			if all_pm or any_wall:
				cand.append(c)
		var order: Array = range(cand.size())
		_shuffle(order)
		var cx_dt: PackedInt32Array = st.distance_to(pm)
		var done := false
		for oi in order.slice(0, 40):
			var c: int = cand[oi]
			var px: int = c % st.w
			var py: int = c / st.w
			for d in DIRS:
				var L: int = (st.wall_h if d.y != 0 else st.wall_v) + 3
				var sx: int = px + d.x * L
				var sy: int = py + d.y * L
				if sx < M + 2 or sy < M + 2 or sx >= st.w - M - 2 or sy >= st.h - M - 2:
					continue
				var blocked := false
				for kk in range(1, L + 1):
					if st.floor_m[(py + d.y * kk) * st.w + px + d.x * kk]:
						blocked = true
						break
				if blocked or st.any_in(st.floor_m, sx - st.wall_v - 1, sy - st.wall_h - 1, sx + st.wall_v + 1, sy + st.wall_h + 1):
					continue
				var far := PackedInt32Array()
				for q in cells:
					if absi(q % st.w - px) + absi(q / st.w - py) > 26:
						far.append(q)
				if far.is_empty():
					continue
				var pf := _pf()
				pf.target = State.LocalSum.from_cells(far, st.w)
				pf.dt = cx_dt
				pf.start_ok = Vector4i(sx - 3, sy - 3, sx + 3, sy + 3)
				var p1 := pf.find(sx, sy)
				if p1.is_empty() or p1.size() < 20:
					continue
				var path := PackedInt32Array()
				for kk in range(1, L):
					path.append((py + d.y * kk) * st.w + px + d.x * kk)
				path.append_array(p1)
				corridors.append(_carve(path))
				loops += 1
				done = true
				break
			if done:
				break
	stats["loops"] = loops


## Pokoiki 7–10 × 6–9 doklejone do długich korytarzy (≥ 22 kratek środka, szansa corridor_room_chance).
func _attached_rooms() -> void:
	var added := 0
	var chance := float(cfg.get("corridor_room_chance", 0.5))
	for cc in corridors:
		if cc.size() < 3 * 22 or rng.randf() > chance:
			continue
		var ccm := {}
		for c in cc:
			ccm[c] = true
		for _a in range(30):
			var c: int = cc[rng.randi() % cc.size()]
			var x: int = c % st.w
			var y: int = c / st.w
			var rw := rng.randi_range(7, 10)
			var rh := rng.randi_range(6, 9)
			var side: Vector2i = DIRS[rng.randi() % 4]
			var r: Vector4i
			if side == Vector2i(1, 0):
				r = Vector4i(x + 1, y - rh / 2, x + rw, y - rh / 2 + rh - 1)
			elif side == Vector2i(-1, 0):
				r = Vector4i(x - rw, y - rh / 2, x - 1, y - rh / 2 + rh - 1)
			elif side == Vector2i(0, 1):
				r = Vector4i(x - rw / 2, y + 1, x - rw / 2 + rw - 1, y + rh)
			else:
				r = Vector4i(x - rw / 2, y - rh, x - rw / 2 + rw - 1, y - 1)
			if not st.inside(r.x, r.y, r.z, r.w):
				continue
			# Ściana od każdej podłogi poza własnym korytarzem; pokój przylega do korytarza, nie przecina go.
			var bad := false
			var touch := false
			for yy in range(r.y - st.wall_h - 1, r.w + st.wall_h + 2):
				for xx in range(r.x - st.wall_v - 1, r.z + st.wall_v + 2):
					if not st.in_map(xx, yy):
						continue
					var i: int = yy * st.w + xx
					var inr: bool = xx >= r.x and xx <= r.z and yy >= r.y and yy <= r.w
					if ccm.has(i):
						if inr:
							bad = true
						elif xx >= r.x - 1 and xx <= r.z + 1 and yy >= r.y - 1 and yy <= r.w + 1:
							touch = true
					elif st.floor_m[i]:
						bad = true
					if bad:
						break
				if bad:
					break
			if bad or not touch:
				continue
			st.fill(st.roomm, r.x, r.y, r.z, r.w)
			st.add_floor_rect(r.x, r.y, r.z, r.w)
			st.rooms.append(r)
			added += 1
			break
	stats["attached_rooms"] = added


# --- R6: kładki ---

func _segment_bridges() -> void:
	var cw: int = st.cw
	var n := 0
	for s in st.segs:
		if s.axis == "h":
			var span: int = s.x1 - s.x0 - 2 * cw
			if span < 6:
				continue
			var cnt := maxi(1, span / int(cfg.get("bridge_every_h", 28)))
			for i in range(cnt):
				var t: int = s.bridge_t if (i == 0 and s.has("bridge_t")) else s.x0 + cw + (i + 1) * span / (cnt + 1) + rng.randi_range(-2, 2)
				if _place_bridge(s, t, true):
					n += 1
		else:
			var span: int = s.y1 - s.y0 - 2 * cw
			if span < 6:
				continue
			var cnt := maxi(1, span / int(cfg.get("bridge_every_v", 24)))
			for i in range(cnt):
				var t: int = s.bridge_t if (i == 0 and s.has("bridge_t")) else s.y0 + cw + (i + 1) * span / (cnt + 1) + rng.randi_range(-2, 2)
				if _place_bridge(s, t, false):
					n += 1
	stats["bridges"] = n


func _bridge_cells(s: Dictionary, t: int, horiz: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if horiz:
		for x in [t, t + 1]:
			for y in range(s.y0, s.y1 + 1):
				out.append(Vector2i(x, y))
	else:
		for y in [t, t + 1]:
			for x in range(s.x0, s.x1 + 1):
				out.append(Vector2i(x, y))
	return out


## Kładka przez odcinek: przesunięcie ±6 od t (exact — tylko t), poza strefą zakrętu, podłoga na obu końcach,
## odstęp od innych kładek ≥ bridge_min_spacing (exact: 2).
func _place_bridge(s: Dictionary, t: int, horiz: bool, exact := false) -> bool:
	var lo: int = s.x0 if horiz else s.y0
	var hi: int = s.x1 if horiz else s.y1
	for d in ([0] if exact else [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6]):
		var tt: int = t + d
		if tt < lo or tt + 1 > hi:
			continue
		var cells := _bridge_cells(s, tt, horiz)
		var ok := true
		for c in cells:
			var i: int = c.y * st.w + c.x
			if st.jz[i] or st.bridge_m[i]:
				ok = false
				break
		if not ok:
			continue
		var ends: Array[Vector2i] = []
		if horiz:   # kładka pionowa przez kanał poziomy
			for x in [tt, tt + 1]:
				ends.append(Vector2i(x, s.y0 - 1))
				ends.append(Vector2i(x, s.y1 + 1))
		else:
			for y in [tt, tt + 1]:
				ends.append(Vector2i(s.x0 - 1, y))
				ends.append(Vector2i(s.x1 + 1, y))
		for e in ends:
			if not st.in_map(e.x, e.y) or not st.floor_m[e.y * st.w + e.x] or st.water[e.y * st.w + e.x]:
				ok = false
				break
		if not ok:
			continue
		# Odstęp od innych kładek: bridge_min_spacing (kładka u-turnu — exact — tylko 2).
		var sp: int = 2 if exact else int(cfg.get("bridge_min_spacing", 10))
		for c in cells:
			if not ok:
				break
			for dy in range(-sp, sp + 1):
				for dx in range(-sp, sp + 1):
					if (dx == 0 and dy == 0) or not st.in_map(c.x + dx, c.y + dy):
						continue
					if st.bridge_m[(c.y + dy) * st.w + c.x + dx] and not cells.has(Vector2i(c.x + dx, c.y + dy)):
						ok = false
						break
				if not ok:
					break
		if not ok:
			continue
		for c in cells:
			st.bridge_m[c.y * st.w + c.x] = 1
		st.bridges.append({"cells": cells, "vertical": horiz, "crossing": false, "exact": exact})
		return true
	return false


## Zbędne kładki (decyzja usera: nie jedna obok drugiej): zwykła kładka (odcinek / przerwa chodnika — nie
## kładka przecięcia korytarza, u-turnu ani naprawy) bliżej niż bridge_min_spacing od innej kładki znika,
## jeśli bez niej oba brzegi dalej łączy inna droga (wtedy spójność całej podłogi się nie zmienia). Kładki
## przecięć powstają po kładkach przerw i nie sprawdzają odstępu — stąd pary.
func _drop_redundant_bridges() -> void:
	var sp := int(cfg.get("bridge_min_spacing", 10))
	var dropped := 0
	var changed := true
	while changed:
		changed = false
		var cands: Array = []
		for bi in range(st.bridges.size()):
			var b: Dictionary = st.bridges[bi]
			if b.get("crossing", false) or b.get("exact", false):
				continue
			var near := _bridge_gap(bi)
			if near < sp:
				cands.append([near, bi])
		cands.sort()
		for c in cands:
			var bi: int = c[1]
			var cells: Array = st.bridges[bi].cells
			for q in cells:
				st.bridge_m[q.y * st.w + q.x] = 0
			if _banks_connected(cells):
				st.bridges.remove_at(bi)
				dropped += 1
				changed = true
				break
			for q in cells:
				st.bridge_m[q.y * st.w + q.x] = 1
	stats["bridges_dropped"] = dropped


## Czy brzegi kładki (podłoga przy jej kratkach, po obu stronach kanału) łączy droga bez niej — BFS z jednego
## brzegu do pierwszej kratki drugiego (kładki kandydatki mają inną kładkę blisko, więc droga jest krótka).
func _banks_connected(cells: Array) -> bool:
	var horiz_canal := true   # kładka pionowa przez kanał poziomy: brzegi nad i pod nią
	var mn: Vector2i = cells[0]
	var mx: Vector2i = cells[0]
	for q in cells:
		mn = Vector2i(mini(mn.x, q.x), mini(mn.y, q.y))
		mx = Vector2i(maxi(mx.x, q.x), maxi(mx.y, q.y))
	horiz_canal = (mx.y - mn.y) >= (mx.x - mn.x)
	var a: Array[int] = []
	var b := {}
	for q in cells:
		var ends: Array = [q + Vector2i(0, -1), q + Vector2i(0, 1)] if horiz_canal else [q + Vector2i(-1, 0), q + Vector2i(1, 0)]
		for e: Vector2i in ends:
			if not st.in_map(e.x, e.y):
				continue
			var i: int = e.y * st.w + e.x
			if not st.floor_m[i] or (st.water[i] and not st.bridge_m[i]):
				continue
			if (e.y < mn.y) if horiz_canal else (e.x < mn.x):
				a.append(i)
			else:
				b[i] = true
	if a.is_empty() or b.is_empty():
		return true   # kładka bez brzegu z którejś strony nic nie łączy
	var seen := {}
	var q := a.duplicate()
	for i in a:
		seen[i] = true
	var head := 0
	while head < q.size():
		var c: int = q[head]
		head += 1
		if b.has(c):
			return true
		var x: int = c % st.w
		var y: int = c / st.w
		for d in DIRS:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if not st.in_map(nx, ny):
				continue
			var n: int = ny * st.w + nx
			if seen.has(n) or not st.floor_m[n] or (st.water[n] and not st.bridge_m[n]):
				continue
			seen[n] = true
			q.append(n)
	return false


## Najmniejszy odstęp (Czebyszew) między kratkami kładki `bi` a kratkami innych kładek.
func _bridge_gap(bi: int) -> int:
	var best := 1 << 30
	var mine: Array = st.bridges[bi].cells
	for bj in range(st.bridges.size()):
		if bj == bi:
			continue
		for a in mine:
			for b in st.bridges[bj].cells:
				best = mini(best, maxi(absi(a.x - b.x), absi(a.y - b.y)))
	return best


func _count(m: PackedByteArray) -> int:
	var n := 0
	for i in range(m.size()):
		if m[i]:
			n += 1
	return n


# --- R7: spójność ---

func _walkable() -> PackedByteArray:
	var m := st.new_mask()
	for i in range(st.w * st.h):
		m[i] = 1 if st.floor_m[i] and not (st.water[i] and not st.bridge_m[i]) else 0
	return m


func _component(walk: PackedByteArray, start: int) -> PackedByteArray:
	var seen := st.new_mask()
	if not walk[start]:
		return seen
	var q := PackedInt32Array([start])
	seen[start] = 1
	var head := 0
	while head < q.size():
		var c: int = q[head]
		head += 1
		var x: int = c % st.w
		var y: int = c / st.w
		for d in DIRS:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if st.in_map(nx, ny):
				var n: int = ny * st.w + nx
				if walk[n] and not seen[n]:
					seen[n] = 1
					q.append(n)
	return seen


## Kratka największej spójnej części chodliwej — korzeń spójności (kratka „najbliżej środka” potrafiła
## leżeć w małym odciętym kawałku: naprawa zamurowywała wtedy resztę mapy).
func _largest_component_cell() -> int:
	var walk := _walkable()
	var seen := st.new_mask()
	var best := -1
	var best_n := 0
	for i in range(st.w * st.h):
		if not walk[i] or seen[i]:
			continue
		var comp := _component(walk, i)
		var n := 0
		for j in range(comp.size()):
			if comp[j]:
				n += 1
				seen[j] = 1
		if n > best_n:
			best_n = n
			best = i
	return best


## Kratka sieci (chodnik / sala) najbliżej środka mapy.
func center_cell() -> int:
	var best := -1
	var bd := 1 << 30
	for i in range(st.w * st.h):
		if st.lanes[i] or st.hallm[i]:
			var d: int = absi(i % st.w - st.w / 2) + absi(i / st.w - st.h / 2)
			if d < bd:
				bd = d
				best = i
	return best


func _repair() -> void:
	var root := _largest_component_cell()
	if root < 0:
		return
	var fixed := 0
	var lost := 0
	var walled := 0
	var bridged := 0
	var given_up := st.new_mask()
	for _it in range(200):
		var walk := _walkable()
		var main := _component(walk, root)
		# Największy odcięty kawałek najpierw (te z pokojami nie czekają za drobnymi strzępami).
		var seen := st.new_mask()
		var piece := PackedByteArray()
		var piece_n := 0
		var seed_c := -1
		for i in range(st.w * st.h):
			if walk[i] and not main[i] and not given_up[i] and not seen[i]:
				var comp := _component(walk, i)
				var n := 0
				for k in range(comp.size()):
					if comp[k]:
						n += 1
						seen[k] = 1
				if n > piece_n:
					piece_n = n
					piece = comp
					seed_c = i
		if seed_c < 0:
			break
		if _bridge_connect(piece, main):
			bridged += 1
			continue
		var piece_c := _mask_cells(piece)
		var bb := Vector4i(1 << 30, 1 << 30, -1, -1)
		for c in piece_c:
			bb = Vector4i(mini(bb.x, c % st.w), mini(bb.y, c / st.w), maxi(bb.z, c % st.w), maxi(bb.w, c / st.w))
		var ctr := Vector2i((bb.x + bb.z) / 2, (bb.y + bb.w) / 2)
		var start: int = ctr.y * st.w + ctr.x if piece[ctr.y * st.w + ctr.x] else seed_c
		var tgt := st.new_mask()
		for i in range(st.w * st.h):
			tgt[i] = main[i] & (1 - st.service[i]) & (1 - st.water[i])
		var pf := _pf()
		pf.own = State.LocalSum.from_cells(piece_c, st.w)
		pf.own_sub = State.LocalSum.from_cells(_sub_cells(piece_c), st.w)
		pf.target = State.LocalSum.from_mask(tgt, st.w)
		pf.dt = st.distance_to(tgt)
		var path := pf.find(start % st.w, start / st.w)
		if path.is_empty():
			# Awaryjnie prosty L z kratki kawałka do najbliższej kratki głównej części.
			var cx: int = start % st.w
			var cy: int = start / st.w
			var bi := -1
			var bd := 1 << 30
			for i in range(st.w * st.h):
				if tgt[i]:
					var d: int = absi(i % st.w - cx) + absi(i / st.w - cy)
					if d < bd:
						bd = d
						bi = i
			if bi < 0:
				break
			var tx: int = bi % st.w
			var ty: int = bi / st.w
			path = PackedInt32Array()
			for x in range(mini(cx, tx), maxi(cx, tx) + 1):
				path.append(cy * st.w + x)
			for y in range(mini(cy, ty), maxi(cy, ty) + 1):
				path.append(y * st.w + tx)
			var through_corner := false
			for c in path:
				if st.jz_c[c]:
					through_corner = true
					break
			if through_corner:
				var has_room := false
				for c in piece_c:
					if st.roomm[c]:
						has_room = true
						break
				if has_room:
					lost += 1
					for c in piece_c:
						given_up[c] = 1
				else:
					# Kawałek chodnika bez pokoju, nie do podpięcia — zamurowany (kanał zostaje przy ścianie).
					for c in piece_c:
						if not st.water[c]:
							st.floor_m[c] = 0
							st.lanes[c] = 0
							st.corrm[c] = 0
							st.hallm[c] = 0
						elif st.bridge_m[c]:
							st.bridge_m[c] = 0   # kładka bez brzegów — znika razem z kawałkiem
					_drop_dead_bridges()
					walled += 1
				continue
		_carve(path)
		fixed += 1
	stats["repairs"] = fixed
	stats["repair_failed"] = lost
	stats["repair_walled"] = walled
	stats["repair_bridged"] = bridged


## Kładki, z których zniknęła choć jedna kratka (zamurowany kawałek), wypadają z listy.
func _drop_dead_bridges() -> void:
	var keep: Array[Dictionary] = []
	for b in st.bridges:
		var alive := true
		for c in b.cells:
			if not st.bridge_m[c.y * st.w + c.x]:
				alive = false
				break
		if alive:
			keep.append(b)
		else:
			for c in b.cells:
				st.bridge_m[c.y * st.w + c.x] = 0
	st.bridges = keep


## Kładka łącząca odcięty kawałek z główną częścią przez dzielący je kanał: odcinek, na którym jeden brzeg
## leży w kawałku, a drugi w głównej części (pozycja środkowa z możliwych).
func _bridge_connect(piece: PackedByteArray, main: PackedByteArray) -> bool:
	for s in st.segs:
		var horiz: bool = s.axis == "h"
		var lo: int = (s.x0 if horiz else s.y0) + 1
		var hi: int = (s.x1 if horiz else s.y1) - 2
		var cands: Array[int] = []
		for t in range(lo, hi + 1):
			var ok := true
			var in_piece := false
			var in_main := false
			for dt in [0, 1]:
				var a: Vector2i = Vector2i(t + dt, s.y0 - 1) if horiz else Vector2i(s.x0 - 1, t + dt)
				var b: Vector2i = Vector2i(t + dt, s.y1 + 1) if horiz else Vector2i(s.x1 + 1, t + dt)
				if not st.in_map(a.x, a.y) or not st.in_map(b.x, b.y):
					ok = false
					break
				var ia: int = a.y * st.w + a.x
				var ib: int = b.y * st.w + b.x
				if (piece[ia] and main[ib]) or (piece[ib] and main[ia]):
					in_piece = true
					in_main = true
				else:
					ok = false
			if ok and in_piece and in_main:
				cands.append(t)
		if cands.is_empty():
			continue
		var order: Array = cands.duplicate()
		var mid: int = cands[cands.size() / 2]
		order.sort_custom(func(x, y) -> bool: return absi(x - mid) < absi(y - mid))
		for t in order:
			if _place_bridge(s, t, horiz, true):
				return true
	return false


## Dźwignie bram: wolna kratka pokoju / sali osiągalna z wejścia bez przechodzenia przez bramy,
## ~18 kratek od bramy (wzorzec: krok 8 prototypu).
static func place_levers(state: State, entrance: Vector2i) -> void:
	var p := StructuredRoomPacker.new()
	p.st = state
	if state.gates.is_empty():
		return
	var walk := p._walkable()
	for g in state.gates:
		for c in g:
			if state.in_map(c.x, c.y):
				walk[c.y * state.w + c.x] = 0
	var reach := p._component(walk, entrance.y * state.w + entrance.x)
	for g in state.gates:
		var gc: Vector2i = g[1]
		var best := Vector2i(-1, -1)
		var bd := 1 << 30
		for i in range(state.w * state.h):
			if not reach[i] or not (state.roomm[i] or state.hallm[i]) or state.water[i] or state.lanes[i] or state.service[i]:
				continue
			var d: int = absi(absi(i % state.w - gc.x) + absi(i / state.w - gc.y) - 18)
			if d < bd:
				bd = d
				best = Vector2i(i % state.w, i / state.w)
		state.levers.append(best)   # wyrównane z gates — (-1, -1) = brak miejsca
