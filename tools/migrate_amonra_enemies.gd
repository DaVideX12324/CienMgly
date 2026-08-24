@tool
extends EditorScript

## Migracja scen z modules/quiz_rpg/scenes/enemies/amonra-yoink/ do schematu
## EnemyBase/QuizRpgEnemyData. Czyta prawdziwe staty (health, speed,
## damage_per_hit) i sciezke SpriteFrames z kazdej sceny zrodlowej -- bez
## zgadywania wartosci. Generuje sceny/skrypty z relative paths (dziala
## identycznie w hoscie i standalone), analogicznie do bandit_1.tscn/gd.
##
## Uzycie: otworz ten plik w Godot Script Editor, Ctrl+Shift+X (File -> Run).
## Nie modyfikuje i nie usuwa oryginalnych plikow w amonra-yoink/.

const SOURCE_DIR := "res://modules/quiz_rpg/scenes/enemies/amonra-yoink/"
const SPRITES_DIR := "res://modules/quiz_rpg/resources/enemies/"
const OUT_SCENE_DIR := "res://modules/quiz_rpg/scenes/enemies/"
const OUT_SCRIPT_DIR := "res://modules/quiz_rpg/scripts/enemies/"

# Relative paths uzywane WEWNATRZ generowanych .tscn (liczone od OUT_SCENE_DIR)
const REL_BASE_SCENE := "enemy.tscn"
const REL_SCRIPT_PREFIX := "../../scripts/enemies/"
const REL_SPRITES_PREFIX := "../../resources/enemies/"

# Balans: staty z paczki -> staty Twojej gry. Podkrec/przykrec wedlug testow.
const HP_SCALE := 2.0
const DAMAGE_SCALE := 2.0
const XP_BASE := 20
const BOSS_HP_MULT := 1.8
const BOSS_XP_MULT := 2.5

# Nazwy bez dedykowanego .tres -- mapowanie na zrodlo, ktore istnieje
const FALLBACK_SPRITE_SOURCE := {
	"mummy_strong": "mummy",
	"slime_tutorial": "slime_1",
	"slime_tutorial_boss": "slime_1",
}


func _run() -> void:
	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		push_error("Nie znaleziono folderu: %s" % SOURCE_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var processed := 0
	var skipped: Array[String] = []

	while file_name != "":
		if file_name.ends_with(".tscn") and file_name != "enemy_template.tscn":
			var ok := _migrate_one(SOURCE_DIR + file_name)
			if ok:
				processed += 1
			else:
				skipped.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Migracja zakonczona. Przetworzono: %d. Pominieto: %s" % [processed, str(skipped)])


func _migrate_one(source_path: String) -> bool:
	var text := FileAccess.get_file_as_string(source_path)
	if text.is_empty():
		push_warning("Pusty lub nieodczytany plik: %s" % source_path)
		return false

	var slug := source_path.get_file().get_basename().replace("enemy_", "")
	var display_name := _to_display_name(slug)

	var health := _extract_float(text, "health", 30.0)
	var speed := _extract_float(text, "speed", 60.0)
	var damage_per_hit := _extract_float(text, "damage_per_hit", 5.0)

	var is_boss := slug.find("strong") != -1 or slug.find("boss") != -1
	var sprite_slug :String = FALLBACK_SPRITE_SOURCE.get(slug, slug)
	var sprite_res_path := "%senemy_%s.tres" % [SPRITES_DIR, sprite_slug]

	if not FileAccess.file_exists(sprite_res_path):
		push_warning("%s: brak %s, uzywam enemies_base_pack.tres" % [slug, sprite_res_path])
		sprite_res_path = SPRITES_DIR + "enemies_base_pack.tres"

	var hp := int(round(health * HP_SCALE * (BOSS_HP_MULT if is_boss else 1.0)))
	var dmg := int(round(damage_per_hit * DAMAGE_SCALE))
	var xp := int(round((XP_BASE + hp / 2.0) * (BOSS_XP_MULT if is_boss else 1.0)))

	_write_script(slug)
	_write_scene(slug, display_name, hp, dmg, speed, sprite_res_path, xp, is_boss)
	return true


func _to_display_name(slug: String) -> String:
	var parts := slug.split("_")
	var out := ""
	for p in parts:
		if p.length() > 0:
			out += (" " if out.length() > 0 else "") + p.substr(0, 1).to_upper() + p.substr(1)
	return out


func _to_pascal(slug: String) -> String:
	var parts := slug.split("_")
	var out := ""
	for p in parts:
		if p.length() > 0:
			out += p.substr(0, 1).to_upper() + p.substr(1)
	return out


func _extract_float(text: String, key: String, fallback: float) -> float:
	var re := RegEx.new()
	re.compile("%s\\s*=\\s*([0-9.]+)" % key)
	var m := re.search(text)
	if m:
		return m.get_string(1).to_float()
	return fallback


func _write_script(slug: String) -> void:
	var cls := "QuizRpg%s" % _to_pascal(slug)
	var content := "extends EnemyBase\nclass_name %s\n\n## Wygenerowano automatycznie z paczki Amonra (zrodlo: enemy_%s.tscn).\n## Zweryfikuj staty i animacje w edytorze przed uzyciem w grze.\n" % [cls, slug]
	var path := "%s%s.gd" % [OUT_SCRIPT_DIR, slug]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()


func _write_scene(slug: String, display_name: String, hp: int, dmg: int, speed: float, sprite_res_path: String, xp: int, is_boss: bool) -> void:
	var rel_script := "%s%s.gd" % [REL_SCRIPT_PREFIX, slug]
	var sprite_filename := sprite_res_path.get_file()
	var rel_sprite := "%s%s" % [REL_SPRITES_PREFIX, sprite_filename]

	var content := "[gd_scene load_steps=4 format=3]\n\n"
	content += "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_base\"]\n" % REL_BASE_SCENE
	content += "[ext_resource type=\"Script\" path=\"%s\" id=\"2_script\"]\n" % rel_script
	content += "[ext_resource type=\"SpriteFrames\" path=\"%s\" id=\"3_frames\"]\n\n" % rel_sprite
	content += "[node name=\"Enemy\" instance=ExtResource(\"1_base\")]\n"
	content += "script = ExtResource(\"2_script\")\n"
	content += "enemy_name = \"%s\"\n" % display_name
	content += "quiz_id = \"ogolne\"\n"
	content += "quiz_category = \"ogolne\"\n"
	content += "hp = %d\n" % hp
	content += "max_hp = %d\n" % hp
	content += "damage_on_wrong = %d\n" % dmg
	content += "xp_reward = %d\n" % xp
	content += "encounter_tier = %d\n" % (4 if is_boss else 1)
	content += "patrol_speed = %.1f\n" % speed
	content += "is_boss = %s\n\n" % ("true" if is_boss else "false")
	content += "[node name=\"AnimatedSprite2D\" parent=\".\" index=\"0\"]\n"
	content += "sprite_frames = ExtResource(\"3_frames\")\n"

	var out_path := "%s%s.tscn" % [OUT_SCENE_DIR, slug]
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	print("Wygenerowano: %s (hp=%d, dmg=%d, xp=%d, boss=%s)" % [out_path, hp, dmg, xp, is_boss])
