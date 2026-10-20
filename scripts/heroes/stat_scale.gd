class_name QuizRpgStatScale
extends RefCounted

## Skala statystyk do lv 100 „jak FNaFB1” (decyzja usera 2026-10-21): nasze lv 1–100 to rozciągnięte lv 1–20 FNaFB1
## (fnafb_level), a wszystko poza HP i SP rośnie dodatkowo razem z krzywą HP (factor = HP bohatera wzorcowego / HP Freddy'ego
## z tego samego punktu FNaFB). HP do 50 000 zostaje, a proporcje na lv 100 są jak u Freddy'ego na lv 20: sprzęt ze sklepu
## ≈ 73 % ATK, pancerz ze sklepu tnie cios najsilniejszego zwykłego wroga o ≈ 22 %, cios ≈ 32 % HP.
## Przyrost statystyk z danych postaci (*_per_level) to przyrost na poziom FNaFB (Freddy ATK 21 -> 58: 1,95 / poziom FNaFB).
## AGI bez skali (kolejność tur, stałe prędkości umiejętności).

const MAX_LEVEL := 100
const FNAFB_LEVELS := 20
## Freddy (FNaFB1): HP 334 -> 1402 liniowo na lv 1–20.
const FNAFB_HP_FIRST := 334.0
const FNAFB_HP_LAST := 1402.0
## Sprzęt sklepu FNaFB1 na lv 1 -> 20 (×2 na lokację): broń 10 -> 160 ATK, pancerz 4 -> 64 DEF (jeden komplet = u nas
## głowa + korpus + tarcza razem).
const SHOP_WEAPON_FIRST := 10.0
const SHOP_WEAPON_LAST := 160.0
const SHOP_ARMOR_FIRST := 4.0
const SHOP_ARMOR_LAST := 64.0
## Party Hat Alpha -> Omega: ATK 20 -> 160 (najsilniejszy zwykły wróg lokacji).
const ENEMY_ATK_FIRST := 20.0
const ENEMY_ATK_LAST := 160.0

static var _factors := PackedFloat32Array()


## Poziom FNaFB odpowiadający naszemu poziomowi (1..20, ułamkowy).
static func fnafb_level(level: float) -> float:
	return 1.0 + (clampf(level, 1.0, MAX_LEVEL) - 1.0) * float(FNAFB_LEVELS - 1) / float(MAX_LEVEL - 1)


## Mnożnik skali poziomu: HP bohatera wzorcowego / HP Freddy'ego w tym samym punkcie FNaFB (lv 1: 1, lv 100: ≈ 35,7).
static func factor(level: int) -> float:
	if _factors.is_empty():
		var hero := QuizRpgHeroData.new()
		_factors.resize(MAX_LEVEL + 1)
		for l in range(1, MAX_LEVEL + 1):
			var f := fnafb_level(l)
			var hp_f := lerpf(FNAFB_HP_FIRST, FNAFB_HP_LAST, (f - 1.0) / float(FNAFB_LEVELS - 1))
			_factors[l] = float(hero.hp_for_level(l, MAX_LEVEL)) / hp_f
		_factors[0] = _factors[1]
	return _factors[clampi(level, 1, MAX_LEVEL)]


## Statystyka postaci z poziomu: (baza + przyrost na poziom FNaFB × (poziom FNaFB − 1)) × factor.
static func stat(base: float, per_level: float, level: int) -> float:
	return (base + per_level * (fnafb_level(level) - 1.0)) * factor(level)


## Wartość rosnąca wykładniczo jak sprzęt / wrogowie FNaFB (first na lv 1, last na lv 20 FNaFB) × factor.
static func curve(first: float, last: float, level: int) -> float:
	var t := (fnafb_level(level) - 1.0) / float(FNAFB_LEVELS - 1)
	return first * pow(last / first, t) * factor(level)


## Broń ze sklepu (standard) na poziomie lokacji.
static func shop_weapon(level: int) -> float:
	return curve(SHOP_WEAPON_FIRST, SHOP_WEAPON_LAST, level)


## Komplet pancerza ze sklepu (głowa + korpus + tarcza) na poziomie lokacji.
static func shop_armor(level: int) -> float:
	return curve(SHOP_ARMOR_FIRST, SHOP_ARMOR_LAST, level)


## ATK najsilniejszego zwykłego wroga lokacji (Party Hat) — własna krzywa wrogów.
static func enemy_atk(level: int) -> float:
	return curve(ENEMY_ATK_FIRST, ENEMY_ATK_LAST, level)
