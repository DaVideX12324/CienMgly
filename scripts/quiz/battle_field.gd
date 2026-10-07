@tool
class_name BattleField
extends Resource

## Jedno pole walki na tle (podłoga, platforma…): czworobok (zwykle trapez) albo wielokąt z punktami
## pośrednimi na bokach (np. bok idący wzdłuż schodów), na którym stoją wrogowie, w jednym albo kilku
## rzędach. Przednia krawędź (niżej na ekranie) = rząd przedni, tylna = rząd najdalszy, rzędy pośrednie
## między nimi (1 rząd — przednia krawędź); końce rzędów idą po punktach boków — rząd k łączy k-ty punkt
## lewego boku z k-tym prawego (rows = liczba punktów na boku), wrogowie równo na linii rzędu. Współrzędne w px obszaru bitwy przy 1920 px szerokości; dół
## obszaru bitwy = BattleBackgroundLayout.REF_AREA.y (nad dolnym paskiem UI).

## Narożniki pola (px). 4 punkty: kolejność dowolna — sortowane na przód-lewy, przód-prawy, tył-prawy,
## tył-lewy. Więcej punktów (pośrednie na bokach): kolejno po obwodzie — układane na przód-lewy,
## przód-prawy, prawy bok w górę…, tył-prawy, tył-lewy, lewy bok w dół… (przód / tył = najniższa /
## najwyższa krawędź wielokąta).
@export var quad := PackedVector2Array([Vector2(222, 765), Vector2(1698, 765), Vector2(1460, 625), Vector2(460, 625)]):
	set(v):
		for p in v:
			if not p.is_finite():
				return  # NaN / nieskończoność (np. z edytora wielokąta) — zostaje poprzedni kształt
		quad = normalized(v)
		emit_changed()
## Liczba rzędów na polu.
@export_range(1, 3) var rows := 1:
	set(v):
		rows = v
		emit_changed()
## Ilu wrogów najwyżej w jednym rzędzie (rzędy bez wpisu w row_capacities).
@export_range(1, 8) var row_capacity := 3:
	set(v):
		row_capacity = v
		emit_changed()
## Pojemność poszczególnych rzędów: wpis 0 = rząd przedni, 1 = następny… Brak wpisu albo 0 — row_capacity.
@export var row_capacities := PackedInt32Array():
	set(v):
		row_capacities = v
		emit_changed()
## Skala wrogów w rzędzie przednim (mnożnik skali walki).
@export_range(0.3, 2.0, 0.01) var front_scale := 1.0:
	set(v):
		front_scale = v
		emit_changed()
## Skala głębi z wysokości na ekranie (wspólna dla wszystkich pól — platforma w głębi też mniejsza): rząd
## na linii zera (DEPTH_ZERO_Y) = front_scale, każde 100 px wyżej — mniejszy o depth_shrink.
@export var auto_depth_scale := true:
	set(v):
		auto_depth_scale = v
		emit_changed()
## Wielkość wrogów w rzędzie najdalszym WZGLĘDEM przedniego, gdy auto_depth_scale wyłączone:
## 0.82 = tylni mają 82 % wielkości przednich (rzędy pośrednie — pomiędzy); mnożone przez front_scale.
@export_range(0.3, 1.5, 0.01) var back_scale := 0.82:
	set(v):
		back_scale = v
		emit_changed()


## Narożniki w kolejności: przód-lewy, przód-prawy, tył-prawy, tył-lewy (przód = dwa niższe na ekranie).
static func sorted_quad(pts: PackedVector2Array) -> PackedVector2Array:
	var a := Array(pts)
	a.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y > q.y)
	var front := [a[0], a[1]]
	var back := [a[2], a[3]]
	front.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	back.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	return PackedVector2Array([front[0], front[1], back[1], back[0]])


## Kształt pola w kolejności pola: 4 punkty — sorted_quad; więcej — wielokąt (punkty kolejno po obwodzie)
## obrócony tak, żeby zaczynał się od przedniej krawędzi (najniższej na ekranie) z lewej do prawej.
static func normalized(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() == 4:
		return sorted_quad(pts)
	if pts.size() < 4:
		return pts
	var p := pts.duplicate()
	var fi := _lowest_edge(p)
	if p[fi].x > p[(fi + 1) % p.size()].x:
		p.reverse()  # obieg w drugą stronę — po przedniej krawędzi z lewej do prawej
		fi = _lowest_edge(p)
	var out := PackedVector2Array()
	for i in range(p.size()):
		out.append(p[(fi + i) % p.size()])
	return out


static func _lowest_edge(p: PackedVector2Array) -> int:
	var best := 0
	for i in range(1, p.size()):
		if p[i].y + p[(i + 1) % p.size()].y > p[best].y + p[(best + 1) % p.size()].y:
			best = i
	return best


## Boki pola od przodu do tyłu: [lewy (przód-lewy … tył-lewy), prawy (przód-prawy … tył-prawy)].
## Tylna krawędź = najwyżej położona krawędź wielokąta poza przednią.
func sides() -> Array[PackedVector2Array]:
	var n := quad.size()
	if n == 4:
		return [PackedVector2Array([quad[0], quad[3]]), PackedVector2Array([quad[1], quad[2]])]
	var back := 1
	for j in range(1, n - 1):
		if quad[j].y + quad[j + 1].y < quad[back].y + quad[back + 1].y:
			back = j
	var right := PackedVector2Array()
	for i in range(1, back + 1):
		right.append(quad[i])
	var left := PackedVector2Array([quad[0]])
	for i in range(n - 1, back, -1):
		left.append(quad[i])
	return [left, right]


## Punkt boku na głębokości t (0 = przód, 1 = tył) liczonej po punktach boku: rzędy idą od punktu do
## punktu — przy 3 rzędach i jednym punkcie pośrednim na boku rząd środkowy leży dokładnie na nim.
## Między punktami (więcej rzędów niż punktów) — liniowo po odcinku.
static func side_point(side: PackedVector2Array, t: float) -> Vector2:
	var u := clampf(t, 0.0, 1.0) * float(side.size() - 1)
	var i := mini(int(floor(u)), side.size() - 2)
	return side[i].lerp(side[i + 1], u - float(i))


## Ilu wrogów najwyżej w rzędzie 0..rows-1 (0 = przedni).
func capacity(row: int) -> int:
	if row >= 0 and row < row_capacities.size() and row_capacities[row] > 0:
		return row_capacities[row]
	return row_capacity


## Ilu wrogów najwyżej na całym polu.
func total_capacity() -> int:
	var n := 0
	for r in range(rows):
		n += capacity(r)
	return n


## Położenie rzędu 0..rows-1 (0 = przedni) między przednią (0.0) a tylną (1.0) krawędzią.
func row_t(row: int) -> float:
	return 0.0 if rows <= 1 else float(row) / float(rows - 1)


## Linia rzędu w px wzorcowych: [lewy koniec, prawy koniec].
func row_line(row: int) -> PackedVector2Array:
	var t := row_t(row)
	var sd := sides()
	return PackedVector2Array([side_point(sd[0], t), side_point(sd[1], t)])


## Linia zera głębi (px wzorcowe): przedni rząd typowego pola — punkt (0, 0) pól w podglądzie (nad cieniem
## z miejscem na pasek HP).
const DEPTH_ZERO_Y := 765.0
const DEPTH_MIN_SCALE := 0.2
## Skala głębi (auto_depth_scale): o ile mniejszy wróg na każde 100 px wyżej od DEPTH_ZERO_Y.
## TYMCZASOWO zmienne — ustawiane w podglądzie pól (depth_shrink), po wyborze wartości zostanie stałą.
static var depth_shrink := 0.13


func row_scale(row: int) -> float:
	var t := row_t(row)
	if auto_depth_scale:
		var line := row_line(row)
		var y := (line[0].y + line[1].y) * 0.5
		return front_scale * maxf(DEPTH_MIN_SCALE, 1.0 - (DEPTH_ZERO_Y - y) * 0.01 * depth_shrink)
	return front_scale * lerpf(1.0, back_scale, t)
