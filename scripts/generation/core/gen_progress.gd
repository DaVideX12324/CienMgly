extends RefCounted

## Znaczniki etapów generowania mapy: postęp dla paska ładowania + czas etapów (profil).
##
## Kod generatora woła statyczne GenProgress.begin(&"etap") na początku etapu, GenProgress.end(&"etap")
## na jego końcu i opcjonalnie GenProgress.sub(0..1) wewnątrz długich pętli. sub() dochodzi najwyżej do
## SUB_MAX etapu — cały etap zalicza dopiero end() (po ostatnim sub(1.0) kod etapu często jeszcze
## pracuje), a 100% paska dopiero finish(). begin() zamyka etap, którego nikt nie zamknął (bez
## przeskoku paska na jego koniec). Aktywny obiekt ustawia wywołujący
## (GenProgress.start(p) / GenProgress.stop()) — jedna generacja naraz. Bez aktywnego obiektu
## wszystkie wywołania to no-op, więc testy i podgląd działają bez zmian.
##
## Bezpieczne wątkowo: generator pisze z wątku roboczego, pasek czyta z głównego (fraction/label).

## Kolejność etapów i ich wagi ≈ czas etapu w ms / 10 (pełna ścieżka gry 250×250 z płaskowyżami).
## Etap spoza listy nie przesuwa paska, ale jego czas jest mierzony.
## Kalibracja 2026-09-30: seed 184356, średnia z dwóch przebiegów (Godot 4.7.2 headless). Pasek i tak
## dopasowuje tempo w trakcie, więc wagi muszą być tylko w dobrych proporcjach.
const STAGES: Array = [
	[&"rooms", 4.0, "Kopanie komnat"],
	[&"corridors", 5.0, "Łączenie korytarzy"],
	[&"smoothing", 66.0, "Wygładzanie ścian"],
	[&"connectivity", 5.0, "Sprawdzanie przejść"],
	[&"portals", 35.0, "Wejście i wyjście"],
	[&"plateaus", 74.0, "Wznoszenie płaskowyżów"],
	[&"plateau_stairs", 124.0, "Schody na płaskowyże"],
	[&"terrain", 36.0, "Błoto i trawa"],
	[&"objects", 82.0, "Rozmieszczanie obiektów"],
	[&"spawns", 1.0, "Rozmieszczanie potworów"],
	[&"edges", 304.0, "Analiza krawędzi"],
	[&"rock", 174.0, "Lita skała"],
	[&"floor", 72.0, "Podłoga"],
	[&"walls", 40.0, "Ściany"],
	[&"plateau_tiles", 299.0, "Płaskowyże"],
	[&"navmesh", 20.0, "Ścieżki przeciwników"],
	[&"paint", 75.0, "Układanie kafli"],
	[&"entities", 5.0, "Potwory i skrzynie"],
	[&"props", 333.0, "Ustawianie obiektów"],
	[&"navigation", 1.0, "Nawigacja"],
]

## Pasek sam przesuwa się w obrębie etapu (także bez sub()) według oczekiwanego czasu etapu: liniowo do
## CREEP_LINEAR szerokości etapu w oczekiwanym czasie, potem coraz wolniej do CREEP_MAX — nigdy za
## koniec etapu. Oczekiwany czas = waga × tempo (ms na jednostkę wagi); tempo startuje od
## `ms_per_weight` (wywołujący skaluje je rozmiarem mapy) i dopasowuje się do zmierzonych etapów.
const CREEP_LINEAR := 0.8
const CREEP_MAX := 0.95
## Najdalej, dokąd w etapie dochodzi sub() — resztę dokłada end().
const SUB_MAX := 0.95
## Pasek przed finish() — 100% tylko na koniec całości.
const BEFORE_FINISH := 0.99
## Ile jednostek wagi „waży” początkowe tempo przy uśrednianiu z pomiarem.
const PRIOR_WEIGHT := 40.0

static var _active = null  # aktywny obiekt tego skryptu

var _mutex := Mutex.new()
var _base := {}          # etap -> suma wag etapów przed nim (0..1)
var _weight := {}        # etap -> waga (0..1)
var _labels := {}        # etap -> opis dla gracza
var _fraction := 0.0
var _stage: StringName = &""
var _stage_start_usec := 0
var _start_usec := 0
var times := {}          # etap -> łączny czas w µs (etapy mogą się powtarzać)
var _raw := {}           # etap -> waga z STAGES (jednostki ≈ 10 ms przy 250×250)
## Początkowe tempo (ms na jednostkę wagi) — 10 przy 250×250; wywołujący skaluje rozmiarem mapy.
var ms_per_weight := 10.0
var _done_w := 0.0       # suma wag zakończonych etapów z listy
var _done_ms := 0.0      # ich zmierzony czas
var _last_stage: StringName = &""  # etap do opisu między end() a kolejnym begin()
var _finished := false
var order: Array[StringName] = []  # etapy w kolejności pierwszego wystąpienia


func _init() -> void:
	var total := 0.0
	for s in STAGES:
		total += float(s[1])
	var acc := 0.0
	for s in STAGES:
		_base[s[0]] = acc / total
		_weight[s[0]] = float(s[1]) / total
		_labels[s[0]] = s[2]
		_raw[s[0]] = float(s[1])
		acc += float(s[1])
	_start_usec = Time.get_ticks_usec()
	_stage_start_usec = _start_usec


# --- API generatora (statyczne, no-op bez aktywnego obiektu) ------------------------------

static func start(p) -> void:
	_active = p


static func stop() -> void:
	if _active != null:
		_active._close_stage()
	_active = null


static func current():
	return _active


## Początek etapu: zamyka poprzedni (czas) i przesuwa pasek na początek etapu.
static func begin(stage: StringName) -> void:
	var p = _active
	if p != null:
		p._begin(stage)


## Koniec etapu: pasek na koniec etapu, zamknięty pomiar czasu. `stage` inny niż bieżący = no-op
## (pusty = bieżący, np. po PlateauPass.run, który kończy się w plateaus albo plateau_stairs).
static func end(stage: StringName = &"") -> void:
	var p = _active
	if p != null and (stage == &"" or p._stage == stage):
		p._end()


## Postęp wewnątrz bieżącego etapu (0..1).
static func sub(frac: float) -> void:
	var p = _active
	if p != null:
		p._sub(frac)


## Postęp etapu `stage`, tylko gdy to on trwa — dla kodu wołanego też z innych etapów (EdgeAnalyzer
## i placery działają również w oknach płaskowyżów, w etapie plateau_tiles).
static func sub_in(stage: StringName, frac: float) -> void:
	var p = _active
	if p != null and p._stage == stage:
		p._sub(frac)


# --- Odczyt (główny wątek) -----------------------------------------------------------------

func fraction() -> float:
	_mutex.lock()
	var f := _fraction
	if _base.has(_stage):
		var expected_ms: float = maxf(float(_raw[_stage]) * _tempo(), 1.0)
		var t := (Time.get_ticks_usec() - _stage_start_usec) / 1000.0 / expected_ms
		var k := CREEP_LINEAR * t if t < 1.0 else CREEP_LINEAR + (CREEP_MAX - CREEP_LINEAR) * (1.0 - exp(1.0 - t))
		f = maxf(f, float(_base[_stage]) + float(_weight[_stage]) * k)
	if not _finished:
		f = minf(f, BEFORE_FINISH)
	_mutex.unlock()
	return f


func label() -> String:
	_mutex.lock()
	var l: String = _labels.get(_stage if _stage != &"" else _last_stage, "")
	_mutex.unlock()
	return l


## Zakończenie całości: pasek na 100%.
func finish() -> void:
	_close_stage()
	_mutex.lock()
	_fraction = 1.0
	_finished = true
	_stage = &""
	_mutex.unlock()


## Tabela czasów etapów (ms) — do profilu w testach.
func report() -> String:
	var lines := PackedStringArray()
	var total := 0
	for st in order:
		total += int(times[st])
	for st in order:
		lines.append("  %-16s %7.1f ms  %5.1f%%" % [st, times[st] / 1000.0, 100.0 * times[st] / maxf(total, 1)])
	lines.append("  %-16s %7.1f ms" % ["RAZEM", total / 1000.0])
	return "\n".join(lines)


# --- Wewnętrzne ----------------------------------------------------------------------------

func _begin(stage: StringName) -> void:
	_close_stage()
	_mutex.lock()
	_stage = stage
	_last_stage = stage
	_stage_start_usec = Time.get_ticks_usec()
	if not times.has(stage):
		times[stage] = 0
		order.append(stage)
	if _base.has(stage):
		_fraction = maxf(_fraction, float(_base[stage]))
	_mutex.unlock()


func _sub(frac: float) -> void:
	_mutex.lock()
	if _base.has(_stage):
		_fraction = maxf(_fraction, float(_base[_stage]) + float(_weight[_stage]) * SUB_MAX * clampf(frac, 0.0, 1.0))
	_mutex.unlock()


func _end() -> void:
	_mutex.lock()
	if _base.has(_stage):
		_fraction = maxf(_fraction, float(_base[_stage]) + float(_weight[_stage]))
	_mutex.unlock()
	_close_stage()


func _close_stage() -> void:
	_mutex.lock()
	if _stage != &"":
		var us := Time.get_ticks_usec() - _stage_start_usec
		times[_stage] = int(times.get(_stage, 0)) + us
		if _raw.has(_stage):
			_done_w += float(_raw[_stage])
			_done_ms += us / 1000.0
	_stage = &""
	_mutex.unlock()


## Tempo tej generacji (ms na jednostkę wagi): początkowe, uśrednione z pomiarem zakończonych etapów.
## Wołać pod muteksem.
func _tempo() -> float:
	return (ms_per_weight * PRIOR_WEIGHT + _done_ms) / (PRIOR_WEIGHT + _done_w)
