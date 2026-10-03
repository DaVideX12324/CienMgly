extends Node

signal scale_changed(new_scale: float)

enum ScaleMode { XSMALL, SMALL, NORMAL, LARGE, XLARGE }


var current_mode: int:
	get:
		return UIScaleService.current_mode
	set(value):
		UIScaleService.current_mode = value


var scale_factor: float:
	get:
		return UIScaleService.scale_factor


var user_picked: bool:
	get:
		return UIScaleService.user_picked
	set(value):
		UIScaleService.user_picked = value


var _user_picked: bool:
	get:
		return UIScaleService.user_picked
	set(value):
		UIScaleService.user_picked = value


func _ready() -> void:
	if not UIScaleService.scale_changed.is_connected(_on_scale_changed):
		UIScaleService.scale_changed.connect(_on_scale_changed)


func set_mode(mode: int) -> void:
	UIScaleService.set_mode(mode)


func reset_to_auto() -> void:
	UIScaleService.reset_to_auto()


func get_mode_labels() -> Array[String]:
	return UIScaleService.get_mode_labels()


func px(base_pixels: float) -> int:
	return UIScaleService.px(base_pixels)


func sz(base: float) -> float:
	return UIScaleService.sz(base)


func sz2(width: float, height: float) -> Vector2:
	return UIScaleService.sz2(width, height)


func load_from_cfg(cfg: ConfigFile) -> void:
	UIScaleService.load_from_cfg(cfg)


func save_to_cfg(cfg: ConfigFile) -> void:
	UIScaleService.save_to_cfg(cfg)


func on_resolution_changed(new_resolution: Vector2i) -> void:
	UIScaleService.on_resolution_changed(new_resolution)


func _on_scale_changed(new_scale: float) -> void:
	scale_changed.emit(new_scale)
