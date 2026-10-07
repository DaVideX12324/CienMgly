extends Node

## Lekki obiekt modułu dla narzędzi deweloperskich (map_generator_preview itp.).
## Umożliwia rejestrację w CoreManager, udostępniając metody modułu quiz_rpg
## dla opcji (snap_font_size, skórki, style pasków, opcje dodatkowe) bez uruchamiania
## sceny głównej modułu.

const QuizTheme = preload("../ui/quiz_theme.gd")


func _ready() -> void:
	var settings := get_node_or_null("/root/SettingsService")
	if settings and settings.has_signal("module_setting_changed"):
		settings.module_setting_changed.connect(_on_module_setting_changed)


func _on_module_setting_changed(module_id: String, key: String, value: Variant) -> void:
	if module_id != QuizTheme.MODULE_ID:
		return
	if key == QuizTheme.SETTING_BRIGHTNESS:
		QuizTheme.set_brightness(float(value))
	elif key in [QuizTheme.SETTING_SKIN, QuizTheme.SETTING_BAR_STYLE]:
		QuizTheme.apply_skin_from_settings()


func snap_font_size(size: int) -> int:
	return QuizTheme.snap(size)


func get_ui_skins() -> Array[Dictionary]:
	return QuizTheme.SKINS


func get_ui_options() -> Array[Dictionary]:
	return QuizTheme.UI_OPTIONS


func get_ui_bar_styles() -> Array[Dictionary]:
	return QuizTheme.BAR_STYLES
