extends RefCounted

## Dzieli pracę na głównym wątku (kafle, encje, obiekty po wygenerowaniu mapy) na kawałki między
## klatkami według czasu, a nie liczby rzeczy — czas generowania nie zależy od FPS.
##
## Budżet kawałka = czas ostatniego czekania na klatkę (render, pasek ładowania), ale nie mniej niż
## MIN_MS i nie więcej niż MAX_MS: przy wolnych klatkach (podgląd z debuggerem, duża mapa) kawałki
## rosną, więc praca zajmuje najwyżej ~2× swój czas zamiast (liczba kawałków × czas klatki).
##
## Użycie: `if slicer.due(): await slicer.next_frame(tree)` w pętli. Nie zmienia wyniku — tylko
## rytm oddawania klatek.

const MIN_MS := 8.0
## Górny limit kawałka: po dużej porcji set_cell silnik przebudowuje warstwy w tej samej klatce (500x500 przy 100 ms
## dawało klatki 200-350 ms, przy 33 ~130 ms); niżej przy wolnych klatkach znów rośnie zależność od FPS.
const MAX_MS := 33.0

var _budget_us := int(MIN_MS * 1000.0)
var _slice_start := 0
var _fixed := false


## fixed_ms > 0: stały budżet kawałka (praca w tle w trakcie gry — np. zapis mapy z wyprzedzeniem — nie może
## zabierać klatce 8–33 ms jak na ekranie ładowania).
func _init(fixed_ms: float = 0.0) -> void:
	_slice_start = Time.get_ticks_usec()
	if fixed_ms > 0.0:
		_fixed = true
		_budget_us = int(fixed_ms * 1000.0)


## Czy kawałek przekroczył budżet (czas oddać klatkę).
func due() -> bool:
	return Time.get_ticks_usec() - _slice_start >= _budget_us


## Czeka jedną klatkę i ustawia budżet następnego kawałka na czas tego czekania.
func next_frame(tree: SceneTree) -> void:
	var t := Time.get_ticks_usec()
	await tree.process_frame
	var now := Time.get_ticks_usec()
	if not _fixed:
		_budget_us = clampi(now - t, int(MIN_MS * 1000.0), int(MAX_MS * 1000.0))
	_slice_start = now
