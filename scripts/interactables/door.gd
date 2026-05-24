extends StaticBody2D






func _on_player_detection_body_entered(body: Node2D) -> void:
	if body.name == 'Player':
		$AnimationPlayer.play("Open")
		
func _on_player_detection_body_exited(body: Node2D) -> void:
	if body.name == 'Player':
		$AnimationPlayer.play("Closed")
