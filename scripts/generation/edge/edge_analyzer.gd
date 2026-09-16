class_name EdgeAnalyzer
extends RefCounted

const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const EdgeKind = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_kind.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const FacadeSegmentDetector = preload("res://modules/quiz_rpg/scripts/generation/edge/facade_segment_detector.gd")
const FacadeHeightResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/facade_height_resolver.gd")
const EdgeAnalysisResult = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_analysis_result.gd")

## Mierzy głębokość litej ściany w danym kierunku od komórki podłogi (§9.5).
static func measure_solid_depth(
	ctx: GenerationContext,
	floor_pos: Vector2i,
	direction: Vector2i,
	max_depth: int = 6
) -> int:
	var depth := 0
	for offset in range(1, max_depth + 1):
		var check_pos := floor_pos + direction * offset
		if GridUtils.is_walkable(ctx.grid, check_pos):
			break
		depth += 1
	return depth


## Szybka, czysto lokalna analiza 3x3 dla prostych fixture'ów punktowych.
static func analyze_local_cell(ctx: GenerationContext, pos: Vector2i) -> EdgeContext:
	var edge := EdgeContext.new()
	edge.pos = pos
	_populate_neighborhood(ctx, edge)

	if ctx.portal_zone.has(pos):
		edge.edge_kind = EdgeKind.Kind.PORTAL_CLEAR
		edge.in_portal_zone = true
		return edge

	if GridUtils.is_walkable(ctx.grid, pos):
		edge.edge_kind = EdgeKind.Kind.FLOOR
		return edge

	# Komórka ściany — lokalna klasyfikacja
	if edge.n_floor and not GridUtils.is_walkable(ctx.grid, pos + Vector2i(0, 1)):
		edge.edge_kind = EdgeKind.Kind.TOP_RIM
		edge.orientation = EdgeKind.Orientation.NORTH
		return edge

	if edge.e_floor and not edge.w_floor:
		edge.edge_kind = EdgeKind.Kind.SIDE_WALL
		edge.orientation = EdgeKind.Orientation.EAST
		return edge
	elif edge.w_floor and not edge.e_floor:
		edge.edge_kind = EdgeKind.Kind.SIDE_WALL
		edge.orientation = EdgeKind.Orientation.WEST
		return edge

	if edge.nw_floor and not edge.ne_floor and not edge.w_floor and not edge.n_floor:
		edge.edge_kind = EdgeKind.Kind.INNER_CORNER
		edge.orientation = EdgeKind.Orientation.NORTH_WEST
		return edge
	elif edge.ne_floor and not edge.nw_floor and not edge.e_floor and not edge.n_floor:
		edge.edge_kind = EdgeKind.Kind.INNER_CORNER
		edge.orientation = EdgeKind.Orientation.NORTH_EAST
		return edge
	elif edge.sw_floor and not edge.se_floor and not edge.w_floor and not edge.s_floor:
		edge.edge_kind = EdgeKind.Kind.INNER_CORNER
		edge.orientation = EdgeKind.Orientation.SOUTH_WEST
		return edge
	elif edge.se_floor and not edge.sw_floor and not edge.e_floor and not edge.s_floor:
		edge.edge_kind = EdgeKind.Kind.INNER_CORNER
		edge.orientation = EdgeKind.Orientation.SOUTH_EAST
		return edge

	edge.edge_kind = EdgeKind.Kind.SOLID_FILL
	return edge


## Główna analiza geometryczna całej siatki mapy (Wariant A) zgodnie z §9.3 i §9.6.
static func analyze(ctx: GenerationContext) -> EdgeAnalysisResult:
	var width := ctx.width
	var height := ctx.height
	var grid := ctx.grid
	var edges: Dictionary = {}

	# Przebieg 1: Inicjalizacja kontekstów 3x3 dla wszystkich komórek w porządku (y, x)
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var edge := EdgeContext.new()
			edge.pos = pos
			_populate_neighborhood(ctx, edge)

			if ctx.portal_zone.has(pos):
				edge.edge_kind = EdgeKind.Kind.PORTAL_CLEAR
				edge.in_portal_zone = true
			elif GridUtils.is_walkable(grid, pos):
				edge.edge_kind = EdgeKind.Kind.FLOOR

			edges[pos] = edge

	# Przebieg 2: Identyfikacja stóp fasad (pierwszy wiersz podłogi pod sufitem o głębokości >= 2)
	var facade_cols: Dictionary = {} # x -> Array of y
	var facade_candidates: Array[Vector2i] = []

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if GridUtils.is_walkable(grid, pos) and not GridUtils.is_walkable(grid, pos + Vector2i(0, -1)):
				if not GridUtils.is_walkable(grid, pos + Vector2i(0, -2)):
					if not facade_cols.has(x):
						facade_cols[x] = []
					facade_cols[x].append(y)
					facade_candidates.append(pos)

	# Przebieg 3: Ścisła segmentacja pozioma fasad
	FacadeSegmentDetector.detect(facade_candidates, edges)

	# Przebieg 4: Klasyfikacja fasad w kanonicznej kolejności kolumn (x rosnąco, y rosnąco)
	var sorted_xs: Array = facade_cols.keys()
	sorted_xs.sort()

	for x in sorted_xs:
		for y in facade_cols[x]:
			var pos := Vector2i(x, y)
			var edge: EdgeContext = edges[pos]
			if edge.in_portal_zone:
				continue

			# Pomiar głębokości litej ściany nad stopą fasady
			edge.solid_depth = measure_solid_depth(ctx, pos, Vector2i(0, -1))
			var resolved_h := FacadeHeightResolver.resolve(edge.solid_depth)
			if resolved_h == FacadeHeightResolver.Height.INVALID:
				push_error("EdgeAnalyzer: invalid facade depth=%d at %s" % [edge.solid_depth, str(pos)])

			# Adnotacja geometryczna kandydatów nisz (dwupoziomowa, nie kończy klasyfikacji)
			_check_niche_candidates(ctx, pos, x, y, facade_cols, edge, edges)

			# 1. Sprawdzenie kontekstu 2H
			var check_2h_col := func(cx: int, fy: int) -> bool:
				return GridUtils.is_walkable(grid, Vector2i(cx, fy)) \
					and not GridUtils.is_walkable(grid, Vector2i(cx, fy - 1)) \
					and not GridUtils.is_walkable(grid, Vector2i(cx, fy - 2)) \
					and GridUtils.is_walkable(grid, Vector2i(cx, fy - 3))

			var left_is_2h: bool = check_2h_col.call(x - 1, y)
			var right_is_2h: bool = check_2h_col.call(x + 1, y)
			var near_2h_context: bool = (left_is_2h and right_is_2h) \
				or (left_is_2h and check_2h_col.call(x + 2, y)) \
				or (right_is_2h and check_2h_col.call(x - 2, y))

			var is_horizontal_facade: bool = FacadeSegmentDetector.has_same_y(facade_cols, x - 1, y, 1) or FacadeSegmentDetector.has_same_y(facade_cols, x + 1, y, 1)
			var is_2h: bool = is_horizontal_facade and (GridUtils.is_walkable(grid, pos + Vector2i(0, -3)) or near_2h_context)

			if is_2h:
				edge.edge_kind = EdgeKind.Kind.FACADE
				edge.orientation = EdgeKind.Orientation.SOUTH
				edge.facade_height = 2
				continue

			# 2. Łączniki modularne 2H <-> 3H
			var left_is_2h_same: bool = check_2h_col.call(x - 1, y)
			var right_is_2h_same: bool = check_2h_col.call(x + 1, y)
			var right_has_room_for_3h: bool = not check_2h_col.call(x + 1, y) and not check_2h_col.call(x + 2, y) and not check_2h_col.call(x + 3, y)
			var left_has_room_for_3h: bool = not check_2h_col.call(x - 1, y) and not check_2h_col.call(x - 2, y) and not check_2h_col.call(x - 3, y)
			var right_is_2h_step: bool = check_2h_col.call(x + 1, y - 1)
			var left_is_2h_step: bool = check_2h_col.call(x - 1, y - 1)

			if left_is_2h_same and right_has_room_for_3h:
				edge.edge_kind = EdgeKind.Kind.CONNECTOR
				edge.orientation = EdgeKind.Orientation.EAST
				edge.facade_height = 3
				continue
			elif right_is_2h_same and left_has_room_for_3h:
				edge.edge_kind = EdgeKind.Kind.CONNECTOR
				edge.orientation = EdgeKind.Orientation.WEST
				edge.facade_height = 2
				continue
			elif (right_is_2h_same or right_is_2h_step) and not (left_is_2h_same or left_is_2h_step):
				edge.edge_kind = EdgeKind.Kind.CONNECTOR
				edge.orientation = EdgeKind.Orientation.WEST
				edge.facade_height = 2
				continue

			var is_out_corner_cand := func(cx: int, cy: int) -> bool:
				if cy < 2: return false
				var w_cand: bool = (cx >= 1) and GridUtils.is_walkable(grid, Vector2i(cx - 1, cy - 1)) \
					and GridUtils.is_walkable(grid, Vector2i(cx - 1, cy - 2)) \
					and not GridUtils.is_walkable(grid, Vector2i(cx, cy - 2))
				var e_cand: bool = (cx < width - 1) and GridUtils.is_walkable(grid, Vector2i(cx + 1, cy - 1)) \
					and GridUtils.is_walkable(grid, Vector2i(cx + 1, cy - 2)) \
					and not GridUtils.is_walkable(grid, Vector2i(cx, cy - 2))
				return w_cand or e_cand

			# 3. Sąsiedzi na innej wysokości (left_y / right_y)
			var left_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x - 1, y, 4)
			if left_y != -1 and is_out_corner_cand.call(x - 1, left_y):
				left_y = -1

			var right_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x + 1, y, 4)
			if right_y != -1 and is_out_corner_cand.call(x + 1, right_y):
				right_y = -1

			# 4. Sprawdzenie OUT_CORNER (początek fasady przy korytarzu / otwartej przestrzeni)
			var w_open := GridUtils.is_walkable(grid, pos + Vector2i(-1, -1)) \
				and GridUtils.is_walkable(grid, pos + Vector2i(-1, -2)) \
				and not GridUtils.is_walkable(grid, pos + Vector2i(0, -2)) \
				and left_y == -1

			var e_open := GridUtils.is_walkable(grid, pos + Vector2i(1, -1)) \
				and GridUtils.is_walkable(grid, pos + Vector2i(1, -2)) \
				and not GridUtils.is_walkable(grid, pos + Vector2i(0, -2)) \
				and right_y == -1

			if w_open and not e_open:
				var is_2h_corner := GridUtils.is_walkable(grid, pos + Vector2i(0, -3))
				edge.edge_kind = EdgeKind.Kind.OUT_CORNER
				edge.orientation = EdgeKind.Orientation.WEST
				edge.facade_height = 2 if is_2h_corner else 3
				continue
			elif e_open and not w_open:
				var is_2h_corner := GridUtils.is_walkable(grid, pos + Vector2i(0, -3))
				edge.edge_kind = EdgeKind.Kind.OUT_CORNER
				edge.orientation = EdgeKind.Orientation.EAST
				edge.facade_height = 2 if is_2h_corner else 3
				continue

			# 5. Schodek (STEP)
			if left_y != -1 and y > left_y:
				edge.edge_kind = EdgeKind.Kind.STEP
				edge.orientation = EdgeKind.Orientation.WEST
				edge.facade_height = 3
				edge.step_dy = y - left_y
				continue
			elif right_y != -1 and y > right_y:
				edge.edge_kind = EdgeKind.Kind.STEP
				edge.orientation = EdgeKind.Orientation.EAST
				edge.facade_height = 3
				edge.step_dy = y - right_y
				continue

			# 6. Zwykła ściana prosta (FACADE 3H)
			edge.edge_kind = EdgeKind.Kind.FACADE
			edge.orientation = EdgeKind.Orientation.SOUTH
			edge.facade_height = 3

	# Przebieg 5: Klasyfikacja komórek ściany (TOP_RIM, SIDE_WALL, INNER_CORNER, SOLID_FILL)
	var rim_cells: Array[Vector2i] = []

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var edge: EdgeContext = edges[pos]

			if not GridUtils.is_walkable(grid, pos) and edge.edge_kind == EdgeKind.Kind.NONE:
				# 1. TOP_RIM: komórka pod podłogą od północy
				if edge.n_floor:
					if not GridUtils.is_walkable(grid, pos + Vector2i(0, 1)):
						edge.edge_kind = EdgeKind.Kind.TOP_RIM
						edge.orientation = EdgeKind.Orientation.NORTH
						rim_cells.append(pos)
						continue

				# 2. SIDE_WALL: komórka ze ścianą boczną
				if edge.e_floor and not edge.w_floor:
					edge.edge_kind = EdgeKind.Kind.SIDE_WALL
					edge.orientation = EdgeKind.Orientation.EAST
					continue
				elif edge.w_floor and not edge.e_floor:
					edge.edge_kind = EdgeKind.Kind.SIDE_WALL
					edge.orientation = EdgeKind.Orientation.WEST
					continue

				# 3. INNER_CORNER: diagonalne domknięcia narożników wewnętrznych
				if edge.nw_floor and not edge.ne_floor and not edge.w_floor and not edge.n_floor:
					edge.edge_kind = EdgeKind.Kind.INNER_CORNER
					edge.orientation = EdgeKind.Orientation.NORTH_WEST
					continue
				elif edge.ne_floor and not edge.nw_floor and not edge.e_floor and not edge.n_floor:
					edge.edge_kind = EdgeKind.Kind.INNER_CORNER
					edge.orientation = EdgeKind.Orientation.NORTH_EAST
					continue
				elif edge.sw_floor and not edge.se_floor and not edge.w_floor and not edge.s_floor:
					edge.edge_kind = EdgeKind.Kind.INNER_CORNER
					edge.orientation = EdgeKind.Orientation.SOUTH_WEST
					continue
				elif edge.se_floor and not edge.sw_floor and not edge.e_floor and not edge.s_floor:
					edge.edge_kind = EdgeKind.Kind.INNER_CORNER
					edge.orientation = EdgeKind.Orientation.SOUTH_EAST
					continue

				# 4. SOLID_FILL: lita skała bez bezpośredniej krawędzi
				edge.edge_kind = EdgeKind.Kind.SOLID_FILL

	# Przebieg 5B: Drugie przejście dla sąsiadów modułów corner 2H i 3H (bez skanowania voidu)
	for pos in edges:
		var edge: EdgeContext = edges[pos]
		if edge.edge_kind == EdgeKind.Kind.OUT_CORNER:
			var h := edge.facade_height
			var is_east := edge.orientation == EdgeKind.Orientation.EAST
			var adj_x: int = pos.x - 1 if is_east else pos.x + 1
			if adj_x >= 0 and adj_x < width:
				# 1. Ściana boczna na poziomie podstawy (pos.y)
				var p_bot := Vector2i(adj_x, pos.y)
				if edges.has(p_bot) and not GridUtils.is_walkable(grid, p_bot):
					var e_bot: EdgeContext = edges[p_bot]
					e_bot.edge_kind = EdgeKind.Kind.SIDE_WALL
					e_bot.orientation = EdgeKind.Orientation.EAST if is_east else EdgeKind.Orientation.WEST
					e_bot.is_protected_solid = false

				if h == 3:
					# 2. W środkowym (pos.y - 1): ściana boczna
					var p_mid := Vector2i(adj_x, pos.y - 1)
					if edges.has(p_mid) and not GridUtils.is_walkable(grid, p_mid):
						var e_mid: EdgeContext = edges[p_mid]
						if not e_mid.n_floor:
							e_mid.edge_kind = EdgeKind.Kind.SIDE_WALL
							e_mid.orientation = EdgeKind.Orientation.EAST if is_east else EdgeKind.Orientation.WEST
							e_mid.is_protected_solid = false

					# 3. W górnym (pos.y - 2): narożnik wewnętrzny SE (dla EAST) lub SW (dla WEST)
					var p_top := Vector2i(adj_x, pos.y - 2)
					if edges.has(p_top) and not GridUtils.is_walkable(grid, p_top):
						var e_top: EdgeContext = edges[p_top]
						if not e_top.n_floor:
							e_top.edge_kind = EdgeKind.Kind.INNER_CORNER
							e_top.orientation = EdgeKind.Orientation.SOUTH_EAST if is_east else EdgeKind.Orientation.SOUTH_WEST
							e_top.is_protected_solid = false
				elif h == 2:
					# Dla 2H: w górnym (pos.y - 1) narożnik wewnętrzny
					var p_top := Vector2i(adj_x, pos.y - 1)
					if edges.has(p_top) and not GridUtils.is_walkable(grid, p_top):
						var e_top: EdgeContext = edges[p_top]
						if not e_top.n_floor:
							e_top.edge_kind = EdgeKind.Kind.INNER_CORNER
							e_top.orientation = EdgeKind.Orientation.SOUTH_EAST if is_east else EdgeKind.Orientation.SOUTH_WEST
							e_top.is_protected_solid = false

			# Komórki w głębi ściany (odległość 2 kratek) o otoczeniu 000/000/000 zabezpieczamy jako lity void
			var deep_x: int = pos.x - 2 if is_east else pos.x + 2
			if deep_x >= 0 and deep_x < width:
				for dy in range(1, -h - 2, -1):
					var deep_p := Vector2i(deep_x, pos.y + dy)
					var e_deep: EdgeContext = edges.get(deep_p)
					if e_deep != null and e_deep.neighborhood_mask == 0:
						e_deep.is_protected_solid = true
						e_deep.edge_kind = EdgeKind.Kind.SOLID_FILL
						e_deep.orientation = EdgeKind.Orientation.NONE

	# Przebieg 6: Segmentacja pozioma rimów
	var rim_segments := FacadeSegmentDetector.detect(rim_cells, edges)

	# Przebieg 7: Wyznaczenie sąsiedztwa fasad 2H dla rimów
	for pos in rim_cells:
		var edge: EdgeContext = edges[pos]
		var left_foot := pos + Vector2i(-1, 1)
		if edges.has(left_foot) and (edges[left_foot] as EdgeContext).facade_height == 2:
			edge.touches_2h_facade_left = true
		var right_foot := pos + Vector2i(1, 1)
		if edges.has(right_foot) and (edges[right_foot] as EdgeContext).facade_height == 2:
			edge.touches_2h_facade_right = true

	var result := EdgeAnalysisResult.new()
	result.edges = edges
	result.facade_cols = facade_cols
	result.sorted_xs = sorted_xs
	result.facade_segments = rim_segments
	return result


static func _populate_neighborhood(ctx: GenerationContext, edge: EdgeContext) -> void:
	var pos := edge.pos
	var grid := ctx.grid

	edge.n_floor = GridUtils.is_walkable(grid, pos + Vector2i(0, -1))
	edge.ne_floor = GridUtils.is_walkable(grid, pos + Vector2i(1, -1))
	edge.e_floor = GridUtils.is_walkable(grid, pos + Vector2i(1, 0))
	edge.se_floor = GridUtils.is_walkable(grid, pos + Vector2i(1, 1))
	edge.s_floor = GridUtils.is_walkable(grid, pos + Vector2i(0, 1))
	edge.sw_floor = GridUtils.is_walkable(grid, pos + Vector2i(-1, 1))
	edge.w_floor = GridUtils.is_walkable(grid, pos + Vector2i(-1, 0))
	edge.nw_floor = GridUtils.is_walkable(grid, pos + Vector2i(-1, -1))

	var cardinal := 0
	if edge.n_floor: cardinal += 1
	if edge.s_floor: cardinal += 1
	if edge.w_floor: cardinal += 1
	if edge.e_floor: cardinal += 1
	edge.floor_cardinal_count = cardinal
	edge.wall_cardinal_count = 4 - cardinal

	var mask := 0
	if edge.n_floor: mask |= 1
	if edge.ne_floor: mask |= 2
	if edge.e_floor: mask |= 4
	if edge.se_floor: mask |= 8
	if edge.s_floor: mask |= 16
	if edge.sw_floor: mask |= 32
	if edge.w_floor: mask |= 64
	if edge.nw_floor: mask |= 128
	edge.neighborhood_mask = mask


static func _check_niche_candidates(
	ctx: GenerationContext,
	pos: Vector2i,
	x: int,
	y: int,
	facade_cols: Dictionary,
	edge: EdgeContext,
	edges: Dictionary
) -> void:
	if edge.niche_partner != Vector2i(-1, -1):
		return

	var pos_next := Vector2i(x + 1, y)
	if edges.has(pos_next) and (edges[pos_next] as EdgeContext).niche_partner != Vector2i(-1, -1):
		return

	var is_in_portal := ctx.portal_zone.has(pos + Vector2i(0, 1)) or ctx.portal_zone.has(pos_next + Vector2i(0, 1))
	if is_in_portal:
		return

	if not (facade_cols.has(x + 1) and facade_cols[x + 1].has(y)):
		return

	var left_has_same_y: bool = facade_cols.has(x - 1) and facade_cols[x - 1].has(y)
	var right_has_same_y: bool = facade_cols.has(x + 2) and facade_cols[x + 2].has(y)
	var left_down_wall: bool = not GridUtils.is_walkable(ctx.grid, Vector2i(x - 1, y + 1)) or (facade_cols.has(x - 1) and facade_cols[x - 1].has(y + 1))
	var right_down_wall: bool = not GridUtils.is_walkable(ctx.grid, Vector2i(x + 2, y + 1)) or (facade_cols.has(x + 2) and facade_cols[x + 2].has(y + 1))
	var front_is_walkable: bool = GridUtils.is_walkable(ctx.grid, Vector2i(x, y + 1)) and GridUtils.is_walkable(ctx.grid, Vector2i(x + 1, y + 1))
	var left_wall_clear: bool = GridUtils.is_walkable(ctx.grid, Vector2i(x - 2, y))
	var right_wall_clear: bool = GridUtils.is_walkable(ctx.grid, Vector2i(x + 3, y))

	if left_has_same_y and right_has_same_y and not left_down_wall and not right_down_wall and front_is_walkable and left_wall_clear and right_wall_clear:
		edge.is_niche_candidate = true
		edge.is_secret_niche_candidate = true
		edge.niche_partner = pos_next
		if edges.has(pos_next):
			var next_edge: EdgeContext = edges[pos_next]
			next_edge.is_niche_candidate = true
			next_edge.is_secret_niche_candidate = true
			next_edge.niche_partner = pos
