extends RefCounted
class_name QuizRpgSkillMath

## Obrażenia i leczenie umiejętności (QuizRpgSkillBase) — te same dla gracza i wrogów. Staty jako słowniki
## {atk, def, mat, mdf}: użytkownik (atk / mat) i cel (def / mdf).

## Zwykły atak bez umiejętności: ATK × 4 − DEF × 2, rozrzut ±10 % (jak „Scream” w FNaFB).
const BASIC_VARIANCE := 0.1


## Obrażenia jednego trafienia (co najmniej 1; DamageMode.NONE -> 0). rng: losowanie rozrzutu (testy podają własny).
static func damage(skill: QuizRpgSkillBase, user: Dictionary, target: Dictionary, rng: RandomNumberGenerator = null) -> int:
	if skill == null:
		return basic_attack(user, target, rng)
	match skill.damage_mode:
		QuizRpgSkillBase.DamageMode.NONE:
			return 0
		QuizRpgSkillBase.DamageMode.FIXED:
			return maxi(roundi(skill.fixed_damage * _spread(skill.variance, rng)), 1)
	var raw := float(skill.base_damage) \
		+ float(user.get("atk", 0)) * skill.atk_coeff + float(user.get("mat", 0)) * skill.mat_coeff \
		- float(target.get("def", 0)) * skill.def_coeff - float(target.get("mdf", 0)) * skill.mdf_coeff
	return maxi(roundi(raw * skill.damage_multiplier * _spread(skill.variance, rng)), 1)


static func basic_attack(user: Dictionary, target: Dictionary, rng: RandomNumberGenerator = null) -> int:
	var raw := float(user.get("atk", 0)) * 4.0 - float(target.get("def", 0)) * 2.0
	return maxi(roundi(raw * _spread(BASIC_VARIANCE, rng)), 1)


## Leczenie celu o maks. HP max_hp (0 = umiejętność nie leczy).
static func heal(skill: QuizRpgSkillBase, max_hp: int) -> int:
	if skill == null:
		return 0
	match skill.heal_mode:
		QuizRpgSkillBase.HealMode.FIXED:
			return skill.heal_amount
		QuizRpgSkillBase.HealMode.PERCENT:
			return maxi(ceili(max_hp * skill.heal_percent), 1)
	return 0


## Czy trafienie wchodzi (success_rate × dodatkowa szansa, np. z quizu).
static func roll_hit(skill: QuizRpgSkillBase, extra_chance: float = 1.0, rng: RandomNumberGenerator = null) -> bool:
	var chance := extra_chance * (skill.success_rate if skill != null else 1.0)
	return (rng.randf() if rng else randf()) < chance


static func _spread(variance: float, rng: RandomNumberGenerator) -> float:
	if variance <= 0.0:
		return 1.0
	return rng.randf_range(1.0 - variance, 1.0 + variance) if rng else randf_range(1.0 - variance, 1.0 + variance)
