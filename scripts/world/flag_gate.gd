@tool
class_name QuizRpgFlagGate
extends Node

## Pokazuje albo chowa węzeł-rodzica wg flag fabularnych (LevelStateManager) — świat reaguje na postęp: NPC pojawia się
## po bossie, bariera znika po zadaniu, dekoracja zmienia się po wydarzeniu. Dodać jako dziecko obiektu (Add Child Node →
## QuizRpgFlagGate). Ukryty rodzic jest też wyłączony (process_mode DISABLED: bez kolizji, rozmowy i logiki).
## Reaguje od razu na nowe flagi (sygnał story_flag_changed).

## Rodzic widoczny tylko z tą flagą (pusta = bez warunku), np. boss:sewer.
@export var show_flag: String = ""
## Rodzic znika, gdy ta flaga jest ustawiona (pusta = bez warunku), np. quest:most_naprawiony.
@export var hide_flag: String = ""

var _lsm: Node = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_lsm = _level_state_manager()
	if _lsm != null and _lsm.has_signal("story_flag_changed"):
		_lsm.connect("story_flag_changed", _on_flag_changed)
	_apply.call_deferred()


func _on_flag_changed(_flag: String, _value: bool) -> void:
	_apply()


## Czy rodzic powinien być widoczny przy bieżących flagach.
func is_shown() -> bool:
	if _lsm == null:
		return show_flag.is_empty()
	if not show_flag.is_empty() and not bool(_lsm.call("has_story_flag", show_flag)):
		return false
	if not hide_flag.is_empty() and bool(_lsm.call("has_story_flag", hide_flag)):
		return false
	return true


func _apply() -> void:
	var target := get_parent()
	if target == null:
		return
	var on := is_shown()
	if target is CanvasItem:
		(target as CanvasItem).visible = on
	target.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _level_state_manager() -> Node:
	var core := get_node_or_null("/root/CoreManager")
	if core and core.has_method("get_singleton"):
		var s: Variant = core.call("get_singleton", "LevelStateManager")
		if s is Node:
			return s
	return get_node_or_null("/root/LevelStateManager")
