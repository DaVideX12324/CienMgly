extends RefCounted

## Generator tla walki dla biomow i lochow Pixel Crawler.
## Obsluguje ladowanie tekstur dla konkretnego biomu (castle, cave, desert, fairy_forest, forge, garden, hideout itp.),
## losowanie wariantow oraz zwracanie zindywidualizowanych profili ukladu wrogow (get_enemy_layout_config).

const BIOMES_DIR: String = "res://modules/quiz_rpg/assets/textures/battle_backgrounds/pixel_crawler/"

const BIOME_CONFIGS: Dictionary = {
	"castle": {
		"enemy_section_height": 340.0,
		"enemy_section_bottom_offset": -35.0,
		"row2_margin_multiplier": 1.0,
		"row1_margin_multiplier": 1.0,
	},
	"cave": {
		"enemy_section_height": 330.0,
		"enemy_section_bottom_offset": -35.0,
		"row2_margin_multiplier": 1.05,
		"row1_margin_multiplier": 1.0,
	},
	"desert": {
		"enemy_section_height": 380.0,
		"enemy_section_bottom_offset": -35.0,
		"row2_margin_multiplier": 0.60,
		"row1_margin_multiplier": 0.70,
	},
	"fairy_forest": {
		"enemy_section_height": 360.0,
		"enemy_section_bottom_offset": -35.0,
		"row2_margin_multiplier": 0.70,
		"row1_margin_multiplier": 0.80,
	},
	"forge": {
		"enemy_section_height": 350.0,
		"enemy_section_bottom_offset": -35.0,
		"row2_margin_multiplier": 0.95,
		"row1_margin_multiplier": 1.0,
	},
	"garden": {
		"enemy_section_height": 340.0,
		"enemy_section_bottom_offset": -35.0,
		"row2_margin_multiplier": 0.95,
		"row1_margin_multiplier": 1.0,
	},
	"hideout": {
		"enemy_section_height": 330.0,
		"enemy_section_bottom_offset": -35.0,
		"row2_margin_multiplier": 1.05,
		"row1_margin_multiplier": 1.0,
	},
}

const DEFAULT_CONFIG: Dictionary = {
	"enemy_section_height": 340.0,
	"enemy_section_bottom_offset": -35.0,
	"row2_margin_multiplier": 1.0,
	"row1_margin_multiplier": 1.0,
}

var _biome_name: String = "castle"
var _cached_texture: Texture2D = null
var _selected_variant_path: String = ""


func _init(biome: String = "castle") -> void:
	_biome_name = biome
	_select_random_texture_for_biome(_biome_name)


func set_biome(biome: String) -> void:
	if _biome_name != biome or _cached_texture == null:
		_biome_name = biome
		_select_random_texture_for_biome(_biome_name)


func get_enemy_layout_config() -> Dictionary:
	return BIOME_CONFIGS.get(_biome_name, DEFAULT_CONFIG)


func _select_random_texture_for_biome(biome: String) -> void:
	var biome_folder: String = BIOMES_DIR + biome + "/"
	var variants: Array[String] = []
	
	var dir := DirAccess.open(biome_folder)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg") or file_name.ends_with(".webp")):
				if not file_name.ends_with(".import"):
					variants.append(biome_folder + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if variants.is_empty():
		# Fallback na bezposrednie sprawdzenie variant_1.jpg i variant_1.png
		if ResourceLoader.exists(biome_folder + "variant_1.jpg"):
			variants.append(biome_folder + "variant_1.jpg")
		elif ResourceLoader.exists(biome_folder + "variant_1.png"):
			variants.append(biome_folder + "variant_1.png")
			
	if not variants.is_empty():
		var idx: int = randi() % variants.size()
		_selected_variant_path = variants[idx]
		if ResourceLoader.exists(_selected_variant_path):
			_cached_texture = load(_selected_variant_path) as Texture2D


func draw_background(canvas: Control, _context: Dictionary) -> void:
	if _cached_texture == null:
		_select_random_texture_for_biome(_biome_name)

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
	var grad_height: float = minf(70.0, h * 0.2)
	var grad_y: float = h - grad_height
	canvas.draw_rect(Rect2(0.0, grad_y, w, grad_height), Color(0.0, 0.0, 0.0, 0.35))
