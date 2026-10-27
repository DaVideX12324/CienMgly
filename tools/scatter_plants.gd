extends SceneTree

## Rozsypuje rośliny (scenes/objects/pixel_crawler/plants) po scenie mapy i zapisuje je jako osobną scenę do wstawienia na warstwę obiektów.
## Użycie: godot --headless --path . --script modules/quiz_rpg/tools/scatter_plants.gd -- <mapa.tscn> <wyjście.tscn> [seed]
## Rośliny trafiają na komórki warstwy „Grass” bez drogi, skał, płotu i wysokiej trawy, z dala od kolizji i punktów startu.
## Kępki traw i kwiatów są skupione w kilku miejscach, pojedyncze sadzonki leżą rzadziej po całej trawie.

const PLANTS_DIR := "res://modules/quiz_rpg/scenes/objects/pixel_crawler/plants/"
const SOLID_LAYERS := ["Road", "RockSlopes", "Fence", "Tall Grass2", "NuhUh"]
const CLEARANCE := 6.0
const SINGLE_CHANCE := 0.04
const PATCHES := 90


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("scatter_plants: potrzebne <mapa.tscn> <wyjście.tscn>")
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[2]) if args.size() > 2 else 1
	var map: Node = (load(args[0]) as PackedScene).instantiate()
	var grass := map.get_node("Grass") as TileMapLayer
	var blocked := {}
	for n in SOLID_LAYERS:
		var l := map.get_node_or_null(n) as TileMapLayer
		if l:
			for c in l.get_used_cells():
				blocked[c] = true
	var rects: Array[Rect2] = []
	_collect_blockers(map, Transform2D.IDENTITY, rects)
	for m in map.get_node("Spawns").get_children():
		rects.append(Rect2((m as Node2D).position - Vector2(24, 24), Vector2(48, 48)))
	var ts := grass.tile_set.tile_size
	var cells: Array[Vector2i] = []
	for c in grass.get_used_cells():
		if not blocked.has(c) and not _hits(rects, grass.map_to_local(c), ts):
			cells.append(c)
	print("komórek trawy wolnych: ", cells.size())
	var scenes := _load_plants()
	var root := Node2D.new()
	root.name = "Plants"
	root.y_sort_enabled = true
	var taken := {}
	var place := func(group: String, cell: Vector2i) -> void:
		if taken.has(cell) or not scenes.has(group):
			return
		taken[cell] = true
		var list: Array = scenes[group]
		var inst := (list[rng.randi() % list.size()] as PackedScene).instantiate() as Node2D
		inst.position = grass.map_to_local(cell) + Vector2(rng.randi_range(-5, 5), rng.randi_range(-4, 6))
		inst.name = "%s_%d" % [group, root.get_child_count()]
		root.add_child(inst)
		inst.owner = root
	for c in cells:
		if rng.randf() < SINGLE_CHANCE:
			place.call("grass", c)
	for i in PATCHES:
		var centre: Vector2i = cells[rng.randi() % cells.size()]
		var group: String = ["flowers", "flowers", "flowers", "grass", "grass", "mushrooms"][rng.randi() % 6]
		for j in rng.randi_range(3, 8):
			var c := centre + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if not blocked.has(c) and cells.has(c):
				place.call(group, c)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, args[1])
	print("zapisano ", root.get_child_count(), " roślin do ", args[1], " (", error_string(err), ")")
	quit(0 if err == OK else 1)


func _load_plants() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(PLANTS_DIR):
		if not f.ends_with(".tscn"):
			continue
		var group := "grass"
		if f.begins_with("flower") or f.begins_with("flowers"):
			group = "flowers"
		elif f.begins_with("reeds"):
			group = "reeds"
		elif f.begins_with("mushroom"):
			group = "mushrooms"
		if not out.has(group):
			out[group] = []
		out[group].append(load(PLANTS_DIR + f))
	return out


func _collect_blockers(n: Node, t: Transform2D, out: Array[Rect2]) -> void:
	for ch in n.get_children():
		if ch is CanvasItem and not (ch as CanvasItem).visible:
			continue
		var ct := t
		if ch is Node2D:
			ct = t * (ch as Node2D).transform
		if ch is CollisionShape2D and (ch as CollisionShape2D).shape is RectangleShape2D:
			var sz: Vector2 = ((ch as CollisionShape2D).shape as RectangleShape2D).size
			out.append(ct * Rect2(-sz / 2.0, sz))
		elif ch is CollisionPolygon2D:
			var pts := (ch as CollisionPolygon2D).polygon
			if pts.size() > 0:
				var r := Rect2(ct * pts[0], Vector2.ZERO)
				for p in pts:
					r = r.expand(ct * p)
				out.append(r)
		_collect_blockers(ch, ct, out)


func _hits(rects: Array[Rect2], pos: Vector2, ts: Vector2i) -> bool:
	var probe := Rect2(pos - Vector2(ts) / 2.0, Vector2(ts)).grow(CLEARANCE)
	for r in rects:
		if r.intersects(probe):
			return true
	return false
