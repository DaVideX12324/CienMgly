@tool
extends EditorScript

## Naprawia dziedziczenie scen przeciwnikow zlamane przez wczesniejszy
## fix_amonra_collision_shapes.gd (load()/instantiate()/pack()/save()
## zawsze splaszcza scene, tracac relacje "instance=" do bazowej sceny).
##
## Ten tool automatycznie wykrywa zlamane sceny (root zadeklarowany jako
## type="CharacterBody2D" zamiast instance=ExtResource(...)), odczytuje
## ich OBECNE wartosci (staty, skrypt, sprite_frames, ksztalt kolizji)
## przez introspekcje, i przepisuje plik jako tekst z prawdziwym
## dziedziczeniem po enemy.tscn -- analogicznie do recznie napisanego
## bandit_1.tscn. Sceny juz poprawnie dziedziczone (np. bandit_1,
## math_golem) sa automatycznie pomijane.
##
## Uzycie: Godot Script Editor -> otworz plik -> Ctrl+Shift+X (File -> Run).

const SCENES_DIR := "res://modules/quiz_rpg/scenes/enemies/"
const BASE_SCENE_REL := "enemy.tscn"
const SCRIPTS_DIR := "res://modules/quiz_rpg/scripts/enemies/"
const SPRITES_DIR := "res://modules/quiz_rpg/resources/enemies/"


func _run() -> void:
	var dir := DirAccess.open(SCENES_DIR)
	if dir == null:
		push_error("Nie znaleziono folderu: %s" % SCENES_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var fixed := 0
	var skipped: Array[String] = []

	while file_name != "":
		if file_name.ends_with(".tscn") and file_name != "enemy.tscn":
			var full_path := SCENES_DIR + file_name
			if _needs_fix(full_path):
				if _rebuild_one(full_path, file_name):
					fixed += 1
				else:
					skipped.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Naprawiono dziedziczenie: %d. Pominieto/juz OK: %s" % [fixed, str(skipped)])


func _needs_fix(scene_path: String) -> bool:
	var text := FileAccess.get_file_as_string(scene_path)
	if text.is_empty():
		return false
	var re := RegEx.new()
	re.compile("\\[node name=\"[^\"]*\"\\s+type=\"CharacterBody2D\"")
	return re.search(text) != null


func _rebuild_one(scene_path: String, file_name: String) -> bool:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return false
	var root: Node = packed.instantiate()
	if root == null:
		return false

	var script_res: Script = root.get_script()
	var script_path := ""
	if script_res:
		script_path = script_res.resource_path

	var sprite := root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var sprite_frames_path := ""
	var animation_name := "idle_down"
	if sprite:
		if sprite.sprite_frames:
			sprite_frames_path = sprite.sprite_frames.resource_path
		if str(sprite.animation) != "":
			animation_name = str(sprite.animation)

	var collision := root.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var cap_radius := 0.0
	var cap_height := 0.0
	var cap_pos := Vector2.ZERO
	var cap_rot := 0.0
	if collision and collision.shape is CapsuleShape2D:
		var cap := collision.shape as CapsuleShape2D
		cap_radius = cap.radius
		cap_height = cap.height
		cap_pos = collision.position
		cap_rot = collision.rotation

	var props := _read_enemy_base_props(root)
	var rel_script := _to_relative_script_path(script_path)
	var rel_sprite := _to_relative_sprite_path(sprite_frames_path)

	var content := _build_scene_text(rel_script, rel_sprite, animation_name, props, cap_radius, cap_height, cap_pos, cap_rot)

	root.queue_free()

	var f := FileAccess.open(scene_path, FileAccess.WRITE)
	if f == null:
		push_warning("Nie mozna zapisac: %s" % scene_path)
		return false
	f.store_string(content)
	f.close()
	print("Naprawiono dziedziczenie: %s" % file_name)
	return true


func _read_enemy_base_props(root: Node) -> Dictionary:
	return {
		"enemy_name": str(root.get("enemy_name")),
		"quiz_id": str(root.get("quiz_id")),
		"quiz_category": str(root.get("quiz_category")),
		"question_count": int(root.get("question_count")),
		"hp": int(root.get("hp")),
		"max_hp": int(root.get("max_hp")),
		"damage_on_wrong": int(root.get("damage_on_wrong")),
		"xp_reward": int(root.get("xp_reward")),
		"encounter_tier": int(root.get("encounter_tier")),
		"min_encounter_size": int(root.get("min_encounter_size")),
		"max_encounter_size": int(root.get("max_encounter_size")),
		"is_boss": bool(root.get("is_boss")),
		"patrol_speed": float(root.get("patrol_speed")),
		"detection_radius": float(root.get("detection_radius")),
	}


func _to_relative_script_path(abs_path: String) -> String:
	if abs_path == "":
		return ""
	if abs_path.begins_with(SCRIPTS_DIR):
		return "../../scripts/enemies/" + abs_path.substr(SCRIPTS_DIR.length())
	return abs_path


func _to_relative_sprite_path(abs_path: String) -> String:
	if abs_path == "":
		return ""
	if abs_path.begins_with(SPRITES_DIR):
		return "../../resources/enemies/" + abs_path.substr(SPRITES_DIR.length())
	return abs_path


func _build_scene_text(rel_script: String, rel_sprite: String, animation_name: String, props: Dictionary, cap_radius: float, cap_height: float, cap_pos: Vector2, cap_rot: float) -> String:
	var load_steps := 2
	var ext := "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_base\"]\n" % BASE_SCENE_REL

	var script_id := ""
	if rel_script != "":
		load_steps += 1
		ext += "[ext_resource type=\"Script\" path=\"%s\" id=\"2_script\"]\n" % rel_script
		script_id = "2_script"

	var frames_id := ""
	if rel_sprite != "":
		load_steps += 1
		ext += "[ext_resource type=\"SpriteFrames\" path=\"%s\" id=\"3_frames\"]\n" % rel_sprite
		frames_id = "3_frames"

	var sub_resources := ""
	if cap_radius > 0.0:
		load_steps += 1
		sub_resources = "\n[sub_resource type=\"CapsuleShape2D\" id=\"CapsuleShape2D_fix\"]\nradius = %.3f\nheight = %.3f\n" % [cap_radius, cap_height]

	var content := "[gd_scene load_steps=%d format=3]\n\n%s%s\n" % [load_steps, ext, sub_resources]
	content += "[node name=\"Enemy\" instance=ExtResource(\"1_base\")]\n"
	if script_id != "":
		content += "script = ExtResource(\"%s\")\n" % script_id
	content += "enemy_name = \"%s\"\n" % props["enemy_name"]
	content += "quiz_id = \"%s\"\n" % props["quiz_id"]
	content += "quiz_category = \"%s\"\n" % props["quiz_category"]
	content += "question_count = %d\n" % props["question_count"]
	content += "hp = %d\n" % props["hp"]
	content += "max_hp = %d\n" % props["max_hp"]
	content += "damage_on_wrong = %d\n" % props["damage_on_wrong"]
	content += "xp_reward = %d\n" % props["xp_reward"]
	content += "encounter_tier = %d\n" % props["encounter_tier"]
	content += "min_encounter_size = %d\n" % props["min_encounter_size"]
	content += "max_encounter_size = %d\n" % props["max_encounter_size"]
	content += "is_boss = %s\n" % ("true" if props["is_boss"] else "false")
	content += "patrol_speed = %.1f\n" % props["patrol_speed"]
	content += "detection_radius = %.1f\n" % props["detection_radius"]

	if frames_id != "":
		content += "\n[node name=\"AnimatedSprite2D\" parent=\".\" index=\"0\"]\n"
		content += "sprite_frames = ExtResource(\"%s\")\n" % frames_id
		content += "animation = &\"%s\"\n" % animation_name

	if cap_radius > 0.0:
		content += "\n[node name=\"CollisionShape2D\" parent=\".\" index=\"1\"]\n"
		content += "position = Vector2(%.2f, %.2f)\n" % [cap_pos.x, cap_pos.y]
		content += "rotation = %.6f\n" % cap_rot
		content += "shape = SubResource(\"CapsuleShape2D_fix\")\n"

	return content
