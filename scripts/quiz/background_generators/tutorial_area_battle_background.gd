extends RefCounted

## Generator tla walki dla Tutorial Area.
## Wybiera losowo jeden z wariantow zrobionych w stylistyce mapy (FPV, fioletowe cegly, szara posadzka).

const VARIANT_PATHS: Array[String] = [
	"res://modules/quiz_rpg/assets/textures/battle_backgrounds/tutorial_area/variant_1_gate.jpg",
	"res://modules/quiz_rpg/assets/textures/battle_backgrounds/tutorial_area/variant_2_training.jpg",
	"res://modules/quiz_rpg/assets/textures/battle_backgrounds/tutorial_area/variant_3_stairs.jpg",
	"res://modules/quiz_rpg/assets/textures/battle_backgrounds/tutorial_area/variant_4_chamber.jpg",
]

var _cached_texture: Texture2D = null
var _selected_index: int = -1


func _init() -> void:
	_select_random_texture()


func _select_random_texture() -> void:
	if VARIANT_PATHS.is_empty():
		return
	var idx: int = randi() % VARIANT_PATHS.size()
	_selected_index = idx
	var path: String = VARIANT_PATHS[idx]
	if ResourceLoader.exists(path):
		_cached_texture = load(path) as Texture2D


func draw_background(canvas: Control, _context: Dictionary) -> void:
	if _cached_texture == null:
		_select_random_texture()

	if _cached_texture != null:
		var tex_size: Vector2 = _cached_texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var scale_factor: float = maxf(canvas.size.x / tex_size.x, canvas.size.y / tex_size.y)
			var scaled_w: float = tex_size.x * scale_factor
			var scaled_h: float = tex_size.y * scale_factor
			var offset_x: float = (canvas.size.x - scaled_w) * 0.5
			var offset_y: float = (canvas.size.y - scaled_h) * 0.5
			var draw_rect: Rect2 = Rect2(offset_x, offset_y, scaled_w, scaled_h)
			canvas.draw_texture_rect(_cached_texture, draw_rect, false)
		else:
			canvas.draw_texture_rect(_cached_texture, Rect2(Vector2.ZERO, canvas.size), false)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.18, 0.14, 0.22))

	_draw_bottom_gradient(canvas)


func _draw_bottom_gradient(canvas: Control) -> void:
	var h: float = canvas.size.y
	var w: float = canvas.size.x
	var grad_height: float = minf(70.0, h * 0.2)
	var grad_y: float = h - grad_height
	canvas.draw_rect(Rect2(0.0, grad_y, w, grad_height), Color(0.0, 0.0, 0.0, 0.35))
