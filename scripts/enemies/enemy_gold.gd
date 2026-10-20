class_name QuizRpgEnemyGold
extends RefCounted

## Złoto za pokonanie wroga (decyzja usera 2026-10-12: złoto wypada już od tutorialu, większość wydaje się na mikstury HP / SP;
## sklep i tiery sprzętu po odblokowaniu miasta). Złoto z wroga tieru 2 = GOLD_PER_ATK × ATK standardowej broni z jego poziomu
## (broń ze sklepu, QuizRpgStatScale) × waga tieru (jak w XP); boss BOSS_MULT razy więcej. Stała GOLD_PER_ATK jest
## dowolna — ceny w sklepie liczy się w „zabiciach zwykłego wroga” (docs/kontekst/ekwipunek_szkic.md). Rozmiar mapy: jak XP
## (skala po liczbie spawnów) nakłada EnemyBase.

const GOLD_PER_ATK := 2.0
const TIER_WEIGHT := {1: 0.6, 2: 1.0, 3: 1.6}
const BOSS_MULT := 6.0


## ATK standardowej broni na poziomie L (broń ze sklepu, QuizRpgStatScale: 10 -> ≈ 5700 od lv 1 do 100).
static func standard_weapon_atk(level: int) -> float:
	return QuizRpgStatScale.shop_weapon(level)


static func kill_gold(level: int, tier: int, is_boss: bool = false) -> int:
	var base := standard_weapon_atk(level) * GOLD_PER_ATK * float(TIER_WEIGHT.get(clampi(tier, 1, 3), 1.0))
	return maxi(roundi(base * (BOSS_MULT if is_boss else 1.0)), 1)
