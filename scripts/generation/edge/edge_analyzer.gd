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


## Czy stopa fasady ma jednoznaczne otwarcie narożnika po wybranej stronie.
##
## EAST:            WEST:
## n11              11n
## nX1              1Xn
## nnn              nnn
##
## X oznacza aktualną stopę fasady. Liczą się tylko komórka z boku
## oraz przekątna nad nią; pozostałe pola wzorca są nieistotne.
## Czy stopa fasady ma jednoznaczne otwarcie narożnika po wybranej stronie.
## Po stronie otwarcia komórki na wysokości stopy (MID), fasady (TOP) 
## oraz nad nią muszą być całkowicie wolne (brak jakiejkolwiek ściany).
static func _has_out_corner_opening(
	grid,
	floor_pos: Vector2i,
	side: Vector2i
) -> bool:
	var side_mid := floor_pos + side
	var side_top := side_mid + Vector2i(0, -1)
	var side_above := side_mid + Vector2i(0, -2)

	return GridUtils.is_walkable(grid, side_mid) \
		and GridUtils.is_walkable(grid, side_top) \
		and GridUtils.is_walkable(grid, side_above)


## Czy komórka jest jakimkolwiek szczytem ściany (TOP_RIM, szczyt fasady 2H/3H/schodka).
static func _is_any_wall_top(edges: Dictionary, p: Vector2i) -> bool:
	var e: EdgeContext = edges.get(p)
	if e == null:
		return false
	if e.edge_kind == EdgeKind.Kind.TOP_RIM:
		return true

	var foot_2h: EdgeContext = edges.get(p + Vector2i(0, 1))
	if foot_2h != null and foot_2h.facade_height == 2 and foot_2h.solid_depth == 2:
		if foot_2h.edge_kind in [EdgeKind.Kind.FACADE, EdgeKind.Kind.STEP, EdgeKind.Kind.OUT_CORNER, EdgeKind.Kind.CONNECTOR]:
			return true

	var foot_2h_d3: EdgeContext = edges.get(p + Vector2i(0, 2))
	if foot_2h_d3 != null and foot_2h_d3.facade_height == 2 and foot_2h_d3.solid_depth >= 3:
		if foot_2h_d3.edge_kind in [EdgeKind.Kind.FACADE, EdgeKind.Kind.STEP, EdgeKind.Kind.OUT_CORNER, EdgeKind.Kind.CONNECTOR]:
			return true

	var foot_3h: EdgeContext = edges.get(p + Vector2i(0, 2))
	if foot_3h != null and foot_3h.facade_height == 3:
		if foot_3h.edge_kind in [EdgeKind.Kind.FACADE, EdgeKind.Kind.STEP, EdgeKind.Kind.OUT_CORNER, EdgeKind.Kind.CONNECTOR]:
			return true

	return false


## Czy komórka jest poziomem MID fasady 3H (stopa o 1 niżej o wysokości 3H).
static func _is_facade_mid(edges: Dictionary, p: Vector2i) -> bool:
	var foot: EdgeContext = edges.get(p + Vector2i(0, 1))
	if foot != null and foot.facade_height == 3:
		return foot.edge_kind in [EdgeKind.Kind.FACADE, EdgeKind.Kind.STEP, EdgeKind.Kind.OUT_CORNER, EdgeKind.Kind.CONNECTOR]
	return false


## Czy komórka jest poziomem BASE (stopą ściany) fasady 3H.
static func _is_facade_base(edges: Dictionary, p: Vector2i) -> bool:
	var foot: EdgeContext = edges.get(p)
	if foot != null and foot.facade_height == 3:
		return foot.edge_kind in [EdgeKind.Kind.FACADE, EdgeKind.Kind.STEP, EdgeKind.Kind.OUT_CORNER, EdgeKind.Kind.CONNECTOR]
	return false
	

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

	# Komórka ściany — lokalna klasyfikacja.
	if edge.n_floor and not GridUtils.is_walkable(ctx.grid, pos + Vector2i(0, 1)):
		edge.edge_kind = EdgeKind.Kind.TOP_RIM
		var is_edge_diag_left: bool = (not edge.nw_floor and edge.ne_floor) and (not edge.w_floor and not edge.e_floor) and (edge.sw_floor and not edge.se_floor)
		var is_edge_diag_right: bool = (edge.nw_floor and not edge.ne_floor) and (not edge.w_floor and not edge.e_floor) and (edge.se_floor and not edge.sw_floor)
		if edge.e_floor and not edge.w_floor:
			edge.orientation = EdgeKind.Orientation.EAST
		elif edge.w_floor and not edge.e_floor:
			edge.orientation = EdgeKind.Orientation.WEST
		elif is_edge_diag_right:
			edge.orientation = EdgeKind.Orientation.EAST
		elif is_edge_diag_left:
			edge.orientation = EdgeKind.Orientation.WEST
		else:
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

	# Przebieg 1: Inicjalizacja kontekstów 3x3 dla wszystkich komórek w porządku (y, x).
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

	# Przebieg 2: Identyfikacja stóp fasad (pierwszy wiersz podłogi pod sufitem o głębokości >= 2).
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

	# Przebieg 3: Ścisła segmentacja pozioma fasad.
	FacadeSegmentDetector.detect(facade_candidates, edges)

	# Przebieg 4: Klasyfikacja fasad w kanonicznej kolejności kolumn (x rosnąco, y rosnąco).
	var sorted_xs: Array = facade_cols.keys()
	sorted_xs.sort()

	for x in sorted_xs:
		for y in facade_cols[x]:
			var pos := Vector2i(x, y)
			var edge: EdgeContext = edges[pos]
			if edge.in_portal_zone:
				continue

			# Pomiar głębokości litej ściany nad stopą fasady.
			edge.solid_depth = measure_solid_depth(ctx, pos, Vector2i(0, -1))
			var resolved_h := FacadeHeightResolver.resolve(edge.solid_depth)
			if resolved_h == FacadeHeightResolver.Height.INVALID:
				push_error("EdgeAnalyzer: invalid facade depth=%d at %s" % [edge.solid_depth, str(pos)])

			# Adnotacja geometryczna kandydatów nisz (dwupoziomowa, nie kończy klasyfikacji).
			_check_niche_candidates(ctx, pos, x, y, facade_cols, edge, edges)

			# 1. Sprawdzenie kontekstu 2H.
			# 1. Sprawdzenie kontekstu 2H.
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

			var is_horizontal_facade: bool = FacadeSegmentDetector.has_same_y(facade_cols, x - 1, y, 1) \
				or FacadeSegmentDetector.has_same_y(facade_cols, x + 1, y, 1)
			var is_2h: bool = is_horizontal_facade and edge.solid_depth == 2

			if is_2h:
				edge.edge_kind = EdgeKind.Kind.FACADE
				edge.orientation = EdgeKind.Orientation.SOUTH
				edge.facade_height = 2
				continue

			# 2. Łączniki modularne 2H <-> 3H (dla prostej fasady o tym samym poziomie Y lub ze schodkiem 1-kafelkowym).
			var left_is_2h_same: bool = check_2h_col.call(x - 1, y)
			var right_is_2h_same: bool = check_2h_col.call(x + 1, y)
			var right_is_2h_step: bool = check_2h_col.call(x + 1, y - 1)
			var left_is_2h_step: bool = check_2h_col.call(x - 1, y - 1)
			var left_is_2h_any: bool = left_is_2h_same or left_is_2h_step
			var right_is_2h_any: bool = right_is_2h_same or right_is_2h_step

			var right_has_room_for_3h: bool = not check_2h_col.call(x + 1, y) \
				and not check_2h_col.call(x + 2, y) \
				and not check_2h_col.call(x + 3, y)
			var left_has_room_for_3h: bool = not check_2h_col.call(x - 1, y) \
				and not check_2h_col.call(x - 2, y) \
				and not check_2h_col.call(x - 3, y)

			if (left_is_2h_any and right_has_room_for_3h) or (left_is_2h_any and not right_is_2h_any):
				edge.edge_kind = EdgeKind.Kind.CONNECTOR
				edge.orientation = EdgeKind.Orientation.EAST
				edge.facade_height = 3
				continue
			elif (right_is_2h_any and left_has_room_for_3h) or (right_is_2h_any and not left_is_2h_any):
				edge.edge_kind = EdgeKind.Kind.CONNECTOR
				edge.orientation = EdgeKind.Orientation.WEST
				edge.facade_height = 2
				continue

			# 3. Sąsiedzi na innej wysokości (left_y / right_y).
			var left_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x - 1, y, 4)
			var right_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x + 1, y, 4)

			# 4. OUT_CORNER — lokalne wzorce:
			#
			# EAST:            WEST:
			# n11              11n
			# nX1              1Xn
			# nnn              nnn
			#
			# X jest aktualną stopą fasady. Warunek wykorzystuje wyłącznie
			# podłogę po boku oraz podłogę po przekątnej nad tym bokiem.
			var w_open := _has_out_corner_opening(
				grid,
				pos,
				Vector2i(-1, 0)
			) and left_y == -1
			var e_open := _has_out_corner_opening(
				grid,
				pos,
				Vector2i(1, 0)
			) and right_y == -1

			var is_2h_col: bool = (edge.solid_depth == 2 or GridUtils.is_walkable(grid, pos + Vector2i(0, -3)))

			# Narożnik musi mieć jeden jednoznaczny kierunek.
			if w_open != e_open:
				edge.edge_kind = EdgeKind.Kind.OUT_CORNER
				edge.orientation = EdgeKind.Orientation.WEST if w_open else EdgeKind.Orientation.EAST
				edge.facade_height = 2 if is_2h_col else 3
				continue

			# 5. Schodek (STEP).
			if left_y != -1 and y > left_y:
				edge.edge_kind = EdgeKind.Kind.STEP
				edge.orientation = EdgeKind.Orientation.WEST
				edge.facade_height = 2 if is_2h_col else 3
				edge.step_dy = y - left_y
				continue
			elif right_y != -1 and y > right_y:
				edge.edge_kind = EdgeKind.Kind.STEP
				edge.orientation = EdgeKind.Orientation.EAST
				edge.facade_height = 2 if is_2h_col else 3
				edge.step_dy = y - right_y
				continue

			# 6. Zwykła ściana prosta (FACADE).
			edge.edge_kind = EdgeKind.Kind.FACADE
			edge.orientation = EdgeKind.Orientation.SOUTH
			edge.facade_height = 2 if is_2h_col else 3

	# Przebieg 5: Klasyfikacja komórek ściany (TOP_RIM, SIDE_WALL, INNER_CORNER, SOLID_FILL).
	var rim_cells: Array[Vector2i] = []

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var edge: EdgeContext = edges[pos]

			if not GridUtils.is_walkable(grid, pos) and edge.edge_kind == EdgeKind.Kind.NONE:
				# 1. TOP_RIM: komórka pod podłogą od północy.
				if edge.n_floor:
					if not GridUtils.is_walkable(grid, pos + Vector2i(0, 1)):
						edge.edge_kind = EdgeKind.Kind.TOP_RIM
						var is_edge_diag_left: bool = (not edge.nw_floor and edge.ne_floor) and (not edge.w_floor and not edge.e_floor) and (edge.sw_floor and not edge.se_floor)
						var is_edge_diag_right: bool = (edge.nw_floor and not edge.ne_floor) and (not edge.w_floor and not edge.e_floor) and (edge.se_floor and not edge.sw_floor)
						if edge.e_floor and not edge.w_floor:
							edge.orientation = EdgeKind.Orientation.EAST
						elif edge.w_floor and not edge.e_floor:
							edge.orientation = EdgeKind.Orientation.WEST
						elif is_edge_diag_right:
							edge.orientation = EdgeKind.Orientation.EAST
						elif is_edge_diag_left:
							edge.orientation = EdgeKind.Orientation.WEST
						else:
							edge.orientation = EdgeKind.Orientation.NORTH
						rim_cells.append(pos)
						continue

				# 2. SIDE_WALL: komórka ze ścianą boczną.
				if edge.e_floor and not edge.w_floor:
					edge.edge_kind = EdgeKind.Kind.SIDE_WALL
					edge.orientation = EdgeKind.Orientation.EAST
					continue
				elif edge.w_floor and not edge.e_floor:
					edge.edge_kind = EdgeKind.Kind.SIDE_WALL
					edge.orientation = EdgeKind.Orientation.WEST
					continue

				# 3. INNER_CORNER: diagonalne domknięcia narożników wewnętrznych.
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
					edge.orientation = EdgeKind.Orientation.SOUTH_EAST
					continue
				elif edge.se_floor and not edge.sw_floor and not edge.e_floor and not edge.s_floor:
					edge.edge_kind = EdgeKind.Kind.INNER_CORNER
					edge.orientation = EdgeKind.Orientation.SOUTH_WEST
					continue

				# 4. SOLID_FILL: lita skała bez bezpośredniej krawędzi.
				edge.edge_kind = EdgeKind.Kind.SOLID_FILL

# Przebieg 5B: Zabezpieczenie voidu, obsługa krawędzi bocznych fasad i narożników wewnętrznych.
	for p_key: Vector2i in edges:
		var pos: Vector2i = p_key
		var edge: EdgeContext = edges[pos]

		# 1. Głęboki void za narożnikami zewnętrznymi
		if edge.edge_kind == EdgeKind.Kind.OUT_CORNER:
			var h: int = edge.facade_height
			var is_east_corner: bool = (edge.orientation == EdgeKind.Orientation.EAST)
			var deep_x: int = pos.x - 2 if is_east_corner else pos.x + 2
			if deep_x >= 0 and deep_x < width:
				for dy: int in range(1, -h - 2, -1):
					var deep_p: Vector2i = Vector2i(deep_x, pos.y + dy)
					var e_deep: EdgeContext = edges.get(deep_p)
					if e_deep != null and e_deep.neighborhood_mask == 0:
						e_deep.is_protected_solid = true
						e_deep.edge_kind = EdgeKind.Kind.SOLID_FILL
						e_deep.orientation = EdgeKind.Orientation.NONE

	# Przebieg 5B (część 1): Wzorzec ściany bocznej typ B
	# Pattern 2 (przy MID):
	# 0  0  top              top  0  0
	# 0 [X] mid      or      mid [X] 0
	# 0  0  base            base  0  0
	#
	# Pattern 3 (przy BASE):
	# 0  0  mid              mid  0  0
	# 0 [X] base     or     base [X] 0
	# 0  0  1                 1   0  0
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if GridUtils.is_walkable(grid, p):
				continue

			var edge_c: EdgeContext = edges.get(p)
			if edge_c == null or edge_c.in_portal_zone:
				continue

			var wall_nw: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, -1))
			var wall_n: bool = not GridUtils.is_walkable(grid, p + Vector2i(0, -1))
			var wall_ne: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, -1))
			var wall_w: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, 0))
			var wall_e: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, 0))
			var wall_sw: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, 1))
			var wall_s: bool = not GridUtils.is_walkable(grid, p + Vector2i(0, 1))
			var wall_se: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, 1))

			# Ściana lewa (pokój / fasada po prawej) -> Orientation.EAST
			# Pattern 2 (przy MID):
			var match_side_left_mid: bool = wall_nw and wall_n and wall_w and wall_sw and wall_s \
				and _is_any_wall_top(edges, p + Vector2i(1, -1)) \
				and _is_facade_mid(edges, p + Vector2i(1, 0)) \
				and _is_facade_base(edges, p + Vector2i(1, 1))

			# Pattern 3 (przy BASE):
			var match_side_left_base: bool = wall_nw and wall_n and wall_w and wall_sw \
				and _is_facade_mid(edges, p + Vector2i(1, -1)) \
				and _is_facade_base(edges, p + Vector2i(1, 0)) \
				and GridUtils.is_walkable(grid, p + Vector2i(1, 1))

			# Ściana prawa (pokój / fasada po lewej) -> Orientation.WEST
			# Pattern 2 (przy MID):
			var match_side_right_mid: bool = wall_ne and wall_n and wall_e and wall_se and wall_s \
				and _is_any_wall_top(edges, p + Vector2i(-1, -1)) \
				and _is_facade_mid(edges, p + Vector2i(-1, 0)) \
				and _is_facade_base(edges, p + Vector2i(-1, 1))

			# Pattern 3 (przy BASE):
			var match_side_right_base: bool = wall_ne and wall_n and wall_e and wall_se \
				and _is_facade_mid(edges, p + Vector2i(-1, -1)) \
				and _is_facade_base(edges, p + Vector2i(-1, 0)) \
				and GridUtils.is_walkable(grid, p + Vector2i(-1, 1))

			if match_side_left_mid or match_side_left_base:
				edge_c.edge_kind = EdgeKind.Kind.SIDE_WALL
				edge_c.orientation = EdgeKind.Orientation.EAST
				edge_c.is_protected_solid = false
			elif match_side_right_mid or match_side_right_base:
				edge_c.edge_kind = EdgeKind.Kind.SIDE_WALL
				edge_c.orientation = EdgeKind.Orientation.WEST
				edge_c.is_protected_solid = false

	# Przebieg 5B (część 2): Wzorzec INNER_CORNER
	# 0  0  0                         0  0  0
	# 0 [X] top              or      top [X] 0
	# 0 (top/side) mid               mid (top/side) 0
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if GridUtils.is_walkable(grid, p):
				continue

			var edge_c: EdgeContext = edges.get(p)
			if edge_c == null or edge_c.in_portal_zone or edge_c.edge_kind == EdgeKind.Kind.INNER_CORNER:
				continue

			var wall_nw: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, -1))
			var wall_n: bool = not GridUtils.is_walkable(grid, p + Vector2i(0, -1))
			var wall_ne: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, -1))
			var wall_w: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, 0))
			var wall_e: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, 0))
			var wall_sw: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, 1))
			var wall_se: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, 1))

			var e_above: EdgeContext = edges.get(p + Vector2i(0, -1))
			var above_is_corner_or_side: bool = e_above != null and e_above.edge_kind in [EdgeKind.Kind.INNER_CORNER, EdgeKind.Kind.SIDE_WALL]

			var no_top_above: bool = not above_is_corner_or_side \
				and not _is_any_wall_top(edges, p + Vector2i(0, -1)) \
				and not _is_any_wall_top(edges, p + Vector2i(-1, -1)) \
				and not _is_any_wall_top(edges, p + Vector2i(1, -1))

			var p_down: Vector2i = p + Vector2i(0, 1)
			var is_down_facade_foot: bool = edges.has(p_down) and (edges[p_down] as EdgeContext).edge_kind == EdgeKind.Kind.FACADE
			var is_down_facade_base: bool = edges.has(p_down + Vector2i(0, 1)) and (edges[p_down + Vector2i(0, 1)] as EdgeContext).edge_kind == EdgeKind.Kind.FACADE
			var is_down_facade_mid: bool = edges.has(p_down + Vector2i(0, 2)) and (edges[p_down + Vector2i(0, 2)] as EdgeContext).edge_kind == EdgeKind.Kind.FACADE
			var down_is_straight_facade: bool = is_down_facade_foot or is_down_facade_base or is_down_facade_mid
			var down_is_wall: bool = not GridUtils.is_walkable(grid, p_down) and not down_is_straight_facade

			var top_above: bool = e_above != null and e_above.edge_kind == EdgeKind.Kind.TOP_RIM
			var allow_top: bool = no_top_above or top_above

			# Wariant SOUTH_WEST (top po prawej, ściana pod spodem -> lewa strona pokoju)
			var match_corner_sw: bool = wall_nw and wall_n and wall_ne and wall_w and wall_sw and allow_top \
				and _is_any_wall_top(edges, p + Vector2i(1, 0)) \
				and down_is_wall \
				and not GridUtils.is_walkable(grid, p + Vector2i(1, 1))

			# Wariant SOUTH_EAST (top po lewej, ściana pod spodem -> prawa strona pokoju)
			var match_corner_se: bool = wall_nw and wall_n and wall_ne and wall_e and wall_se and allow_top \
				and _is_any_wall_top(edges, p + Vector2i(-1, 0)) \
				and down_is_wall \
				and not GridUtils.is_walkable(grid, p + Vector2i(-1, 1))

			if match_corner_sw:
				edge_c.edge_kind = EdgeKind.Kind.INNER_CORNER
				edge_c.orientation = EdgeKind.Orientation.SOUTH_WEST
				edge_c.is_protected_solid = false
			elif match_corner_se:
				edge_c.edge_kind = EdgeKind.Kind.INNER_CORNER
				edge_c.orientation = EdgeKind.Orientation.SOUTH_EAST
				edge_c.is_protected_solid = false

	# Przebieg 6: Segmentacja pozioma rimów.
	var rim_segments := FacadeSegmentDetector.detect(rim_cells, edges)

	# Przebieg 7: Wyznaczenie sąsiedztwa fasad 2H dla rimów.
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

	# Reguła prepass:
	# 100 / 000 / 001 -> górny narożnik (NW) zmienia się na 0
	if edge.nw_floor and edge.se_floor \
		and not edge.n_floor and not edge.ne_floor and not edge.e_floor \
		and not edge.s_floor and not edge.sw_floor and not edge.w_floor:
		edge.nw_floor = false

	# 001 / 000 / 100 -> górny narożnik (NE) zmienia się na 0
	if edge.ne_floor and edge.sw_floor \
		and not edge.nw_floor and not edge.n_floor and not edge.w_floor \
		and not edge.e_floor and not edge.s_floor and not edge.se_floor:
		edge.ne_floor = false

	var cardinal := 0
	if edge.n_floor:
		cardinal += 1
	if edge.s_floor:
		cardinal += 1
	if edge.w_floor:
		cardinal += 1
	if edge.e_floor:
		cardinal += 1
	edge.floor_cardinal_count = cardinal
	edge.wall_cardinal_count = 4 - cardinal

	var mask := 0
	if edge.n_floor:
		mask |= 1
	if edge.ne_floor:
		mask |= 2
	if edge.e_floor:
		mask |= 4
	if edge.se_floor:
		mask |= 8
	if edge.s_floor:
		mask |= 16
	if edge.sw_floor:
		mask |= 32
	if edge.w_floor:
		mask |= 64
	if edge.nw_floor:
		mask |= 128
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

	var is_in_portal := ctx.portal_zone.has(pos + Vector2i(0, 1)) \
		or ctx.portal_zone.has(pos_next + Vector2i(0, 1))
	if is_in_portal:
		return

	if not (facade_cols.has(x + 1) and facade_cols[x + 1].has(y)):
		return

	var left_has_same_y: bool = facade_cols.has(x - 1) and facade_cols[x - 1].has(y)
	var right_has_same_y: bool = facade_cols.has(x + 2) and facade_cols[x + 2].has(y)
	var left_down_wall: bool = not GridUtils.is_walkable(ctx.grid, Vector2i(x - 1, y + 1)) \
		or (facade_cols.has(x - 1) and facade_cols[x - 1].has(y + 1))
	var right_down_wall: bool = not GridUtils.is_walkable(ctx.grid, Vector2i(x + 2, y + 1)) \
		or (facade_cols.has(x + 2) and facade_cols[x + 2].has(y + 1))
	var front_is_walkable: bool = GridUtils.is_walkable(ctx.grid, Vector2i(x, y + 1)) \
		and GridUtils.is_walkable(ctx.grid, Vector2i(x + 1, y + 1))
	var left_wall_clear: bool = GridUtils.is_walkable(ctx.grid, Vector2i(x - 2, y))
	var right_wall_clear: bool = GridUtils.is_walkable(ctx.grid, Vector2i(x + 3, y))

	if left_has_same_y and right_has_same_y \
		and not left_down_wall \
		and not right_down_wall \
		and front_is_walkable \
		and left_wall_clear \
		and right_wall_clear:
		edge.is_niche_candidate = true
		edge.is_secret_niche_candidate = true
		edge.niche_partner = pos_next

		if edges.has(pos_next):
			var next_edge: EdgeContext = edges[pos_next]
			next_edge.is_niche_candidate = true
			next_edge.is_secret_niche_candidate = true
			next_edge.niche_partner = pos
