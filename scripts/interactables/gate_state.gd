extends RefCounted

## Stan zagadek bram poziomu w LevelStateManager (zapis gry): podniesione klucze (spawned_items, prefiks
## KEY_PREFIX) i otwarte bramy (destroyed_gates, prefiks GATE_PREFIX). Klucze są wspólne dla poziomu:
## dostępne = podniesione - użyte (każdy zamek zużywa jeden).

const KEY_PREFIX := "gate_key:"
const GATE_PREFIX := "sewer_gate:"


static func keys_available(node: Node) -> int:
	var lsm := _lsm(node)
	var path := level_path(node)
	if lsm == null or path.is_empty():
		return 0
	var state: Dictionary = lsm.get_level_state(path)
	var taken := 0
	for s in state.get("spawned_items", []):
		if String(s).begins_with(KEY_PREFIX):
			taken += 1
	var used := 0
	for s in state.get("destroyed_gates", []):
		if String(s).begins_with(GATE_PREFIX):
			used += 1
	return taken - used


static func is_key_taken(node: Node, key_id: String) -> bool:
	var lsm := _lsm(node)
	var path := level_path(node)
	return lsm != null and not path.is_empty() and lsm.is_item_spawned(path, KEY_PREFIX + key_id)


static func take_key(node: Node, key_id: String) -> void:
	var lsm := _lsm(node)
	var path := level_path(node)
	if lsm != null and not path.is_empty():
		lsm.mark_item_spawned(path, KEY_PREFIX + key_id)


static func is_gate_open(node: Node, gate_id: String) -> bool:
	var lsm := _lsm(node)
	var path := level_path(node)
	return lsm != null and not path.is_empty() and lsm.is_gate_opened(path, GATE_PREFIX + gate_id)


## Otwiera bramę (zapis + chowa jej kolce: grupa "gate:<id>").
static func open_gate(node: Node, gate_id: String) -> void:
	var lsm := _lsm(node)
	var path := level_path(node)
	if lsm != null and not path.is_empty():
		lsm.mark_gate_opened(path, GATE_PREFIX + gate_id)
	node.get_tree().call_group("gate:" + gate_id, "open")


static func singleton(node: Node, singleton_name: String) -> Node:
	var core_manager := node.get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var s: Variant = core_manager.call("get_singleton", singleton_name)
		if s is Node:
			return s
	return node.get_node_or_null("/root/%s" % singleton_name)


static func _lsm(node: Node) -> Node:
	return singleton(node, "LevelStateManager")


## Ścieżka bieżącego poziomu (jak w skrzyniach: level_manager.current_level_path).
static func level_path(node: Node) -> String:
	var tree := node.get_tree()
	if tree == null:
		return ""
	var lm: Node = null
	if tree.current_scene:
		lm = tree.current_scene.find_child("level_manager", true, false)
	if lm == null:
		var core_manager := node.get_node_or_null("/root/CoreManager")
		if core_manager and core_manager.has_method("get_active_module"):
			var module_root: Variant = core_manager.call("get_active_module")
			if module_root is Node:
				lm = (module_root as Node).find_child("level_manager", true, false)
	return str(lm.get("current_level_path")) if lm != null else ""


static func is_player(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "Player"
