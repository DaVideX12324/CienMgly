@tool
extends EditorScript

## Podmienia prostokatny CollisionShape2D (dziedziczony z enemy.tscn) na
## CapsuleShape2D przeniesiony z oryginalnych scen paczki Amon Ra. Operuje
## wylacznie na juz wygenerowanych scenach w modules/quiz_rpg/scenes/enemies/
## (bandit_1.tscn, ork_1.tscn, itd.) -- nie dotyka amonra-yoink/ (zrodlo,
## tylko do odczytu) i nie zmienia zadnych statow/animacji/sprite'ow.
##
## Uzycie: Godot Script Editor -> otworz plik -> Ctrl+Shift+X (File -> Run).

const SOURCE_DIR := "res://modules/quiz_rpg/scenes/enemies/amonra-yoink/"
const TARGET_DIR := "res://modules/quiz_rpg/scenes/enemies/"


func _run() -> void:
	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		push_error("Nie znaleziono folderu: %s" % SOURCE_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var fixed := 0
	var skipped: Array[String] = []

	while file_name != "":
		if file_name.ends_with(".tscn") and file_name != "enemy_template.tscn":
			var slug := file_name.get_basename().replace("enemy_", "")
			if _fix_one(SOURCE_DIR + file_name, slug):
				fixed += 1
			else:
				skipped.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Hitboxy poprawione: %d. Pominieto: %s" % [fixed, str(skipped)])


func _fix_one(source_path: String, slug: String) -> bool:
	var target_path := "%s%s.tscn" % [TARGET_DIR, slug]
	if not FileAccess.file_exists(target_path):
		push_warning("Brak wygenerowanej sceny: %s" % target_path)
		return false

	var shape_data := _extract_root_capsule(source_path)
	if shape_data.is_empty():
		push_warning("%s: nie znaleziono CapsuleShape2D w oryginale" % slug)
		return false

	var packed: PackedScene = load(target_path)
	if packed == null:
		push_warning("Nie mozna wczytac sceny: %s" % target_path)
		return false

	var root: Node = packed.instantiate()
	var collision: CollisionShape2D = root.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		root.add_child(collision)

	var radius: float = shape_data.get("radius", 8.0)
	var height: float = shape_data.get("height", 20.0)
	var shape_position: Vector2 = shape_data.get("position", Vector2.ZERO)
	var shape_rotation: float = shape_data.get("rotation", 0.0)

	var capsule := CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = height
	collision.shape = capsule
	collision.position = shape_position
	collision.rotation = shape_rotation
	collision.visible = false

	var new_packed := PackedScene.new()
	var pack_err := new_packed.pack(root)
	root.queue_free()
	if pack_err != OK:
		push_warning("%s: blad pack() = %d" % [slug, pack_err])
		return false

	var save_err := ResourceSaver.save(new_packed, target_path)
	if save_err != OK:
		push_warning("%s: blad zapisu = %d" % [slug, save_err])
		return false

	print("Poprawiono hitbox: %s (radius=%.1f height=%.1f)" % [slug, radius, height])
	return true


func _extract_root_capsule(source_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(source_path)
	if text.is_empty():
		return {}

	# Pierwszy blok [node ... type="CollisionShape2D" parent="."] -- dziecko
	# root, nie zagniezdzone w DamageHitbox/Hurtbox/VisionRange.
	var node_re := RegEx.new()
	node_re.compile("\\[node name=\"[^\"]*\" type=\"CollisionShape2D\" parent=\"\\.\"\\][^\\[]*")
	var node_match := node_re.search(text)
	if node_match == null:
		return {}
	var block := node_match.get_string()

	var shape_id_re := RegEx.new()
	shape_id_re.compile("shape\\s*=\\s*SubResource\\(\"([^\"]+)\"\\)")
	var shape_id_match := shape_id_re.search(block)
	if shape_id_match == null:
		return {}
	var shape_id: String = shape_id_match.get_string(1)

	var sub_re := RegEx.new()
	sub_re.compile("\\[sub_resource type=\"CapsuleShape2D\" id=\"%s\"\\]\\s*(?:radius = ([0-9.]+)\\s*)?(?:height = ([0-9.]+))?" % shape_id)
	var sub_match := sub_re.search(text)
	if sub_match == null:
		return {}

	var radius := 8.0
	var height := 20.0
	if sub_match.get_string(1) != "":
		radius = sub_match.get_string(1).to_float()
	if sub_match.get_string(2) != "":
		height = sub_match.get_string(2).to_float()

	var pos_re := RegEx.new()
	pos_re.compile("position = Vector2\\(([\\-0-9.]+), ([\\-0-9.]+)\\)")
	var pos_match := pos_re.search(block)
	var shape_position := Vector2.ZERO
	if pos_match:
		shape_position = Vector2(pos_match.get_string(1).to_float(), pos_match.get_string(2).to_float())

	var rot_re := RegEx.new()
	rot_re.compile("rotation = ([\\-0-9.]+)")
	var rot_match := rot_re.search(block)
	var rotation_val := 0.0
	if rot_match:
		rotation_val = rot_match.get_string(1).to_float()

	return {
		"radius": radius,
		"height": height,
		"position": shape_position,
		"rotation": rotation_val,
	}
