class_name ObjectCatalog
extends RefCounted

## Katalog obiektów z JSON-a: "groups" (domyślne wartości dla wielu obiektów) + "objects" (każdy
## wskazuje grupę i może nadpisać dowolne pole). Po scaleniu i walidacji -> ObjectDef posortowane
## w kolejności rozmieszczania (priorytet malejąco, potem kolejność w pliku).
##
## {
##   "groups":  { "rubble": { "class": "DECAL", "placement": "grid_jitter", "density": 3 } },
##   "objects": [ { "id": "pebbles", "group": "rubble", "scene": ["res://…/pebble_a.tscn", "res://…/pebble_b.tscn"] } ]
## }
##
## Grafika: "scene" (scena albo lista scen = warianty; statyczne są wypiekane — ObjectBake) albo
## "atlas" (+ "variants") z TileSetu poziomu.

const KEYS := [
	"id", "group", "class", "placement", "jitter", "spacing", "spacing_px", "density", "count",
	"atlas", "variants", "size", "footprint", "scene", "collision", "shape", "context", "avoid",
	"levels", "cluster", "keep_paths", "priority", "flip_h",
]
## Tagi kontekstu rozpoznawane przez ObjectFeatures.
const CONTEXT_TAGS := [
	"wall_n", "wall_s", "wall_e", "wall_w", "wall_any", "corner", "open", "center",
	"room", "corridor", "dead_end", "niche", "plateau_edge",
]
const LEVELS := ["ground", "plateau", "pit"]
const CLASSES := {"DECAL": ObjectDef.Klass.DECAL, "PROP": ObjectDef.Klass.PROP, "INTERACTIVE": ObjectDef.Klass.INTERACTIVE}
const PLACEMENTS := {"grid": ObjectDef.Placement.GRID, "grid_jitter": ObjectDef.Placement.GRID_JITTER, "free": ObjectDef.Placement.FREE}
const COLLISIONS := {"none": ObjectDef.Collision.NONE, "tile": ObjectDef.Collision.TILE, "shape": ObjectDef.Collision.SHAPE, "scene": ObjectDef.Collision.SCENE}

var path: String = ""
var defs: Array[ObjectDef] = []
var errors: Array[String] = []

static var _cache := {}
static var _cache_mutex := Mutex.new()


## Katalog z pliku (cache po ścieżce — generowanie w wątku roboczym woła to przy każdej mapie).
## Pusta ścieżka albo brak pliku -> pusty katalog z błędem.
static func load_path(json_path: String) -> ObjectCatalog:
	_cache_mutex.lock()
	var cached: ObjectCatalog = _cache.get(json_path)
	_cache_mutex.unlock()
	if cached != null:
		return cached
	var cat := ObjectCatalog.new()
	cat.path = json_path
	if json_path.is_empty() or not FileAccess.file_exists(json_path):
		cat.errors.append("Brak katalogu obiektów '%s'." % json_path)
	else:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			cat._parse(parsed)
		else:
			cat.errors.append("Niepoprawny JSON katalogu obiektów '%s'." % json_path)
	for e in cat.errors:
		push_warning("ObjectCatalog: " + e)
	_cache_mutex.lock()
	_cache[json_path] = cat
	_cache_mutex.unlock()
	return cat


## Katalog z gotowego słownika (testy).
static func from_dict(d: Dictionary) -> ObjectCatalog:
	var cat := ObjectCatalog.new()
	cat._parse(d)
	return cat


static func clear_cache() -> void:
	_cache_mutex.lock()
	_cache.clear()
	_cache_mutex.unlock()


func get_def(def_id: StringName) -> ObjectDef:
	for d in defs:
		if d.id == def_id:
			return d
	return null


func _parse(d: Dictionary) -> void:
	var groups: Dictionary = d.get("groups", {}) if d.get("groups", {}) is Dictionary else {}
	for g in groups:
		if not (groups[g] is Dictionary):
			errors.append("Grupa '%s' nie jest obiektem JSON." % g)
			continue
		for k in groups[g]:
			if not k in KEYS or k in ["id", "group"]:
				errors.append("Grupa '%s': nieznane pole '%s'." % [g, k])
	var objects = d.get("objects", [])
	if not (objects is Array):
		errors.append("'objects' musi być listą.")
		return
	var seen := {}
	var i := 0
	for o in objects:
		i += 1
		if not (o is Dictionary):
			errors.append("Obiekt #%d nie jest obiektem JSON." % i)
			continue
		var merged := {}
		var gname := String(o.get("group", ""))
		if not gname.is_empty():
			if not groups.has(gname):
				errors.append("Obiekt '%s': nieznana grupa '%s'." % [o.get("id", "#%d" % i), gname])
			elif groups[gname] is Dictionary:
				merged = (groups[gname] as Dictionary).duplicate(true)
		for k in o:
			merged[k] = o[k]
		var def := _build(merged, i)
		if def == null:
			continue
		if seen.has(def.id):
			errors.append("Obiekt '%s': powtórzone id." % def.id)
			continue
		seen[def.id] = true
		defs.append(def)
	defs.sort_custom(func(a: ObjectDef, b: ObjectDef) -> bool:
		return a.priority > b.priority or (a.priority == b.priority and a.order < b.order))


func _build(m: Dictionary, order: int) -> ObjectDef:
	var def := ObjectDef.new()
	def.order = order
	def.id = StringName(String(m.get("id", "")))
	var tag := "Obiekt '%s'" % def.id
	if def.id == &"":
		errors.append("Obiekt #%d: brak id." % order)
		return null
	for k in m:
		if not k in KEYS:
			errors.append("%s: nieznane pole '%s'." % [tag, k])
	def.group = StringName(String(m.get("group", "")))

	var klass_s := String(m.get("class", ""))
	if not CLASSES.has(klass_s):
		errors.append("%s: class musi być jednym z %s." % [tag, CLASSES.keys()])
		return null
	def.klass = CLASSES[klass_s]
	var placement_s := String(m.get("placement", "grid"))
	if not PLACEMENTS.has(placement_s):
		errors.append("%s: placement musi być jednym z %s." % [tag, PLACEMENTS.keys()])
		return null
	def.placement = PLACEMENTS[placement_s]
	def.jitter_px = float(m.get("jitter", def.jitter_px))
	def.spacing = maxi(int(m.get("spacing", def.spacing)), 1)
	def.spacing_px = maxf(float(m.get("spacing_px", def.spacing_px)), 1.0)
	def.density = maxf(float(m.get("density", 0.0)), 0.0)
	if m.has("count"):
		var c = m["count"]
		if c is Array and c.size() == 2:
			def.count_min = int(c[0])
			def.count_max = maxi(int(c[1]), int(c[0]))
		elif c is float or c is int:
			def.count_min = int(c)
			def.count_max = int(c)
		else:
			errors.append("%s: count to liczba albo [min, max]." % tag)

	def.size = _vec(m.get("size", [1, 1]), Vector2i.ONE, tag, "size")
	def.size = Vector2i(maxi(def.size.x, 1), maxi(def.size.y, 1))
	if m.has("atlas"):
		var base := _vec(m["atlas"], Vector2i(-1, -1), tag, "atlas")
		var variants = m.get("variants", 1)
		if variants is Array:
			for v in variants:
				def.atlas.append(_vec(v, base, tag, "variants"))
		else:
			for vi in range(maxi(int(variants), 1)):
				def.atlas.append(base + Vector2i(vi * def.size.x, 0))
	if m.has("footprint"):
		for f in m["footprint"]:
			var fv := _vec(f, Vector2i.ZERO, tag, "footprint")
			if fv.y > 0 or fv.x < 0 or fv.x >= def.size.x or -fv.y >= def.size.y:
				errors.append("%s: footprint %s poza sprite'em %s (kotwica = lewy-dolny róg, y <= 0)." % [tag, fv, def.size])
			else:
				def.footprint.append(fv)
	if def.footprint.is_empty():
		for x in range(def.size.x):
			def.footprint.append(Vector2i(x, 0))
	var sc = m.get("scene", "")
	if sc is Array:
		for x in sc:
			def.scenes.append(String(x))
	elif not String(sc).is_empty():
		def.scenes.append(String(sc))
	def.scene = def.scenes[0] if not def.scenes.is_empty() else ""
	if def.klass != ObjectDef.Klass.INTERACTIVE:
		for sp in def.scenes:
			var b := ObjectBake.bake(sp)
			if not b.error.is_empty():
				errors.append("%s: %s." % [tag, b.error])
				return null
			def.bakes.append(b)

	var default_collision := "none"
	if def.klass == ObjectDef.Klass.PROP:
		default_collision = "shape"
	elif def.klass == ObjectDef.Klass.INTERACTIVE:
		default_collision = "scene"
	if not def.bakes.is_empty():
		# Sceny: kolizja z węzłów sceny (StaticBody2D), chyba że JSON mówi inaczej.
		default_collision = "none"
		for b in def.bakes:
			if b.has_collision() or not b.static_ok:
				default_collision = "shape"
	var coll_s := String(m.get("collision", default_collision))
	if not COLLISIONS.has(coll_s):
		errors.append("%s: collision musi być jednym z %s." % [tag, COLLISIONS.keys()])
		coll_s = default_collision
	def.collision = COLLISIONS[coll_s]
	if def.collision == ObjectDef.Collision.TILE and def.placement != ObjectDef.Placement.GRID:
		errors.append("%s: collision 'tile' tylko przy placement 'grid' (kafel)." % tag)
		def.collision = ObjectDef.Collision.SHAPE
	if def.collision == ObjectDef.Collision.SCENE and def.klass != ObjectDef.Klass.INTERACTIVE:
		errors.append("%s: collision 'scene' tylko dla INTERACTIVE." % tag)
		def.collision = ObjectDef.Collision.SHAPE
	var fsize := def.footprint_size()
	def.shape_rect = Vector2(fsize.x * ObjectDef.CELL - 4, 8)
	def.shape_offset = Vector2(0, -4)
	# Sceny: kształt dla planera (zajętość kratek) = obrys kolizji wszystkich wariantów.
	# Origin sceny leży pół kratki nad punktem obiektu (ObjectPlacement.origin).
	var sb := Rect2()
	var has_sb := false
	for b in def.bakes:
		if b.has_collision():
			sb = b.bounds if not has_sb else sb.merge(b.bounds)
			has_sb = true
	if has_sb:
		def.shape_rect = sb.size
		def.shape_offset = sb.get_center() - Vector2(0, ObjectDef.CELL * 0.5)
	if m.has("shape"):
		var sh = m["shape"]
		if sh is Dictionary:
			if sh.has("rect"):
				def.shape_rect = Vector2(_vec(sh["rect"], Vector2i(16, 8), tag, "shape.rect"))
			elif sh.has("circle"):
				def.shape_rect = Vector2.ZERO
				def.shape_radius = float(sh["circle"])
			def.shape_offset = Vector2(_vec(sh.get("offset", [0, 0]), Vector2i.ZERO, tag, "shape.offset"))
		else:
			errors.append("%s: shape to {\"rect\": [w, h]} albo {\"circle\": r} (+ \"offset\")." % tag)

	for t in m.get("context", []):
		if String(t) in CONTEXT_TAGS:
			def.context.append(StringName(String(t)))
		else:
			errors.append("%s: nieznany tag kontekstu '%s' (znane: %s)." % [tag, t, CONTEXT_TAGS])
	for t in m.get("avoid", []):
		if String(t) in CONTEXT_TAGS:
			def.avoid.append(StringName(String(t)))
		else:
			errors.append("%s: nieznany tag w avoid '%s'." % [tag, t])
	for lv in m.get("levels", []):
		if String(lv) in LEVELS:
			def.levels.append(StringName(String(lv)))
		else:
			errors.append("%s: nieznany poziom '%s' (znane: %s)." % [tag, lv, LEVELS])
	if m.has("cluster"):
		var cl = m["cluster"]
		if cl is Dictionary:
			var sz := _vec(cl.get("size", [2, 4]), Vector2i(2, 4), tag, "cluster.size")
			def.cluster_min = maxi(sz.x, 1)
			def.cluster_max = maxi(sz.y, def.cluster_min)
			def.cluster_radius = maxi(int(cl.get("radius", 2)), 1)
		else:
			errors.append("%s: cluster to {\"size\": [a, b], \"radius\": r}." % tag)
	def.keep_paths = bool(m.get("keep_paths", true))
	def.flip_h = bool(m.get("flip_h", false))

	var default_priority := 100
	match def.klass:
		ObjectDef.Klass.INTERACTIVE:
			default_priority = 300
		ObjectDef.Klass.PROP:
			default_priority = 400 if def.footprint.size() > 1 else 200
	def.priority = int(m.get("priority", default_priority))

	if def.klass == ObjectDef.Klass.INTERACTIVE:
		if def.scene.is_empty():
			errors.append("%s: INTERACTIVE wymaga 'scene' (ścieżka res:// albo alias)." % tag)
			return null
	elif def.atlas.is_empty() and def.scenes.is_empty():
		errors.append("%s: brak grafiki — 'scene' (scena .tscn) albo 'atlas' (kafel TileSetu poziomu)." % tag)
		return null
	return def


func _vec(v, fallback: Vector2i, tag: String, field: String) -> Vector2i:
	if v is Array and v.size() == 2:
		return Vector2i(int(v[0]), int(v[1]))
	errors.append("%s: '%s' musi być [x, y]." % [tag, field])
	return fallback
