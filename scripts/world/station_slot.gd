@tool
class_name QuizRpgStationSlot
extends Node2D

## Miejsce na rozbudowywane stanowisko pracy (kowadło, piec, stół alchemiczny…): trzyma sceny kolejnych tierów
## i pokazuje ten, który gracz już wykupił (flaga fabularna `station:<station_id>:tier<N>`, ustawia ją usługa
## QuizRpgNpcStationUpgrade). W edytorze widać tier z preview_tier. Dla NPC (QuizRpgNpc.work_station) zachowuje się jak
## stanowisko — przekazuje work_spot / start_work / stop_work bieżącemu tierowi.

## Identyfikator w nazwach flag; unikalny dla każdego slotu w grze (kilka pieców = kilka identyfikatorów).
@export var station_id: String = "":
	set(v):
		station_id = v
		if is_node_ready():
			refresh()
## Sceny tierów od najniższego (indeks 0 = tier 1).
@export var tiers: Array[PackedScene] = []:
	set(v):
		tiers = v
		if is_node_ready():
			refresh()
## Tylko podgląd w edytorze; w grze decyduje zapis.
@export_range(1, 5) var preview_tier: int = 1:
	set(v):
		preview_tier = v
		if is_node_ready():
			refresh()

var _tier := 1
var _station: Node2D


static func tier_flag(id: String, tier: int) -> String:
	return "station:%s:tier%d" % [id, tier]


func _ready() -> void:
	refresh()


func tier() -> int:
	return _tier


func max_tier() -> int:
	return tiers.size()


## Ustawia wygląd wg zapisu gry (w edytorze: preview_tier).
func refresh() -> void:
	_show(preview_tier if Engine.is_editor_hint() else _saved_tier())


func _saved_tier() -> int:
	var t := 1
	for k in range(2, tiers.size() + 1):
		if QuizRpgNpcContext.has_flag(self, tier_flag(station_id, k)):
			t = k
	return t


func _show(t: int) -> void:
	if tiers.is_empty():
		return
	_tier = clampi(t, 1, tiers.size())
	if _station != null:
		remove_child(_station)
		_station.queue_free()
		_station = null
	var scene := tiers[_tier - 1]
	if scene != null:
		_station = scene.instantiate() as Node2D
		add_child(_station)


func work_spot() -> Vector2:
	if _station != null and _station.has_method("work_spot"):
		return _station.call("work_spot")
	return global_position + Vector2(0, 7)


func start_work() -> void:
	if _station != null and _station.has_method("start_work"):
		_station.call("start_work")


func stop_work() -> void:
	if _station != null and _station.has_method("stop_work"):
		_station.call("stop_work")
