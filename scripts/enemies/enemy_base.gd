extends CharacterBody2D
class_name EnemyBase

## Bazowa klasa przeciwnika — patroluje, wykrywa gracza, inicjuje walke quizowa.
## Programmer art: rysowany kodem jesli brak sprite frames.

const QuizRpgEnemyData = preload("res://modules/quiz_rpg/scripts/enemies/enemy_data.gd")

@export var enemy_data: QuizRpgEnemyData
@export_group("Identity")
@export var enemy_name: String = "Przeciwnik"
@export var quiz_id: String = "inf_podst"
@export var quiz_category: String = "ogolne"
@export_group("Combat")
@export var question_count: int = 3
@export var hp: int = 50
@export var max_hp: int = 50
@export var damage_on_wrong: int = 15
@export var xp_reward: int = 50
@export_range(1, 5, 1) var encounter_tier: int = 2
@export var min_encounter_size: int = 1
@export var max_encounter_size: int = 3
@export var is_boss: bool = false
## Trwałe id bossa dla zapisu pokonania/respawnu (puste => generowane z nazwy+pozycji).
## Używane tylko gdy is_boss = true. Zmienne per seed (reroll => nowa pozycja/id).
@export var unique_id: String = ""
## Stabilne story-id bossa dla postępu urządzenia arcymaga (fabuła). NIE zmienia się
## przy rerollu — dzięki temu ten sam story-boss nie liczy się dwa razy. Puste =>
## fallback do level_path (jeden krok postępu na mapę). Ustaw np. "boss_desert_fragment1".
@export var boss_story_id: String = ""
## Czy ten boss dobija pasek postępu urządzenia. Odznacz dla bossów, które nie mają
## się liczyć (globalna bramka fazy jest osobno w LevelStateManager).
@export var counts_toward_device: bool = true
@export_group("Movement")
@export var patrol_speed: float = 80.0
@export var detection_radius: float = 150.0
@export_group("AI Behavior")
@export var wander_radius: float = 100.0
@export var memory_duration: float = 3.0
@export_group("Visual")
@export var body_color: Color = Color(0.9, 0.2, 0.2)
## 2-way: odbicie w poziomie dopiero, gdy |kierunek.x| (wektor znormalizowany) przekracza próg —
## ruch prawie pionowy nie przerzuca sprite'a. 0 = każdy ruch w bok.
@export_range(0.0, 0.95, 0.05) var flip_threshold: float = 0.3
## 4-way: o ile składowa jednej osi musi przewyższać drugą, żeby zmienić kierunek (histereza jak
## w Amon-Ra) — na skosach zostaje poprzedni kierunek, sprite nie migocze.
@export_range(0.0, 0.9, 0.05) var direction_hysteresis: float = 0.5

enum State { IDLE, PATROL, CHASING, COMBAT, DEFEATED }
var state: State = State.PATROL

var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var patrol_stuck_timer: float = 0.0

var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var is_idle_pause: bool = false
var memory_timer: float = 0.0
var last_seen_player_pos: Vector2 = Vector2.ZERO

var player_ref: Node2D = null
var defeated: bool = false
var _use_programmer_art: bool = true
var _anim_time: float = 0.0
var _flash_timer: float = 0.0
var _flash_color: Color = Color.WHITE
var _uses_directional_animations: bool = false
var _last_facing_dir: String = "down"
var _anim_walk_2way: StringName = &""   # 2-way: animacja chodu / spoczynku wykryta w SpriteFrames
var _anim_idle_2way: StringName = &""   # („walk”, „slime_walk”…), patrz _resolve_2way_anims

enum EnemyShape { DIAMOND, CIRCLE, TRIANGLE, SQUARE, HEXAGON }
@export var shape_type: EnemyShape = EnemyShape.DIAMOND

## Maska promienia widoczności (jak w Amon-Ra: promień trafia zasłonę albo gracza): warstwa 1 „Player”
## + warstwa 3 „GroundCollisions” (ściany); do tego warstwa obiektów „ObjectCollisions” (ObjectBake).
## Domyślna maska RayCast2D (1) nie widziała ścian — wróg widział przez nie.
const SIGHT_RAY_MASK := 1 | 4

const OUTLINE_COLOR := Color(0.15, 0.1, 0.1)
const EYE_COLOR    := Color(1.0, 0.9, 0.2)

# Singletony
var _ps: Node   # PlayerStats
var _dm: Node   # DifficultyManager
var _gm: Node   # GameManager

@onready var _raycast: RayCast2D = get_node_or_null("RayCast2D")
@onready var _nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
var _grid: Dictionary = {}   # siatka mapy (ProceduralLevel.last_result.grid) — widoczność po kratkach

# Ruch po siatce nawigacji (NavOutlines z generatora).
const REPATH_INTERVAL := 0.25    # trasa przeliczana najwyżej co tyle s…
const REPATH_DISTANCE := 8.0     # …albo gdy cel przesunie się o pół kratki
const ARRIVE_DISTANCE := 6.0
const STEER_RATE := 10.0         # płynny obrót kierunku (zamiast losowych drgań z Amon-Ra)
const WANDER_PATH_FACTOR := 1.6  # cel wałęsania odrzucany, gdy ścieżka dłuższa niż promień × to (za ścianą)
const WANDER_TRIES := 6
var _nav_target := Vector2.INF
var _repath_timer := 0.0
var _move_dir := Vector2.ZERO
var _path := PackedVector2Array()   # ścieżka z NavigationServer2D (własne śledzenie — agent tylko do RVO)
var _path_i := 0


func _ready() -> void:
	_apply_enemy_data()
	# Węzeł zamiast identyfikatora autoloadu — skrypt kompiluje się też w testach (-s), gdzie
	# identyfikatory autoloadów nie istnieją w czasie kompilacji.
	var core := _core()
	if core:
		_ps = core.get_singleton("PlayerStats")
		_dm = core.get_singleton("DifficultyManager")
		_gm = core.get_singleton("GameManager")

	add_to_group("enemies")
	add_to_group("interactable")

	# Bossy: przywróć stan pokonania (per-save). Deferred + retry na level_path,
	# bo current_level_path bywa ustawiany dopiero po _ready (jak w skrzyniach).
	if is_boss:
		if unique_id.is_empty():
			unique_id = _generate_boss_id()
		call_deferred("_check_boss_defeated")

	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite is AnimatedSprite2D and sprite.sprite_frames:
		if sprite.sprite_frames.get_animation_names().size() > 0:
			_use_programmer_art = false
		if sprite.sprite_frames.has_animation("walk_down") or sprite.sprite_frames.has_animation("idle_down"):
			_uses_directional_animations = true
		_resolve_2way_anims(sprite.sprite_frames)

	if _use_programmer_art:
		if sprite:
			sprite.visible = false

	if _raycast:
		_raycast.enabled = true
		_raycast.collision_mask = SIGHT_RAY_MASK | ObjectBake.object_layer_bit()

	_setup_detection_area()
	_setup_nav_agent()

	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and cheat_service.has_signal("enemies_toggled"):
		cheat_service.enemies_toggled.connect(_on_enemies_toggled)

	wander_target = global_position
	_set_new_wander_target()


func _are_enemies_disabled() -> bool:
	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and "enemies_disabled" in cheat_service:
		return bool(cheat_service.enemies_disabled)
	return false


func _on_enemies_toggled(disabled: bool) -> void:
	if disabled:
		if state == State.CHASING:
			state = State.PATROL
		velocity = Vector2.ZERO
		player_ref = null
		if _use_programmer_art:
			queue_redraw()


func _apply_enemy_data() -> void:
	if enemy_data == null:
		hp = maxi(hp, 1)
		max_hp = maxi(max_hp, 1)
		hp = mini(hp, max_hp)
		encounter_tier = clampi(encounter_tier, 1, 5)
		return
	enemy_name = enemy_data.enemy_name
	quiz_id = enemy_data.quiz_id
	quiz_category = enemy_data.quiz_category
	question_count = enemy_data.question_count
	max_hp = maxi(enemy_data.max_hp, 1)
	hp = max_hp
	damage_on_wrong = maxi(enemy_data.damage_on_wrong, 0)
	xp_reward = maxi(enemy_data.xp_reward, 0)
	encounter_tier = clampi(enemy_data.encounter_tier, 1, 5)
	min_encounter_size = maxi(enemy_data.min_encounter_size, 1)
	max_encounter_size = maxi(enemy_data.max_encounter_size, min_encounter_size)
	is_boss = enemy_data.is_boss
	patrol_speed = enemy_data.patrol_speed
	detection_radius = enemy_data.detection_radius
	body_color = enemy_data.body_color
	shape_type = enemy_data.shape_type


func _physics_process(delta: float) -> void:
	_anim_time += delta
	if _flash_timer > 0:
		_flash_timer -= delta

	if defeated or state == State.COMBAT:
		if _use_programmer_art:
			queue_redraw()
		return

	if _are_enemies_disabled():
		if state == State.CHASING:
			state = State.PATROL
		velocity = Vector2.ZERO
		if _use_programmer_art:
			queue_redraw()
		return

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASING:
			_chase(delta)
		State.IDLE:
			pass

	if not _use_programmer_art:
		_update_sprite_animation()

	if _use_programmer_art:
		queue_redraw()


const MOVING_EPS := 5.0


func _update_sprite_animation() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return

	var moving := velocity.length() > MOVING_EPS

	if _uses_directional_animations:
		if moving:
			_last_facing_dir = _direction_name_from_velocity(velocity)
		var frames := sprite.sprite_frames
		var anim_name := ("walk_" if moving else "idle_") + _last_facing_dir
		if not frames.has_animation(anim_name):
			anim_name = "idle_" + _last_facing_dir
		if not frames.has_animation(anim_name):
			anim_name = "walk_" + _last_facing_dir
		if not frames.has_animation(anim_name):
			return
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
	else:
		var anim_name := _anim_walk_2way if moving else _anim_idle_2way
		if anim_name == &"":
			return
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
		# Odbicie tylko przy wyraźnym ruchu w bok; w bezruchu zostaje ostatnie.
		if moving:
			var dir := velocity.normalized()
			if absf(dir.x) > flip_threshold:
				sprite.flip_h = dir.x < 0.0


## 2-way: nazwy animacji chodu i spoczynku. Dokładnie „walk” / „idle” albo z przedrostkiem
## („slime_walk”, „slime_idle” — sceny z Amon-Ra); brak chodu -> spoczynek i odwrotnie; nic nie pasuje ->
## pierwsza animacja zestawu (żeby sprite w ogóle się animował).
func _resolve_2way_anims(frames: SpriteFrames) -> void:
	_anim_walk_2way = _find_anim(frames, "walk")
	_anim_idle_2way = _find_anim(frames, "idle")
	if _anim_walk_2way == &"":
		_anim_walk_2way = _anim_idle_2way
	if _anim_idle_2way == &"":
		_anim_idle_2way = _anim_walk_2way
	if _anim_walk_2way == &"":
		var names := frames.get_animation_names()
		if not names.is_empty():
			_anim_walk_2way = StringName(names[0])
			_anim_idle_2way = _anim_walk_2way


static func _find_anim(frames: SpriteFrames, key: String) -> StringName:
	if frames.has_animation(key):
		return StringName(key)
	for n in frames.get_animation_names():
		if String(n).ends_with("_" + key) or String(n).begins_with(key + "_"):
			return StringName(n)
	return &""


## Kierunek 4-way z histerezą: oś musi przewyższać drugą o `direction_hysteresis`, inaczej zostaje
## poprzedni kierunek (skosy i drgania toru nie przełączają animacji co klatkę).
func _direction_name_from_velocity(vel: Vector2) -> String:
	var v := vel.normalized()
	if absf(v.x) > absf(v.y) + direction_hysteresis:
		return "right" if v.x > 0.0 else "left"
	if absf(v.y) > absf(v.x) + direction_hysteresis:
		return "down" if v.y > 0.0 else "up"
	return _last_facing_dir


## Widoczność jak w Amon-Ra: promień z wroga do kształtu kolizji gracza; ściany i obiekty z kolizją
## zasłaniają (inni wrogowie nie). Dodatkowo linia po siatce mapy: kolizje ścian są tylko na krawędziach
## kafli, więc promień potrafił przeciec przez litą skałę (~15% linii przez ścianę).
func _has_line_of_sight_to_player() -> bool:
	if not is_instance_valid(player_ref):
		return false
	var distance := global_position.distance_to(player_ref.global_position)
	if distance > detection_radius:
		return false

	if _raycast != null:
		var target := player_ref.global_position
		var shape := player_ref.get_node_or_null("CollisionShape2D") as Node2D
		if shape:
			target = shape.global_position
		_raycast.target_position = _raycast.to_local(target)
		_raycast.force_raycast_update()
		# is_colliding, nie sam collider: przeszkody z generatora obiektów to ciała PhysicsServer2D bez
		# węzła — get_collider() zwraca dla nich null mimo trafienia.
		if _raycast.is_colliding():
			var collider := _raycast.get_collider()
			if collider != player_ref and not ((collider is Node) and (collider as Node).is_in_group("player")):
				return false

	var grid := _map_grid()
	if not grid.is_empty() and not GridSight.has_line(grid, global_position, player_ref.global_position):
		return false
	return true


## Siatka mapy z poziomu (pusta dla poziomów robionych ręcznie). Szukana ponownie, dopóki pusta —
## wróg bywa dodany, zanim poziom ustawi last_result.
func _map_grid() -> Dictionary:
	if _grid.is_empty():
		_grid = GridSight.grid_for(self)
	return _grid


func _draw() -> void:
	if not _use_programmer_art:
		return

	var hover = sin(_anim_time * 2.0) * 2.0
	var draw_color = body_color
	if _flash_timer > 0:
		draw_color = _flash_color

	draw_circle(Vector2(0, 14), 8.0, Color(0, 0, 0, 0.25))

	match shape_type:
		EnemyShape.DIAMOND:
			_draw_diamond(Vector2(0, hover - 4), 12, 16, draw_color)
		EnemyShape.CIRCLE:
			draw_circle(Vector2(0, hover - 4), 14.0, draw_color)
			draw_arc(Vector2(0, hover - 4), 14.0, 0, TAU, 24, OUTLINE_COLOR, 2.0)
		EnemyShape.TRIANGLE:
			_draw_triangle(Vector2(0, hover - 4), 16, draw_color)
		EnemyShape.SQUARE:
			var r = Rect2(-11, hover - 15, 22, 22)
			draw_rect(r, draw_color)
			draw_rect(r, OUTLINE_COLOR, false, 2.0)
		EnemyShape.HEXAGON:
			_draw_polygon_shape(Vector2(0, hover - 4), 14, 6, draw_color)

	var eye_y = hover - 7.0
	var look_dir = Vector2.ZERO
	if is_instance_valid(player_ref) and state == State.CHASING:
		look_dir = (player_ref.global_position - global_position).normalized() * 2.0

	draw_circle(Vector2(-4 + look_dir.x, eye_y + look_dir.y), 3.0, Color.WHITE)
	draw_circle(Vector2(4 + look_dir.x, eye_y + look_dir.y), 3.0, Color.WHITE)
	draw_circle(Vector2(-4 + look_dir.x * 1.3, eye_y + look_dir.y * 1.3), 1.5, EYE_COLOR)
	draw_circle(Vector2(4 + look_dir.x * 1.3, eye_y + look_dir.y * 1.3), 1.5, EYE_COLOR)

	if not defeated:
		var bar_y = hover - 22
		var bar_w = 24.0
		var bar_h = 3.0
		var hp_ratio := float(hp) / float(max_hp)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2))
		var hp_color := Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * hp_ratio, bar_h), hp_color)
		draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), OUTLINE_COLOR, false, 1.0)

	if state == State.CHASING:
		var ex_y = hover - 28
		draw_string(ThemeDB.fallback_font, Vector2(-3, ex_y), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.RED)


func _draw_diamond(center: Vector2, w: float, h: float, color: Color) -> void:
	var pts = PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, 0),
		center + Vector2(0, h),
		center + Vector2(-w, 0),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), OUTLINE_COLOR, 2.0)


func _draw_triangle(center: Vector2, size: float, color: Color) -> void:
	var pts = PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size, size * 0.7),
		center + Vector2(-size, size * 0.7),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), OUTLINE_COLOR, 2.0)


func _draw_polygon_shape(center: Vector2, radius: float, sides: int, color: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(sides):
		var angle = (float(i) / sides) * TAU - PI / 2.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, OUTLINE_COLOR, 2.0)


func _patrol(delta: float) -> void:
	if is_instance_valid(player_ref) and not defeated and _has_line_of_sight_to_player():
		state = State.CHASING
		last_seen_player_pos = player_ref.global_position
		memory_timer = memory_duration
		return

	if not patrol_points.is_empty():
		_follow_patrol_path(delta)
	else:
		_idle_wander(delta)


func _idle_wander(delta: float) -> void:
	wander_timer -= delta
	if is_idle_pause:
		_move_towards(Vector2.ZERO, 0.0, delta)
		if wander_timer <= 0.0:
			_set_new_wander_target()
		return

	if wander_timer <= 0.0 or global_position.distance_to(wander_target) < ARRIVE_DISTANCE * 2.0:
		_set_new_wander_target()
		return

	var dir := _nav_direction(wander_target, delta)
	if dir == Vector2.ZERO:
		_set_new_wander_target()
		return
	_move_towards(dir, patrol_speed * 0.5, delta)

	# Ściana na drodze = siatka nawigacji nie zgadza się ze ścianami (np. ręcznie narysowana w poziomie)
	# albo cel bez siatki — nowy cel, odbity od ściany.
	if is_on_wall():
		_set_new_wander_target(get_wall_normal())


## Nowy cel wałęsania w promieniu `wander_radius`. Z siatką nawigacji: punkt przyciągnięty do siatki,
## ścieżka nie dłuższa niż promień × WANDER_PATH_FACTOR (cel za ścianą = długi objazd -> odrzuć).
## Bez siatki (jeszcze się wczytuje / poziom bez niej): cel na czystej linii po siatce mapy.
func _set_new_wander_target(bias_normal: Vector2 = Vector2.ZERO) -> void:
	if randf() < 0.25 and bias_normal == Vector2.ZERO:
		_start_idle_pause()
		return

	is_idle_pause = false
	wander_timer = randf_range(2.0, 4.0)
	var map := _nav_map()
	var grid := _map_grid()
	for _i in range(WANDER_TRIES):
		var random_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if bias_normal != Vector2.ZERO:
			random_dir = (random_dir + bias_normal * 1.8).normalized()
		var cand := global_position + random_dir * randf_range(30.0, wander_radius)
		if map.is_valid():
			var path := NavigationServer2D.map_get_path(map, global_position, cand, true)
			if _path_starts_here(path):
				var length := 0.0
				for k in range(path.size() - 1):
					length += path[k].distance_to(path[k + 1])
				if length <= wander_radius * WANDER_PATH_FACTOR and path[path.size() - 1].distance_to(global_position) > ARRIVE_DISTANCE * 2.0 and _path_clear(path):
					wander_target = path[path.size() - 1]
					return
				continue
		if _segment_clear(global_position, cand):
			wander_target = cand
			return
	_start_idle_pause()


func _start_idle_pause() -> void:
	is_idle_pause = true
	wander_timer = randf_range(1.0, 2.5)
	_move_dir = Vector2.ZERO
	velocity = Vector2.ZERO


func _follow_patrol_path(delta: float) -> void:
	var target = patrol_points[current_patrol_index]
	var direction = (target - global_position).normalized()
	velocity = direction * patrol_speed
	move_and_slide()

	if is_on_wall():
		patrol_stuck_timer += delta
		if patrol_stuck_timer > 1.5:
			patrol_stuck_timer = 0.0
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	else:
		patrol_stuck_timer = 0.0

	if global_position.distance_to(target) < 12.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()


func _chase(delta: float) -> void:
	if not defeated and is_instance_valid(player_ref) and _has_line_of_sight_to_player():
		last_seen_player_pos = player_ref.global_position
		memory_timer = memory_duration
	else:
		memory_timer -= delta
		if memory_timer <= 0.0:
			state = State.PATROL
			_move_towards(Vector2.ZERO, 0.0, delta)
			_set_new_wander_target()
			return

	# Walka startuje wyłącznie z kontaktu (collider wroga w Player/InteractionArea). Ruch po ścieżce
	# siatki nawigacji; u celu (ostatnio widziana pozycja) wróg stoi, a nie „idzie w miejscu”.
	_move_towards(_nav_direction(last_seen_player_pos, delta), patrol_speed * 1.3, delta)


# --- Ruch po siatce nawigacji ---------------------------------------------------------------

func _setup_nav_agent() -> void:
	if _nav_agent == null:
		return
	_nav_agent.path_desired_distance = ARRIVE_DISTANCE
	_nav_agent.target_desired_distance = ARRIVE_DISTANCE
	# Bez RVO: agent przekazuje prędkość do avoidance tylko przy własnym celu nawigacji, a ścieżkę
	# prowadzimy sami. Wrogowie i tak nie zbijają się w punkt — kolidują ze sobą (warstwa Enemies).
	_nav_agent.avoidance_enabled = false


## Mapa nawigacji wroga, gdy już zsynchronizowana (pierwsza synchronizacja po dodaniu regionu) —
## zapytania przed nią kończą się błędem. Pusty RID = brak.
func _nav_map() -> RID:
	var map: RID = _nav_agent.get_navigation_map() if _nav_agent != null else get_world_2d().navigation_map
	if not map.is_valid() or NavigationServer2D.map_get_iteration_id(map) == 0:
		return RID()
	return map


func _has_nav_path() -> bool:
	return not _path.is_empty()


## Kierunek ruchu do `target` po ścieżce siatki nawigacji. Ścieżkę pobieramy sami
## (NavigationServer2D.map_get_path co REPATH_INTERVAL albo gdy cel się przesunie) i sami za nią idziemy:
## NavigationAgent2D potrafił trzymać ścieżkę policzoną od (0, 0) — sprzed ustawienia pozycji — i prowadził
## wroga „ku górze” (ponowne ustawienie tego samego celu nie wymusza przeliczenia).
## Bez ścieżki (mapa jeszcze się wczytuje, poziom bez siatki, cel poza siatką) — prosto, ale tylko przy
## czystej linii po siatce mapy. ZERO = u celu (albo u najbliższego osiągalnego punktu) / stój.
func _nav_direction(target: Vector2, delta: float) -> Vector2:
	if global_position.distance_to(target) <= ARRIVE_DISTANCE:
		return Vector2.ZERO
	var map := _nav_map()
	if map.is_valid():
		_repath_timer -= delta
		if _repath_timer <= 0.0 or _nav_target.distance_to(target) > REPATH_DISTANCE:
			_path = NavigationServer2D.map_get_path(map, global_position, target, true)
			if not _path_starts_here(_path):
				_path = PackedVector2Array()
			_path_i = 1
			_nav_target = target
			_repath_timer = REPATH_INTERVAL
		if not _path.is_empty():
			while _path_i < _path.size() and global_position.distance_to(_path[_path_i]) <= ARRIVE_DISTANCE:
				_path_i += 1
			if _path_i >= _path.size():
				return Vector2.ZERO
			# Siatka niezgodna ze ścianami (ręcznie narysowana w poziomie) — odcinek przez ścianę:
			# nie ufamy ścieżce, idziemy jak dawniej prosto do celu (move_and_slide ślizga po ścianie).
			if _segment_clear(global_position, _path[_path_i]):
				return (_path[_path_i] - global_position).normalized()
			_path = PackedVector2Array()
			return (target - global_position).normalized()
	var grid := _map_grid()
	if grid.is_empty() or GridSight.has_line(grid, global_position, target):
		return (target - global_position).normalized()
	return Vector2.ZERO


## Czy odcinek jest wolny od ścian i przeszkód: promień fizyki po tym, z czym wróg się zderza (jego maska
## bez warstwy wrogów — ściany bywają na różnych warstwach: jaskinie 3, tileset tutoriala domyślnie 1)
## i — na mapie z generatora — linia po siatce (kolizje ścian są tam tylko na krawędziach kafli).
func _segment_clear(a: Vector2, b: Vector2) -> bool:
	var grid := _map_grid()
	if not grid.is_empty() and not GridSight.has_line(grid, a, b):
		return false
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters2D.create(a, b, collision_mask & ~collision_layer, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _path_clear(path: PackedVector2Array) -> bool:
	if path.is_empty() or not _segment_clear(global_position, path[0]):
		return false
	for k in range(path.size() - 1):
		if not _segment_clear(path[k], path[k + 1]):
			return false
	return true


## Ścieżka zaczyna się przy wrogu (stoi na siatce nawigacji). Poza siatką — np. ręcznie narysowana siatka
## poziomu nie pokrywa miejsca wroga — map_get_path zaczyna od najbliższego punktu siatki, często za
## ścianą, i wróg szedł prosto w tę ścianę („tylko w górę”).
func _path_starts_here(path: PackedVector2Array) -> bool:
	return not path.is_empty() and path[0].distance_to(global_position) <= ARRIVE_DISTANCE * 2.0


## Ruch w kierunku `dir` z płynnym obrotem (zamiast losowych drgań toru z Amon-Ra). ZERO = stój.
func _move_towards(dir: Vector2, speed: float, delta: float) -> void:
	if dir == Vector2.ZERO:
		_move_dir = Vector2.ZERO
		velocity = Vector2.ZERO
		return
	_move_dir = dir if _move_dir == Vector2.ZERO else _move_dir.slerp(dir, clampf(STEER_RATE * delta, 0.0, 1.0)).normalized()
	velocity = _move_dir * speed
	move_and_slide()


func _setup_detection_area() -> void:
	var det_area = get_node_or_null("DetectionArea")
	if det_area:
		det_area.monitoring = true
		det_area.monitorable = true
		det_area.collision_mask = 1
		if not det_area.body_entered.is_connected(_on_detection_area_body_entered):
			det_area.body_entered.connect(_on_detection_area_body_entered)
		if not det_area.body_exited.is_connected(_on_detection_area_body_exited):
			det_area.body_exited.connect(_on_detection_area_body_exited)
		if det_area.get_child_count() == 0:
			var shape = CircleShape2D.new()
			shape.radius = detection_radius
			var col = CollisionShape2D.new()
			col.shape = shape
			det_area.add_child(col)
		else:
			var col = det_area.get_child(0)
			if col is CollisionShape2D and col.shape is CircleShape2D:
				col.shape.radius = detection_radius


func _on_detection_area_body_entered(body: Node2D) -> void:
	if _are_enemies_disabled():
		return
	if body.is_in_group("player") and not defeated:
		player_ref = body
		if _has_line_of_sight_to_player():
			state = State.CHASING
			last_seen_player_pos = body.global_position
			memory_timer = memory_duration


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null


func interact(player: Node2D) -> void:
	if _are_enemies_disabled():
		return
	if not defeated:
		start_combat(player)


## Wywoływane przez Player/InteractionArea po wejściu collidera przeciwnika.
func engage_from_player_interaction(player: Node2D) -> void:
	if not is_instance_valid(player) or defeated or _are_enemies_disabled():
		return
	player_ref = player
	last_seen_player_pos = player.global_position
	memory_timer = memory_duration
	start_combat(player)


func start_combat(player: Node2D) -> void:
	if _are_enemies_disabled():
		return
	if state == State.COMBAT or defeated:
		return
	if _gm and _gm.is_in_quiz():
		return
	if get_tree().paused:
		return

	state = State.COMBAT
	velocity = Vector2.ZERO

	if player.has_method("set_can_move"):
		player.set_can_move(false)

	if _gm:
		_gm.change_state(_gm.GameState.QUIZ_COMBAT)

	var diff_range: Vector2i = Vector2i(1, 3)
	if _dm:
		diff_range = _dm.get_difficulty_range(quiz_category)
	var encounter_size_range: Vector2i = Vector2i(maxi(1, min_encounter_size), maxi(maxi(1, min_encounter_size), max_encounter_size))

	var combat_canvas: CanvasLayer = preload("res://modules/quiz_rpg/scenes/quiz/quiz_combat_ui.tscn").instantiate() as CanvasLayer
	var combat_ui: Control = combat_canvas.get_node("Root") as Control
	combat_ui.setup(self, player, quiz_id, diff_range, question_count, encounter_size_range)
	get_tree().current_scene.add_child(combat_canvas)
	get_tree().paused = true


func on_combat_finished(player_won: bool, player: Node2D) -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false
	if player.has_method("set_can_move"):
		player.set_can_move(true)

	if player_won:
		defeated = true
		state = State.DEFEATED
		if is_boss:
			_persist_boss_defeat()
		if _ps:
			_ps.add_xp(xp_reward)
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.4).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
		await tween.finished
		queue_free()
	else:
		state = State.IDLE
		await get_tree().create_timer(2.0).timeout
		state = State.PATROL

	if _gm:
		_gm.change_state(_gm.GameState.EXPLORING)


func take_quiz_damage(amount: int) -> void:
	hp -= amount
	hp = maxi(hp, 0)
	_flash_color = Color(1.0, 0.3, 0.3)
	_flash_timer = 0.15
	if _use_programmer_art:
		queue_redraw()
	else:
		var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			var tween: Tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.RED, 0.1)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func is_defeated() -> bool:
	return hp <= 0


## --- Zapis pokonania bossa (per-save, czyszczony przy rerollu mapy) ---

func _generate_boss_id() -> String:
	var parts: Array[String] = ["boss"]
	var nm := enemy_name.strip_edges().to_lower()
	if nm.is_empty() or nm == "przeciwnik":
		nm = name.replace("@", "").strip_edges().to_lower()
	if not nm.is_empty():
		parts.append(nm)
	var px := int(global_position.x / 10.0) * 10
	var py := int(global_position.y / 10.0) * 10
	parts.append(str(px))
	parts.append(str(py))
	return "_".join(parts)


func _check_boss_defeated() -> void:
	if not is_boss or not is_instance_valid(self):
		return
	var level_path := _get_current_level_path()
	if level_path.is_empty():
		await get_tree().process_frame
		if is_instance_valid(self):
			_check_boss_defeated()
		return
	var lsm := _get_level_state_manager()
	if lsm and lsm.is_boss_defeated(level_path, unique_id):
		# Już pokonany w tym zapisie -> nie spawnuj (usuń cicho).
		defeated = true
		state = State.DEFEATED
		queue_free()


func _persist_boss_defeat() -> void:
	var level_path := _get_current_level_path()
	var lsm := _get_level_state_manager()
	if lsm == null:
		return
	# 1) Respawn: pod tym seedem boss zostaje pokonany (czyszczone rerollem).
	if not level_path.is_empty():
		lsm.mark_boss_defeated(level_path, unique_id)
	# 2) Postęp urządzenia arcymaga: monotoniczny, nieodwracalny, per story-boss.
	#    Fallback story_id = level_path (jeden krok na mapę), gdy nie ustawiono jawnie.
	#    Globalna bramka (device_counting_enabled) jest sprawdzana w managerze.
	if counts_toward_device:
		var story_id := boss_story_id if not boss_story_id.is_empty() else level_path
		if not story_id.is_empty() and lsm.has_method("register_device_progress"):
			lsm.register_device_progress(story_id)


func _core() -> Node:
	return get_node_or_null("/root/CoreManager")


func _get_level_state_manager() -> Node:
	var core := _core()
	var s: Variant = core.get_singleton("LevelStateManager") if core else null
	if s is Node:
		return s
	return get_node_or_null("/root/LevelStateManager")


func _get_level_manager() -> Node:
	var game_root := get_tree().current_scene
	if game_root:
		var lm := game_root.find_child("level_manager", true, false)
		if lm is Node:
			return lm
	var core := _core()
	if core and core.has_method("get_active_module"):
		var module_root: Variant = core.call("get_active_module")
		if module_root is Node:
			var lm2 := (module_root as Node).find_child("level_manager", true, false)
			if lm2 is Node:
				return lm2
	return null


func _get_current_level_path() -> String:
	var lm := _get_level_manager()
	if lm and lm.get("current_level_path") != null:
		return str(lm.get("current_level_path"))
	return ""
