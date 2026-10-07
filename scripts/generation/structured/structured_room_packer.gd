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
var cross_p := PackedInt32Array()
var stats := {}


static func run(state: State, seed_val: int, config: Dictionary) -> Dictionary:
	var p := StructuredRoomPacker.new()
	p.st = state
	p.cfg = config
	p.rng = RandomNumberGenerator.new()
	p.rng.seed = hash([seed_val, "structured_rooms"])
	p.cross_p = state.prefix(state.cross_any)
	p._service_corridors()
	p._lane_gaps()
	p._rooms()
	p._room_links()
	p._complex_loops()
	p._attached_rooms()
	p._segment_bridges()
	p._repair()
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

## Kładka tam, gdzie środek korytarza jest na wodzie: kratki wody w 3 × 3 wokół takich środków.
func _crossing_bridges(centers: PackedInt32Array) -> void:
	var wc := {}
	for c in centers:
		if not st.water[c]:
			continue
		var x: int = c % st.w
		var y: int = c / st.w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var nx: int = x + dx
				var ny: int = y + dy
				if st.in_map(nx, ny) and st.water[ny * st.w + nx]:
					wc[Vector2i(nx, ny)] = true
	if wc.is_empty():
		return
	var cells: Array[Vector2i] = []
	for p in wc:
		cells.append(p)
		st.bridge_m[p.y * st.w + p.x] = 1
	cells.sort()
	st.bridges.append({"cells": cells, "vertical": bool(st.cross_h[cells[0].y * st.w + cells[0].x]), "crossing": true})


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
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var i: int = (y + dy) * st.w + x + dx
				if not cxm[i] and not st.water[i]:
					st.add_floor(x + dx, y + dy)
					st.service[i] = 1
		if not cxm[c]:
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

## Strona chodnika urywa się (szerokość 0) na dłuższym odcinku, a druga strona ma chodnik. Przy początku
## odcinka 0: u-turn (szansa lane_gap_bypass_chance) — tunel z końca chodnika przez mur, wzdłuż kanału za
## ścianą i z powrotem do kanału dalej w odcinku 0, tam kładka na drugą stronę (gdzie jest ścieżka); albo
## zwykła kładka przy końcu chodnika. Przy końcu odcinka 0 kładka z szansą 0,5 (chodnik i tak łączy się na
## końcu odcinka kanału).
func _lane_gaps() -> void:
	var chance := float(cfg.get("lane_gap_bypass_chance", 0.5))
	var uturn := 0
	var bridged := 0
	var lost := 0
	for s in st.segs:
		var horiz: bool = s.axis == "h"
		for g in s.get("lane_gaps", []):
			var ok := false
			var before: bool = g.get("before", true)
			var after: bool = g.get("after", true)
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
	stats["gap_uturn"] = uturn
	stats["gap_bridged"] = bridged
	stats["gap_unresolved"] = lost


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
		if _near_foreign(c.x, c.y, cells):
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


## Obca podłoga (poza siecią kanałów i chodników oraz samym u-turnem) bliżej niż ściana + 1.
func _near_foreign(x: int, y: int, own: Dictionary) -> bool:
	var rx: int = st.wall_v + 1
	var ry: int = st.wall_h + 1
	for yy in range(maxi(0, y - ry), mini(st.h - 1, y + ry) + 1):
		for xx in range(maxi(0, x - rx), mini(st.w - 1, x + rx) + 1):
			var i: int = yy * st.w + xx
			if st.floor_m[i] and not st.cross_any[i] and not own.has(Vector2i(xx, yy)):
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
	for _a in range(target * 40):
		if placed.size() >= target:
			break
		var rw := rng.randi_range(int(rw_r[0]), int(rw_r[1]))
		var rh := rng.randi_range(int(rh_r[0]), int(rh_r[1]))
		if st.w - M - rw <= M or st.h - M - rh <= M + 2:
			break
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


func _room_links() -> void:
	var link := st.new_mask()
	for i in range(st.w * st.h):
		link[i] = st.lanes[i] | st.hallm[i]
	var link_sum := State.LocalSum.from_mask(link, st.w)
	var link_dt: PackedInt32Array = st.distance_to(link)
	var linked := 0
	var free_rooms: Array[Vector4i] = st.rooms.duplicate()
	for r in free_rooms:
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
			var cnt := maxi(1, span / 20)
			for i in range(cnt):
				var t: int = s.bridge_t if (i == 0 and s.has("bridge_t")) else s.x0 + cw + (i + 1) * span / (cnt + 1) + rng.randi_range(-2, 2)
				if _place_bridge(s, t, true):
					n += 1
		else:
			var span: int = s.y1 - s.y0 - 2 * cw
			if span < 6:
				continue
			var cnt := maxi(1, span / 18)
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


## Kładka przez odcinek: przesunięcie ±6 od t (exact — tylko t), poza strefą zakrętu, podłoga na obu końcach, odstęp ≥ 2.
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
		for c in cells:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if (dx == 0 and dy == 0) or not st.in_map(c.x + dx, c.y + dy):
						continue
					if st.bridge_m[(c.y + dy) * st.w + c.x + dx] and not cells.has(Vector2i(c.x + dx, c.y + dy)):
						ok = false
		if not ok:
			continue
		for c in cells:
			st.bridge_m[c.y * st.w + c.x] = 1
		st.bridges.append({"cells": cells, "vertical": horiz, "crossing": false})
		return true
	return false


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


## Kratka sieci (chodnik / sala) najbliżej środka mapy — korzeń spójności.
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
	var root := center_cell()
	if root < 0:
		return
	var fixed := 0
	var lost := 0
	var walled := 0
	var given_up := st.new_mask()
	for _it in range(40):
		var walk := _walkable()
		var main := _component(walk, root)
		var seed_c := -1
		for i in range(st.w * st.h):
			if walk[i] and not main[i] and not given_up[i]:
				seed_c = i
				break
		if seed_c < 0:
			break
		var piece := _component(walk, seed_c)
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
			# Awaryjnie prosty L do najbliższej kratki głównej części.
			var cx: int = ctr.x
			var cy: int = ctr.y
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
					walled += 1
				continue
		_carve(path)
		fixed += 1
	stats["repairs"] = fixed
	stats["repair_failed"] = lost
	stats["repair_walled"] = walled


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
		if best.x >= 0:
			state.levers.append(best)
