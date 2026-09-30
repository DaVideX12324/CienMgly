extends CanvasLayer

## Ekran ładowania: tytuł, pasek postępu, opis etapu. Scena: scenes/ui/loading_screen.tscn
## (wygląd edytuje się tam; skrypt szuka węzłów po unikalnych nazwach %Root, %Art, %Title, %Stage,
## %Percent, %Bar (opcjonalnie %FillClip + %Shine — błysk na pasku), więc można je dowolnie przenosić
## w drzewie, np. do MarginContainer). Źródło postępu do wyboru:
##   track(source)             — obiekt z fraction() -> 0..1 i opcjonalnie label() -> String,
##                               np. GenProgress generatora map (procedural_level);
##   track_resource_load(path) — wczytywanie zasobu w tle (ResourceLoader.load_threaded_request),
##                               np. ręcznie robiona mapa jak tutorial_area;
##   set_progress(frac, label) — ręcznie, bez źródła.
## close() dociąga pasek do 100%, wygasza ekran i usuwa węzeł.
##
## Dopasowywanie układu: `paused` (inspektor, Remote w trakcie gry albo klawisz Pause/Break) zatrzymuje
## pasek, a close() czeka ze zniknięciem do zdjęcia pauzy. Scena uruchomiona sama (F6) pokazuje
## podgląd: grafika z folderu preview_key, nazwa preview_location, pasek na preview_progress.
##
## Tło: losowa grafika z folderu mapy BACKGROUND_DIR/<klucz>/ (set_background_for) — dowolne pliki
## .png/.jpg/.webp, nazwy bez znaczenia. Brak folderu lub grafik = ciemne tło.
## Pod paskiem ładowania: pas %Band w kolorze dolnej krawędzi grafiki (edge_color). Wysokość pasa
## i miejsce przejścia w obraz (offsety gradientu) ustawia się w edytorze — skrypt zmienia tylko kolory.
## Klucze (nazwy folderów): mapa ręczna = nazwa pliku sceny (tutorial_area), mapa generowana =
## ProceduralLevel.loading_screen_key albo biom z typu poziomu (cave, castle, forest).
## Prompty i zasady grafik: BACKGROUND_DIR/loading_screen_prompts.md.

const FADE_TIME := 0.25
const BACKGROUND_DIR := "res://modules/quiz_rpg/assets/textures/loading_screens/"
const BACKGROUND_EXTS := ["png", "jpg", "jpeg", "webp"]
## Dolna część grafiki (ułamek wysokości), z której uśredniany jest kolor pasa.
const BAND_SAMPLE := 0.02
## Błysk przesuwający się po wypełnionej części paska (%Shine w %FillClip) — widać, że gra działa,
## także gdy postęp chwilowo stoi. Szerokość i prędkość w px, przerwa między przejściami w s.
const SHINE_WIDTH := 140.0
const SHINE_SPEED := 600.0
const SHINE_GAP := 0.6
## Kropki po nazwie etapu: 1..3, zmiana co DOTS_STEP s.
const DOTS_STEP := 0.4

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

## Pauza ekranu (do dopasowywania układu): pasek stoi, close() czeka ze zniknięciem do jej zdjęcia.
## Przełącza też klawisz Pause/Break.
@export var paused: bool = false:
	set(value):
		paused = value
		if not paused and _close_pending:
			close()

@export_group("Podgląd (scena uruchomiona sama, F6)")
## Folder grafik tła do podglądu (jak klucz mapy).
@export var preview_key: String = "cave"
@export var preview_location: String = "Jaskinia Żółtych Łez"
@export_range(0.0, 1.0, 0.01) var preview_progress: float = 0.4
@export_group("")

var _source = null  # obiekt z fraction() / label()
var _close_pending := false
var _target := 0.0
var _label := ""
var _shown := 0.0
var _closing := false
var _anim_t := 0.0
## Lewa krawędź błysku (px od początku paska) i pozostała przerwa do następnego przejścia.
var _shine_x := -SHINE_WIDTH
var _shine_wait := 0.0

@onready var _root: Control = %Root
@onready var _art: TextureRect = %Art
@onready var _band: TextureRect = %Band
@onready var _title: Label = %Title
@onready var _location: Label = %Location
@onready var _bar: ProgressBar = %Bar
@onready var _stage: Label = %Stage
@onready var _percent: Label = %Percent
@onready var _fill_clip: Control = get_node_or_null("%FillClip")
@onready var _shine: Control = get_node_or_null("%Shine")


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
	_apply_band()
	_bar.value = 0.0
	_percent.text = ""
	_stage.text = ""
	if get_tree().current_scene == self:
		_show_preview()


## Podgląd przy uruchomieniu samej sceny (F6) — do dopasowywania układu.
func _show_preview() -> void:
	set_background_for(preview_key)
	if location.is_empty():
		location = preview_location
	if title == "Ładowanie…":
		title = "Generowanie jaskini…"
	set_progress(preview_progress, "Podgląd układu")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_PAUSE:
		paused = not paused
		print("[LoadingScreen] pauza: ", paused)
		get_viewport().set_input_as_handled()


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
	_anim_t += delta
	_animate(delta)
	if _closing or paused:
		return
	if _source != null:
		_target = _source.fraction()
		_label = _source.label() if _source.has_method("label") else ""
	# Płynnie za postępem, ale bez zostawania w tyle przy dużych skokach.
	_shown = minf(_target, lerpf(_shown, _target, clampf(delta * 8.0, 0.0, 1.0)) + delta * 0.05)
	_bar.value = _shown * 100.0
	_percent.text = "%d%%" % int(_shown * 100.0)  # w dół: 100% dopiero przy close()


## Błysk na pasku i kropki po nazwie etapu (niezależnie od postępu).
func _animate(delta: float) -> void:
	if _label != "":
		_stage.text = _label + ".".repeat(1 + int(_anim_t / DOTS_STEP) % 3)
	if _fill_clip == null or _shine == null:
		return
	var fill_w := _bar.size.x * _bar.value / 100.0
	_fill_clip.position = Vector2.ZERO
	_fill_clip.size = Vector2(fill_w, _bar.size.y)
	_shine.visible = fill_w >= 1.0
	_shine.size = Vector2(SHINE_WIDTH, _bar.size.y)
	# Stan zamiast fmod(czas, okres): okres zależy od szerokości wypełnienia, która rośnie z paskiem,
	# więc wzór skakał (także w lewo). Tu błysk tylko jedzie w prawo; po dojściu do końca wypełnienia
	# czeka SHINE_GAP i startuje od nowa (rosnące wypełnienie po prostu wydłuża trasę).
	if _shine_wait > 0.0:
		_shine_wait -= delta
		_shine.visible = false
		return
	_shine_x += SHINE_SPEED * delta
	if _shine_x >= fill_w:
		_shine_x = -SHINE_WIDTH
		_shine_wait = SHINE_GAP
		_shine.visible = false
		return
	_shine.position = Vector2(_shine_x, 0.0)


## Pasek na 100% i zanik; węzeł usuwa się sam.
func close() -> void:
	if _closing:
		return
	if paused:
		_close_pending = true
		return
	_close_pending = false
	_closing = true
	_shown = 1.0
	_bar.value = 100.0
	_percent.text = "100%"
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
