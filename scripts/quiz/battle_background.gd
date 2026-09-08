extends Control

const GENERATORS: Dictionary = {
	"world_map": preload("res://modules/quiz_rpg/scripts/quiz/background_generators/world_map_battle_background.gd"),
	"tutorial_area": preload("res://modules/quiz_rpg/scripts/quiz/background_generators/tutorial_area_battle_background.gd"),
	"default": preload("res://modules/quiz_rpg/scripts/quiz/background_generators/default_battle_background.gd"),
}

var _map_node: Node
var _enemy: Node
var _player: Node
var _enemy_units: Array = []
var _generator: RefCounted


func _ready() -> void:
	resized.connect(func() -> void: queue_redraw())
	_select_generator()


func set_context(map_node: Node, enemy: Node, player: Node, enemy_units: Array = []) -> void:
	_map_node = map_node
	_enemy = enemy
	_player = player
	_enemy_units = enemy_units.duplicate(true)
	_select_generator()
	queue_redraw()


func refresh_units(enemy_units: Array) -> void:
	_enemy_units = enemy_units.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if _generator == null:
		_select_generator()
	var context: Dictionary = {
		"map": _map_node,
		"enemy": _enemy,
		"player": _player,
		"enemy_units": _enemy_units,
	}
	_generator.draw_background(self, context)


func _select_generator() -> void:
	var key: String = _map_key(_map_node)
	var generator_script: Script = GENERATORS.get(key, GENERATORS["default"]) as Script
	_generator = generator_script.new()


func _map_key(map_node: Node) -> String:
	if map_node == null:
		return "default"
	var script: Script = map_node.get_script() as Script
	if script and script.resource_path.ends_with("/world_map.gd"):
		return "world_map"
	if script and (script.resource_path.ends_with("/tutorial_area.gd") or script.resource_path.contains("tutorial_area")):
		return "tutorial_area"
	var node_name: String = str(map_node.name).to_snake_case()
	if GENERATORS.has(node_name):
		return node_name
	if node_name.contains("tutorial"):
		return "tutorial_area"
	return "default"
