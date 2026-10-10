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
## SP na poziomie 1 i na MAX_LEVEL — liniowo (FNaFB1 FM, Freddy: MP 139 -> 446); koszty umiejętności są w tej skali.
## Krzywa XP jak „exp params” klasy w RPG Makerze VX Ace / FNaFB1 (Freddy: 50, 40, 50, 39): lv 1->2 90 XP, 2->3 204, 5->6 943, 19->20 12 532.
@export var xp_base: int = 50
@export var xp_extra: int = 40
@export var xp_acc_a: int = 50
@export var xp_acc_b: int = 39
@export var base_sp: int = 139
@export var sp_at_max_level: int = 446
@export var base_tp: int = 100
## Staty jak w FNaFB1: poziom 1 ~11–21, wzrost ~+1–2 na poziom (do ~30–60 na poziomie 20); resztę dają przedmioty.
## ATK / DEF — fizyczne, MAT / MDF — magiczne (wzory umiejętności: baza + ATK × a + MAT × m − DEF × d − MDF × md).
@export_range(5, 30) var base_atk: int = 21
@export_range(5, 30) var base_def: int = 11
@export_range(5, 30) var base_mat: int = 21
@export_range(5, 30) var base_mdf: int = 12
@export_range(0.0, 4.0, 0.05) var atk_per_level: float = 1.95
@export_range(0.0, 4.0, 0.1) var def_per_level: float = 1.1
@export_range(0.0, 4.0, 0.05) var mat_per_level: float = 1.95
@export_range(0.0, 4.0, 0.1) var mdf_per_level: float = 1.1

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


## Łączna liczba XP potrzebna do osiągnięcia poziomu lvl (wzór EXP klasy z RPG Makera VX Ace).
func xp_total_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	var l := float(lvl)
	return roundi(xp_base * pow(l - 1.0, 0.9 + xp_acc_a / 250.0) * l * (l + 1.0) / (6.0 + l * l / 50.0 / xp_acc_b) + (l - 1.0) * xp_extra)


## XP z poziomu lvl na lvl + 1.
func xp_to_next(lvl: int) -> int:
	return maxi(xp_total_for_level(lvl + 1) - xp_total_for_level(lvl), 1)


## Maks. SP na danym poziomie (jak hp_for_level).
func sp_for_level(lvl: int, max_level: int) -> int:
	return QuizRpgHeroData.linear_hp(base_sp, sp_at_max_level, lvl, max_level)


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
		"base_mat": base_mat,
		"base_mdf": base_mdf,
		"mat_per_level": mat_per_level,
		"mdf_per_level": mdf_per_level,
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
