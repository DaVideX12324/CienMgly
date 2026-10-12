class_name QuizRpgEnemyStats
extends RefCounted

## Statystyki wroga z poziomu (faza 2 poziomów, 2026-10-12). Wróg o poziomie L i tierze T ma statystyki dobrane do „bohatera wzorcowego” z poziomu L
## (statystyki z krzywych + ekwipunek idący po krzywej GEAR_*), tak żeby proporcje walki trzymały się na każdej mapie:
## zwykły atak wroga zabiera HIT_FRAC[T] maks. HP bohatera, bohater zabija go w HITS_TO_KILL[T] zwykłych trafieniach.
## ATK = MAT, DEF = MDF (jak dotąd). Wróg z poziomem 0 (tutorial) zostaje przy statystykach z danych.
## Wzorzec wariantu: stosunek statystyk wroga do bazy jego tieru (TIER_BASE) przenosi się na wynik, więc ręcznie strojone odmiany
## (np. szybszy nietoperz z mniejszym HP) zachowują proporcje.

## Ekwipunek wzorcowy: broń (+ATK) i suma pancerza (+DEF) rosną wykładniczo od poziomu 1 do MAX_LEVEL (training_sword 10 -> shadowbane 320;
## cloth_cap + tunika + drewniana tarcza + talizman 14 -> komplet tieru 5 ok. 194). Gracz poniżej krzywej ekwipunku jest słabszy od wzorca.
const MAX_LEVEL := 100
const GEAR_ATK_START := 10.0
const GEAR_ATK_END := 320.0
const GEAR_DEF_START := 14.0
const GEAR_DEF_END := 194.0

## Ułamek maks. HP bohatera zabierany zwykłym atakiem wroga danego tieru i liczba zwykłych trafień bohatera potrzebna do zabicia.
const HIT_FRAC := {1: 0.10, 2: 0.14, 3: 0.16, 4: 0.15}
const HITS_TO_KILL := {1: 1.5, 2: 4.0, 3: 6.0, 4: 12.0}
## DEF wroga jako ułamek ATK bohatera wzorcowego (zwykłe trafienie bohatera = ATK×4 − DEF×2).
const DEF_RATIO := 0.7

## Bazowe statystyki tieru w danych (HP, ATK, DEF) — odniesienie do wariantów.
const TIER_BASE := {1: [100, 26, 30], 2: [400, 60, 61], 3: [900, 90, 90], 4: [2500, 155, 140]}

static var _hero: QuizRpgHeroData = null


## Bohater wzorcowy z poziomu: {hp, atk, def}.
static func hero_ref(level: int) -> Dictionary:
	if _hero == null:
		_hero = QuizRpgHeroData.new()
	var l := clampi(level, 1, MAX_LEVEL)
	var t := float(l - 1) / float(MAX_LEVEL - 1)
	return {
		"hp": float(_hero.hp_for_level(l, MAX_LEVEL)),
		"atk": float(_hero.base_atk) + _hero.atk_per_level * float(l - 1) + GEAR_ATK_START * pow(GEAR_ATK_END / GEAR_ATK_START, t),
		"def": float(_hero.base_def) + _hero.def_per_level * float(l - 1) + GEAR_DEF_START * pow(GEAR_DEF_END / GEAR_DEF_START, t),
	}


## Statystyki bazowe (wariant 1,0) wroga o poziomie i tierze: {hp, atk, def}.
static func for_level(level: int, tier: int) -> Dictionary:
	var t := clampi(tier, 1, 4)
	var h := hero_ref(level)
	var e_def: float = DEF_RATIO * h["atk"]
	var hero_hit: float = maxf(4.0 * h["atk"] - 2.0 * e_def, 1.0)
	var e_atk: float = (float(HIT_FRAC[t]) * h["hp"] + 2.0 * h["def"]) / 4.0
	return {"hp": maxf(hero_hit * float(HITS_TO_KILL[t]), 1.0), "atk": e_atk, "def": e_def}


## Stosunek statystyk wariantu do bazy tieru: {hp, atk, def}.
static func variant_ratio(tier: int, hp: int, atk: int, def: int) -> Dictionary:
	var b: Array = TIER_BASE[clampi(tier, 1, 4)]
	return {"hp": float(hp) / float(b[0]), "atk": float(atk) / float(b[1]), "def": float(def) / float(b[2])}
