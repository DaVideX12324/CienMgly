extends RefCounted

## A* środka korytarza (3 kratki) dla układu structured (wzorzec: proto_layout.py `astar`, plan R4 / R5):
## - środek nie wchodzi w dylatację obcej podłogi o (wall_v + 2, wall_h + 2) — korytarz idzie wyłącznie
##   przez lity mur ze ścianą od każdej podłogi poza własną (`own`); licznik st.fcnt minus własne kratki;
## - cel = pierścień: dylatacja celu o (wall_v + 3, wall_h + 3) poza zakazem; z pierścienia jedno proste
##   wejście prostopadle do celu (drzwi przez ścianę), bez przecinania innej podłogi;
## - przy kanale poziomym (strefa ZH) tylko ruch pionowy, przy pionowym tylko poziomy, węzeł — zakaz;
##   środek nie na wodzie przy zakręcie / węźle (JZ_C);
## - koszt: 1 + 4 za skręt + bias; heurystyka = odległość Manhattana do celu minus zasięg pierścienia.

const State = preload("core/structured_state.gd")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const INF := 1 << 30
const MAX_POPS := 600000

var st: State
var own: State.LocalSum
var own_sub: State.LocalSum
var target: State.LocalSum
var dt := PackedInt32Array()
var has_bias := false
var bias_rect := Vector4i()       # kratki w nim: 0, poza: +3
var bias_side := -1               # 0 / 1 = strona kanału bez kary (poza nią +50)
var bias_horiz := true
var bias_canal := Vector4i()
var start_ok := Vector4i(1, 1, 0, 0)       # pusty, gdy x0 > x1
var zone_skip_rect := Vector4i(1, 1, 0, 0)
var zone_skip_canal := Vector4i(1, 1, 0, 0)
var extra_rect := Vector4i(1, 1, 0, 0)
var extra_mask: State.LocalSum
var cross_p := PackedInt32Array()


static func empty_sum() -> State.LocalSum:
	return State.LocalSum.new()


func _init(state: State) -> void:
	st = state
	own = empty_sum()
	own_sub = empty_sum()
	target = empty_sum()
	extra_mask = empty_sum()


static func _in(r: Vector4i, x: int, y: int) -> bool:
	return x >= r.x and x <= r.z and y >= r.y and y <= r.w


func _forb(i: int, x: int, y: int) -> bool:
	var rx: int = st.wall_v + 2
	var ry: int = st.wall_h + 2
	return st.fcnt[i] - own_sub.count(x - rx, y - ry, x + rx, y + ry) > 0


func _ring(i: int, x: int, y: int) -> bool:
	var rx: int = st.wall_v + 3
	var ry: int = st.wall_h + 3
	return target.count(x - rx, y - ry, x + rx, y + ry) > 0 and not _forb(i, x, y)


func _zone_skip(x: int, y: int) -> bool:
	if zone_skip_rect.x > zone_skip_rect.z or not _in(zone_skip_rect, x, y):
		return false
	var rx: int = st.wall_v + 2
	var ry: int = st.wall_h + 2
	var n: int = st.box(cross_p, x - rx, y - ry, x + rx, y + ry)
	# kratki samego kanału (zawsze w cross_any) w oknie nie liczą się
	var ax0 := maxi(x - rx, zone_skip_canal.x)
	var ay0 := maxi(y - ry, zone_skip_canal.y)
	var ax1 := mini(x + rx, zone_skip_canal.z)
	var ay1 := mini(y + ry, zone_skip_canal.w)
	if ax0 <= ax1 and ay0 <= ay1:
		n -= (ax1 - ax0 + 1) * (ay1 - ay0 + 1)
	return n <= 0


func _bias(x: int, y: int) -> int:
	var b := 0 if _in(bias_rect, x, y) else 3
	var on_side := false
	if bias_horiz:
		on_side = y < bias_canal.y if bias_side == 0 else y > bias_canal.w
	else:
		on_side = x < bias_canal.x if bias_side == 0 else x > bias_canal.z
	return b + (0 if on_side else 50)


## Ścieżka środków korytarza od (sx, sy) do celu (indeksy kratek, z prostym wejściem); pusta = brak drogi.
func find(sx: int, sy: int) -> PackedInt32Array:
	var W: int = st.w
	var H: int = st.h
	var M: int = st.margin
	var hr: int = (st.wall_v + 3) + (st.wall_h + 3)
	var n_states := W * H * 5
	var best := PackedInt32Array()
	best.resize(n_states)
	best.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n_states)
	prev.fill(-1)
	var heap := PackedInt64Array()
	var s0: int = (sy * W + sx) * 5 + 4
	best[s0] = 0
	_push(heap, _h(sy * W + sx, hr), s0)
	var pops := 0
	while not heap.is_empty():
		pops += 1
		if pops > MAX_POPS:
			return PackedInt32Array()
		var top := _pop(heap)
		var s: int = top & 0xFFFFF
		var i: int = s / 5
		var dI: int = s % 5
		var g: int = best[s]
		if (top >> 20) != g + _h(i, hr):
			continue   # nieaktualny wpis
		var x: int = i % W
		var y: int = i / W
		if _ring(i, x, y) and not own.has(x, y):
			var entry := _entry(x, y)
			if not entry.is_empty():
				var path := PackedInt32Array()
				var k := s
				while k >= 0:
					path.append(k / 5)
					k = prev[k]
				path.reverse()
				path.append_array(entry)
				return path
		for ni in range(4):
			var d := DIRS[ni]
			var nx := x + d.x
			var ny := y + d.y
			if nx < M + 1 or ny < M + 1 or nx >= W - M - 1 or ny >= H - M - 1:
				continue
			var n := ny * W + nx
			var n_own := own.has(nx, ny)
			if not n_own:
				if _forb(n, nx, ny) and not _in(start_ok, nx, ny):
					continue
				if _in(extra_rect, nx, ny) or extra_mask.has(nx, ny):
					continue
				if st.jz_c[n]:
					continue
				# Pierścień celu NIE zwalnia z zasady przecięć (inaczej korytarz sunie wzdłuż chodnika kanału
				# o kratkę od niego, a przejścia czyszczące zjadają go do 1 kratki).
				if not _zone_skip(nx, ny):
					var zh: int = st.zh[n]
					var zv: int = st.zv[n]
					if zh and zv:
						continue          # węzeł kanałów — nie przez skrzyżowanie
					if zh and d.x != 0:
						continue          # przy kanale poziomym tylko ruch pionowy
					if zv and d.y != 0:
						continue
			var ng := g + 1 + (4 if dI != 4 and dI != ni else 0) + (_bias(nx, ny) if has_bias else 0)
			var ns := n * 5 + ni
			if ng < best[ns]:
				best[ns] = ng
				prev[ns] = s
				_push(heap, ng + _h(n, hr), ns)
	return PackedInt32Array()


func _h(i: int, hr: int) -> int:
	if dt.is_empty():
		return 0
	return maxi(0, dt[i] - hr)


## Proste wejście z pierścienia do celu: najkrótszy odcinek prostopadły, który nie przecina innej podłogi.
func _entry(x: int, y: int) -> PackedInt32Array:
	var best_l := -1
	var best_d := Vector2i.ZERO
	for d in DIRS:
		for L in range(1, st.wall_h + 6):
			var nx := x + d.x * L
			var ny := y + d.y * L
			if not st.in_map(nx, ny):
				break
			if target.has(nx, ny):
				if best_l < 0 or L < best_l:
					best_l = L
					best_d = d
				break
			if st.floor_m[ny * st.w + nx]:
				break
	var out := PackedInt32Array()
	if best_l < 0:
		return out
	for k in range(1, best_l):
		out.append((y + best_d.y * k) * st.w + x + best_d.x * k)
	if out.is_empty():
		out.append(y * st.w + x)   # cel tuż obok pierścienia: ścieżka bez dodatkowych kratek
	return out


static func _push(heap: PackedInt64Array, key: int, s: int) -> void:
	heap.append((key << 20) | s)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if heap[p] <= heap[i]:
			break
		var t := heap[p]
		heap[p] = heap[i]
		heap[i] = t
		i = p


static func _pop(heap: PackedInt64Array) -> int:
	var top := heap[0]
	var last := heap[heap.size() - 1]
	heap.resize(heap.size() - 1)
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var l := 2 * i + 1
		if l >= n:
			break
		var c := l
		if l + 1 < n and heap[l + 1] < heap[l]:
			c = l + 1
		if heap[i] <= heap[c]:
			break
		var t := heap[c]
		heap[c] = heap[i]
		heap[i] = t
		i = c
	return top
