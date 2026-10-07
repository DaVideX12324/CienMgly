@tool
class_name BattleBackgroundLayout
extends Resource

## Pola walki (gdzie stoją wrogowie) na konkretnym tle — plik obok grafiki tła (`<nazwa>_layout.tres`).
## Edycja graficzna: scenes/tools/battle_layout_preview.tscn (narożniki pól — trapezów — przeciągane
## myszą, Ctrl+D = nowe pole, np. platforma). Współrzędne pól w px obszaru bitwy przy 1920 px szerokości
## (REF_AREA = obszar nad dolnym paskiem UI przy 1920×1080); w grze: x skalowane szerokością ekranu,
## y liczone od dołu obszaru bitwy (skala wysokości ekranu). Liczenie położenia jest tylko tutaj —
## kontroler walki i podgląd używają tych samych funkcji.

## Grafika tła, której dotyczy układ (podgląd w edytorze; tło w grze wybiera generator tła).
@export var texture: Texture2D:
	set(v):
		texture = v
		emit_changed()
## Pola walki (np. podłoga, platformy). Wrogowie stoją na dolnej krawędzi pola.
## Pusty wpis (np. „Add Element” w inspektorze) zamienia się w nowe pole: kopię poprzedniego 120 px wyżej.
@export var fields: Array[BattleField] = []:
	set(v):
		for f in fields:
			if f and f.changed.is_connected(emit_changed):
				f.changed.disconnect(emit_changed)
		var clean: Array[BattleField] = []
		for f in v:
			clean.append(f if f != null else _new_field_after(clean))
		fields = clean
		for f in fields:
			if f and not f.changed.is_connected(emit_changed):
				f.changed.connect(emit_changed)
		emit_changed()

## Szansa wylosowania rzędu względem rzędu tuż przed nim (rzędy ze wszystkich pól od najbliższego):
## 0.4 przy 3 rzędach = szanse 1 : 0.4 : 0.16 (pojedynczy wróg: 64 % przód, 26 % środek, 10 % tył).
## Pełne rzędy odpadają, więc przy większej liczbie wrogów zapełniają się kolejne. 1.0 = po równo.
@export_range(0.05, 1.0, 0.01) var depth_chance := 0.4:
	set(v):
		depth_chance = v
		emit_changed()

const LAYOUT_SUFFIX := "_layout.tres"
const REF_SIZE := Vector2(1920.0, 1080.0)
const REF_AREA := Vector2(1920.0, 830.0)  # obszar bitwy przy pasku UI 250 px
const ENEMY_BASE_PX := 36.0               # szerokość grafiki wroga przed skalą


## Plik układu dla grafiki tła (`variant_1.jpg` -> `variant_1_layout.tres`) albo dla tła rysowanego
## w kodzie (ścieżka bez rozszerzenia).
static func path_for(texture_path: String) -> String:
	return texture_path.get_basename() + LAYOUT_SUFFIX


static func load_for(texture_path: String) -> BattleBackgroundLayout:
	var p := path_for(texture_path)
	return load(p) as BattleBackgroundLayout if ResourceLoader.exists(p) else null


## Nowe pole w miejsce pustego wpisu: kopia ostatniego przesunięta 120 px w górę (albo pole domyślne).
static func _new_field_after(prev: Array[BattleField]) -> BattleField:
	if prev.is_empty():
		return BattleField.new()
	var f := prev[prev.size() - 1].duplicate() as BattleField
	var q := PackedVector2Array()
	for p in f.quad:
		q.append(p + Vector2(0.0, -120.0))
	f.quad = q
	return f


## Pola, a gdy lista pusta — jedno pole domyślne (trapez, dwa rzędy na środku obszaru bitwy).
func active_fields() -> Array[BattleField]:
	if not fields.is_empty():
		return fields
	var f := BattleField.new()
	f.rows = 2
	f.row_capacity = 5
	f.auto_depth_scale = false
	return [f]


## Punkt pola (px wzorcowe) -> obszar bitwy o rozmiarze `area_size` (px ekranu): x skalowane szerokością,
## y liczone od dołu obszaru bitwy (skala wysokości ekranu).
func to_screen(p: Vector2, area_size: Vector2, viewport_size: Vector2) -> Vector2:
	var sx: float = area_size.x / REF_AREA.x if area_size.x > 0.0 else 1.0
	var sy: float = clampf(viewport_size.y / REF_SIZE.y, 0.75, 2.5) if viewport_size.y > 0.0 else 1.0
	return Vector2(p.x * sx, area_size.y - (REF_AREA.y - p.y) * sy)


## Miejsce wroga: pole, rząd (0 = przedni), k-ty z n w tym rzędzie.
class Spot:
	var field := 0
	var row := 0
	var k := 0
	var n := 1


## Przydział wrogów do miejsc (pole, rząd) z pojemnością rzędu; null = brak miejsca. `prefs[i]` =
## "front" / "back" / "" — przód = rząd z najniższą linią stóp (najbliżej), tył = z najwyższą; reszta
## losowo wśród rzędów z wolnym miejscem, z szansą malejącą w głąb (depth_chance). Kolejność w rzędzie
## = kolejność wrogów.
func assign(count: int, prefs: Array, rng: RandomNumberGenerator) -> Array:
	var fl := active_fields()
	var slots: Array = []  # [pole, rząd, linia stóp (px wzorcowe)]
	for fi in range(fl.size()):
		for r in range(fl[fi].rows):
			var line: PackedVector2Array = fl[fi].row_line(r)
			slots.append([fi, r, (line[0].y + line[1].y) * 0.5])
	slots.sort_custom(func(a, b) -> bool: return a[2] > b[2])
	var used: Array[int] = []
	used.resize(slots.size())
	used.fill(0)
	var picks: Array[int] = []
	for e in range(count):
		var pref: String = str(prefs[e]).to_lower() if e < prefs.size() else ""
		var free: Array[int] = []
		for si in range(slots.size()):
			if used[si] < fl[slots[si][0]].capacity(slots[si][1]):
				free.append(si)
		var pick := -1
		if not free.is_empty():
			if pref == "front":
				pick = free[0]
			elif pref == "back" or pref == "rear":
				pick = free[free.size() - 1]
			else:
				pick = _weighted_pick(free, rng)
			used[pick] += 1
		picks.append(pick)
	var out: Array = []
	var seen: Array[int] = []
	seen.resize(slots.size())
	seen.fill(0)
	for e in range(count):
		if picks[e] < 0:
			out.append(null)
			continue
		var sp := Spot.new()
		sp.field = slots[picks[e]][0]
		sp.row = slots[picks[e]][1]
		sp.k = seen[picks[e]]
		sp.n = used[picks[e]]
		seen[picks[e]] += 1
		out.append(sp)
	# Gdy jest 2 wrogów jeden za drugim (różne rzędy / głębokości):
	# Zamiast stawiać obu w centrum swoich rzędów (t=0.5), co sprawia, że przedni zasłania tylnego,
	# rozsuwamy ich po przekątnej jak w układzie dla 4 wrogów (jeden z jednej, drugi z drugiej strony: n=2, k=0 i k=1).
	if count == 2 and out.size() == 2 and out[0] != null and out[1] != null and picks[0] != picks[1]:
		var side := rng.randi() % 2
		out[0].n = 2
		out[0].k = side
		out[1].n = 2
		out[1].k = 1 - side
	return out


## Rząd z wolnych (indeksy w liście rzędów od najbliższego): rząd i ma wagę depth_chance^i.
func _weighted_pick(free: Array[int], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for si in free:
		total += pow(depth_chance, si)
	var x := rng.randf() * total
	for si in free:
		x -= pow(depth_chance, si)
		if x < 0.0:
			return si
	return free[free.size() - 1]


## Linia stóp wroga na miejscu `spot`: równo na linii rzędu między lewym a prawym bokiem pola.
func foot(spot: Spot, area_size: Vector2, viewport_size: Vector2) -> Vector2:
	var fl := active_fields()
	var field: BattleField = fl[clampi(spot.field, 0, fl.size() - 1)]
	var line := field.row_line(spot.row)
	var p := line[0].lerp(line[1], (spot.k + 0.5) / maxi(spot.n, 1))
	return to_screen(p, area_size, viewport_size)


func spot_scale(spot: Spot) -> float:
	var fl := active_fields()
	return fl[clampi(spot.field, 0, fl.size() - 1)].row_scale(spot.row)


## Skala wroga (przed skalą pola): mniejsza przy większej liczbie wrogów.
static func enemy_scale(active_count: int, viewport_size: Vector2) -> float:
	var res := 1.0
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		res = clampf(minf(viewport_size.x / REF_SIZE.x, viewport_size.y / REF_SIZE.y), 0.65, 2.5)
	var base := 5.2
	if active_count <= 1:
		base = 8.5
	elif active_count == 2:
		base = 7.2
	elif active_count == 3:
		base = 6.2
	elif active_count == 4:
		base = 5.6
	return base * clampf(res, 0.7, 2.5)
