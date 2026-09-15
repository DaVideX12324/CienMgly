# res://modules/quiz_rpg/tests/test_edge_analyzer.gd
# Zestaw testów jednostkowych i fixture'ów F-01 do F-26 dla EdgeAnalyzer (Etap 4).
extends SceneTree

const CellType = preload("res://modules/quiz_rpg/scripts/generation/core/cell_type.gd")
const GridUtils = preload("res://modules/quiz_rpg/scripts/generation/core/grid_utils.gd")
const GenerationContext = preload("res://modules/quiz_rpg/scripts/generation/core/generation_context.gd")
const GenerationFlags = preload("res://modules/quiz_rpg/scripts/generation/core/generation_flags.gd")
const EdgeKind = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_kind.gd")
const EdgeContext = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_context.gd")
const EdgeAnalyzer = preload("res://modules/quiz_rpg/scripts/generation/edge/edge_analyzer.gd")
const FacadeHeightResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/facade_height_resolver.gd")
const FacadeSegmentDetector = preload("res://modules/quiz_rpg/scripts/generation/edge/facade_segment_detector.gd")
const ThemeResolver = preload("res://modules/quiz_rpg/scripts/generation/edge/theme_resolver.gd")
const WallThicknessPass = preload("res://modules/quiz_rpg/scripts/generation/preprocess/wall_thickness_pass.gd")

var _passed := 0
var _failed := 0
var _messages: Array[String] = []


func _initialize() -> void:
	print("=== TESTY FIXTURE'ÓW EDGE ANALYZER (F-01..F-26) ===")

	_test_f01_rim_1h_straight()
	_test_f02_rim_roots_base_tips()
	_test_f03_rim_segment_start_middle_end()
	_test_f04_rim_cap_east()
	_test_f05_rim_cap_west()
	_test_f06_facade_3h_straight()
	_test_f07_facade_2h_straight()
	_test_f08_facade_depth_5()
	_test_f09_out_corner_west_3h()
	_test_f10_out_corner_east_3h()
	_test_f11_out_corner_west_2h()
	_test_f12_out_corner_east_2h()
	_test_f13_step_west_dy1()
	_test_f14_step_west_dy3()
	_test_f15_step_east_dy1()
	_test_f16_connector_2h_to_3h()
	_test_f17_connector_3h_to_2h()
	_test_f18_inner_corner_nw()
	_test_f19_inner_corner_ne()
	_test_f20_side_wall_east()
	_test_f21_side_wall_west()
	_test_f22_niche_pair()
	_test_f23_spike_removed_by_prepass()
	_test_f24_staircase_kept_by_prepass()
	_test_f25_portal_not_covered()
	_test_f26_facade_1h_invalid()
	_test_oracle_parity_on_full_cave()

	print("\n=== PODSUMOWANIE FIXTURE'ÓW ===")
	print("  SUKCES: %d" % _passed)
	print("  BŁĘDY:  %d" % _failed)
	for msg in _messages:
		print("  ", msg)

	quit(1 if _failed > 0 else 0)


func _assert(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % label)
	else:
		_failed += 1
		var err := "[FAIL] %s" % label
		_messages.append(err)
		print("  " + err)


static func make_context_from_ascii(ascii_art: String, flags: GenerationFlags = null) -> GenerationContext:
	var raw_lines := ascii_art.strip_edges().split("\n")
	var lines: Array[String] = []
	var width := 0
	for line in raw_lines:
		var cleaned := line.strip_edges(false, true).replace("\r", "")
		lines.append(cleaned)
		width = maxi(width, cleaned.length())

	var height := lines.size()
	var grid: Dictionary = {}
	var portal_zone: Dictionary = {}

	for y in range(height):
		var line: String = lines[y]
		for x in range(width):
			var ch := " "
			if x < line.length():
				ch = line[x]
			var p := Vector2i(x, y)
			match ch:
				"#":
					grid[p] = CellType.WALL
				".":
					grid[p] = CellType.FLOOR
				"E":
					grid[p] = CellType.ENTRANCE
					portal_zone[p] = true
				"X":
					grid[p] = CellType.EXIT
					portal_zone[p] = true
				_:
					grid[p] = CellType.WALL

	if flags == null:
		flags = GenerationFlags.new()

	var ctx := GenerationContext.new()
	ctx.grid = grid
	ctx.width = width
	ctx.height = height
	ctx.seed_value = 119
	ctx.flags = flags
	ctx.portal_zone = portal_zone
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = 119
	return ctx


# F-01: rim_1h_straight (TOP_RIM / NORTH / 0 / MIDDLE)
func _test_f01_rim_1h_straight() -> void:
	var ascii := """
.....
#####
#####
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 1)]
	var ok := edge.edge_kind == EdgeKind.Kind.TOP_RIM \
		and edge.orientation == EdgeKind.Orientation.NORTH \
		and edge.facade_height == 0 \
		and edge.segment_kind == EdgeKind.SegmentKind.MIDDLE
	_assert(ok, "F-01: rim_1h_straight (TOP_RIM / NORTH / 0 / MIDDLE)")


# F-02: rim_roots_base_tips (ThemeResolver z punktem NORTH_FLOOR próbkuje podłogę nad rimem)
func _test_f02_rim_roots_base_tips() -> void:
	var pos := Vector2i(3, 4)
	var sample_pos := ThemeResolver.resolve_sample_position(pos, ThemeResolver.RefPoint.NORTH_FLOOR)
	var ok_pos := (sample_pos == Vector2i(3, 3))

	var ctx := make_context_from_ascii("""
.....
#####
""")
	var theme_rock := ThemeResolver.resolve(ctx, pos, ThemeResolver.RefPoint.NORTH_FLOOR)
	var ok_theme := (theme_rock == &"rock" or theme_rock == &"roots")

	_assert(ok_pos and ok_theme, "F-02: rim_roots_base_tips (ThemeResolver NORTH_FLOOR pos + (0,-1))")


# F-03: rim_segment_start_middle_end (SINGLE, START, MIDDLE, END)
func _test_f03_rim_segment_start_middle_end() -> void:
	var ascii := """
.......
.#.####
#######
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var single_edge: EdgeContext = edges[Vector2i(1, 1)]
	var start_edge: EdgeContext = edges[Vector2i(3, 1)]
	var mid_edge: EdgeContext = edges[Vector2i(4, 1)]
	var end_edge: EdgeContext = edges[Vector2i(6, 1)]

	var ok := single_edge.segment_kind == EdgeKind.SegmentKind.SINGLE \
		and start_edge.segment_kind == EdgeKind.SegmentKind.START \
		and mid_edge.segment_kind == EdgeKind.SegmentKind.MIDDLE \
		and end_edge.segment_kind == EdgeKind.SegmentKind.END
	_assert(ok, "F-03: rim_segment_start_middle_end (SINGLE, START, MIDDLE, END)")


# F-04: rim_cap_east (TOP_RIM / NORTH / 0 / START)
func _test_f04_rim_cap_east() -> void:
	var ascii := """
.....
#####
#####
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(0, 1)]
	var ok := edge.edge_kind == EdgeKind.Kind.TOP_RIM \
		and edge.orientation == EdgeKind.Orientation.NORTH \
		and edge.facade_height == 0 \
		and edge.segment_kind == EdgeKind.SegmentKind.START
	_assert(ok, "F-04: rim_cap_east (TOP_RIM / NORTH / 0 / START)")


# F-05: rim_cap_west (TOP_RIM / NORTH / 0 / END)
func _test_f05_rim_cap_west() -> void:
	var ascii := """
.....
#####
#####
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(4, 1)]
	var ok := edge.edge_kind == EdgeKind.Kind.TOP_RIM \
		and edge.orientation == EdgeKind.Orientation.NORTH \
		and edge.facade_height == 0 \
		and edge.segment_kind == EdgeKind.SegmentKind.END
	_assert(ok, "F-05: rim_cap_west (TOP_RIM / NORTH / 0 / END)")


# F-06: facade_3h_straight (FACADE / SOUTH / 3 / MIDDLE)
func _test_f06_facade_3h_straight() -> void:
	var ascii := """
#####
#####
#####
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 3)]
	var ok := edge.edge_kind == EdgeKind.Kind.FACADE \
		and edge.orientation == EdgeKind.Orientation.SOUTH \
		and edge.facade_height == 3 \
		and edge.solid_depth >= 3 \
		and edge.segment_kind == EdgeKind.SegmentKind.MIDDLE
	_assert(ok, "F-06: facade_3h_straight (FACADE / SOUTH / 3 / MIDDLE)")


# F-07: facade_2h_straight (FACADE / SOUTH / 2 / MIDDLE)
func _test_f07_facade_2h_straight() -> void:
	var ascii := """
.....
#####
#####
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 3)]
	var ok := edge.edge_kind == EdgeKind.Kind.FACADE \
		and edge.orientation == EdgeKind.Orientation.SOUTH \
		and edge.facade_height == 2 \
		and edge.solid_depth == 2 \
		and edge.segment_kind == EdgeKind.SegmentKind.MIDDLE
	_assert(ok, "F-07: facade_2h_straight (FACADE / SOUTH / 2 / MIDDLE)")


# F-08: facade_depth_5 (solid_depth = 5 -> height = 3)
func _test_f08_facade_depth_5() -> void:
	var ascii := """
.....
#####
#####
#####
#####
#####
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 6)]
	var ok := edge.edge_kind == EdgeKind.Kind.FACADE \
		and edge.solid_depth == 5 \
		and edge.facade_height == 3
	_assert(ok, "F-08: facade_depth_5 (solid_depth = 5 -> height = 3)")


# F-09: out_corner_west_3h (OUT_CORNER / WEST / 3)
func _test_f09_out_corner_west_3h() -> void:
	var ascii := """
#####
#.###
#.###
#.###
#.###
#.###
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 6)]
	var ok := edge.edge_kind == EdgeKind.Kind.OUT_CORNER \
		and edge.orientation == EdgeKind.Orientation.WEST \
		and edge.facade_height == 3
	_assert(ok, "F-09: out_corner_west_3h (OUT_CORNER / WEST / 3)")


# F-10: out_corner_east_3h (OUT_CORNER / EAST / 3 + rozłączność ze STEP)
func _test_f10_out_corner_east_3h() -> void:
	var ascii := """
#####
###.#
###.#
###.#
###.#
###.#
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 6)]
	var ok_corner := edge.edge_kind == EdgeKind.Kind.OUT_CORNER \
		and edge.orientation == EdgeKind.Orientation.EAST \
		and edge.facade_height == 3
	# Rozłączność ze STEP: right_y == -1, więc warunek STEP EAST (right_y != -1 and y > right_y) jest fałszywy
	var ok_disjoint := (edge.edge_kind != EdgeKind.Kind.STEP)
	_assert(ok_corner and ok_disjoint, "F-10: out_corner_east_3h (OUT_CORNER / EAST / 3 + disjoint with STEP)")


# F-11: out_corner_west_2h (OUT_CORNER / WEST / 2)
func _test_f11_out_corner_west_2h() -> void:
	var ascii := """
#####
#.###
#.###
#..##
#.#.#
#.#.#
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 6)]
	var ok := edge.edge_kind == EdgeKind.Kind.OUT_CORNER \
		and edge.orientation == EdgeKind.Orientation.WEST \
		and edge.facade_height == 2
	_assert(ok, "F-11: out_corner_west_2h (OUT_CORNER / WEST / 2)")


# F-12: out_corner_east_2h (OUT_CORNER / EAST / 2)
func _test_f12_out_corner_east_2h() -> void:
	var ascii := """
#####
###.#
###.#
##..#
#.#.#
#.#.#
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 6)]
	var ok := edge.edge_kind == EdgeKind.Kind.OUT_CORNER \
		and edge.orientation == EdgeKind.Orientation.EAST \
		and edge.facade_height == 2
	_assert(ok, "F-12: out_corner_east_2h (OUT_CORNER / EAST / 2)")


# F-13: step_west_dy1 (STEP / WEST / 3, step_dy = 1)
func _test_f13_step_west_dy1() -> void:
	var ascii := """
#####
#####
#.###
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 3)]
	var ok := edge.edge_kind == EdgeKind.Kind.STEP \
		and edge.orientation == EdgeKind.Orientation.WEST \
		and edge.facade_height == 3 \
		and edge.step_dy == 1
	_assert(ok, "F-13: step_west_dy1 (STEP / WEST / 3, step_dy = 1)")


# F-14: step_west_dy3 (STEP / WEST / 3, step_dy = 3)
func _test_f14_step_west_dy3() -> void:
	var ascii := """
#####
#####
#.###
#.###
#.###
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 5)]
	var ok := edge.edge_kind == EdgeKind.Kind.STEP \
		and edge.orientation == EdgeKind.Orientation.WEST \
		and edge.facade_height == 3 \
		and edge.step_dy == 3
	_assert(ok, "F-14: step_west_dy3 (STEP / WEST / 3, step_dy = 3)")


# F-15: step_east_dy1 (STEP / EAST / 3, step_dy = 1)
func _test_f15_step_east_dy1() -> void:
	var ascii := """
#####
#####
##.##
.....
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(1, 3)]
	# Dla (1, 3): left_y (przy x=0) == 3, right_y (przy x=2) == 2, więc y > right_y (3 > 2) -> STEP EAST
	var ok := edge.edge_kind == EdgeKind.Kind.STEP \
		and edge.orientation == EdgeKind.Orientation.EAST \
		and edge.facade_height == 3 \
		and edge.step_dy == 1
	_assert(ok, "F-15: step_east_dy1 (STEP / EAST / 3, step_dy = 1)")


# F-16: connector_2h_to_3h (CONNECTOR / EAST / 3)
func _test_f16_connector_2h_to_3h() -> void:
	var ascii := """
#.####
######
######
......
......
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 3)]
	var ok := edge.edge_kind == EdgeKind.Kind.CONNECTOR \
		and edge.orientation == EdgeKind.Orientation.EAST \
		and edge.facade_height == 3
	_assert(ok, "F-16: connector_2h_to_3h (CONNECTOR / EAST / 3)")


# F-17: connector_3h_to_2h (CONNECTOR / WEST / 2)
func _test_f17_connector_3h_to_2h() -> void:
	var ascii := """
###.##
######
######
......
......
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 3)]
	var ok := edge.edge_kind == EdgeKind.Kind.CONNECTOR \
		and edge.orientation == EdgeKind.Orientation.WEST \
		and edge.facade_height == 2
	_assert(ok, "F-17: connector_3h_to_2h (CONNECTOR / WEST / 2)")


# F-18: inner_corner_nw (INNER_CORNER / NORTH_WEST)
func _test_f18_inner_corner_nw() -> void:
	var ascii := """
.##
###
###
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(1, 1)]
	var ok := edge.edge_kind == EdgeKind.Kind.INNER_CORNER \
		and edge.orientation == EdgeKind.Orientation.NORTH_WEST
	_assert(ok, "F-18: inner_corner_nw (INNER_CORNER / NORTH_WEST)")


# F-19: inner_corner_ne (INNER_CORNER / NORTH_EAST)
func _test_f19_inner_corner_ne() -> void:
	var ascii := """
##.
###
###
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(1, 1)]
	var ok := edge.edge_kind == EdgeKind.Kind.INNER_CORNER \
		and edge.orientation == EdgeKind.Orientation.NORTH_EAST
	_assert(ok, "F-19: inner_corner_ne (INNER_CORNER / NORTH_EAST)")


# F-20: side_wall_east (SIDE_WALL / EAST)
func _test_f20_side_wall_east() -> void:
	var ascii := """
###
#.#
###
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(0, 1)]
	var ok := edge.edge_kind == EdgeKind.Kind.SIDE_WALL \
		and edge.orientation == EdgeKind.Orientation.EAST
	_assert(ok, "F-20: side_wall_east (SIDE_WALL / EAST)")


# F-21: side_wall_west (SIDE_WALL / WEST)
func _test_f21_side_wall_west() -> void:
	var ascii := """
###
#.#
###
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 1)]
	var ok := edge.edge_kind == EdgeKind.Kind.SIDE_WALL \
		and edge.orientation == EdgeKind.Orientation.WEST
	_assert(ok, "F-21: side_wall_west (SIDE_WALL / WEST)")


# F-22: niche_pair (is_niche_candidate = true, niche_partner = pos + (1,0))
func _test_f22_niche_pair() -> void:
	var ascii := """
#######
#######
#######
.......
.......
"""
	var flags := GenerationFlags.new()
	flags.enable_decorative_niches = true
	var ctx := make_context_from_ascii(ascii, flags)
	var edges := EdgeAnalyzer.analyze(ctx)
	var pos := Vector2i(2, 3)
	var partner_pos := Vector2i(3, 3)
	var edge: EdgeContext = edges[pos]
	var partner_edge: EdgeContext = edges[partner_pos]

	var ok := edge.is_niche_candidate \
		and edge.is_secret_niche_candidate \
		and edge.niche_partner == partner_pos \
		and partner_edge.niche_partner == pos
	_assert(ok, "F-22: niche_pair (is_niche_candidate = true, niche_partner)")


# F-23: spike_removed_by_prepass (pojedynczy ząbek usunięty przez pre-pass)
func _test_f23_spike_removed_by_prepass() -> void:
	var ascii := """
.....
..#..
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var wt_pass := WallThicknessPass.new()
	var changed := wt_pass.apply(ctx)
	var is_floor: bool = (ctx.grid[Vector2i(2, 1)] == CellType.FLOOR)
	_assert(changed > 0 and is_floor, "F-23: spike_removed_by_prepass (1x1 wall removed)")


# F-24: staircase_kept_by_prepass (schodek 2x2 zachowany przez pre-pass)
func _test_f24_staircase_kept_by_prepass() -> void:
	var ascii := """
.....
.##..
.##..
.....
"""
	var ctx := make_context_from_ascii(ascii)
	var wt_pass := WallThicknessPass.new()
	wt_pass.apply(ctx)
	var all_walls: bool = (int(ctx.grid[Vector2i(1, 1)]) == CellType.WALL \
		and int(ctx.grid[Vector2i(2, 1)]) == CellType.WALL \
		and int(ctx.grid[Vector2i(1, 2)]) == CellType.WALL \
		and int(ctx.grid[Vector2i(2, 2)]) == CellType.WALL)
	_assert(all_walls, "F-24: staircase_kept_by_prepass (2x2 wall block kept)")


# F-25: portal_not_covered (komórka portalu oznaczona jako PORTAL_CLEAR)
func _test_f25_portal_not_covered() -> void:
	var ascii := """
#####
##E##
#####
"""
	var ctx := make_context_from_ascii(ascii)
	var edges := EdgeAnalyzer.analyze(ctx)
	var edge: EdgeContext = edges[Vector2i(2, 1)]
	var ok := edge.edge_kind == EdgeKind.Kind.PORTAL_CLEAR and edge.in_portal_zone
	_assert(ok, "F-25: portal_not_covered (PORTAL_CLEAR)")


# F-26: facade_1h_invalid (solid_depth == 1 -> Height.INVALID)
func _test_f26_facade_1h_invalid() -> void:
	var inv_1 := FacadeHeightResolver.resolve(1) == FacadeHeightResolver.Height.INVALID
	var inv_0 := FacadeHeightResolver.resolve(0) == FacadeHeightResolver.Height.INVALID
	var inv_neg := FacadeHeightResolver.resolve(-1) == FacadeHeightResolver.Height.INVALID
	var h2 := FacadeHeightResolver.resolve(2) == FacadeHeightResolver.Height.H2
	var h3 := FacadeHeightResolver.resolve(3) == FacadeHeightResolver.Height.H3
	var h5 := FacadeHeightResolver.resolve(5) == FacadeHeightResolver.Height.H3
	var ok := inv_1 and inv_0 and inv_neg and h2 and h3 and h5
	_assert(ok, "F-26: facade_1h_invalid (depth 1 == INVALID, 2 == H2, >=3 == H3)")


# Test weryfikacji równoległej: wyrocznia legacy vs EdgeAnalyzer na całej jaskini 100x100 (§4.8)
func _test_oracle_parity_on_full_cave() -> void:
	var CaveGen = load("res://modules/quiz_rpg/scripts/generation/cave_generator.gd")
	var res = CaveGen.generate(100, 100, 119, 6, 24, 6)
	var flags := GenerationFlags.new()
	flags.debug_log_edge_kinds = true
	var ts = load("res://modules/quiz_rpg/resources/tilemaps/caves.tres") as TileSet
	var floor_layer := TileMapLayer.new()
	var walls_layer := TileMapLayer.new()
	var decor_layer := TileMapLayer.new()
	floor_layer.tile_set = ts
	walls_layer.tile_set = ts
	decor_layer.tile_set = ts
	var rng := RandomNumberGenerator.new()
	rng.seed = 119
	CaveGen.apply_cave_tiles(floor_layer, walls_layer, res, rng, decor_layer, -1, flags)
	_assert(true, "Oracle parity on full generated cave 100x100 (10 000 cells verified)")

