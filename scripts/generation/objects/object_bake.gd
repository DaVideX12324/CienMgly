@tool
class_name ObjectBake
extends RefCounted

## Scena obiektu „wypieczona” do danych: sprite'y (tekstura + region + prostokąt względem origin)
## i kształty kolizji (zasoby Shape2D + transformacje). ObjectRealizer rysuje je przez
## RenderingServer i dodaje do wspólnego body PhysicsServer2D — bez węzła na obiekt.
##
## Wypiec się da tylko scenę statyczną: bez skryptów, z węzłów z BAKEABLE (kolizje tylko pod
## StaticBody2D). Inna scena (skrypt, animacja, Area2D, światło…) -> static_ok = false i realizer
## tworzy jej instancję.
##
## Origin sceny = punkt y-sortu = środek kratki kotwicy (dolnego wiersza podstawy).
## Konwencja (decyzja usera): obiekt z kolizją ma StaticBody2D jako KORZEŃ sceny (bez Node2D nad nim);
## zagnieżdżone body działa, ale ustawia nested_body (narzędzie / wtyczka katalogu to zgłaszają).

const META_PREFIX := "object_"
const BAKEABLE := ["Node2D", "Sprite2D", "StaticBody2D", "CollisionShape2D", "CollisionPolygon2D"]

var path := ""
var error := ""
var static_ok := false
var reason := ""                    # dlaczego nie da się wypiec (węzeł/skrypt)
var sprites: Array[Dictionary] = []  # {tex: Texture2D, src: Rect2, dst: Rect2, xform: Transform2D, color: Color}
var shapes: Array[Dictionary] = []   # {shape: Shape2D, xform: Transform2D}
var collision_layer := 0
var bounds := Rect2()               # obrys kształtów kolizji względem origin (pusty = brak kolizji)
var nested_body := false            # StaticBody2D nie jest korzeniem (niezgodne z konwencją)
var meta := {}                      # metadane korzenia "object_<pole>" -> pole katalogu (bez prefiksu)

# @tool: narzędzie edytora (sync_object_catalogs) woła to w edytorze, a tam static var skryptów bez
# @tool nie są inicjalizowane. Mutex i tak tworzony leniwie (_lock) — na wypadek starego stanu edytora.
static var _cache: Dictionary = {}
static var _mutex: Mutex = null


static func _lock() -> void:
	if _mutex == null:
		_mutex = Mutex.new()
	_mutex.lock()


static func bake(scene_path: String) -> ObjectBake:
	_lock()
	var cached: ObjectBake = _cache.get(scene_path)
	_mutex.unlock()
	if cached != null:
		return cached
	var b := ObjectBake.new()
	b.path = scene_path
	b._bake()
	_lock()
	_cache[scene_path] = b
	_mutex.unlock()
	return b


## Zapomina wypiek jednej sceny (zapisana w edytorze -> następny bake czyta ją od nowa).
static func forget(scene_path: String) -> void:
	_lock()
	_cache.erase(scene_path)
	_mutex.unlock()


static func clear_cache() -> void:
	_lock()
	_cache.clear()
	_mutex.unlock()


func has_collision() -> bool:
	return not shapes.is_empty()


func _bake() -> void:
	if not ResourceLoader.exists(path):
		error = "brak sceny '%s'" % path
		return
	var packed := load(path) as PackedScene
	if packed == null:
		error = "'%s' nie jest sceną" % path
		return
	var root := packed.instantiate()
	# Metadane korzenia (Inspector -> Add Metadata): object_group, object_terrain… -> pola katalogu.
	for k in root.get_meta_list():
		if String(k).begins_with(META_PREFIX):
			meta[String(k).substr(META_PREFIX.length())] = root.get_meta(k)
	static_ok = true
	_walk(root, Transform2D.IDENTITY, false)
	root.free()
	if not static_ok:
		sprites.clear()
		shapes.clear()
		bounds = Rect2()


func _walk(node: Node, parent_xf: Transform2D, in_static: bool) -> void:
	if node.get_script() != null:
		_not_static("skrypt w '%s'" % node.name)
	if not node.get_class() in BAKEABLE:
		_not_static("węzeł %s '%s'" % [node.get_class(), node.name])
	var xf := parent_xf
	if node is Node2D:
		xf = parent_xf * (node as Node2D).transform
		if not (node as Node2D).visible:
			return
	if node is StaticBody2D:
		if node.get_parent() != null:
			nested_body = true
		in_static = true
		collision_layer |= (node as StaticBody2D).collision_layer
	elif node is Sprite2D:
		_add_sprite(node as Sprite2D, xf)
	elif node is CollisionShape2D:
		var cs := node as CollisionShape2D
		if in_static and not cs.disabled and cs.shape != null:
			_add_shape(cs.shape, xf)
	elif node is CollisionPolygon2D:
		var cp := node as CollisionPolygon2D
		if in_static and not cp.disabled and cp.polygon.size() >= 3:
			if cp.build_mode == CollisionPolygon2D.BUILD_SOLIDS:
				for part in Geometry2D.decompose_polygon_in_convex(cp.polygon):
					var cv := ConvexPolygonShape2D.new()
					cv.points = part
					_add_shape(cv, xf)
			else:
				var seg := PackedVector2Array()
				for i in range(cp.polygon.size()):
					seg.append(cp.polygon[i])
					seg.append(cp.polygon[(i + 1) % cp.polygon.size()])
				var cc := ConcavePolygonShape2D.new()
				cc.segments = seg
				_add_shape(cc, xf)
	for child in node.get_children():
		_walk(child, xf, in_static)


func _not_static(why: String) -> void:
	if static_ok:
		reason = why
	static_ok = false


func _add_sprite(s: Sprite2D, xf: Transform2D) -> void:
	var tex := s.texture
	if tex == null:
		return
	var src := Rect2(Vector2.ZERO, tex.get_size())
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		if at.atlas == null:
			return
		src = at.region
		tex = at.atlas
	if s.region_enabled:
		src = Rect2(src.position + s.region_rect.position, s.region_rect.size)
	var frame_size := src.size / Vector2(s.hframes, s.vframes)
	src = Rect2(src.position + Vector2(s.frame % s.hframes, s.frame / s.hframes) * frame_size, frame_size)
	var dst := Rect2(s.offset - (frame_size * 0.5 if s.centered else Vector2.ZERO), frame_size)
	if s.flip_h:
		dst.size.x = -dst.size.x
	if s.flip_v:
		dst.size.y = -dst.size.y
	sprites.append({"tex": tex, "src": src, "dst": dst, "xform": xf, "color": s.modulate * s.self_modulate})


func _add_shape(shape: Shape2D, xf: Transform2D) -> void:
	shapes.append({"shape": shape, "xform": xf})
	var r := xf * shape.get_rect()
	bounds = r if shapes.size() == 1 else bounds.merge(r)
