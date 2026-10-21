class_name QuizRpgMinimapData
extends RefCounted

## Dane minimapy jednej mapy: rodzaj każdej kratki (podłoga, płaskowyż, ściana, uskok, wejście / wyjście), jej kolor i maska
## odkrycia (fog of war). Mapa generowana: rodzaje z wyniku generacji (ProceduralLevel.last_result — siatka, płaskowyże,
## portale); mapa ręczna: z warstw TileMapLayer — podłoga = warstwy z z_index < 0 (teren, trawa, ścieżki, dekoracje
## podłogi), ściana = kafel z kolizją na warstwie Walls / Cliffs albo na warstwie nad podłogą (z_index >= 0: ściany budynków);
## kafle bez kolizji nad podłogą (dachy, drzwi, propsy, sztandary, wypełnienie pustki) się nie liczą.
## Kolor kratki podłogi: średni kolor kafla z najwyżej rysowanej warstwy podłogi na niej (np. trawa nad terenem — decyzja
## usera 2026-10-21, bez mieszania z warstwami pod spodem). Ściany: średnia z kafli ścian mapy.
## Odkrywanie: kratki w promieniu od gracza z linią wzroku — ściany zasłaniają (same się odkrywają), uskoki płaskowyżów nie.

const CELL := 16
const UNKNOWN := 0
const FLOOR := 1
const HIGH := 2      # góra płaskowyżu
const WALL := 3      # ściana przy podłodze (obrys)
const CLIFF := 4     # bariera płaskowyżu (rim, lico)
const ENTRANCE := 5
const EXIT := 6
## Warstwy ścian po nazwie węzła (bez wielkości liter) — także gdy leżą pod podłogą w kolejności rysowania.
const WALL_LAYERS := ["walls", "cliffs"]
const MAX_SAMPLES := 160
const MIN_CONTRAST := 0.12

var width := 0
var height := 0
var origin := Vector2i.ZERO   # kratka mapy odpowiadająca (0, 0) danych
var kinds := PackedByteArray()
var revealed := PackedByteArray()
## Kolor kratki podłogi z kafli (indeks jak kinds; alfa 0 = brak kafli — minimapa bierze floor_color).
var cell_colors := PackedColorArray()
## Średni kolor podłogi / ścian tej mapy (has_colors = policzone; inaczej minimapa bierze swoje domyślne).
var floor_color := Color(0.56, 0.5, 0.42)
var wall_color := Color(0.12, 0.1, 0.09)
var has_colors := false

var _images := {}       # Texture2D -> Image (zdekompresowany obraz atlasu)
var _tile_avg := {}     # "<tileset id>:<źródło>:<x>:<y>" -> [Color, pokrycie 0..1]


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
		d._paint_layers(level)
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
	for layer in _layers(level):
		var is_floor := _is_floor_layer(layer)
		var no_physics := layer.tile_set.get_physics_layers_count() == 0
		for c in layer.get_used_cells():
			if not is_floor and not (no_physics and _is_named_wall(layer)) and not _blocks(layer, c):
				continue   # nad podłogą liczy się tylko kafel z kolizją
			for p in _cells_of(layer, c):
				if is_floor:
					floors[p] = true
				else:
					walls[p] = true
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


## Widoczne warstwy kafli poziomu, od najniżej rysowanej (z_index, potem kolejność w drzewie).
static func _layers(level: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for n in level.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		if layer.tile_set != null and layer.visible:
			out.append(layer)
	var order := {}
	for i in out.size():
		order[out[i]] = i
	out.sort_custom(func(a: TileMapLayer, b: TileMapLayer) -> bool:
		return a.z_index < b.z_index if a.z_index != b.z_index else int(order[a]) < int(order[b]))
	return out


static func _is_named_wall(layer: TileMapLayer) -> bool:
	return WALL_LAYERS.has(String(layer.name).to_lower())


static func _is_floor_layer(layer: TileMapLayer) -> bool:
	return layer.z_index < 0 and not _is_named_wall(layer)


static func _blocks(layer: TileMapLayer, c: Vector2i) -> bool:
	if layer.tile_set.get_physics_layers_count() == 0:
		return false
	var td := layer.get_cell_tile_data(c)
	return td != null and td.get_collision_polygons_count(0) > 0


## Kratki minimapy zajęte przez kafel warstwy w komórce `c`: kafel wielokratkowy (np. podłoga 2×1, ściana 1×2) jest zapisany
## tylko w kratce kotwicy, a zajmuje też sąsiednie; warstwa może być przesunięta i mieć inny rozmiar kafla.
static func _cells_of(layer: TileMapLayer, c: Vector2i) -> Array[Vector2i]:
	var scale := Vector2(layer.tile_set.tile_size) / float(CELL)
	var p := Vector2i((Vector2(c) * scale + layer.position / float(CELL)).floor())
	var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
	var ac := layer.get_cell_atlas_coords(c)
	var span := src.get_tile_size_in_atlas(ac) if src != null and src.has_tile(ac) else Vector2i.ONE   # kafel usunięty z atlasu
	var out: Array[Vector2i] = []
	for dy in span.y:
		for dx in span.x:
			out.append(p + Vector2i(dx, dy))
	return out


## Kolory z kafli: każda kratka podłogi — kafel najwyżej rysowanej warstwy podłogi (warstwy od dołu, wyższa nadpisuje);
## średnia podłogi z kratek, średnia ścian z kafli z kolizją (warstwy ścian i nad podłogą).
func _paint_layers(level: Node) -> void:
	cell_colors.resize(width * height)
	cell_colors.fill(Color(0, 0, 0, 0))
	var wall_layers: Array[TileMapLayer] = []
	for layer in _layers(level):
		if not _is_floor_layer(layer):
			wall_layers.append(layer)
			continue
		for c in layer.get_used_cells():
			var avg := _tile_color(layer, c)
			if avg.is_empty():
				continue
			var top: Color = avg[0]
			for p in _cells_of(layer, c):
				if has_cell(p):
					cell_colors[index(p)] = top
	var sum := Vector3.ZERO
	var n := 0
	for i in cell_colors.size():
		if cell_colors[i].a > 0.0 and kinds[i] != UNKNOWN:
			sum += Vector3(cell_colors[i].r, cell_colors[i].g, cell_colors[i].b)
			n += 1
	if n > 0:
		floor_color = Color(sum.x / n, sum.y / n, sum.z / n)
		has_colors = true
	var w: Variant = _average_walls(wall_layers)
	if w != null:
		wall_color = w
		has_colors = true
	# Czytelność: ściany o podobnej jasności co podłoga (np. samouczek) przyciemnione, odcień ze średniej zostaje.
	if absf(wall_color.get_luminance() - floor_color.get_luminance()) < MIN_CONTRAST:
		wall_color = wall_color.darkened(0.5)
	_images.clear()


## Kolor kratki podłogi z kafli (alfa 0 = brak kafli).
func color_at(p: Vector2i) -> Color:
	return cell_colors[index(p)] if has_cell(p) and not cell_colors.is_empty() else Color(0, 0, 0, 0)


## [średni kolor nieprzezroczystych pikseli, pokrycie] kafla w komórce; [] = brak tekstury.
func _tile_color(layer: TileMapLayer, c: Vector2i) -> Array:
	var sid := layer.get_cell_source_id(c)
	var ac := layer.get_cell_atlas_coords(c)
	var key := "%d:%d:%d:%d" % [layer.tile_set.get_instance_id(), sid, ac.x, ac.y]
	if _tile_avg.has(key):
		return _tile_avg[key]
	var out: Array = []
	var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
	var im := _image_of(src)
	if im != null and src.has_tile(ac):
		var region := src.get_tile_texture_region(ac)
		var sum := Vector3.ZERO
		var n := 0
		var total := 0
		for y in range(region.position.y, mini(region.end.y, im.get_height()), 2):
			for x in range(region.position.x, mini(region.end.x, im.get_width()), 2):
				total += 1
				var px := im.get_pixel(x, y)
				if px.a > 0.5:
					sum += Vector3(px.r, px.g, px.b)
					n += 1
		if n > 0:
			out = [Color(sum.x / n, sum.y / n, sum.z / n), float(n) / float(total)]
	_tile_avg[key] = out
	return out


func _image_of(src: TileSetAtlasSource) -> Image:
	if src == null or src.texture == null:
		return null
	if _images.has(src.texture):
		return _images[src.texture]
	var im := src.texture.get_image()
	if im != null and im.is_compressed():
		im.decompress()
	_images[src.texture] = im
	return im


## Średnia ścian: próbka do MAX_SAMPLES kafli z kolizją na warstwę (bez wypełnienia pustki i dekoracji), gdy TileSet ma
## fizykę; kafel waży tyle, ile ma pokrycia.
func _average_walls(layers: Array[TileMapLayer]) -> Variant:
	var sum := Vector3.ZERO
	var w := 0.0
	for layer in layers:
		var cells := layer.get_used_cells()
		if layer.tile_set.get_physics_layers_count() > 0:
			cells = cells.filter(func(c: Vector2i) -> bool: return _blocks(layer, c))
		var step := maxi(1, cells.size() / MAX_SAMPLES)
		for k in range(0, cells.size(), step):
			var avg := _tile_color(layer, cells[k])
			if avg.is_empty():
				continue
			var col: Color = avg[0]
			sum += Vector3(col.r, col.g, col.b) * float(avg[1])
			w += float(avg[1])
	if w <= 0.0:
		return null
	return Color(sum.x / w, sum.y / w, sum.z / w)


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
