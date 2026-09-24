class_name ObjectDef
extends RefCounted

## Definicja obiektu z katalogu (JSON: grupa + obiekt, scalone w ObjectCatalog). Czyste dane —
## ObjectPlanner decyduje, gdzie stoi, ObjectRealizer — jak powstaje (kafel / canvas item / scena).
##
## Pozycja obiektu: kratka kotwicy `cell` = lewa-dolna kratka podstawy (footprintu). Punkt obiektu
## w px (y-sort, kolizja, scena) = środek dolnej krawędzi podstawy (+ przesunięcie jitter/free).

enum Klass { DECAL, PROP, INTERACTIVE }
enum Placement { GRID, GRID_JITTER, FREE }
enum Collision { NONE, TILE, SHAPE, SCENE }

const CELL := 16

var id: StringName = &""
var group: StringName = &""
var klass: Klass = Klass.DECAL
var placement: Placement = Placement.GRID
var jitter_px: float = 4.0            # grid_jitter: maks. przesunięcie w każdej osi
var spacing: int = 1                  # grid/grid_jitter: min. odstęp kotwic tego obiektu (kratki, Chebyshev)
var spacing_px: float = 16.0          # free: min. odstęp punktów tego obiektu (px)
var density: float = 0.0              # sztuk na 100 kratek-kandydatów
var count_min: int = -1               # count: [min, max] — stała liczba zamiast gęstości (-1 = gęstość)
var count_max: int = -1
var atlas: Array[Vector2i] = []       # warianty grafiki (atlas coords w TileSecie poziomu)
var size := Vector2i.ONE              # rozmiar sprite'a w kratkach (w × h), dół = wiersz kotwicy
var footprint: Array[Vector2i] = []   # kratki podstawy względem kotwicy (y <= 0)
var scene: String = ""                # INTERACTIVE: ścieżka res:// albo alias (np. "chest")
var collision: Collision = Collision.NONE
var shape_rect := Vector2.ZERO        # kształt kolizji (px): prostokąt w × h …
var shape_radius: float = 0.0         # … albo koło
var shape_offset := Vector2.ZERO      # przesunięcie kształtu względem punktu obiektu
var context: Array[StringName] = []   # tagi kontekstu — wystarczy jeden (OR); pusto = bez wymagań
var avoid: Array[StringName] = []     # tagi wykluczające
var levels: Array[StringName] = []    # "ground" / "plateau" / "pit"; pusto = każda wysokość
var cluster_min: int = 0              # cluster: {"size": [a, b], "radius": r} — skupiska
var cluster_max: int = 0
var cluster_radius: int = 0
var keep_paths: bool = true           # z kolizją: nie na zarezerwowanych przejściach
var priority: int = 0                 # większy = rozmieszczany wcześniej
var flip_h: bool = false              # losowe odbicie (canvas item / scena)
var order: int = 0                    # kolejność w pliku (remisy priorytetu)


func is_solid() -> bool:
	return collision != Collision.NONE


func footprint_size() -> Vector2i:
	var mx := 0
	var my := 0
	for f in footprint:
		mx = maxi(mx, f.x)
		my = maxi(my, -f.y)
	return Vector2i(mx + 1, my + 1)


## Punkt obiektu (px) dla kotwicy `cell`: środek dolnej krawędzi podstawy.
func base_point(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + footprint_size().x * 0.5) * CELL, (cell.y + 1) * CELL)


## Czy obiekt rysowany jest kaflem (siatka + grafika z atlasu), a nie canvas itemem / sceną.
func renders_as_tile() -> bool:
	return klass != Klass.INTERACTIVE and placement == Placement.GRID and not atlas.is_empty()
