@tool
class_name BattleField
extends Resource

## Jedno pole walki na tle (podłoga, platforma…): czworobok (zwykle trapez), na którym stoją wrogowie,
## w jednym albo kilku rzędach. Przednia krawędź (niżej na ekranie) = rząd przedni, tylna = rząd
## najdalszy, rzędy pośrednie równo między nimi (1 rząd — przednia krawędź); wrogowie równo na linii
## rzędu między lewym a prawym bokiem. Współrzędne w px obszaru bitwy przy 1920 px szerokości; dół
## obszaru bitwy = BattleBackgroundLayout.REF_AREA.y (nad dolnym paskiem UI).

## Narożniki pola (px): kolejność dowolna — sortowane na przód-lewy, przód-prawy, tył-prawy, tył-lewy.
@export var quad := PackedVector2Array([Vector2(240, 795), Vector2(1680, 795), Vector2(1460, 625), Vector2(460, 625)]):
	set(v):
		for p in v:
			if not p.is_finite():
				return  # NaN / nieskończoność (np. z edytora wielokąta) — zostaje poprzedni kształt
		quad = sorted_quad(v) if v.size() == 4 else v
		emit_changed()
## Liczba rzędów na polu.
@export_range(1, 3) var rows := 1:
	set(v):
		rows = v
		emit_changed()
## Ilu wrogów najwyżej w jednym rzędzie.
@export_range(1, 8) var row_capacity := 3:
	set(v):
		row_capacity = v
		emit_changed()
## Skala wrogów w rzędzie przednim (mnożnik skali walki).
@export_range(0.3, 2.0, 0.01) var front_scale := 1.0:
	set(v):
		front_scale = v
		emit_changed()
## Skala głębi z kształtu: dalszy rząd tyle razy mniejszy, ile razy węższy od przedniej krawędzi.
@export var auto_depth_scale := true:
	set(v):
		auto_depth_scale = v
		emit_changed()
## Skala wrogów w rzędzie najdalszym, gdy auto_depth_scale wyłączone (rzędy pośrednie — pomiędzy).
@export_range(0.3, 2.0, 0.01) var back_scale := 0.82:
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


## Położenie rzędu 0..rows-1 (0 = przedni) między przednią (0.0) a tylną (1.0) krawędzią.
func row_t(row: int) -> float:
	return 0.0 if rows <= 1 else float(row) / float(rows - 1)


## Linia rzędu w px wzorcowych: [lewy koniec, prawy koniec].
func row_line(row: int) -> PackedVector2Array:
	var t := row_t(row)
	return PackedVector2Array([quad[0].lerp(quad[3], t), quad[1].lerp(quad[2], t)])


func row_scale(row: int) -> float:
	var t := row_t(row)
	if auto_depth_scale:
		var front_w := quad[0].distance_to(quad[1])
		var line := row_line(row)
		return front_scale * (line[0].distance_to(line[1]) / front_w if front_w > 0.0 else 1.0)
	return lerpf(front_scale, back_scale, t)
