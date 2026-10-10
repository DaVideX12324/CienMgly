extends Node2D
class_name ProceduralLevel

## Scena poziomu generowanego proceduralnie dla modulu Quiz RPG.
## W pelni kompatybilna z LevelManager i systemem zapisu.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const LevelPortal = preload("level_portal.gd")
const HeightVeilScript = preload("height_veil.gd")
const GateNavScript = preload("gate_nav.gd")
const MapGeneratorBaseScript = preload("../generation/map_generator_base.gd")
const OverworldForestGeneratorScript = preload("../generation/overworld_forest_generator.gd")
const DungeonGeneratorScript = preload("../generation/dungeon_generator.gd")
const CaveGeneratorScript = preload("../generation/cave_generator.gd")
const TileSetFieldScript = preload("../generation/core/tileset_field.gd")
const GenProgress = preload("../generation/core/gen_progress.gd")
const LoadingScreenScene = preload("../../scenes/ui/loading_screen.tscn")

## Koniec generowania (także synchronicznego) — mapa, encje i nawigacja są gotowe.
signal generation_finished

## Kafli wstawianych na klatkę przy generowaniu w tle (reszta klatki zostaje na pasek ładowania).
const PAINT_CHUNK := 6000
## Encji (wrogów/skrzyń/drzwi) tworzonych na klatkę przy generowaniu w tle.
const ENTITY_CHUNK := 6
## Budżet pracy obiektów (ObjectRealizer) na klatkę, ms — reszta klatki dla paska ładowania.
const PROPS_BUDGET_MS := 8

enum LevelType {
	FOREST_OVERWORLD,
	DUNGEON_CASTLE,
	CAVE_DUNGEON
}

const LOADING_SCREEN_KEYS := {
	LevelType.FOREST_OVERWORLD: "forest",
	LevelType.DUNGEON_CASTLE: "castle",
	LevelType.CAVE_DUNGEON: "cave",
}
const LOCATION_NAMES := {
	LevelType.FOREST_OVERWORLD: "Las",
	LevelType.DUNGEON_CASTLE: "Zamek",
	LevelType.CAVE_DUNGEON: "Jaskinia",
}

@export var level_type: LevelType = LevelType.FOREST_OVERWORLD
@export var map_seed: int = 0
## Nadpisania GenerationFlags (nazwa flagi -> wartość) ponad companion-JSON — ustawia eksplorator map.
var flag_overrides: Dictionary = {}
@export var map_width: int = 160
@export var map_height: int = 160
@export var custom_tileset: TileSet = null
@export var enemy_scenes: Array[PackedScene] = []
## Pula do spawn_entities (indeks = tier - 1): enemy_scenes z edytora albo domyślna pula typu poziomu,
## w której tier może mieć kilka wariantów (tablica scen).
var _enemy_pool: Array = []
@export var chest_scene: PackedScene = null
@export var door_scene: PackedScene = null
@export var next_level_path: String = ""
@export var next_spawn_name: String = "Spawn"
## Powrót przez wejście (enter_previous_level): poziom i spawn, w którym się pojawia (marker przy jego wyjściu).
@export var previous_level_path: String = ""
@export var previous_spawn_name: String = LevelPortal.FROM_NEXT_SPAWN
@export_group("Przejścia")
## Wyjście / wejście aktywowane klawiszem interakcji (E) zamiast wejścia w obszar — np. drabina w ściekach.
@export var next_portal_use_key: bool = false
@export var previous_portal_use_key: bool = false
## Tekst podpowiedzi w trybie klawisza („” = „Przejdź”).
@export var next_portal_prompt: String = ""
@export var previous_portal_prompt: String = ""
@export_group("")
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
## Klucz mapy: folder grafik ekranu ładowania (assets/textures/loading_screens/<klucz>/) i teł walki
## (battle_backgrounds/[pixel_crawler/]<klucz>/). Puste = biom z typu poziomu (LOADING_SCREEN_KEYS).
@export var loading_screen_key: String = ""
## Nazwa lokacji na ekranie ładowania. Puste = nazwa z typu poziomu (LOCATION_NAMES).
@export var location_name: String = ""

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
	var debug_report := false       # caves.json debug.print_map_report — raport mapy do Output
	var level_key := ""
	var result: RefCounted = null
	var rng: RandomNumberGenerator = null
	var plans: Dictionary = {}
	var chest_scene: PackedScene = null  # scena skrzyni z companion-JSON (nadpisuje @export chest_scene)

	func run() -> void:
		if is_cave:
			result = gen_script.generate(width, height, seed_value, min_room, max_room, rooms_count, corridor, flags)
			# Seed faktycznie użyty przez topologię (== seed_value, gdy > 0; przy losowym seedzie
			# kafle i teren dostają ten sam, więc maski terenu z etapu obiektów pasują).
			rng = base_script.create_rng(result.seed_used)
			plans = gen_script.plan_cave_tiles(result, rng, -1, flags,
				behaviour.get("profile"), behaviour.get("field"), behaviour.get("raw", {}))
			# Siatka nawigacji z mapy (podłoga bez barier i przeszkód) — wypiekana tu, w wątku roboczym,
			# w kawałkach (cała mapa naraz: minuty przy 500×500).
			GenProgress.begin(&"navmesh")
			result.nav_polygons = NavOutlines.build_chunks(result)
			GenProgress.end(&"navmesh")
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
	if not enemy_scenes.is_empty():
		_enemy_pool = enemy_scenes.duplicate()
	else:
		_enemy_pool = []
		var enemy_paths: Array = []  # element: ścieżka albo tablica ścieżek (warianty tieru)
		if level_type == LevelType.CAVE_DUNGEON:
			enemy_paths = [
				QuizRpgPaths.path("scenes/enemies/pixel_crawler/fungus_immature.tscn"),
				[
					QuizRpgPaths.path("scenes/enemies/pixel_crawler/fungus_long.tscn"),
					QuizRpgPaths.path("scenes/enemies/pixel_crawler/fungus_heavy.tscn"),
				],
				QuizRpgPaths.path("scenes/enemies/pixel_crawler/fungus_old.tscn")
			]
		elif level_type == LevelType.FOREST_OVERWORLD:
			enemy_paths = [
				QuizRpgPaths.path("scenes/enemies/slime_1.tscn"),
				QuizRpgPaths.path("scenes/enemies/plant_1.tscn"),
				QuizRpgPaths.path("scenes/enemies/warhog.tscn")
			]
		else:
			enemy_paths = [
				QuizRpgPaths.path("scenes/enemies/bandit_1.tscn"),
				QuizRpgPaths.path("scenes/enemies/ork_1.tscn"),
				QuizRpgPaths.path("scenes/enemies/knowledge_guardian.tscn")
			]
		for entry in enemy_paths:
			var variants: Array[PackedScene] = []
			for ep in (entry if entry is Array else [entry]):
				if ResourceLoader.exists(ep):
					var p := load(ep) as PackedScene
					if p:
						variants.append(p)
			if variants.size() == 1:
				_enemy_pool.append(variants[0])
			elif variants.size() > 1:
				_enemy_pool.append(variants)

	if chest_scene == null:
		var cp := QuizRpgPaths.path("scenes/objects/closed_chest_tutorial.tscn")
		if ResourceLoader.exists(cp):
			chest_scene = load(cp) as PackedScene

	if door_scene == null and level_type == LevelType.DUNGEON_CASTLE:
		var dp := QuizRpgPaths.path("scenes/objects/tutorial_area/door_horizontal.tscn")
		if ResourceLoader.exists(dp):
			door_scene = load(dp) as PackedScene


## Generuje poziom synchronicznie (cała mapa w tej klatce).
func generate_level(seed_val: int = 0) -> void:
	var job := _prepare_job(seed_val)
	job.run()
	_apply_job(job)
	if job.debug_report:
		print(map_report(job))
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
	# Wagi etapów są dla 250×250 — oczekiwany czas etapu rośnie z polem mapy (pasek płynie między kotwicami).
	progress.ms_per_weight = 10.0 * float(job.width * job.height) / (250.0 * 250.0)
	var overlay = LoadingScreenScene.instantiate()
	overlay.title = _loading_title()
	overlay.location = location_name if not location_name.is_empty() else LOCATION_NAMES.get(level_type, "")
	overlay.set_background_for(get_map_key())
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
	if job.debug_report:
		print(map_report(job, progress))
	generation_finished.emit()


## Raport wygenerowanej mapy (debug.print_map_report w companion-JSON): seed i rozmiar do odtworzenia
## w eksploratorze map, parametry generacji, flagi jaskini, płaskowyże, obiekty, encje, nawigacja
## i czasy etapów (generowanie w tle).
func map_report(job: GenJob, progress = null) -> String:
	var r = job.result
	var lines := PackedStringArray()
	lines.append("===== [Mapa] %s =====" % (job.level_key if not job.level_key.is_empty() else name))
	if r == null:
		lines.append("  brak wyniku generacji")
		return "\n".join(lines)
	lines.append("  seed %d, rozmiar %dx%d  (eksplorator map: seed %d, wymiary %d x %d)" % [r.seed_used, r.width, r.height, r.seed_used, r.width, r.height])
	lines.append("  generacja: pokoje %d (max_rooms %d), rozmiar pokoju %d..%d, korytarz %d" % [r.rooms.size(), job.rooms_count, job.min_room, job.max_room, job.corridor])
	lines.append("  wejście %s, wyjście %s, spawn gracza %s" % [r.entrance_pos, r.exit_pos, r.player_spawn])
	if job.flags != null:
		var parts := PackedStringArray()
		for k in GeneratorBehaviourConfig.FLAG_BOOL_KEYS + GeneratorBehaviourConfig.FLAG_FLOAT_KEYS + GeneratorBehaviourConfig.FLAG_INT_KEYS + GeneratorBehaviourConfig.FLAG_STRING_KEYS:
			var v = job.flags.get(k)
			parts.append("%s=%s" % [k, ("%.3f" % v) if v is float else str(v)])
		lines.append("  flagi:")
		for i in range(0, parts.size(), 6):
			lines.append("    " + ", ".join(parts.slice(i, i + 6)))
	var pl = r.plateau
	if pl != null and not pl.is_empty():
		lines.append("  płaskowyże: maska %d kratek, poziomy %d..%d, schody S/N/E/W %d/%d/%d/%d, naprawa: +%d schodów, -%d płaskowyżów, %d kratek góry zablokowanych" % [
			pl.mask.size(), pl.min_level, pl.max_level, pl.stairs.size(), pl.stairs_north.size(), pl.stairs_east.size(), pl.stairs_west.size(),
			pl.connect_stairs, pl.dropped_pieces, pl.unreachable_top])
	if r.objects != null:
		lines.append("  obiekty: %d (plan %.1f ms, zdjętych dla osiągalności %d) %s" % [r.objects.placements.size(), r.objects.time_usec / 1000.0, r.objects.removed_for_reach, r.objects.stats])
	var chests: int = r.chest_spawns.size() + (r.objects.cells_with_scene("chest").size() if r.objects != null else 0)
	lines.append("  wrogowie %d, skrzynie %d" % [r.enemy_spawns.size(), chests])
	if not r.nav_polygons.is_empty():
		var polys := 0
		for np in r.nav_polygons:
			polys += np.get_polygon_count()
		lines.append("  nawigacja: %d wielokątów w %d kawałkach (siatka z generatora)" % [polys, r.nav_polygons.size()])
	if progress != null:
		lines.append("  czasy etapów:\n" + progress.report())
	return "\n".join(lines)


func _exit_tree() -> void:
	# Poziom zamknięty w trakcie generowania: dokończ zadanie wątku (inaczej wyciek zadania puli).
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		GenProgress.stop()


## Klucz mapy (loading_screen_key albo biom z typu poziomu) — ekran ładowania i tło walki.
func get_map_key() -> String:
	return loading_screen_key if not loading_screen_key.is_empty() else str(LOADING_SCREEN_KEYS.get(level_type, ""))


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
	# Precedencja parametrów: UI/@export (>0) > seed zapisu > JSON > default.
	var cfg = _load_behaviour_config()
	var level_key := _level_key()
	var lsm = _get_level_state_manager()

	# Seed: jawny @export/UI (>0, eksplorator map) > seed mapy z seeda zapisu (LevelStateManager.get_level_seed,
	# jeden seed na save) > JSON > wylosuj (bez LevelStateManagera, np. narzędzia).
	var explicit_seed: int = seed_val if seed_val > 0 else (map_seed if map_seed > 0 else 0)
	var actual_seed: int = explicit_seed
	if actual_seed <= 0 and lsm != null and not level_key.is_empty():
		actual_seed = lsm.get_level_seed(level_key)
	if actual_seed <= 0 and cfg != null:
		actual_seed = cfg.gen_int("seed", 0)
	if actual_seed <= 0:
		actual_seed = int(randi() % 1000000) + 1

	var gen_width: int = map_width if map_width > 0 else (cfg.gen_int("width", 160) if cfg != null else 160)
	var gen_height: int = map_height if map_height > 0 else (cfg.gen_int("height", 160) if cfg != null else 160)

	# Flagi generacji z JSON (wspólne dla topologii i tilingu). Brak JSON => null => domyślne.
	var cave_flags = cfg.build_flags() if cfg != null else null
	# Nadpisania flag z eksploratora map (nazwa flagi -> wartość) — ponad companion-JSON.
	if cave_flags != null:
		for k in flag_overrides:
			cave_flags.set(k, flag_overrides[k])

	var job := GenJob.new()
	job.is_cave = level_type == LevelType.CAVE_DUNGEON
	job.base_script = MapGeneratorBaseScript
	job.seed_value = actual_seed
	job.width = gen_width
	job.height = gen_height
	job.flags = cave_flags
	job.level_key = level_key
	job.debug_report = cfg != null and bool(cfg.debug().get("print_map_report", false))

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
				# Skalowanie: 60x60 -> 6, 160x160 -> 15, 250x250 -> ~37 (clamp 4..120), razy room_density z JSON-a.
				var density := float(cfg.flags().get("room_density", 1.0)) if cfg != null else 1.0
				rooms_count = int(clampf(round(15.0 * density * (float(gen_width * gen_height) / (160.0 * 160.0))), 4, 120))
			job.rooms_count = rooms_count
			# Named TileSet System (opcjonalny). Profil i pole zestawów z wczytanego configu.
			job.behaviour = _build_tile_behaviour(cfg, gen_width, gen_height)
			# Scena skrzyni z companion-JSON ("scenes": {"chest": "res://…"}) — np. skrzynia ścieków z grafiki paczki.
			var chest_path := String((cfg.raw.get("scenes", {}) as Dictionary).get("chest", "")) if cfg != null else ""
			if chest_path != "" and ResourceLoader.exists(chest_path):
				job.chest_scene = load(chest_path) as PackedScene
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
			var cave_ts_path: String = palette.get("tileset_path", QuizRpgPaths.path("resources/maps/caves.tres"))
			if ResourceLoader.exists(cave_ts_path):
				ts = load(cave_ts_path) as TileSet
		if ts == null:
			var tex_path: String = palette.get("texture_path", "")
			var col_tiles: Array = palette.get("collision_tiles", [])
			ts = MapGeneratorBaseScript.create_default_tileset(tex_path, col_tiles)
	return ts


## Warstwy poziomu. Jaskinie: przygotowane i wyczyszczone przez generator (FloorDecor/Bridges/Rails/Platforms;
## Bridges / Rails tylko na mapach z kładkami / barierkami — tworzy je prepare_cave_layers).
func _prepare_layers(job: GenJob) -> Dictionary:
	var ts := _resolve_tileset(_palette())
	var floor_layer := _get_or_create_layer("Floor", -2, ts)
	var floor_decor := _get_or_create_layer("FloorDecor", -1, ts)
	var walls_layer := _get_or_create_layer("Walls", 0, ts)
	var platforms_layer := _get_or_create_layer("Platforms", -1, ts)  # płaskowyże: pod Walls i encjami
	var bridges_layer := get_node_or_null("Bridges") as TileMapLayer
	if bridges_layer != null:
		bridges_layer.tile_set = ts
	var rails_layer := get_node_or_null("Rails") as TileMapLayer
	if rails_layer != null:
		rails_layer.tile_set = ts
	if level_type == LevelType.CAVE_DUNGEON:
		return CaveGeneratorScript.prepare_cave_layers(floor_layer, walls_layer, job.result, floor_decor, platforms_layer, bridges_layer, rails_layer)
	return {&"Floor": floor_layer, &"FloorDecor": floor_decor, &"Bridges": bridges_layer, &"Walls": walls_layer, &"Rails": rails_layer, &"Platforms": platforms_layer}


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
		var order := [&"Floor", &"FloorDecor", &"Curbs", &"Bridges", &"Walls", &"Rails", &"Platforms"]
		var total := 0
		for layer_name in order:
			total += (tiles.by_layer.get(layer_name, {}) as Dictionary).size()
		var done := 0
		for layer_name in order:
			if layer_name == &"FloorDecor":
				# Teren (błoto/trawa) między Floor a FloorDecor / Walls — jak execute_cave_tiles.
				await TerrainPaintExecutor.execute_chunked(layers, job.plans.terrain, get_tree(), PAINT_CHUNK)
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
		GenProgress.end(&"paint")
	else:
		_apply_grid_layers(job, layers)
	await _finish_level(job, ENTITY_CHUNK)


func _apply_grid_layers(job: GenJob, layers: Dictionary) -> void:
	var floor_decor: TileMapLayer = layers.get(&"FloorDecor")
	if floor_decor:
		floor_decor.clear()
	var bridges_layer: TileMapLayer = layers.get(&"Bridges")
	if bridges_layer:
		bridges_layer.clear()
	var rails_layer: TileMapLayer = layers.get(&"Rails")
	if rails_layer:
		rails_layer.clear()
	var curbs := get_node_or_null("Curbs") as TileMapLayer
	if curbs:
		curbs.clear()
	(layers[&"Platforms"] as TileMapLayer).clear()
	MapGeneratorBaseScript.apply_grid_to_layers(layers[&"Floor"], layers[&"Walls"], job.result, _palette(), job.rng)


## Encje, nawigacja i wyjście — wspólne dla obu ścieżek. per_frame > 0: encje porcjami między
## klatkami (wtedy wołać z await); 0 = od razu (wywołanie bez await jest synchroniczne).
func _finish_level(job: GenJob, per_frame: int = 0) -> void:
	# 3. Encje (gracz, wrogowie, skrzynie)
	GenProgress.begin(&"entities")
	if spawn_entities_enabled:
		await MapGeneratorBaseScript.spawn_entities(self, job.result, _enemy_pool, job.chest_scene if job.chest_scene != null else chest_scene, door_scene, 16, per_frame)
		GenProgress.end(&"entities")
		# Obiekty z generatora obiektów (po encjach — spawn_entities czyści węzeł Objects).
		var walls := get_node_or_null("Walls") as TileMapLayer
		GenProgress.begin(&"props")
		await ObjectRealizer.realize(self, job.result.objects as ObjectPlan, walls.tile_set if walls else null, {&"chest": job.chest_scene if job.chest_scene != null else chest_scene}, PROPS_BUDGET_MS if per_frame > 0 else 0)
		GenProgress.end(&"props")
	GenProgress.end(&"entities")  # spawn_entities_enabled = false
	_setup_height_veil(job.result)

	# 4. Nawigacja 2D
	GenProgress.begin(&"navigation")
	if setup_nav_enabled:
		MapGeneratorBaseScript.setup_navigation_region(self, job.result)
		_setup_gate_nav(job.result)
	GenProgress.end(&"navigation")

	# 5. Podepnij wyjscie
	_connect_exit_trigger()


## Nawigacja przez otwarte bramy (GateNav): przebudowa kawałków siatki po otwarciu bramy.
func _setup_gate_nav(result) -> void:
	var old := get_node_or_null("GateNav")
	if old != null:
		old.queue_free()
	var nav := get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if result == null or result.objects == null or nav == null or result.nav_chunk_keys.is_empty():
		return
	var gn: Node = GateNavScript.new()
	gn.name = "GateNav"
	add_child(gn)
	gn.setup(result, nav)


## Efekt wysokości korytarzy-schodów (HeightVeil): węzeł tworzony, gdy mapa ma korytarze-schody.
func _setup_height_veil(result) -> void:
	var old := get_node_or_null("HeightVeil")
	if old != null:
		old.queue_free()
	if result == null or result.canals == null or not "stair_corridors" in result.canals or result.canals.stair_corridors.is_empty():
		return
	var veil: Node2D = HeightVeilScript.new()
	veil.name = "HeightVeil"
	add_child(veil)
	veil.setup(result)


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


## Wyjście -> następny poziom, wejście -> poprzedni. Gracz pojawia się przy markerach odsuniętych od obszarów
## (Spawn przy wejściu, FromNext przy wyjściu — MapGeneratorBase.arrival_cell), więc od razu nie wraca.
func _connect_exit_trigger() -> void:
	LevelPortal.connect_area(get_node_or_null(LevelPortal.NEXT_AREA) as Area2D,
		_change_level.bind(next_level_path, next_spawn_name), next_portal_use_key, next_portal_prompt)
	LevelPortal.connect_area(get_node_or_null(LevelPortal.PREVIOUS_AREA) as Area2D,
		_change_level.bind(previous_level_path, previous_spawn_name), previous_portal_use_key, previous_portal_prompt)


func _change_level(level_path: String, spawn_name: String) -> void:
	if _transitioning or level_path.is_empty():
		return
	var level_manager := _find_level_manager()
	if level_manager and level_manager.has_method("change_level"):
		_transitioning = true
		level_manager.call("change_level", level_path, spawn_name)


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


## Reroll: NOWY seed zapisu (new_seed <= 0 => losowy) — zmienia wszystkie mapy, więc czyści stan wszystkich
## poziomów (skrzynie/beczki/ściany/bossowie; stare id pozycyjne nie pasują do nowego układu), a następnie
## przeładowuje bieżący poziom. Postęp urządzenia zostaje. Publiczne API — np. po zebraniu trzeciego fragmentu.
func reroll(new_seed: int = 0) -> void:
	var lsm = _get_level_state_manager()
	if lsm == null:
		push_warning("[ProceduralLevel] reroll: brak LevelStateManager")
		return
	lsm.reroll_world_seed(new_seed)

	var lm := _find_level_manager()
	if lm != null and lm.has_method("change_level"):
		var path := str(lm.get("current_level_path"))
		if path.is_empty():
			path = scene_file_path
		var spawn: String = str(lm.get("current_spawn_name")) if lm.get("current_spawn_name") != null else next_spawn_name
		lm.call("change_level", path, spawn)
	else:
		push_warning("[ProceduralLevel] reroll: brak level_managera — mapy dostaną nowy seed przy następnym wejściu.")
