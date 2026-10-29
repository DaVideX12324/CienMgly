class_name QuizRpgEnemyStats
extends RefCounted

## Statystyki wroga z poziomu (faza 2 poziomów, 2026-10-12; skala FNaFB 2026-10-21). Wróg o poziomie L i tierze T:
## - ATK z własnej krzywej wrogów (QuizRpgStatScale.enemy_atk: Party Hat Alpha -> Omega FNaFB1, rozciągnięte na lv 1–100 i skalowane
##   z HP) × ENEMY_ATK_MULT[T] — pancerz bohatera waży tyle co w FNaFB (komplet ze sklepu tnie cios o ≈ 14 % na lv 1, 22 % na lv 100);
##   cios na bohaterze wzorcowym: tier 2 ≈ 14 % HP na lv 1, ≈ 30 % na lv 100 (jak Omega na Freddym lv 20);
## - HP i DEF z „bohatera wzorcowego” z poziomu L (statystyki z QuizRpgStatScale + sprzęt ze sklepu): bohater zabija go
##   w HITS_TO_KILL[T] zwykłych trafieniach, DEF = DEF_RATIO × ATK bohatera.
## Sprzęt bohatera wzorcowego (2026-10-25, decyzja usera): prawdziwe przedmioty rekomendowanego tieru mapy
## (resources/data/gear_tiers.json, companion-JSON "gear_tier") zamiast krzywej sprzętu ze sklepu. ATK wroga z krzywej
## poprawiony o ½ różnicy pancerza (tier vs krzywa) — cios zabiera bohaterowi wzorcowemu tyle HP, co przy krzywej.
## ATK = MAT, DEF = MDF (jak dotąd). Wróg z poziomem 0 (bez poziomu z mapy ani sceny) zostaje przy statystykach z danych.
## Statystyki bazowe wroga (dane / scena) = jego statystyki na poziomie 1 (bohater wzorcowy lv 1 w sprzęcie startowym,
## tier 0 — decyzja usera 2026-10-25): na poziomie L wróg ma bazę × for_level(L, tier, sprzęt mapy) / for_level(1, tier, 0),
## więc ręcznie strojone odmiany (np. szybszy nietoperz z mniejszym HP) zachowują proporcje względem bohatera.

const MAX_LEVEL := QuizRpgStatScale.MAX_LEVEL

## Mnożnik ATK z krzywej wrogów dla tieru (na lv 1 cios tieru: 10 / 14 / 16 / 15 % HP bohatera wzorcowego, jak dotąd).
const ENEMY_ATK_MULT := {1: 0.79, 2: 0.96, 3: 1.04, 4: 1.0}
## Liczba zwykłych trafień bohatera wzorcowego potrzebna do zabicia wroga tieru.
const HITS_TO_KILL := {1: 1.5, 2: 4.0, 3: 6.0, 4: 12.0}
## DEF wroga jako ułamek ATK bohatera wzorcowego (zwykłe trafienie bohatera = ATK×4 − DEF×2).
const DEF_RATIO := 0.7
## Korekta tierów po testach (2026-10-29: zwykli za łatwi, bossowie za trudni) — mnożnik HP / ATK (i MAT) wroga na
## poziomie, ponad wariant. Nie wchodzi do wzoru (variant_ratio by ją znosiło), nakłada ją enemy_base po wariancie.
const TIER_BALANCE := {1: {"hp": 1.6, "atk": 1.15}, 2: {"hp": 1.15, "atk": 1.05}, 3: {"hp": 1.0, "atk": 1.0}, 4: {"hp": 0.7, "atk": 0.9}}
## Stałe obrażenia umiejętności wrogów (base_damage) rosną z poziomem: pełne od tego poziomu, niżej proporcjonalnie
## (min. BASE_DAMAGE_MIN_SCALE) — bez tego umiejętności z base_damage 100–200 zabijały jednym ciosem na lv 5–9.
const BASE_DAMAGE_FULL_LEVEL := 20.0
const BASE_DAMAGE_MIN_SCALE := 0.25


static func base_damage_scale(level: int) -> float:
	return clampf(float(level) / BASE_DAMAGE_FULL_LEVEL, BASE_DAMAGE_MIN_SCALE, 1.0) if level > 0 else 1.0


const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const GEAR_TIERS_PATH := "resources/data/gear_tiers.json"

static var _hero: QuizRpgHeroData = null
## tier sprzętu -> {atk, def} (suma premii przedmiotów z gear_tiers.json).
static var _gear: Dictionary = {}


## Premie rekomendowanego sprzętu tieru: {atk, def}; nieznany tier — najbliższy niższy (brak pliku — zero).
static func gear(gear_tier: int) -> Dictionary:
	if _gear.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(QuizRpgPaths.path(GEAR_TIERS_PATH)))
		var tiers: Dictionary = data.get("tiers", {}) if data is Dictionary else {}
		for k in tiers:
			var sum := {"atk": 0.0, "def": 0.0}
			for item_id in tiers[k]:
				var item := load(QuizRpgPaths.path("resources/items/%s.tres" % item_id)) as QuizRpgItemData
				if item != null:
					sum["atk"] += float(item.atk_bonus)
					sum["def"] += float(item.def_bonus)
			_gear[int(str(k))] = sum
	for t in range(gear_tier, -1, -1):
		if _gear.has(t):
			return _gear[t]
	return {"atk": 0.0, "def": 0.0}


## Bohater wzorcowy z poziomu w rekomendowanym sprzęcie tieru: {hp, atk, def, agi}.
static func hero_ref(level: int, gear_tier: int = 0) -> Dictionary:
	if _hero == null:
		_hero = QuizRpgHeroData.new()
	var l := clampi(level, 1, MAX_LEVEL)
	var g := gear(gear_tier)
	return {
		"hp": float(_hero.hp_for_level(l, MAX_LEVEL)),
		"atk": QuizRpgStatScale.stat(_hero.base_atk, _hero.atk_per_level, l) + float(g["atk"]),
		"def": QuizRpgStatScale.stat(_hero.base_def, _hero.def_per_level, l) + float(g["def"]),
		"agi": float(_hero.base_agi) + _hero.agi_per_level * float(l - 1),
	}


## Statystyki bazowe (wariant 1,0) wroga o poziomie, tierze i rekomendowanym tierze sprzętu: {hp, atk, def, agi}
## (AGI jak bohater wzorcowy).
static func for_level(level: int, tier: int, gear_tier: int = 0) -> Dictionary:
	var t := clampi(tier, 1, 4)
	var l := clampi(level, 1, MAX_LEVEL)
	var h := hero_ref(l, gear_tier)
	var e_def: float = DEF_RATIO * h["atk"]
	var hero_hit: float = maxf(4.0 * h["atk"] - 2.0 * e_def, 1.0)
	var curve_def := QuizRpgStatScale.stat(_hero.base_def, _hero.def_per_level, l) + QuizRpgStatScale.shop_armor(l)
	var e_atk: float = QuizRpgStatScale.enemy_atk(l) * float(ENEMY_ATK_MULT[t]) + (h["def"] - curve_def) * 0.5
	return {"hp": maxf(hero_hit * float(HITS_TO_KILL[t]), 1.0), "atk": maxf(e_atk, 1.0), "def": e_def, "agi": h["agi"]}


## Stosunek statystyk bazowych wroga (= poziom 1) do wzoru na poziomie 1 w sprzęcie startowym: {hp, atk, def, agi}.
static func variant_ratio(tier: int, hp: int, atk: int, def: int, agi: int) -> Dictionary:
	var b := for_level(1, tier, 0)
	return {"hp": float(hp) / b["hp"], "atk": float(atk) / b["atk"], "def": float(def) / b["def"], "agi": float(agi) / b["agi"]}
