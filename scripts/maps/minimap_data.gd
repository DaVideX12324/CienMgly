class_name QuizRpgMinimapData
extends RefCounted

## Dane minimapy jednej mapy: rodzaj każdej kratki (podłoga, płaskowyż, ściana, uskok, wejście / wyjście, pustka), kolory
## z kafli i maska odkrycia (fog of war). Mapa generowana: rodzaje z wyniku generacji (ProceduralLevel.last_result — siatka,
## płaskowyże, portale, pustka za wnęką portalu); mapa ręczna: z warstw TileMapLayer — podłoga = warstwy z z_index < 0
## (teren, trawa, ścieżki, dekoracje podłogi), ściana = kafel z kolizją na warstwie nad podłogą (z_index >= 0: ściany
## budynków) albo dowolny kafel na warstwie Walls / Cliffs (z wypełnieniem pustki); dachy, drzwi i propsy się nie liczą.
## Kolory jak na mapie: kratka podłogi — średni kolor kafla z najwyżej rysowanej warstwy podłogi (decyzja usera 2026-10-21);
## kratka ściany — średni kolor najwyższego kafla warstw ścian. Pustka (VOID): kratka bez podłogi z prawie czarnym kaflem
## (lita skała, wypełnienie pustki) albo bez kafla (koniec wnęki portalu) — w kolorze kafla / pustki, nie zasłania widoku.
## Odkrywanie: kratki w promieniu od gracza z linią wzroku; wzrok przechodzi przez SOLID_SIGHT - 1 kratek ściany (lico
## i pustka nad nim, jak na ekranie), ale podłogę widać tylko bez ściany po drodze — pokoje za ścianą zostają ukryte.

const CELL := 16
const UNKNOWN := 0
const FLOOR := 1
const HIGH := 2      # góra płaskowyżu
const WALL := 3      # ściana przy podłodze (obrys)
const CLIFF := 4     # bariera płaskowyżu (rim, lico)
const ENTRANCE := 5
const EXIT := 6
const VOID := 7      # pustka: bez podłogi, z kaflem pustki / litej skały albo bez kafla (koniec wnęki portalu) — nie zasłania
## Warstwy ścian po nazwie węzła (bez wielkości liter) — także gdy leżą pod podłogą w kolejności rysowania.
const WALL_LAYERS := ["walls", "cliffs"]
## Ile kratek ściany na linii wzroku jeszcze się odkrywa (lico 2–3 rzędy).
const SOLID_SIGHT := 4
## Kafel ściany ciemniejszy niż to (średnia jasność) = kafel pustki / litej skały (SOLID_FILL jaskiń, wypełnienie pustki
## samouczka) — na minimapie pustka, nie ściana.
const VOID_LUMA := 0.09

var width := 0
var height := 0
var origin := Vector2i.ZERO   # kratka mapy odpowiadająca (0, 0) danych
var kinds := PackedByteArray()
var revealed := PackedByteArray()
## Kolor kratki podłogi / ściany z kafli (indeks jak kinds; alfa 0 = brak kafla).
var cell_colors := PackedColorArray()
var solid_colors := PackedColorArray()
## Średni kolor podłogi mapy (has_colors = policzony; inaczej minimapa bierze swój domyślny).
var floor_color := Color(0.56, 0.5, 0.42)
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
	for v: Vector2i in result.portal_void:
		if d.has_cell(v):
			d.kinds[d.index(v)] = VOID
	return d


static func from_layers(level: Node) -> QuizRpgMinimapData:
	var floors := {}
	var walls := {}
	for layer in _layers(level):
		var is_floor := _is_floor_layer(layer)
		var named_wall := _is_named_wall(layer)
		var kinds_of := _tiles_by_kind(layer)
		for k: Vector4i in kinds_of:
			var cells: Array = kinds_of[k]
			if is_floor:
				for p in _cells_of(layer, cells, k):
					floors[p] = true
			elif _blocks(layer, cells[0]) or (named_wall and layer.tile_set.get_physics_layers_count() == 0):
				for p in _cells_of(layer, cells, k):
					walls[p] = true
			# Kafle bez kolizji: na Walls / Cliffs (wypełnienie pustki, sztandary) — kratka zostaje podłogą albo skałą
			# z kolorem kafla (solid_colors); nad podłogą (dachy, drzwi, propsy) — pomijane.
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
	var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
	if src == null or not src.has_tile(layer.get_cell_atlas_coords(c)):
		return false  # kafel usunięty z atlasu (komórka wskazuje środek kafla wielokratkowego albo pustkę)
	var td := layer.get_cell_tile_data(c)
	return td != null and td.get_collision_polygons_count(0) > 0


## Komórki warstwy wg rodzaju kafla {Vector4i(źródło, atlas x, atlas y, alternatywa): [komórki]} — zapytania o kafel
## (rozmiar w atlasie, kolizja, kolor) raz na rodzaj, a nie na każdą komórkę (miasto ma ~60 tys. komórek, ~150 rodzajów).
static func _tiles_by_kind(layer: TileMapLayer) -> Dictionary:
	var out := {}
	for c in layer.get_used_cells():
		var ac := layer.get_cell_atlas_coords(c)
		var k := Vector4i(layer.get_cell_source_id(c), ac.x, ac.y, layer.get_cell_alternative_tile(c))
		var list: Variant = out.get(k)
		if list == null:
			out[k] = [c]
		else:
			(list as Array).append(c)
	return out


## Kratki minimapy zajęte przez kafle rodzaju `k` w komórkach `cells`: kafel wielokratkowy (np. podłoga 2×1, ściana 1×2)
## jest zapisany tylko w kratce kotwicy, a zajmuje też sąsiednie; warstwa może być przesunięta i mieć inny rozmiar kafla.
static func _cells_of(layer: TileMapLayer, cells: Array, k: Vector4i) -> Array[Vector2i]:
	var scale := Vector2(layer.tile_set.tile_size) / float(CELL)
	var off := layer.position / float(CELL)
	var src := layer.tile_set.get_source(k.x) as TileSetAtlasSource
	var ac := Vector2i(k.y, k.z)
	var span := src.get_tile_size_in_atlas(ac) if src != null and src.has_tile(ac) else Vector2i.ONE   # kafel usunięty z atlasu
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		var p := Vector2i((Vector2(c) * scale + off).floor())
		for dy in span.y:
			for dx in span.x:
				out.append(p + Vector2i(dx, dy))
	return out


## Kolory z kafli: kratka podłogi — kafel najwyżej rysowanej warstwy podłogi, kratka ściany — kafel najwyżej rysowanej
## warstwy ścian (Walls / Cliffs); warstwy od dołu, wyższa nadpisuje. Średnia podłogi z kratek podłogi.
func _paint_layers(level: Node) -> void:
	cell_colors.resize(width * height)
	cell_colors.fill(Color(0, 0, 0, 0))
	solid_colors.resize(width * height)
	solid_colors.fill(Color(0, 0, 0, 0))
	for layer in _layers(level):
		if _is_floor_layer(layer):
			_paint_layer(layer, false)
		elif _is_named_wall(layer):
			_paint_layer(layer, true)
	# Pustka: bez podłogi, z kaflem pustki / litej skały albo bez żadnego kafla — nie zasłania widoku.
	for i in kinds.size():
		if kinds[i] != UNKNOWN or cell_colors[i].a > 0.0:
			continue
		var sc := solid_colors[i]
		if sc.a == 0.0 or sc.get_luminance() < VOID_LUMA:
			kinds[i] = VOID
	var sum := Vector3.ZERO
	var n := 0
	for i in cell_colors.size():
		var k := kinds[i]
		if cell_colors[i].a > 0.0 and k != UNKNOWN and k != WALL and k != VOID:
			sum += Vector3(cell_colors[i].r, cell_colors[i].g, cell_colors[i].b)
			n += 1
	if n > 0:
		floor_color = Color(sum.x / n, sum.y / n, sum.z / n)
		has_colors = true
	_images.clear()


## Kafle warstwy do cell_colors (podłoga) albo solid_colors (ściany) — tablice to typy wartościowe, więc wprost w polach.
## Komórki po kolei (get_used_cells) — kafle wielokratkowe nachodzą na sąsiednie kratki, wygrywa później malowany.
func _paint_layer(layer: TileMapLayer, solid: bool) -> void:
	var scale := Vector2(layer.tile_set.tile_size) / float(CELL)
	var off := layer.position / float(CELL)
	var per_kind := {}   # Vector4i -> [kolor, rozmiar w atlasie] albo [] (brak tekstury)
	for c in layer.get_used_cells():
		var ac := layer.get_cell_atlas_coords(c)
		var k := Vector4i(layer.get_cell_source_id(c), ac.x, ac.y, layer.get_cell_alternative_tile(c))
		var info: Variant = per_kind.get(k)
		if info == null:
			var avg := _tile_color(layer, k)
			var src := layer.tile_set.get_source(k.x) as TileSetAtlasSource
			info = [] if avg.is_empty() else [avg[0], src.get_tile_size_in_atlas(ac) if src != null and src.has_tile(ac) else Vector2i.ONE]
			per_kind[k] = info
		if (info as Array).is_empty():
			continue
		var col: Color = info[0]
		var span: Vector2i = info[1]
		var base := Vector2i((Vector2(c) * scale + off).floor())
		for dy in span.y:
			for dx in span.x:
				var p := base + Vector2i(dx, dy)
				if not has_cell(p):
					continue
				if solid:
					solid_colors[index(p)] = col
				else:
					cell_colors[index(p)] = col


## Kolor kratki z kafli: podłoga — z warstw podłogi, ściana / skała — z warstw ścian (alfa 0 = brak kafla, czyli pustka).
func color_at(p: Vector2i) -> Color:
	if not has_cell(p) or cell_colors.is_empty():
		return Color(0, 0, 0, 0)
	var k := kind_at(p)
	return solid_colors[index(p)] if k == WALL or k == UNKNOWN or k == VOID else cell_colors[index(p)]


## [średni kolor nieprzezroczystych pikseli, pokrycie] kafla rodzaju `k` (_tiles_by_kind); [] = brak tekstury.
func _tile_color(layer: TileMapLayer, k: Vector4i) -> Array:
	var sid := k.x
	var ac := Vector2i(k.y, k.z)
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


func _alloc(w: int, h: int, o: Vector2i) -> void:
	width = w
	height = h
	origin = o
	kinds.resize(w * h)
	kinds.fill(UNKNOWN)
	revealed.resize(w * h)
	revealed.fill(0)


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
			var solid := kinds[i] == UNKNOWN or kinds[i] == WALL
			var crossed := _walls_between(center, p, SOLID_SIGHT)
			if crossed == 0 or (solid and crossed < SOLID_SIGHT):
				if kinds[i] == UNKNOWN:
					kinds[i] = WALL
				revealed[i] = 1
				out.append(p)
	return out


## Liczba kratek ściany na linii wzroku (Bresenham) między `a` i `b`, bez końców; liczenie kończy się na `limit`.
func _walls_between(a: Vector2i, b: Vector2i, limit: int) -> int:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var n := 0
	while not (x == b.x and y == b.y):
		if (x != a.x or y != a.y) and _blocks_sight(Vector2i(x, y)):
			n += 1
			if n >= limit:
				return n
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return n


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
