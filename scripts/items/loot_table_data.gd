@tool
class_name QuizRpgLootTableData
extends Resource

## Tabela łupu jako plik .tres (resources/loot/): lista wpisów QuizRpgLootEntry (przedmiot, waga, liczba sztuk od–do, szansa).
## Podpinana w Inspectorze pod beczkę / skrzynię / wroga (pole loot_data) albo pod strefę w JSON mapy ("barrel_loot" /
## "chest_loot": ścieżka do .tres, "enemy_loot": tier -> ścieżka) — jedną tabelę łatwo przenieść między obiektami
## i podmienić dla innej strefy. Beczki i skrzynie losują wpis wagowo, wrogowie każdy wpis osobno z jego szansą.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

@export var entries: Array[QuizRpgLootEntry] = []

@export_group("Beczka: szanse")
## Szansa na n-ty przedmiot z beczki, gdy wypadły poprzednie: [0] = 1. przedmiot, [1] = 2. … Liczba wartości = maks. liczba
## przedmiotów. Domyślnie wzór min(1, 1,5 / n): 100 / 75 / 50 / 37,5 / 30 / 25 / 21,4 / 18,75 %.
@export var item_chances: PackedFloat32Array = PackedFloat32Array([1.0, 0.75, 0.5, 0.375, 0.3, 0.25, 0.2143, 0.1875])
## Szansa na kolejną sztukę wpisu ponad count_min (do count_max), gdy wypadły poprzednie: [0] = 2. sztuka, [1] = 3. …
## Brak wartości = koniec. Domyślnie wzór min(1, 1 / k): 50 / 33,3 / 25 / 20 %.
@export var amount_chances: PackedFloat32Array = PackedFloat32Array([0.5, 0.3333, 0.25, 0.2])


## Tabela słowników {item_id, weight, count_min, count_max, chance} (wpisy bez przedmiotu pomijane).
func to_table() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for le in entries:
		if le == null or le.item == null or le.item.item_id == "":
			continue
		out.append({"item_id": le.item.item_id, "weight": le.weight, "count_min": le.count_min,
			"count_max": maxi(le.count_max, le.count_min), "chance": le.chance})
	return out


## Ile kolejnych prób z listy szans się udało (n-ta tylko, gdy udały się poprzednie).
static func roll_chain(chances: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var n := 0
	while n < chances.size() and rng.randf() < chances[n]:
		n += 1
	return n


## Liczba sztuk wpisu: count_min, potem kolejne do count_max wg amount_chances ([0] = 2. sztuka).
func roll_amount(lo: int, hi: int, rng: RandomNumberGenerator) -> int:
	var n := maxi(lo, 1)
	while n < hi and n - 1 < amount_chances.size() and rng.randf() < amount_chances[n - 1]:
		n += 1
	return n


## Szanse ze wzoru min(1, scale / n) dla n = 1..count (np. metadane "barrel_loot" rodzica beczek: {scale, max_items}).
static func scale_chances(scale: float, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n in range(1, maxi(count, 1) + 1):
		out.append(minf(1.0, scale / float(n)))
	return out


## Tabela z wartości JSON mapy: ścieżka do .tres (res:// albo względem modułu) -> zasób; inna wartość / brak pliku -> null.
static func from_json(value: Variant) -> QuizRpgLootTableData:
	if not (value is String) or String(value) == "":
		return null
	var path := String(value) if String(value).begins_with("res://") else QuizRpgPaths.path(String(value))
	return load(path) as QuizRpgLootTableData if ResourceLoader.exists(path) else null
