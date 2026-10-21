class_name QuizRpgMinimapData
extends RefCounted

## Dane minimapy jednej mapy: rodzaj każdej kratki (podłoga, płaskowyż, ściana, uskok, wejście / wyjście) i maska odkrycia
## (fog of war). Mapa generowana: z wyniku generacji (ProceduralLevel.last_result — siatka, płaskowyże, portale); mapa
## ręczna: z warstw TileMapLayer (Walls / Cliffs = ściana, reszta = podłoga). Odkrywanie: kratki w promieniu od gracza
## z linią wzroku — ściany zasłaniają (same się odkrywają), uskoki płaskowyżów nie.

const CELL := 16
const UNKNOWN := 0
const FLOOR := 1
const HIGH := 2      # góra płaskowyżu
const WALL := 3      # ściana przy podłodze (obrys)
const CLIFF := 4     # bariera płaskowyżu (rim, lico)
const ENTRANCE := 5
const EXIT := 6
## Warstwy ręcznych map traktowane jako ściany (po nazwie węzła, bez wielkości liter).
const WALL_LAYERS := ["walls", "cliffs"]

var width := 0
var height := 0
var origin := Vector2i.ZERO   # kratka mapy odpowiadająca (0, 0) danych
var kinds := PackedByteArray()
var revealed := PackedByteArray()


## Z węzła poziomu: wynik generacji, gdy jest; inaczej warstwy kafli. null = brak danych (pusta mapa).
static func from_level(level: Node) -> QuizRpgMinimapData:
	if level == null:
		return null
	var result = level.get("last_result")
	if result != null and "grid" in result and not (result.grid as Dictionary).is_empty():
		return from_result(result)
	return from_layers(level)


static func from_result(result) -> QuizRpgMinimapData:
	var d := QuizRpgMinimapData.new()
	d._alloc(int(result.width), int(result.height), Vector2i.ZERO)
	var grid: Dictionary = result.grid
	var pl = result.plateau
	var blocked: Dictionary = pl.blocked if pl != null else {}
	var top: Dictionary = pl.mask if pl != null else {}
	for p: Vector2i in grid:
		if not d.has_cell(p):
			continue
		if blocked.has(p):
			d.kinds[d.index(p)] = CLIFF
		elif GridUtils.is_walkable(grid, p):
			d.kinds[d.index(p)] = HIGH if top.has(p) else FLOOR
	for z: Vector2i in result.entrance_zone:
		if d.has_cell(z) and d.kinds[d.index(z)] != UNKNOWN:
			d.kinds[d.index(z)] = ENTRANCE
	for z: Vector2i in result.exit_zone:
		if d.has_cell(z) and d.kinds[d.index(z)] != UNKNOWN:
			d.kinds[d.index(z)] = EXIT
	return d


static func from_layers(level: Node) -> QuizRpgMinimapData:
	var floors := {}
	var walls := {}
	for n in level.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		if layer.tile_set == null or not layer.visible:
			continue
		var scale := Vector2(layer.tile_set.tile_size) / float(CELL)
		var is_wall := WALL_LAYERS.has(String(layer.name).to_lower())
		for c in layer.get_used_cells():
			var p := Vector2i((Vector2(c) * scale + layer.position / float(CELL)).floor())
			if is_wall:
				walls[p] = true
			else:
				floors[p] = true
	if floors.is_empty():
		return null
	var r := Rect2i(floors.keys()[0], Vector2i.ONE)
	for p: Vector2i in floors:
		r = r.expand(p)
	for p: Vector2i in walls:
		r = r.expand(p)
	var d := QuizRpgMinimapData.new()
	d._alloc(r.size.x + 1, r.size.y + 1, r.position)
	for p: Vector2i in floors:
		if not walls.has(p):
			d.kinds[d.index(p)] = FLOOR
	return d


func _alloc(w: int, h: int, o: Vector2i) -> void:
	width = w
	height = h
	origin = o
	kinds.resize(w * h)
	kinds.fill(UNKNOWN)
	revealed.resize(w * h)
	revealed.fill(0)


## Pusta kratka przy podłodze (8-sąsiedztwo) = ściana; liczone leniwie przy odkrywaniu (bez przebiegu po całej mapie).
func _touches_floor(p: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var k := kind_at(p + Vector2i(dx, dy))
			if k != UNKNOWN and k != WALL:
				return true
	return false


func has_cell(p: Vector2i) -> bool:
	var q := p - origin
	return q.x >= 0 and q.y >= 0 and q.x < width and q.y < height


func index(p: Vector2i) -> int:
	var q := p - origin
	return q.y * width + q.x


func kind_at(p: Vector2i) -> int:
	return kinds[index(p)] if has_cell(p) else UNKNOWN


func is_revealed(p: Vector2i) -> bool:
	return has_cell(p) and revealed[index(p)] != 0


## Kratka mapy pod punktem świata (lokalnym względem poziomu).
static func cell_of(local_pos: Vector2) -> Vector2i:
	return Vector2i((local_pos / float(CELL)).floor())


func _blocks_sight(p: Vector2i) -> bool:
	var k := kind_at(p)
	return k == UNKNOWN or k == WALL


## Odkrywa kratki w promieniu `radius` od `center` z linią wzroku. Zwraca nowo odkryte kratki (puste = bez zmian).
func reveal(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not has_cell(center):
		return out
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var p := center + Vector2i(dx, dy)
			if not has_cell(p):
				continue
			var i := index(p)
			if revealed[i] != 0:
				continue
			if kinds[i] == UNKNOWN:
				if not _touches_floor(p):
					continue
				kinds[i] = WALL
			if _line_clear(center, p):
				revealed[i] = 1
				out.append(p)
	return out


## Linia wzroku (Bresenham) z `a` do `b`: żadna kratka pośrednia nie zasłania (cel może być ścianą).
func _line_clear(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while true:
		if x == b.x and y == b.y:
			return true
		if (x != a.x or y != a.y) and _blocks_sight(Vector2i(x, y)):
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return true


## Maska odkrycia do zapisu (skompresowana, base64) i z powrotem; inny rozmiar mapy = maska odrzucona.
func mask_to_string() -> String:
	return "%d:%d:%s" % [revealed.size(), width, Marshalls.raw_to_base64(revealed.compress(FileAccess.COMPRESSION_DEFLATE))]


func mask_from_string(s: String) -> bool:
	var parts := s.split(":", true, 2)
	if parts.size() != 3 or int(parts[0]) != revealed.size() or int(parts[1]) != width:
		return false
	var raw := Marshalls.base64_to_raw(parts[2]).decompress(revealed.size(), FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != revealed.size():
		return false
	revealed = raw
	return true
