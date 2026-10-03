extends Node

## CheatService — Globalny serwis kodów / ułatwień dla dewelopera i testów.
## Skróty klawiszowe:
##   F9 lub K: Instant Win (natychmiastowe wygranie w walce lub rozwiązanie zagadki drzwi)
##   F10 lub O: Toggle Enemies (włączenie/wyłączenie przeciwników i pościgu na mapie)
##   F11 lub P: Toggle Quizzes (włączenie/wyłączenie quizów — auto-pass bez wyświetlania pytań)

signal enemies_toggled(disabled: bool)
signal quizzes_toggled(quizless: bool)
signal instant_win_triggered
signal god_mode_toggled(enabled: bool)
signal speed_mult_changed(mult: float)
signal quiz_ui_mode_changed(mode: String)

var enemies_disabled: bool = false
var god_mode: bool = false
var player_speed_mult: float = 1.0
var active_quiz_override: String = ""
var quiz_ui_mode: String = "bottom" # "bottom" (100% full-width bar) lub "popup" (modal w centrum)

var _toast_layer: CanvasLayer
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _dev_menu: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_toast_ui()
	_setup_dev_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	# F1 lub tylda (~): Przełącz Menu Deweloperskie
	if key_event.keycode == KEY_F1 or key_event.keycode == KEY_QUOTELEFT:
		toggle_dev_menu()
		get_viewport().set_input_as_handled()
		return

	# Nie przejmuj pojedynczych liter jeśli gracz wpisuje tekst w polu edycji
	var focus_owner := get_viewport().gui_get_focus_owner()
	var is_typing := focus_owner is LineEdit or focus_owner is TextEdit

	# F9 lub K: Natychmiastowe zwycięstwo
	if key_event.keycode == KEY_F9 or (not is_typing and key_event.keycode == KEY_K):
		trigger_instant_win()
		get_viewport().set_input_as_handled()
		return

	# F10 lub O: Włącz/Wyłącz wrogów
	if key_event.keycode == KEY_F10 or (not is_typing and key_event.keycode == KEY_O):
		toggle_enemies()
		get_viewport().set_input_as_handled()
		return

	# F11 lub P: Włącz/Wyłącz quizy
	if key_event.keycode == KEY_F11 or (not is_typing and key_event.keycode == KEY_P):
		toggle_quizzes()
		get_viewport().set_input_as_handled()
		return


func toggle_dev_menu() -> void:
	if _dev_menu and _dev_menu.has_method("toggle"):
		_dev_menu.call("toggle")


func set_god_mode(enabled: bool) -> void:
	god_mode = enabled
	god_mode_toggled.emit(god_mode)
	if god_mode:
		show_toast("🛡️ CHEAT: God Mode WŁĄCZONY (Brak obrażeń)", Color(1.0, 0.9, 0.3))
	else:
		show_toast("🛡️ CHEAT: God Mode WYŁĄCZONY", Color(0.7, 0.7, 0.7))


func set_speed_mult(mult: float) -> void:
	player_speed_mult = maxf(0.2, mult)
	speed_mult_changed.emit(player_speed_mult)
	show_toast("👟 CHEAT: Prędkość gracza: %.1fx" % player_speed_mult, Color(0.4, 0.8, 1.0))


func _setup_dev_menu() -> void:
	var DevMenuScript = preload("res://_host/autoloads/services/dev_menu.gd")
	_dev_menu = DevMenuScript.new()
	add_child(_dev_menu)


func toggle_enemies() -> bool:
	enemies_disabled = not enemies_disabled
	enemies_toggled.emit(enemies_disabled)
	if enemies_disabled:
		show_toast("🛑 CHEAT: Przeciwnicy WYŁĄCZENI (Brak agresji/walk)", Color(1.0, 0.45, 0.45))
	else:
		show_toast("⚔️ CHEAT: Przeciwnicy WŁĄCZENI (Normalny tryb)", Color(0.45, 1.0, 0.45))
	return enemies_disabled


func toggle_quizzes() -> bool:
	var settings_service := get_node_or_null("/root/SettingsService")
	var is_quizless := false
	if settings_service and settings_service.has_method("is_quizless_mode_enabled"):
		is_quizless = bool(settings_service.call("is_quizless_mode_enabled"))
	var new_quizless := not is_quizless
	if settings_service and settings_service.has_method("set_quizless_mode_enabled"):
		settings_service.call("set_quizless_mode_enabled", new_quizless)
	quizzes_toggled.emit(new_quizless)
	if new_quizless:
		show_toast("⚡ CHEAT: Quizy WYŁĄCZONE (Auto-pass bez pytań)", Color(1.0, 0.85, 0.3))
	else:
		show_toast("📖 CHEAT: Quizy WŁĄCZONE (Pytania aktywne)", Color(0.4, 0.85, 1.0))
	return new_quizless


func trigger_instant_win() -> void:
	instant_win_triggered.emit()
	show_toast("🏆 CHEAT: Natychmiastowe Zwycięstwo (Instant Win)!", Color(1.0, 0.95, 0.2))


func set_quiz_ui_mode(mode: String) -> void:
	quiz_ui_mode = mode
	quiz_ui_mode_changed.emit(quiz_ui_mode)
	if mode == "popup":
		show_toast("🖼️ Układ quizu: Modal / Popup w centrum", Color(0.4, 0.85, 1.0))
	else:
		show_toast("📏 Układ quizu: Dolny pasek (100% szerokości)", Color(0.4, 0.85, 1.0))


func show_toast(text: String, accent_color: Color = Color.WHITE) -> void:
	if _toast_label == null or _toast_panel == null:
		return
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", accent_color)

	var style := _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = accent_color

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0

	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func():
		if is_instance_valid(_toast_panel):
			_toast_panel.visible = false
	)


func _setup_toast_ui() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "CheatToastLayer"
	_toast_layer.layer = 120
	add_child(_toast_layer)

	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_color = Color(1.0, 0.8, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_toast_panel.add_theme_stylebox_override("panel", style)

	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_panel.add_child(_toast_label)

	# Wyśrodkowanie na górze ekranu
	_toast_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.offset_left = -260
	_toast_panel.offset_right = 260
	_toast_panel.offset_top = 24
	_toast_panel.offset_bottom = 68
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_toast_layer.add_child(_toast_panel)
