extends Control

## Przód tła walki (np. barierki ścieków): `<grafika tła>_front.png` z przezroczystością, rysowany nad warstwą wrogów
## tym samym dopasowaniem „cover” co tło (BattleBackground) — wrogowie stoją za barierkami. Brak pliku = nic.

var background: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()   # tło i warstwa wrogów zmieniają położenie (pas, skala UI) — tani rysunek jednej tekstury


func _draw() -> void:
	if background == null or not is_instance_valid(background) or not background.has_method("get_front_texture"):
		return
	var tex: Texture2D = background.call("get_front_texture")
	if tex == null:
		return
	var ts := tex.get_size()
	var cs: Vector2 = background.size
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var k := maxf(cs.x / ts.x, cs.y / ts.y)
	draw_set_transform_matrix(get_global_transform().affine_inverse() * background.get_global_transform())
	draw_texture_rect(tex, Rect2((cs - ts * k) * 0.5, ts * k), false)
