class_name QuizRpgRandomEncounters
extends Node

## Losowe spotkania jak w JRPG (obok widocznych wrogów): po przejściu min_distance z każdym krokiem (kratką) rośnie szansa
## na spotkanie, aż do pewności przy max_distance — walka zaczyna się nagle z niewidzialnym wrogiem z puli mapy (ProceduralLevel: enemy_pool / faction_pools / enemy_levels). Konfiguracja z
## companion-JSON mapy, klucz "random_encounters":
##   mode          "off" (domyślnie) | "always" | "cleared" (dopiero gdy na mapie nie ma już zwykłych wrogów)
##   min_distance / max_distance   px od ostatniej walki: do min_distance spotkania nie ma, od max_distance jest pewne
##   max_chance    szansa na krok tuż przed max_distance (rośnie liniowo od 0 przy min_distance), domyślnie 0,12
##   tiers         {"1": waga, "2": waga…} — tier wroga wg wag (domyślnie najniższy tier puli)
## Nie liczy się dystans w azylu startowym, w walce, w dialogu ani podczas nietykalności po walce.

const MODE_OFF := "off"
const MODE_ALWAYS := "always"
const MODE_CLEARED := "cleared"
const DEFAULT_MIN := 480.0
const DEFAULT_MAX := 1100.0
const DEFAULT_MAX_CHANCE := 0.12
const STEP := 16.0   # px = jedna kratka = jeden „krok” losowania

var mode := MODE_OFF
var min_distance := DEFAULT_MIN
var max_distance := DEFAULT_MAX
var max_chance := DEFAULT_MAX_CHANCE
var tier_weights: Dictionary = {}   # tier (int) -> waga
var _pool: Array = []
var _faction_pools: Dictionary = {}
var _levels: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _player: Node2D
var _last_pos := Vector2.ZERO
var _walked := 0.0
var _step_acc := 0.0


## Tworzy komponent z configu mapy; null, gdy tryb wyłączony albo brak puli wrogów.
static func create(cfg: Dictionary, pool: Array, faction_pools: Dictionary, levels: Dictionary) -> QuizRpgRandomEncounters:
	var m := str(cfg.get("mode", MODE_OFF))
	if m != MODE_ALWAYS and m != MODE_CLEARED:
		return null
	if pool.is_empty() and faction_pools.is_empty():
		return null
	var re := QuizRpgRandomEncounters.new()
	re.name = "RandomEncounters"
	re.mode = m
	re.min_distance = maxf(float(cfg.get("min_distance", DEFAULT_MIN)), 16.0)
	re.max_distance = maxf(float(cfg.get("max_distance", DEFAULT_MAX)), re.min_distance + STEP)
	re.max_chance = clampf(float(cfg.get("max_chance", DEFAULT_MAX_CHANCE)), 0.0, 1.0)
	var tw: Variant = cfg.get("tiers", {})
	if tw is Dictionary:
		for k in tw:
			re.tier_weights[int(str(k))] = float(tw[k])
	re._pool = pool
	re._faction_pools = faction_pools
	re._levels = levels
	return re


func _ready() -> void:
	_rng.randomize()
	reset_walk()


func reset_walk() -> void:
	_walked = 0.0
	_step_acc = 0.0


## Szansa na spotkanie przy kolejnym kroku po przejściu `walked` px od ostatniej walki.
func chance_at(walked: float) -> float:
	if walked < min_distance:
		return 0.0
	if walked >= max_distance:
		return 1.0
	return max_chance * (walked - min_distance) / (max_distance - min_distance)


func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player != null:
			_last_pos = _player.global_position
		return
	var pos := _player.global_position
	var step := pos.distance_to(_last_pos)
	_last_pos = pos
	if step > 64.0 or not _can_count():
		return   # teleport (przejście, powrót z sekretnego pokoju) albo stan, w którym spotkania nie liczą dystansu
	_walked += step
	_step_acc += step
	while _step_acc >= STEP:
		_step_acc -= STEP
		if _rng.randf() < chance_at(_walked):
			reset_walk()
			trigger()
			return


## Czy w tej chwili dystans się liczy (eksploracja, poza azylem i nietykalnością, tryb „cleared” po wyczyszczeniu).
func _can_count() -> bool:
	var gm := QuizRpgNpcContext.singleton(self, "GameManager")
	if gm != null and "current_state" in gm and int(gm.current_state) != int(gm.GameState.EXPLORING):
		return false
	if get_tree().paused:
		return false
	if _player.has_method("is_encounter_immune") and _player.is_encounter_immune():
		return false
	if QuizRpgSafeZone.contains(get_tree(), _player.global_position):
		return false
	if mode == MODE_CLEARED and _live_regular_enemies() > 0:
		return false
	return true


func _live_regular_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_meta("random_encounter") or not get_parent().is_ancestor_of(e):
			continue
		if bool(e.get("defeated")) or bool(e.get("is_boss")):
			continue
		n += 1
	return n


## Tier wroga wg wag (bez wag — najniższy tier puli).
func pick_tier() -> int:
	var total := 0.0
	for t in tier_weights:
		total += maxf(float(tier_weights[t]), 0.0)
	if total <= 0.0:
		return 1
	var r := _rng.randf() * total
	for t in tier_weights:
		r -= maxf(float(tier_weights[t]), 0.0)
		if r <= 0.0:
			return int(t)
	return int(tier_weights.keys()[0])


## Tworzy niewidzialnego wroga i zaczyna walkę. Zwraca go (null — nic nie wylosowano).
func trigger() -> Node2D:
	var pool: Array = _pool
	if pool.is_empty() and not _faction_pools.is_empty():
		pool = _faction_pools[_faction_pools.keys()[0]]
	if pool.is_empty() or _player == null:
		return null
	var tier := pick_tier()
	var idx := clampi(tier - 1, 0, pool.size() - 1)
	var entry: Variant = pool[idx]
	var packed: PackedScene
	if entry is Array:
		packed = (entry as Array)[_rng.randi() % (entry as Array).size()] as PackedScene
	else:
		packed = entry as PackedScene
	if packed == null:
		return null
	var enemy := packed.instantiate() as Node2D
	if enemy == null:
		return null
	enemy.set_meta("random_encounter", true)
	enemy.visible = false
	enemy.position = _player.global_position - get_parent().global_position
	var band: Variant = _levels.get(str(idx + 1))
	if band is Array and (band as Array).size() == 2 and enemy.has_method("set_enemy_level"):
		var lo := int(band[0])
		enemy.call("set_enemy_level", _rng.randi_range(lo, maxi(int(band[1]), lo)), 1.0)
	get_parent().add_child(enemy)
	enemy.remove_from_group("enemies")
	enemy.call("start_combat", _player)
	return enemy
