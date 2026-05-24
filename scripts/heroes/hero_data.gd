extends Resource
class_name QuizRpgHeroData

@export_group("Identity")
@export var hero_id: String = "hero"
@export var display_name: String = "Bohater"
@export var portrait: Texture2D
@export var actor_scene: PackedScene
@export_group("Visual")
@export var sprite_frames: SpriteFrames
@export var body_color: Color = Color(0.2, 0.6, 1.0)

@export_group("Progression")
@export var base_level: int = 1
@export var base_hp: int = 100
@export var base_sp: int = 100
@export var base_tp: int = 100
@export var base_atk: int = 10
@export var base_def: int = 8

@export_group("Equipment")
@export var default_weapon_id: String = ""
@export var default_shield_id: String = ""
@export var default_head_id: String = ""
@export var default_body_id: String = ""
@export var default_accessory_id: String = ""


func build_member_data() -> Dictionary:
	return {
		"hero_id": hero_id,
		"name": display_name,
		"level": base_level,
		"hp": base_hp,
		"max_hp": base_hp,
		"sp": base_sp,
		"max_sp": base_sp,
		"tp": 0,
		"max_tp": base_tp,
		"base_atk": base_atk,
		"base_def": base_def,
		"portrait": portrait,
		"actor_scene": actor_scene,
		"sprite_frames": sprite_frames,
		"body_color": body_color,
		"equipment": {
			"weapon": default_weapon_id,
			"shield": default_shield_id,
			"head": default_head_id,
			"body": default_body_id,
			"accessory": default_accessory_id,
		},
		"default_equipment": {
			"weapon": default_weapon_id,
			"shield": default_shield_id,
			"head": default_head_id,
			"body": default_body_id,
			"accessory": default_accessory_id,
		},
	}
