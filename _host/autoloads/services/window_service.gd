extends Node

signal resolution_changed(new_resolution: Vector2i)
signal window_mode_changed(mode_idx: int)
## Użytkownik sam zmienił rozmiar okna (tryb okienkowy) — po resolution_changed.
signal window_resized_by_user(new_size: Vector2i)

const MODE_WINDOWED := 0
const MODE_BORDERLESS := 1
const MODE_FULLSCREEN := 2

## Najmniejszy obszar roboczy okna (bez ramki) w trybie okienkowym.
const MIN_WINDOW_SIZE := Vector2i(320, 240)
## Ramka okna (z niewidocznymi krawędziami Windows) zanim da się ją zmierzyć — np. gdy gra startuje w pełnym ekranie.
const DEFAULT_FRAME := Vector2i(16, 39)

var window_mode_idx := MODE_FULLSCREEN
var resolution := Vector2i(1920, 1080)
var monitor_idx := 0
## Okno zmaksymalizowane przez użytkownika (tryb okienkowy) — przywracane przy starcie.
var window_maximized := false
## Ramka zmierzona na oknie z dekoracjami (ZERO = jeszcze nie).
var _frame := Vector2i.ZERO
## apply_settings w toku — zmiany rozmiaru okna to nie ręczna zmiana użytkownika.
var _applying := false
var _resize_timer: Timer

## Po ręcznej zmianie rozmiaru okna (przeciąganie, maksymalizacja) zapis dopiero po tylu sekundach spokoju.
const RESIZE_SETTLE_SEC := 0.4


func _ready() -> void:
	_resize_timer = Timer.new()
	_resize_timer.one_shot = true
	_resize_timer.wait_time = RESIZE_SETTLE_SEC
	_resize_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_resize_timer.timeout.connect(_on_resize_settled)
	add_child(_resize_timer)
	get_tree().root.size_changed.connect(_on_root_size_changed)


## Ustawia tryb okna, rozdzielczość i monitor. Okno ląduje zawsze na wybranym monitorze:
## - okno: obszar roboczy = res, ale okno z ramką mieści się w obszarze roboczym ekranu (bez paska zadań),
##   wyśrodkowane w nim;
## - bez ramki: okno res (przycięte do ekranu), wyśrodkowane na ekranie;
## - pełny ekran: wyłączny pełny ekran na tym monitorze, UI układane w res (stretch canvas_items).
## Przejście przez tryb okienkowy tylko gdy trzeba (zmiana trybu / monitora) — bez mignięcia przy starcie
## i przy samej zmianie rozdzielczości w pełnym ekranie.
func apply_settings(mode_idx: int, res: Vector2i, screen: int, save_now: bool = true) -> void:
	var previous_resolution := resolution
	window_mode_idx = clampi(mode_idx, MODE_WINDOWED, MODE_FULLSCREEN)
	resolution = res
	monitor_idx = clampi(screen, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	_applying = true

	if DisplayServer.get_name() != "headless":
		match window_mode_idx:
			MODE_WINDOWED:
				# Zmaksymalizowane zostaje, gdy rozmiar się nie zmienia (start, „Zastosuj” z tą samą pozycją);
				# inny rozmiar z listy = zwykłe okno.
				var keep_maximized := window_maximized and res == previous_resolution
				_to_plain_window()
				_disable_stretch()
				if keep_maximized:
					DisplayServer.window_set_current_screen(monitor_idx)
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
				else:
					window_maximized = false
					_place_windowed(res)
			MODE_BORDERLESS:
				window_maximized = false
				_to_plain_window()
				_disable_stretch()
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				# Windows maksymalizuje okno, które po zdjęciu ramki wypełnia obszar roboczy — z powrotem do okna.
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				var screen_rect := _screen_rect(monitor_idx)
				var clamped := res.clamp(MIN_WINDOW_SIZE, screen_rect.size)
				DisplayServer.window_set_size(clamped)
				DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - clamped) / 2)
			MODE_FULLSCREEN:
				# Okno bez ramki na cały ekran Godot też zgłasza jako EXCLUSIVE_FULLSCREEN — stąd warunek flagi.
				var already := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN \
						and DisplayServer.window_get_current_screen() == monitor_idx \
						and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
				window_maximized = false
				if not already:
					_to_plain_window()
					DisplayServer.window_set_current_screen(monitor_idx)
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				_enable_stretch(res)

	_applying = false
	if _resize_timer:
		_resize_timer.stop()
	if save_now:
		SettingsService.save_settings()
	window_mode_changed.emit(window_mode_idx)
	if resolution != previous_resolution:
		resolution_changed.emit(resolution)


## Tryb okienkowy: użytkownik może dowolnie zmieniać rozmiar okna — po chwili spokoju faktyczny obszar
## roboczy (i monitor) trafia do resolution / monitor_idx, zapis i resolution_changed (prośba usera 2026-10-04).
## Zmaksymalizowane okno liczy się tak samo (obszar roboczy po maksymalizacji).
func _on_root_size_changed() -> void:
	if _applying or window_mode_idx != MODE_WINDOWED or DisplayServer.get_name() == "headless":
		return
	_resize_timer.start()


func _on_resize_settled() -> void:
	if _applying or window_mode_idx != MODE_WINDOWED:
		return
	var mode := DisplayServer.window_get_mode()
	if mode != DisplayServer.WINDOW_MODE_WINDOWED and mode != DisplayServer.WINDOW_MODE_MAXIMIZED:
		return
	var size := DisplayServer.window_get_size()
	var maximized := mode == DisplayServer.WINDOW_MODE_MAXIMIZED
	if (size == resolution and maximized == window_maximized) or size.x <= 0 or size.y <= 0:
		return
	resolution = size
	window_maximized = maximized
	monitor_idx = DisplayServer.window_get_current_screen()
	SettingsService.save_settings()
	resolution_changed.emit(resolution)
	SettingsService.resolution_changed.emit(resolution)  # UIScaleService słucha SettingsService
	window_resized_by_user.emit(resolution)


func center_on_cursor_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	center_on_screen(get_screen_at_cursor())


func center_on_screen(screen: int) -> void:
	var rect := _usable_rect(screen)
	var decorated := DisplayServer.window_get_size_with_decorations()
	_set_outer_position(rect.position + (rect.size - decorated) / 2)


## Monitor pod kursorem (gdy kursor poza ekranami — główny).
func get_screen_at_cursor() -> int:
	if DisplayServer.get_name() == "headless":
		return 0
	return _get_screen_at(DisplayServer.mouse_get_position())


## Największy obszar roboczy okna z ramką, które mieści się nad paskiem zadań monitora.
func get_max_windowed_size(screen: int = -1) -> Vector2i:
	var target_screen := monitor_idx if screen < 0 else screen
	return (_usable_rect(target_screen).size - get_frame_size()).max(MIN_WINDOW_SIZE)


## Ramka okna: zmierzona, a jeśli okno nie ma teraz ramki i jeszcze jej nie mierzono — typowa dla Windows.
func get_frame_size() -> Vector2i:
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED \
			and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		var border := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
		if border.x > 0 or border.y > 0:
			_frame = border
	return _frame if _frame != Vector2i.ZERO else DEFAULT_FRAME


## Rozdzielczości do wyboru. Dla trybu okienkowego (mode = MODE_WINDOWED) tylko takie, które z ramką mieszczą
## się nad paskiem zadań, i na końcu największe okno (get_max_windowed_size) — prośba usera 2026-10-04.
func get_available_resolutions(screen: int = -1, mode: int = -1) -> Array[Vector2i]:
	var target_screen := monitor_idx if screen < 0 else screen
	var screen_size := DisplayServer.screen_get_size(target_screen)
	if mode == MODE_WINDOWED:
		screen_size = get_max_windowed_size(target_screen)
	var candidates: Array[Vector2i] = [
		Vector2i(640, 480),
		Vector2i(800, 600),
		Vector2i(1024, 600),
		Vector2i(1280, 720),
		Vector2i(1280, 800),
		Vector2i(1366, 768),
		Vector2i(1440, 900),
		Vector2i(1600, 900),
		Vector2i(1680, 1050),
		Vector2i(1920, 1080),
		Vector2i(1920, 1200),
		Vector2i(2560, 1080),
		Vector2i(2560, 1440),
		Vector2i(2560, 1600),
		Vector2i(3440, 1440),
		Vector2i(3840, 2160),
	]
	var result: Array[Vector2i] = []
	for candidate in candidates:
		if candidate.x <= screen_size.x and candidate.y <= screen_size.y:
			result.append(candidate)
	if not result.has(screen_size):
		result.append(screen_size)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y or (a.x * a.y == b.x * b.y and a.x < b.x))
	return result


## Okno z ramką: obszar roboczy res, ale całe okno (z ramką) w obszarze roboczym ekranu; wyśrodkowane.
## Ramkę mierzy się po ustawieniu rozmiaru (window_get_size_with_decorations) i dopiero wtedy liczy pozycję
## (wcześniej pozycja liczona ze starego rozmiaru i jako róg obszaru roboczego — okno przesunięte o ramkę).
func _place_windowed(res: Vector2i) -> void:
	var rect := _usable_rect(monitor_idx)
	DisplayServer.window_set_size(res.max(MIN_WINDOW_SIZE))
	var border := get_frame_size()
	var inner := res.clamp(MIN_WINDOW_SIZE, (rect.size - border).max(MIN_WINDOW_SIZE))
	if inner != DisplayServer.window_get_size():
		DisplayServer.window_set_size(inner)
	resolution = inner  # zapis = faktyczny obszar roboczy (np. 1920x1080 na ekranie 1080p -> maks. okno)
	var decorated := inner + border
	_set_outer_position(rect.position + (rect.size - decorated) / 2)


## window_set_position ustawia róg obszaru roboczego, nie okna z ramką — przesunięcie o lewą/górną ramkę.
func _set_outer_position(outer: Vector2i) -> void:
	var frame := DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	DisplayServer.window_set_position(outer + frame)


## Zwykłe okno z ramką. Flaga „bez ramki” schodzi PIERWSZA: okno bez ramki na cały ekran Godot uznaje za
## EXCLUSIVE_FULLSCREEN i od razu cofa zmianę na tryb okienkowy (zapisane „bez ramki” 2560x1440 blokowało
## przejście do okna).
func _to_plain_window() -> void:
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	_leave_fullscreen()


## Pełny ekran / zmaksymalizowane -> zwykłe okno (bez zmiany, gdy już jest okno — bez mignięcia).
func _leave_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _screen_rect(screen: int) -> Rect2i:
	return Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))


## Ekran bez paska zadań; gdy system nie poda (pusty prostokąt) — cały ekran.
func _usable_rect(screen: int) -> Rect2i:
	var rect := DisplayServer.screen_get_usable_rect(screen)
	return rect if rect.size.x > 0 and rect.size.y > 0 else _screen_rect(screen)


func _enable_stretch(render_resolution: Vector2i) -> void:
	var root := get_tree().root
	root.content_scale_size = render_resolution
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _disable_stretch() -> void:
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO


func _get_screen_at(position: Vector2i) -> int:
	for index in range(DisplayServer.get_screen_count()):
		if _screen_rect(index).has_point(position):
			return index
	return DisplayServer.get_primary_screen()
