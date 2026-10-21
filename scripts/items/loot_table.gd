class_name QuizRpgLootTable
extends RefCounted

## Losowanie z tabel łupu (słowniki z QuizRpgLootTableData.to_table albo listy z JSON nisz / skarbu): skrzynie i beczki —
## jeden wpis wybierany wagowo, wrogowie — każdy wpis osobno ze swoją szansą. Wpis bez count = 1 sztuka.


## Jeden wpis wybrany wagowo (weight; brak = 1) albo {} dla pustej tabeli.
static func pick_weighted(entries: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var total := 0.0
	for e in entries:
		total += maxf(float((e as Dictionary).get("weight", 1.0)), 0.0)
	if total <= 0.0:
		return {}
	var roll := (rng.randf() if rng else randf()) * total
	var cursor := 0.0
	for e in entries:
		cursor += maxf(float((e as Dictionary).get("weight", 1.0)), 0.0)
		if roll < cursor:
			return e
	return entries[entries.size() - 1]


## Wpisy, które wypadły: każdy osobno z szansą chance (0–1).
static func roll_chances(entries: Array, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if (rng.randf() if rng else randf()) < float((e as Dictionary).get("chance", 0.0)):
			out.append(e)
	return out
