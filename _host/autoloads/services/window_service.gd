extends Node

signal resolution_changed(new_resolution: Vector2i)
signal window_mode_changed(mode_idx: int)

const MODE_WINDOWED := 0
const MODE_BORDERLESS := 1
const MODE_FULLSCREEN := 2

var window_mode_idx := MODE_FULLSCREEN
var resolution := Vector2i(1920, 1080)
var monitor_idx := 0


func apply_settings(mode_idx: int, res: Vector2i, screen: int, save_now: bool = true) -> void:
	var previous_resolution := resolution
	window_mode_idx = clampi(mode_idx, MODE_WINDOWED, MODE_FULLSCREEN)
	resolution = res
	monitor_idx = clampi(screen, 0, max(0, DisplayServer.get_screen_count() - 1))

	if DisplayServer.get_name() == "headless":
		if save_now:
			SettingsService.save_settings()
		return

	var screen_pos := DisplayServer.screen_get_position(monitor_idx)
	var screen_size := DisplayServer.screen_get_size(monitor_idx)

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	match window_mode_idx:
		MODE_WINDOWED:
			_disable_stretch()
			DisplayServer.window_set_size(res)
			var decorated := DisplayServer.window_get_size_with_decorations()
			var border := decorated - DisplayServer.window_get_size()
			var inner := Vector2i(maxi(res.x - border.x, 320), maxi(res.y - border.y, 240))
			DisplayServer.window_set_size(inner)
			DisplayServer.window_set_position(screen_pos + (screen_size - decorated) / 2)
		MODE_BORDERLESS:
			_disable_stretch()
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var clamped := Vector2i(mini(res.x, screen_size.x), mini(res.y, screen_size.y))
			DisplayServer.window_set_size(clamped)
			DisplayServer.window_set_position(screen_pos + (screen_size - clamped) / 2)
		MODE_FULLSCREEN:
			DisplayServer.window_set_size(res)
			DisplayServer.window_set_position(screen_pos + (screen_size - res) / 2)
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
	center_on_screen(_get_screen_at(DisplayServer.mouse_get_position()))


func center_on_screen(screen: int) -> void:
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var window_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_pos + (screen_size - window_size) / 2)


func get_available_resolutions(screen: int = -1) -> Array[Vector2i]:
	var target_screen := monitor_idx if screen < 0 else screen
	var screen_size := DisplayServer.screen_get_size(target_screen)
	var candidates: Array[Vector2i] = [
		Vector2i(640, 480),
		Vector2i(800, 600),
		Vector2i(1024, 600),
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]
	var result: Array[Vector2i] = []
	for candidate in candidates:
		if candidate.x <= screen_size.x and candidate.y <= screen_size.y:
			result.append(candidate)
	if not result.has(screen_size):
		result.append(screen_size)
	return result


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
		var rect := Rect2i(DisplayServer.screen_get_position(index), DisplayServer.screen_get_size(index))
		if rect.has_point(position):
			return index
	return DisplayServer.get_primary_screen()
