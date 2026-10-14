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
const MAX_MS := 100.0

var _budget_us := int(MIN_MS * 1000.0)
var _slice_start := 0


func _init() -> void:
	_slice_start = Time.get_ticks_usec()


## Czy kawałek przekroczył budżet (czas oddać klatkę).
func due() -> bool:
	return Time.get_ticks_usec() - _slice_start >= _budget_us


## Czeka jedną klatkę i ustawia budżet następnego kawałka na czas tego czekania.
func next_frame(tree: SceneTree) -> void:
	var t := Time.get_ticks_usec()
	await tree.process_frame
	var now := Time.get_ticks_usec()
	_budget_us = clampi(now - t, int(MIN_MS * 1000.0), int(MAX_MS * 1000.0))
	_slice_start = now
