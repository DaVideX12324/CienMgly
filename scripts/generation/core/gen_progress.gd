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

## Opisy etapów dla gracza. Etap spoza tabeli wag układu nie przesuwa paska, ale jego czas jest mierzony.
const LABELS := {
	&"rooms": "Kopanie komnat",
	&"corridors": "Łączenie korytarzy",
	&"smoothing": "Wygładzanie ścian",
	&"connectivity": "Sprawdzanie przejść",
	&"portals": "Wejście i wyjście",
	&"plateaus": "Wznoszenie płaskowyżów",
	&"plateau_stairs": "Schody na płaskowyże",
	&"terrain": "Błoto i trawa",
	&"objects": "Rozmieszczanie obiektów",
	&"spawns": "Rozmieszczanie potworów",
	&"edges": "Analiza krawędzi",
	&"rock": "Lita skała",
	&"floor": "Podłoga",
	&"walls": "Ściany",
	&"plateau_tiles": "Płaskowyże",
	&"navmesh": "Ścieżki przeciwników",
	&"paint": "Układanie kafli",
	&"entities": "Potwory i skrzynie",
	&"props": "Ustawianie obiektów",
	&"navigation": "Nawigacja",
}

## Wagi etapów per układ mapy (GenerationFlags.layout), w kolejności wykonania: [etap, ms przy 250×250, wykładnik].
## Oczekiwany czas etapu = ms × (pole / 250²)^wykładnik — etapy rosną z polem różnie (korytarze ścieków ~pole^1,5).
## Kalibracja 2026-10-16: pełna ścieżka gry, seed 119, 160² / 250² / 500², dopasowanie w skali log (Godot 4.7.2
## headless). Tempo maszyny pasek dopasowuje w trakcie, więc wagi muszą być tylko w dobrych proporcjach.
const WEIGHTS := {
	"interior": [
		[&"rooms", 11.0, 1.04], [&"corridors", 22.0, 1.0], [&"smoothing", 140.0, 0.96], [&"connectivity", 24.0, 1.0],
		[&"portals", 91.0, 0.97], [&"plateaus", 209.0, 1.03], [&"plateau_stairs", 383.0, 1.33], [&"terrain", 198.0, 0.67],
		[&"objects", 352.0, 1.11], [&"spawns", 53.0, 1.05], [&"edges", 423.0, 1.03], [&"rock", 275.0, 1.01],
		[&"floor", 184.0, 0.98], [&"walls", 158.0, 0.99], [&"plateau_tiles", 498.0, 1.01], [&"navmesh", 66.0, 0.95],
		[&"paint", 183.0, 0.99], [&"entities", 41.0, 1.2], [&"props", 17.0, 1.17], [&"navigation", 1.0, 0.7],
	],
	"structured": [
		[&"rooms", 216.0, 1.35], [&"corridors", 918.0, 1.53], [&"portals", 5.0, 1.5], [&"smoothing", 462.0, 1.19],
		[&"plateaus", 143.0, 1.1], [&"terrain", 2.0, 0.0], [&"objects", 798.0, 1.25], [&"spawns", 58.0, 0.5],
		[&"edges", 427.0, 1.02], [&"rock", 220.0, 1.07], [&"floor", 527.0, 0.93], [&"walls", 238.0, 0.93],
		[&"plateau_tiles", 122.0, 1.33], [&"navmesh", 54.0, 0.94], [&"paint", 367.0, 1.13], [&"entities", 29.0, 0.92],
		[&"props", 79.0, 0.0], [&"navigation", 1.0, 0.7],
	],
}

## Kroki wewnątrz długich etapów (GenProgress.step) — [krok, ms przy 250×250, wykładnik] jak WEIGHTS; pasek idzie
## krok po kroku zamiast stać przez cały etap. Klucz: "układ:etap".
const STEPS := {
	"structured:corridors": [
		[&"service_corridors", 98.0, 1.33], [&"lane_gaps", 23.0, 0.0], [&"rooms", 65.0, 0.92],
		[&"room_links", 169.0, 1.63], [&"complex_loops", 74.0, 2.23], [&"attached_rooms", 3.0, 1.0],
		[&"segment_bridges", 65.0, 0.37], [&"repair", 188.0, 1.48], [&"drop_redundant_bridges", 10.0, 0.92],
	],
}

## Pasek sam przesuwa się w obrębie etapu (także bez sub()) według oczekiwanego czasu etapu: liniowo do
## CREEP_LINEAR szerokości etapu w oczekiwanym czasie, potem coraz wolniej do CREEP_MAX — nigdy za
## koniec etapu (kroku, gdy etap ma kroki). Oczekiwany czas = waga × tempo; tempo startuje od ms_per_weight (wagi
## są w ms) i dopasowuje się do zmierzonych etapów (wolniejsza maszyna = wolniejsze tempo).
const CREEP_LINEAR := 0.8
const CREEP_MAX := 0.95
## Najdalej, dokąd w etapie dochodzi sub() — resztę dokłada end().
const SUB_MAX := 0.95
## Pasek przed finish() — 100% tylko na koniec całości.
const BEFORE_FINISH := 0.99
## Ile ms wagi „waży” początkowe tempo przy uśrednianiu z pomiarem.
const PRIOR_WEIGHT := 400.0

static var _active = null  # aktywny obiekt tego skryptu
## Wątek -> zadanie generowania (obiekt z polem `progress`): wątek z wpisem raportuje do progress swojego zadania
## (null = nikomu — generowanie mapy z wyprzedzeniem nie rusza paska bieżącej mapy), wątek bez wpisu do _active.
static var _bound := {}
static var _bind_mutex := Mutex.new()

var _mutex := Mutex.new()
var _base := {}          # etap -> suma wag etapów przed nim (0..1)
var _weight := {}        # etap -> waga (0..1)
var _labels := {}        # etap -> opis dla gracza
var _fraction := 0.0
var _stage: StringName = &""
var _stage_start_usec := 0
var _start_usec := 0
var times := {}          # etap -> łączny czas w µs (etapy mogą się powtarzać)
var _raw := {}           # etap -> oczekiwany czas (ms) dla układu i rozmiaru mapy (configure)
var _layout := "interior"
var _area_k := 1.0       # pole mapy / 250²
## Początkowe tempo (ms rzeczywiste na ms wagi).
var ms_per_weight := 1.0
var _steps := {}         # etap -> {krok: [początek, długość]} (ułamki etapu)
var _step_base := 0.0    # bieżący krok: początek i długość w etapie (długość 0 = bez kroku)
var _step_len := 0.0
var _step_start_usec := 0
var _done_w := 0.0       # suma wag zakończonych etapów z listy
var _done_ms := 0.0      # ich zmierzony czas
var _last_stage: StringName = &""  # etap do opisu między end() a kolejnym begin()
var _finished := false
var order: Array[StringName] = []  # etapy w kolejności pierwszego wystąpienia


func _init() -> void:
	_labels = LABELS
	configure("interior", 250, 250)
	_start_usec = Time.get_ticks_usec()
	_stage_start_usec = _start_usec


## Wagi etapów dla układu mapy ("interior" = jaskinia, "structured" = ścieki) i jej rozmiaru. Wołać przed start().
func configure(layout: String, width: int, height: int) -> void:
	_layout = layout if WEIGHTS.has(layout) else "interior"
	_area_k = maxf(float(width * height), 1.0) / (250.0 * 250.0)
	_base.clear()
	_weight.clear()
	_raw.clear()
	var total := 0.0
	for row in WEIGHTS[_layout]:
		_raw[row[0]] = _expected(row)
		total += _raw[row[0]]
	var acc := 0.0
	for row in WEIGHTS[_layout]:
		_base[row[0]] = acc / total
		_weight[row[0]] = _raw[row[0]] / total
		acc += _raw[row[0]]
	_steps.clear()
	for key: String in STEPS:
		if not key.begins_with(_layout + ":"):
			continue
		var steps := {}
		var sum := 0.0
		for row in STEPS[key]:
			sum += _expected(row)
		var at := 0.0
		for row in STEPS[key]:
			var part := _expected(row) / sum
			steps[row[0]] = [at, part]
			at += part
		_steps[StringName(key.get_slice(":", 1))] = steps


func _expected(row: Array) -> float:
	return float(row[1]) * pow(_area_k, float(row[2]))


# --- API generatora (statyczne, no-op bez aktywnego obiektu) ------------------------------

static func start(p) -> void:
	_active = p


static func stop() -> void:
	if _active != null:
		_active._close_stage()
	_active = null


## Bieżący wątek raportuje do `holder.progress` (GenJob.run w wątku roboczym); unbind() po zakończeniu.
static func bind(holder) -> void:
	_bind_mutex.lock()
	_bound[OS.get_thread_caller_id()] = holder
	_bind_mutex.unlock()


static func unbind() -> void:
	_bind_mutex.lock()
	_bound.erase(OS.get_thread_caller_id())
	_bind_mutex.unlock()


## Podpina pasek pod zadanie, które już liczy w tle (mapa z wyprzedzeniem, na którą gracz właśnie wchodzi).
static func set_holder_progress(holder, p) -> void:
	_bind_mutex.lock()
	holder.progress = p
	_bind_mutex.unlock()


static func _for_caller():
	_bind_mutex.lock()
	var p = _active
	var tid := OS.get_thread_caller_id()
	if _bound.has(tid):
		var h = _bound[tid]
		p = h.progress if h != null else null
	_bind_mutex.unlock()
	return p


static func current():
	return _active


## Początek etapu: zamyka poprzedni (czas) i przesuwa pasek na początek etapu.
static func begin(stage: StringName) -> void:
	var p = _for_caller()
	if p != null:
		p._begin(stage)


## Koniec etapu: pasek na koniec etapu, zamknięty pomiar czasu. `stage` inny niż bieżący = no-op
## (pusty = bieżący, np. po PlateauPass.run, który kończy się w plateaus albo plateau_stairs).
static func end(stage: StringName = &"") -> void:
	var p = _for_caller()
	if p != null and (stage == &"" or p._stage == stage):
		p._end()


## Początek kroku bieżącego etapu (tabela STEPS) — pasek na początek kroku i płynie w nim wg jego wagi.
## Krok spoza tabeli = no-op.
static func step(step_name: StringName) -> void:
	var p = _for_caller()
	if p != null:
		p._step(step_name)


## Postęp wewnątrz bieżącego etapu (0..1).
static func sub(frac: float) -> void:
	var p = _for_caller()
	if p != null:
		p._sub(frac)


## Postęp etapu `stage`, tylko gdy to on trwa — dla kodu wołanego też z innych etapów (EdgeAnalyzer
## i placery działają również w oknach płaskowyżów, w etapie plateau_tiles).
static func sub_in(stage: StringName, frac: float) -> void:
	var p = _for_caller()
	if p != null and p._stage == stage:
		p._sub(frac)


# --- Odczyt (główny wątek) -----------------------------------------------------------------

func fraction() -> float:
	_mutex.lock()
	var f := _fraction
	if _base.has(_stage):
		var w: float = _weight[_stage]
		var expected_ms: float = maxf(float(_raw[_stage]) * _tempo(), 1.0)
		if _step_len > 0.0:
			var ts := (Time.get_ticks_usec() - _step_start_usec) / 1000.0 / maxf(expected_ms * _step_len, 1.0)
			f = maxf(f, float(_base[_stage]) + w * (_step_base + _step_len * _creep(ts)))
		else:
			var t := (Time.get_ticks_usec() - _stage_start_usec) / 1000.0 / expected_ms
			f = maxf(f, float(_base[_stage]) + w * _creep(t))
	if not _finished:
		f = minf(f, BEFORE_FINISH)
	_mutex.unlock()
	return f


func label() -> String:
	_mutex.lock()
	var st: StringName = _stage if _stage != &"" else _last_stage
	var l: String = _labels.get(st, "")
	_mutex.unlock()
	return QuizRpgI18n.t("gen.stage.%s" % st, l) if l != "" else l


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

## Ułamek drogi w etapie / kroku po czasie t (1 = oczekiwany czas): liniowo do CREEP_LINEAR, potem asymptotycznie.
static func _creep(t: float) -> float:
	return CREEP_LINEAR * t if t < 1.0 else CREEP_LINEAR + (CREEP_MAX - CREEP_LINEAR) * (1.0 - exp(1.0 - t))


func _step(step_name: StringName) -> void:
	_mutex.lock()
	var steps: Dictionary = _steps.get(_stage, {})
	if steps.has(step_name):
		_step_base = float(steps[step_name][0])
		_step_len = float(steps[step_name][1])
		_step_start_usec = Time.get_ticks_usec()
		_fraction = maxf(_fraction, float(_base[_stage]) + float(_weight[_stage]) * _step_base)
	_mutex.unlock()


func _begin(stage: StringName) -> void:
	_close_stage()
	_mutex.lock()
	_stage = stage
	_last_stage = stage
	_stage_start_usec = Time.get_ticks_usec()
	_step_len = 0.0
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
