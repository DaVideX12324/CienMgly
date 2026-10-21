@tool
class_name QuizRpgLootEntry
extends Resource

## Wpis tabeli łupu ustawiany w Inspectorze (beczki, skrzynie — pole loot_entries): przedmiot, waga losowania i liczba
## sztuk (od–do). Lista wpisów na konkretnej beczce / skrzyni ma pierwszeństwo przed tabelą z JSON mapy i domyślną.

@export var item: QuizRpgItemData
## Waga losowania względem innych wpisów listy (0 = nigdy).
@export_range(0.0, 1000.0, 1.0) var weight: float = 10.0
@export_range(1, 99, 1) var count_min: int = 1
@export_range(1, 99, 1) var count_max: int = 1


## Lista wpisów -> tabela słowników {item_id, weight, count_min, count_max} (wpisy bez przedmiotu pomijane).
static func to_table(entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		var le := e as QuizRpgLootEntry
		if le == null or le.item == null or le.item.item_id == "":
			continue
		out.append({"item_id": le.item.item_id, "weight": le.weight, "count_min": le.count_min,
			"count_max": maxi(le.count_max, le.count_min)})
	return out


## Liczba sztuk wpisu tabeli: count_min..count_max, albo count (tabele z JSON), albo 1.
static func roll_count(entry: Dictionary, rng: RandomNumberGenerator = null) -> int:
	if entry.has("count_min"):
		var lo := maxi(int(entry["count_min"]), 1)
		var hi := maxi(int(entry.get("count_max", lo)), lo)
		return rng.randi_range(lo, hi) if rng else randi_range(lo, hi)
	return maxi(int(entry.get("count", 1)), 1)
