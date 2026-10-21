extends RefCounted

## Zapis gotowych map na dysk: wczytanie zapisu i powrót na mapę (także po restarcie gry) bez generowania.
## Plan: docs/plan_zapis_map.md. Plik `user://maps/<seed zapisu>/<mapa>.map` = zstd(var_to_bytes) słownika:
##   v — MAP_CACHE_VERSION, sig — podpis zgodności (poziom, seed, rozmiar, pliki konfiguracji, tileset, skrypty
##   generatora w buildzie debug), tiles — {warstwa: tile_map_data} zaraz po malowaniu kafli (przed encjami
##   i obiektami), r — lekki wynik generatora z polami, których poziom używa po generowaniu.
## Niezgodny podpis albo uszkodzony plik = brak trafienia (mapa generowana od nowa i zapisana ponownie).

const MapGeneratorBaseScript = preload("../generation/map_generator_base.gd")
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

## Podbijać przy zmianach generatora / kafli, które zmieniają wynik mapy (w buildzie debug dodatkowo działa data
## modyfikacji skryptów generatora).
const MAP_CACHE_VERSION := 1
const MAGIC := 0x4D415031  # "MAP1"
const ROOT := "user://maps"
const KEEP_SEEDS := 6
const GENERATOR_DIR := "scripts/generation"

static var _script_stamp := ""   # data modyfikacji skryptów generatora (raz na sesję, tylko build debug)
static var _tasks: Array[int] = []
static var _swept := false


static func enabled() -> bool:
	return not OS.has_feature("no_map_cache") and ProjectSettings.get_setting("quiz_rpg/map_disk_cache", true)


static func path_for(world_seed: int, level_key: String) -> String:
	var name := QuizRpgPaths.level_name(level_key)
	return "%s/%d/%s.map" % [ROOT, world_seed, name]


## Podpis zgodności zapisu. `files`: pliki, których zmiana unieważnia mapę (companion-JSON, katalog obiektów,
## tileset) — liczy się data modyfikacji i rozmiar.
static func signature(key: String, files: Array) -> String:
	var parts: PackedStringArray = [str(MAP_CACHE_VERSION), key]
	for f in files:
		var p := str(f)
		if p.is_empty():
			continue
		parts.append("%s:%d:%d" % [p.get_file(), FileAccess.get_modified_time(p), _file_size(p)])
	parts.append(_generator_stamp())
	return "|".join(parts)


static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f != null else -1


static func _generator_stamp() -> String:
	if not OS.is_debug_build():
		return ""
	if _script_stamp.is_empty():
		_script_stamp = str(_newest_script(QuizRpgPaths.path(GENERATOR_DIR)))
	return _script_stamp


static func _newest_script(dir: String) -> int:
	var newest := 0
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			newest = maxi(newest, FileAccess.get_modified_time(dir.path_join(f)))
	for d in DirAccess.get_directories_at(dir):
		newest = maxi(newest, _newest_script(dir.path_join(d)))
	return newest


# --- Migawka (główny wątek: tylko kopie referencji / proste pętle; zapis w wątku roboczym) ---

## Warstwy kafli, które maluje generator (reszta — Decals / Props / … — powstaje z planu obiektów po wczytaniu).
const PAINT_LAYERS := [&"Floor", &"FloorDecor", &"Curbs", &"Bridges", &"Walls", &"Rails", &"Platforms", &"PortalShade"]


static func snapshot(layers: Dictionary, result, sig: String) -> Dictionary:
	var tiles := {}
	for name in PAINT_LAYERS:
		var layer := layers.get(name) as TileMapLayer
		if layer != null:
			tiles[String(name)] = layer.tile_map_data
	return {"v": MAP_CACHE_VERSION, "sig": sig, "tiles": tiles, "r": _pack_result(result)}


static func _pack_result(r) -> Dictionary:
	var grid := PackedByteArray()
	grid.resize(r.width * r.height)
	grid.fill(255)
	for p: Vector2i in r.grid:
		grid[p.y * r.width + p.x] = int(r.grid[p])
	var nav: Array = []
	for np: NavigationPolygon in r.nav_polygons:
		var polys: Array = []
		for i in np.get_polygon_count():
			polys.append(np.get_polygon(i))
		nav.append([np.vertices, polys, np.agent_radius, np.baking_rect, np.border_size])
	var out := {
		"width": r.width, "height": r.height, "seed_used": r.seed_used, "player_spawn": r.player_spawn,
		"rooms": Array(r.rooms), "enemy_spawns": Array(r.enemy_spawns), "chest_spawns": Array(r.chest_spawns),
		"doors": Array(r.doors), "entrance_pos": r.entrance_pos, "exit_pos": r.exit_pos,
		"entrance_edge": r.entrance_edge, "exit_edge": r.exit_edge,
		"portal_stairs": Array(r.portal_stairs), "portal_ladders": Array(r.portal_ladders), "portal_scene": r.portal_scene,
		"portal_void": Array(r.portal_void), "nav_excluded": r.nav_excluded, "nav_chunk_keys": Array(r.nav_chunk_keys),
		"grid": grid, "nav": nav,
	}
	var c = r.canals
	if c != null:
		out["canals"] = {"cells": c.cells, "blocked": c.blocked, "crossings": Array(c.crossings),
			"crossing_cells": c.crossing_cells, "rail_cells": c.rail_cells, "stair_corridors": c.stair_corridors,
			"stair_cells": c.stair_cells}
	var pl = r.plateau
	if pl != null:
		out["plateau"] = {"mask": pl.mask, "blocked": pl.blocked, "min_level": pl.min_level}
	var o = r.objects
	if o != null:
		var placements: Array = []
		for p in o.placements:
			placements.append([_pack_def(p.def), p.cell, p.offset, p.variant, p.flip, p.cells, p.link, p.on_top])
		out["objects"] = {"width": o.width, "height": o.height, "placements": placements, "occupancy": o.occupancy,
			"stats": o.stats, "removed_for_reach": o.removed_for_reach, "time_usec": o.time_usec,
			"interactive_scenes": o.interactive_scenes}
	return out


## Definicja obiektu: id (z katalogu) albo, dla syntetycznych (bramy, zamki, płyty), pola potrzebne po generowaniu.
static func _pack_def(def) -> Array:
	return [String(def.id), int(def.klass), def.scene, String(def.mount), Array(def.footprint)]


# --- Zapis i odczyt pliku ---

## Migawka jako bajty — na głównym wątku, póki wynik generatora nie jest już zmieniany przez grę (kompresja i zapis
## idą do wątku roboczego, który nie czyta żywych słowników).
static func encode(snap: Dictionary) -> PackedByteArray:
	return var_to_bytes(snap)


## Zapisuje bajty (z encode) w wątku roboczym: `*.tmp` + rename (przerwany zapis nie psuje pliku).
static func save_async(path: String, bytes: PackedByteArray) -> void:
	var task := WorkerThreadPool.add_task(_save.bind(path, bytes), false, "Zapis mapy")
	_tasks.append(task)


static func _save(path: String, bytes: PackedByteArray) -> void:
	var packed := bytes.compress(FileAccess.COMPRESSION_ZSTD)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_32(MAGIC)
	f.store_32(bytes.size())
	f.store_buffer(_md5(bytes))
	f.store_buffer(packed)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)


static func _md5(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish()


## Czeka na zapisy w toku (wyjście z gry, testy).
static func flush() -> void:
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


## Migawka z pliku albo {} (brak pliku, uszkodzony, inny podpis).
static func read(path: String, sig: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 24 or f.get_32() != MAGIC:
		return {}
	var size := f.get_32()
	var sum := f.get_buffer(16)
	var packed := f.get_buffer(f.get_length() - 24)
	f.close()
	if size <= 0 or size > 512 * 1024 * 1024:
		return {}
	var bytes := packed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	if bytes.size() != size or _md5(bytes) != sum:
		return {}
	var snap = bytes_to_var(bytes)
	if not (snap is Dictionary) or int(snap.get("v", -1)) != MAP_CACHE_VERSION or str(snap.get("sig", "")) != sig:
		return {}
	if not (snap.get("tiles") is Dictionary) or not (snap.get("r") is Dictionary):
		return {}
	return snap


## Usuwa najstarsze foldery seedów (zostaje KEEP_SEEDS ostatnio zmienianych). Raz na sesję gry.
static func sweep_once() -> void:
	if _swept:
		return
	_swept = true
	sweep()


static func sweep() -> void:
	var dirs: Array = []
	for d in DirAccess.get_directories_at(ROOT):
		var p := ROOT.path_join(d)
		var newest := 0
		for f in DirAccess.get_files_at(p):
			newest = maxi(newest, FileAccess.get_modified_time(p.path_join(f)))
		dirs.append([newest, p])
	if dirs.size() <= KEEP_SEEDS:
		return
	dirs.sort_custom(func(a, b): return a[0] > b[0])
	for i in range(KEEP_SEEDS, dirs.size()):
		clear_dir(dirs[i][1])


## Usuwa mapy seeda zapisu `world_seed`, o ile nie używa go żaden slot zapisu ani bieżąca gra (usunięcie slotu,
## reroll świata). Seedy slotów z SaveManagera (used_world_seeds).
static func clear_seed_if_unused(world_seed: int, keep_current: bool = false) -> void:
	if world_seed <= 0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var core := tree.root.get_node_or_null("CoreManager") if tree != null else null
	var sm: Variant = core.call("get_singleton", "SaveManager") if core != null and core.has_method("get_singleton") else null
	if sm is Node and (sm as Node).has_method("used_world_seeds") and world_seed in (sm as Node).call("used_world_seeds"):
		return
	if keep_current:
		var lsm: Variant = core.call("get_singleton", "LevelStateManager") if core != null and core.has_method("get_singleton") else null
		if lsm is Node and int((lsm as Node).get("world_seed")) == world_seed:
			return
	var p := "%s/%d" % [ROOT, world_seed]
	if DirAccess.dir_exists_absolute(p):
		clear_dir(p)


static func clear_dir(p: String) -> void:
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)


# --- Odtwarzanie wyniku ---

## Lekki GenerationResult z migawki. `catalog`: ObjectCatalog poziomu (definicje obiektów po id) albo null.
static func restore_result(r: Dictionary, catalog):
	var res = MapGeneratorBaseScript.GenerationResult.new()
	res.width = r.width
	res.height = r.height
	res.seed_used = r.seed_used
	res.player_spawn = r.player_spawn
	res.rooms.assign(r.rooms)
	res.enemy_spawns.assign(r.enemy_spawns)
	res.chest_spawns.assign(r.chest_spawns)
	res.doors.assign(r.doors)
	res.entrance_pos = r.entrance_pos
	res.exit_pos = r.exit_pos
	res.entrance_edge = int(r.get("entrance_edge", -1))
	res.exit_edge = int(r.get("exit_edge", -1))
	res.portal_stairs.assign(r.portal_stairs)
	res.portal_ladders.assign(r.portal_ladders)
	res.portal_scene = r.portal_scene
	res.portal_void.assign(r.portal_void)
	res.nav_excluded = r.nav_excluded
	res.nav_chunk_keys.assign(r.nav_chunk_keys)
	var grid: PackedByteArray = r.grid
	var w: int = res.width
	var g := {}
	for i in range(grid.size()):
		var t := grid[i]
		if t != 255:
			g[Vector2i(i % w, i / w)] = int(t)
	res.grid = g
	for item in r.nav:
		var np := NavigationPolygon.new()
		np.vertices = item[0]
		for poly in item[1]:
			np.add_polygon(poly)
		np.agent_radius = item[2]
		np.baking_rect = item[3]
		np.border_size = item[4]
		res.nav_polygons.append(np)
	if r.has("canals"):
		var c := CanalLayout.new()
		var cd: Dictionary = r.canals
		c.cells = cd.cells
		c.water = c.cells
		c.blocked = cd.blocked
		c.crossings.assign(cd.crossings)
		c.bridges = c.crossings
		c.crossing_cells = cd.crossing_cells
		c.bridge_cells = c.crossing_cells
		c.rail_cells = cd.rail_cells
		c.stair_corridors = cd.stair_corridors
		c.stair_cells = cd.stair_cells
		res.canals = c
	if r.has("plateau"):
		var p := PlateauLayout.new()
		p.mask = r.plateau.mask
		p.blocked = r.plateau.blocked
		p.min_level = r.plateau.min_level
		res.plateau = p
	if r.has("objects"):
		res.objects = _restore_objects(r.objects, catalog)
	return res


static func _restore_objects(od: Dictionary, catalog) -> ObjectPlan:
	var plan := ObjectPlan.new()
	plan.width = od.width
	plan.height = od.height
	plan.occupancy = od.occupancy
	plan.stats = od.stats
	plan.removed_for_reach = od.removed_for_reach
	plan.time_usec = od.time_usec
	plan.interactive_scenes = od.interactive_scenes
	var defs := {}
	if catalog != null:
		for d in catalog.defs + catalog.wall_defs:
			defs[String(d.id)] = d
	var synthetic := {}
	for item in od.placements:
		var dp: Array = item[0]
		var did: String = dp[0]
		var def: ObjectDef = defs.get(did)
		if def == null:
			var key := "%s|%s|%s" % [did, dp[2], dp[3]]
			def = synthetic.get(key)
			if def == null:
				def = ObjectDef.new()
				def.id = StringName(did)
				def.klass = dp[1]
				def.scene = dp[2]
				def.mount = StringName(dp[3])
				def.footprint.assign(dp[4])
				synthetic[key] = def
		var pl := ObjectPlacement.new()
		pl.def = def
		pl.cell = item[1]
		pl.offset = item[2]
		pl.variant = item[3]
		pl.flip = item[4]
		pl.cells = item[5]
		pl.link = item[6]
		pl.on_top = item[7]
		plan.placements.append(pl)
	return plan


## Warstwy z migawki: tile_map_data na warstwach przygotowanych przez poziom (kolejność jak przy malowaniu).
static func apply_tiles(layers: Dictionary, tiles: Dictionary) -> void:
	for name in tiles:
		var layer := layers.get(StringName(name)) as TileMapLayer
		if layer != null:
			layer.tile_map_data = tiles[name]
