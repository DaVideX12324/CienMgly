extends Control

## Tło menu z warstw paralaksy: dzieci TextureRect od najdalszej do najbliższej (scena menu_parallax.tscn).
## Warstwy powtarzają się w poziomie (STRETCH_TILE), skalowane całkowicie tak, by wypełnić wysokość ekranu (wyrównane
## do dołu — nadmiar nieba ucięty u góry); dalsze płyną wolniej, bliższe szybciej, a ruch myszy lekko je przesuwa.

## Prędkość najbliższej warstwy (px grafiki na sekundę); najdalsza stoi.
@export var drift_px_per_sec := 12.0
## Przesunięcie najbliższej warstwy przy myszy na brzegu ekranu (px grafiki).
@export var mouse_shift_px := 8.0

var _t := 0.0
var _mouse := 0.0  # wygładzona pozycja myszy -1..1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer in _layers():
		layer.stretch_mode = TextureRect.STRETCH_TILE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layers() -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	for c in get_children():
		if c is TextureRect and (c as TextureRect).texture != null:
			out.append(c)
	return out


func _process(delta: float) -> void:
	_t += delta
	var vs := size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return
	_mouse = lerpf(_mouse, clampf(get_local_mouse_position().x / vs.x * 2.0 - 1.0, -1.0, 1.0), minf(delta * 3.0, 1.0))
	var layers := _layers()
	var src_h := float(layers[0].texture.get_height()) if not layers.is_empty() else 1.0
	var k := maxf(ceilf(vs.y / src_h), 1.0)
	for i in layers.size():
		var layer := layers[i]
		var depth := float(i) / float(maxi(layers.size() - 1, 1))
		var tile_w := float(layer.texture.get_width())
		var off := fposmod(_t * drift_px_per_sec * depth + _mouse * mouse_shift_px * depth, tile_w)
		layer.scale = Vector2(k, k)
		layer.size = Vector2(ceilf(vs.x / k) + tile_w * 2.0, src_h)
		# Co piksel ekranu, nie grafiki — przy skali ×5–6 skoki o cały piksel grafiki klatkowały.
		layer.position = Vector2(roundf(-(off + tile_w) * k), vs.y - src_h * k)
