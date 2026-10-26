class_name QuizRpgStation
extends StaticBody2D

## Animowane stanowisko pracy (kowadło, kuchnia, tartak, stół alchemiczny — sceny scenes/objects/pixel_crawler/stations/*_anim):
## stoi w klatce spoczynku (animacja „idle”), a gdy rzemieślnik przy nim pracuje, gra animację „work”.
## Scena bez „idle” (np. zapalony piec) gra „work” cały czas. Miejsce, w którym staje rzemieślnik, wyznacza
## węzeł Marker2D „WorkSpot” (przesuwany w edytorze); NPC wskazuje stanowisko polem work_station (QuizRpgNpc).

## Animacja „work” gra stale, także bez rzemieślnika (np. stół alchemiczny jako dekoracja).
@export var always_active: bool = false

const IDLE := &"idle"
const WORK := &"work"

var _working := false

@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	_play_rest()


## Globalna pozycja, w której staje rzemieślnik (Marker2D „WorkSpot”, domyślnie tuż przed stanowiskiem).
func work_spot() -> Vector2:
	var marker := get_node_or_null("WorkSpot") as Node2D
	return marker.global_position if marker else global_position + Vector2(0, 7)


func is_working() -> bool:
	return _working


func start_work() -> void:
	_working = true
	if _sprite and _sprite.sprite_frames.has_animation(WORK):
		_sprite.play(WORK)


func stop_work() -> void:
	_working = false
	_play_rest()


func _play_rest() -> void:
	if _sprite == null:
		return
	var frames := _sprite.sprite_frames
	if always_active or not frames.has_animation(IDLE):
		_sprite.play(WORK)
	else:
		_sprite.play(IDLE)
