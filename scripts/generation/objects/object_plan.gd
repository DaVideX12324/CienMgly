class_name ObjectPlan
extends RefCounted

## Wynik ObjectPlannera — czyste dane (bez węzłów), liczone w wątku roboczym. ObjectRealizer robi
## z nich kafle / canvas items / sceny na głównym wątku.

const FORBID := 1     # ściana, bariera/stopa lica, schody (+1), portal (+2), spawn — nic nie stoi
const RESERVED := 2   # zarezerwowane przejście — tylko obiekty bez kolizji
const SOLID := 4      # zajęte przez obiekt z kolizją
const USED := 8       # zajęte przez dowolny obiekt (jeden obiekt na kratkę)

var width := 0
var height := 0
var placements: Array[ObjectPlacement] = []
var occupancy := PackedByteArray()
var stats := {}           # id obiektu -> liczba
var removed_for_reach := 0  # przeszkody zdjęte, bo odcinały teren
var time_usec := 0
var interactive_scenes := {}  # sceny INTERACTIVE z katalogu (np. &"chest") — kto inny ich nie stawia


func count(def_id: StringName) -> int:
	return int(stats.get(def_id, 0))


## Kratki zajęte przez obiekty z kolizją (Vector2i -> true) — dla spawnów wrogów.
func solid_cells() -> Dictionary:
	var out := {}
	for i in range(occupancy.size()):
		if occupancy[i] & SOLID:
			out[Vector2i(i % width, i / width)] = true
	return out


## Postawione obiekty ze sceną `scene` (alias albo ścieżka) — np. skrzynie dla podglądu.
func cells_with_scene(scene: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in placements:
		if p.def.scene == scene:
			out.append(p.cell)
	return out


## Odcisk planu (testy determinizmu / parytet).
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for p in placements:
		ctx.update(("%s %d %d %.2f %.2f %d %d\n" % [p.def.id, p.cell.x, p.cell.y, p.offset.x, p.offset.y, p.variant, int(p.flip)]).to_utf8_buffer())
	return ctx.finish().hex_encode()
