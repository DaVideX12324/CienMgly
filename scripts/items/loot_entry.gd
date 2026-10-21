@tool
class_name QuizRpgLootEntry
extends Resource

## Wpis tabeli łupu (QuizRpgLootTableData, plik .tres): przedmiot, waga losowania i liczba sztuk (od–do).

@export var item: QuizRpgItemData
## Waga losowania względem innych wpisów listy (0 = nigdy).
@export_range(0.0, 1000.0, 1.0) var weight: float = 10.0
@export_range(1, 99, 1) var count_min: int = 1
@export_range(1, 99, 1) var count_max: int = 1


## Liczba sztuk wpisu tabeli: count_min..count_max, albo count (tabele z JSON), albo 1.
static func roll_count(entry: Dictionary, rng: RandomNumberGenerator = null) -> int:
	if entry.has("count_min"):
		var lo := maxi(int(entry["count_min"]), 1)
		var hi := maxi(int(entry.get("count_max", lo)), lo)
		return rng.randi_range(lo, hi) if rng else randi_range(lo, hi)
	return maxi(int(entry.get("count", 1)), 1)
