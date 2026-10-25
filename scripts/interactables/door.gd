extends StaticBody2D

## Drzwi otwierane ruchem gracza i drużyny: otwierają się, gdy wejdzie pierwsza postać (lider albo towarzysz),
## zamykają, gdy wyjdzie ostatnia.

var _inside := 0


func _ready() -> void:
	var detection := get_node_or_null("PlayerDetection") as Area2D
	if detection != null:
		QuizRpgPartyMember.watch(detection)


func _on_player_detection_body_entered(body: Node2D) -> void:
	if not QuizRpgPartyMember.is_member(body):
		return
	_inside += 1
	if _inside == 1:
		$AnimationPlayer.play("Open")
		var audio := get_node_or_null("/root/AudioService")
		if audio:
			audio.play_sfx_by_name("door_open")


func _on_player_detection_body_exited(body: Node2D) -> void:
	if not QuizRpgPartyMember.is_member(body):
		return
	_inside = maxi(_inside - 1, 0)
	if _inside == 0:
		$AnimationPlayer.play("Closed")
		var audio := get_node_or_null("/root/AudioService")
		if audio:
			audio.play_sfx_by_name("door_close")
