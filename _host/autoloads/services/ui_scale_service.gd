extends Node

signal scale_changed(new_scale: float)

enum ScaleMode { XSMALL, SMALL, NORMAL, LARGE, XLARGE }

const SCALE_VALUES: Dictionary = {
	ScaleMode.XSMALL: 0.5,
	ScaleMode.SMALL: 0.75,
	ScaleMode.NORMAL: 1.0,
	ScaleMode.LARGE: 1.5,
	ScaleMode.XLARGE: 2.0,
}

const SCALE_LABELS: Dictionary = {
	ScaleMode.XSMALL: "Bardzo male (0.5x)",
	ScaleMode.SMALL: "Male (0.75x)",
	ScaleMode.NORMAL: "Normalne (1x)",
	ScaleMode.LARGE: "Duze (1.5x)",
	ScaleMode.XLARGE: "4K (2x)",
}

const MIN_SCREEN_H: Dictionary = {
	ScaleMode.XLARGE: 2160,
	ScaleMode.LARGE: 1080,
	ScaleMode.NORMAL: 900,
	ScaleMode.SMALL: 720,
	ScaleMode.XSMALL: 0,
}

var current_mode: int = ScaleMode.NORMAL:
	set(value):
		current_mode = clampi(value, ScaleMode.XSMALL, ScaleMode.XLARGE)
		scale_factor = SCALE_VALUES[current_mode]
		scale_changed.emit(scale_factor)

var scale_factor := 1.0
var user_picked := false


func set_mode(mode: int) -> void:
	user_picked = true
	current_mode = _clamp_mode_to_screen(mode)


func reset_to_auto() -> void:
	user_picked = false
	current_mode = max_mode_for_height(_screen_height())


## Największa skala, przy której UI mieści się na ekranie tej wysokości (tabela MIN_SCREEN_H) — wybór automatyczny
## i po każdej zmianie rozdzielczości; w opcjach większe pozycje są wyszarzone.
func max_mode_for_height(height: int) -> int:
	var result: int = ScaleMode.XLARGE
	while result > ScaleMode.XSMALL and height < int(MIN_SCREEN_H[result]):
		result -= 1
	return result


func get_mode_labels() -> Array[String]:
	return [
		SCALE_LABELS[ScaleMode.XSMALL],
		SCALE_LABELS[ScaleMode.SMALL],
		SCALE_LABELS[ScaleMode.NORMAL],
		SCALE_LABELS[ScaleMode.LARGE],
		SCALE_LABELS[ScaleMode.XLARGE],
	]


func px(base_pixels: float) -> int:
	return roundi(base_pixels * scale_factor)


func sz(base: float) -> float:
	return base * scale_factor


func sz2(width: float, height: float) -> Vector2:
	return Vector2(width, height) * scale_factor


func load_from_cfg(cfg: ConfigFile) -> void:
	var is_auto: bool = cfg.get_value("ui", "ui_scale_auto", true)
	if not is_auto:
		var saved: int = cfg.get_value("ui", "ui_scale_mode", -1)
		if saved >= ScaleMode.XSMALL and saved <= ScaleMode.XLARGE:
			user_picked = true
			current_mode = _clamp_mode_to_screen(saved)
			return
	user_picked = false
	current_mode = max_mode_for_height(_screen_height())


func save_to_cfg(cfg: ConfigFile) -> void:
	cfg.set_value("ui", "ui_scale_mode", current_mode)
	cfg.set_value("ui", "ui_scale_auto", not user_picked)


## Nowa rozdzielczość (opcje, przeciągnięte okno): największa skala, jaka się mieści — także po ręcznym wyborze
## (prośba usera 2026-10-16). Ręczny wybór razem ze zmianą rozdzielczości opcje ustawiają po niej (set_mode).
func on_resolution_changed(_new_resolution: Vector2i) -> void:
	user_picked = false
	current_mode = max_mode_for_height(_screen_height())


func _screen_height() -> int:
	var height: int = WindowService.resolution.y
	return height if height > 0 else DisplayServer.window_get_size().y


func _clamp_mode_to_screen(mode: int) -> int:
	return mini(clampi(mode, ScaleMode.XSMALL, ScaleMode.XLARGE), max_mode_for_height(_screen_height()))
