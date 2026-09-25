extends Node2D
class_name ProceduralLevel

## Scena poziomu generowanego proceduralnie dla modulu Quiz RPG.
## W pelni kompatybilna z LevelManager i systemem zapisu.

const MapGeneratorBaseScript = preload("res://modules/quiz_rpg/scripts/generation/map_generator_base.gd")
const OverworldForestGeneratorScript = preload("res://modules/quiz_rpg/scripts/generation/overworld_forest_generator.gd")
const DungeonGeneratorScript = preload("res://modules/quiz_rpg/scripts/generation/dungeon_generator.gd")
const CaveGeneratorScript = preload("res://modules/quiz_rpg/scripts/generation/cave_generator.gd")
const TileSetFieldScript = preload("res://modules/quiz_rpg/scripts/generation/core/tileset_field.gd")
const GenProgress = preload("res://modules/quiz_rpg/scripts/generation/core/gen_progress.gd")
const LoadingOverlayScript = preload("res://modules/quiz_rpg/scripts/ui/generation_loading_overlay.gd")

## Koniec generowania (także synchronicznego) — mapa, encje i nawigacja są gotowe.
signal generation_finished

## Kafli wstawianych na klatkę przy generowaniu w tle (reszta klatki zostaje na pasek ładowania).
const PAINT_CHUNK := 6000
## Encji (wrogów/skrzyń/drzwi) tworzonych na klatkę przy generowaniu w tle.
const ENTITY_CHUNK := 6

enum LevelType {
	FOREST_OVERWORLD,
	DUNGEON_CASTLE,
	CAVE_DUNGEON
}

@export var level_type: LevelType = LevelType.FOREST_OVERWORLD
@export var map_seed: int = 0
@export var map_width: int = 160
@export var map_height: int = 160
@export var custom_tileset: TileSet = null
@export var enemy_scenes: Array[PackedScene] = []
@export var chest_scene: PackedScene = null
@export var door_scene: PackedScene = null
@export var next_level_path: String = ""
@export var next_spawn_name: String = "Spawn"
@export var spawn_entities_enabled: bool = true
@export var setup_nav_enabled: bool = true
@export var cave_max_rooms: int = 0 # 0 = obliczane automatycznie na podstawie rozmiaru mapy

## Named TileSet System: ścieżka do companion-JSON zachowania (np. caves.json).
## Puste => dla jaskiń companion-JSON tilesetu (caves.tres -> config/caves.json); gdy go brak,
## generator działa jak dotychczas (placery używają stałych CaveTileConstants).
@export_file("*.json") var tile_behaviour_json_path: String = ""

## Generowanie w tle (wątek roboczy) z ekranem ładowania. false = jak dawniej: cała mapa w _ready
## w jednej klatce (testy, narzędzia, które czytają last_result od razu po add_child).
@export var async_generation: bool = true

var last_result: RefCounted = null
var is_generating: bool = false
var _transitioning: bool = false
var _task_id: int = -1


## Dane jednej generacji. run() to czyste dane (bez węzłów) — wołane w wątku roboczym albo od razu.
class GenJob extends RefCounted:
	var is_cave: bool = false
	var gen_script: Script = null
	var base_script: Script = null  # MapGeneratorBase (create_rng)
	var seed_value: int = 0
	var width: int = 0
	var height: int = 0
	var min_room: int = 6
	var max_room: int = 24
	var rooms_count: int = 0
	var corridor: int = 3
	var flags = null
	var behaviour: Dictionary = {}
	var result: RefCounted = null
	var rng: RandomNumberGenerator = null
	var plans: Dictionary = {}

	func run() -> void:
		if is_cave:
			result = gen_script.generate(width, height, seed_value, min_room, max_room, rooms_count, corridor, flags)
			# Seed faktycznie użyty przez topologię (== seed_value, gdy > 0; przy losowym seedzie
			# kafle i teren dostają ten sam, więc maski terenu z etapu obiektów pasują).
			rng = base_script.create_rng(result.seed_used)
			plans = gen_script.plan_cave_tiles(result, rng, -1, flags,
				behaviour.get("profile"), behaviour.get("field"), behaviour.get("raw", {}))
		else:
			result = gen_script.generate(width, height, seed_value)
			rng = base_script.create_rng(seed_value)


## Wczytuje companion-JSON (parametry generatora + Named TileSet System).
## Zwraca obiekt konfiguracji lub null (puste/brak ścieżki => stary tryb).
func _load_behaviour_config():
	var json_path := _resolve_behaviour_json_path()
	if json_path.is_empty():
		return null
	var cfg = GeneratorBehaviourConfig.load_from_json_path(json_path)
	for w in cfg.warnings:
		push_warning("[TileBehaviour] " + w)
	for e in cfg.errors:
		push_error("[TileBehaviour] " + e)
	return cfg


## Jawna ścieżka z @export wygrywa; inaczej (tylko jaskinie) companion-JSON używanego tilesetu.
func _resolve_behaviour_json_path() -> String:
	if not tile_behaviour_json_path.is_empty():
		return tile_behaviour_json_path
	if level_type != LevelType.CAVE_DUNGEON:
		return ""
	var ts_path: String = custom_tileset.resource_path if custom_tileset != null else CaveGeneratorScript.CAVES_TILESET_PATH
	return GeneratorBehaviourConfig.resolve_json_path(ts_path)


## Buduje profil + pole zestawów dla Named TileSet System z wczytanego configu.
## Zwraca {profile, field, raw}. Brak profilu => {} (generator działa jak dotychczas).
func _build_tile_behaviour(cfg, gen_width: int, gen_height: int) -> Dictionary:
	if cfg == null or cfg.profile == null:
		return {} # brak profilu => stary tryb (stałe)

	# TileSetField: domyślnie puste (pojedynczy zestaw = default_tileset_id).
	# MIXED: gdy JSON ustawia tilesets.mixed = <id puli>, wypełniamy field tym id dla
	# całego obszaru mapy -> resolver miesza rodziny per moduł (respektując grupę).
	var field = TileSetFieldScript.new()
	var mix_id: StringName = cfg.mixed_pool_id()
	if mix_id != &"" and cfg.profile.get_mixed_pool(mix_id) != null:
		field.fill_rect(Rect2i(-6, -6, gen_width + 12, gen_height + 12), mix_id)
	return {"profile": cfg.profile, "field": field, "raw": cfg.raw}


func _ready() -> void:
	y_sort_enabled = true
	_ensure_default_resources()
	if async_generation:
		generate_level_async(map_seed)
	else:
		generate_level(map_seed)
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		if level_type == LevelType.DUNGEON_CASTLE:
			audio.play_music("castle")
		elif level_type == LevelType.CAVE_DUNGEON:
			audio.play_music("caves")
		else:
			audio.play_music("fairy_forest")


func _ensure_default_resources() -> void:
	if enemy_scenes.is_empty():
		var enemy_paths: Array[String] = []
		if level_type == LevelType.CAVE_DUNGEON:
			enemy_paths = [
				"res://modules/quiz_rpg/scenes/enemies/slime_tutorial.tscn",
				"res://modules/quiz_rpg/scenes/enemies/slime_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/slime_tutorial_boss.tscn"
			]
		elif level_type == LevelType.FOREST_OVERWORLD:
			enemy_paths = [
				"res://modules/quiz_rpg/scenes/enemies/slime_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/plant_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/warhog.tscn"
			]
		else:
			enemy_paths = [
				"res://modules/quiz_rpg/scenes/enemies/bandit_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/ork_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/knowledge_guardian.tscn"
			]
		for ep in enemy_paths:
			if ResourceLoader.exists(ep):
				var p := load(ep) as PackedScene
				if p:
					enemy_scenes.append(p)

	if chest_scene == null:
		var cp := "res://modules/quiz_rpg/scenes/objects/closed_chest_tutorial.tscn"
		if ResourceLoader.exists(cp):
			chest_scene = load(cp) as PackedScene

	if door_scene == null and level_type == LevelType.DUNGEON_CASTLE:
		var dp := "res://modules/quiz_rpg/scenes/objects/tutorial_area/door_horizontal.tscn"
		if ResourceLoader.exists(dp):
			door_scene = load(dp) as PackedScene


## Generuje poziom synchronicznie (cała mapa w tej klatce).
func generate_level(seed_val: int = 0) -> void:
	var job := _prepare_job(seed_val)
	job.run()
	_apply_job(job)
	generation_finished.emit()


## Generuje poziom w tle: topologia + plan kafli w wątku roboczym, potem kafle porcjami między
## klatkami, encje i nawigacja. Ekran ładowania śledzi znaczniki GenProgress. Kończy się sygnałem
## generation_finished (level_manager czeka na niego przed postawieniem gracza).
func generate_level_async(seed_val: int = 0) -> void:
	if is_generating:
		return
	is_generating = true
	var job := _prepare_job(seed_val)
	var progress := GenProgress.new()
	var overlay = LoadingOverlayScript.new(_loading_title())
	add_child(overlay)
	overlay.track(progress)
	GenProgress.start(progress)

	_task_id = WorkerThreadPool.add_task(job.run, false, "Generowanie mapy")
	while not WorkerThreadPool.is_task_completed(_task_id):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1

	await _apply_job_async(job)
	progress.finish()
	GenProgress.stop()
	overlay.close()
	is_generating = false
	generation_finished.emit()


func _exit_tree() -> void:
	# Poziom zamknięty w trakcie generowania: dokończ zadanie wątku (inaczej wyciek zadania puli).
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		GenProgress.stop()


func _loading_title() -> String:
	match level_type:
		LevelType.CAVE_DUNGEON:
			return "Generowanie jaskini…"
		LevelType.DUNGEON_CASTLE:
			return "Generowanie zamku…"
	return "Generowanie mapy…"


## Parametry generacji z UI/@export, zapisu i companion-JSON (główny wątek: węzły, zasoby).
func _prepare_job(seed_val: int) -> GenJob:
	# Companion-JSON: parametry generatora + Named TileSet System (opcjonalne).
	# Precedencja parametrów: UI/@export (>0) > zapisany seed (per-save) > JSON > default.
	var cfg = _load_behaviour_config()
	var level_key := _level_key()
	var lsm = _get_level_state_manager()

	# Seed: jawny @export/UI (>0) > zapisany per-save > JSON > wylosuj.
	var explicit_seed: int = seed_val if seed_val > 0 else (map_seed if map_seed > 0 else 0)
	var actual_seed: int = explicit_seed
	if actual_seed <= 0 and lsm != null and not level_key.is_empty():
		actual_seed = lsm.get_map_seed(level_key)
	if actual_seed <= 0 and cfg != null:
		actual_seed = cfg.gen_int("seed", 0)
	if actual_seed <= 0:
		actual_seed = int(randi() % 1000000) + 1

	# Utrwal seed dla tego poziomu, gdy nie było jeszcze zapisanego (stały układ
	# per-save). Jawny @export/UI jest override'em projektanta i NIE nadpisuje zapisu.
	if explicit_seed <= 0 and lsm != null and not level_key.is_empty() and lsm.get_map_seed(level_key) <= 0:
		lsm.set_map_seed(level_key, actual_seed)

	var gen_width: int = map_width if map_width > 0 else (cfg.gen_int("width", 160) if cfg != null else 160)
	var gen_height: int = map_height if map_height > 0 else (cfg.gen_int("height", 160) if cfg != null else 160)

	# Flagi generacji z JSON (wspólne dla topologii i tilingu). Brak JSON => null => domyślne.
	var cave_flags = cfg.build_flags() if cfg != null else null

	var job := GenJob.new()
	job.is_cave = level_type == LevelType.CAVE_DUNGEON
	job.base_script = MapGeneratorBaseScript
	job.seed_value = actual_seed
	job.width = gen_width
	job.height = gen_height
	job.flags = cave_flags

	match level_type:
		LevelType.CAVE_DUNGEON:
			job.gen_script = CaveGeneratorScript
			job.min_room = cfg.gen_int("min_room_size", 6) if cfg != null else 6
			job.max_room = cfg.gen_int("max_room_size", 24) if cfg != null else 24
			job.corridor = cfg.gen_int("corridor_width", 3) if cfg != null else 3
			var rooms_count: int = cave_max_rooms
			if rooms_count <= 0 and cfg != null:
				rooms_count = cfg.gen_int("max_rooms", 0)
			if rooms_count <= 0:
				# Skalowanie: 60x60 -> 6, 160x160 -> 15, 250x250 -> ~37 (clamp 4..120)
				rooms_count = int(clampf(round(15.0 * (float(gen_width * gen_height) / (160.0 * 160.0))), 4, 120))
			job.rooms_count = rooms_count
			# Named TileSet System (opcjonalny). Profil i pole zestawów z wczytanego configu.
			job.behaviour = _build_tile_behaviour(cfg, gen_width, gen_height)
		LevelType.FOREST_OVERWORLD:
			job.gen_script = OverworldForestGeneratorScript
		LevelType.DUNGEON_CASTLE:
			job.gen_script = DungeonGeneratorScript
	return job


func _palette() -> Dictionary:
	match level_type:
		LevelType.CAVE_DUNGEON:
			return CaveGeneratorScript.get_default_palette()
		LevelType.FOREST_OVERWORLD:
			return OverworldForestGeneratorScript.get_default_palette()
	return DungeonGeneratorScript.get_default_palette()


## TileSet poziomu: @export > tileset z palety (jaskinie) > domyślny z tekstury palety.
func _resolve_tileset(palette: Dictionary) -> TileSet:
	var ts := custom_tileset
	if ts == null:
		if level_type == LevelType.CAVE_DUNGEON:
			var cave_ts_path: String = palette.get("tileset_path", "res://modules/quiz_rpg/resources/maps/caves.tres")
			if ResourceLoader.exists(cave_ts_path):
				ts = load(cave_ts_path) as TileSet
		if ts == null:
			var tex_path: String = palette.get("texture_path", "")
			var col_tiles: Array = palette.get("collision_tiles", [])
			ts = MapGeneratorBaseScript.create_default_tileset(tex_path, col_tiles)
	return ts


## Warstwy poziomu. Jaskinie: przygotowane i wyczyszczone przez generator (FloorDecor/Platforms).
func _prepare_layers(job: GenJob) -> Dictionary:
	var ts := _resolve_tileset(_palette())
	var floor_layer := _get_or_create_layer("Floor", -2, ts)
	var floor_decor := _get_or_create_layer("FloorDecor", -1, ts)
	var walls_layer := _get_or_create_layer("Walls", 0, ts)
	var platforms_layer := _get_or_create_layer("Platforms", -1, ts)  # płaskowyże: pod Walls i encjami
	if level_type == LevelType.CAVE_DUNGEON:
		return CaveGeneratorScript.prepare_cave_layers(floor_layer, walls_layer, job.result, floor_decor, platforms_layer)
	return {&"Floor": floor_layer, &"FloorDecor": floor_decor, &"Walls": walls_layer, &"Platforms": platforms_layer}


## Nakłada wynik generacji na scenę w jednej klatce.
func _apply_job(job: GenJob) -> void:
	last_result = job.result
	var layers := _prepare_layers(job)
	if level_type == LevelType.CAVE_DUNGEON:
		seed(job.rng.seed)  # jak apply_cave_tiles: globalny seed dla operacji silnika
		CaveGeneratorScript.execute_cave_tiles(layers, job.plans)
	else:
		_apply_grid_layers(job, layers)
	_finish_level(job)


## Jak _apply_job, ale kafle jaskini porcjami (PAINT_CHUNK na klatkę) z postępem paska.
func _apply_job_async(job: GenJob) -> void:
	last_result = job.result
	var layers := _prepare_layers(job)
	if level_type == LevelType.CAVE_DUNGEON:
		seed(job.rng.seed)
		GenProgress.begin(&"paint")
		var tiles = job.plans.tiles
		var order := [&"Floor", &"Walls", &"Platforms"]
		var total := 0
		for layer_name in order:
			total += (tiles.by_layer.get(layer_name, {}) as Dictionary).size()
		var done := 0
		for layer_name in order:
			if layer_name == &"Walls":
				# Teren (błoto/trawa) między Floor a Walls — jak execute_cave_tiles.
				TerrainPaintExecutor.execute(layers, job.plans.terrain)
			var layer: TileMapLayer = layers.get(layer_name)
			var cells: Dictionary = tiles.by_layer.get(layer_name, {})
			if layer == null or cells.is_empty():
				continue
			var positions: Array = cells.keys()
			for from in range(0, positions.size(), PAINT_CHUNK):
				TilePlacementExecutor.place_range(layer, cells, positions, from, from + PAINT_CHUNK)
				done += mini(PAINT_CHUNK, positions.size() - from)
				GenProgress.sub(float(done) / maxf(total, 1))
				await get_tree().process_frame
	else:
		_apply_grid_layers(job, layers)
	await _finish_level(job, ENTITY_CHUNK)


func _apply_grid_layers(job: GenJob, layers: Dictionary) -> void:
	var floor_decor: TileMapLayer = layers.get(&"FloorDecor")
	if floor_decor:
		floor_decor.clear()
	(layers[&"Platforms"] as TileMapLayer).clear()
	MapGeneratorBaseScript.apply_grid_to_layers(layers[&"Floor"], layers[&"Walls"], job.result, _palette(), job.rng)


## Encje, nawigacja i wyjście — wspólne dla obu ścieżek. per_frame > 0: encje porcjami między
## klatkami (wtedy wołać z await); 0 = od razu (wywołanie bez await jest synchroniczne).
func _finish_level(job: GenJob, per_frame: int = 0) -> void:
	# 3. Encje (gracz, wrogowie, skrzynie)
	GenProgress.begin(&"entities")
	if spawn_entities_enabled:
		await MapGeneratorBaseScript.spawn_entities(self, job.result, enemy_scenes, chest_scene, door_scene, 16, per_frame)
		# Obiekty z generatora obiektów (po encjach — spawn_entities czyści węzeł Objects).
		var walls := get_node_or_null("Walls") as TileMapLayer
		await ObjectRealizer.realize(self, job.result.objects as ObjectPlan, walls.tile_set if walls else null, {&"chest": chest_scene}, per_frame)

	# 4. Nawigacja 2D
	GenProgress.begin(&"navigation")
	if setup_nav_enabled:
		MapGeneratorBaseScript.setup_navigation_region(self, job.result)

	# 5. Podepnij wyjscie
	_connect_exit_trigger()


func _get_or_create_layer(layer_name: String, z_idx: int, ts: TileSet) -> TileMapLayer:
	var layer := get_node_or_null(layer_name) as TileMapLayer
	if not layer:
		layer = TileMapLayer.new()
		layer.name = layer_name
		add_child(layer)
	layer.tile_set = ts
	layer.z_index = z_idx
	layer.y_sort_enabled = true
	return layer


func _connect_exit_trigger() -> void:
	var exit_area := get_node_or_null("enter_next_level") as Area2D
	if exit_area and not exit_area.body_entered.is_connected(_on_exit_body_entered):
		exit_area.body_entered.connect(_on_exit_body_entered)


func _on_exit_body_entered(body: Node2D) -> void:
	if _transitioning:
		return
	if not (body.is_in_group("player") or body.name == "Player"):
		return
	if next_level_path.is_empty():
		return
		
	var level_manager := _find_level_manager()
	if level_manager and level_manager.has_method("change_level"):
		_transitioning = true
		level_manager.call("change_level", next_level_path, next_spawn_name)


func _find_level_manager() -> Node:
	var cur := get_tree().current_scene
	if cur:
		var lm := cur.find_child("level_manager", true, false)
		if lm:
			return lm
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_active_module"):
		var module_root: Variant = core_manager.call("get_active_module")
		if module_root is Node:
			return (module_root as Node).find_child("level_manager", true, false)
	return null


## Klucz poziomu do zapisu seeda/stanu. scene_file_path jest ustawiony już w _ready
## (niezależnie od timingu level_managera) i równy ścieżce używanej przez skrzynie itd.
func _level_key() -> String:
	if not scene_file_path.is_empty():
		return scene_file_path
	var lm := _find_level_manager()
	if lm != null and lm.get("current_level_path") != null:
		return str(lm.get("current_level_path"))
	return ""


func _get_level_state_manager() -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var s: Variant = core_manager.call("get_singleton", "LevelStateManager")
		if s is Node:
			return s
	return get_node_or_null("/root/LevelStateManager")


## Reroll mapy: przypisuje nowy seed i CZYŚCI zapisany stan tego poziomu
## (skrzynie/beczki/ściany/boss — bo stare id pozycyjne nie pasują do nowego układu),
## a następnie przeładowuje poziom, generując go z nowym seedem.
## new_seed <= 0 => losowy. Publiczne API — np. po zebraniu trzeciego fragmentu.
func reroll(new_seed: int = 0) -> void:
	var level_key := _level_key()
	var lsm = _get_level_state_manager()
	if lsm == null or level_key.is_empty():
		push_warning("[ProceduralLevel] reroll: brak LevelStateManager lub klucza poziomu")
		return

	if new_seed > 0:
		lsm.clear_level_state(level_key)
		lsm.set_map_seed(level_key, new_seed)
	else:
		lsm.reroll_map_seed(level_key)

	var lm := _find_level_manager()
	if lm != null and lm.has_method("change_level"):
		var path := str(lm.get("current_level_path"))
		if path.is_empty():
			path = scene_file_path
		var spawn: String = str(lm.get("current_spawn_name")) if lm.get("current_spawn_name") != null else next_spawn_name
		lm.call("change_level", path, spawn)
	else:
		push_warning("[ProceduralLevel] reroll: brak level_managera — mapa dostanie nowy seed przy następnym wejściu.")
