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


func is_empty() -> bool:
	return mask.is_empty()


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
