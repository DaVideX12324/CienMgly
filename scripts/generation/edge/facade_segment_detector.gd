class_name FacadeSegmentDetector
extends RefCounted

const EdgeKind = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_kind.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const FacadeSegment = preload("res://modules/quiz_rpg/scripts/generation/edge/facade_segment.gd")

## Wykrywa ścisłe, poziome segmenty (ten sam y, kolejne x: x, x+1, x+2...)
## i nadaje komórkom w edges odpowiedni segment_kind (SINGLE, START, MIDDLE, END).
static func detect(candidate_cells: Array[Vector2i], edges: Dictionary) -> Array[FacadeSegment]:
	var by_y: Dictionary = {}
	for pos in candidate_cells:
		if not by_y.has(pos.y):
			by_y[pos.y] = []
		by_y[pos.y].append(pos.x)

	var sorted_ys: Array = by_y.keys()
	sorted_ys.sort()

	var result_segments: Array[FacadeSegment] = []

	for y in sorted_ys:
		var xs: Array = by_y[y]
		xs.sort()

		var cur_run: Array[int] = []
		for x in xs:
			if cur_run.is_empty():
				cur_run.append(x)
			elif x == cur_run[-1] + 1:
				cur_run.append(x)
			else:
				_commit_run(y, cur_run, edges, result_segments)
				cur_run = [x]

		if not cur_run.is_empty():
			_commit_run(y, cur_run, edges, result_segments)

	return result_segments


static func _commit_run(y: int, xs: Array[int], edges: Dictionary, out_segments: Array[FacadeSegment]) -> void:
	if xs.is_empty():
		return

	var seg := FacadeSegment.new()
	seg.y = y
	seg.x_start = xs[0]
	seg.x_end = xs[-1]
	for x in xs:
		seg.cells.append(Vector2i(x, y))

	var seg_idx := out_segments.size()
	out_segments.append(seg)

	var len := xs.size()
	for i in range(len):
		var p := Vector2i(xs[i], y)
		if edges.has(p):
			var ctx: EdgeContext = edges[p]
			ctx.segment_index = seg_idx
			if len == 1:
				ctx.segment_kind = EdgeKind.SegmentKind.SINGLE
			elif i == 0:
				ctx.segment_kind = EdgeKind.SegmentKind.START
			elif i == len - 1:
				ctx.segment_kind = EdgeKind.SegmentKind.END
			else:
				ctx.segment_kind = EdgeKind.SegmentKind.MIDDLE


# =========================================================================
# LEGACY LOOKUP HELPERS (Osobne zapytania pomocnicze, niebędące definicją segmentu)
# =========================================================================

## Sprawdza czy kolumna sąsiednia x posiada stopę fasady w odległości abs(fy - y) <= tolerance (domyślnie 1).
static func has_same_y(facade_cols: Dictionary, x: int, y: int, tolerance: int = 1) -> bool:
	if not facade_cols.has(x):
		return false
	for fy in facade_cols[x]:
		if abs(fy - y) <= tolerance:
			return true
	return false


## Zwraca pierwsze y stopy fasady w kolumnie x w odległości abs(fy - y) <= tolerance (domyślnie 4), lub -1.
static func find_adjacent_facade_y(facade_cols: Dictionary, x: int, y: int, tolerance: int = 4) -> int:
	if not facade_cols.has(x):
		return -1
	for fy in facade_cols[x]:
		if abs(fy - y) <= tolerance:
			return fy
	return -1


## Sprawdza kontekst ściany bocznej B obok schodka (FAZA 2.5, tolerance = 2).
static func has_side_wall_context(facade_cols: Dictionary, x: int, y: int, tolerance: int = 2) -> bool:
	if not facade_cols.has(x):
		return false
	for fy in facade_cols[x]:
		if abs(fy - y) <= tolerance:
			return true
	return false
