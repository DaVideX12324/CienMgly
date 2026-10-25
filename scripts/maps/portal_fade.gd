class_name QuizRpgPortalFade
extends Node

## Stopniowe wejście w przejście (schody wnęki przy voidzie): im bliżej obszaru przejścia, tym bardziej postać ciemnieje
## i znika (self_modulate sprite'a) — w chwili dotknięcia obszaru jest już niewidoczna, więc nie znika nagle razem z
## mapą. Dotyczy lidera i towarzyszy w zasięgu. Po wczytaniu nowej mapy drużyna wynurza się (fade_in).
## Podpinane przez LevelPortal.connect_area do obszarów z metadaną `portal_fade` (generator ustawia ją przy schodach wnęki).

const META := &"portal_fade"
## Na tej długości (px, dwa stopnie) przed dotknięciem obszaru postać znika od pełnej widoczności do zera.
const FADE_LENGTH := 32.0
## Tyle px od obszaru ciało lidera (kapsuła) go dotyka — wtedy znikanie ma być zakończone.
const TOUCH_DISTANCE := 3.0
const MIN_BRIGHTNESS := 0.2
const FADE_IN_TIME := 0.6
const HOLDER_NAME := "PartyFollowers"

var _area: Area2D
var _shape: RectangleShape2D
var _area_shape_node: CollisionShape2D
var _faded: Dictionary = {}   # sprite -> true: tym zmieniliśmy self_modulate (do przywrócenia)


func _ready() -> void:
	_area = get_parent() as Area2D
	for c in _area.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is RectangleShape2D:
			_shape = (c as CollisionShape2D).shape
			_area_shape_node = c as CollisionShape2D
			break
	set_physics_process(_shape != null)


func _physics_process(_delta: float) -> void:
	var seen := {}
	for member in members(get_tree()):
		var sprite := member.get_node_or_null("AnimatedSprite2D") as CanvasItem
		if sprite == null:
			continue
		var t := _fade_amount(member.global_position)
		if t > 0.0:
			_apply(sprite, t)
			seen[sprite] = true
			_faded[sprite] = true
	for sprite in _faded.keys():
		if not seen.has(sprite):
			if is_instance_valid(sprite):
				(sprite as CanvasItem).self_modulate = Color.WHITE
			_faded.erase(sprite)


## 0 = daleko, 1 = ciało dotyka obszaru.
func _fade_amount(p: Vector2) -> float:
	var center := _area_shape_node.global_position
	var half := _shape.size * 0.5
	var dx := maxf(maxf(center.x - half.x - p.x, p.x - (center.x + half.x)), 0.0)
	var dy := maxf(maxf(center.y - half.y - p.y, p.y - (center.y + half.y)), 0.0)
	var dist := Vector2(dx, dy).length()
	return clampf(1.0 - (dist - TOUCH_DISTANCE) / FADE_LENGTH, 0.0, 1.0)


static func _apply(sprite: CanvasItem, t: float) -> void:
	var b := lerpf(1.0, MIN_BRIGHTNESS, t)
	sprite.self_modulate = Color(b, b, b, 1.0 - t)


## Lider i towarzysze (węzeł PartyFollowers obok lidera).
static func members(tree: SceneTree) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for leader in tree.get_nodes_in_group("player"):
		if not (leader is Node2D):
			continue
		out.append(leader as Node2D)
		var parent := leader.get_parent()
		var holder := parent.get_node_or_null(HOLDER_NAME) if parent else null
		if holder != null:
			for f in holder.get_children():
				if f is Node2D:
					out.append(f as Node2D)
	return out


## Po wejściu na nową mapę: drużyna wynurza się z ciemności (od niewidocznej do pełnej).
static func fade_in(tree: SceneTree) -> void:
	for member in members(tree):
		var sprite := member.get_node_or_null("AnimatedSprite2D") as CanvasItem
		if sprite == null:
			continue
		sprite.self_modulate = Color(MIN_BRIGHTNESS, MIN_BRIGHTNESS, MIN_BRIGHTNESS, 0.0)
		sprite.create_tween().tween_property(sprite, "self_modulate", Color.WHITE, FADE_IN_TIME)
