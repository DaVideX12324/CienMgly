extends StaticBody2D

## Kratka ściekowa nad przejściem do ścieków (obszar `portal` w trybie klawisza). Zamknięta: można po niej chodzić,
## pierwsze [E] ją otwiera. Otwarta: kolizja (nie wejdzie się w dziurę), kolejne [E] — zejście. Otwarcie zostaje
## w zapisie (flaga fabularna `flag`).

@export var portal: NodePath = ^"../enter_next_level"
@export var flag := "town:sewer_grate_open"
@export var closed_region := Rect2(288, 240, 32, 32)
@export var open_region := Rect2(288, 272, 32, 32)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
var _open := false


func _ready() -> void:
	var lsm := _lsm()
	_set_open(lsm != null and lsm.has_story_flag(flag))
	_hook()


## Po podpięciu obszaru przez mapę (odroczone w jej _ready) podmienia akcję klawisza, póki kratka zamknięta.
func _hook() -> void:
	await get_tree().process_frame
	var area := get_node_or_null(portal)
	var key: Node = area.get_node_or_null("PortalKey") if area else null
	if key == null or _open:
		return
	var descend: Callable = key.on_enter
	var descend_text: String = key.prompt_text
	key.prompt_text = "prompt.open_grate"
	key.on_enter = func() -> void:
		_set_open(true)
		var lsm := _lsm()
		if lsm:
			lsm.set_story_flag(flag)
		key.on_enter = descend
		key.prompt_text = descend_text
		key.set_in_range(true)


func _set_open(open: bool) -> void:
	_open = open
	_sprite.region_rect = open_region if open else closed_region
	_shape.set_deferred("disabled", not open)


func _lsm() -> Node:
	var core := get_node_or_null("/root/CoreManager")
	return core.call("get_singleton", "LevelStateManager") as Node if core else null
