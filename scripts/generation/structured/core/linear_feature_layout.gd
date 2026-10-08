class_name LinearFeatureLayout
extends RefCounted

## Uniwersalna reprezentacja sieci cech liniowych (kanały, ulice, fosy, rzeki).
## Działa jako nakładka na siatkę - komórki podłogi i cech liniowych są koordynowane z rezerwacjami.

var feature_type: StringName = &"canal"

## Wszystkie komórki zajmowane przez sam element liniowy (np. woda, bruk ulicy)
var cells: Dictionary = {}  # Vector2i -> bool

## Pasy ruchu / chodniki wzdłuż elementu liniowego
var lanes: Dictionary = {}  # Vector2i -> bool

## Kładki / mostki / przejścia przez element liniowy
## Każdy element: {cells: Array[Vector2i], vertical: bool, crossing: bool}
var crossings: Array[Dictionary] = []
var crossing_cells: Dictionary = {}  # Vector2i -> bool

## Komórki blokujące ruch (cells bez kładek)
var blocked: Dictionary = {}  # Vector2i -> bool

## Odcinki krawędzi kwalifikujące się pod barierki ochronne
## Każdy element: {cells: Array[Vector2i], dir: Vector2i, side: int}
var rail_edges: Array[Dictionary] = []

## Strefy prześwitu przed i za kładkami (zakaz stawiania obiektów)
var bridge_clearance: Dictionary = {}  # Vector2i -> bool

## Puste koryto / sekcje suche (bez cieczy)
var dry: Dictionary = {}  # Vector2i -> bool

## Doły w pustym korycie: prostokąty i kratki -> wariant (VOID, TOP, TOP_B, BOTTOM) — tylko grafika (koryto i tak
## jest nieprzechodnie)
var pits: Array[Rect2i] = []
var pit_cells: Dictionary = {}  # Vector2i -> StringName

## Barierki: kratka -> wariant (L, M, R, CL, CR); tylko grafika (wejście do kanału blokuje obrzeże)
var rail_cells: Dictionary = {}  # Vector2i -> StringName

## Odcinki sieci liniowej
var segments: Array[Dictionary] = []  # {rect: Rect2i, axis: String, line: int, idx: int, kind: String}
var lines: Dictionary = {}  # line_id -> Array[Dictionary]

## Kompleksy sal wokół sieci
var complexes: Dictionary = {}  # cid -> {segs: Array, mask: Dictionary, pinch: Dictionary}

## Bramy i dźwignie przy korytarzach serwisowych
var gates: Array = []
var levers: Array = []
var service: Dictionary = {}  # Vector2i -> bool


func is_empty() -> bool:
	return cells.is_empty()


func is_cell(p: Vector2i) -> bool:
	return cells.has(p)


func is_lane(p: Vector2i) -> bool:
	return lanes.has(p)


func is_crossing(p: Vector2i) -> bool:
	return crossing_cells.has(p)


## Przelicza blocked i crossing_cells na podstawie cells i crossings.
func rebuild_blocked() -> void:
	crossing_cells.clear()
	for cr in crossings:
		var c_list: Array = cr.get("cells", [])
		for c in c_list:
			if c is Vector2i:
				crossing_cells[c] = true
			elif c is Array and c.size() >= 2:
				crossing_cells[Vector2i(c[0], c[1])] = true
			elif cr.has("rect"):
				var r: Rect2i = cr.rect
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						crossing_cells[Vector2i(x, y)] = true

	blocked.clear()
	for p in cells:
		if not crossing_cells.has(p):
			blocked[p] = true
