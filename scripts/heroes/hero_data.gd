extends Resource
class_name QuizRpgHeroData

@export_group("Identity")
@export var hero_id: String = "hero"
@export var display_name: String = "Bohater"
## Klasa postaci (archetyp, docs/kontekst/klasy_postaci_i_bronie.md): ogranicza ekwipunek z `allowed_classes` i wyznacza styl walki.
@export_enum("warrior", "rogue", "mage", "priest") var character_class: String = "warrior"
@export var portrait: Texture2D
@export var actor_scene: PackedScene
@export_group("Visual")
@export var sprite_frames: SpriteFrames
## Przesunięcie sprite'a na mapie (AnimatedSprite2D.offset) — klatki Pixel Crawlera 64×64 mają stopy przy dolnej krawędzi.
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var body_color: Color = Color(0.2, 0.6, 1.0)

@export_group("Progression")
@export var base_level: int = 1
## HP: jedna gładka krzywa przez trzy punkty: lv 1 = base_hp, lv hp_ref_level = hp_ref_value (jak FNaFB1: 334 -> 1402 na lv 20)
## i MAX_LEVEL = hp_at_max_level („chore liczby” późnej gry, decyzja usera 2026-10-12); kształt w hero_data.curve_value. Każda postać ma swoją pulę.
@export var base_hp: int = 334
@export var hp_ref_level: int = 20
@export var hp_ref_value: int = 1402
@export var hp_at_max_level: int = 50000
## SP: ta sama krzywa przez lv 1, sp_ref_level i MAX_LEVEL (FNaFB1 FM, Freddy: MP 139 -> 446 na lv 20); koszty umiejętności są w tej skali.
## Punkt kontrolny leży na prostej, więc dziś SP rośnie liniowo; niżej ustawiona sp_ref_value da krzywą wypukłą jak HP.
@export var sp_ref_level: int = 20
@export var sp_ref_value: int = 446
## Krzywa XP jak „exp params” klasy w RPG Makerze VX Ace / FNaFB1 (Freddy: 50, 40, 50, 39): lv 1->2 90 XP, 2->3 204, 5->6 943, 19->20 12 532.
@export var xp_base: int = 50
@export var xp_extra: int = 40
@export var xp_acc_a: int = 50
@export var xp_acc_b: int = 39
@export var base_sp: int = 139
@export var sp_at_max_level: int = 1739
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


## Maks. HP na danym poziomie: jedna krzywa przez (1, base_hp), (hp_ref_level, hp_ref_value), (max_level, hp_at_max_level).
func hp_for_level(lvl: int, max_level: int) -> int:
	return QuizRpgHeroData.curve_value(base_hp, hp_ref_level, hp_ref_value, hp_at_max_level, lvl, max_level)


## Wartość krzywej first + B × (e^(k × (lvl − 1)) − 1) przechodzącej przez (1, first), (ref_level, ref_value) i (max_level, last); k z bisekcji.
## Gdy punkt kontrolny leży na prostej (albo poniżej niej), wychodzi prosta first -> last. Rosnąca i gładka (bez załamania).
static func curve_value(first: int, ref_level: int, ref_value: int, last: int, lvl: int, max_level: int) -> int:
	var span_max := float(max_level - 1)
	var span_ref := float(clampi(ref_level, 2, max_level) - 1)
	var t := clampf(float(lvl - 1), 0.0, span_max)
	var rise_ref := float(ref_value - first)
	var rise_max := float(last - first)
	if max_level <= 1 or rise_ref <= 0.0 or rise_max / rise_ref <= span_max / span_ref + 0.001:
		return QuizRpgHeroData.linear_hp(first, last, lvl, max_level)
	var need := rise_max / rise_ref
	var lo := 1e-6
	var hi := 2.0
	for i in range(80):
		var k := 0.5 * (lo + hi)
		if (exp(k * span_max) - 1.0) / (exp(k * span_ref) - 1.0) < need:
			lo = k
		else:
			hi = k
	var kk := 0.5 * (lo + hi)
	return roundi(float(first) + rise_ref / (exp(kk * span_ref) - 1.0) * (exp(kk * t) - 1.0))


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
	return QuizRpgHeroData.curve_value(base_sp, sp_ref_level, sp_ref_value, sp_at_max_level, lvl, max_level)


static func linear_hp(hp_first: int, hp_last: int, lvl: int, max_level: int) -> int:
	if max_level <= 1:
		return hp_first
	var t := clampf(float(lvl - 1) / float(max_level - 1), 0.0, 1.0)
	return roundi(lerpf(float(hp_first), float(hp_last), t))


const CHARACTER_CLASSES: Array[String] = ["warrior", "rogue", "mage", "priest"]
const CLASS_LABELS := {"warrior": "Wojownik", "rogue": "Łotrzyk", "mage": "Mag", "priest": "Kapłan"}


## Nazwa klasy w wybranym języku (klucz class.<id>), zapasowo polska z CLASS_LABELS.
static func class_label(class_id: String) -> String:
	return QuizRpgI18n.t("class." + class_id, str(CLASS_LABELS.get(class_id, class_id)))


func build_member_data() -> Dictionary:
	return {
		"hero_id": hero_id,
		"name": display_name,
		"character_class": character_class,
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
		"sprite_offset": sprite_offset,
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
