extends RefCounted

## Mapy z wyprzedzeniem: dane mapy (GenJob.run — topologia, plan kafli, siatka nawigacji) liczone w tle dla
## sąsiednich poziomów (next_level_path, potem previous_level_path), gdy gracz jest na mapie. Wejście na mapę
## (ProceduralLevel.generate_level_async) bierze gotowe dane — zostaje tylko kładzenie kafli, encje i obiekty.
## Wynik zależy tylko od seeda zapisu, konfiguracji i rozmiaru (klucz), więc liczony wcześniej jest identyczny.
## Jedno zadanie w tle naraz (jeden rdzeń); gotowe dane trzymane dla MAX_READY ostatnich zleceń. Policzona mapa
## trafia też na dysk (ProceduralLevel.save_prefetched_async — kafle malowane w tle), więc po restarcie gry sąsiednie
## mapy wczytują się z pliku.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const MAX_READY := 2

static var PROCEDURAL_BASE: String = QuizRpgPaths.path("scenes/maps/procedural_level.tscn")

static var _queue: PackedStringArray = []   # sceny czekające na swoją kolej
static var _entries: Array = []             # {path, key, job, task, waited, stale} — liczone i gotowe, od najstarszego
static var _pumping := false


## Klucz danych mapy: poziom, seed, rozmiar i krawędzie trasy map (MapLinks — inna trasa = inna mapa).
static func key_of(job) -> String:
	var links := ""
	if job.flags != null and (job.flags.entrance_edge >= 0 or not job.flags.exit_edges.is_empty()):
		links = "|e%d>%s" % [job.flags.entrance_edge, ",".join(Array(job.flags.exit_edges).map(func(e): return str(e)))]
	return "%s|%d|%dx%d%s" % [job.level_key, job.seed_value, job.width, job.height, links]


## Zleca w tle dane mapy sceny `level_path` (bez efektu, gdy już są albo czekają, albo scena nie jest
## generowana proceduralnie).
static func request(level_path: String) -> void:
	level_path = QuizRpgPaths.localize(level_path)
	if level_path.is_empty() or level_path in _queue:
		return
	for e in _entries:
		if e.path == level_path and not e.stale:
			return
	_queue.append(level_path)
	if not _pumping:
		_pump()


## Bierze dane mapy o kluczu `key`: {job, task} (task = -1, gdy już policzone) albo {} — brak. Zadanie jeszcze
## liczone: wołający czeka na WorkerThreadPool.is_task_completed(task) i woła wait_for_task_completion.
static func take(key: String) -> Dictionary:
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		if e.key != key or e.stale:
			continue
		_entries.remove_at(i)
		var task: int = e.task
		if not e.waited and WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			task = -1
		elif e.waited:
			task = -1
		return {"job": e.job, "task": task}
	return {}


## Zdejmuje scenę z kolejki (gracz już na nią wchodzi i liczy ją sam).
static func unqueue(level_path: String) -> void:
	var i := _queue.find(QuizRpgPaths.localize(level_path))
	if i >= 0:
		_queue.remove_at(i)


## Zapomina dane (nowy seed zapisu — stare klucze już nie pasują). Zadania w toku kończą się same i wypadają przy
## kolejnym sprzątaniu.
static func clear() -> void:
	_queue.clear()
	for e in _entries:
		e.stale = true
	_sweep(0)


static func _pump() -> void:
	_pumping = true
	var tree := Engine.get_main_loop() as SceneTree
	while not _queue.is_empty() and tree != null:
		# jedno zadanie naraz — następne po zakończeniu poprzedniego
		var busy := false
		for e in _entries:
			if not e.waited and not WorkerThreadPool.is_task_completed(e.task):
				busy = true
		if busy:
			await tree.process_frame
			continue
		var path: String = _queue[0]
		_queue.remove_at(0)
		var prep: Array = await _prepare(path, tree)
		if prep.is_empty():
			continue
		var job = prep[0]
		var lvl: Node = prep[1]
		var key := key_of(job)
		var known := false
		for e in _entries:
			known = known or (e.key == key and not e.stale)
		if known:
			lvl.free()
			continue
		job.background = true
		var task := WorkerThreadPool.add_task(job.run, false, "Mapa z wyprzedzeniem")
		var entry := {"path": path, "key": key, "job": job, "task": task, "waited": false, "stale": false}
		_entries.append(entry)
		_sweep(MAX_READY + 1)
		_save_when_ready(entry, lvl, tree)
	_pumping = false


## Po policzeniu danych: zapis mapy na dysk przez poziom poza drzewem (o ile wejście nie wzięło ich wcześniej).
static func _save_when_ready(entry: Dictionary, lvl: Node, tree: SceneTree) -> void:
	# wpis zdjęty (wejście wzięło dane, sprzątanie) albo czekany przez kogoś innego — ID zadania już nieważne
	while _entries.has(entry) and not entry.waited and not WorkerThreadPool.is_task_completed(entry.task):
		await tree.process_frame
	var free := func() -> bool: return not entry.stale and _entries.has(entry)
	if free.call() and lvl.has_method("save_prefetched_async"):
		await lvl.call("save_prefetched_async", entry.job, free)
	lvl.free()


## [GenJob, poziom poza drzewem] sceny poziomu (wczytanej w tle), bez dodawania jej do drzewa; [] = nie ProceduralLevel.
## Poziom zostaje do zapisu mapy na dysk (_save_when_ready) — zwalnia go wołający.
static func _prepare(path: String, tree: SceneTree) -> Array:
	var scene := QuizRpgPaths.level_scene(path)
	if not ResourceLoader.exists(scene) or ResourceLoader.load_threaded_request(scene, "PackedScene") != OK:
		return []
	while ResourceLoader.load_threaded_get_status(scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
	var packed := ResourceLoader.load_threaded_get(scene) as PackedScene
	if packed == null or not _is_procedural(packed):
		return []
	# Sceny wrogów z pul map (~0,4 s) wczytane w tle przed _prepare_job — inaczej enemy_scene() czeka albo wczytuje je
	# na głównym wątku (zacięcie zaraz po wejściu na mapę, np. tutorial zleca jaskinię od razu po starcie).
	var level_script: Script = load(QuizRpgPaths.path("scripts/maps/procedural_level.gd"))
	level_script.call("warm_enemy_scenes")
	while not bool(level_script.call("enemy_scenes_ready")):
		await tree.process_frame
	var lvl := packed.instantiate()
	lvl.set("level_path", path)
	# Zasoby .tres z companion-JSON (tabele łupu z przedmiotami) też w tle — trzymane do końca _prepare_job.
	var held: Array = []
	for res_path in _json_resources(str(lvl.call("_resolve_behaviour_json_path"))):
		if ResourceLoader.load_threaded_request(res_path) == OK:
			held.append(res_path)
	for res_path in held:
		while ResourceLoader.load_threaded_get_status(res_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
	held = held.map(func(p): return ResourceLoader.load_threaded_get(p))
	var job = null
	if lvl.has_method("_prepare_job") and bool(lvl.get("async_generation")):
		job = lvl.call("_prepare_job", 0)
	if job == null:
		lvl.free()
		return []
	return [job, lvl]


## Ścieżki .tres z companion-JSON mapy (wartości tekstowe w głąb, względem modułu albo res://), które istnieją.
static func _json_resources(json_path: String) -> Array:
	var out: Array = []
	if json_path.is_empty() or not FileAccess.file_exists(json_path):
		return out
	_collect_tres(JSON.parse_string(FileAccess.get_file_as_string(json_path)), out)
	return out


static func _collect_tres(v: Variant, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			_collect_tres(v[k], out)
	elif v is Array:
		for e in v:
			_collect_tres(e, out)
	elif v is String and String(v).ends_with(".tres"):
		var p := String(v) if String(v).begins_with("res://") else QuizRpgPaths.path(String(v))
		if not out.has(p) and ResourceLoader.exists(p):
			out.append(p)


## Czy scena dziedziczy po procedural_level.tscn (bez tworzenia jej węzłów — mapy ręczne bywają duże).
static func _is_procedural(packed: PackedScene) -> bool:
	var p := packed
	for _depth in 4:
		var base := p.get_state().get_node_instance(0)
		if base == null:
			return false
		if base.resource_path == PROCEDURAL_BASE:
			return true
		p = base
	return false


## Zostawia najwyżej `keep` wpisów (najstarsze gotowe wypadają; liczone dalej zostają do końca zadania).
static func _sweep(keep: int) -> void:
	for e in _entries:
		if not e.waited and WorkerThreadPool.is_task_completed(e.task):
			WorkerThreadPool.wait_for_task_completion(e.task)
			e.waited = true
	var i := 0
	while _entries.size() > keep and i < _entries.size():
		if _entries[i].waited:
			_entries.remove_at(i)
		else:
			i += 1
