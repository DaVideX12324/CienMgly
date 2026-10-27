@tool
class_name SpriteRig
extends Node2D
## Części doczepione do klatek AnimatedSprite2D (ręce, broń — np. szczury Pixel Crawlera): dziecko ciała, a w nim
## Sprite2D z wycinkami atlasu (region) i AnimationPlayer (root_node = ".." = ten węzeł) z animacjami o nazwach
## animacji ciała. Klucze w czasie klatek ciała (klatka i = i / fps), tryb dyskretny; pozycje części w pikselach
## klatki (0,0 = lewy górny róg klatki ciała, jak w arkuszu).
##
## W grze ciało rządzi: zmiana klatki / animacji ustawia AnimationPlayer na ten sam moment (kod wroga i walki dalej
## woła tylko play() na AnimatedSprite2D). W edytorze odwrotnie: przewijanie osi czasu AnimationPlayer pokazuje
## pasującą klatkę ciała, więc ręce układa się na podglądzie. flip_h ciała odbija cały rig w lustrze.

@export var anim_player_path: NodePath = ^"RigAnim"

var _body: AnimatedSprite2D
var _ap: AnimationPlayer
var _placed_key := []
var _editor_state := []


func _ready() -> void:
	_body = get_parent() as AnimatedSprite2D
	_ap = get_node_or_null(anim_player_path) as AnimationPlayer
	if _body == null or _ap == null:
		return
	if not Engine.is_editor_hint():
		_body.frame_changed.connect(_sync)
		_body.animation_changed.connect(_sync, CONNECT_DEFERRED)  # klatka zeruje się po sygnale zmiany animacji
		_sync()
	_place()


func _process(_delta: float) -> void:
	if _body == null or _ap == null:
		return
	_place()
	if Engine.is_editor_hint():
		_editor_follow_timeline()


## Układ rigu względem ciała: lewy górny róg klatki (offset / centered), a przy flip_h lustro wokół środka klatki.
func _place() -> void:
	var size := _frame_size()
	var key := [_body.flip_h, _body.offset, _body.centered, size]
	if key == _placed_key:
		return
	_placed_key = key
	var origin := _body.offset - (size * 0.5 if _body.centered else Vector2.ZERO)
	if _body.flip_h:
		position = Vector2(origin.x + size.x, origin.y)
		scale = Vector2(-1, 1)
	else:
		position = origin
		scale = Vector2.ONE


func _frame_size() -> Vector2:
	var frames := _body.sprite_frames
	if frames == null or not frames.has_animation(_body.animation) or frames.get_frame_count(_body.animation) == 0:
		return Vector2.ZERO
	var tex := frames.get_frame_texture(_body.animation, 0)
	return tex.get_size() if tex else Vector2.ZERO


## Czas początku klatki `frame` animacji ciała (sekundy, z czasami trwania klatek).
func _frame_time(anim: StringName, frame: int) -> float:
	var frames := _body.sprite_frames
	var fps := maxf(frames.get_animation_speed(anim), 0.001)
	var t := 0.0
	for i in mini(frame, frames.get_frame_count(anim)):
		t += frames.get_frame_duration(anim, i) / fps
	return t


## Wartości ścieżek (value) animacji rigu w chwili bieżącej klatki ciała — nakładane wprost (seek AnimationPlayera
## wstecz nie nakłada kluczy dyskretnych, np. klatka 1 -> 0). Inne typy ścieżek (metody, audio) są pomijane.
func _sync() -> void:
	var anim := _body.animation
	if _body.sprite_frames == null or not _ap.has_animation(anim):
		return
	var a := _ap.get_animation(anim)
	var t := _frame_time(anim, _body.frame) + 0.0001  # klucze dyskretne dokładnie na początku klatki
	var root := _ap.get_node_or_null(_ap.root_node)
	if root == null:
		return
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_VALUE or not a.track_is_enabled(i) or a.track_get_key_count(i) == 0:
			continue
		var path := a.track_get_path(i)
		var target := root.get_node_or_null(NodePath(path.get_concatenated_names()))
		if target != null:
			target.set_indexed(NodePath(path.get_concatenated_subnames()), a.value_track_interpolate(i, t))


## Edytor: animacja i moment wybrany na osi czasu AnimationPlayer -> klatka ciała.
func _editor_follow_timeline() -> void:
	var anim := StringName(_ap.assigned_animation)
	if anim == &"" or _body.sprite_frames == null or not _body.sprite_frames.has_animation(anim):
		return
	var pos := _ap.current_animation_position
	var state := [anim, pos]
	if state == _editor_state:
		return
	_editor_state = state
	var frame := 0
	var count := _body.sprite_frames.get_frame_count(anim)
	while frame + 1 < count and _frame_time(anim, frame + 1) <= pos + 0.0001:
		frame += 1
	if _body.animation != anim:
		_body.animation = anim
	_body.frame = frame
