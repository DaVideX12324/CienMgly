class_name QuizRpgZTrigger
extends Area2D

## Wyzwalacz poziomu na schodach budynku. Miejsce na schodach i za nimi nachodzą się na ekranie — decyduje droga:
## wyzwalacz działa tylko na postać z z_index == from_z i ustawia jej z (pierwszy stopień: 1 -> 0, drugi stopień
## i podest: 0 -> 1). Liczy się punkt stóp (feet względem postaci) w wielokącie wyzwalacza, sprawdzany co klatkę
## fizyki, póki postać go dotyka — punkt leży najwyżej na jednym stopniu, więc kolejność zdarzeń sąsiednich obszarów
## nie ma znaczenia. Na górze (z > 0) postać ignoruje kolizje ciała domu (owner — BaseCollision parteru) i zderza się
## z obrysem górnego poziomu (warstwa stairs_layer); na dole odwrotnie.

@export var z := 1
## Poziom, na który wyzwalacz działa.
@export var from_z := 0
## Punkt stóp względem postaci (środek kapsuły kolizji gracza).
@export var feet := Vector2(0, 11)
## Warstwa fizyki obrysu górnego poziomu (wartość bitu; 64 = warstwa 7).
@export var stairs_layer := 64

var _poly: CollisionPolygon2D
var _inside: Array[CharacterBody2D] = []


func _ready() -> void:
	for c in get_children():
		if c is CollisionPolygon2D:
			_poly = c
			break
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not _inside.has(body):
		_inside.append(body)
		set_physics_process(true)


func _on_body_exited(body: Node2D) -> void:
	_inside.erase(body)
	set_physics_process(not _inside.is_empty())


func _physics_process(_delta: float) -> void:
	for b in _inside:
		if is_instance_valid(b) and b.z_index == from_z and _feet_inside(b):
			_set_level(b)


func _feet_inside(b: CharacterBody2D) -> bool:
	if _poly == null:
		return true
	var p := _poly.global_transform.affine_inverse() * (b.global_position + feet)
	return Geometry2D.is_point_in_polygon(p, _poly.polygon)


func _set_level(b: CharacterBody2D) -> void:
	b.z_index = z
	var house := owner as PhysicsBody2D
	if z > 0:
		b.collision_mask |= stairs_layer
		if house:
			b.add_collision_exception_with(house)
	else:
		b.collision_mask &= ~stairs_layer
		if house:
			b.remove_collision_exception_with(house)
