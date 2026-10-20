class_name QuizRpgEnemyStats
extends RefCounted

## Statystyki wroga z poziomu (faza 2 poziomów, 2026-10-12; skala FNaFB 2026-10-21). Wróg o poziomie L i tierze T:
## - ATK z własnej krzywej wrogów (QuizRpgStatScale.enemy_atk: Party Hat Alpha -> Omega FNaFB1, rozciągnięte na lv 1–100 i skalowane
##   z HP) × ENEMY_ATK_MULT[T] — pancerz bohatera waży tyle co w FNaFB (komplet ze sklepu tnie cios o ≈ 14 % na lv 1, 22 % na lv 100);
##   cios na bohaterze wzorcowym: tier 2 ≈ 14 % HP na lv 1, ≈ 30 % na lv 100 (jak Omega na Freddym lv 20);
## - HP i DEF z „bohatera wzorcowego” z poziomu L (statystyki z QuizRpgStatScale + sprzęt ze sklepu): bohater zabija go
##   w HITS_TO_KILL[T] zwykłych trafieniach, DEF = DEF_RATIO × ATK bohatera.
## ATK = MAT, DEF = MDF (jak dotąd). Wróg z poziomem 0 (tutorial) zostaje przy statystykach z danych.
## Wzorzec wariantu: stosunek statystyk wroga do bazy jego tieru (TIER_BASE) przenosi się na wynik, więc ręcznie strojone odmiany
## (np. szybszy nietoperz z mniejszym HP) zachowują proporcje.

const MAX_LEVEL := QuizRpgStatScale.MAX_LEVEL

## Mnożnik ATK z krzywej wrogów dla tieru (na lv 1 cios tieru: 10 / 14 / 16 / 15 % HP bohatera wzorcowego, jak dotąd).
const ENEMY_ATK_MULT := {1: 0.79, 2: 0.96, 3: 1.04, 4: 1.0}
## Liczba zwykłych trafień bohatera wzorcowego potrzebna do zabicia wroga tieru.
const HITS_TO_KILL := {1: 1.5, 2: 4.0, 3: 6.0, 4: 12.0}
## DEF wroga jako ułamek ATK bohatera wzorcowego (zwykłe trafienie bohatera = ATK×4 − DEF×2).
const DEF_RATIO := 0.7

## AGI wroga w danych dla każdego tieru (wariant 1,0) — szybszy / wolniejszy wróg ma odpowiednio więcej / mniej.
const AGI_BASE := 15.0

## Bazowe statystyki tieru w danych (HP, ATK, DEF) — odniesienie do wariantów.
const TIER_BASE := {1: [100, 26, 30], 2: [400, 60, 61], 3: [900, 90, 90], 4: [2500, 155, 140]}

static var _hero: QuizRpgHeroData = null


## Bohater wzorcowy z poziomu (sprzęt ze sklepu lokacji): {hp, atk, def, agi}.
static func hero_ref(level: int) -> Dictionary:
	if _hero == null:
		_hero = QuizRpgHeroData.new()
	var l := clampi(level, 1, MAX_LEVEL)
	return {
		"hp": float(_hero.hp_for_level(l, MAX_LEVEL)),
		"atk": QuizRpgStatScale.stat(_hero.base_atk, _hero.atk_per_level, l) + QuizRpgStatScale.shop_weapon(l),
		"def": QuizRpgStatScale.stat(_hero.base_def, _hero.def_per_level, l) + QuizRpgStatScale.shop_armor(l),
		"agi": float(_hero.base_agi) + _hero.agi_per_level * float(l - 1),
	}


## Statystyki bazowe (wariant 1,0) wroga o poziomie i tierze: {hp, atk, def, agi} (AGI jak bohater wzorcowy).
static func for_level(level: int, tier: int) -> Dictionary:
	var t := clampi(tier, 1, 4)
	var h := hero_ref(level)
	var e_def: float = DEF_RATIO * h["atk"]
	var hero_hit: float = maxf(4.0 * h["atk"] - 2.0 * e_def, 1.0)
	var e_atk: float = QuizRpgStatScale.enemy_atk(level) * float(ENEMY_ATK_MULT[t])
	return {"hp": maxf(hero_hit * float(HITS_TO_KILL[t]), 1.0), "atk": e_atk, "def": e_def, "agi": h["agi"]}


## Stosunek statystyk wariantu do bazy tieru: {hp, atk, def, agi}.
static func variant_ratio(tier: int, hp: int, atk: int, def: int, agi: int = int(AGI_BASE)) -> Dictionary:
	var b: Array = TIER_BASE[clampi(tier, 1, 4)]
	return {"hp": float(hp) / float(b[0]), "atk": float(atk) / float(b[1]), "def": float(def) / float(b[2]), "agi": float(agi) / AGI_BASE}
