extends RefCounted

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

## Towarzysze drużyny idący za liderem na mapie: instancje sceny aktora członka (player.tscn) w trybie
## is_party_follower, w węźle PartyFollowers obok gracza (ten sam rodzic — to samo sortowanie). Każdy idzie po
## śladzie poprzedniego. Lider (party[0], szyk) dostaje grafikę swojej postaci na węźle gracza. Przebudowa tylko przy
## zmianie składu albo szyku (hero_id członków w kolejności).

const HOLDER_NAME := "PartyFollowers"
const FOLLOW_SPACING := 28.0
const PLAYER_SCENE := "scenes/player/player.tscn"


## Dopasowuje towarzyszy do składu drużyny (PlayerStats.get_party_members).
static func sync(leader: CharacterBody2D, ps: Node) -> void:
	if leader == null or ps == null or not ps.has_method("get_party_members") or leader.get_parent() == null:
		return
	var members: Array[Dictionary] = ps.get_party_members()
	var ids := PackedStringArray()
	for m in members:
		ids.append(str(m.get("hero_id", "")))
	var holder := _holder(leader)
	if holder.get_meta(&"hero_ids", PackedStringArray()) == ids:
		return
	if not members.is_empty() and leader.has_method("apply_hero_data"):
		leader.call("apply_hero_data", members[0])
	for child in holder.get_children():
		holder.remove_child(child)   # od razu z drzewa — nowe dostają te same nazwy
		child.queue_free()
	var prev: CharacterBody2D = leader
	for i in range(1, members.size()):
		var member: Dictionary = members[i]
		var scene := member.get("actor_scene") as PackedScene
		if scene == null:
			scene = load(QuizRpgPaths.path(PLAYER_SCENE)) as PackedScene
		var node := scene.instantiate() if scene else null
		if not (node is CharacterBody2D):
			if node:
				node.free()
			continue
		var follower := node as CharacterBody2D
		follower.name = "Follower%d" % i
		holder.add_child(follower)
		follower.global_position = leader.global_position
		if follower.has_method("apply_hero_data"):
			follower.call("apply_hero_data", member)
		if follower.has_method("set_follow_target"):
			follower.call("set_follow_target", prev, FOLLOW_SPACING)
		prev = follower
	holder.set_meta(&"hero_ids", ids)


## Po przeniesieniu lidera (spawn na nowej mapie): towarzysze na jego pozycji, ślady wyczyszczone.
static func snap_to_leader(leader: CharacterBody2D) -> void:
	if leader == null:
		return
	if leader.has_method("reset_trail"):
		leader.call("reset_trail")
	var holder := leader.get_parent().get_node_or_null(HOLDER_NAME) if leader.get_parent() else null
	if holder == null:
		return
	for f in holder.get_children():
		if f is Node2D:
			(f as Node2D).global_position = leader.global_position
			if f.has_method("reset_trail"):
				f.call("reset_trail")


static func _holder(leader: CharacterBody2D) -> Node2D:
	var parent := leader.get_parent()
	var holder := parent.get_node_or_null(HOLDER_NAME) as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = HOLDER_NAME
		parent.add_child(holder)
	holder.y_sort_enabled = true   # towarzysze sortowani z graczem i ścianami (bez tego cała grupa w jednym miejscu)
	return holder
