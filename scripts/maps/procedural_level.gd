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
const FrameSlicer = preload("../generation/core/frame_slicer.gd")
const MapPrefetch = preload("map_prefetch.gd")
const MapDiskCache = preload("map_disk_cache.gd")
const MapLinks = preload("map_links.gd")
const LoadingScreenScene = preload("../../scenes/ui/loading_screen.tscn")
const EndScreenScene = preload("../../scenes/ui/end_screen.tscn")
## Flaga fabularna ukończenia gry (znacznik „Ukończono” w opisie slotu zapisu).
const GAME_COMPLETED_FLAG := "game:completed"

## Koniec generowania (także synchronicznego) — mapa, encje i nawigacja są gotowe.
signal generation_finished

## Kafli wstawianych między sprawdzeniami budżetu klatki (FrameSlicer) przy generowaniu w tle.
const PAINT_STEP := 512
## Budżet klatki (ms) malowania kafli mapy z wyprzedzeniem w trakcie gry (zapis na dysk, save_prefetched_async).
const BACKGROUND_PAINT_MS := 2.0
## Kafli między sprawdzeniami budżetu przy malowaniu w tle (mniej niż PAINT_STEP — budżet tylko 2 ms).
const BACKGROUND_PAINT_STEP := 64

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
var _faction_pools: Dictionary = {}  # frakcja -> pula (companion-JSON "enemies" jako słownik)
var _enemy_levels: Dictionary = {}  # companion-JSON "enemy_levels": tier -> [min, max] poziomu wroga
var _enemy_loot: Dictionary = {}  # companion-JSON "enemy_loot": tier wroga (int) -> QuizRpgLootTableData (ścieżka .tres)
var _chest_loot: QuizRpgLootTableData = null  # companion-JSON "chest_loot": ścieżka .tres — tabela skrzyń strefy
var _barrel_loot: QuizRpgLootTableData = null  # companion-JSON "barrel_loot": ścieżka .tres — tabela beczek strefy
var _chest_tier: int = 1  # companion-JSON "chest_tier" (1..4): trudność quizu wytrycha dla skrzyń wygenerowanych na mapie
var _niche_content: Dictionary = {}  # companion-JSON "niche_content": wagi, tier i łup zawartości nisz out (NicheContentPlanner)
var _treasure: Dictionary = {}  # companion-JSON "treasure": skarb (TreasurePlanner) — skrzynie (tier, łup) albo relikwia
var _boss_cfg: Dictionary = {}  # companion-JSON "boss": story_id, counts_toward_device, locks_exit bossów mapy
var _exit_ends_game := false  # companion-JSON "exit_ends_game": wyjście pokazuje ekran końca zamiast następnej mapy
var _random_encounters: Dictionary = {}  # companion-JSON "random_encounters": tryb, dystans i tiery losowych spotkań (QuizRpgRandomEncounters)
var _rare_rooms: Dictionary = {}  # companion-JSON "rare_rooms": skrzynie specjalne w rzadkich pokojach (TreasurePlanner.plan_rare)
@export var chest_scene: PackedScene = null
@export var door_scene: PackedScene = null
@export var next_level_path: String = ""
@export var next_spawn_name: String = "Spawn"
## Powrót przez wejście (enter_previous_level): poziom i spawn, w którym się pojawia (marker przy jego wyjściu).
@export var previous_level_path: String = ""
@export var previous_spawn_name: String = LevelPortal.FROM_NEXT_SPAWN
## Krawędź, którą następna mapa (ręczna, o stałym układzie — np. miasto) ma wejście: wyjście tej mapy wypada po
## przeciwnej stronie (spójna trasa, MapLinks). Dowolna = wg trasy.
@export_enum("Dowolna:-1", "N:0", "E:1", "S:2", "W:3") var next_entry_edge: int = -1
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
## Tło ekranu ładowania przekazane przez level_manager przed add_child — to samo, co na jego ekranie sprzed
## generowania (inaczej drugie losowanie podmieniało obraz w chwili ruszenia paska). null = losowe z folderu mapy.
var loading_background: Texture2D = null
## Pełna ścieżka poziomu (level_manager przed add_child) — z argumentem mapy (QuizRpgPaths.level_arg), gdy jedna scena
## daje wiele map: sekretny pokój "<scena>#<poziom niszy>@<x>,<y>" (powrót do markera przed niszą). Pusta = scene_file_path.
var level_path: String = ""
## Sekcja companion-JSON nakładana na resztę pliku (słowniki scalane w głąb, inne wartości zastępowane) — np. "secret_room":
## mniejsza mapa, bez wyjścia, skarb. Dodatkowo "rooms": [min, max] — liczba pokoi losowana z seeda mapy.
@export var config_overlay: String = ""

var last_result: RefCounted = null
## Zapis mapy na dysk (MapDiskCache): plik i podpis bieżącej generacji, bajty migawki po malowaniu kafli.
var _cache_path := ""
var _cache_sig := ""
var _cache_bytes := PackedByteArray()
## Spójna trasa map (MapLinks.constraints) z _prepare_job — zapisywana w LevelStateManager po wygenerowaniu.
var _link_constraints: Dictionary = {}
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
	## Pasek, do którego raportuje run() w wątku roboczym (GenProgress.bind); background = mapa z wyprzedzeniem
	## (bez paska, dopóki gracz na nią nie wejdzie — GenProgress.set_holder_progress).
	var progress = null
	var background := false

	func run() -> void:
		var bound := background or progress != null
		if bound:
			GenProgress.bind(self)
		_run()
		if bound:
			GenProgress.unbind()

	func _run() -> void:
		if is_cave:
			result = gen_script.generate(width, height, seed_value, min_room, max_room, rooms_count, corridor, flags)
			# Seed faktycznie użyty przez topologię (== seed_value, gdy > 0; przy losowym seedzie
			# kafle i teren dostają ten sam, więc maski terenu z etapu obiektów pasują).
			rng = base_script.create_rng(result.seed_used)
			plans = gen_script.plan_cave_tiles(result, rng, -1, flags,
				behaviour.get("profile"), behaviour.get("field"), behaviour.get("raw", {}))
			# Zawartość nisz out (powstają przy kaflach) i skarb (sekretny pokój) — przed siatką nawigacji i zapisem mapy.
			var raw: Dictionary = behaviour.get("raw", {})
			NicheContentPlanner.plan(result, raw.get("niche_content", {}))
			TreasurePlanner.plan(result, raw.get("treasure", {}))
			TreasurePlanner.plan_rare(result, raw.get("rare_rooms", {}))
			TreasurePlanner.plan_return_boss(result, raw.get("return_boss", {}))
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
	if not config_overlay.is_empty():
		var over: Variant = cfg.raw.get(config_overlay)
		if over is Dictionary:
			_merge_deep(cfg.raw, over)
		else:
			push_warning("[TileBehaviour] brak sekcji '%s' w %s" % [config_overlay, json_path])
	return cfg


## Scala `over` w `base` w głąb: słowniki rekurencyjnie, inne wartości (też tablice) zastępowane.
static func _merge_deep(base: Dictionary, over: Dictionary) -> void:
	for k in over:
		if over[k] is Dictionary and base.get(k) is Dictionary:
			_merge_deep(base[k], over[k])
		else:
			base[k] = over[k]


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
	_apply_return_point()
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
	# Pula domyślna typu poziomu ładowana dopiero w _prepare_job, gdy companion-JSON nie poda własnej
	# (ładowanie jej zawsze kosztowało ~0,3 s na głównym wątku przed ekranem ładowania — i tak była podmieniana).
	_enemy_pool = enemy_scenes.duplicate() if not enemy_scenes.is_empty() else []

	if chest_scene == null:
		var cp := QuizRpgPaths.path("scenes/objects/closed_chest_tutorial.tscn")
		if ResourceLoader.exists(cp):
			chest_scene = load(cp) as PackedScene

	if door_scene == null and level_type == LevelType.DUNGEON_CASTLE:
		var dp := QuizRpgPaths.path("scenes/objects/tutorial_area/door_horizontal.tscn")
		if ResourceLoader.exists(dp):
			door_scene = load(dp) as PackedScene


## Domyślna pula wrogów typu poziomu (bez puli z companion-JSON); element: ścieżka albo tablica wariantów tieru.
func _default_enemy_paths() -> Array:
	if level_type == LevelType.CAVE_DUNGEON:
		return [
			QuizRpgPaths.path("scenes/enemies/pixel_crawler/fungus_immature.tscn"),
			QuizRpgPaths.path("scenes/enemies/pixel_crawler/fungus_long.tscn"),
			QuizRpgPaths.path("scenes/enemies/pixel_crawler/fungus_heavy.tscn"),
			QuizRpgPaths.path("scenes/enemies/pixel_crawler/fungus_old.tscn")
		]
	if level_type == LevelType.FOREST_OVERWORLD:
		return [
			QuizRpgPaths.path("scenes/enemies/slime_1.tscn"),
			QuizRpgPaths.path("scenes/enemies/plant_1.tscn"),
			QuizRpgPaths.path("scenes/enemies/warhog.tscn")
		]
	return [
		QuizRpgPaths.path("scenes/enemies/bandit_1.tscn"),
		QuizRpgPaths.path("scenes/enemies/ork_1.tscn"),
		QuizRpgPaths.path("scenes/enemies/knowledge_guardian.tscn")
	]


## Generuje poziom synchronicznie (cała mapa w tej klatce).
func generate_level(seed_val: int = 0) -> void:
	var job := _prepare_job(seed_val)
	var progress: GenProgress = null
	if job.debug_report:
		progress = GenProgress.new()
		GenProgress.start(progress)
	job.run()
	_apply_job(job)
	if progress != null:
		progress.finish()
		GenProgress.stop()
	if job.debug_report:
		print(map_report(job, progress))
	_record_link(job)
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
	# Wagi etapów zależą od układu mapy (jaskinia / ścieki) i rosną z jej polem (pasek płynie między kotwicami).
	progress.configure(str(job.flags.layout) if job.flags != null else "interior", job.width, job.height)
	var overlay = LoadingScreenScene.instantiate()
	overlay.title = _loading_title()
	var raw_loc: String = location_name if not location_name.is_empty() else str(LOCATION_NAMES.get(level_type, ""))
	var map_k := get_map_key()
	var loc := QuizRpgI18n.t("map." + map_k + ".name", raw_loc) if map_k != "" else raw_loc
	# Własna nazwa sceny (map.<scena>.name, jak na ekranie level_managera) przed nazwą klucza mapy — np. sekretny pokój
	# ma tła jaskini, ale inną nazwę.
	var scene_name := QuizRpgPaths.level_scene(_level_key()).get_file().get_basename()
	overlay.location = QuizRpgI18n.t("map." + scene_name + ".name", loc) if scene_name != "" else loc
	if loading_background != null:
		overlay.background = loading_background
	else:
		# Folder o nazwie sceny (np. sewer/), gdy ma grafiki, inaczej folder klucza mapy (biom) — jak nazwa wyżej.
		overlay.set_background_for([scene_name, map_k])
	add_child(overlay)
	overlay.track(progress)
	GenProgress.start(progress)

	# Mapa zapisana na dysku (ten sam seed zapisu, konfiguracja i tileset): bez generowania, od razu kafle z pliku.
	_setup_disk_cache(job)
	var snap: Dictionary = MapDiskCache.read(_cache_path, _cache_sig) if not _cache_path.is_empty() else {}
	if not snap.is_empty():
		MapPrefetch.unqueue(job.level_key)
		await get_tree().process_frame  # generation_finished zawsze po wyjściu z _ready (jak przy generowaniu w wątku)
		await _apply_cached_async(job, snap)
		_finish_generation(progress, overlay, job)
		return

	# Dane mapy policzone już w tle (MapPrefetch, ten sam klucz = te same dane) albo liczone teraz.
	var pre: Dictionary = MapPrefetch.take(MapPrefetch.key_of(job)) if _prefetch_allowed() else {}
	if not pre.is_empty():
		job = pre.job
		_task_id = pre.task
		if _task_id >= 0:
			GenProgress.set_holder_progress(job, progress)
	else:
		MapPrefetch.unqueue(job.level_key)
		job.progress = progress
		_task_id = WorkerThreadPool.add_task(job.run, false, "Generowanie mapy")
	if _task_id >= 0:
		while not WorkerThreadPool.is_task_completed(_task_id):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1

	await _apply_job_async(job)
	_finish_generation(progress, overlay, job)


## Koniec generowania (z pliku albo świeżego): pasek, ekran ładowania, sygnał, zapis na dysk, mapy z wyprzedzeniem.
func _finish_generation(progress, overlay, job: GenJob) -> void:
	progress.finish()
	GenProgress.stop()
	overlay.close()
	is_generating = false
	if job.debug_report:
		print(map_report(job, progress))
	generation_finished.emit()
	if not _cache_bytes.is_empty():
		MapDiskCache.save_async(_cache_path, _cache_bytes)
		_cache_bytes = PackedByteArray()
	_record_link(job)  # przed zleceniem sąsiednich map — następna liczy wejście z tego wpisu
	if _prefetch_allowed():
		MapPrefetch.request(next_level_path)
		MapPrefetch.request(previous_level_path)


## Zapis map na dysk tylko w grze (jak mapy z wyprzedzeniem) i dla jaskiń / ścieków (układ z planem kafli).
## `check_game`: false dla poziomu poza drzewem z MapPrefetch (ten liczy mapy tylko w grze).
func _setup_disk_cache(job: GenJob, check_game: bool = true) -> void:
	_cache_path = ""
	_cache_sig = ""
	_cache_bytes = PackedByteArray()
	if not job.is_cave or not MapDiskCache.enabled() or (check_game and not _prefetch_allowed()):
		return
	var lsm = _get_level_state_manager()
	if lsm == null or job.level_key.is_empty():
		return
	MapDiskCache.sweep_once()
	var files: Array = [_resolve_behaviour_json_path()]
	if job.flags != null and not str(job.flags.objects_catalog).is_empty():
		files.append(job.flags.objects_catalog)
	var ts_path: String = custom_tileset.resource_path if custom_tileset != null else str(_palette().get("tileset_path", ""))
	files.append(ts_path)
	_cache_path = MapDiskCache.path_for(lsm.get_world_seed(), job.level_key)
	_cache_sig = MapDiskCache.signature(MapPrefetch.key_of(job), files)


## Jak _apply_job_async, ale warstwy kafli i wynik z pliku — encje, obiekty, nawigacja i wyjścia liczone jak zawsze.
func _apply_cached_async(job: GenJob, snap: Dictionary) -> void:
	var catalog = null
	if job.flags != null and not str(job.flags.objects_catalog).is_empty():
		catalog = ObjectCatalog.load_path(job.flags.objects_catalog)
	job.result = MapDiskCache.restore_result(snap.r, catalog)
	job.debug_report = false
	last_result = job.result
	var layers := _prepare_layers(job)
	MapDiskCache.apply_tiles(layers, snap.tiles)
	seed(job.result.seed_used)  # jak przy malowaniu (job.rng.seed): encje dostają ten sam ciąg losowań
	_cache_path = ""
	await _finish_level(job, FrameSlicer.new())


## Mapy z wyprzedzeniem tylko w grze: seed zapisu i flagi z JSON-a (eksplorator map podaje własne).
func _prefetch_allowed() -> bool:
	return map_seed <= 0 and flag_overrides.is_empty() and _find_level_manager() != null


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
	if r.preprocess_stats != null and r.preprocess_stats.has("structured"):
		var st_stats: Dictionary = r.preprocess_stats["structured"]
		lines.append("  ścieki: kanały %d (%d suchych), kompleksy %d, pokoje %d (dostawione %d), kładki %d, korytarze serwisowe %d, pętle %d, naprawy %d (zamurowane %d)" % [
			st_stats.get("segs", 0), st_stats.get("dry_segs", 0), st_stats.get("complexes", 0),
			st_stats.get("rooms", 0), st_stats.get("rooms_flush", 0),
			st_stats.get("bridges", 0), st_stats.get("service", 0),
			st_stats.get("loops", 0), st_stats.get("repairs", 0), st_stats.get("repair_walled", 0)
		])
		if st_stats.has("t") and st_stats["t"] is Dictionary:
			var t_sub: Dictionary = st_stats["t"]
			var sub_lines := PackedStringArray()
			for k in t_sub.keys():
				sub_lines.append("%s: %.1f ms" % [k, float(t_sub[k])])
			lines.append("    pod-etapy korytarzy (structured): " + ", ".join(sub_lines))
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


## Azyl przy punkcie pojawienia się gracza (QuizRpgSafeZone, tworzy level_manager): pokój z tym punktem,
## przycięty do ±SAFE_ZONE_HALF_CELLS kratek (pokój wyjścia z bossem nie staje się w całości azylem przy
## powrocie z następnej mapy). Poza pokojem — sam kwadrat. Współrzędne globalne; pusty Rect2 = brak danych.
const SAFE_ZONE_HALF_CELLS := SpawnPlanner.START_SAFE_HALF
const CELL_PX := 16


func start_safe_zone_rect(spawn_global: Vector2) -> Rect2:
	if last_result == null:
		return Rect2()
	var cell := Vector2i((to_local(spawn_global) / CELL_PX).floor())
	var area := Rect2i(cell - Vector2i.ONE * SAFE_ZONE_HALF_CELLS, Vector2i.ONE * (SAFE_ZONE_HALF_CELLS * 2 + 1))
	for room: Rect2i in last_result.rooms:
		if room.has_point(cell):
			area = area.intersection(room)
			break
	return Rect2(to_global(Vector2(area.position * CELL_PX)), Vector2(area.size * CELL_PX))


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


## Pula wrogów z listy tierów: element = ścieżka sceny albo tablica ścieżek (warianty tieru); nieistniejące pomijane.
func _pool_from_paths(enemy_paths: Array) -> Array:
	var pool: Array = []
	for entry in enemy_paths:
		var variants: Array[PackedScene] = []
		for ep in (entry if entry is Array else [entry]):
			var p := enemy_scene(String(ep))
			if p:
				variants.append(p)
		if variants.size() == 1:
			pool.append(variants[0])
		elif variants.size() > 1:
			pool.append(variants)
	return pool


## Sceny wrogów z pul map trzymane przez całą sesję modułu — wczytanie (~0,4 s) nie wypada na główny wątek
## przed ekranem ładowania każdej mapy. warm_enemy_scenes() (start modułu) zleca wczytanie w tle.
static var _enemy_scenes := {}      # ścieżka -> PackedScene (null = brak)
static var _enemy_requested := {}   # ścieżki wczytywane w tle (load_threaded_request)


static func enemy_scene(path: String) -> PackedScene:
	if _enemy_scenes.has(path):
		return _enemy_scenes[path]
	var p: PackedScene = null
	if _enemy_requested.has(path):
		_enemy_requested.erase(path)
		p = ResourceLoader.load_threaded_get(path) as PackedScene   # czeka, jeśli jeszcze się wczytuje
	elif ResourceLoader.exists(path):
		p = load(path) as PackedScene
	_enemy_scenes[path] = p
	return p


## Czy sceny wrogów zlecone w tle (warm_enemy_scenes) już się wczytały — wtedy enemy_scene() nie czeka na głównym wątku.
static func enemy_scenes_ready() -> bool:
	for path in _enemy_requested:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
	return true


## Zleca wczytanie w tle scen wrogów ze wszystkich companion-JSON map ("enemies": tiery albo frakcje -> tiery).
static func warm_enemy_scenes() -> void:
	var dir := QuizRpgPaths.path("resources/maps/config")
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if not data is Dictionary:
			continue
		var en: Variant = (data as Dictionary).get("enemies")
		var tier_lists: Array = []
		if en is Array:
			tier_lists.append(en)
		elif en is Dictionary:
			tier_lists.append_array((en as Dictionary).values())
		var rb: Variant = (data as Dictionary).get("return_boss")
		if rb is Dictionary and str(rb.get("scene", "")) != "":
			tier_lists.append([str(rb.scene)])   # boss powrotu (TreasurePlanner.plan_return_boss)
		for tiers in tier_lists:
			if not tiers is Array:
				continue
			for entry in tiers:
				for e in (entry if entry is Array else [entry]):
					var path := QuizRpgPaths.path(String(e))
					if not _enemy_scenes.has(path) and not _enemy_requested.has(path) and ResourceLoader.exists(path) \
							and ResourceLoader.load_threaded_request(path) == OK:
						_enemy_requested[path] = true


## Tiery puli ze ścieżek względem modułu (tier = ścieżka albo lista wariantów) -> ścieżki res://.
func _module_paths(tiers: Array) -> Array:
	var paths: Array = []
	for entry in tiers:
		if entry is Array:
			paths.append((entry as Array).map(func(e): return QuizRpgPaths.path(String(e))))
		else:
			paths.append(QuizRpgPaths.path(String(entry)))
	return paths


## Parametry generacji z UI/@export, zapisu i companion-JSON (główny wątek: węzły, zasoby).
func _prepare_job(seed_val: int) -> GenJob:
	# Companion-JSON: parametry generatora + Named TileSet System (opcjonalne).
	# Precedencja parametrów: UI/@export (>0) > seed zapisu > JSON > default.
	var cfg = _load_behaviour_config()
	# Pula wrogów mapy z companion-JSON ("enemies": tiery, ścieżki względem modułu; tier = ścieżka albo lista
	# wariantów) — gdy scena nie ma własnej (enemy_scenes); inaczej domyślna typu poziomu.
	# Słownik frakcja -> tiery: osobne pule (spawny z "faction", SpawnPlanner); pierwsza frakcja = pula domyślna.
	_faction_pools = {}
	_enemy_levels = cfg.raw.get("enemy_levels", {}) if cfg != null else {}
	_chest_tier = clampi(int(cfg.raw.get("chest_tier", 1)) if cfg != null else 1, 1, 4)
	_enemy_loot = {}
	var enemy_loot: Variant = cfg.raw.get("enemy_loot", {}) if cfg != null else {}
	if enemy_loot is Dictionary:
		for tier in enemy_loot:
			var data := QuizRpgLootTableData.from_json(enemy_loot[tier])
			if data != null:
				_enemy_loot[int(str(tier))] = data
	_chest_loot = QuizRpgLootTableData.from_json(cfg.raw.get("chest_loot", "")) if cfg != null else null
	_barrel_loot = QuizRpgLootTableData.from_json(cfg.raw.get("barrel_loot", "")) if cfg != null else null
	_niche_content = cfg.raw.get("niche_content", {}) if cfg != null else {}
	_treasure = cfg.raw.get("treasure", {}) if cfg != null else {}
	_boss_cfg = cfg.raw.get("boss", {}) if cfg != null else {}
	_exit_ends_game = bool(cfg.raw.get("exit_ends_game", false)) if cfg != null else false
	_rare_rooms = cfg.raw.get("rare_rooms", {}) if cfg != null else {}
	_random_encounters = cfg.raw.get("random_encounters", {}) if cfg != null else {}
	if enemy_scenes.is_empty() and cfg != null:
		var en: Variant = cfg.raw.get("enemies")
		if en is Array:
			var pool := _pool_from_paths(_module_paths(en))
			if not pool.is_empty():
				_enemy_pool = pool
		elif en is Dictionary:
			for k in en:
				var fp := _pool_from_paths(_module_paths(en[k]))
				if not fp.is_empty():
					_faction_pools[String(k)] = fp
					if _faction_pools.size() == 1:
						_enemy_pool = fp
	if _enemy_pool.is_empty():
		_enemy_pool = _pool_from_paths(_default_enemy_paths())
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
	# Spójna trasa map: wejście naprzeciw wyjścia poprzedniej mapy, wyjście nie w stronę odwiedzonych (MapLinks).
	_link_constraints = {}
	var link_name := _link_name(lsm)
	if cave_flags != null and not link_name.is_empty():
		_link_constraints = MapLinks.constraints(lsm.map_links, link_name, QuizRpgPaths.level_name(previous_level_path))
		cave_flags.entrance_edge = int(_link_constraints.in)
		var out_edge := MapLinks.opposite(next_entry_edge)
		if out_edge >= 0 and out_edge != int(_link_constraints.in):
			_link_constraints.allow = [out_edge] as Array[int]   # następna mapa ma stałe wejście
		cave_flags.exit_edges.assign(_link_constraints.allow)

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
			var rooms_range: Variant = cfg.raw.get("rooms") if cfg != null else null
			if rooms_count <= 0 and rooms_range is Array and (rooms_range as Array).size() == 2:
				# "rooms": [min, max] (nakładka sekretnego pokoju) — z seeda mapy, ta sama mapa = tyle samo pokoi
				var rr := RandomNumberGenerator.new()
				rr.seed = hash([actual_seed, "rooms"])
				rooms_count = rr.randi_range(int(rooms_range[0]), int(rooms_range[1]))
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


## Jak _apply_job, ale kafle, encje i obiekty porcjami wg budżetu czasu klatki (FrameSlicer) z postępem paska.
func _apply_job_async(job: GenJob) -> void:
	last_result = job.result
	var layers := _prepare_layers(job)
	var slicer := FrameSlicer.new()
	if level_type == LevelType.CAVE_DUNGEON:
		seed(job.rng.seed)
		GenProgress.begin(&"paint")
		await _paint_cave_tiles(job, layers, get_tree(), slicer, PAINT_STEP, true)
		GenProgress.end(&"paint")
		if not _cache_path.is_empty():
			_cache_bytes = MapDiskCache.encode(MapDiskCache.snapshot(layers, job.result, _cache_sig))
	else:
		_apply_grid_layers(job, layers)
	await _finish_level(job, slicer)


## Kafle jaskini / ścieków z planu (kolejność jak execute_cave_tiles), porcjami wg `slicer`. Bez losowania — ten sam
## plan daje te same warstwy (także malowany w tle przez save_prefetched_async). `progress`: pasek GenProgress.
func _paint_cave_tiles(job: GenJob, layers: Dictionary, tree: SceneTree, slicer, step: int, progress: bool) -> void:
	var tiles = job.plans.tiles
	var order := [&"Floor", &"FloorDecor", &"Curbs", &"Bridges", &"Walls", &"Rails", &"Platforms", &"PortalShade"]
	var total := 0
	for layer_name in order:
		total += (tiles.by_layer.get(layer_name, {}) as Dictionary).size()
	var done := 0
	for layer_name in order:
		if layer_name == &"FloorDecor":
			# Teren (błoto/trawa) między Floor a FloorDecor / Walls — jak execute_cave_tiles.
			await TerrainPaintExecutor.execute_chunked(layers, job.plans.terrain, tree, slicer)
		var layer: TileMapLayer = layers.get(layer_name)
		var cells: Dictionary = tiles.by_layer.get(layer_name, {})
		if layer == null or cells.is_empty():
			continue
		var positions: Array = cells.keys()
		for from in range(0, positions.size(), step):
			TilePlacementExecutor.place_range(layer, cells, positions, from, from + step)
			done += mini(step, positions.size() - from)
			if slicer.due():
				if progress:
					GenProgress.sub(float(done) / maxf(total, 1))
				await slicer.next_frame(tree)


## Zapis na dysk mapy policzonej z wyprzedzeniem (MapPrefetch; poziom poza drzewem): kafle malowane małymi porcjami
## w trakcie gry, potem migawka jak przy wejściu — po restarcie gry sąsiednie mapy wczytują się z pliku. `still_free`:
## czy dane nadal czekają w MapPrefetch (wejście, które je wzięło, zapisze mapę samo — wynik zmienia już gra).
## Bez efektu, gdy plik z tym podpisem już jest albo to nie jaskinia / ścieki.
func save_prefetched_async(job: GenJob, still_free: Callable) -> void:
	# Kroki po kilka ms rozdzielone klatkami (gra trwa): podpis, sprawdzenie pliku, kafle porcjami, migawka, kodowanie.
	var tree := Engine.get_main_loop() as SceneTree
	_setup_disk_cache(job, false)
	if _cache_path.is_empty() or job.plans == null:
		return
	await tree.process_frame
	if not MapDiskCache.read(_cache_path, _cache_sig).is_empty():
		return
	await tree.process_frame
	var layers := _prepare_layers(job)
	await _paint_cave_tiles(job, layers, tree, FrameSlicer.new(BACKGROUND_PAINT_MS), BACKGROUND_PAINT_STEP, false)
	await tree.process_frame
	if not still_free.call():
		return
	var snap := MapDiskCache.snapshot(layers, job.result, _cache_sig)
	await tree.process_frame
	if still_free.call():
		MapDiskCache.save_async(_cache_path, MapDiskCache.encode(snap))


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


## Encje, nawigacja i wyjście — wspólne dla obu ścieżek. slicer (FrameSlicer): encje i obiekty porcjami
## między klatkami (wtedy wołać z await); null = od razu (wywołanie bez await jest synchroniczne).
func _finish_level(job: GenJob, slicer: FrameSlicer = null) -> void:
	# 3. Encje (gracz, wrogowie, skrzynie)
	GenProgress.begin(&"entities")
	if spawn_entities_enabled:
		await MapGeneratorBaseScript.spawn_entities(self, job.result, _enemy_pool, job.chest_scene if job.chest_scene != null else chest_scene, door_scene, 16, slicer, _faction_pools, _enemy_levels)
		GenProgress.end(&"entities")
		# Obiekty z generatora obiektów (po encjach — spawn_entities czyści węzeł Objects).
		var walls := get_node_or_null("Walls") as TileMapLayer
		GenProgress.begin(&"props")
		await ObjectRealizer.realize(self, job.result.objects as ObjectPlan, walls.tile_set if walls else null, {&"chest": job.chest_scene if job.chest_scene != null else chest_scene}, slicer)
		GenProgress.end(&"props")
		_apply_chest_tier()
		_apply_loot_tables()
		_apply_niche_content(job.result)
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
	_setup_exit_gate()
	_setup_random_encounters()


## Losowe spotkania mapy ("random_encounters" w JSON; tryb "off" albo brak wpisu = bez spotkań).
func _setup_random_encounters() -> void:
	var old := get_node_or_null("RandomEncounters")
	if old != null:
		old.queue_free()
	var re := QuizRpgRandomEncounters.create(_random_encounters, _enemy_pool, _faction_pools, _enemy_levels)
	if re != null:
		re.enemy_loot = _enemy_loot
		add_child(re)


## Ustawia tier ("chest_tier" z JSON mapy) na skrzyniach wygenerowanych na tej mapie (spawn_entities i generator obiektów).
func _apply_chest_tier() -> void:
	for node in get_tree().get_nodes_in_group("chests"):
		if is_ancestor_of(node) and "tier" in node:
			node.set("tier", _chest_tier)


## Tabele łupu z JSON mapy na wrogach, skrzyniach i beczkach wygenerowanych na tej mapie: "enemy_loot" (tier wroga ->
## ścieżka .tres), "chest_loot" i "barrel_loot" (ścieżki .tres — tabele strefy). Tabela trafia tylko do obiektów bez własnej
## (loot_data ustawione w Inspectorze sceny wygrywa).
func _apply_loot_tables() -> void:
	if not _enemy_loot.is_empty():
		for node in get_tree().get_nodes_in_group("enemies"):
			if is_ancestor_of(node) and "loot_data" in node and node.get("loot_data") == null and "encounter_tier" in node:
				node.set("loot_data", _enemy_loot.get(int(node.get("encounter_tier"))))
	if _chest_loot != null:
		for node in get_tree().get_nodes_in_group("chests"):
			if is_ancestor_of(node) and "loot_data" in node and node.get("loot_data") == null:
				node.set("loot_data", _chest_loot)
	if _barrel_loot != null:
		for node in get_tree().get_nodes_in_group("destructible"):
			if is_ancestor_of(node) and "loot_data" in node and node.get("loot_data") == null:
				node.set("loot_data", _barrel_loot)


## Zawartość nisz out (NicheContentPlanner, "niche_content" w JSON mapy): skrzynie nisz dostają własny tier ("chest_tier",
## domyślnie tier mapy) i łup ("chest_loot", .tres), przedmioty na ziemi — wpis z "item_loot" (.tres) wylosowany z hash(seed mapy, id),
## więc ta sama mapa ma w tej samej niszy ten sam przedmiot. Przejścia do sekretnych pokoi: cel = scena "secret_scene"
## (nisza pokoju relikwii — "relic_scene") z argumentem (ten poziom i kratka niszy), przed niszą marker powrotu
## (secret_marker).
func _apply_niche_content(result) -> void:
	_apply_treasure()
	var cfg: Dictionary = _niche_content
	if cfg.is_empty() or result == null:
		return
	_apply_special_chests("niche_chest_", cfg)
	var item_data := QuizRpgLootTableData.from_json(cfg.get("item_loot", ""))
	var item_loot: Array[Dictionary] = []
	if item_data != null:
		item_loot = item_data.to_table()
	var secret_scene := QuizRpgPaths.path(str(cfg.get("secret_scene", "")))
	var relic_scene := QuizRpgPaths.path(str(cfg.get("relic_scene", "")))
	for node in get_tree().get_nodes_in_group("secret_passages"):
		if not is_ancestor_of(node):
			continue
		var cell: Vector2i = node.get("niche_cell")
		var scene := relic_scene if String(node.get("unique_id")).begins_with(String(NicheContentPlanner.RELIC_ID) + "_") else secret_scene
		var target := "%s%s%s@%d,%d" % [scene, QuizRpgPaths.LEVEL_ARG_SEP, _level_key(), cell.x, cell.y]
		node.set("on_enter", _change_level.bind(target, "Spawn"))
		node.set_meta(&"target_level", target)   # minimapa: przejście odwiedzone = poziom celu ma stan
		LevelPortal.place_marker(self, secret_marker(cell), Vector2((cell.x + 1) * CELL_PX, (cell.y + 1) * CELL_PX))
	for node in get_tree().get_nodes_in_group("ground_items"):
		if not is_ancestor_of(node) or item_loot.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([result.seed_used, String(node.get("unique_id"))])
		var picked := QuizRpgLootTable.pick_weighted(item_loot, rng)
		if not picked.is_empty():
			node.set("item_id", str(picked.get("item_id", "potion")))
			node.set("count", QuizRpgLootEntry.roll_count(picked, rng))


## Skarb ("treasure", TreasurePlanner): skrzynie (tier i łup). "flag" — skrzynia z jedynym przedmiotem (krypta): flaga
## ustawiana przy otwarciu, stała przy rerollu (przedmiot nie wraca); "prefer_key" — klucz przed wytrychem. Boss mapy
## ("boss": story_id, counts_toward_device, locks_exit — _setup_exit_gate; "story": false — boss poza fabułą, bez flagi boss:<id>; "loot" —
## własna tabela łupu .tres, np. strażnik krypty z gwarantowanym kluczem do skrzyni skarbu).
func _apply_treasure() -> void:
	_apply_special_chests(String(TreasurePlanner.CHEST_DEF_ID) + "_", _treasure)
	_apply_special_chests(String(TreasurePlanner.RARE_DEF_ID) + "_", _rare_rooms)
	if _treasure.has("flag"):
		for node in get_tree().get_nodes_in_group("chests"):
			if is_ancestor_of(node) and String(node.get("unique_id")).begins_with(String(TreasurePlanner.CHEST_DEF_ID) + "_"):
				node.set("story_flag", str(_treasure.flag))
				node.set("prefer_key", bool(_treasure.get("prefer_key", false)))
	if not _boss_cfg.is_empty():
		var boss_loot := QuizRpgLootTableData.from_json(_boss_cfg.get("loot", ""))
		for node in get_tree().get_nodes_in_group("enemies"):
			if is_ancestor_of(node) and bool(node.get("is_boss")):
				node.set("boss_story_id", str(_boss_cfg.get("story_id", "")))
				node.set("story_boss", bool(_boss_cfg.get("story", true)))
				node.set("counts_toward_device", bool(_boss_cfg.get("counts_toward_device", true)))
				if boss_loot != null:
					node.set("loot_data", boss_loot)


## Skrzynie o unique_id z prefiksem (nisze, skarb): tier ("chest_tier", domyślnie tier mapy) i łup ("chest_loot": ścieżka .tres)
## z `cfg` — zamiast tabeli strefy.
func _apply_special_chests(prefix: String, cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	var tier := clampi(int(cfg.get("chest_tier", _chest_tier)), 1, 4)
	var loot := QuizRpgLootTableData.from_json(cfg.get("chest_loot", ""))
	for node in get_tree().get_nodes_in_group("chests"):
		if is_ancestor_of(node) and String(node.get("unique_id")).begins_with(prefix):
			node.set("tier", tier)
			if loot != null:
				node.set("loot_data", loot)


## Nazwa markera powrotu przed niszą z przejściem do sekretnego pokoju.
static func secret_marker(cell: Vector2i) -> String:
	return "Secret_%d_%d" % [cell.x, cell.y]


## Mapa z argumentem "<poziom>@<x>,<y>" (sekretny pokój): wejście prowadzi z powrotem na ten poziom, do markera przed niszą.
func _apply_return_point() -> void:
	var arg := QuizRpgPaths.level_arg(level_path)
	var at := arg.rfind("@")
	if at < 0:
		return
	var xy := arg.substr(at + 1).split(",")
	if xy.size() != 2:
		return
	previous_level_path = QuizRpgPaths.localize(arg.substr(0, at))
	previous_spawn_name = secret_marker(Vector2i(int(xy[0]), int(xy[1])))


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
## "exit_ends_game" (ścieki): wyjście kończy grę — _finish_game zamiast przejścia.
func _connect_exit_trigger() -> void:
	var on_exit := _finish_game if _exit_ends_game else _change_level.bind(next_level_path, next_spawn_name)
	LevelPortal.connect_area(get_node_or_null(LevelPortal.NEXT_AREA) as Area2D, on_exit,
		next_portal_use_key, next_portal_prompt)
	LevelPortal.connect_area(get_node_or_null(LevelPortal.PREVIOUS_AREA) as Area2D,
		_change_level.bind(previous_level_path, previous_spawn_name), previous_portal_use_key, previous_portal_prompt)


## Koniec gry (uproszczone zakończenie na inżynierkę): wyjście ze ścieków na cmentarzysko — flaga game:completed,
## zapis w bieżącym slocie (jeśli wybrany) i ekran końca. Każde kolejne wejście w wyjście pokazuje ekran znowu.
func _finish_game() -> void:
	if get_tree().root.get_children().any(func(n: Node) -> bool: return n.scene_file_path == EndScreenScene.resource_path):
		return
	var lsm := _get_level_state_manager()
	if lsm != null and lsm.has_method("set_story_flag"):
		lsm.set_story_flag(GAME_COMPLETED_FLAG)
	var saved := false
	var core := get_node_or_null("/root/CoreManager")
	var sm: Variant = core.get_singleton("SaveManager") if core else null
	if sm is Node and int((sm as Node).get("current_save_slot")) >= 0:
		saved = bool((sm as Node).call("save_game"))
	var screen := EndScreenScene.instantiate()
	screen.set("saved", saved)
	get_tree().root.add_child(screen)


## Wyjście zamknięte do pokonania bossów mapy (companion-JSON "boss": {"locks_exit": true}, np. ścieki — boss przed
## ekranem końca): obszar wyjścia nie działa, a snop światła drabiny wyjścia jest ukryty. Otwiera się, gdy ostatni boss
## zniknie po przegranej walce albo gdy był już pokonany w tym zapisie (usuwa się sam po wczytaniu).
func _setup_exit_gate() -> void:
	if not bool(_boss_cfg.get("locks_exit", false)):
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(node) and bool(node.get("is_boss")):
			node.tree_exiting.connect(_refresh_exit_gate.bind(node))
	_refresh_exit_gate()


func _refresh_exit_gate(leaving: Node = null) -> void:
	if not is_inside_tree():
		return
	var locked := false
	for node in get_tree().get_nodes_in_group("enemies"):
		if node != leaving and is_ancestor_of(node) and bool(node.get("is_boss")) and not bool(node.get("defeated")):
			locked = true
			break
	var area := get_node_or_null(LevelPortal.NEXT_AREA) as Area2D
	if area:
		area.set_deferred("monitoring", not locked)
	for node in get_tree().get_nodes_in_group(MapGeneratorBaseScript.EXIT_PORTAL_GROUP):
		if is_ancestor_of(node):
			node.set("light_on", not locked)


func _change_level(path: String, spawn_name: String) -> void:
	if _transitioning or path.is_empty():
		return
	var level_manager := _find_level_manager()
	if level_manager and level_manager.has_method("change_level"):
		_transitioning = true
		level_manager.call("change_level", path, spawn_name)


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


## Klucz poziomu do zapisu seeda/stanu: level_path (z argumentem mapy) albo scene_file_path — ustawione już w _ready
## (niezależnie od timingu level_managera) i równe ścieżce używanej przez skrzynie itd.
func _level_key() -> String:
	if not level_path.is_empty():
		return level_path
	if not scene_file_path.is_empty():
		return scene_file_path
	var lm := _find_level_manager()
	if lm != null and lm.get("current_level_path") != null:
		return str(lm.get("current_level_path"))
	return ""


## Zapisuje mapę w trasie (MapLinks.record): ograniczenia z _prepare_job i faktyczna krawędź wyjścia.
func _record_link(job: GenJob) -> void:
	var lsm := _get_level_state_manager()
	var link_name := _link_name(lsm)
	if not link_name.is_empty() and job.result != null:
		MapLinks.record(lsm.map_links, link_name, _link_constraints, int(job.result.exit_edge))


## Nazwa mapy w trasie (MapLinks) albo "": tylko mapy głównego łańcucha w grze — seed zapisu, bez nadpisań eksploratora
## map i bez argumentu mapy (sekretne pokoje nie).
func _link_name(lsm: Node) -> String:
	if lsm == null or map_seed > 0 or not flag_overrides.is_empty():
		return ""
	var key := _level_key()
	if key.is_empty() or not QuizRpgPaths.level_arg(key).is_empty():
		return ""
	return QuizRpgPaths.level_name(key)


func _get_level_state_manager() -> Node:
	# Przez korzeń drzewa, nie get_node("/root/…") — działa też dla poziomu poza drzewem (MapPrefetch).
	var tree := Engine.get_main_loop() as SceneTree
	var root: Node = tree.root if tree != null else null
	if root == null:
		return null
	var core_manager := root.get_node_or_null("CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var s: Variant = core_manager.call("get_singleton", "LevelStateManager")
		if s is Node:
			return s
	return root.get_node_or_null("LevelStateManager")


## Reroll: NOWY seed zapisu (new_seed <= 0 => losowy) — zmienia wszystkie mapy, więc czyści stan wszystkich
## poziomów (skrzynie/beczki/ściany/bossowie; stare id pozycyjne nie pasują do nowego układu), a następnie
## przeładowuje bieżący poziom. Postęp urządzenia zostaje. Publiczne API — np. po zebraniu trzeciego fragmentu.
func reroll(new_seed: int = 0) -> void:
	var lsm = _get_level_state_manager()
	if lsm == null:
		push_warning("[ProceduralLevel] reroll: brak LevelStateManager")
		return
	var old_seed: int = lsm.get_world_seed()
	lsm.reroll_world_seed(new_seed)
	MapPrefetch.clear()
	MapDiskCache.clear_seed_if_unused(old_seed)  # stare mapy, o ile żaden slot zapisu nie ma tego seeda

	var lm := _find_level_manager()
	if lm != null and lm.has_method("change_level"):
		var path := str(lm.get("current_level_path"))
		if path.is_empty():
			path = scene_file_path
		var spawn: String = str(lm.get("current_spawn_name")) if lm.get("current_spawn_name") != null else next_spawn_name
		lm.call("change_level", path, spawn)
	else:
		push_warning("[ProceduralLevel] reroll: brak level_managera — mapy dostaną nowy seed przy następnym wejściu.")
