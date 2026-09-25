class_name ObjectRealizer
extends RefCounted

## ObjectPlan -> scena (główny wątek). Trzy ścieżki, wg tego, czego obiekt potrzebuje:
## - kafel (placement grid + atlas, nie INTERACTIVE): warstwa Decals (DECAL, pod encjami) albo
##   Props (PROP, y-sort); kolizja z warstwy fizyki TileSetu;
## - canvas item (grid_jitter / free): RenderingServer pod węzłem Objects (y-sort razem z encjami),
##   grafika = region atlasu TileSetu; kolizja: kształty w jednym statycznym body PhysicsServer2D
##   na fragment CHUNK×CHUNK kratek;
## - wypieczona scena (DECAL/PROP z "scene", statyczna — ObjectBake): canvas item ze sprite'ami sceny
##   (PROP pod Objects z y-sortem, DECAL pod DecalItems z -1) + jej kształty w body fragmentu;
##   scena niestatyczna (skrypt, animacja…) -> instancja;
## - scena (INTERACTIVE): instancja w Objects (alias ze `scenes` albo ścieżka res://).
## RID-y trzyma węzeł ObjectRuntime poziomu (zwalniane przy regeneracji i usunięciu poziomu).

const SOURCE_ID := 0
const CHUNK := 32
const RUNTIME_NAME := "ObjectRuntime"
const DECALS := "Decals"
const PROPS := "Props"
const DECAL_ITEMS := "DecalItems"
const GROUP := &"generated_objects"


## Czyści poprzednie obiekty i stawia nowe. `plan` == null -> tylko czyszczenie.
## per_frame > 0: co tyle obiektów czeka klatkę (wołać z await); 0 = od razu.
static func realize(level: Node2D, plan: ObjectPlan, tileset: TileSet, scenes: Dictionary = {}, per_frame: int = 0) -> ObjectRuntime:
	var runtime := level.get_node_or_null(RUNTIME_NAME) as ObjectRuntime
	if runtime == null:
		runtime = ObjectRuntime.new()
		runtime.name = RUNTIME_NAME
		level.add_child(runtime)
	runtime.clear()
	for layer_name in [DECALS, PROPS]:
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
	var layer_bits := 1
	if tileset != null and tileset.get_physics_layers_count() > 0:
		layer_bits = tileset.get_physics_layer_collision_layer(0)
	var space := level.get_world_2d().space if level.is_inside_tree() else RID()
	var chunk_bodies := {}
	var scene_cache := {}
	var made := 0
	for pl in plan.placements:
		var def := pl.def
		if def.klass == ObjectDef.Klass.INTERACTIVE:
			_place_scene(objects, pl, def.scene, scenes, scene_cache, runtime)
		elif not def.bakes.is_empty():
			var b := def.bakes[pl.variant]
			if b.static_ok:
				_place_baked(decal_items if def.klass == ObjectDef.Klass.DECAL else objects, b, pl, runtime)
				if b.has_collision() and def.is_solid():
					_add_baked_shapes(runtime, chunk_bodies, space, b.collision_layer if b.collision_layer != 0 else layer_bits, b, pl)
			else:
				_place_scene(objects, pl, b.path, scenes, scene_cache, runtime)
		elif def.renders_as_tile():
			_place_tile(level, tileset, pl, runtime)
		elif source != null:
			_place_item(objects, source, pl, runtime)
			if def.is_solid():
				_add_shape(runtime, chunk_bodies, space, layer_bits, pl)
		made += 1
		if per_frame > 0 and made % per_frame == 0:
			await level.get_tree().process_frame
	return runtime


static func _objects_node(level: Node2D) -> Node2D:
	var objects := level.get_node_or_null("Objects") as Node2D
	if objects == null:
		objects = Node2D.new()
		objects.name = "Objects"
		objects.y_sort_enabled = true
		level.add_child(objects)
	return objects


## Wypieczone DECAL-e: płasko pod encjami (bez y-sortu), nad podłogą.
static func _decal_items_node(level: Node2D) -> Node2D:
	var n := level.get_node_or_null(DECAL_ITEMS) as Node2D
	if n == null:
		n = Node2D.new()
		n.name = DECAL_ITEMS
		n.z_index = -1
		level.add_child(n)
	return n


static func _layer(level: Node2D, tileset: TileSet, layer_name: String) -> TileMapLayer:
	var layer := level.get_node_or_null(layer_name) as TileMapLayer
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = layer_name
		level.add_child(layer)
	layer.tile_set = tileset
	if layer_name == DECALS:
		layer.z_index = -1   # nad FloorDecor (później w drzewie), pod encjami
	else:
		layer.z_index = 0
		layer.y_sort_enabled = true
	return layer


static func _place_tile(level: Node2D, tileset: TileSet, pl: ObjectPlacement, runtime: ObjectRuntime) -> void:
	var def := pl.def
	var layer := _layer(level, tileset, DECALS if def.klass == ObjectDef.Klass.DECAL else PROPS)
	var alt := TileSetAtlasSource.TRANSFORM_FLIP_H if pl.flip else 0
	layer.set_cell(pl.cell, SOURCE_ID, def.atlas[pl.variant], alt)
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
static func _place_baked(parent: Node2D, b: ObjectBake, pl: ObjectPlacement, runtime: ObjectRuntime) -> void:
	var item := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, parent.get_canvas_item())
	RenderingServer.canvas_item_set_transform(item, _origin_xform(pl))
	for sp in b.sprites:
		RenderingServer.canvas_item_add_set_transform(item, sp["xform"])
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
	if pl.flip:
		inst.scale.x = -1.0
	inst.add_to_group(GROUP)
	objects.add_child(inst)
	runtime.counts["scenes"] += 1
