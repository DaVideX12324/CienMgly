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
	if foot_2h != null and foot_2h.facade_height == 2:
		if foot_2h.edge_kind in [EdgeKind.Kind.FACADE, EdgeKind.Kind.STEP, EdgeKind.Kind.OUT_CORNER, EdgeKind.Kind.CONNECTOR]:
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


## Czy komórka jest poziomem BASE (stopą) fasady 3H.
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
			var is_2h: bool = is_horizontal_facade and (
				GridUtils.is_walkable(grid, pos + Vector2i(0, -3)) or near_2h_context
			)

			if is_2h:
				edge.edge_kind = EdgeKind.Kind.FACADE
				edge.orientation = EdgeKind.Orientation.SOUTH
				edge.facade_height = 2
				continue

			# 2. Łączniki modularne 2H <-> 3H.
			var left_is_2h_same: bool = check_2h_col.call(x - 1, y)
			var right_is_2h_same: bool = check_2h_col.call(x + 1, y)
			var right_has_room_for_3h: bool = not check_2h_col.call(x + 1, y) \
				and not check_2h_col.call(x + 2, y) \
				and not check_2h_col.call(x + 3, y)
			var left_has_room_for_3h: bool = not check_2h_col.call(x - 1, y) \
				and not check_2h_col.call(x - 2, y) \
				and not check_2h_col.call(x - 3, y)
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
				var candidate_pos := Vector2i(cx, cy)
				var w_cand := cx > 0 and _has_out_corner_opening(
					grid,
					candidate_pos,
					Vector2i(-1, 0)
				)
				var e_cand := cx < width - 1 and _has_out_corner_opening(
					grid,
					candidate_pos,
					Vector2i(1, 0)
				)

				# Obustronne otwarcie oznacza przejście / szeroką przestrzeń,
				# a nie pojedynczy moduł OUT_CORNER.
				return w_cand != e_cand

			# 3. Sąsiedzi na innej wysokości (left_y / right_y).
			var left_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x - 1, y, 4)
			if left_y != -1 and is_out_corner_cand.call(x - 1, left_y):
				left_y = -1

			var right_y := FacadeSegmentDetector.find_adjacent_facade_y(facade_cols, x + 1, y, 4)
			if right_y != -1 and is_out_corner_cand.call(x + 1, right_y):
				right_y = -1

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

			# Narożnik musi mieć jeden jednoznaczny kierunek.
			if w_open != e_open:
				var is_2h_corner := GridUtils.is_walkable(grid, pos + Vector2i(0, -3))
				edge.edge_kind = EdgeKind.Kind.OUT_CORNER
				edge.orientation = EdgeKind.Orientation.WEST if w_open else EdgeKind.Orientation.EAST
				edge.facade_height = 2 if is_2h_corner else 3
				continue

			# 5. Schodek (STEP).
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

			# 6. Zwykła ściana prosta (FACADE 3H).
			edge.edge_kind = EdgeKind.Kind.FACADE
			edge.orientation = EdgeKind.Orientation.SOUTH
			edge.facade_height = 3

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
					edge.orientation = EdgeKind.Orientation.SOUTH_WEST
					continue
				elif edge.se_floor and not edge.sw_floor and not edge.e_floor and not edge.s_floor:
					edge.edge_kind = EdgeKind.Kind.INNER_CORNER
					edge.orientation = EdgeKind.Orientation.SOUTH_EAST
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

		# 2. Ściany boczne (MID / BOT) i narożniki wewnętrzne przy końcach fasad, schodków i OUT_CORNER
		if edge.edge_kind in [EdgeKind.Kind.STEP, EdgeKind.Kind.FACADE, EdgeKind.Kind.OUT_CORNER]:
			for sdir: int in [-1, 1]:
				var adj_x: int = pos.x + sdir
				if adj_x < 0 or adj_x >= width:
					continue

				var has_adjacent_facade: bool = false
				if facade_cols.has(adj_x):
					var col_y_arr: Array = facade_cols[adj_x]
					for fy_val in col_y_arr:
						var fy: int = fy_val as int
						if abs(fy - pos.y) <= 2:
							has_adjacent_facade = true
							break

				if not has_adjacent_facade:
					var is_east: bool = (sdir == 1)
					var p_bot: Vector2i = Vector2i(adj_x, pos.y)
					var p_mid: Vector2i = Vector2i(adj_x, pos.y - 1)
					var p_top: Vector2i = Vector2i(adj_x, pos.y - 2)

					# Ściana boczna na wysokości podstawy
					var e_bot: EdgeContext = edges.get(p_bot)
					if e_bot != null and not GridUtils.is_walkable(grid, p_bot) and e_bot.edge_kind != EdgeKind.Kind.INNER_CORNER:
						e_bot.edge_kind = EdgeKind.Kind.SIDE_WALL
						e_bot.orientation = EdgeKind.Orientation.WEST if is_east else EdgeKind.Orientation.EAST
						e_bot.is_protected_solid = false

					# Ściana boczna na wysokości MID
					var e_mid: EdgeContext = edges.get(p_mid)
					if e_mid != null and not GridUtils.is_walkable(grid, p_mid) and e_mid.edge_kind != EdgeKind.Kind.INNER_CORNER:
						e_mid.edge_kind = EdgeKind.Kind.SIDE_WALL
						e_mid.orientation = EdgeKind.Orientation.WEST if is_east else EdgeKind.Orientation.EAST
						e_mid.is_protected_solid = false

					# Narożnik wewnętrzny na szczycie
					var e_top: EdgeContext = edges.get(p_top)
					if e_top != null and not GridUtils.is_walkable(grid, p_top):
						e_top.edge_kind = EdgeKind.Kind.INNER_CORNER
						e_top.orientation = EdgeKind.Orientation.SOUTH_WEST if is_east else EdgeKind.Orientation.SOUTH_EAST
						e_top.is_protected_solid = false

		# 3. Schodki o uskokach pionowych dy >= 2
		if edge.edge_kind == EdgeKind.Kind.STEP and edge.step_dy >= 2:
			var is_west_step: bool = (edge.orientation == EdgeKind.Orientation.WEST)
			var higher_y: int = pos.y - edge.step_dy
			var p_top_step: Vector2i = Vector2i(pos.x, higher_y - 2)
			var e_top_step: EdgeContext = edges.get(p_top_step)
			if e_top_step != null and not GridUtils.is_walkable(grid, p_top_step):
				e_top_step.edge_kind = EdgeKind.Kind.INNER_CORNER
				e_top_step.orientation = EdgeKind.Orientation.SOUTH_WEST if is_west_step else EdgeKind.Orientation.SOUTH_EAST
				e_top_step.is_protected_solid = false

			for cy: int in range(higher_y - 1, pos.y - 2):
				var p_side: Vector2i = Vector2i(pos.x, cy)
				var e_side: EdgeContext = edges.get(p_side)
				if e_side != null and not GridUtils.is_walkable(grid, p_side):
					e_side.edge_kind = EdgeKind.Kind.SIDE_WALL
					e_side.orientation = EdgeKind.Orientation.WEST if is_west_step else EdgeKind.Orientation.EAST
					e_side.is_protected_solid = false

# Przebieg 5B (część 1): Wzorzec ściany bocznej typ B
	# 0  0  top              top  0  0
	# 0 [X] mid      or      mid [X] 0
	# 0  0  base            base  0  0
	for p_key: Vector2i in edges:
		var p: Vector2i = p_key
		if GridUtils.is_walkable(grid, p):
			continue

		var edge_c: EdgeContext = edges[p]
		if edge_c.in_portal_zone or edge_c.edge_kind == EdgeKind.Kind.INNER_CORNER:
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
		var match_side_left: bool = wall_nw and wall_n and wall_w and wall_sw and wall_s \
			and _is_any_wall_top(edges, p + Vector2i(1, -1)) \
			and _is_facade_mid(edges, p + Vector2i(1, 0)) \
			and _is_facade_base(edges, p + Vector2i(1, 1))

		# Ściana prawa (pokój / fasada po lewej) -> Orientation.WEST
		var match_side_right: bool = wall_ne and wall_n and wall_e and wall_se and wall_s \
			and _is_any_wall_top(edges, p + Vector2i(-1, -1)) \
			and _is_facade_mid(edges, p + Vector2i(-1, 0)) \
			and _is_facade_base(edges, p + Vector2i(-1, 1))

		if match_side_left:
			edge_c.edge_kind = EdgeKind.Kind.SIDE_WALL
			edge_c.orientation = EdgeKind.Orientation.EAST
			edge_c.is_protected_solid = false
		elif match_side_right:
			edge_c.edge_kind = EdgeKind.Kind.SIDE_WALL
			edge_c.orientation = EdgeKind.Orientation.WEST
			edge_c.is_protected_solid = false

	# Przebieg 5B (część 2): Wzorzec INNER_CORNER
	# 0  0  0                         0  0  0
	# 0 [X] top              or      top [X] 0
	# 0 (top/side) mid               mid (top/side) 0
	for p_key: Vector2i in edges:
		var p: Vector2i = p_key
		if GridUtils.is_walkable(grid, p):
			continue

		var edge_c: EdgeContext = edges[p]
		if edge_c.in_portal_zone or edge_c.edge_kind == EdgeKind.Kind.INNER_CORNER:
			continue

		var wall_nw: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, -1))
		var wall_n: bool = not GridUtils.is_walkable(grid, p + Vector2i(0, -1))
		var wall_ne: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, -1))
		var wall_w: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, 0))
		var wall_e: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, 0))
		var wall_sw: bool = not GridUtils.is_walkable(grid, p + Vector2i(-1, 1))
		var wall_se: bool = not GridUtils.is_walkable(grid, p + Vector2i(1, 1))

		var no_top_above: bool = not _is_any_wall_top(edges, p + Vector2i(0, -1)) \
			and not _is_any_wall_top(edges, p + Vector2i(-1, -1)) \
			and not _is_any_wall_top(edges, p + Vector2i(1, -1))

		var p_down: Vector2i = p + Vector2i(0, 1)
		var down_is_top_or_side: bool = _is_any_wall_top(edges, p_down) \
			or (edges.has(p_down) and (edges[p_down] as EdgeContext).edge_kind == EdgeKind.Kind.SIDE_WALL)

		# Wariant SOUTH_EAST (top po prawej, ściana/top pod spodem)
		var match_corner_se: bool = wall_nw and wall_n and wall_ne and wall_w and wall_sw and no_top_above \
			and _is_any_wall_top(edges, p + Vector2i(1, 0)) \
			and down_is_top_or_side \
			and _is_facade_mid(edges, p + Vector2i(1, 1))

		# Wariant SOUTH_WEST (top po lewej, ściana/top pod spodem)
		var match_corner_sw: bool = wall_nw and wall_n and wall_ne and wall_e and wall_se and no_top_above \
			and _is_any_wall_top(edges, p + Vector2i(-1, 0)) \
			and down_is_top_or_side \
			and _is_facade_mid(edges, p + Vector2i(-1, 1))

		if match_corner_se:
			edge_c.edge_kind = EdgeKind.Kind.INNER_CORNER
			edge_c.orientation = EdgeKind.Orientation.SOUTH_EAST
			edge_c.is_protected_solid = false
		elif match_corner_sw:
			edge_c.edge_kind = EdgeKind.Kind.INNER_CORNER
			edge_c.orientation = EdgeKind.Orientation.SOUTH_WEST
			edge_c.is_protected_solid = false

	# Aktualizacja rim_cells: usunięcie komórek, które stały się narożnikami
	rim_cells = rim_cells.filter(func(pos_rim: Vector2i) -> bool:
		return (edges[pos_rim] as EdgeContext).edge_kind == EdgeKind.Kind.TOP_RIM
	)
	
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
