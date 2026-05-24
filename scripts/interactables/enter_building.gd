extends Area2D

# Drag and drop the target Area2D in the Inspector
@export var target_area: Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and target_area:
		body.global_position = target_area.global_position
