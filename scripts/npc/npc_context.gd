class_name QuizRpgNpcContext
extends RefCounted

## Wspólne pomocniki NPC i ich usług: singletony modułu (przez CoreManager), flagi fabularne, przedmioty, tekst.

static func singleton(node: Node, singleton_name: String) -> Node:
	var cm := node.get_node_or_null("/root/CoreManager")
	if cm and cm.has_method("get_singleton"):
		var s: Variant = cm.call("get_singleton", singleton_name)
		if s is Node:
			return s
	return node.get_node_or_null("/root/%s" % singleton_name)


static func player_stats(node: Node) -> Node:
	return singleton(node, "PlayerStats")


## Flaga fabularna (LevelStateManager: flaga rozmowy / zadania albo pokonany story-boss), zapisywana z grą.
static func has_flag(node: Node, flag: String) -> bool:
	if flag == "":
		return true
	var lsm := singleton(node, "LevelStateManager")
	return lsm != null and lsm.has_method("has_story_flag") and bool(lsm.call("has_story_flag", flag))


static func set_flag(node: Node, flag: String) -> void:
	var lsm := singleton(node, "LevelStateManager")
	if flag != "" and lsm != null and lsm.has_method("set_story_flag"):
		lsm.call("set_story_flag", flag)


static func item(node: Node, item_id: String) -> QuizRpgItemData:
	var inv := singleton(node, "InventoryService")
	if inv and inv.has_method("get_item") and item_id != "":
		return inv.call("get_item", item_id) as QuizRpgItemData
	return null


static func item_name(node: Node, item_id: String) -> String:
	var it := item(node, item_id)
	return it.localized_name() if it != null else item_id


## Linie rozmowy w wybranym języku: klucz `<key_prefix>_<n>` (od 1), zapasowo tekst z listy.
static func lines(texts: PackedStringArray, key_prefix: String, args: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	for i in texts.size():
		var t := QuizRpgI18n.t("%s_%d" % [key_prefix, i + 1], texts[i]) if key_prefix != "" else texts[i]
		out.append(t.format(args) if not args.is_empty() else t)
	return out


static func play_sfx(node: Node, sfx: String) -> void:
	var audio := node.get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_sfx_by_name"):
		audio.play_sfx_by_name(sfx)
