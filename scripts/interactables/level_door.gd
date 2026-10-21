class_name QuizRpgLevelDoor
extends Area2D

## Drzwi / przejście do innej sceny pod klawiszem „interact” (E) — wejście do budynku i wyjście z wnętrza z powrotem.
## Cel: scena `target_level` i marker `target_spawn` w jej węźle Spawns (np. marker przed drzwiami w mieście).
## Obszar = CollisionShape2D dziecka (zmieniany w edytorze); podpowiedź jak przy innych przejściach (LevelPortal).
## Zamknięte drzwi: `required_flag` (flaga fabularna) — bez niej komunikat `locked_key` i brak przejścia.

const LevelPortal = preload("../maps/level_portal.gd")

@export_file("*.tscn") var target_level: String = ""
@export var target_spawn: String = "Spawn"
## Klucz tłumaczenia podpowiedzi (resources/i18n): prompt.enter „Wejdź”, prompt.exit „Wyjdź” albo własny.
@export var prompt_key: String = "prompt.enter"
## Flaga fabularna wymagana do przejścia (np. boss:sewer); pusta = zawsze otwarte.
@export var required_flag: String = ""
## Klucz tłumaczenia komunikatu przy zamkniętych drzwiach.
@export var locked_key: String = "prompt.locked"

var _transitioning := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	LevelPortal.connect_area.call_deferred(self, _on_use, true, QuizRpgI18n.t(prompt_key, "Wejdź"))


func _on_use() -> void:
	if _transitioning or target_level.is_empty():
		return
	if not is_open():
		var lm := _singleton("LootManager")
		if lm and lm.has_method("show_message_toast"):
			lm.call("show_message_toast", QuizRpgI18n.t(locked_key, "Zamknięte"))
		return
	var level_manager := QuizRpgHandmadeLevel.find_level_manager(self)
	if level_manager == null or not level_manager.has_method("change_level"):
		push_warning("[LevelDoor] brak level_manager")
		return
	_transitioning = true
	await level_manager.call("change_level", target_level, target_spawn)


## Czy drzwi są otwarte (bez wymaganej flagi albo flaga ustawiona).
func is_open() -> bool:
	if required_flag.is_empty():
		return true
	var lsm := _singleton("LevelStateManager")
	return lsm != null and bool(lsm.call("has_story_flag", required_flag))


func _singleton(n: String) -> Node:
	var core := get_node_or_null("/root/CoreManager")
	if core and core.has_method("get_singleton"):
		var s: Variant = core.call("get_singleton", n)
		if s is Node:
			return s
	return get_node_or_null("/root/" + n)
