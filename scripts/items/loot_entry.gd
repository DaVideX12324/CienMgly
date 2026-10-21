@tool
class_name QuizRpgLootEntry
extends Resource

## Wpis tabeli łupu (QuizRpgLootTableData, plik .tres): przedmiot, waga losowania, liczba sztuk (od–do) i szansa.

@export var item: QuizRpgItemData
## Waga losowania względem innych wpisów listy (0 = nigdy).
@export_range(0.0, 1000.0, 1.0) var weight: float = 10.0
@export_range(1, 99, 1) var count_min: int = 1
@export_range(1, 99, 1) var count_max: int = 1
## Szansa wypadnięcia (0–1) — tylko tabele wrogów, gdzie każdy wpis losowany osobno; beczki i skrzynie biorą wagę.
@export_range(0.0, 1.0, 0.001) var chance: float = 1.0


## Liczba sztuk wpisu tabeli (słownik z QuizRpgLootTableData.to_table): równomiernie count_min..count_max.
static func roll_count(entry: Dictionary, rng: RandomNumberGenerator = null) -> int:
	var lo := maxi(int(entry.get("count_min", 1)), 1)
	var hi := maxi(int(entry.get("count_max", lo)), lo)
	return rng.randi_range(lo, hi) if rng else randi_range(lo, hi)
