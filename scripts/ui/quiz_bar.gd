@tool
class_name QuizBar
extends ProgressBar

## Pasek walki (LP / SP / TP, czas odpowiedzi, HP wrogów). Bez tekstur w motywie — zwykły ProgressBar
## ze stylami `background` / `fill` typu (theme_type_variation, np. QuizBarLP). Gdy motyw ma ikony
## `bar_under` (pusty) i `bar_progress` (pełny) — pikselowy pasek z tekstur: środek rozciągany do
## szerokości węzła, końcówki (np. skosy) bez zmian, wypełnienie przycinane płynnie wiersz po wierszu
## w granicach kształtu paska (koniec wypełnienia idzie za skosem). Stałe motywu: `bar_scale` =
## powiększenie pikseli grafiki (domyślnie 2); `bar_tile` = 1 — środek powtarzany zamiast rozciągany
## (paski modułowe: początek + segment + koniec; szerokość dociągana do pełnych segmentów);
## `bar_cap_left` / `bar_cap_right` — szerokość początku / końca w px grafiki (bez nich: z kształtu).

const _SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D under_tex : filter_nearest;
uniform sampler2D progress_tex : filter_nearest;
uniform vec2 src_size;
uniform float dst_w;
uniform float cap_l;
uniform float cap_r;
uniform bool tile;
uniform float ratio;
uniform float row_l[32];
uniform float row_r[32];
varying vec4 vcol;  // kolor wierzchołka (modulate) — COLOR we fragment zawiera już teksturę rysowaną

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec2 p = floor(UV * vec2(dst_w, src_size.y));
	float tx;
	if (p.x < cap_l) {
		tx = p.x;
	} else if (p.x >= dst_w - cap_r) {
		tx = src_size.x - (dst_w - p.x);
	} else {
		float mid_src = src_size.x - cap_l - cap_r;
		float mid_dst = max(dst_w - cap_l - cap_r, 1.0);
		tx = tile ? cap_l + mod(p.x - cap_l, mid_src) : cap_l + floor((p.x - cap_l) * mid_src / mid_dst);
	}
	int y = clamp(int(p.y), 0, 31);
	float l = row_l[y];
	float r = dst_w - (src_size.x - row_r[y]);
	vec2 uv = (vec2(tx, p.y) + 0.5) / src_size;
	vec4 c = (p.x < l + ratio * (r - l)) ? texture(progress_tex, uv) : texture(under_tex, uv);
	COLOR = c * vcol;
}
"""

static var _shader: Shader = null
static var _rows_cache := {}   # Texture2D -> [row_l, row_r] (pierwsza / za ostatnią nieprzezroczystą kolumną)

var _textured := false
var _switching := false  # nadpisania stylów same wywołują NOTIFICATION_THEME_CHANGED


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_refresh_mode()


func _refresh_mode() -> void:
	if _switching:
		return
	var textured := has_theme_icon(&"bar_under") and has_theme_icon(&"bar_progress")
	_switching = true
	_textured = textured
	if textured:
		# Wbudowane rysowanie ProgressBar wyłączone — pasek rysuje _draw z shaderem. Puste tło trzyma
		# wysokość grafiki (minimalny rozmiar ProgressBar liczy się natywnie ze stylów) — przeliczana
		# przy każdej zmianie motywu (inny styl pasków = inna wysokość).
		var under := get_theme_icon(&"bar_under")
		var h := float(under.get_height() * _scale()) if under else 0.0
		var bg := get_theme_stylebox(&"background") as StyleBoxEmpty if has_theme_stylebox_override(&"background") else null
		if bg == null or bg.get_minimum_size().y != h:
			bg = StyleBoxEmpty.new()
			bg.content_margin_top = floorf(h * 0.5)
			bg.content_margin_bottom = h - floorf(h * 0.5)
			add_theme_stylebox_override(&"background", bg)
		if not has_theme_stylebox_override(&"fill"):
			add_theme_stylebox_override(&"fill", StyleBoxEmpty.new())
		if not (material is ShaderMaterial):
			if _shader == null:
				_shader = Shader.new()
				_shader.code = _SHADER_CODE
			var m := ShaderMaterial.new()
			m.shader = _shader
			material = m
	elif material != null or has_theme_stylebox_override(&"fill"):
		remove_theme_stylebox_override(&"background")
		remove_theme_stylebox_override(&"fill")
		material = null
	_switching = false
	update_minimum_size()
	queue_redraw()


func _scale() -> int:
	return maxi(1, get_theme_constant(&"bar_scale") if has_theme_constant(&"bar_scale") else 2)


func _draw() -> void:
	if not _textured or not (material is ShaderMaterial):
		return
	var under := get_theme_icon(&"bar_under")
	var progress := get_theme_icon(&"bar_progress")
	if under == null or progress == null:
		return
	var k := _scale()
	var src := Vector2(under.get_size())
	var dst_w := floorf(size.x / k)
	if dst_w < src.x * 0.25:
		return
	var rows := _rows(under)
	var caps := _caps(rows, src)
	if has_theme_constant(&"bar_cap_left"):
		caps.x = get_theme_constant(&"bar_cap_left")
	if has_theme_constant(&"bar_cap_right"):
		caps.y = get_theme_constant(&"bar_cap_right")
	var tile := has_theme_constant(&"bar_tile") and get_theme_constant(&"bar_tile") != 0
	if tile:  # pełne segmenty: początek + n × środek + koniec
		var mid := maxf(src.x - caps.x - caps.y, 1.0)
		dst_w = caps.x + caps.y + maxf(floorf((dst_w - caps.x - caps.y) / mid), 1.0) * mid
	var m := material as ShaderMaterial
	m.set_shader_parameter(&"under_tex", under)
	m.set_shader_parameter(&"progress_tex", progress)
	m.set_shader_parameter(&"src_size", src)
	m.set_shader_parameter(&"dst_w", dst_w)
	m.set_shader_parameter(&"cap_l", caps.x)
	m.set_shader_parameter(&"cap_r", caps.y)
	m.set_shader_parameter(&"tile", tile)
	m.set_shader_parameter(&"row_l", rows[0])
	m.set_shader_parameter(&"row_r", rows[1])
	var span := max_value - min_value
	m.set_shader_parameter(&"ratio", clampf((value - min_value) / span, 0.0, 1.0) if span > 0.0 else 0.0)
	var h := src.y * k
	draw_texture_rect(under, Rect2(Vector2(0, roundf((size.y - h) * 0.5)), Vector2(dst_w * k, h)), false)


## Zasięg kształtu w każdym wierszu grafiki (do przycinania wypełnienia po skosie).
static func _rows(tex: Texture2D) -> Array:
	if _rows_cache.has(tex):
		return _rows_cache[tex]
	var img := tex.get_image()
	var l := PackedFloat32Array()
	var r := PackedFloat32Array()
	l.resize(32)
	r.resize(32)
	if img:
		if img.is_compressed():
			img.decompress()
		for y in range(mini(img.get_height(), 32)):
			var first := -1
			var last := -1
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.05:
					if first < 0:
						first = x
					last = x
			l[y] = maxf(first, 0)
			r[y] = last + 1 if last >= 0 else img.get_width()
	_rows_cache[tex] = [l, r]
	return _rows_cache[tex]


## Końcówki nierozciągane: najdalszy początek / koniec kształtu w wierszach + 1 px obrysu.
static func _caps(rows: Array, src: Vector2) -> Vector2:
	var cl := 0.0
	var cr := 0.0
	for y in range(int(src.y)):
		cl = maxf(cl, rows[0][y] + 1.0)
		cr = maxf(cr, src.x - rows[1][y] + 1.0)
	return Vector2(minf(cl, src.x * 0.45), minf(cr, src.x * 0.45))
