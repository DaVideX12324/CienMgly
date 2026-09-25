class_name ObjectPlacement
extends RefCounted

## Jeden postawiony obiekt w ObjectPlan.

var def: ObjectDef
var cell := Vector2i.ZERO        # kratka kotwicy (lewa-dolna kratka podstawy)
var offset := Vector2.ZERO       # przesunięcie punktu obiektu (grid_jitter / free), px
var variant := 0                 # indeks w def.atlas
var flip := false
var cells := PackedInt32Array()  # zajęte kratki (idx) — podstawa albo kratki pod kształtem


## Punkt obiektu w px (środek dołu podstawy + przesunięcie) — pozycja sprite'a / sceny / kształtu.
func point() -> Vector2:
	return def.base_point(cell) + offset


## Origin sceny / wypieczonej sceny: środek kratki kotwicy (dolny wiersz podstawy) + przesunięcie.
func origin() -> Vector2:
	return point() - Vector2(0, ObjectDef.CELL * 0.5)
