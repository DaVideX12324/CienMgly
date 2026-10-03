extends Node

signal resolution_changed(new_resolution: Vector2i)


var window_mode_idx: int:
	get:
		return WindowService.window_mode_idx
	set(value):
		WindowService.window_mode_idx = value


var resolution: Vector2i:
	get:
		return WindowService.resolution
	set(value):
		WindowService.resolution = value


var monitor_idx: int:
	get:
		return WindowService.monitor_idx
	set(value):
		WindowService.monitor_idx = value


func _ready() -> void:
	if not SettingsService.resolution_changed.is_connected(_on_resolution_changed):
		SettingsService.resolution_changed.connect(_on_resolution_changed)


func apply_settings(mode_idx: int, res: Vector2i, screen: int) -> void:
	SettingsService.apply_settings(mode_idx, res, screen)


func get_available_resolutions() -> Array[Vector2i]:
	return SettingsService.get_available_resolutions()


func get_bus_volume(bus_name: String) -> float:
	return SettingsService.get_bus_volume(bus_name)


func set_bus_volume(bus_name: String, value: float, save_now: bool = true) -> void:
	SettingsService.set_bus_volume(bus_name, value, save_now)


func get_global(key: String, default_value: Variant = null) -> Variant:
	return SettingsService.get_global(key, default_value)


func set_global(key: String, value: Variant, save_now: bool = true) -> void:
	SettingsService.set_global(key, value, save_now)


func get_module(module_id: String, key: String, default_value: Variant = null) -> Variant:
	return SettingsService.get_module(module_id, key, default_value)


func set_module(module_id: String, key: String, value: Variant, save_now: bool = true) -> void:
	SettingsService.set_module(module_id, key, value, save_now)


func _on_resolution_changed(new_resolution: Vector2i) -> void:
	resolution_changed.emit(new_resolution)
