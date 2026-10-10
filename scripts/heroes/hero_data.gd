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
## HP na poziomie 1 i na MAX_LEVEL (PlayerStats.MAX_LEVEL) — pomiędzy liniowo (hp_for_level). Każda postać ma swoją pulę.
@export var base_hp: int = 334
@export var hp_at_max_level: int = 1402
@export var base_sp: int = 100
@export var base_tp: int = 100
## Staty jak w FNAfB: poziom 1 ~11–21, wzrost ~+1–2 na poziom (do ~30–60 na poziomie 20); resztę dają przedmioty.
@export_range(5, 30) var base_atk: int = 20
@export_range(5, 30) var base_def: int = 15
@export_range(0.0, 4.0, 0.1) var atk_per_level: float = 2.0
@export_range(0.0, 4.0, 0.1) var def_per_level: float = 1.5

@export_group("Skills")
## Pula umiejętności postaci (kolejność = kolejność w menu); z poziomu — QuizRpgSkillData.learn_level, reszta od NPC.
@export var skills: Array[QuizRpgSkillData] = []

@export_group("Equipment")
@export var default_weapon_id: String = ""
@export var default_shield_id: String = ""
@export var default_head_id: String = ""
@export var default_body_id: String = ""
@export var default_accessory_id: String = ""


## Maks. HP na danym poziomie: liniowo od base_hp (poziom 1) do hp_at_max_level (max_level).
func hp_for_level(lvl: int, max_level: int) -> int:
	return QuizRpgHeroData.linear_hp(base_hp, hp_at_max_level, lvl, max_level)


static func linear_hp(hp_first: int, hp_last: int, lvl: int, max_level: int) -> int:
	if max_level <= 1:
		return hp_first
	var t := clampf(float(lvl - 1) / float(max_level - 1), 0.0, 1.0)
	return roundi(lerpf(float(hp_first), float(hp_last), t))


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
		"atk_per_level": atk_per_level,
		"skills": [],
		"def_per_level": def_per_level,
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
