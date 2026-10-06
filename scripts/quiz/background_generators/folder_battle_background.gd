extends RefCounted

## Tło walki z grafik w folderze mapy: battle_backgrounds/<klucz>/ (np. tutorial_area) albo
## battle_backgrounds/pixel_crawler/<klucz>/ (biomy Pixel Crawlera: cave, castle, desert…). Dowolne pliki
## .png/.jpg/.webp, nazwy bez znaczenia — przy każdej walce losowany jeden wariant. Wymiary pola walki
## w pliku obok grafiki (`<grafika>_layout.tres`, get_layout_key -> BattleBackgroundLayout).
## Klucz mapy wybiera battle_background.gd (_map_key).

const QuizRpgPaths = preload("../../quiz_rpg_paths.gd")

static var ROOT_DIR: String = QuizRpgPaths.path("assets/textures/battle_backgrounds/")
static var SEARCH_DIRS: Array[String] = [ROOT_DIR, ROOT_DIR + "pixel_crawler/"]
const IMAGE_EXTS: Array[String] = ["png", "jpg", "jpeg", "webp"]
## Cień nad dolnym paskiem UI walki (px, przy dolnej krawędzi obszaru walki) — też w podglądzie pól.
const SHADOW_HEIGHT := 35.0
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)

var _variants: PackedStringArray
var _cached_texture: Texture2D = null
var _selected_variant_path: String = ""


## Grafiki tła dla klucza mapy (pierwszy folder z SEARCH_DIRS, który ma jakąkolwiek); puste = brak.
## ResourceLoader.list_directory widzi pliki także w wyeksportowanej grze (tam na dysku są tylko
## .import/.remap — DirAccess ich nie pokazuje).
static func variant_paths(key: String) -> PackedStringArray:
	var out := PackedStringArray()
	if key.is_empty():
		return out
	for base in SEARCH_DIRS:
		var dir := base + key + "/"
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in ResourceLoader.list_directory(dir):
			if f.get_extension().to_lower() in IMAGE_EXTS:
				out.append(dir + f)
		if not out.is_empty():
			return out
	return out


func _init(variants: PackedStringArray) -> void:
	_variants = variants
	_select_random_texture()


## Wymiary pola walki: `<grafika>_layout.tres` obok wylosowanej grafiki (BattleBackgroundLayout).
func get_layout_key() -> String:
	if _selected_variant_path == "":
		_select_random_texture()
	return _selected_variant_path


func _select_random_texture() -> void:
	if _variants.is_empty():
		return
	_selected_variant_path = _variants[randi() % _variants.size()]
	_cached_texture = load(_selected_variant_path) as Texture2D


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
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.12, 0.10, 0.15))

	_draw_bottom_gradient(canvas)


func _draw_bottom_gradient(canvas: Control) -> void:
	var h: float = canvas.size.y
	var w: float = canvas.size.x
	var grad_height: float = minf(SHADOW_HEIGHT, h * 0.1)  # cień nad dolnym paskiem UI
	var band_top: float = h * (830.0 / 1080.0) if h > 850.0 else h
	var grad_y: float = band_top - grad_height
	canvas.draw_rect(Rect2(0.0, grad_y, w, grad_height), SHADOW_COLOR)
