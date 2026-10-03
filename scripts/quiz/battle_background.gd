extends Control

## Tło walki wg klucza mapy (_map_key): najpierw grafiki z folderu mapy (FolderGenerator:
## battle_backgrounds/<klucz>/ albo battle_backgrounds/pixel_crawler/<klucz>/), gdy folderu z grafikami
## nie ma — tło rysowane w kodzie (GENERATORS, „default” na końcu). Nowa mapa = nowy folder, bez kodu.
const FolderGenerator: Script = preload("background_generators/folder_battle_background.gd")

const GENERATORS: Dictionary = {
	"world_map": preload("background_generators/world_map_battle_background.gd"),
	"default": preload("background_generators/default_battle_background.gd"),
}
## Klucz mapy -> folder teł walki, gdy mapa nie ma własnego (las generowany -> baśniowy las).
const KEY_ALIASES: Dictionary = {
	"forest": "fairy_forest",
}
## Słowa w ścieżce skryptu / nazwie węzła mapy -> klucz (mapy bez get_map_key, biome ani sceny z folderem).
const NAME_KEYWORDS: Array = [
	["world_map", "world_map"], ["tutorial", "tutorial_area"], ["castle", "castle"], ["cave", "cave"],
	["desert", "desert"], ["fairy", "fairy_forest"], ["forge", "forge"], ["garden", "garden"],
	["hideout", "hideout"], ["dungeon", "castle"],
]

signal layout_changed(layout: BattleBackgroundLayout)

var _map_node: Node
var _enemy: Node
var _player: Node
var _enemy_units: Array = []
var _generator: RefCounted


func _ready() -> void:
	resized.connect(func() -> void: queue_redraw())
	_select_generator()


## Wymiary pola walki dla bieżącego tła (plik `<grafika>_layout.tres`; brak — wartości domyślne).
func get_layout() -> BattleBackgroundLayout:
	if _generator == null:
		_select_generator()
	var layout: BattleBackgroundLayout = null
	if _generator != null and _generator.has_method("get_layout_key"):
		layout = BattleBackgroundLayout.load_for(str(_generator.call("get_layout_key")))
	return layout if layout != null else BattleBackgroundLayout.new()


func set_context(map_node: Node, enemy: Node, player: Node, enemy_units: Array = []) -> void:
	_map_node = map_node
	_enemy = enemy
	_player = player
	_enemy_units = enemy_units.duplicate(true)
	_select_generator()
	layout_changed.emit(get_layout())
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
	var variants: PackedStringArray = FolderGenerator.variant_paths(_folder_key(key))
	if not variants.is_empty():
		_generator = FolderGenerator.new(variants)
	else:
		_generator = (GENERATORS.get(key, GENERATORS["default"]) as Script).new()


func _folder_key(key: String) -> String:
	return str(KEY_ALIASES.get(key, key))


## Ma tło: folder z grafikami albo generator w kodzie.
func _has_background(key: String) -> bool:
	return key != "" and (GENERATORS.has(key) or not FolderGenerator.variant_paths(_folder_key(key)).is_empty())


## Klucz mapy — ten sam co folder ekranu ładowania: get_map_key() mapy (ProceduralLevel: loading_screen_key
## albo biom z typu poziomu), właściwości biome / theme…, nazwa pliku sceny mapy ręcznej (tutorial_area),
## na końcu słowa w ścieżce skryptu / nazwie węzła. Pierwszy klucz, który ma tło.
func _map_key(map_node: Node) -> String:
	if map_node == null:
		return "default"
	var candidates: Array[String] = []
	if map_node.has_method("get_map_key"):
		candidates.append(str(map_node.call("get_map_key")))
	for prop in ["biome", "theme", "dungeon_theme", "dungeon_type", "background_type"]:
		if prop in map_node:
			candidates.append(str(map_node.get(prop)).to_snake_case())
		if map_node.has_meta(prop):
			candidates.append(str(map_node.get_meta(prop)).to_snake_case())
	if map_node.scene_file_path != "":
		candidates.append(map_node.scene_file_path.get_file().get_basename())
	candidates.append(str(map_node.name).to_snake_case())
	for key in candidates:
		if _has_background(key):
			return key
	var script: Script = map_node.get_script() as Script
	var haystacks: Array[String] = [str(map_node.name).to_snake_case()]
	if script != null:
		haystacks.push_front(script.resource_path.to_snake_case())
	for text in haystacks:
		for pair in NAME_KEYWORDS:
			if text.contains(pair[0]):
				return pair[1]
	return "default"
