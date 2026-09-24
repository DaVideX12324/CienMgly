class_name ObjectFeatures
extends RefCounted

## Cechy kratek mapy dla generatora obiektów — liczone raz na mapę, płaskie tablice W×H (idx = y*W + x),
## więc reguły obiektów to odczyty O(1). Do tego listy kratek per tag kontekstu (baza losowania).
##
## Tagi: wall_n/s/e/w (ściana ortogonalnie z tej strony), wall_any, corner (ściany z dwóch prostopadłych
## stron), niche (ściany z trzech stron), dead_end (nisza albo najwyżej 1 chodliwy sąsiad ortogonalny),
## open (≥ 2 kratki od ściany), center (≥ 3), room / corridor (wewnątrz prostokąta pokoju / poza),
## plateau_edge (sąsiaduje z barierą płaskowyżu).

const WALL_N := 1
const WALL_S := 2
const WALL_E := 4
const WALL_W := 8
const DIST_CAP := 15
const HEIGHT_OFFSET := 8

var width := 0
var height := 0
var walk := PackedByteArray()     # 1 = chodliwa podłoga
var walls := PackedByteArray()    # bity WALL_* (ortogonalni sąsiedzi niechodliwi)
var dist := PackedByteArray()     # odległość Chebysheva do ściany (0 = ściana), obcięta do DIST_CAP
var room := PackedInt32Array()    # indeks pokoju (prostokąt z ctx.rooms) albo -1
var level := PackedByteArray()    # wysokość + HEIGHT_OFFSET
var edge := PackedByteArray()     # 1 = sąsiaduje (8) z barierą płaskowyżu
var floor_cells := PackedInt32Array()
var tag_cells := {}               # StringName -> PackedInt32Array


static func build(result) -> ObjectFeatures:
	var f := ObjectFeatures.new()
	f._build(result)
	return f


func idx(c: Vector2i) -> int:
	return c.y * width + c.x


func cell(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func height_at(i: int) -> int:
	return int(level[i]) - HEIGHT_OFFSET


## Czy kratka ma tag kontekstu.
func has_tag(i: int, tag: StringName) -> bool:
	var b := int(walls[i])
	match tag:
		&"wall_n": return b & WALL_N != 0
		&"wall_s": return b & WALL_S != 0
		&"wall_e": return b & WALL_E != 0
		&"wall_w": return b & WALL_W != 0
		&"wall_any": return b != 0
		&"corner": return (b & (WALL_N | WALL_S)) != 0 and (b & (WALL_E | WALL_W)) != 0
		&"niche": return _bits(b) == 3
		&"dead_end": return _bits(b) >= 3
		&"open": return int(dist[i]) >= 2
		&"center": return int(dist[i]) >= 3
		&"room": return room[i] >= 0
		&"corridor": return room[i] < 0
		&"plateau_edge": return int(edge[i]) == 1
	return false


func level_ok(i: int, levels: Array[StringName]) -> bool:
	if levels.is_empty():
		return true
	var h := height_at(i)
	for lv in levels:
		if (lv == &"ground" and h == 0) or (lv == &"plateau" and h > 0) or (lv == &"pit" and h < 0):
			return true
	return false


## Reguły kontekstu obiektu w kratce (context: wystarczy jeden tag; avoid: żaden; wysokość).
func rules_ok(i: int, def: ObjectDef) -> bool:
	if not level_ok(i, def.levels):
		return false
	for t in def.avoid:
		if has_tag(i, t):
			return false
	if def.context.is_empty():
		return true
	for t in def.context:
		if has_tag(i, t):
			return true
	return false


## Baza losowania dla obiektu: suma list jego tagów kontekstu (albo cała podłoga). Kratki mogą się
## powtarzać między tagami — planer i tak sprawdza reguły dla wylosowanej kratki.
func base_cells(def: ObjectDef) -> PackedInt32Array:
	if def.context.is_empty():
		return floor_cells
	if def.context.size() == 1:
		return tag_cells.get(def.context[0], PackedInt32Array())
	var out := PackedInt32Array()
	for t in def.context:
		out.append_array(tag_cells.get(t, PackedInt32Array()))
	return out


static func _bits(b: int) -> int:
	return (b & 1) + ((b >> 1) & 1) + ((b >> 2) & 1) + ((b >> 3) & 1)


func _build(result) -> void:
	width = result.width
	height = result.height
	var n := width * height
	walk.resize(n)
	walls.resize(n)
	dist.resize(n)
	room.resize(n)
	level.resize(n)
	edge.resize(n)
	room.fill(-1)
	level.fill(HEIGHT_OFFSET)
	var grid: Dictionary = result.grid
	for y in range(height):
		for x in range(width):
			walk[y * width + x] = 1 if GridUtils.is_walkable(grid, Vector2i(x, y)) else 0

	# Transformata odległości (Chebyshev, dwa przebiegi) — ściana i brzeg mapy = 0.
	for i in range(n):
		dist[i] = DIST_CAP if walk[i] == 1 else 0
	for y in range(height):
		for x in range(width):
			var i := y * width + x
			if walk[i] == 0:
				continue
			var d := int(dist[i])
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				d = 0
			else:
				d = mini(d, int(dist[i - 1]) + 1)
				d = mini(d, int(dist[i - width]) + 1)
				d = mini(d, int(dist[i - width - 1]) + 1)
				d = mini(d, int(dist[i - width + 1]) + 1)
			dist[i] = d
	for y in range(height - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			var i := y * width + x
			if walk[i] == 0 or x == 0 or y == 0 or x == width - 1 or y == height - 1:
				continue
			var d := int(dist[i])
			d = mini(d, int(dist[i + 1]) + 1)
			d = mini(d, int(dist[i + width]) + 1)
			d = mini(d, int(dist[i + width + 1]) + 1)
			d = mini(d, int(dist[i + width - 1]) + 1)
			dist[i] = d

	for r_i in range(result.rooms.size()):
		var r: Rect2i = result.rooms[r_i]
		for y in range(maxi(r.position.y, 0), mini(r.end.y, height)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, width)):
				if room[y * width + x] < 0:
					room[y * width + x] = r_i

	var pl = result.plateau
	if pl != null and not pl.is_empty():
		for c in pl.heights:
			if in_bounds(c):
				level[idx(c)] = clampi(int(pl.heights[c]) + HEIGHT_OFFSET, 0, 255)
		for c in pl.blocked:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q: Vector2i = c + Vector2i(dx, dy)
					if in_bounds(q) and walk[idx(q)] == 1 and not pl.blocked.has(q):
						edge[idx(q)] = 1

	# Listy per tag jako zwykłe Array (referencje) — Packed* ze słownika to kopia przy zapisie.
	var tags: Array[StringName] = []
	var lists: Array = []
	for tg in ObjectCatalog.CONTEXT_TAGS:
		tags.append(StringName(tg))
		lists.append([])
	var floor_list: Array[int] = []
	for y in range(height):
		for x in range(width):
			var i := y * width + x
			if walk[i] == 0:
				continue
			var b := 0
			if y == 0 or walk[i - width] == 0: b |= WALL_N
			if y == height - 1 or walk[i + width] == 0: b |= WALL_S
			if x == width - 1 or walk[i + 1] == 0: b |= WALL_E
			if x == 0 or walk[i - 1] == 0: b |= WALL_W
			walls[i] = b
			floor_list.append(i)
			for t_i in range(tags.size()):
				if has_tag(i, tags[t_i]):
					(lists[t_i] as Array).append(i)
	floor_cells = PackedInt32Array(floor_list)
	for t_i in range(tags.size()):
		tag_cells[tags[t_i]] = PackedInt32Array(lists[t_i])
