extends Node2D

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

## Utwór mapy (nazwa z music_tracks.json hosta) — gra go LevelManager.
@export var music_track: String = "tutorial"

static var NEXT_LEVEL_PATH: String = QuizRpgPaths.path("scenes/maps/levels/cave.tscn")
const NEXT_SPAWN_NAME := "Spawn"
## Marker w Spawns, przy którym gracz pojawia się po powrocie z jaskini (cave.tscn: previous_spawn_name),
## odsunięty od obszaru wyjścia (ustawiany w edytorze).
const FROM_CAVES_SPAWN := "Tutorial-Caves"
const LevelPortal = preload("level_portal.gd")
const MapPrefetch = preload("map_prefetch.gd")
const MapLinks = preload("map_links.gd")

## Krawędź mapy, którą wychodzi się do jaskini (spójna trasa map, MapLinks): schody na górze ruin = N. Jaskinia ma wtedy
## wejście od południa.
@export_enum("N", "E", "S", "W") var exit_edge: int = 0

var _transitioning: bool = false


func _ready() -> void:
	_record_link()
	# Jaskinia liczy się w tle, gdy gracz jest w ruinach — wejście bez czekania na generowanie.
	MapPrefetch.request.call_deferred(NEXT_LEVEL_PATH)
	var next_level_area := get_node_or_null(LevelPortal.NEXT_AREA) as Area2D
	if next_level_area == null:
		return
	# Brak markera powrotu w scenie — awaryjnie w obszarze wyjścia (zadziała po jego opuszczeniu).
	if get_node_or_null("Spawns/" + FROM_CAVES_SPAWN) == null:
		var shape := next_level_area.get_node_or_null("CollisionShape2D") as Node2D
		LevelPortal.place_marker(self, FROM_CAVES_SPAWN, to_local((shape if shape else next_level_area).global_position))
	# Po add_child poziomu level_manager ustawia current_spawn_name — stąd podpięcie odroczone.
	_connect_next_area.call_deferred(next_level_area)


func _connect_next_area(area: Area2D) -> void:
	LevelPortal.connect_area(area, _on_enter_next_level)


func _on_enter_next_level() -> void:
	if _transitioning:
		return
	var level_manager := _get_level_manager()
	if level_manager == null or not level_manager.has_method("change_level"):
		push_warning("[TutorialArea] Missing level manager.")
		return
	_transitioning = true
	await level_manager.call("change_level", NEXT_LEVEL_PATH, NEXT_SPAWN_NAME)


## Ruiny w trasie map (przed zleceniem jaskini w tle — jaskinia liczy wejście z tego wpisu).
func _record_link() -> void:
	var lsm: Node = null
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		lsm = core_manager.call("get_singleton", "LevelStateManager") as Node
	if lsm == null:
		lsm = get_node_or_null("/root/LevelStateManager")
	if lsm != null and not scene_file_path.is_empty():
		MapLinks.record(lsm.map_links, QuizRpgPaths.level_name(scene_file_path), {}, exit_edge)


func _get_level_manager() -> Node:
	var scene := get_tree().current_scene
	if scene:
		var level_manager := scene.find_child("level_manager", true, false)
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
