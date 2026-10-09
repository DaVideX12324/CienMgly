extends Area2D

## Klucz do przejścia (zamka bramy z kolców) — podnoszony wejściem gracza na kratkę. Klucze są wspólne dla
## poziomu (GateState): pasuje do dowolnego zamka bram. Stan w zapisie (podniesiony = nie wraca).

const GateStateScript = preload("gate_state.gd")

@export var unique_id: String = ""
@export var gate_id: String = ""   # brama, do której generator go położył (informacyjnie)

var _taken := false


func _ready() -> void:
	add_to_group("gate_keys")
	body_entered.connect(_on_body_entered)
	call_deferred("_check_taken")
	var sprite := $Sprite as Node2D
	var tw := create_tween().set_loops()
	tw.tween_property(sprite, "position:y", sprite.position.y - 2.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "position:y", sprite.position.y, 0.6).set_trans(Tween.TRANS_SINE)


func _key_id() -> String:
	return unique_id if not unique_id.is_empty() else "%d_%d" % [int(global_position.x), int(global_position.y)]


func _check_taken() -> void:
	if GateStateScript.level_path(self).is_empty():
		await get_tree().process_frame
		if is_inside_tree():
			_check_taken()
		return
	if GateStateScript.is_key_taken(self, _key_id()):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not GateStateScript.is_player(body):
		return
	_taken = true
	GateStateScript.take_key(self, _key_id())
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_sfx_by_name"):
		audio.play_sfx_by_name("coin")
	var loot := GateStateScript.singleton(self, "LootManager")
	if loot and loot.has_method("show_loot_popup"):
		loot.call("show_loot_popup", {
			"found": true,
			"title": "Klucz do przejscia",
			"message": "Pasuje do zamka przy kracie z kolcow. Klucze: %d." % GateStateScript.keys_available(self),
			"detail": "Nacisnij E albo Enter, aby kontynuowac.",
		})
	queue_free()
