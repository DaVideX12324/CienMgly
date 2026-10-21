@tool
class_name QuizRpgLootTableData
extends Resource

## Tabela łupu jako plik .tres (resources/loot/): lista wpisów QuizRpgLootEntry (przedmiot, waga, liczba sztuk od–do).
## Podpinana w Inspectorze pod beczkę / skrzynię (pole loot_data) albo pod strefę w JSON mapy ("barrel_loot" /
## "chest_loot": ścieżka do .tres) — jedną tabelę łatwo przenieść między obiektami i podmienić dla innej strefy.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

@export var entries: Array[QuizRpgLootEntry] = []


## Tabela słowników {item_id, weight, count_min, count_max} (wpisy bez przedmiotu pomijane).
func to_table() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for le in entries:
		if le == null or le.item == null or le.item.item_id == "":
			continue
		out.append({"item_id": le.item.item_id, "weight": le.weight, "count_min": le.count_min,
			"count_max": maxi(le.count_max, le.count_min)})
	return out


## Tabela z wartości JSON mapy: ścieżka do .tres (res:// albo względem modułu) -> zasób; inna wartość / brak pliku -> null.
static func from_json(value: Variant) -> QuizRpgLootTableData:
	if not (value is String) or String(value) == "":
		return null
	var path := String(value) if String(value).begins_with("res://") else QuizRpgPaths.path(String(value))
	return load(path) as QuizRpgLootTableData if ResourceLoader.exists(path) else null
