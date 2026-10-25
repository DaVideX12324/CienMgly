class_name QuizRpgHandmadeLevel
extends Node2D

## Mapa robiona ręcznie w edytorze (miasto, wnętrza budynków) w trasie map. Przejścia: obszary Area2D
## `enter_next_level` / `enter_previous_level` (LevelPortal — metadana `portal_use_key` = przejście pod E), punkty
## pojawienia się: Marker2D w węźle Spawns (nazwy podają sąsiednie mapy: ich next_spawn_name / previous_spawn_name).
## Mapa zapisuje się w spójnej trasie (MapLinks) z krawędzią wejścia i wyjścia z układu sceny, a sąsiednie mapy
## generowane liczą się w tle (MapPrefetch), gdy gracz tu jest. Drzwi do wnętrz: QuizRpgLevelDoor.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const LevelPortal = preload("level_portal.gd")
const MapPrefetch = preload("map_prefetch.gd")
const MapLinks = preload("map_links.gd")
const Freeroam = preload("freeroam.gd")

## Mapa za wyjściem `enter_next_level` i marker, przy którym gracz się tam pojawia.
@export_file("*.tscn") var next_level_path: String = ""
@export var next_spawn_name: String = "Spawn"
## Mapa za wyjściem `enter_previous_level` i marker na niej (mapy generowane: FromNext — przy ich wyjściu).
@export_file("*.tscn") var previous_level_path: String = ""
@export var previous_spawn_name: String = LevelPortal.FROM_NEXT_SPAWN
## Krawędź mapy, którą się wchodzi z poprzedniej (MapLinks: 0 N, 1 E, 2 S, 3 W; -1 = bez krawędzi, np. drzwi).
## Poprzednia mapa generowana powinna mieć next_entry_edge = ta sama wartość (wyjście po przeciwnej stronie).
@export_enum("Brak:-1", "N:0", "E:1", "S:2", "W:3") var entry_edge: int = -1
## Krawędź, którą się wychodzi do następnej mapy (ta wejdzie z przeciwnej strony).
@export_enum("Brak:-1", "N:0", "E:1", "S:2", "W:3") var exit_edge: int = -1
## Czy mapa jest w głównej trasie (MapLinks). Wnętrza budynków: nie.
@export var in_route := true
## Utwór muzyki (AudioService); pusty = wg ścieżki sceny (level_manager).
@export var music_track: String = ""

var _transitioning := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if Freeroam.is_standalone(self):   # F6 na scenie mapy: swobodne zwiedzanie, bez zapisu trasy i generowania sąsiednich map
		Freeroam.start(self)
		return
	var lsm := _level_state_manager()
	if lsm != null and not scene_file_path.is_empty():
		lsm.set_story_flag("visited:" + QuizRpgPaths.level_name(scene_file_path))   # np. visited:town (boss powrotu w jaskiniach)
	if in_route:
		_record_link()
	# Sąsiednie mapy generowane liczą się w tle, póki gracz tu jest (MapPrefetch pomija mapy ręczne).
	for p in [next_level_path, previous_level_path]:
		if not p.is_empty():
			MapPrefetch.request.call_deferred(p)
	# Po add_child poziomu level_manager ustawia current_spawn_name — stąd podpięcie odroczone.
	_connect_areas.call_deferred()


func _connect_areas() -> void:
	var next_area := get_node_or_null(LevelPortal.NEXT_AREA) as Area2D
	if next_area != null and not next_level_path.is_empty():
		LevelPortal.connect_area(next_area, _change_level.bind(next_level_path, next_spawn_name))
	var prev_area := get_node_or_null(LevelPortal.PREVIOUS_AREA) as Area2D
	if prev_area != null and not previous_level_path.is_empty():
		LevelPortal.connect_area(prev_area, _change_level.bind(previous_level_path, previous_spawn_name))


func _change_level(path: String, spawn: String) -> void:
	if _transitioning:
		return
	var lm := find_level_manager(self)
	if lm == null or not lm.has_method("change_level"):
		push_warning("[HandmadeLevel] brak level_manager")
		return
	_transitioning = true
	await lm.call("change_level", path, spawn)


## Wpis w trasie map: pole na siatce świata z poprzedniej mapy, krawędzie wejścia / wyjścia z układu sceny.
func _record_link() -> void:
	var lsm := _level_state_manager()
	if lsm == null or scene_file_path.is_empty():
		return
	var name := QuizRpgPaths.level_name(scene_file_path)
	var cons := MapLinks.constraints(lsm.map_links, name, QuizRpgPaths.level_name(previous_level_path))
	cons["in"] = entry_edge
	cons["allow"] = [exit_edge] if exit_edge >= 0 else []
	MapLinks.record(lsm.map_links, name, cons, exit_edge)


func _level_state_manager() -> Node:
	var core := get_node_or_null("/root/CoreManager")
	if core and core.has_method("get_singleton"):
		var s: Variant = core.call("get_singleton", "LevelStateManager")
		if s is Node:
			return s
	return get_node_or_null("/root/LevelStateManager")


## level_manager gry (scena gry albo aktywny moduł) — też dla drzwi i innych przejść.
static func find_level_manager(from: Node) -> Node:
	var tree := from.get_tree()
	var cur := tree.current_scene if tree else null
	if cur:
		var lm := cur.find_child("level_manager", true, false)
		if lm:
			return lm
	var core := from.get_node_or_null("/root/CoreManager")
	if core and core.has_method("get_active_module"):
		var mr: Variant = core.call("get_active_module")
		if mr is Node:
			return (mr as Node).find_child("level_manager", true, false)
	return null
