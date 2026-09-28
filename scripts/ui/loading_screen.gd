extends CanvasLayer

## Ekran ładowania: tytuł, pasek postępu, opis etapu. Scena: scenes/ui/loading_screen.tscn
## (wygląd edytuje się tam; skrypt szuka węzłów po unikalnych nazwach %Root, %Art, %Title, %Stage,
## %Percent, %Bar, więc można je dowolnie przenosić w drzewie, np. do MarginContainer). Źródło postępu do wyboru:
##   track(source)             — obiekt z fraction() -> 0..1 i opcjonalnie label() -> String,
##                               np. GenProgress generatora map (procedural_level);
##   track_resource_load(path) — wczytywanie zasobu w tle (ResourceLoader.load_threaded_request),
##                               np. ręcznie robiona mapa jak tutorial_area;
##   set_progress(frac, label) — ręcznie, bez źródła.
## close() dociąga pasek do 100%, wygasza ekran i usuwa węzeł.
##
## Tło: losowa grafika z folderu mapy BACKGROUND_DIR/<klucz>/ (set_background_for) — dowolne pliki
## .png/.jpg/.webp, nazwy bez znaczenia. Brak folderu lub grafik = ciemne tło.
## Pod paskiem ładowania: pas %Band w kolorze dolnej krawędzi grafiki (edge_color), od dołu ekranu
## do góry bloku z nazwą lokacji i paskiem + miękkie przejście BAND_FADE w obraz.
## Klucze (nazwy folderów): mapa ręczna = nazwa pliku sceny (tutorial_area), mapa generowana =
## ProceduralLevel.loading_screen_key albo biom z typu poziomu (cave, castle, forest).
## Prompty i zasady grafik: BACKGROUND_DIR/loading_screen_prompts.md.

const FADE_TIME := 0.25
const BACKGROUND_DIR := "res://modules/quiz_rpg/assets/textures/loading_screens/"
const BACKGROUND_EXTS := ["png", "jpg", "jpeg", "webp"]
## Wysokość (px) miękkiego przejścia od grafiki do jednolitego pasa pod paskiem ładowania.
const BAND_FADE := 64.0
## Dolna część grafiki (ułamek wysokości), z której uśredniany jest kolor pasa.
const BAND_SAMPLE := 0.02

## Nazwa lokacji nad paskiem (duży ozdobny napis, font Jacquard 24). Pusta = ukryta.
@export var location: String = "":
	set(value):
		location = value
		if is_node_ready():
			_apply_location()

## Tytuł (lewa strona pasa nad paskiem postępu).
@export var title: String = "Ładowanie…":
	set(value):
		title = value
		if is_node_ready():
			_title.text = value

## Grafika tła (zakrywa ekran, proporcje zachowane). null = ciemne tło.
@export var background: Texture2D = null:
	set(value):
		background = value
		if is_node_ready():
			_art.texture = value
			_apply_band()

var _source = null  # obiekt z fraction() / label()
var _target := 0.0
var _label := ""
var _shown := 0.0
var _closing := false

@onready var _root: Control = %Root
@onready var _art: TextureRect = %Art
@onready var _band: TextureRect = %Band
@onready var _bottom: Control = %MarginContainer
@onready var _title: Label = %Title
@onready var _location: Label = %Location
@onready var _bar: ProgressBar = %Bar
@onready var _stage: Label = %Stage
@onready var _percent: Label = %Percent


## Postęp wczytywania zasobu w tle (ResourceLoader). Zakłada, że load_threaded_request(path) już
## wywołano; zasób odbiera wywołujący przez ResourceLoader.load_threaded_get(path).
class ResourceLoadProgress:
	var path: String
	var text: String
	var _progress: Array = []

	func _init(p_path: String, p_text: String) -> void:
		path = p_path
		text = p_text

	func fraction() -> float:
		var status := ResourceLoader.load_threaded_get_status(path, _progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return 1.0
		return float(_progress[0]) if not _progress.is_empty() else 0.0

	func label() -> String:
		return text


## Grafiki tła z folderu mapy BACKGROUND_DIR/<klucz>/. ResourceLoader.list_directory widzi pliki
## także w wyeksportowanej grze (tam na dysku są tylko .import/.remap).
static func background_paths(key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := BACKGROUND_DIR + key + "/"
	if key.is_empty() or not DirAccess.dir_exists_absolute(dir):
		return out
	for f in ResourceLoader.list_directory(dir):
		if f.get_extension().to_lower() in BACKGROUND_EXTS:
			out.append(dir + f)
	return out


## Losowa grafika pierwszego klucza, który ma jakąkolwiek; false = brak (zostaje obecne tło).
func set_background_for(keys) -> bool:
	for key in ([keys] if keys is String else keys):
		var paths := background_paths(key)
		if not paths.is_empty():
			background = load(paths[randi() % paths.size()]) as Texture2D
			return background != null
	return false


func _ready() -> void:
	_title.text = title
	_apply_location()
	_art.texture = background
	_bottom.resized.connect(_layout_band)
	_apply_band()
	_bar.value = 0.0
	_percent.text = ""
	_stage.text = ""


func _apply_location() -> void:
	_location.text = location
	_location.visible = not location.is_empty()


## Średni kolor dolnego pasa grafiki (BAND_SAMPLE wysokości) — tło pod paskiem ładowania.
static func edge_color(tex: Texture2D) -> Color:
	var img := tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return Color(0.05, 0.045, 0.04)
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var rows := maxi(2, int(h * BAND_SAMPLE))
	var step := maxi(1, w / 256)
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(h - rows, h):
		for x in range(0, w, step):
			sum += img.get_pixel(x, y)
			n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n, 1.0)


func _apply_band() -> void:
	_band.visible = background != null
	if background == null:
		return
	var c := edge_color(background)
	var grad: Gradient = (_band.texture as GradientTexture2D).gradient
	grad.set_color(0, Color(c, 0.0))
	grad.set_color(1, c)
	grad.set_color(2, c)
	_layout_band()


## Pas sięga od dołu ekranu do góry bloku z nazwą i paskiem, plus BAND_FADE przejścia.
func _layout_band() -> void:
	var height := _bottom.size.y + BAND_FADE
	_band.offset_top = -height
	(_band.texture as GradientTexture2D).gradient.set_offset(1, BAND_FADE / height)


## Podpina źródło postępu (fraction(), opcjonalnie label()) — od tej chwili pasek za nim podąża.
func track(source) -> void:
	_source = source


## Pasek za wczytywaniem zasobu w tle; load_threaded_request(path) musi być już wywołane.
func track_resource_load(path: String, label: String = "Wczytywanie mapy") -> void:
	track(ResourceLoadProgress.new(path, label))


## Postęp ustawiany ręcznie (odpina źródło).
func set_progress(fraction: float, label: String = "") -> void:
	_source = null
	_target = clampf(fraction, 0.0, 1.0)
	_label = label


func _process(delta: float) -> void:
	if _closing:
		return
	if _source != null:
		_target = _source.fraction()
		_label = _source.label() if _source.has_method("label") else ""
	# Płynnie za postępem, ale bez zostawania w tyle przy dużych skokach.
	_shown = minf(_target, lerpf(_shown, _target, clampf(delta * 12.0, 0.0, 1.0)) + delta * 0.05)
	_bar.value = _shown * 100.0
	_percent.text = "%d%%" % int(round(_shown * 100.0))
	if _label != "":
		_stage.text = _label + "…"


## Pasek na 100% i zanik; węzeł usuwa się sam.
func close() -> void:
	if _closing:
		return
	_closing = true
	_shown = 1.0
	_bar.value = 100.0
	_percent.text = "100%"
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
