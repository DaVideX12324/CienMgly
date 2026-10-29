class_name QuizRpgZTrigger
extends Area2D

## Wyzwalacz poziomu na schodach budynku: postać (gracz, NPC, towarzysz), która w niego wejdzie, dostaje
## z_index = z i zachowuje go do następnego wyzwalacza. Miejsce na schodach i za nimi nachodzą się na ekranie —
## decyduje droga: pierwszy stopień (z 0, poziom ziemi), drugi stopień i podest (z 1, na schodach, nad budynkiem).
## Kolizje też zależą od drogi (tylko u postaci, które w ogóle mają maskę): na schodach krawędź schodów (stairs_layer),
## na ziemi kolizja pod schodami (ground_layer, gracz ma ją domyślnie w masce).

@export var z := 1
## Warstwa fizyki krawędzi schodów — dla postaci na schodach (wartość bitu; 64 = warstwa 7).
@export var stairs_layer := 64
## Warstwa fizyki kolizji pod schodami — dla postaci na ziemi (wartość bitu; 128 = warstwa 8).
@export var ground_layer := 128


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var b := body as CharacterBody2D
	if b == null:
		return
	b.z_index = z
	if b.collision_mask == 0:
		return
	if z > 0:
		b.collision_mask = (b.collision_mask | stairs_layer) & ~ground_layer
	else:
		b.collision_mask = (b.collision_mask | ground_layer) & ~stairs_layer
