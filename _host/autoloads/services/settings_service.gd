extends Node

signal resolution_changed(new_resolution: Vector2i)
signal settings_saved
signal settings_loaded
## Zmiana ustawienia modułu (set_module) — np. motyw UI z opcji, zmieniany na żywo.
signal module_setting_changed(module_id: String, key: String, value: Variant)

const CONFIG_PATH := "user://artefakt_wiedzy_settings.cfg"
const SEC_DISPLAY := "display"
const SEC_AUDIO := "audio"
const KEY_QUIZLESS_MODE := "quizless_mode"

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_settings()
	apply_input_binds()
	UIScaleService.load_from_cfg(_cfg)
	if not resolution_changed.is_connected(UIScaleService.on_resolution_changed):
		resolution_changed.connect(UIScaleService.on_resolution_changed)
	_load_audio()
	# Okno na zapisanym monitorze (wcześniej centrowanie pod kursorem nadpisywało wybór z opcji).
	WindowService.apply_settings(WindowService.window_mode_idx, WindowService.resolution, WindowService.monitor_idx, false)


func load_settings() -> void:
	_cfg = ConfigFile.new()
	if _cfg.load(CONFIG_PATH) != OK:
		_load_defaults()
	else:
		WindowService.window_mode_idx = _cfg.get_value(SEC_DISPLAY, "window_mode_idx", WindowService.MODE_FULLSCREEN)
		WindowService.monitor_idx = clampi(int(_cfg.get_value(SEC_DISPLAY, "monitor_idx", 0)), 0, maxi(0, DisplayServer.get_screen_count() - 1))
		var default_screen := DisplayServer.screen_get_size(WindowService.monitor_idx)
		var width: int = _cfg.get_value(SEC_DISPLAY, "resolution_x", default_screen.x)
		var height: int = _cfg.get_value(SEC_DISPLAY, "resolution_y", default_screen.y)
		WindowService.resolution = Vector2i(width, height)
		WindowService.window_maximized = bool(_cfg.get_value(SEC_DISPLAY, "window_maximized", false))
	WindowService.monitor_idx = clampi(WindowService.monitor_idx, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	settings_loaded.emit()


## Zapisane klawisze akcji wszystkich modułów (sekcje module:<id>, klucz "binds") -> InputMap.
func apply_input_binds() -> void:
	for section in _cfg.get_sections():
		if section.begins_with("module:"):
			InputBinds.apply_module(self, section.substr(7))


func save_settings() -> void:
	_cfg.set_value(SEC_DISPLAY, "window_mode_idx", WindowService.window_mode_idx)
	_cfg.set_value(SEC_DISPLAY, "resolution_x", WindowService.resolution.x)
	_cfg.set_value(SEC_DISPLAY, "resolution_y", WindowService.resolution.y)
	_cfg.set_value(SEC_DISPLAY, "monitor_idx", WindowService.monitor_idx)
	_cfg.set_value(SEC_DISPLAY, "window_maximized", WindowService.window_maximized)
	UIScaleService.save_to_cfg(_cfg)
	_save_audio_to_cfg()
	_cfg.save(CONFIG_PATH)
	settings_saved.emit()


func apply_settings(mode_idx: int, res: Vector2i, screen: int) -> void:
	var previous_resolution := WindowService.resolution
	WindowService.apply_settings(mode_idx, res, screen, false)
	save_settings()
	if WindowService.resolution != previous_resolution:
		resolution_changed.emit(WindowService.resolution)


func get_available_resolutions() -> Array[Vector2i]:
	return WindowService.get_available_resolutions(WindowService.monitor_idx)


func get_global(key: String, default_value: Variant = null) -> Variant:
	if not _cfg.has_section("global"):
		return default_value
	if not _cfg.has_section_key("global", key):
		return default_value
	return _cfg.get_value("global", key, default_value)


func set_global(key: String, value: Variant, save_now: bool = true) -> void:
	_cfg.set_value("global", key, value)
	if save_now:
		save_settings()


func is_quizless_mode_enabled() -> bool:
	for key_name in [KEY_QUIZLESS_MODE, "disable_quizzes", "skip_quizzes"]:
		var value: Variant = get_global(key_name, null)
		if value != null:
			return bool(value)
	return false


func set_quizless_mode_enabled(enabled: bool, save_now: bool = true) -> void:
	set_global(KEY_QUIZLESS_MODE, enabled, false)
	if save_now:
		save_settings()


func get_module(module_id: String, key: String, default_value: Variant = null) -> Variant:
	var section_name: String = "module:%s" % module_id
	if not _cfg.has_section(section_name):
		return default_value
	if not _cfg.has_section_key(section_name, key):
		return default_value
	return _cfg.get_value(section_name, key, default_value)


func set_module(module_id: String, key: String, value: Variant, save_now: bool = true) -> void:
	_cfg.set_value("module:%s" % module_id, key, value)
	if save_now:
		save_settings()
	module_setting_changed.emit(module_id, key, value)


func get_bus_volume(bus_name: String) -> float:
	var key := bus_name.to_lower()
	if _cfg.has_section_key(SEC_AUDIO, key):
		return clampf(float(_cfg.get_value(SEC_AUDIO, key, 1.0)), 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 1.0
	var db := AudioServer.get_bus_volume_db(index)
	if db <= -70.0:
		return 0.0
	return clampf(db_to_linear(db), 0.0, 1.0)


func set_bus_volume(bus_name: String, value: float, save_now: bool = true) -> void:
	var index := _ensure_bus(bus_name)
	var clamped_val := clampf(value, 0.0, 1.0)
	_cfg.set_value(SEC_AUDIO, bus_name.to_lower(), clamped_val)
	if clamped_val <= 0.0001:
		AudioServer.set_bus_volume_db(index, -80.0)
	else:
		AudioServer.set_bus_volume_db(index, linear_to_db(clamped_val))

	var audio := get_node_or_null("/root/AudioService")
	if audio:
		match bus_name.to_lower():
			"master":
				if audio.master_volume != clamped_val:
					audio.master_volume = clamped_val
			"music":
				if audio.music_volume != clamped_val:
					audio.music_volume = clamped_val
			"sfx":
				if audio.sfx_volume != clamped_val:
					audio.sfx_volume = clamped_val

	if save_now:
		save_settings()


## Pierwsze uruchomienie: pełny ekran w natywnej rozdzielczości monitora, na którym jest kursor.
func _load_defaults() -> void:
	WindowService.monitor_idx = WindowService.get_screen_at_cursor()
	WindowService.resolution = DisplayServer.screen_get_size(WindowService.monitor_idx)
	WindowService.window_mode_idx = WindowService.MODE_FULLSCREEN


func _load_audio() -> void:
	for bus_name: String in ["Master", "Music", "SFX"]:
		var key: String = bus_name.to_lower()
		var value: float = clampf(float(_cfg.get_value(SEC_AUDIO, key, 1.0)), 0.0, 1.0)
		var index := _ensure_bus(bus_name)
		if value <= 0.0001:
			AudioServer.set_bus_volume_db(index, -80.0)
		else:
			AudioServer.set_bus_volume_db(index, linear_to_db(value))


func _save_audio_to_cfg() -> void:
	for bus_name: String in ["Master", "Music", "SFX"]:
		var key: String = bus_name.to_lower()
		if not _cfg.has_section_key(SEC_AUDIO, key):
			_cfg.set_value(SEC_AUDIO, key, get_bus_volume(bus_name))


func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	return index
