extends Node2D
class_name ProceduralLevel

## Scena poziomu generowanego proceduralnie dla modulu Quiz RPG.
## W pelni kompatybilna z LevelManager i systemem zapisu.

const MapGeneratorBaseScript = preload("res://modules/quiz_rpg/scripts/generation/map_generator_base.gd")
const OverworldForestGeneratorScript = preload("res://modules/quiz_rpg/scripts/generation/overworld_forest_generator.gd")
const DungeonGeneratorScript = preload("res://modules/quiz_rpg/scripts/generation/dungeon_generator.gd")
const CaveGeneratorScript = preload("res://modules/quiz_rpg/scripts/generation/cave_generator.gd")

enum LevelType {
	FOREST_OVERWORLD,
	DUNGEON_CASTLE,
	CAVE_DUNGEON
}

@export var level_type: LevelType = LevelType.FOREST_OVERWORLD
@export var map_seed: int = 0
@export var map_width: int = 60
@export var map_height: int = 60
@export var custom_tileset: TileSet = null
@export var enemy_scenes: Array[PackedScene] = []
@export var chest_scene: PackedScene = null
@export var door_scene: PackedScene = null
@export var next_level_path: String = ""
@export var next_spawn_name: String = "Spawn"

var last_result: RefCounted = null
var _transitioning: bool = false


func _ready() -> void:
	y_sort_enabled = true
	_ensure_default_resources()
	generate_level(map_seed)
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		if level_type == LevelType.DUNGEON_CASTLE:
			audio.play_music("castle")
		elif level_type == LevelType.CAVE_DUNGEON:
			audio.play_music("caves")
		else:
			audio.play_music("fairy_forest")


func _ensure_default_resources() -> void:
	if enemy_scenes.is_empty():
		var enemy_paths: Array[String] = []
		if level_type == LevelType.CAVE_DUNGEON:
			enemy_paths = [
				"res://modules/quiz_rpg/scenes/enemies/slime_tutorial.tscn",
				"res://modules/quiz_rpg/scenes/enemies/slime_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/slime_tutorial_boss.tscn"
			]
		elif level_type == LevelType.FOREST_OVERWORLD:
			enemy_paths = [
				"res://modules/quiz_rpg/scenes/enemies/slime_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/plant_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/warhog.tscn"
			]
		else:
			enemy_paths = [
				"res://modules/quiz_rpg/scenes/enemies/bandit_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/ork_1.tscn",
				"res://modules/quiz_rpg/scenes/enemies/knowledge_guardian.tscn"
			]
		for ep in enemy_paths:
			if ResourceLoader.exists(ep):
				var p := load(ep) as PackedScene
				if p:
					enemy_scenes.append(p)

	if chest_scene == null:
		var cp := "res://modules/quiz_rpg/scenes/objects/closed_chest_tutorial.tscn"
		if ResourceLoader.exists(cp):
			chest_scene = load(cp) as PackedScene

	if door_scene == null and level_type == LevelType.DUNGEON_CASTLE:
		var dp := "res://modules/quiz_rpg/scenes/objects/tutorial_area/door_horizontal.tscn"
		if ResourceLoader.exists(dp):
			door_scene = load(dp) as PackedScene


func generate_level(seed_val: int = 0) -> void:
	var actual_seed: int = seed_val if seed_val > 0 else (map_seed if map_seed > 0 else int(randi() % 1000000))
	var palette: Dictionary = {}
	var gen_result: RefCounted = null
	
	match level_type:
		LevelType.CAVE_DUNGEON:
			palette = CaveGeneratorScript.get_default_palette()
			gen_result = CaveGeneratorScript.generate(map_width, map_height, actual_seed)
		LevelType.FOREST_OVERWORLD:
			palette = OverworldForestGeneratorScript.get_default_palette()
			gen_result = OverworldForestGeneratorScript.generate(map_width, map_height, actual_seed)
		LevelType.DUNGEON_CASTLE:
			palette = DungeonGeneratorScript.get_default_palette()
			gen_result = DungeonGeneratorScript.generate(map_width, map_height, actual_seed)
			
	last_result = gen_result
	
	# 1. TileSet
	var ts := custom_tileset
	if ts == null:
		if level_type == LevelType.CAVE_DUNGEON:
			var cave_ts_path: String = palette.get("tileset_path", "res://modules/quiz_rpg/resources/tilemaps/caves.tres")
			if ResourceLoader.exists(cave_ts_path):
				ts = load(cave_ts_path) as TileSet
		if ts == null:
			var tex_path: String = palette.get("texture_path", "")
			var col_tiles: Array = palette.get("collision_tiles", [])
			ts = MapGeneratorBaseScript.create_default_tileset(tex_path, col_tiles)
		
	# 2. Warstwy TileMapLayer
	var floor_layer := _get_or_create_layer("Floor", -2, ts)
	var floor_decor := _get_or_create_layer("FloorDecor", -1, ts)
	var walls_layer := _get_or_create_layer("Walls", 0, ts)
	
	var rng := MapGeneratorBaseScript.create_rng(actual_seed)
	if level_type == LevelType.CAVE_DUNGEON:
		CaveGeneratorScript.apply_cave_tiles(floor_layer, walls_layer, gen_result, rng, floor_decor)
	else:
		if floor_decor:
			floor_decor.clear()
		MapGeneratorBaseScript.apply_grid_to_layers(floor_layer, walls_layer, gen_result, palette, rng)
	
	# 3. Encje (gracz, wrogowie, skrzynie)
	MapGeneratorBaseScript.spawn_entities(self, gen_result, enemy_scenes, chest_scene, door_scene)
	
	# 4. Nawigacja 2D
	MapGeneratorBaseScript.setup_navigation_region(self, gen_result)
	
	# 5. Podepnij wyjscie
	_connect_exit_trigger()


func _get_or_create_layer(layer_name: String, z_idx: int, ts: TileSet) -> TileMapLayer:
	var layer := get_node_or_null(layer_name) as TileMapLayer
	if not layer:
		layer = TileMapLayer.new()
		layer.name = layer_name
		add_child(layer)
	layer.tile_set = ts
	layer.z_index = z_idx
	layer.y_sort_enabled = true
	return layer


func _connect_exit_trigger() -> void:
	var exit_area := get_node_or_null("enter_next_level") as Area2D
	if exit_area and not exit_area.body_entered.is_connected(_on_exit_body_entered):
		exit_area.body_entered.connect(_on_exit_body_entered)


func _on_exit_body_entered(body: Node2D) -> void:
	if _transitioning:
		return
	if not (body.is_in_group("player") or body.name == "Player"):
		return
	if next_level_path.is_empty():
		return
		
	var level_manager := _find_level_manager()
	if level_manager and level_manager.has_method("change_level"):
		_transitioning = true
		level_manager.call("change_level", next_level_path, next_spawn_name)


func _find_level_manager() -> Node:
	var cur := get_tree().current_scene
	if cur:
		var lm := cur.find_child("level_manager", true, false)
		if lm:
			return lm
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_active_module"):
		var module_root: Variant = core_manager.call("get_active_module")
		if module_root is Node:
			return (module_root as Node).find_child("level_manager", true, false)
	return null
