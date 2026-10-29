class_name QuizRpgZTrigger
extends Area2D

## Wyzwalacz poziomu na schodach budynku. Miejsce na schodach i za nimi nachodzą się na ekranie — decyduje droga:
## wyzwalacz działa tylko na postać z z_index == from_z i ustawia jej z (pierwszy stopień: 1 -> 0, drugi stopień
## i podest: 0 -> 1). Postać stojąca naraz na tym i na sąsiednim stopniu (pair) zachowuje poziom — zmiana dopiero, gdy
## stoi tylko na tym (sprawdzane przy wejściu tu i przy wyjściu z pair, bez wyścigu kolejności zdarzeń).
## Na górze (z > 0) postać ignoruje kolizje ciała domu (owner — BaseCollision parteru) i zderza się z obrysem górnego
## poziomu (warstwa stairs_layer); na dole odwrotnie.

@export var z := 1
## Poziom, na który wyzwalacz działa.
@export var from_z := 0
## Sąsiedni stopień (wyzwalacz) — gdy postać stoi też na nim, poziom się nie zmienia.
@export var pair: NodePath
## Warstwa fizyki obrysu górnego poziomu (wartość bitu; 64 = warstwa 7).
@export var stairs_layer := 64

var _pair: Area2D


func _ready() -> void:
	_pair = get_node_or_null(pair) as Area2D
	body_entered.connect(_check)
	if _pair:
		_pair.body_exited.connect(_check)


func _check(body: Node2D) -> void:
	var b := body as CharacterBody2D
	if b == null or b.z_index != from_z or not overlaps_body(b):
		return
	if _pair and _pair.overlaps_body(b):
		return
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
