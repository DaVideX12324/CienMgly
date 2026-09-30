@tool
class_name BattleField
extends Resource

## Jedno pole walki na tle (podłoga, platforma…): obszar, na którym stoją wrogowie, w jednym albo kilku
## rzędach. Prostokąt = obszar stóp: dolna krawędź — rząd przedni, górna — rząd najdalszy, rzędy
## pośrednie równo między nimi (1 rząd — dolna krawędź). Współrzędne w px obszaru bitwy przy 1920 px
## szerokości; dół obszaru bitwy = BattleBackgroundLayout.REF_AREA.y (nad dolnym paskiem UI).

## Obszar stóp wrogów (px).
@export var rect := Rect2(240.0, 625.0, 1440.0, 170.0):
	set(v):
		rect = v
		emit_changed()
## Liczba rzędów na polu (dalsze rzędy wyżej, mniejsze wrogi).
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
## Skala wrogów w rzędzie najdalszym (perspektywa, np. 0.82); rzędy pośrednie — pomiędzy.
@export_range(0.3, 2.0, 0.01) var back_scale := 0.82:
	set(v):
		back_scale = v
		emit_changed()
## Rząd najdalszy węższy o tyle px z każdej strony (perspektywa); rzędy pośrednie — pomiędzy.
@export_range(0.0, 800.0, 1.0, "suffix:px") var back_row_inset := 0.0:
	set(v):
		back_row_inset = v
		emit_changed()


## Położenie rzędu 0..rows-1 (0 = przedni) między dolną (0.0) a górną (1.0) krawędzią.
func row_t(row: int) -> float:
	return 0.0 if rows <= 1 else float(row) / float(rows - 1)


func row_scale(row: int) -> float:
	return lerpf(front_scale, back_scale, row_t(row))
