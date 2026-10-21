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
	ScaleMode.LARGE: 1081,  # powyżej FHD — przy 1080 ×1,5 jest za duże (decyzja usera 2026-10-16)
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
## Ręczny wybór gracza bez przycięcia do ekranu (-1 = auto) — po powrocie do większego okna wraca w całości.
var picked_mode := -1


func set_mode(mode: int) -> void:
	user_picked = true
	picked_mode = clampi(mode, ScaleMode.XSMALL, ScaleMode.XLARGE)
	current_mode = _clamp_mode_to_screen(picked_mode)


func reset_to_auto() -> void:
	user_picked = false
	picked_mode = -1
	current_mode = max_mode_for_height(_screen_height())


## Największa skala, przy której UI mieści się na ekranie tej wysokości (tabela MIN_SCREEN_H) — wybór automatyczny
## i po każdej zmianie rozdzielczości; w opcjach większe pozycje są wyszarzone.
func max_mode_for_height(height: int) -> int:
	var result: int = ScaleMode.XLARGE
	while result > ScaleMode.XSMALL and height < int(MIN_SCREEN_H[result]):
		result -= 1
	return result


func get_mode_labels() -> Array[String]:
	var i18n := get_node_or_null("/root/I18nService")
	if i18n and i18n.has_method("t"):
		return [
			str(i18n.call("t", "host.options.scale_xsmall", SCALE_LABELS[ScaleMode.XSMALL])),
			str(i18n.call("t", "host.options.scale_small", SCALE_LABELS[ScaleMode.SMALL])),
			str(i18n.call("t", "host.options.scale_normal", SCALE_LABELS[ScaleMode.NORMAL])),
			str(i18n.call("t", "host.options.scale_large", SCALE_LABELS[ScaleMode.LARGE])),
			str(i18n.call("t", "host.options.scale_xlarge", SCALE_LABELS[ScaleMode.XLARGE])),
		]
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
			set_mode(saved)
			return
	reset_to_auto()


func save_to_cfg(cfg: ConfigFile) -> void:
	cfg.set_value("ui", "ui_scale_mode", picked_mode if user_picked and picked_mode >= 0 else current_mode)
	cfg.set_value("ui", "ui_scale_auto", not user_picked)


## Nowa rozdzielczość (opcje, przeciągnięte okno, dopasowanie okna po starcie): skala auto — największa, jaka się
## mieści; ręczny wybór gracza zostaje, przycięty do ekranu, gdy się nie mieści (decyzja usera 2026-10-21 — wcześniej
## każda zmiana rozdzielczości przełączała na auto).
func on_resolution_changed(_new_resolution: Vector2i) -> void:
	if user_picked and picked_mode >= 0:
		current_mode = _clamp_mode_to_screen(picked_mode)
	else:
		current_mode = max_mode_for_height(_screen_height())


func _screen_height() -> int:
	var height: int = WindowService.resolution.y
	return height if height > 0 else DisplayServer.window_get_size().y


func _clamp_mode_to_screen(mode: int) -> int:
	return mini(clampi(mode, ScaleMode.XSMALL, ScaleMode.XLARGE), max_mode_for_height(_screen_height()))
