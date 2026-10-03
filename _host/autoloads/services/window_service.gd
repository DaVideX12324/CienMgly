extends Node

signal resolution_changed(new_resolution: Vector2i)
signal window_mode_changed(mode_idx: int)

const MODE_WINDOWED := 0
const MODE_BORDERLESS := 1
const MODE_FULLSCREEN := 2

## Najmniejszy obszar roboczy okna (bez ramki) w trybie okienkowym.
const MIN_WINDOW_SIZE := Vector2i(320, 240)

var window_mode_idx := MODE_FULLSCREEN
var resolution := Vector2i(1920, 1080)
var monitor_idx := 0


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

	if DisplayServer.get_name() != "headless":
		match window_mode_idx:
			MODE_WINDOWED:
				_leave_fullscreen()
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				_disable_stretch()
				_place_windowed(res)
			MODE_BORDERLESS:
				_leave_fullscreen()
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				# Windows maksymalizuje okno, które po zdjęciu ramki wypełnia obszar roboczy — z powrotem do okna.
				_leave_fullscreen()
				_disable_stretch()
				var screen_rect := _screen_rect(monitor_idx)
				var clamped := res.clamp(MIN_WINDOW_SIZE, screen_rect.size)
				DisplayServer.window_set_size(clamped)
				DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - clamped) / 2)
			MODE_FULLSCREEN:
				var already := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN \
						and DisplayServer.window_get_current_screen() == monitor_idx
				if not already:
					_leave_fullscreen()
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
					DisplayServer.window_set_current_screen(monitor_idx)
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				_enable_stretch(res)

	if save_now:
		SettingsService.save_settings()
	window_mode_changed.emit(window_mode_idx)
	if resolution != previous_resolution:
		resolution_changed.emit(resolution)


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


func get_available_resolutions(screen: int = -1) -> Array[Vector2i]:
	var target_screen := monitor_idx if screen < 0 else screen
	var screen_size := DisplayServer.screen_get_size(target_screen)
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
	var border := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var inner := res.clamp(MIN_WINDOW_SIZE, (rect.size - border).max(MIN_WINDOW_SIZE))
	if inner != DisplayServer.window_get_size():
		DisplayServer.window_set_size(inner)
	var decorated := inner + border
	_set_outer_position(rect.position + (rect.size - decorated) / 2)


## window_set_position ustawia róg obszaru roboczego, nie okna z ramką — przesunięcie o lewą/górną ramkę.
func _set_outer_position(outer: Vector2i) -> void:
	var frame := DisplayServer.window_get_position() - DisplayServer.window_get_position_with_decorations()
	DisplayServer.window_set_position(outer + frame)


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
