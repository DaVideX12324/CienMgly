@tool
class_name QuizRpgSafeZone
extends Node2D

## Strefa bezpieczna (azyl przy punkcie startu): prostokąt `size` wyśrodkowany w pozycji węzła. Wrogowie
## (EnemyBase) nie wybierają w niej celów wałęsania, nie widzą w niej gracza i nie zaczynają walki.
## level_manager tworzy ją przy punkcie pojawienia się gracza, gdy poziom nie ma własnej; w scenach ręcznych
## można ją postawić w edytorze (podgląd prostokąta).

const GROUP := &"quiz_safe_zone"
const EDITOR_COLOR := Color(0.35, 1.0, 0.55, 0.18)

@export var size := Vector2(192, 192):
	set(v):
		size = v
		queue_redraw()


func _enter_tree() -> void:
	add_to_group(GROUP)


## Prostokąt strefy we współrzędnych globalnych.
func global_rect() -> Rect2:
	var s := size * global_scale.abs()
	return Rect2(global_position - s * 0.5, s)


## Czy punkt globalny leży w którejkolwiek strefie bezpiecznej drzewa.
static func contains(tree: SceneTree, point: Vector2) -> bool:
	if tree == null:
		return false
	for z in tree.get_nodes_in_group(GROUP):
		if (z as QuizRpgSafeZone).global_rect().has_point(point):
			return true
	return false


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, EDITOR_COLOR)
	draw_rect(r, Color(EDITOR_COLOR, 0.9), false, 2.0)
