class_name QuizRpgRaisedZone
extends Area2D

## Strefa schodów / podestu budynku: postacie w środku (gracz, NPC, towarzysze) są rysowane nad budynkiem
## (z_index + raise), po wyjściu wraca ich poprzedni z_index. Poza strefą schody sortują się zwykle (Y Sort),
## więc postać za schodami jest nimi zasłonięta, a na schodach stoi na nich.

@export var raise := 1

var _saved := {}   # ciało -> z_index sprzed wejścia


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not _saved.has(body):
		_saved[body] = body.z_index
		body.z_index += raise


func _on_body_exited(body: Node2D) -> void:
	if _saved.has(body):
		if is_instance_valid(body):
			body.z_index = _saved[body]
		_saved.erase(body)
