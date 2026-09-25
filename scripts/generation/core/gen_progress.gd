extends RefCounted

## Znaczniki etapów generowania mapy: postęp dla paska ładowania + czas etapów (profil).
##
## Kod generatora woła statyczne GenProgress.begin(&"etap") na początku etapu i opcjonalnie
## GenProgress.sub(0..1) wewnątrz długich pętli. Aktywny obiekt ustawia wywołujący
## (GenProgress.start(p) / GenProgress.stop()) — jedna generacja naraz. Bez aktywnego obiektu
## wszystkie wywołania to no-op, więc testy i podgląd działają bez zmian.
##
## Bezpieczne wątkowo: generator pisze z wątku roboczego, pasek czyta z głównego (fraction/label).

## Kolejność etapów i ich wagi ≈ czas etapu w ms / 10 (pełna ścieżka gry 250×250 z płaskowyżami,
## tests/diag_async_stages.gd). Etap spoza listy nie przesuwa paska, ale jego czas jest mierzony.
## "entities" jest duże przez odtwarzanie sceny slime_tutorial przy każdej instancji (ostrzeżenie
## „re-save this scene”) — po jej ponownym zapisie w edytorze wagę można zmniejszyć.
const STAGES: Array = [
	[&"rooms", 1.0, "Kopanie komnat"],
	[&"corridors", 2.0, "Łączenie korytarzy"],
	[&"smoothing", 41.0, "Wygładzanie ścian"],
	[&"connectivity", 3.0, "Sprawdzanie przejść"],
	[&"portals", 15.0, "Wejście i wyjście"],
	[&"plateaus", 28.0, "Wznoszenie płaskowyżów"],
	[&"objects", 10.0, "Rozmieszczanie obiektów"],
	[&"spawns", 0.5, "Rozmieszczanie potworów"],
	[&"edges", 62.0, "Analiza krawędzi"],
	[&"rock", 34.0, "Lita skała"],
	[&"floor", 22.0, "Podłoga"],
	[&"walls", 17.0, "Ściany"],
	[&"plateau_tiles", 38.0, "Płaskowyże"],
	[&"paint", 34.0, "Układanie kafli"],
	[&"entities", 104.0, "Potwory i skrzynie"],
	[&"navigation", 1.0, "Nawigacja"],
]

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


## Postęp wewnątrz bieżącego etapu (0..1).
static func sub(frac: float) -> void:
	var p = _active
	if p != null:
		p._sub(frac)


# --- Odczyt (główny wątek) -----------------------------------------------------------------

func fraction() -> float:
	_mutex.lock()
	var f := _fraction
	_mutex.unlock()
	return f


func label() -> String:
	_mutex.lock()
	var l: String = _labels.get(_stage, "")
	_mutex.unlock()
	return l


## Zakończenie całości: pasek na 100%.
func finish() -> void:
	_close_stage()
	_mutex.lock()
	_fraction = 1.0
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
		_fraction = maxf(_fraction, float(_base[_stage]) + float(_weight[_stage]) * clampf(frac, 0.0, 1.0))
	_mutex.unlock()


func _close_stage() -> void:
	_mutex.lock()
	if _stage != &"":
		times[_stage] = int(times.get(_stage, 0)) + Time.get_ticks_usec() - _stage_start_usec
	_stage = &""
	_mutex.unlock()
