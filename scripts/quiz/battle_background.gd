extends Control

const PIXEL_CRAWLER_GENERATOR: Script = preload("res://modules/quiz_rpg/scripts/quiz/background_generators/pixel_crawler_battle_background.gd")

const GENERATORS: Dictionary = {
	"world_map": preload("res://modules/quiz_rpg/scripts/quiz/background_generators/world_map_battle_background.gd"),
	"tutorial_area": preload("res://modules/quiz_rpg/scripts/quiz/background_generators/tutorial_area_battle_background.gd"),
	"castle": PIXEL_CRAWLER_GENERATOR,
	"cave": PIXEL_CRAWLER_GENERATOR,
	"desert": PIXEL_CRAWLER_GENERATOR,
	"fairy_forest": PIXEL_CRAWLER_GENERATOR,
	"forge": PIXEL_CRAWLER_GENERATOR,
	"garden": PIXEL_CRAWLER_GENERATOR,
	"hideout": PIXEL_CRAWLER_GENERATOR,
	"pixel_crawler": PIXEL_CRAWLER_GENERATOR,
	"default": preload("res://modules/quiz_rpg/scripts/quiz/background_generators/default_battle_background.gd"),
}

signal layout_config_changed(config: Dictionary)

var _map_node: Node
var _enemy: Node
var _player: Node
var _enemy_units: Array = []
var _generator: RefCounted


func _ready() -> void:
	resized.connect(func() -> void: queue_redraw())
	_select_generator()


func get_enemy_layout_config() -> Dictionary:
	if _generator == null:
		_select_generator()
	if _generator != null and _generator.has_method("get_enemy_layout_config"):
		return _generator.call("get_enemy_layout_config")
	return {
		"enemy_section_height": 340.0,
		"enemy_section_bottom_offset": -35.0,
		"row2_margin_multiplier": 1.0,
		"row1_margin_multiplier": 1.0,
	}


func set_context(map_node: Node, enemy: Node, player: Node, enemy_units: Array = []) -> void:
	_map_node = map_node
	_enemy = enemy
	_player = player
	_enemy_units = enemy_units.duplicate(true)
	_select_generator()
	layout_config_changed.emit(get_enemy_layout_config())
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
	if generator_script == PIXEL_CRAWLER_GENERATOR:
		_generator = generator_script.new(key)
	else:
		_generator = generator_script.new()


func _map_key(map_node: Node) -> String:
	if map_node == null:
		return "default"
	for prop in ["biome", "theme", "dungeon_theme", "dungeon_type", "background_type"]:
		if prop in map_node and str(map_node.get(prop)) != "":
			var val: String = str(map_node.get(prop)).to_snake_case()
			if GENERATORS.has(val):
				return val
		if map_node.has_meta(prop):
			var val_meta: String = str(map_node.get_meta(prop)).to_snake_case()
			if GENERATORS.has(val_meta):
				return val_meta

	var script: Script = map_node.get_script() as Script
	if script != null:
		var path: String = script.resource_path.to_snake_case()
		if path.ends_with("/world_map.gd"):
			return "world_map"
		if path.ends_with("/tutorial_area.gd") or path.contains("tutorial_area"):
			return "tutorial_area"
		if path.contains("castle"):
			return "castle"
		if path.contains("cave"):
			return "cave"
		if path.contains("desert"):
			return "desert"
		if path.contains("fairy"):
			return "fairy_forest"
		if path.contains("forge"):
			return "forge"
		if path.contains("garden"):
			return "garden"
		if path.contains("hideout"):
			return "hideout"
		if path.contains("dungeon"):
			return "castle"

	var node_name: String = str(map_node.name).to_snake_case()
	if GENERATORS.has(node_name):
		return node_name
	if node_name.contains("tutorial"):
		return "tutorial_area"
	if node_name.contains("castle"):
		return "castle"
	if node_name.contains("cave"):
		return "cave"
	if node_name.contains("desert"):
		return "desert"
	if node_name.contains("fairy"):
		return "fairy_forest"
	if node_name.contains("forge"):
		return "forge"
	if node_name.contains("garden"):
		return "garden"
	if node_name.contains("hideout"):
		return "hideout"
	if node_name.contains("dungeon"):
		return "castle"
	return "default"
