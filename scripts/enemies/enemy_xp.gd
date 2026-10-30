class_name QuizRpgEnemyXp
extends RefCounted

## XP za pokonanie wroga z jego poziomu (decyzja usera 2026-10-12: 15 map, wyczyszczenie 120 % wrogów z każdej mapy ma
## dać razem poziom 100). Wróg o poziomie L daje KILL_FRACTION × XP potrzebne bohaterowi z poziomu L na następny,
## razy waga tieru (tier 1 słabszy, 3 mocniejszy); boss — BOSS_MULT razy więcej. KILL_FRACTION ≈ 0,09 wychodzi z
## budżetu: ok. 72 zabić na mapę (120 %), każda mapa ≈ 1/15 drogi do lv 100 (jaskinie do lv 8–9). Wróg z poziomem 0
## ma stałe xp_reward z danych (tutorial). Tabela budżetów: docs/kontekst/poziomy_i_xp.md.

const KILL_FRACTION := 0.12  # 2026-10-30: grind za żmudny (wrogowie nie wracają, XP za odpowiedzi tylko po wygranej)
const TIER_WEIGHT := {1: 0.6, 2: 1.0, 3: 1.6}
const BOSS_MULT := 6.0

static var _hero: QuizRpgHeroData = null


## Schodki poziomów (pomysł usera 2026-10-30): XP walki × mnożnik z różnicy (poziom wroga − poziom gracza) —
## na nowej mapie (wrogowie wyżej) szybko, przy jej końcu coraz wolniej, a o LEVEL_GAP_ZERO poziomów nad wrogami nic.
## Obejmuje też XP za odpowiedzi w walce (inaczej grind quizami na starej mapie). Wróg bez poziomu (0) = ×1.
const LEVEL_STEP := 0.2         # zmiana mnożnika na poziom różnicy
const LEVEL_MULT_MAX := 1.5     # wrogowie wyżej o 3+
const BOSS_LEVEL_MULT_MIN := 0.5  # boss zawsze coś daje


static func level_mult(enemy_level: int, player_level: int, is_boss: bool = false) -> float:
	if enemy_level <= 0:
		return 1.0
	var m := clampf(1.0 + LEVEL_STEP * float(enemy_level - player_level), 0.0, LEVEL_MULT_MAX)
	return maxf(m, BOSS_LEVEL_MULT_MIN) if is_boss else m


static func kill_xp(level: int, tier: int, is_boss: bool = false) -> int:
	if _hero == null:
		_hero = QuizRpgHeroData.new()
	var base := float(_hero.xp_to_next(clampi(level, 1, 99), true)) * KILL_FRACTION * float(TIER_WEIGHT.get(clampi(tier, 1, 3), 1.0))
	return maxi(roundi(base * (BOSS_MULT if is_boss else 1.0)), 1)
