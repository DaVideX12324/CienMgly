extends RefCounted

## Wersje statystyk przeciwników do wyboru w opcjach (prośba usera 2026-10-31 — dopasowanie, potem poziomy trudności).
## Każde ustawienie osobno: wersja z historii balansu albo „własne” (pola liczbowe). Domyślnie obecny balans.
## Wersje: v0 = sprzed 07f26d46 (pierwotne), v1 = 07f26d46 / cc5c617f, v2 = d3567474 / 08ceadc0 (obecne).

const MODULE_ID := "quiz_rpg"
const CUSTOM := "custom"

const TIER_BALANCE := {
	"v0": {1: {"hp": 1.0, "atk": 1.0}, 2: {"hp": 1.0, "atk": 1.0}, 3: {"hp": 1.0, "atk": 1.0}},
	"v1": {1: {"hp": 1.6, "atk": 1.15}, 2: {"hp": 1.15, "atk": 1.05}, 3: {"hp": 1.0, "atk": 1.0}},
	"v2": {1: {"hp": 1.3, "atk": 1.0}, 2: {"hp": 1.0, "atk": 0.95}, 3: {"hp": 0.9, "atk": 0.95}},
}
const BOSS_STATS := {"v0": {"hp": 1.0, "atk": 1.0}, "v1": {"hp": 0.7, "atk": 0.9}}
const BOSS_SKILL_DAMAGE := {"v0": 1.0, "v1": 0.6, "v2": 0.7}
const BOSS_SKILL_COOLDOWN := {"v0": 0, "v1": 2}
## Dane wroga nadpisywane wersją (ścieżka .tres -> wersja -> pola EnemyData).
const DATA_VERSIONS := {
	"res://modules/quiz_rpg/resources/enemies/pixel_crawler/data/bat_fur.tres": {
		"key": "diff_bat_fur",
		"v0": {"max_hp": 81, "attack": 8, "defense": 11, "magic_attack": 8, "magic_defense": 11},
		"v1": {"max_hp": 260, "attack": 19, "defense": 18, "magic_attack": 19, "magic_defense": 18},
		"v2": {"max_hp": 220, "attack": 17, "defense": 18, "magic_attack": 17, "magic_defense": 18},
	},
}
const DEFAULTS := {"diff_tier_balance": "v2", "diff_boss_stats": "v1", "diff_boss_skill_damage": "v2",
	"diff_boss_cooldown": "v1", "diff_skill_level_scale": true, "diff_bat_fur": "v2"}


static func _setting(key: String) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	var s: Node = tree.root.get_node_or_null("/root/SettingsService") if tree else null
	var def: Variant = DEFAULTS.get(key, 1.0)
	return s.call("get_module", MODULE_ID, key, def) if s else def


static func _num(key: String, fallback: float) -> float:
	var v: Variant = _setting(key)
	return float(v) if v != null and (v is float or v is int) else fallback


## Mnożnik HP / ATK wroga tieru (1–3 zwykli, 4+ bossowie).
static func tier_balance(tier: int) -> Dictionary:
	if tier >= 4:
		var b := str(_setting("diff_boss_stats"))
		if b == CUSTOM:
			return {"hp": _num("diff_boss_hp", 1.0), "atk": _num("diff_boss_atk", 1.0)}
		return BOSS_STATS.get(b, BOSS_STATS["v1"])
	var t := clampi(tier, 1, 3)
	var v := str(_setting("diff_tier_balance"))
	if v == CUSTOM:
		return {"hp": _num("diff_t%d_hp" % t, 1.0), "atk": _num("diff_t%d_atk" % t, 1.0)}
	return (TIER_BALANCE.get(v, TIER_BALANCE["v2"]) as Dictionary)[t]


static func boss_skill_damage() -> float:
	var v := str(_setting("diff_boss_skill_damage"))
	return _num("diff_boss_skill_damage_value", 1.0) if v == CUSTOM else float(BOSS_SKILL_DAMAGE.get(v, 0.7))


static func boss_skill_cooldown() -> int:
	var v := str(_setting("diff_boss_cooldown"))
	return roundi(_num("diff_boss_cooldown_value", 0.0)) if v == CUSTOM else int(BOSS_SKILL_COOLDOWN.get(v, 2))


## Stałe obrażenia umiejętności wrogów słabsze na niskich poziomach (07f26d46); wyłączone = zawsze pełne.
static func skill_level_scale_enabled() -> bool:
	return bool(_setting("diff_skill_level_scale"))


## Pola EnemyData do nadpisania wg wybranej wersji (puste = bez zmian).
static func data_override(path: String) -> Dictionary:
	var d: Dictionary = DATA_VERSIONS.get(path, {})
	if d.is_empty():
		return {}
	return d.get(str(_setting(str(d["key"]))), {})


## Opcje dla zakładki opcji hosta (get_ui_options): wybory wersji + pola własnych wartości.
static func ui_options() -> Array[Dictionary]:
	var t := func(k: String, pl: String) -> String: return QuizRpgI18n.t("diff." + k, pl)
	var own := {"id": CUSTOM, "name": t.call("custom", "Własne")}
	var out: Array[Dictionary] = []
	out.append({"key": "diff_tier_balance", "type": "choice", "default": "v2", "label": t.call("tier_balance", "Zwykli wrogowie (HP / ATK)"),
		"choices": [{"id": "v0", "name": t.call("tier_v0", "Pierwotne (×1)")}, {"id": "v1", "name": t.call("tier_v1", "Mocne (T1 ×1,6/×1,15)")},
			{"id": "v2", "name": t.call("tier_v2", "Łagodne (obecne)")}, own]})
	for tier in [1, 2, 3]:
		for st in ["hp", "atk"]:
			out.append({"key": "diff_t%d_%s" % [tier, st], "type": "number", "default": 1.0, "min": 0.1, "max": 5.0, "step": 0.05,
				"label": t.call("custom_tier", "Własne: tier {t} {s} ×").replace("{t}", str(tier)).replace("{s}", st.to_upper())})
	out.append({"key": "diff_boss_stats", "type": "choice", "default": "v1", "label": t.call("boss_stats", "Bossowie (HP / ATK)"),
		"choices": [{"id": "v0", "name": t.call("boss_v0", "Pierwotne (×1)")}, {"id": "v1", "name": t.call("boss_v1", "Łagodne ×0,7 / ×0,9 (obecne)")}, own]})
	out.append({"key": "diff_boss_hp", "type": "number", "default": 1.0, "min": 0.1, "max": 5.0, "step": 0.05, "label": t.call("custom_boss_hp", "Własne: boss HP ×")})
	out.append({"key": "diff_boss_atk", "type": "number", "default": 1.0, "min": 0.1, "max": 5.0, "step": 0.05, "label": t.call("custom_boss_atk", "Własne: boss ATK ×")})
	out.append({"key": "diff_boss_skill_damage", "type": "choice", "default": "v2", "label": t.call("boss_skill", "Umiejętności bossów (obrażenia)"),
		"choices": [{"id": "v0", "name": "×1"}, {"id": "v1", "name": "×0,6"}, {"id": "v2", "name": t.call("boss_skill_v2", "×0,7 (obecne)")}, own]})
	out.append({"key": "diff_boss_skill_damage_value", "type": "number", "default": 1.0, "min": 0.1, "max": 3.0, "step": 0.05, "label": t.call("custom_boss_skill", "Własne: obrażenia umiejętności bossów ×")})
	out.append({"key": "diff_boss_cooldown", "type": "choice", "default": "v1", "label": t.call("boss_cooldown", "Odnowienie umiejętności bossów"),
		"choices": [{"id": "v0", "name": "+0"}, {"id": "v1", "name": t.call("boss_cooldown_v1", "+2 tury (obecne)")}, own]})
	out.append({"key": "diff_boss_cooldown_value", "type": "number", "default": 0.0, "min": 0.0, "max": 10.0, "step": 1.0, "label": t.call("custom_boss_cooldown", "Własne: dodatkowe tury odnowienia")})
	out.append({"key": "diff_skill_level_scale", "type": "bool", "default": true, "label": t.call("skill_level_scale", "Umiejętności wrogów słabsze na niskich poziomach")})
	out.append({"key": "diff_bat_fur", "type": "choice", "default": "v2", "label": t.call("bat_fur", "Nietoperz futrzasty"),
		"choices": [{"id": "v0", "name": "HP 81 ATK 8"}, {"id": "v1", "name": "HP 260 ATK 19"}, {"id": "v2", "name": t.call("bat_fur_v2", "HP 220 ATK 17 (obecne)")}]})
	return out
