extends RefCounted
class_name QuizRpgSkillSlots

## Sloty umiejętności (docs/kontekst/sloty_umiejetnosci_szkic.md): skill ma tiery [tier_min, tier_max]; aktywny skill na
## tierze T kosztuje TIER_COST[T] jednostek wspólnego budżetu członka. Budżet i maks. tier rosną z poziomem członka,
## akcesoria mogą je zmienić (QuizRpgItemData.slot_budget / max_tier_bonus). Skan jest poza budżetem (zawsze dostępny).
## W walce i w menu działają tylko aktywne skille (PlayerStats.get_member_battle_skills).

## Koszt aktywnego skilla na tierze 1..4 w jednostkach budżetu (T4 „zjada” pięć T1).
const TIER_COST: Array[int] = [1, 2, 3, 5]
## Poziom członka, od którego wolno ustawić tier 1, 2, 3, 4 (tiery 5+ dojdą z rozwojem gry).
const TIER_LEVELS: Array[int] = [1, 6, 12, 20]
## Budżet rośnie liniowo od BUDGET_MIN (lv 1) do BUDGET_MAX (BUDGET_MAX_LEVEL i wyżej).
const BUDGET_MIN := 3
const BUDGET_MAX := 11
const BUDGET_MAX_LEVEL := 20
## Twardy limit aktywnych skilli naraz (menu w walce nie puchnie).
const MAX_ACTIVE := 6


static func cost(tier: int) -> int:
	return TIER_COST[clampi(tier, 1, TIER_COST.size()) - 1] if tier > 0 else 0


## Najwyższy tier, jaki członek może ustawić (bonus z akcesoriów; co najmniej 1, najwyżej liczba tierów).
static func max_tier(level: int, bonus: int = 0) -> int:
	var t := 0
	for l in TIER_LEVELS:
		if level >= l:
			t += 1
	return clampi(t + bonus, 1, TIER_LEVELS.size())


static func budget(level: int, bonus: int = 0) -> int:
	var f := clampf(float(level - 1) / float(BUDGET_MAX_LEVEL - 1), 0.0, 1.0)
	return maxi(roundi(lerpf(BUDGET_MIN, BUDGET_MAX, f)) + bonus, 0)


## Skill poza budżetem (nie zajmuje slotu, zawsze aktywny).
static func is_free(skill: QuizRpgSkillData) -> bool:
	return skill != null and skill.scan


## Zakres tierów skilla dla członka: [tier_min, min(tier_max, maks. tier członka)]; pusty (x > y), gdy tier startowy
## jest jeszcze za wysoki.
static func tier_range(skill: QuizRpgSkillData, member_max_tier: int) -> Vector2i:
	return Vector2i(skill.tier_min, mini(skill.tier_max, member_max_tier))
