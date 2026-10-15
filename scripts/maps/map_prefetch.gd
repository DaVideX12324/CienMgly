extends RefCounted

## Mapy z wyprzedzeniem: dane mapy (GenJob.run — topologia, plan kafli, siatka nawigacji) liczone w tle dla
## sąsiednich poziomów (next_level_path, potem previous_level_path), gdy gracz jest na mapie. Wejście na mapę
## (ProceduralLevel.generate_level_async) bierze gotowe dane — zostaje tylko kładzenie kafli, encje i obiekty.
## Wynik zależy tylko od seeda zapisu, konfiguracji i rozmiaru (klucz), więc liczony wcześniej jest identyczny.
## Jedno zadanie w tle naraz (jeden rdzeń); gotowe dane trzymane dla MAX_READY ostatnich zleceń.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const MAX_READY := 2

static var PROCEDURAL_BASE: String = QuizRpgPaths.path("scenes/maps/procedural_level.tscn")

static var _queue: PackedStringArray = []   # sceny czekające na swoją kolej
static var _entries: Array = []             # {path, key, job, task, waited, stale} — liczone i gotowe, od najstarszego
static var _pumping := false


## Klucz danych mapy: poziom, seed, rozmiar.
static func key_of(job) -> String:
	return "%s|%d|%dx%d" % [job.level_key, job.seed_value, job.width, job.height]


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
		var job = await _prepare(path, tree)
		if job == null:
			continue
		var key := key_of(job)
		var known := false
		for e in _entries:
			known = known or (e.key == key and not e.stale)
		if known:
			continue
		job.background = true
		var task := WorkerThreadPool.add_task(job.run, false, "Mapa z wyprzedzeniem")
		_entries.append({"path": path, "key": key, "job": job, "task": task, "waited": false, "stale": false})
		_sweep(MAX_READY + 1)
	_pumping = false


## GenJob sceny poziomu (wczytanej w tle), bez dodawania jej do drzewa; null = nie ProceduralLevel.
static func _prepare(path: String, tree: SceneTree):
	if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
		return null
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null or not _is_procedural(packed):
		return null
	var lvl := packed.instantiate()
	var job = null
	if lvl.has_method("_prepare_job") and bool(lvl.get("async_generation")):
		job = lvl.call("_prepare_job", 0)
	lvl.free()
	return job


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
