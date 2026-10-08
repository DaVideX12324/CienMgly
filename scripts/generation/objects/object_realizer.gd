class_name ObjectRealizer
extends RefCounted

const GenProgress = preload("../core/gen_progress.gd")

## ObjectPlan -> scena (główny wątek). Trzy ścieżki, wg tego, czego obiekt potrzebuje:
## - kafel (placement grid + atlas, nie INTERACTIVE): warstwa Decals (DECAL) albo
##   Props (PROP, y-sort); kolizja z warstwy fizyki TileSetu;
## - canvas item (grid_jitter / free): RenderingServer pod węzłem Objects (y-sort razem z encjami),
##   grafika = region atlasu TileSetu; kolizja: kształty w jednym statycznym body PhysicsServer2D
##   na fragment CHUNK×CHUNK kratek;
## - wypieczona scena (DECAL/PROP z "scene", statyczna — ObjectBake): canvas item ze sprite'ami sceny
##   (PROP pod Objects, DECAL pod DecalItems — oba z = 0 z y-sortem) + jej kształty w body fragmentu;
##   scena niestatyczna (skrypt, animacja…) -> instancja;
## - scena (INTERACTIVE): instancja w Objects (alias ze `scenes` albo ścieżka res://).
## RID-y trzyma węzeł ObjectRuntime poziomu (zwalniane przy regeneracji i usunięciu poziomu).

const SOURCE_ID := 0
const CHUNK := 32
const RUNTIME_NAME := "ObjectRuntime"
const DECALS := "Decals"
const PROPS := "Props"
const DECAL_ITEMS := "DecalItems"
## Warstwy kafli obiektów z własnym "layer" w katalogu (czyszczone przy regeneracji jak Decals / Props).
const EXTRA_LAYERS := ["WallDecor"]
## DECAL sortuje się po GÓRNEJ krawędzi kratki (origin = jej środek), więc postać stojąca na nim
## albo niżej zawsze go przykrywa, a ściana nad nim nachodzi na niego jak na podłogę.
const DECAL_SORT_LIFT := ObjectDef.CELL * 0.5
const GROUP := &"generated_objects"
## Obiekt na licu sortuje się prawie na dole kratki kotwicy (origin = jej środek).
const WALL_SORT_DROP := ObjectDef.CELL * 0.5 - 1.0


## Czyści poprzednie obiekty i stawia nowe. `plan` == null -> tylko czyszczenie.
## budget_ms > 0: po przekroczeniu tylu ms pracy czeka klatkę (wołać z await); 0 = od razu.
## Budżet czasu zamiast stałej liczby obiektów — obiekt kosztuje mikrosekundy (kafel/canvas item),
## a stała liczba na klatkę zamieniała ~10 tys. obiektów w ~1800 klatek czekania.
static func realize(level: Node2D, plan: ObjectPlan, tileset: TileSet, scenes: Dictionary = {}, budget_ms: int = 0) -> ObjectRuntime:
	var runtime := level.get_node_or_null(RUNTIME_NAME) as ObjectRuntime
	if runtime == null:
		runtime = ObjectRuntime.new()
		runtime.name = RUNTIME_NAME
		level.add_child(runtime)
	runtime.clear()
	for layer_name in [DECALS, PROPS] + EXTRA_LAYERS:
		var old := level.get_node_or_null(layer_name) as TileMapLayer
		if old != null:
			old.clear()
	var objects := _objects_node(level)
	var decal_items := _decal_items_node(level)
	for child in objects.get_children():
		if child.is_in_group(GROUP):
			child.queue_free()
	if plan == null or plan.placements.is_empty():
		return runtime

	var source: TileSetAtlasSource = null
	if tileset != null and tileset.has_source(SOURCE_ID):
		source = tileset.get_source(SOURCE_ID) as TileSetAtlasSource
	# Warstwa fizyki obiektów ("ObjectCollisions") — gracz i wrogowie mają ją w masce.
	var layer_bits := ObjectBake.object_layer_bit()
	var space := level.get_world_2d().space if level.is_inside_tree() else RID()
	var chunk_bodies := {}
	var scene_cache := {}
	var made := 0
	var budget_us := budget_ms * 1000
	var slice_start := Time.get_ticks_usec()
	var stack_cells := {}   # kratki obiektów ze stack (skrzynia na skrzyni)
	for pl in plan.placements:
		if pl.def.stack:
			stack_cells[pl.cell] = true
	for pl in plan.placements:
		var def := pl.def
		if def.klass == ObjectDef.Klass.INTERACTIVE:
			_place_scene(objects, pl, def.scene, scenes, scene_cache, runtime)
		elif not def.bakes.is_empty():
			var b := def.bakes[pl.variant]
			if b.static_ok:
				if def.is_wall_mounted():
					# Na licu: y-sort tuż nad górną krawędzią podłogi pod licem — nad kaflami lica,
					# pod postacią stojącą przy ścianie.
					_place_baked(objects, b, pl, runtime, -WALL_SORT_DROP)
				elif def.klass == ObjectDef.Klass.DECAL:
					_place_baked(decal_items, b, pl, runtime, DECAL_SORT_LIFT)
				else:
					_place_baked(objects, b, pl, runtime)
				if b.has_collision() and def.is_solid():
					_add_baked_shapes(runtime, chunk_bodies, space, b.collision_layer if b.collision_layer != 0 else layer_bits, b, pl)
			else:
				_place_scene(objects, pl, b.path, scenes, scene_cache, runtime)
		elif def.renders_as_tile():
			_place_tile(level, tileset, pl, runtime, def.stack and stack_cells.has(pl.cell + Vector2i(0, 1)))
		elif source != null and not def.atlas.is_empty():
			if def.source_id != SOURCE_ID and tileset.has_source(def.source_id):
				_place_item(objects, tileset.get_source(def.source_id) as TileSetAtlasSource, pl, runtime)
			else:
				_place_item(objects, source, pl, runtime)
			if def.is_solid():
				_add_shape(runtime, chunk_bodies, space, layer_bits, pl)
		made += 1
		if budget_us > 0 and (made & 15) == 0 and Time.get_ticks_usec() - slice_start >= budget_us:
			GenProgress.sub_in(&"props", float(made) / plan.placements.size())
			await level.get_tree().process_frame
			slice_start = Time.get_ticks_usec()
	return runtime


static func _objects_node(level: Node2D) -> Node2D:
	var objects := level.get_node_or_null("Objects") as Node2D
	if objects == null:
		objects = Node2D.new()
		objects.name = "Objects"
		objects.y_sort_enabled = true
		level.add_child(objects)
	return objects


## Wypieczone DECAL-e: z = 0 z y-sortem (nad trawą z FloorDecor, która na z = -1 sortuje się
## kaflami po Y i przykrywała cały węzeł); pod postaciami dzięki DECAL_SORT_LIFT.
static func _decal_items_node(level: Node2D) -> Node2D:
	var n := level.get_node_or_null(DECAL_ITEMS) as Node2D
	if n == null:
		n = Node2D.new()
		n.name = DECAL_ITEMS
		level.add_child(n)
	n.z_index = 0
	n.y_sort_enabled = true
	return n


static func _layer(level: Node2D, tileset: TileSet, layer_name: String) -> TileMapLayer:
	var layer := level.get_node_or_null(layer_name) as TileMapLayer
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = layer_name
		level.add_child(layer)
	layer.tile_set = tileset
	layer.z_index = 0   # Decals też na 0 — na -1 przykrywa je trawa (FloorDecor) i ściany
	layer.y_sort_enabled = true
	return layer


static func _place_tile(level: Node2D, tileset: TileSet, pl: ObjectPlacement, runtime: ObjectRuntime, on_stack := false) -> void:
	var def := pl.def
	# Na licu zawsze Props (y-sort razem ze ścianami), na podłodze DECAL pod Decals.
	var flat := def.klass == ObjectDef.Klass.DECAL and not def.is_wall_mounted()
	var layer := _layer(level, tileset, String(def.layer_name) if def.layer_name != &"" else (DECALS if flat else PROPS))
	if not def.tiles.is_empty():
		# Moduł z kilku kafli (np. kratka 9-slice) — sortowanie / kolizja z danych kafli TileSetu.
		for t in def.tiles:
			layer.set_cell(pl.cell + (t["off"] as Vector2i), def.source_id, t["coords"])
			runtime.counts["tiles"] += 1
		return
	var alt := TileSetAtlasSource.TRANSFORM_FLIP_H if pl.flip else 0
	var coords: Vector2i = def.atlas[pl.variant]
	if on_stack:
		var src := tileset.get_source(def.source_id) as TileSetAtlasSource
		if src != null and src.has_alternative_tile(coords, ObjectDef.STACK_ALT):
			alt |= ObjectDef.STACK_ALT
	layer.set_cell(pl.cell, def.source_id, coords, alt)
	runtime.counts["tiles"] += 1


## Region atlasu dla wariantu (size kratek w prawo i w górę od kafla wariantu).
static func _region(source: TileSetAtlasSource, coords: Vector2i, size: Vector2i) -> Rect2:
	var rs := source.texture_region_size
	var step := rs + source.separation
	var pos := source.margins + coords * step
	return Rect2(Vector2(pos), Vector2(size * rs + (size - Vector2i.ONE) * source.separation))


static func _place_item(objects: Node2D, source: TileSetAtlasSource, pl: ObjectPlacement, runtime: ObjectRuntime) -> void:
	var def := pl.def
	var region := _region(source, def.atlas[pl.variant], def.size)
	var item := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, objects.get_canvas_item())
	# Punkt obiektu = środek dołu podstawy -> y-sort po podstawie; sprite rośnie w górę.
	var sx := -1.0 if pl.flip else 1.0
	RenderingServer.canvas_item_set_transform(item, Transform2D(0.0, Vector2(sx, 1.0), 0.0, pl.point()))
	RenderingServer.canvas_item_add_texture_rect_region(item,
		Rect2(Vector2(-region.size.x * 0.5, -region.size.y), region.size), source.texture.get_rid(), region)
	runtime.items.append(item)
	runtime.counts["items"] += 1


static func _add_shape(runtime: ObjectRuntime, chunk_bodies: Dictionary, space: RID, layer_bits: int, pl: ObjectPlacement) -> void:
	var def := pl.def
	var body := _chunk_body(runtime, chunk_bodies, space, layer_bits, pl.cell)
	var shape: RID
	if def.shape_radius > 0.0:
		shape = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(shape, def.shape_radius)
	else:
		shape = PhysicsServer2D.rectangle_shape_create()
		PhysicsServer2D.shape_set_data(shape, def.shape_rect * 0.5)
	PhysicsServer2D.body_add_shape(body, shape, Transform2D(0.0, pl.point() + def.shape_offset))
	runtime.shapes.append(shape)
	runtime.counts["shapes"] += 1


## Statyczne body fragmentu CHUNK×CHUNK kratek (osobne per warstwa kolizji).
static func _chunk_body(runtime: ObjectRuntime, chunk_bodies: Dictionary, space: RID, layer_bits: int, cell: Vector2i) -> RID:
	var key := Vector3i(cell.x / CHUNK, cell.y / CHUNK, layer_bits)
	var body: RID = chunk_bodies.get(key, RID())
	if body.is_valid():
		return body
	body = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(body, PhysicsServer2D.BODY_MODE_STATIC)
	if space.is_valid():
		PhysicsServer2D.body_set_space(body, space)
	PhysicsServer2D.body_set_state(body, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D.IDENTITY)
	PhysicsServer2D.body_set_collision_layer(body, layer_bits)
	PhysicsServer2D.body_set_collision_mask(body, 0)
	chunk_bodies[key] = body
	runtime.bodies.append(body)
	return body


## Transformacja origin obiektu (z odbiciem).
static func _origin_xform(pl: ObjectPlacement) -> Transform2D:
	return Transform2D(0.0, Vector2(-1.0 if pl.flip else 1.0, 1.0), 0.0, pl.origin())


## Wypieczona scena: jeden canvas item na obiekt (y-sort po origin), sprite'y jako komendy rysowania.
## Transformacja canvas itemu: origin obiektu podniesiony o sort_lift (punkt y-sortu).
static func item_xform(pl: ObjectPlacement, sort_lift: float = 0.0) -> Transform2D:
	var xf := _origin_xform(pl)
	xf.origin.y -= sort_lift
	return xf


## sort_lift: punkt y-sortu o tyle px wyżej niż origin (rysunek bez zmian).
static func _place_baked(parent: Node2D, b: ObjectBake, pl: ObjectPlacement, runtime: ObjectRuntime, sort_lift: float = 0.0) -> void:
	var item := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, parent.get_canvas_item())
	RenderingServer.canvas_item_set_transform(item, item_xform(pl, sort_lift))
	var back := Transform2D(0.0, Vector2(0.0, sort_lift))
	for sp in b.sprites:
		RenderingServer.canvas_item_add_set_transform(item, back * (sp["xform"] as Transform2D))
		RenderingServer.canvas_item_add_texture_rect_region(item, sp["dst"], (sp["tex"] as Texture2D).get_rid(), sp["src"], sp["color"])
	runtime.items.append(item)
	runtime.counts["items"] += 1


## Kształty wypieczonej sceny (zasoby Shape2D trzyma cache ObjectBake — runtime ich nie zwalnia).
static func _add_baked_shapes(runtime: ObjectRuntime, chunk_bodies: Dictionary, space: RID, layer_bits: int, b: ObjectBake, pl: ObjectPlacement) -> void:
	var body := _chunk_body(runtime, chunk_bodies, space, layer_bits, pl.cell)
	var oxf := _origin_xform(pl)
	for sh in b.shapes:
		PhysicsServer2D.body_add_shape(body, (sh["shape"] as Shape2D).get_rid(), oxf * (sh["xform"] as Transform2D))
		runtime.counts["shapes"] += 1


## Pierwszy węzeł sceny z właściwością unique_id (skrypt skrzyni bywa w dziecku korzenia).
static func _set_unique_id(node: Node, id: String) -> bool:
	if "unique_id" in node:
		if String(node.get("unique_id")).is_empty():
			node.set("unique_id", id)
		return true
	for c in node.get_children():
		if _set_unique_id(c, id):
			return true
	return false


## Scena: pozycja = środek dolnego wiersza podstawy (1×1 -> środek kratki, jak dotychczasowe skrzynie).
static func _place_scene(objects: Node2D, pl: ObjectPlacement, path: String, scenes: Dictionary, cache: Dictionary, runtime: ObjectRuntime) -> void:
	var packed: PackedScene = cache.get(path)
	if packed == null:
		packed = scenes.get(StringName(path)) as PackedScene
		if packed == null and path.begins_with("res://") and ResourceLoader.exists(path):
			packed = load(path) as PackedScene
		if packed == null:
			push_warning("ObjectRealizer: brak sceny '%s' (obiekt '%s')." % [path, pl.def.id])
			return
		cache[path] = packed
	var inst := packed.instantiate() as Node2D
	if inst == null:
		return
	inst.position = pl.origin()
	# Stałe id (stan skrzyni w LevelStateManager): obiekt + kratka — ta sama mapa = te same id.
	_set_unique_id(inst, "%s_%d_%d" % [pl.def.id, pl.cell.x, pl.cell.y])
	if pl.flip:
		inst.scale.x = -1.0
	inst.add_to_group(GROUP)
	objects.add_child(inst)
	runtime.counts["scenes"] += 1
