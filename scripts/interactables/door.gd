extends StaticBody2D






func _on_player_detection_body_entered(body: Node2D) -> void:
	if body.name == 'Player':
		$AnimationPlayer.play("Open")
		var audio := get_node_or_null("/root/AudioService")
		if audio:
			audio.play_sfx_by_name("door_open")


func _on_player_detection_body_exited(body: Node2D) -> void:
	if body.name == 'Player':
		$AnimationPlayer.play("Closed")
		var audio := get_node_or_null("/root/AudioService")
		if audio:
			audio.play_sfx_by_name("door_close")
