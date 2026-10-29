class_name QuizRpgZTrigger
extends Area2D

## Wyzwalacz poziomu na schodach budynku: postać (gracz, NPC, towarzysz), która w niego wejdzie, dostaje
## z_index = z i zachowuje go do następnego wyzwalacza. Miejsce na schodach i za nimi nachodzą się na ekranie —
## decyduje droga: pierwszy stopień (z 0, poziom ziemi), drugi stopień i podest (z 1, na schodach, nad budynkiem).
## Przy z > 0 postać zderza się też z krawędzią schodów (warstwa edge_layer), przy z 0 — nie (za schodami przechodzi).

@export var z := 1
## Warstwa fizyki krawędzi schodów (wartość bitu; 64 = warstwa 7).
@export var edge_layer := 64


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var b := body as CharacterBody2D
	if b == null:
		return
	b.z_index = z
	if z > 0:
		b.collision_mask |= edge_layer
	else:
		b.collision_mask &= ~edge_layer
