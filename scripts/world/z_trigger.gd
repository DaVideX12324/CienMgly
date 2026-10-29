class_name QuizRpgZTrigger
extends Area2D

## Wyzwalacz poziomu rysowania na schodach budynku: postać (gracz, NPC, towarzysz), która w niego wejdzie, dostaje
## z_index = z i zachowuje go do następnego wyzwalacza. Miejsce na schodach i za nimi nachodzą się na ekranie —
## decyduje droga: pierwszy stopień (z 0, poziom ziemi), drugi stopień i podest (z 1, na schodach, nad budynkiem).

@export var z := 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.z_index = z
