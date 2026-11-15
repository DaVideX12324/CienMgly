extends RefCounted

## Przejście zamknięte do pokonania bossa w mapach ręcznych (polana, miasto → ścieki): wymagana flaga fabularna
## (np. boss:tutorial_area) i komunikat, gdy jej brak. Mapy generowane mają własną blokadę (procedural_level:
## "boss": {"locks_exit": true}).


## Czy przejście jest otwarte (pusta flaga = zawsze).
static func is_open(node: Node, flag: String) -> bool:
	if flag.is_empty():
		return true
	var lsm := singleton(node, "LevelStateManager")
	return lsm != null and bool(lsm.call("has_story_flag", flag))


## Sprawdza przejście; zamknięte = komunikat (klucz i18n) i false.
static func try_pass(node: Node, flag: String, locked_key: String, fallback: String) -> bool:
	if is_open(node, flag):
		return true
	var loot := singleton(node, "LootManager")
	if loot and loot.has_method("show_message_toast"):
		loot.call("show_message_toast", QuizRpgI18n.t(locked_key, fallback))
	return false


static func singleton(node: Node, singleton_name: String) -> Node:
	var core := node.get_node_or_null("/root/CoreManager")
	if core and core.has_method("get_singleton"):
		var s: Variant = core.call("get_singleton", singleton_name)
		if s is Node:
			return s
	return node.get_node_or_null("/root/" + singleton_name)
