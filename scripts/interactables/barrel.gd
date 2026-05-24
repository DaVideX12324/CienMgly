class_name Barrel
extends CharacterBody2D

@export var health: float = 5.0
@export_range(0.0, 1.0, 0.01) var interaction_drop_chance: float = 0.45
@export var remove_after_interaction: bool = true
@export var unique_id: String = ""

@onready var player: Node2D = _get_player()
@onready var sprite: Sprite2D = $Sprite2D
@onready var damage_hitbox: CollisionShape2D = get_node_or_null("DamageHitbox/DamageHitbox")

var is_dead: bool = false
var _player_in_interaction_range: bool = false


func _ready() -> void:
	add_to_group("destructible")
	add_to_group("interactable")
	if unique_id.is_empty():
		unique_id = _generate_unique_id()
	call_deferred("_check_if_destroyed")


func _check_if_destroyed() -> void:
	var level_path := _get_current_level_path()
	if level_path.is_empty():
		await get_tree().process_frame
		_check_if_destroyed()
		return

	var level_state_manager := _get_level_state_manager()
	if level_state_manager and level_state_manager.is_barrel_destroyed(level_path, unique_id):
		queue_free()


func _generate_unique_id() -> String:
	var id_parts: Array[String] = ["barrel"]
	if name != "Barrel" and not name.begins_with("@"):
		id_parts.append(name.replace("@", "").strip_edges().to_lower())
	var pos_x := int(global_position.x / 10.0) * 10
	var pos_y := int(global_position.y / 10.0) * 10
	id_parts.append(str(pos_x))
	id_parts.append(str(pos_y))
	return "_".join(id_parts)


func take_damage(weapon_damage: float, _is_crit: bool) -> float:
	health -= weapon_damage
	if health <= 0.0:
		_interact()
		return weapon_damage + health
	return weapon_damage


func _interact() -> void:
	if is_dead:
		return
	is_dead = true

	var level_path := _get_current_level_path()
	if level_path != "":
		var level_state_manager := _get_level_state_manager()
		if level_state_manager:
			level_state_manager.mark_barrel_destroyed(level_path, unique_id)

	var loot_result: Dictionary = {
		"found": false,
		"title": "Pusta beczka",
		"message": "Nic nie wypadlo.",
		"detail": "Nacisnij E albo Enter, aby kontynuowac.",
	}
	var loot_manager := _get_loot_manager()
	if loot_manager and loot_manager.has_method("search_barrel"):
		var raw_result: Variant = loot_manager.call("search_barrel", interaction_drop_chance)
		if raw_result is Dictionary:
			loot_result = (raw_result as Dictionary).duplicate(true)

	if remove_after_interaction:
		_play_death_and_free()

	if bool(loot_result.get("found", false)) and loot_manager and loot_manager.has_method("show_loot_popup"):
		loot_manager.call("show_loot_popup", loot_result)


func _play_death_and_free() -> void:
	_disable_collision()
	_spawn_procedural_particles()
	queue_free()


func _spawn_procedural_particles() -> void:
	if get_parent() == null:
		return
	var particles := CPUParticles2D.new()
	particles.amount = 16
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.55, 0.4, 0.25)
	particles.global_position = global_position
	get_parent().add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _disable_collision() -> void:
	if damage_hitbox:
		call_deferred("_disable_shape", damage_hitbox)
	var body_shape := get_node_or_null("CollisionShape2D")
	if body_shape:
		call_deferred("_disable_shape", body_shape)
	var interaction_shape := get_node_or_null("InteractionArea/CollisionShape2D")
	if interaction_shape:
		call_deferred("_disable_shape", interaction_shape)


func _disable_shape(shape: CollisionShape2D) -> void:
	if shape:
		shape.disabled = true


func _get_level_state_manager() -> Node:
	return _get_module_singleton("LevelStateManager")


func _get_loot_manager() -> Node:
	return _get_module_singleton("LootManager")


func _get_module_singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var singleton: Variant = core_manager.call("get_singleton", singleton_name)
		if singleton is Node:
			return singleton
	return get_node_or_null("/root/%s" % singleton_name)


func _get_level_manager() -> Node:
	var game_root := get_tree().current_scene
	if game_root:
		var level_manager := game_root.find_child("level_manager", true, false)
		if level_manager is Node:
			return level_manager
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_active_module"):
		var module_root: Variant = core_manager.call("get_active_module")
		if module_root is Node:
			var level_manager := (module_root as Node).find_child("level_manager", true, false)
			if level_manager is Node:
				return level_manager
	return null


func _get_current_level_path() -> String:
	var level_manager := _get_level_manager()
	if level_manager:
		return str(level_manager.get("current_level_path"))
	return ""


func _get_player() -> Node2D:
	var game_root := get_tree().current_scene
	if game_root:
		var player_node := game_root.find_child("Player", true, false)
		if player_node is Node2D:
			return player_node
	return null


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_interaction_range = true
		player = body
		_interact()


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body == player or body.is_in_group("player") or body.name == "Player":
		_player_in_interaction_range = false
