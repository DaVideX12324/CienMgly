@tool
class_name BattleBackgroundLayout
extends Resource

## Pola walki (gdzie stoją wrogowie) na konkretnym tle — plik obok grafiki tła (`<nazwa>_layout.tres`).
## Edycja graficzna: scenes/tools/battle_layout_preview.tscn (prostokąty pól przeciągane myszą,
## Ctrl+D = nowe pole, np. platforma). Współrzędne pól w px obszaru bitwy przy 1920 px szerokości
## (REF_AREA = obszar nad dolnym paskiem UI przy 1920×1080); w grze: x skalowane szerokością ekranu,
## y liczone od dołu obszaru bitwy (skala wysokości ekranu). Liczenie położenia jest tylko tutaj —
## kontroler walki i podgląd używają tych samych funkcji.

## Grafika tła, której dotyczy układ (podgląd w edytorze; tło w grze wybiera generator tła).
@export var texture: Texture2D:
	set(v):
		texture = v
		emit_changed()
## Pola walki (np. podłoga, platformy). Wrogowie stoją na dolnej krawędzi pola.
@export var fields: Array[BattleField] = []:
	set(v):
		for f in fields:
			if f and f.changed.is_connected(emit_changed):
				f.changed.disconnect(emit_changed)
		fields = v
		for f in fields:
			if f and not f.changed.is_connected(emit_changed):
				f.changed.connect(emit_changed)
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


## Pola, a gdy lista pusta — jedno pole domyślne (dwa rzędy na środku obszaru bitwy).
func active_fields() -> Array[BattleField]:
	if not fields.is_empty():
		return fields
	var f := BattleField.new()
	f.rect = Rect2(240.0, 625.0, 1440.0, 170.0)
	f.rows = 2
	f.row_capacity = 5
	f.back_row_inset = 220.0
	return [f]


## Prostokąt obszaru stóp pola w obszarze bitwy o rozmiarze `area_size` (px ekranu).
func field_rect(field: BattleField, area_size: Vector2, viewport_size: Vector2) -> Rect2:
	var sx: float = area_size.x / REF_AREA.x if area_size.x > 0.0 else 1.0
	var sy: float = clampf(viewport_size.y / REF_SIZE.y, 0.75, 2.5) if viewport_size.y > 0.0 else 1.0
	var r := field.rect
	var bottom: float = area_size.y - (REF_AREA.y - r.end.y) * sy
	return Rect2(r.position.x * sx, bottom - r.size.y * sy, r.size.x * sx, r.size.y * sy)


## Miejsce wroga: pole, rząd (0 = przedni), k-ty z n w tym rzędzie.
class Spot:
	var field := 0
	var row := 0
	var k := 0
	var n := 1


## Przydział wrogów do miejsc (pole, rząd) z pojemnością rzędu; null = brak miejsca. `prefs[i]` =
## "front" / "back" / "" — przód = rząd z najniższą linią stóp (najbliżej), tył = z najwyższą; reszta
## losowo wśród rzędów z wolnym miejscem. Kolejność w rzędzie = kolejność wrogów.
func assign(count: int, prefs: Array, rng: RandomNumberGenerator) -> Array:
	var fl := active_fields()
	var slots: Array = []  # [pole, rząd, linia stóp (px wzorcowe)]
	for fi in range(fl.size()):
		for r in range(fl[fi].rows):
			slots.append([fi, r, fl[fi].rect.end.y - fl[fi].rect.size.y * fl[fi].row_t(r)])
	slots.sort_custom(func(a, b) -> bool: return a[2] > b[2])
	var used: Array[int] = []
	used.resize(slots.size())
	used.fill(0)
	var picks: Array[int] = []
	for e in range(count):
		var pref: String = str(prefs[e]).to_lower() if e < prefs.size() else ""
		var free: Array[int] = []
		for si in range(slots.size()):
			if used[si] < fl[slots[si][0]].row_capacity:
				free.append(si)
		var pick := -1
		if not free.is_empty():
			if pref == "front":
				pick = free[0]
			elif pref == "back" or pref == "rear":
				pick = free[free.size() - 1]
			else:
				pick = free[rng.randi() % free.size()]
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
	return out


## Linia stóp wroga na miejscu `spot` (równo na szerokość rzędu; dalsze rzędy węższe o wcięcie).
func foot(spot: Spot, area_size: Vector2, viewport_size: Vector2) -> Vector2:
	var fl := active_fields()
	var field: BattleField = fl[clampi(spot.field, 0, fl.size() - 1)]
	var r := field_rect(field, area_size, viewport_size)
	var t := field.row_t(spot.row)
	var sx: float = area_size.x / REF_AREA.x if area_size.x > 0.0 else 1.0
	var inset := field.back_row_inset * t * sx
	var y := r.end.y - r.size.y * t
	var x0 := r.position.x + inset
	var w := maxf(r.size.x - 2.0 * inset, 0.0)
	return Vector2(x0 + w * (spot.k + 0.5) / maxi(spot.n, 1), y)


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
