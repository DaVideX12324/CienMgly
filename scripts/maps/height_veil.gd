extends Node2D

## Efekt wysokości korytarzy-schodów (canals.stair_corridors, StructuredStairs): gdy gracz wejdzie `veil_rows` kratek
## schodów w górę albo jest w obszarze nad nimi, reszta mapy chowa się pod voidem (płynnie, FADE_SPEED / s) — widać
## tylko obszar, schody i ściany wokół nich (WALL_REACH kratek). Rysowane nad wszystkim w świecie (z_index).

const CELL := 16
const WALL_REACH := 4
const FADE_SPEED := 3.0
const VOID_COLOR := Color8(14, 17, 19)  # kolor kafla voidu ścieków (SOLID_FILL) — granica zasłony niewidoczna

var _zones: Array = []      # {rect: Rect2i, zone: Dictionary, veil_rows: int, hidden: Array[Rect2]}
var _active := -1
var _alpha := 0.0
var _player: Node2D = null


func setup(result) -> void:
	_zones.clear()
	if result == null or result.canals == null or not "stair_corridors" in result.canals:
		return
	for sc in result.canals.stair_corridors:
		var zone := {}
		for p: Vector2i in sc.zone:
			zone[p] = true
		_zones.append({"rect": sc.rect, "zone": zone, "veil_rows": int(sc.get("veil_rows", 4)),
			"hidden": _hidden_rects(result, sc.rect, zone)})
	z_index = 100
	z_as_relative = false
	set_process(not _zones.is_empty())


## Prostokąty (wiersze) mapy poza widocznym: obszar + schody + ściany w zasięgu WALL_REACH od obszaru i ściany
## korytarza (zasięg 1) przy schodach.
func _hidden_rects(result, rect: Rect2i, zone: Dictionary) -> Array[Rect2]:
	var visible := zone.duplicate()
	for c: Vector2i in zone:
		_add_walls(result, visible, c, WALL_REACH)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			visible[Vector2i(x, y)] = true
			_add_walls(result, visible, Vector2i(x, y), 1)
	var out: Array[Rect2] = []
	for y in range(result.height):
		var x := 0
		while x < result.width:
			if visible.has(Vector2i(x, y)):
				x += 1
				continue
			var x0 := x
			while x < result.width and not visible.has(Vector2i(x, y)):
				x += 1
			out.append(Rect2(x0 * CELL, y * CELL, (x - x0) * CELL, CELL))
	return out


func _add_walls(result, visible: Dictionary, c: Vector2i, reach: int) -> void:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var q := c + Vector2i(dx, dy)
			if not GridUtils.is_walkable(result.grid, q):
				visible[q] = true


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var c := Vector2i(floori(_player.global_position.x / CELL), floori(_player.global_position.y / CELL))
	var want := -1
	for i in _zones.size():
		var z: Dictionary = _zones[i]
		var r: Rect2i = z.rect
		if (z.zone as Dictionary).has(c) or (r.has_point(c) and r.end.y - c.y >= int(z.veil_rows)):
			want = i
			break
	var target := 1.0 if want >= 0 else 0.0
	if want >= 0:
		_active = want
	var a := move_toward(_alpha, target, FADE_SPEED * delta)
	if a != _alpha:
		_alpha = a
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0 or _active < 0:
		return
	var col := Color(VOID_COLOR, _alpha)
	for r: Rect2 in _zones[_active].hidden:
		draw_rect(r, col)
