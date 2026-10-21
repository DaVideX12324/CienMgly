class_name QuizRpgMinimapData
extends RefCounted

## Dane minimapy jednej mapy: rodzaj każdej kratki (podłoga, płaskowyż, ściana, uskok, wejście / wyjście) i maska odkrycia
## (fog of war). Mapa generowana: z wyniku generacji (ProceduralLevel.last_result — siatka, płaskowyże, portale); mapa
## ręczna: z warstw TileMapLayer (Walls / Cliffs = ściana — tylko kafle z kolizją, dekoracje bez kolizji to podłoga; reszta
## warstw = podłoga). Odkrywanie: kratki w promieniu od gracza z linią wzroku — ściany zasłaniają (same się odkrywają),
## uskoki płaskowyżów nie. Kolory podłogi i ścian: średnia z tekstur kafli mapy (floor_color / wall_color).

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
## Średni kolor kafli podłogi / ścian tej mapy (has_colors = policzone; inaczej minimapa bierze swoje domyślne).
var floor_color := Color(0.56, 0.5, 0.42)
var wall_color := Color(0.12, 0.1, 0.09)
var has_colors := false


## Z węzła poziomu: wynik generacji, gdy jest; inaczej warstwy kafli. null = brak danych (pusta mapa).
static func from_level(level: Node) -> QuizRpgMinimapData:
	if level == null:
		return null
	var result = level.get("last_result")
	var d: QuizRpgMinimapData
	if result != null and "grid" in result and not (result.grid as Dictionary).is_empty():
		d = from_result(result)
	else:
		d = from_layers(level)
	if d != null:
		d._average_colors(level)
	return d


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
		var no_physics := layer.tile_set.get_physics_layers_count() == 0
		for c in layer.get_used_cells():
			var p := Vector2i((Vector2(c) * scale + layer.position / float(CELL)).floor())
			# Kafel wielokratkowy (np. podłoga 2×1, ściana 1×2) jest zapisany tylko w kratce kotwicy — zajmuje też sąsiednie.
			var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
			var span := src.get_tile_size_in_atlas(layer.get_cell_atlas_coords(c)) if src != null else Vector2i.ONE
			# Na warstwie ścian liczy się tylko kafel z kolizją — bez niej to dekoracja (sztandar) albo wypełnienie
			# pustki; podłoga pod spodem i tak jest na warstwie podłogi.
			var target: Variant = floors if not is_wall else (walls if no_physics or _blocks(layer, c) else null)
			if target == null:
				continue
			for dy in span.y:
				for dx in span.x:
					(target as Dictionary)[p + Vector2i(dx, dy)] = true
	if floors.is_empty():
		return null
	# Prostokąt z samej podłogi (+1 na obrys ścian) — ściany daleko od podłogi nie powiększają mapy.
	var r := Rect2i(floors.keys()[0], Vector2i.ONE)
	for p: Vector2i in floors:
		r = r.expand(p)
	r = r.grow(1)
	var d := QuizRpgMinimapData.new()
	d._alloc(r.size.x + 1, r.size.y + 1, r.position)
	for p: Vector2i in floors:
		if not walls.has(p):
			d.kinds[d.index(p)] = FLOOR
	return d


static func _blocks(layer: TileMapLayer, c: Vector2i) -> bool:
	var td := layer.get_cell_tile_data(c)
	return td != null and td.get_collision_polygons_count(0) > 0


## Średnie kolory z tekstur kafli: podłoga z warstwy „Floor” (bez niej — ze wszystkich warstw poza ścianami), ściany
## z warstw Walls / Cliffs. Próbka do MAX_SAMPLES kratek na warstwę, co drugi piksel, bez przezroczystych.
const MAX_SAMPLES := 160
const MIN_CONTRAST := 0.12


func _average_colors(level: Node) -> void:
	var floor_layers: Array[TileMapLayer] = []
	var wall_layers: Array[TileMapLayer] = []
	var named_floor: TileMapLayer = null
	for n in level.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		if layer.tile_set == null or not layer.visible:
			continue
		var nm := String(layer.name).to_lower()
		if WALL_LAYERS.has(nm):
			wall_layers.append(layer)
		else:
			floor_layers.append(layer)
			if nm == "floor":
				named_floor = layer
	if named_floor != null:
		floor_layers = [named_floor]
	var images := {}
	var f: Variant = _average_of(floor_layers, images)
	var w: Variant = _average_of(wall_layers, images, true)
	if f != null:
		floor_color = f
		has_colors = true
	if w != null:
		wall_color = w
		has_colors = true
	# Czytelność: ściany o podobnej jasności co podłoga (np. samouczek) przyciemnione, odcień ze średniej zostaje.
	if absf(wall_color.get_luminance() - floor_color.get_luminance()) < MIN_CONTRAST:
		wall_color = wall_color.darkened(0.5)


## solid_only: tylko kafle z kolizją (warstwa ścian bez wypełnienia pustki i dekoracji), gdy TileSet ma fizykę.
static func _average_of(layers: Array[TileMapLayer], images: Dictionary, solid_only := false) -> Variant:
	var sum := Vector3.ZERO
	var n := 0
	for layer in layers:
		var cells := layer.get_used_cells()
		if solid_only and layer.tile_set.get_physics_layers_count() > 0:
			cells = cells.filter(func(c: Vector2i) -> bool: return _blocks(layer, c))
		var step := maxi(1, cells.size() / MAX_SAMPLES)
		for k in range(0, cells.size(), step):
			var c: Vector2i = cells[k]
			var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
			if src == null or src.texture == null:
				continue
			var im: Image = images.get(src.texture)
			if im == null:
				im = src.texture.get_image()
				if im == null:
					continue
				if im.is_compressed():
					im.decompress()
				images[src.texture] = im
			var region := src.get_tile_texture_region(layer.get_cell_atlas_coords(c))
			for y in range(region.position.y, mini(region.end.y, im.get_height()), 2):
				for x in range(region.position.x, mini(region.end.x, im.get_width()), 2):
					var px := im.get_pixel(x, y)
					if px.a > 0.5:
						sum += Vector3(px.r, px.g, px.b)
						n += 1
	if n == 0:
		return null
	return Color(sum.x / n, sum.y / n, sum.z / n)


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
