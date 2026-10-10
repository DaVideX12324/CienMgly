@tool
extends SceneTree

const SF_DIR := "res://modules/quiz_rpg/resources/enemies/pixel_crawler/"
const DATA_DIR := "res://modules/quiz_rpg/resources/enemies/pixel_crawler/data/"
const SCENE_DIR := "res://modules/quiz_rpg/scenes/enemies/pixel_crawler/"
const BASE_TEX_DIR := "res://assets/pixel_crawler/enemies/bat_enemy/"

func _initialize() -> void:
	_create_bat_small()
	_create_bat_fur()
	print("Bat enemies created successfully!")
	quit()

func _create_bat_small() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var tex_idle_side := load(BASE_TEX_DIR + "Small_Bat/Idle/Idle_Side-Sheet.png") as Texture2D
	var tex_move_side := load(BASE_TEX_DIR + "Small_Bat/Move/Move_Side-Sheet.png") as Texture2D
	var tex_hit_side := load(BASE_TEX_DIR + "Small_Bat/Hit/Hit_Side-Sheet.png") as Texture2D
	var tex_death_side := load(BASE_TEX_DIR + "Small_Bat/Death/Death_Side-Sheet.png") as Texture2D
	var tex_attack_side := load(BASE_TEX_DIR + "Small_Bat/Attack_01/Attack_01_Side-Sheet.png") as Texture2D

	var tex_idle_down := load(BASE_TEX_DIR + "Small_Bat/Idle/Idle_Down-Sheet.png") as Texture2D
	var tex_move_down := load(BASE_TEX_DIR + "Small_Bat/Move/Move_Down-Sheet.png") as Texture2D
	var tex_hit_down := load(BASE_TEX_DIR + "Small_Bat/Hit/Hit_Down-Sheet.png") as Texture2D
	var tex_death_down := load(BASE_TEX_DIR + "Small_Bat/Death/Death_Down-Sheet.png") as Texture2D
	var tex_attack_down := load(BASE_TEX_DIR + "Small_Bat/Attack_01/Attack_01_Down-Sheet.png") as Texture2D

	var tex_idle_up := load(BASE_TEX_DIR + "Small_Bat/Idle/Idle_Up-Sheet.png") as Texture2D
	var tex_move_up := load(BASE_TEX_DIR + "Small_Bat/Move/Move_Up-Sheet.png") as Texture2D
	var tex_hit_up := load(BASE_TEX_DIR + "Small_Bat/Hit/Hit_Up-Sheet.png") as Texture2D
	var tex_death_up := load(BASE_TEX_DIR + "Small_Bat/Death/Death_Up-Sheet.png") as Texture2D
	var tex_attack_up := load(BASE_TEX_DIR + "Small_Bat/Attack_01/Attack_01_Up-Sheet.png") as Texture2D

	_add_anim(sf, "idle", tex_idle_side, 64, 4, 6.0, true)
	_add_anim(sf, "walk", tex_move_side, 64, 8, 10.0, true)
	_add_anim(sf, "hurt", tex_hit_side, 64, 4, 10.0, false)
	_add_anim(sf, "death", tex_death_side, 64, 4, 10.0, false)
	_add_anim(sf, "attack", tex_attack_side, 64, 6, 10.0, false)

	_add_anim(sf, "idle_front", tex_idle_down, 64, 4, 6.0, true)
	_add_anim(sf, "walk_front", tex_move_down, 64, 8, 10.0, true)
	_add_anim(sf, "hurt_front", tex_hit_down, 64, 4, 10.0, false)
	_add_anim(sf, "death_front", tex_death_down, 64, 4, 10.0, false)
	_add_anim(sf, "attack_front", tex_attack_down, 64, 6, 10.0, false)

	_add_anim(sf, "idle_back", tex_idle_up, 64, 4, 6.0, true)
	_add_anim(sf, "walk_back", tex_move_up, 64, 8, 10.0, true)
	_add_anim(sf, "hurt_back", tex_hit_up, 64, 4, 10.0, false)
	_add_anim(sf, "death_back", tex_death_up, 64, 4, 10.0, false)
	_add_anim(sf, "attack_back", tex_attack_up, 64, 6, 10.0, false)

	var sf_path := SF_DIR + "bat_small.tres"
	var err := ResourceSaver.save(sf, sf_path)
	if err != OK:
		push_error("Blad zapisu SpriteFrames bat_small: %d" % err)

	var EnemyDataScript = load("res://modules/quiz_rpg/scripts/enemies/enemy_data.gd")
	var data: Resource = EnemyDataScript.new()
	data.set("enemy_name", "Mały Nietoperz")
	data.set("quiz_id", "ogolne")
	data.set("quiz_category", "ogolne")
	data.set("is_boss", false)
	data.set("question_count", 3)
	data.set("max_hp", 40)
	data.set("attack", 10)
	data.set("xp_reward", 35)
	data.set("encounter_tier", 1)
	data.set("min_encounter_size", 1)
	data.set("max_encounter_size", 3)
	data.set("patrol_speed", 85.0)
	data.set("detection_radius", 100.0)
	data.set("body_color", Color(0.9, 0.2, 0.2, 1))
	data.set("shape_type", 0)

	var data_path := DATA_DIR + "bat_small.tres"
	err = ResourceSaver.save(data, data_path)
	if err != OK:
		push_error("Blad zapisu EnemyData bat_small: %d" % err)

	_write_scene_file("bat_small", 3.0, 10.0, Vector2(0, 4), Vector2(0, -26))

func _create_bat_fur() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var tex_idle_side := load(BASE_TEX_DIR + "Bat_Fur/Idle/Idle_Side-Sheet.png") as Texture2D
	var tex_move_side := load(BASE_TEX_DIR + "Bat_Fur/Move/Move_Side-Sheet.png") as Texture2D
	var tex_hit_side := load(BASE_TEX_DIR + "Bat_Fur/Hit/Hit_Side-Sheet.png") as Texture2D
	var tex_death_side := load(BASE_TEX_DIR + "Bat_Fur/Death/Death_Side-Sheet.png") as Texture2D
	var tex_attack_side := load(BASE_TEX_DIR + "Bat_Fur/Attack_01/Attack_Side-Sheet.png") as Texture2D

	var tex_idle_down := load(BASE_TEX_DIR + "Bat_Fur/Idle/Idle_Down-Sheet.png") as Texture2D
	var tex_move_down := load(BASE_TEX_DIR + "Bat_Fur/Move/Move_Down-Sheet.png") as Texture2D
	var tex_hit_down := load(BASE_TEX_DIR + "Bat_Fur/Hit/Hit_Down-Sheet.png") as Texture2D
	var tex_death_down := load(BASE_TEX_DIR + "Bat_Fur/Death/Death_Down-Sheet.png") as Texture2D
	var tex_attack_down := load(BASE_TEX_DIR + "Bat_Fur/Attack_01/Attack_Down-Sheet.png") as Texture2D

	var tex_idle_up := load(BASE_TEX_DIR + "Bat_Fur/Idle/Idle_Up-Sheet.png") as Texture2D
	var tex_move_up := load(BASE_TEX_DIR + "Bat_Fur/Move/Move_Up-Sheet.png") as Texture2D
	var tex_hit_up := load(BASE_TEX_DIR + "Bat_Fur/Hit/Hit_Up-Sheet.png") as Texture2D
	var tex_death_up := load(BASE_TEX_DIR + "Bat_Fur/Death/Death_Up-Sheet.png") as Texture2D
	var tex_attack_up := load(BASE_TEX_DIR + "Bat_Fur/Attack_01/Attack_Up-Sheet.png") as Texture2D

	_add_anim(sf, "idle", tex_idle_side, 96, 4, 6.0, true)
	_add_anim(sf, "walk", tex_move_side, 96, 8, 10.0, true)
	_add_anim(sf, "hurt", tex_hit_side, 96, 4, 10.0, false)
	_add_anim(sf, "death", tex_death_side, 96, 6, 10.0, false)
	_add_anim(sf, "attack", tex_attack_side, 96, 6, 10.0, false)

	_add_anim(sf, "idle_front", tex_idle_down, 96, 4, 6.0, true)
	_add_anim(sf, "walk_front", tex_move_down, 96, 8, 10.0, true)
	_add_anim(sf, "hurt_front", tex_hit_down, 96, 4, 10.0, false)
	_add_anim(sf, "death_front", tex_death_down, 96, 6, 10.0, false)
	_add_anim(sf, "attack_front", tex_attack_down, 96, 6, 10.0, false)

	_add_anim(sf, "idle_back", tex_idle_up, 96, 4, 6.0, true)
	_add_anim(sf, "walk_back", tex_move_up, 96, 8, 10.0, true)
	_add_anim(sf, "hurt_back", tex_hit_up, 96, 4, 10.0, false)
	_add_anim(sf, "death_back", tex_death_up, 96, 6, 10.0, false)
	_add_anim(sf, "attack_back", tex_attack_up, 96, 6, 10.0, false)

	var sf_path := SF_DIR + "bat_fur.tres"
	var err := ResourceSaver.save(sf, sf_path)
	if err != OK:
		push_error("Blad zapisu SpriteFrames bat_fur: %d" % err)

	var EnemyDataScript = load("res://modules/quiz_rpg/scripts/enemies/enemy_data.gd")
	var data: Resource = EnemyDataScript.new()
	data.set("enemy_name", "Włochaty Nietoperz")
	data.set("quiz_id", "ogolne")
	data.set("quiz_category", "ogolne")
	data.set("is_boss", false)
	data.set("question_count", 3)
	data.set("max_hp", 80)
	data.set("attack", 16)
	data.set("xp_reward", 65)
	data.set("encounter_tier", 2)
	data.set("min_encounter_size", 1)
	data.set("max_encounter_size", 3)
	data.set("patrol_speed", 75.0)
	data.set("detection_radius", 100.0)
	data.set("body_color", Color(0.9, 0.2, 0.2, 1))
	data.set("shape_type", 0)

	var data_path := DATA_DIR + "bat_fur.tres"
	err = ResourceSaver.save(data, data_path)
	if err != OK:
		push_error("Blad zapisu EnemyData bat_fur: %d" % err)

	_write_scene_file("bat_fur", 4.0, 14.0, Vector2(0, 4), Vector2(0, -42))

func _add_anim(sf: SpriteFrames, anim_name: String, tex: Texture2D, frame_size: int, frame_count: int, speed: float, loop: bool) -> void:
	if tex == null:
		push_error("Null texture for animation %s" % anim_name)
		return
	if not sf.has_animation(anim_name):
		sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, speed)
	sf.set_animation_loop(anim_name, loop)
	for i in range(frame_count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		sf.add_frame(anim_name, at)

func _write_scene_file(id: String, col_radius: float, col_height: float, spr_pos: Vector2, spr_offset: Vector2) -> void:
	var sf_path := "res://modules/quiz_rpg/resources/enemies/pixel_crawler/%s.tres" % id
	var data_path := "res://modules/quiz_rpg/resources/enemies/pixel_crawler/data/%s.tres" % id
	var sf_uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(sf_path))
	var data_uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(data_path))

	var lines: Array[String] = [
		"[gd_scene format=3]",
		"",
		"[ext_resource type=\"PackedScene\" uid=\"uid://enemy001\" path=\"res://modules/quiz_rpg/scenes/enemies/enemy.tscn\" id=\"1_base\"]",
		"[ext_resource type=\"SpriteFrames\" %spath=\"%s\" id=\"2_frames\"]" % [("uid=\"%s\" " % sf_uid) if not sf_uid.is_empty() else "", sf_path],
		"[ext_resource type=\"Resource\" %spath=\"%s\" id=\"3_data\"]" % [("uid=\"%s\" " % data_uid) if not data_uid.is_empty() else "", data_path],
		"",
		"[sub_resource type=\"CapsuleShape2D\" id=\"CapsuleShape2D_body\"]",
		"radius = %.1f" % col_radius,
		"height = %.1f" % col_height,
		"",
		"[node name=\"Enemy\" instance=ExtResource(\"1_base\")]",
		"enemy_data = ExtResource(\"3_data\")",
		"",
		"[node name=\"AnimatedSprite2D\" parent=\".\" index=\"0\"]",
		"position = Vector2(%.1f, %.1f)" % [spr_pos.x, spr_pos.y],
		"sprite_frames = ExtResource(\"2_frames\")",
		"animation = &\"idle\"",
		"offset = Vector2(%.1f, %.1f)" % [spr_offset.x, spr_offset.y],
		"",
		"[node name=\"CollisionShape2D\" parent=\".\" index=\"1\"]",
		"position = Vector2(%.1f, %.1f)" % [spr_pos.x, spr_pos.y],
		"rotation = 1.570796",
		"shape = SubResource(\"CapsuleShape2D_body\")",
		""
	]
	var content := "\n".join(lines)
	var out_path := SCENE_DIR + "%s.tscn" % id
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()
		print("Saved scene: %s" % out_path)
	else:
		push_error("Failed to open scene file for writing: %s" % out_path)
