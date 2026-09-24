class_name PlateauLayout
extends RefCounted

## Płaskowyże mapy (jeden poziom) jako NAKŁADKA na podłogę — grid zostaje FLOOR.
## mask    — komórki podłogi płaskowyżu (M), renderowane przez PlateauRenderer.
## blocked — bariery logiczne (rimy, boki, lico i jego stopa) — spawny/BFS ich unikają.
## top     — chodliwa góra płaskowyżu.
## stairs  — schody w licu: Vector3i(x_start, width, top_y); stopa = top_y + 1.

var mask: Dictionary = {}
var blocked: Dictionary = {}
var top: Dictionary = {}
var stairs: Array[Vector3i] = []         # południowe schody w licu: Vector3i(x_start, width, top_y); stopa = top_y + 1
var stairs_north: Array[Vector3i] = []   # północne schody w rimie: Vector3i(x_start, width, rim_y); góra = rim_y - 1
var stairs_east: Array[Vector3i] = []    # wschodnie schody w boku: Vector3i(edge_x, top_y, height)
var stairs_west: Array[Vector3i] = []    # zachodnie schody w boku: Vector3i(edge_x, top_y, height)

# Mapa wysokości (pole szumu na całej mapie), z której wycięto płaskowyż — do podglądu.
# Odtwarzana przez PlateauPass.make_noise(noise_seed, noise_frequency) > threshold.
var noise_seed: int = 0
var noise_frequency: float = 0.0
var noise_octaves: int = 3
var threshold: float = 0.0
var noise_block: int = 1      # próbkowanie pola w blokach (PlateauPass.sample_height)
# Progi pasm pola (podgląd): poziom k >= 2 powyżej high_threshold + (k-2)·level_step, dół -j poniżej
# pit_threshold - (j-1)·level_step. level_count / pit_count = ile poziomów generator mógł zrobić.
var high_threshold: float = 0.0
var pit_threshold: float = 0.0
var level_step: float = 0.0
var level_count: int = 1
var pit_count: int = 0

# Pole wysokości (wielopoziomowe: płaskowyże 1, 2… i zagłębienia -1, -2…). Ziemia = 0.
# levels[k] = kratki o wysokości >= k dla k w (min_level, max_level]; levels[1] == mask.
# Dla k <= 0 poziom to „ziemia nad zagłębieniem” (cała podłoga poza dołem) — renderowany jak
# płaskowyż, którego krawędzie otaczają doły. heights: kratka -> wysokość (tylko != 0).
var levels: Dictionary = {}
var heights: Dictionary = {}
var min_level: int = 0
var max_level: int = 0

# Statystyki naprawy osiągalności (PlateauPass._solve) — diagnostyka i testy.
var connect_stairs: int = 0      # schody dodane, bo obszar był nieosiągalny (ponad budżet)
var dropped_pieces: int = 0      # płaskowyże usunięte: odcinały teren, a schodów nie dało się postawić
var unreachable_top: int = 0     # kratki góry bez dojścia (brak miejsca na schody) -> bariera


func is_empty() -> bool:
	return mask.is_empty() and min_level == 0


## Wysokość kratki (0 = ziemia; płaskowyż > 0, zagłębienie < 0).
func height_of(c: Vector2i) -> int:
	return int(heights.get(c, 0))


## Pary (góra, stopa) wszystkich schodów — jedyne przejścia między sąsiednimi wysokościami.
func stair_pairs() -> Array:
	var out: Array = []
	for st in stairs:
		for x in range(st.x, st.x + st.y):
			out.append([Vector2i(x, st.z), Vector2i(x, st.z + 1)])
	for st in stairs_north:
		for x in range(st.x, st.x + st.y):
			out.append([Vector2i(x, st.z), Vector2i(x, st.z - 1)])
	for st in stairs_east:
		for dy in range(st.z):
			out.append([Vector2i(st.x, st.y + dy), Vector2i(st.x + 1, st.y + dy)])
	for st in stairs_west:
		for dy in range(st.z):
			out.append([Vector2i(st.x, st.y + dy), Vector2i(st.x - 1, st.y + dy)])
	return out


## Komórki schodów (top i stopa) — chodliwe, łączą górę z ziemią.
func stair_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for st in stairs:
		for x in range(st.x, st.x + st.y):
			out.append(Vector2i(x, st.z))
			out.append(Vector2i(x, st.z + 1))
	for st in stairs_north:
		for x in range(st.x, st.x + st.y):
			out.append(Vector2i(x, st.z))
			out.append(Vector2i(x, st.z - 1))
	for st in stairs_east:
		for dy in range(st.z):
			out.append(Vector2i(st.x, st.y + dy))
			out.append(Vector2i(st.x + 1, st.y + dy))
	for st in stairs_west:
		for dy in range(st.z):
			out.append(Vector2i(st.x, st.y + dy))
			out.append(Vector2i(st.x - 1, st.y + dy))
	return out
