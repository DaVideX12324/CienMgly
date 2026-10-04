extends RefCounted

## Kanały ścieków (flaga canal_count > 0): proste kanały przez ciągłą podłogę pokoi i korytarzy.
## Poziomy: H_BAND rzędów (lico brzegu + kwas), pionowy: V_BAND kolumn kwasu. Po obu stronach brzeg
## z podłogi; kanał kończy się na ścianie (wpływa w mur) albo w podłodze. Grid bez zmian — wynik to
## CanalLayout (nakładka). Kładki: po jednej na kanał + dodatkowe, aż każdy obszar podłogi (>= MIN_AREA)
## łączy się z wejściem; kanał, którego nie da się tak podpiąć, jest usuwany.

const CanalLayoutScript = preload("../core/canal_layout.gd")

const H_BAND := 4
const V_BAND := 3
const PORTAL_MARGIN := 3
const MIN_AREA := 6
const BRIDGE_END_MARGIN := 2


static func run(ctx: GenerationContext, flags: GenerationFlags) -> CanalLayout:
	var layout: CanalLayout = CanalLayoutScript.new()
	if flags == null or flags.canal_count <= 0:
		return layout
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([ctx.seed_value, "canals"])
	var forbidden := {}
	for p in ctx.portal_zone:
		for dy in range(-PORTAL_MARGIN, PORTAL_MARGIN + 1):
			for dx in range(-PORTAL_MARGIN, PORTAL_MARGIN + 1):
				forbidden[p + Vector2i(dx, dy)] = true

	var segments: Array[Dictionary] = []
	var attempts := flags.canal_count * 60
	while segments.size() < flags.canal_count and attempts > 0:
		attempts -= 1
		var seg := _try_segment(ctx, layout, forbidden, rng.randi() % 2 == 0, rng, maxi(flags.canal_min_length, 6))
		if seg.is_empty():
			continue
		segments.append(seg)
		for p in _band_cells(seg):
			layout.water[p] = true

	# Kładki co canal_bridge_spacing kratek wzdłuż kanału (co najmniej jedna), potem dokładanie /
	# usuwanie kanałów aż do spójności.
	var spacing := maxi(flags.canal_bridge_spacing, 6)
	for seg in segments:
		var last := int(seg.a) - spacing / 2 - rng.randi_range(0, spacing / 2)
		var placed := false
		for cand in _bridge_candidates(ctx, layout, seg):
			if int(cand.t) >= last + spacing:
				layout.bridges.append(cand)
				layout.rebuild_blocked()
				last = int(cand.t)
				placed = true
		if not placed:
			var cands := _bridge_candidates(ctx, layout, seg)
			if not cands.is_empty():
				layout.bridges.append(cands[rng.randi() % cands.size()])
	layout.rebuild_blocked()
	_ensure_connected(ctx, layout, segments, rng)
	_mark_dry(layout, segments, flags.canal_dry_chance, rng)
	return layout


static func _floorish(ctx: GenerationContext, p: Vector2i) -> bool:
	return int(ctx.grid.get(p, CellType.WALL)) == CellType.FLOOR


## Oś kanału: dla każdego położenia pasa najdłuższy odcinek, w którym pas i oba brzegi leżą na podłodze;
## wybór losowy spośród TOP_CHOICES najdłuższych (dłuższe kanały przez pokoje i korytarze).
const TOP_CHOICES := 4


static func _try_segment(ctx: GenerationContext, layout: CanalLayout, forbidden: Dictionary, vertical: bool, rng: RandomNumberGenerator, min_len: int) -> Dictionary:
	var band := V_BAND if vertical else H_BAND
	var span := ctx.width if vertical else ctx.height       # wymiar poprzeczny (położenie pasa)
	var length := ctx.height if vertical else ctx.width     # wymiar wzdłuż kanału
	if span < band + 6:
		return {}
	var found: Array[Dictionary] = []
	for c0 in range(2, span - band - 2):
		var best := Vector2i(-1, -1)
		var run_start := -1
		for t in range(1, length):
			var ok := t < length - 1 and _column_ok(ctx, layout, forbidden, vertical, c0, band, t)
			if ok and run_start < 0:
				run_start = t
			if not ok and run_start >= 0:
				if best.x < 0 or t - run_start > best.y - best.x + 1:
					best = Vector2i(run_start, t - 1)
				run_start = -1
		if best.x >= 0 and best.y - best.x + 1 >= min_len:
			found.append({"vertical": vertical, "c0": c0, "a": best.x, "b": best.y, "len": best.y - best.x + 1})
	if found.is_empty():
		return {}
	found.sort_custom(func(x, y): return int(x.len) > int(y.len))
	return found[rng.randi() % mini(TOP_CHOICES, found.size())]


## Przekrój kanału w miejscu t: pas na podłodze (albo przecina inny kanał), brzegi na podłodze, bez stref
## portali i bez równoległego kanału tuż obok (odstęp brzegu >= 2).
static func _column_ok(ctx: GenerationContext, layout: CanalLayout, forbidden: Dictionary, vertical: bool, c0: int, band: int, t: int) -> bool:
	var crossing := false
	for k in range(band):
		var p := _cell(vertical, c0 + k, t)
		if not _floorish(ctx, p) or forbidden.has(p):
			return false
		if layout.water.has(p):
			crossing = true
	for k in [-1, band]:
		var bank := _cell(vertical, c0 + k, t)
		if not _floorish(ctx, bank) or forbidden.has(bank):
			return false
	if not crossing:
		for k in [-2, band + 1]:
			if layout.water.has(_cell(vertical, c0 + k, t)):
				return false
	return true


## Kratka w układzie kanału: pionowy — (poprzeczna = x, wzdłuż = y), poziomy — odwrotnie.
static func _cell(vertical: bool, across: int, along: int) -> Vector2i:
	return Vector2i(across, along) if vertical else Vector2i(along, across)


static func _band_cells(seg: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var band := V_BAND if seg.vertical else H_BAND
	for t in range(int(seg.a), int(seg.b) + 1):
		for k in range(band):
			out.append(_cell(seg.vertical, int(seg.c0) + k, t))
	return out


## Kładki dla odcinka: pionowa (2 × H_BAND+2) przez kanał poziomy, pozioma (V_BAND+2 × 2) przez pionowy.
## Oba końce na zwykłej podłodze (nie kanał), pas pod kładką tylko z tego kanału (bez skrzyżowań).
static func _bridge_candidates(ctx: GenerationContext, layout: CanalLayout, seg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var vertical: bool = seg.vertical
	var band := V_BAND if vertical else H_BAND
	var c0: int = seg.c0
	for t in range(int(seg.a) + BRIDGE_END_MARGIN, int(seg.b) - BRIDGE_END_MARGIN):
		var ok := true
		for dt in range(2):
			for k in [-1, band]:
				var bank := _cell(vertical, c0 + k, t + dt)
				if not _floorish(ctx, bank) or layout.water.has(bank) or layout.bridge_cells.has(bank):
					ok = false
			# bez skrzyżowania z innym kanałem w pasie pod kładką i obok niej
			for k in range(band):
				for side in [-1, 2]:
					var q := _cell(vertical, c0 + k, t + side)
					if not layout.water.has(q):
						ok = false
		if not ok:
			continue
		var rect := Rect2i(c0 - 1, t, band + 2, 2) if vertical else Rect2i(t, c0 - 1, 2, band + 2)
		var overlaps := false
		for b in layout.bridges:
			if (b.rect as Rect2i).grow(1).intersects(rect):
				overlaps = true
		if not overlaps:
			out.append({"rect": rect, "vertical": not vertical, "t": t})
	return out


## Spójność: każdy obszar chodliwy (>= MIN_AREA) połączony z wejściem — dokładane kładki, a gdy żadna
## nie łączy, usuwany kanał graniczący z odciętym obszarem.
static func _ensure_connected(ctx: GenerationContext, layout: CanalLayout, segments: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for _i in 64:
		var comp := _components(ctx, layout)
		var labels: Dictionary = comp.labels
		var start: Vector2i = ctx.entrance_pos
		if not labels.has(start) and not labels.is_empty():
			start = labels.keys()[0]
		if not labels.has(start):
			return
		var main_id: int = labels[start]
		var cut_id := -1
		for id in comp.sizes:
			if id != main_id and int(comp.sizes[id]) >= MIN_AREA:
				cut_id = id
				break
		if cut_id < 0:
			return
		# kładka łącząca odcięty obszar z głównym
		var added := false
		for seg in segments:
			var cands := _bridge_candidates(ctx, layout, seg)
			cands.shuffle()
			for cand in cands:
				var ends := _bridge_ends(cand)
				var la: int = labels.get(ends[0], -1)
				var lb: int = labels.get(ends[1], -1)
				if (la == main_id and lb == cut_id) or (la == cut_id and lb == main_id):
					layout.bridges.append(cand)
					layout.rebuild_blocked()
					added = true
					break
			if added:
				break
		if added:
			continue
		# brak kładki — usuń kanał graniczący z odciętym obszarem
		var removed := false
		for si in range(segments.size()):
			var touches := false
			for p in _band_cells(segments[si]):
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if labels.get(p + d, -1) == cut_id:
						touches = true
			if touches:
				for p in _band_cells(segments[si]):
					layout.water.erase(p)
				var keep: Array[Dictionary] = []
				for b in layout.bridges:
					var on_seg := false
					for p in _band_cells(segments[si]):
						if (b.rect as Rect2i).has_point(p):
							on_seg = true
							break
					if not on_seg:
						keep.append(b)
				layout.bridges = keep
				segments.remove_at(si)
				layout.rebuild_blocked()
				removed = true
				break
		if not removed:
			return


## Puste koryto: sieci kanałów (odcinki połączone skrzyżowaniem) z szansą `chance` bez kwasu — cała sieć
## jednego rodzaju, żeby na skrzyżowaniu nie stykał się kwas z suchym dnem.
static func _mark_dry(layout: CanalLayout, segments: Array[Dictionary], chance: float, rng: RandomNumberGenerator) -> void:
	if chance <= 0.0 or segments.is_empty():
		return
	var cells: Array[Dictionary] = []
	for seg in segments:
		var d := {}
		for p in _band_cells(seg):
			d[p] = true
		cells.append(d)
	var group: Array[int] = []
	for i in range(segments.size()):
		group.append(i)
	var find := func(i: int) -> int:
		while group[i] != i:
			i = group[i]
		return i
	for i in range(segments.size()):
		for j in range(i + 1, segments.size()):
			for p in cells[i]:
				if cells[j].has(p):
					group[find.call(j)] = find.call(i)
					break
	var dry_root := {}
	for i in range(segments.size()):
		var r: int = find.call(i)
		if not dry_root.has(r):
			dry_root[r] = rng.randf() < chance
		if dry_root[r]:
			for p in cells[i]:
				layout.dry[p] = true


## Końce kładki (kratki brzegów po obu stronach kanału).
static func _bridge_ends(b: Dictionary) -> Array[Vector2i]:
	var r: Rect2i = b.rect
	if b.vertical:
		return [r.position, Vector2i(r.position.x, r.end.y - 1)]
	return [r.position, Vector2i(r.end.x - 1, r.position.y)]


## Obszary chodliwe (podłoga bez zablokowanego kanału), 4-sąsiedztwo: {labels: p -> id, sizes: id -> n}.
static func _components(ctx: GenerationContext, layout: CanalLayout) -> Dictionary:
	var labels := {}
	var sizes := {}
	var next_id := 0
	for y in range(ctx.height):
		for x in range(ctx.width):
			var s := Vector2i(x, y)
			if labels.has(s) or not GridUtils.is_walkable(ctx.grid, s) or layout.blocked.has(s):
				continue
			var queue: Array[Vector2i] = [s]
			labels[s] = next_id
			var head := 0
			while head < queue.size():
				var p := queue[head]
				head += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if labels.has(q) or not GridUtils.is_walkable(ctx.grid, q) or layout.blocked.has(q):
						continue
					labels[q] = next_id
					queue.append(q)
			sizes[next_id] = queue.size()
			next_id += 1
	return {"labels": labels, "sizes": sizes}
