extends SceneTree
## Dzieli budynek (scena z Tilesets + BaseCollision) na segmenty sortowania: każda kolumna kafli dostaje podstawę =
## dolna krawędź obrysu BaseCollision w środku kolumny (poza obrysem — najbliższej kolumny w obrysie); kolumny o tej
## samej podstawie tworzą segment — Node2D „Seg_<y>” w Tilesets na wysokości podstawy, bez Y Sort, więc sortuje się
## z postaciami w całości w tym punkcie (postać we wnęce stoi przed jej tylną ścianą, za wysuniętą częścią domu).
## W segmencie węzeł „Sort” z Y Sort: kafle segmentu sortują się między sobą jak dotąd (y kafla + y_sort_origin
## z TileSetu — dach nad oknem, komin na dachu), ale nie mieszają się z postaciami.
## Kafle warstw (wszystkie TileMapLayer w Tilesets poza tymi z z_index != 0, np. Shadow) trafiają do kopii warstw
## w segmentach; położenie kafli w świecie bez zmian. Kolejność warstw (przy równym y): ściany, ramy drzwi, dach,
## rekwizyty, komin. Korzeń i Tilesets dostają Y Sort.
## Uruchomienie: godot --headless --path . -s res://modules/quiz_rpg/tools/segment_building.gd -- [A=B ...] <scena.tscn> ...
## A=B: kolumny z podstawą A idą do segmentu B (np. 14=32 — wnęka drzwi to ta sama bryła co front).
## lift=N: punkt sortowania segmentu N px nad dolną krawędzią obrysu (domy: 15 — postać w drzwiach
## dłużej przed domem, punkt gracza jest ~14 px nad stopami).
const CELL := 16
const ORDER := ["Walls", "DoorFrame", "Roof", "Props", "Chimney"]


var _merge := {}   # podstawa -> podstawa docelowa (argumenty A=B)
var _lift := 0.0   # lift=N


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("lift="):
			_lift = float(arg.get_slice("=", 1))
		elif "=" in arg:
			_merge[float(arg.get_slice("=", 0))] = float(arg.get_slice("=", 1))
		else:
			print(arg, ": ", _segment(arg))
	quit()


func _segment(path: String) -> String:
	var packed := load(path) as PackedScene
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	var tilesets := root.get_node_or_null("Tilesets") as Node2D
	var bc := root.get_node_or_null("BaseCollision") as CollisionPolygon2D
	if tilesets == null or bc == null:
		return "brak Tilesets / BaseCollision"
	var poly: Array[Vector2] = []
	for p in bc.polygon:
		poly.append(bc.transform * p)
	var layers: Array[TileMapLayer] = []
	for n in tilesets.find_children("*", "TileMapLayer", true, false):
		if (n as TileMapLayer).z_index == 0:
			layers.append(n)
	# komórki: podstawa -> warstwa -> [komórki]
	var groups := {}
	var count := 0
	for layer in layers:
		var off := _pos_in(layer, tilesets)
		for c in layer.get_used_cells():
			var base := _base_at(poly, tilesets.position.x + off.x + c.x * CELL + CELL * 0.5)
			base = _merge.get(base, base)
			if not groups.has(base):
				groups[base] = {}
			if not groups[base].has(layer):
				groups[base][layer] = []
			groups[base][layer].append(c)
			count += 1
	var bases := groups.keys()
	bases.sort()
	var segs := {}
	for base: float in bases:
		var seg := Node2D.new()
		seg.name = "Seg_%d" % int(base)
		seg.position = Vector2(0, base - _lift - tilesets.position.y)
		segs[base] = seg
		var sort := Node2D.new()
		sort.name = "Sort"
		sort.y_sort_enabled = true
		seg.add_child(sort)
		var srcs: Array = groups[base].keys()
		srcs.sort_custom(func(a, b): return ORDER.find(_kind(String(a.name))) < ORDER.find(_kind(String(b.name))))
		var made := {}   # nazwa -> nowa warstwa (warstwy o tej samej nazwie, zestawie i przesunięciu — jedna, np. po A=B)
		for src: TileMapLayer in srcs:
			var pos := _pos_in(src, tilesets) - seg.position
			var same: TileMapLayer = made.get(String(src.name))
			if same != null and same.position == pos and same.tile_set == src.tile_set:
				for c: Vector2i in groups[base][src]:
					same.set_cell(c, src.get_cell_source_id(c), src.get_cell_atlas_coords(c), src.get_cell_alternative_tile(c))
				continue
			var nl := TileMapLayer.new()
			nl.name = String(src.name) if same == null else "%s_%d" % [src.name, made.size()]
			made[String(nl.name)] = nl
			nl.tile_set = src.tile_set
			nl.y_sort_enabled = true
			nl.rendering_quadrant_size = src.rendering_quadrant_size
			nl.collision_enabled = src.collision_enabled
			nl.navigation_enabled = src.navigation_enabled
			nl.modulate = src.modulate
			nl.self_modulate = src.self_modulate
			nl.position = pos
			for c: Vector2i in groups[base][src]:
				nl.set_cell(c, src.get_cell_source_id(c), src.get_cell_atlas_coords(c), src.get_cell_alternative_tile(c))
			sort.add_child(nl)
	# warstwy z z_index != 0 (np. WallsDetail pod Walls) zostają — spod usuwanych warstw idą do Tilesets
	for n in tilesets.find_children("*", "TileMapLayer", true, false):
		var kept := n as TileMapLayer
		if kept.z_index != 0 and kept.get_parent() != tilesets and layers.has(kept.get_parent()):
			var pos := _pos_in(kept, tilesets)
			kept.get_parent().remove_child(kept)
			tilesets.add_child(kept)
			kept.owner = root
			kept.position = pos
	# stare warstwy i puste grupy precz, segmenty na ich miejsce
	for layer in layers:
		if is_instance_valid(layer) and layer.get_parent() != null:
			layer.get_parent().remove_child(layer)
			layer.free()
	for n in tilesets.get_children():
		if n is Node2D and not (n is TileMapLayer) and n.find_children("*", "TileMapLayer", true, false).is_empty():
			tilesets.remove_child(n)
			n.free()
	for base: float in bases:
		tilesets.add_child(segs[base])
		for n in [segs[base]] + segs[base].find_children("*", "", true, false):
			n.owner = root
	root.y_sort_enabled = true
	tilesets.y_sort_enabled = true
	var out := PackedScene.new()
	var err := out.pack(root)
	if err != OK:
		return "pack: " + error_string(err)
	err = ResourceSaver.save(out, path)
	root.free()
	return "%d kafli, segmenty %s, zapis %s" % [count, bases, error_string(err)]


## Rodzaj warstwy z nazwy (Walls2 -> Walls, Roof2 -> Roof).
func _kind(n: String) -> String:
	for k in ORDER:
		if n.begins_with(k):
			return k
	return n


func _pos_in(node: Node2D, ancestor: Node2D) -> Vector2:
	var p := Vector2.ZERO
	var n: Node = node
	while n != ancestor and n != null:
		p += (n as Node2D).position
		n = n.get_parent()
	return p


## Dolna krawędź obrysu w kolumnie x (największe y przecięcia pionu z krawędziami); poza obrysem — najbliższy x obrysu.
func _base_at(poly: Array[Vector2], x: float) -> float:
	var xmin := INF
	var xmax := -INF
	for p in poly:
		xmin = minf(xmin, p.x)
		xmax = maxf(xmax, p.x)
	x = clampf(x, xmin + 0.5, xmax - 0.5)
	var best := -INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if (a.x <= x and x <= b.x) or (b.x <= x and x <= a.x):
			if is_equal_approx(a.x, b.x):
				best = maxf(best, maxf(a.y, b.y))
			else:
				best = maxf(best, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return best
