extends CanvasLayer

## DevMenu — Menu Deweloperskie / Debug Menu
## Dostępne pod F1, tyldą (~) lub przyciskiem w prawym górnym rogu ekranu.
## Własny motyw z czcionką hosta (nie dziedziczy pikselowej czcionki modułu) i rozmiary tekstu / okna
## skalowane skalą UI z opcji (UIScaleService), przeliczane po zmianie skali i rozmiaru okna.
## Rozmiary bazowe przy skali 1x (zgłoszenie usera 2026-10-04: tekst był za mały i niespójny).
const BASE_FONT_SIZE := 18
const BASE_PANEL_SIZE := Vector2(880, 600)

signal menu_visibility_changed(is_visible: bool)

var _modal_root: Control
var _backdrop_overlay: ColorRect
var _main_panel: PanelContainer
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# Przełączniki i kontrolki
var _btn_toggle_enemies: CheckButton
var _btn_toggle_quizzes: CheckButton
var _btn_toggle_god_mode: CheckButton
var _btn_instant_win: Button
var _btn_full_heal: Button
var _btn_add_xp: Button
var _btn_add_streak: Button
var _opt_speed: OptionButton
var _opt_quizzes: OptionButton
var _opt_quiz_layout: OptionButton
var _opt_items: OptionButton
var _spin_item_count: SpinBox
var _btn_equip_item: Button
var _lbl_fps: Label
var _lbl_info: Label
var _lbl_stats_details: Label

var _floating_toggle_btn: Button
var _ui_theme: Theme


func _get_service(service_name: String) -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node(service_name):
		return tree.root.get_node(service_name)
	return null


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_theme = Theme.new()
	var font_path := str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	if not font_path.is_empty() and ResourceLoader.exists(font_path):
		_ui_theme.default_font = load(font_path) as Font
	_build_floating_button()
	_build_menu_ui()
	_refresh_controls_state()
	var ui_scale := _get_service("UIScaleService")
	if ui_scale and ui_scale.has_signal("scale_changed"):
		ui_scale.scale_changed.connect(func(_s: float) -> void: _apply_scale())
	get_viewport().size_changed.connect(_apply_scale)
	_apply_scale()

	var cheat_service := _get_service("CheatService")
	if cheat_service:
		if cheat_service.has_signal("enemies_toggled"):
			cheat_service.enemies_toggled.connect(func(_val): _refresh_controls_state())
		if cheat_service.has_signal("quizzes_toggled"):
			cheat_service.quizzes_toggled.connect(func(_val): _refresh_controls_state())
		if cheat_service.has_signal("god_mode_toggled"):
			cheat_service.god_mode_toggled.connect(func(_val): _refresh_controls_state())


func _process(_delta: float) -> void:
	if _modal_root and _modal_root.visible:
		if _lbl_fps:
			_lbl_fps.text = "FPS: %d | %.1f ms" % [
				Engine.get_frames_per_second(),
				(1.0 / max(1.0, float(Engine.get_frames_per_second()))) * 1000.0
			]
		if _lbl_info or _lbl_stats_details:
			var core_mgr := _get_service("CoreManager")
			var mod_id: String = core_mgr.get_active_module_id() if core_mgr and core_mgr.has_method("get_active_module_id") else "Brak"
			var gm = core_mgr.get_singleton("GameManager") if core_mgr else null
			var state_str: String = str(gm.current_state) if gm and "current_state" in gm else "-"
			var ps = core_mgr.get_singleton("PlayerStats") if core_mgr else null
			var hp_str: String = "%d/%d" % [ps.hp, ps.max_hp] if ps and "hp" in ps and "max_hp" in ps else "-"
			var exp_str: String = str(ps.experience) if ps and "experience" in ps else (str(ps.xp) if ps and "xp" in ps else "0")
			var pts_str: String = str(ps.points) if ps and "points" in ps else "0"
			var streak_str: String = str(ps.streak) if ps and "streak" in ps else "0"

			if _lbl_info:
				_lbl_info.text = "Aktywny moduł: %s  |  Stan gry: %s  |  HP Gracza: %s" % [mod_id, state_str, hp_str]
			if _lbl_stats_details:
				_lbl_stats_details.text = "HP: %s  •  EXP: %s  •  Punkty: %s  •  Seria: %s  •  Moduł: %s" % [
					hp_str, exp_str, pts_str, streak_str, mod_id
				]


func _unhandled_input(event: InputEvent) -> void:
	if not is_menu_open():
		return
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.pressed and not key_ev.echo:
			if key_ev.keycode == KEY_ESCAPE:
				close()
				get_viewport().set_input_as_handled()


func toggle() -> void:
	if _modal_root == null or _main_panel == null:
		return
	var new_vis := not _modal_root.visible
	_modal_root.visible = new_vis
	if new_vis:
		_refresh_controls_state()
		_refresh_item_cheats()
		_center_panel()
	menu_visibility_changed.emit(new_vis)


func open() -> void:
	if _modal_root and not _modal_root.visible:
		toggle()


func close() -> void:
	if _modal_root and _modal_root.visible:
		toggle()


func is_menu_open() -> bool:
	return _modal_root != null and _modal_root.visible


## Rozmiar w px przy bieżącej skali UI (bez usługi — bez skalowania).
func _px(base: float) -> int:
	var ui_scale := _get_service("UIScaleService")
	return int(ui_scale.call("px", base)) if ui_scale else roundi(base)


## Rozmiar tekstu `base` (przy skali 1x) — zapamiętany w meta, przeliczany w _apply_scale.
func _font(control: Control, base: int) -> void:
	control.set_meta(&"dev_font", base)
	control.add_theme_font_size_override("font_size", _px(base))


func _min_height(control: Control, base: int) -> void:
	control.set_meta(&"dev_min_h", base)
	control.custom_minimum_size = Vector2(0, _px(base))


## Skala UI / rozmiar okna zmienione: tekst, wysokości przycisków i rozmiar okna.
func _apply_scale() -> void:
	if _ui_theme == null:
		return
	_ui_theme.default_font_size = _px(BASE_FONT_SIZE)
	for root_node: Node in [_modal_root, _floating_toggle_btn]:
		if root_node == null:
			continue
		for node in [root_node] + root_node.find_children("*", "Control", true, false):
			if node.has_meta(&"dev_font"):
				(node as Control).add_theme_font_size_override("font_size", _px(int(node.get_meta(&"dev_font"))))
			if node.has_meta(&"dev_min_h"):
				(node as Control).custom_minimum_size = Vector2(0, _px(int(node.get_meta(&"dev_min_h"))))
			if node is OptionButton:
				(node as OptionButton).get_popup().add_theme_font_size_override("font_size", _px(BASE_FONT_SIZE))
	if _floating_toggle_btn:
		_floating_toggle_btn.reset_size()
		_floating_toggle_btn.offset_left = -_floating_toggle_btn.get_combined_minimum_size().x - 12
	if is_menu_open():
		_center_panel()


func _center_panel() -> void:
	if _main_panel == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1920, 1080)
	var panel_w: float = minf(_px(BASE_PANEL_SIZE.x), vp_size.x - 40.0)
	var panel_h: float = minf(_px(BASE_PANEL_SIZE.y), vp_size.y - 40.0)
	_main_panel.set_anchors_preset(Control.PRESET_CENTER)
	_main_panel.offset_left = -panel_w * 0.5
	_main_panel.offset_right = panel_w * 0.5
	_main_panel.offset_top = -panel_h * 0.5
	_main_panel.offset_bottom = panel_h * 0.5
	_main_panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _refresh_controls_state() -> void:
	var cheat_service := _get_service("CheatService")
	var settings_service := _get_service("SettingsService")

	if _btn_toggle_enemies and cheat_service and "enemies_disabled" in cheat_service:
		_btn_toggle_enemies.set_pressed_no_signal(bool(cheat_service.enemies_disabled))
		_btn_toggle_enemies.text = "WYŁĄCZENI" if cheat_service.enemies_disabled else "WŁĄCZENI"

	if _btn_toggle_quizzes and settings_service and settings_service.has_method("is_quizless_mode_enabled"):
		var is_quizless: bool = settings_service.is_quizless_mode_enabled()
		_btn_toggle_quizzes.set_pressed_no_signal(is_quizless)
		_btn_toggle_quizzes.text = "WYŁĄCZONE (Auto-pass)" if is_quizless else "WŁĄCZONE"

	if _btn_toggle_god_mode and cheat_service and "god_mode" in cheat_service:
		_btn_toggle_god_mode.set_pressed_no_signal(bool(cheat_service.god_mode))
		_btn_toggle_god_mode.text = "AKTYWNY" if cheat_service.god_mode else "Wyłączony"

	if _opt_speed and cheat_service and "player_speed_mult" in cheat_service:
		var mult: float = float(cheat_service.player_speed_mult)
		if is_equal_approx(mult, 1.0): _opt_speed.selected = 0
		elif is_equal_approx(mult, 1.5): _opt_speed.selected = 1
		elif is_equal_approx(mult, 2.0): _opt_speed.selected = 2
		elif is_equal_approx(mult, 3.0): _opt_speed.selected = 3

	if _opt_quizzes and cheat_service:
		var active_quiz: String = str(cheat_service.active_quiz_override) if "active_quiz_override" in cheat_service else ""
		for i in range(_opt_quizzes.item_count):
			if _opt_quizzes.get_item_metadata(i) == active_quiz:
				_opt_quizzes.selected = i
				break

	if _opt_quiz_layout and cheat_service and "quiz_ui_mode" in cheat_service:
		_opt_quiz_layout.selected = 1 if cheat_service.quiz_ui_mode == "popup" else 0


func _build_floating_button() -> void:
	_floating_toggle_btn = Button.new()
	_floating_toggle_btn.theme = _ui_theme
	_font(_floating_toggle_btn, 16)
	_floating_toggle_btn.text = "🛠️ DEV"
	_floating_toggle_btn.tooltip_text = "Menu Deweloperskie [F1 / ~]"
	_floating_toggle_btn.focus_mode = Control.FOCUS_NONE
	_floating_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.85)
	style.border_color = Color(0.3, 0.6, 1.0, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_floating_toggle_btn.add_theme_stylebox_override("normal", style)

	_floating_toggle_btn.anchor_left = 1.0
	_floating_toggle_btn.anchor_right = 1.0
	_floating_toggle_btn.anchor_top = 0.0
	_floating_toggle_btn.anchor_bottom = 0.0
	_floating_toggle_btn.offset_left = -78
	_floating_toggle_btn.offset_right = -12
	_floating_toggle_btn.offset_top = 10
	_floating_toggle_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_floating_toggle_btn.pressed.connect(toggle)

	add_child(_floating_toggle_btn)


func _build_menu_ui() -> void:
	# Główny kontener pełnoekranowy modala
	_modal_root = Control.new()
	_modal_root.name = "DevMenuModalRoot"
	_modal_root.theme = _ui_theme
	_modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_root.visible = false
	_modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Półprzezroczysty backdrop przyciemniający resztę gry
	_backdrop_overlay = ColorRect.new()
	_backdrop_overlay.name = "Backdrop"
	_backdrop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_backdrop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	_modal_root.add_child(_backdrop_overlay)

	# Główny panel okna
	_main_panel = PanelContainer.new()
	_main_panel.name = "DevMenuPanel"
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.12, 0.97)
	panel_style.border_color = Color(0.28, 0.52, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	panel_style.shadow_color = Color(0, 0, 0, 0.65)
	panel_style.shadow_size = 16
	_main_panel.add_theme_stylebox_override("panel", panel_style)

	_center_panel()

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	_main_panel.add_child(root_vbox)

	# --- Pasek Tytułowy (Header z przeciąganiem myszą) ---
	var header_hbox := HBoxContainer.new()
	header_hbox.name = "HeaderHBox"
	header_hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	header_hbox.add_theme_constant_override("separation", 10)
	header_hbox.gui_input.connect(_on_header_gui_input)

	var icon_lbl := Label.new()
	icon_lbl.text = "🛠️"
	_font(icon_lbl, 22)
	header_hbox.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = "MENU DEWELOPERSKIE (DEV MENU)"
	_font(title_lbl, 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	header_hbox.add_child(title_lbl)

	var shortcut_badge := _create_badge("[ F1 / ~ ]", Color(0.3, 0.7, 1.0))
	header_hbox.add_child(shortcut_badge)

	_lbl_fps = Label.new()
	_lbl_fps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_fps.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	_font(_lbl_fps, 16)
	header_hbox.add_child(_lbl_fps)

	var recenter_btn := Button.new()
	recenter_btn.text = "🎯"
	recenter_btn.tooltip_text = "Wyśrodkuj okno"
	recenter_btn.focus_mode = Control.FOCUS_NONE
	recenter_btn.pressed.connect(_center_panel)
	header_hbox.add_child(recenter_btn)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.tooltip_text = "Zamknij [ESC / F1 / ~]"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	header_hbox.add_child(close_btn)

	root_vbox.add_child(header_hbox)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# --- Zakładki (TabContainer) ---
	var tab_container := TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(tab_container)

	# TAB 1: Cheaty i Opcje (2-kolumnowy dashboard)
	var tab_cheats := _build_tab_cheats()
	tab_cheats.name = "⚡ Cheaty i Opcje"
	tab_container.add_child(tab_cheats)

	# TAB 2: Baza Quizów
	var tab_quizzes := _build_tab_quizzes()
	tab_quizzes.name = "📚 Baza Quizów"
	tab_container.add_child(tab_quizzes)

	# TAB 3: Rozgrywka i Postać
	var tab_gameplay := _build_tab_gameplay()
	tab_gameplay.name = "🎮 Rozgrywka i Postać"
	tab_container.add_child(tab_gameplay)

	# --- Stopka ---
	var footer_vbox := VBoxContainer.new()
	footer_vbox.add_theme_constant_override("separation", 2)

	_lbl_info = Label.new()
	_lbl_info.text = "Ładowanie informacji o sesji..."
	_font(_lbl_info, 15)
	_lbl_info.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	footer_vbox.add_child(_lbl_info)

	var shortcuts_hint := Label.new()
	shortcuts_hint.text = "Skróty: [F1 / ~] Menu  |  [F9 / K] Instant Win  |  [F10 / O] Wrogowie  |  [F11 / P] Quizy  |  [ESC] Zamknij"
	_font(shortcuts_hint, 14)
	shortcuts_hint.add_theme_color_override("font_color", Color(0.45, 0.52, 0.65))
	footer_vbox.add_child(shortcuts_hint)

	root_vbox.add_child(footer_vbox)

	_modal_root.add_child(_main_panel)
	add_child(_modal_root)


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_drag_offset = _main_panel.global_position - mb.global_position
			else:
				_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		var new_pos: Vector2 = mm.global_position + _drag_offset
		var vp_rect := get_viewport().get_visible_rect()
		new_pos.x = clampf(new_pos.x, 10.0, maxf(10.0, vp_rect.size.x - _main_panel.size.x - 10.0))
		new_pos.y = clampf(new_pos.y, 10.0, maxf(10.0, vp_rect.size.y - _main_panel.size.y - 10.0))
		_main_panel.global_position = new_pos


func _build_tab_cheats() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	# 2-kolumnowa siatka dashboardu
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	margin.add_child(grid)

	# --- KOLUMNA LEWA: Eksploracja i Walka ---
	# 1. Przełącznik wrogów
	var enemy_box := _create_card_container("🛑 Przeciwnicy na mapie", "[ F10 / O ]", "Wyłącza pościg, agresję i inicjowanie starć przez wrogów na mapie.")
	_btn_toggle_enemies = CheckButton.new()
	_btn_toggle_enemies.text = "WŁĄCZENI"
	_btn_toggle_enemies.focus_mode = Control.FOCUS_NONE
	_btn_toggle_enemies.toggled.connect(func(_pressed):
		var cheat_service := _get_service("CheatService")
		if cheat_service and cheat_service.has_method("toggle_enemies"):
			cheat_service.toggle_enemies()
	)
	_get_card_content(enemy_box).add_child(_btn_toggle_enemies)
	grid.add_child(enemy_box)

	# 2. Przełącznik quizów
	var quiz_box := _create_card_container("⚡ Pytania i Quizy", "[ F11 / P ]", "W trybie wyłączonym pytania są pomijane i automatycznie zaliczane bez czekania.")
	_btn_toggle_quizzes = CheckButton.new()
	_btn_toggle_quizzes.text = "WŁĄCZONE"
	_btn_toggle_quizzes.focus_mode = Control.FOCUS_NONE
	_btn_toggle_quizzes.toggled.connect(func(_pressed):
		var cheat_service := _get_service("CheatService")
		if cheat_service and cheat_service.has_method("toggle_quizzes"):
			cheat_service.toggle_quizzes()
	)
	_get_card_content(quiz_box).add_child(_btn_toggle_quizzes)
	grid.add_child(quiz_box)

	# 3. God Mode
	var god_box := _create_card_container("🛡️ God Mode (Nieśmiertelność)", "[ GOD ]", "Bohater nie otrzymuje żadnych obrażeń od przeciwników ani pułapek.")
	_btn_toggle_god_mode = CheckButton.new()
	_btn_toggle_god_mode.text = "Wyłączony"
	_btn_toggle_god_mode.focus_mode = Control.FOCUS_NONE
	_btn_toggle_god_mode.toggled.connect(func(pressed):
		var cheat_service := _get_service("CheatService")
		if cheat_service and cheat_service.has_method("set_god_mode"):
			cheat_service.set_god_mode(pressed)
	)
	_get_card_content(god_box).add_child(_btn_toggle_god_mode)
	grid.add_child(god_box)

	# 4. Instant Win
	var win_box := _create_card_container("🏆 Natychmiastowe Zwycięstwo", "[ F9 / K ]", "W walce natychmiast zadaje 9999 pkt obrażeń wrogom. Przy drzwiach od razu je otwiera.")
	_btn_instant_win = Button.new()
	_btn_instant_win.text = "🏆 Aktywuj Natychmiastowe Zwycięstwo"
	_btn_instant_win.focus_mode = Control.FOCUS_NONE
	_min_height(_btn_instant_win, 36)
	_btn_instant_win.pressed.connect(func():
		var cheat_service := _get_service("CheatService")
		if cheat_service and cheat_service.has_method("trigger_instant_win"):
			cheat_service.trigger_instant_win()
	)
	_get_card_content(win_box).add_child(_btn_instant_win)
	grid.add_child(win_box)

	# 5. Prędkość poruszania się
	var speed_box := _create_card_container("👟 Prędkość poruszania się", "[ SPEED ]", "Mnożnik tempa chodu i biegu gracza po świecie.")
	_opt_speed = OptionButton.new()
	_opt_speed.add_item("1.0x (Normalna)", 0)
	_opt_speed.add_item("1.5x (Szybki chód)", 1)
	_opt_speed.add_item("2.0x (Sprint)", 2)
	_opt_speed.add_item("3.0x (Super prędkość)", 3)
	_opt_speed.focus_mode = Control.FOCUS_NONE
	_opt_speed.item_selected.connect(func(idx):
		var mult := 1.0
		match idx:
			0: mult = 1.0
			1: mult = 1.5
			2: mult = 2.0
			3: mult = 3.0
		var cheat_service := _get_service("CheatService")
		if cheat_service and cheat_service.has_method("set_speed_mult"):
			cheat_service.set_speed_mult(mult)
	)
	_get_card_content(speed_box).add_child(_opt_speed)
	grid.add_child(speed_box)

	# 6. Układ UI Quizu w walce
	var layout_box := _create_card_container("📏 Styl Wyświetlania Quizu w Walce", "[ UI ]", "Wybierz sposób prezentacji pytań podczas starcia RPG.")
	_opt_quiz_layout = OptionButton.new()
	_opt_quiz_layout.add_item("📏 Dolny pasek (100% szerokości, styl RPG)", 0)
	_opt_quiz_layout.set_item_metadata(0, "bottom")
	_opt_quiz_layout.add_item("🖼️ Modal / Popup w centrum ekranu", 1)
	_opt_quiz_layout.set_item_metadata(1, "popup")
	_opt_quiz_layout.focus_mode = Control.FOCUS_NONE
	var cs_layout := _get_service("CheatService")
	if cs_layout and "quiz_ui_mode" in cs_layout:
		_opt_quiz_layout.selected = 1 if cs_layout.quiz_ui_mode == "popup" else 0
	_opt_quiz_layout.item_selected.connect(func(idx):
		var mode: String = str(_opt_quiz_layout.get_item_metadata(idx))
		var cs := _get_service("CheatService")
		if cs and cs.has_method("set_quiz_ui_mode"):
			cs.set_quiz_ui_mode(mode)
	)
	_get_card_content(layout_box).add_child(_opt_quiz_layout)
	grid.add_child(layout_box)

	return scroll


func _build_tab_quizzes() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	scroll.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)

	# 1. Wybór zestawu pytań
	var quiz_select_box := _create_card_container("Aktywny Zestaw Pytań", "[ ROOT ]", "Wybierz bazę pytań pobieraną bezpośrednio z res://_host/resources/quizzes/.")
	var select_content: VBoxContainer = _get_card_content(quiz_select_box)

	_opt_quizzes = OptionButton.new()
	_opt_quizzes.add_item("Domyślny (inf_podst - Podstawowy)", 0)
	_opt_quizzes.set_item_metadata(0, "inf_podst")
	_opt_quizzes.add_item("Zaawansowany (informatyka - 100 pytań)", 1)
	_opt_quizzes.set_item_metadata(1, "informatyka")
	_opt_quizzes.focus_mode = Control.FOCUS_NONE
	_opt_quizzes.item_selected.connect(func(idx):
		var chosen_id: String = str(_opt_quizzes.get_item_metadata(idx))
		var cheat_service = _get_service("CheatService")
		if cheat_service:
			cheat_service.active_quiz_override = chosen_id
			cheat_service.show_toast("📚 Zmieniono aktywny quiz na: %s" % chosen_id, Color(0.4, 0.8, 1.0))
	)
	select_content.add_child(_opt_quizzes)

	var reload_btn := Button.new()
	reload_btn.text = "🔄 Przeładuj pliki JSON z dysku"
	reload_btn.focus_mode = Control.FOCUS_NONE
	reload_btn.pressed.connect(func():
		var quiz_service = _get_service("QuizService")
		if quiz_service:
			quiz_service.reload_module("quiz_rpg")
			quiz_service.reload_module("global")
			quiz_service.reload_module("")
		var cheat_service = _get_service("CheatService")
		if cheat_service:
			cheat_service.show_toast("✅ Przeładowano pliki quizów z res://_host/resources/quizzes!", Color(0.4, 1.0, 0.5))
	)
	select_content.add_child(reload_btn)
	grid.add_child(quiz_select_box)

	# 2. Status i ścieżki plików quizów
	var paths_box := _create_card_container("Wykryte Pliki Bazy Pytań", "[ STATUS ]", "Stan plików w katalogu res://_host/resources/quizzes/:")
	var paths_content: VBoxContainer = _get_card_content(paths_box)

	var lbl_files := Label.new()
	var f1_ok: bool = FileAccess.file_exists("res://_host/resources/quizzes/inf_podst.json")
	var f2_ok: bool = FileAccess.file_exists("res://_host/resources/quizzes/informatyka.json")
	lbl_files.text = "• inf_podst.json: %s\n• informatyka.json: %s" % [
		"✅ Dostępny" if f1_ok else "❌ Brak",
		"✅ Dostępny" if f2_ok else "❌ Brak"
	]
	_font(lbl_files, 16)
	lbl_files.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95))
	paths_content.add_child(lbl_files)
	grid.add_child(paths_box)

	# 3. Test losowego pytania
	var test_box := _create_card_container("Test Losowania Pytania", "[ TEST ]", "Pobiera losowe pytanie z aktualnej bazy i wyświetla podgląd w powiadomieniu.")
	var test_content: VBoxContainer = _get_card_content(test_box)
	var btn_test_q := Button.new()
	btn_test_q.text = "🎲 Wylosuj i Przetestuj Pytanie"
	btn_test_q.focus_mode = Control.FOCUS_NONE
	btn_test_q.pressed.connect(func():
		var qm = _get_service("QuizManager")
		var cs = _get_service("CheatService")
		if qm and qm.has_method("get_random_question"):
			var q = qm.get_random_question()
			if cs:
				cs.show_toast("🎲 Pytanie [%s]: %s" % [q.get("type", "mc"), q.get("question", "Brak")], Color(0.4, 0.9, 1.0))
	)
	test_content.add_child(btn_test_q)
	vbox.add_child(test_box)

	return scroll


func _build_tab_gameplay() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	scroll.add_child(margin)

	# 1. Podgląd parametrów na żywo
	var info_card := _create_card_container("Parametry Postaci Na Żywo", "[ LIVE ]", "Bieżące statystyki pobierane z PlayerStats i GameManager:")
	var info_content: VBoxContainer = _get_card_content(info_card)
	_lbl_stats_details = Label.new()
	_lbl_stats_details.text = "Ładowanie..."
	_font(_lbl_stats_details, 16)
	_lbl_stats_details.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	info_content.add_child(_lbl_stats_details)
	vbox.add_child(info_card)

	# 2. Szybkie modyfikatory statystyk (Siatka 2x2 przycisków)
	var party_box := _create_card_container("Szybkie Modyfikatory Drużyny", "[ CHEAT ]", "Natychmiastowe operacje na statystykach drużyny.")
	var party_content: VBoxContainer = _get_card_content(party_box)

	var party_grid := GridContainer.new()
	party_grid.columns = 2
	party_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_grid.add_theme_constant_override("h_separation", 10)
	party_grid.add_theme_constant_override("v_separation", 10)

	_btn_full_heal = Button.new()
	_btn_full_heal.text = "❤️ Pełne Uleczenie (100% HP)"
	_btn_full_heal.focus_mode = Control.FOCUS_NONE
	_min_height(_btn_full_heal, 36)
	_btn_full_heal.pressed.connect(func():
		var core_mgr = _get_service("CoreManager")
		var ps = core_mgr.get_singleton("PlayerStats") if core_mgr else null
		if ps and ps.has_method("heal"):
			ps.call("heal", 9999)
		var cheat_service = _get_service("CheatService")
		if cheat_service:
			cheat_service.show_toast("❤️ Drużyna została w pełni uleczona!", Color(0.4, 1.0, 0.4))
	)
	party_grid.add_child(_btn_full_heal)

	_btn_add_xp = Button.new()
	_btn_add_xp.text = "⭐ Dodaj +100 EXP"
	_btn_add_xp.focus_mode = Control.FOCUS_NONE
	_min_height(_btn_add_xp, 36)
	_btn_add_xp.pressed.connect(func():
		var core_mgr = _get_service("CoreManager")
		var ps = core_mgr.get_singleton("PlayerStats") if core_mgr else null
		if ps and ps.has_method("add_xp"):
			ps.call("add_xp", 100)
		var cheat_service = _get_service("CheatService")
		if cheat_service:
			cheat_service.show_toast("⭐ Dodano +100 EXP!", Color(1.0, 0.85, 0.2))
	)
	party_grid.add_child(_btn_add_xp)

	_btn_add_streak = Button.new()
	_btn_add_streak.text = "🔥 Seria Odpowiedzi (+10)"
	_btn_add_streak.focus_mode = Control.FOCUS_NONE
	_min_height(_btn_add_streak, 36)
	_btn_add_streak.pressed.connect(func():
		var core_mgr = _get_service("CoreManager")
		var ps = core_mgr.get_singleton("PlayerStats") if core_mgr else null
		if ps and "streak" in ps:
			ps.streak += 10
			if ps.has_signal("points_changed"):
				ps.points_changed.emit(ps.points)
		var cheat_service = _get_service("CheatService")
		if cheat_service:
			cheat_service.show_toast("🔥 Zwiększono serię odpowiedzi o +10!", Color(1.0, 0.5, 0.2))
	)
	party_grid.add_child(_btn_add_streak)

	var btn_add_coins := Button.new()
	btn_add_coins.text = "💰 Dodaj 100 Punktów"
	btn_add_coins.focus_mode = Control.FOCUS_NONE
	_min_height(btn_add_coins, 36)
	btn_add_coins.pressed.connect(func():
		var core_mgr = _get_service("CoreManager")
		var ps = core_mgr.get_singleton("PlayerStats") if core_mgr else null
		if ps and "points" in ps:
			ps.points += 100
			if ps.has_signal("points_changed"):
				ps.points_changed.emit(ps.points)
		var cheat_service = _get_service("CheatService")
		if cheat_service:
			cheat_service.show_toast("💰 Dodano +100 Punktów!", Color(1.0, 0.9, 0.3))
	)
	party_grid.add_child(btn_add_coins)

	party_content.add_child(party_grid)
	vbox.add_child(party_box)

	vbox.add_child(_build_item_cheats())

	return scroll


## Dowolny przedmiot / ekwipunek z katalogu modułu (InventoryService.get_all_items): dodanie do plecaka
## albo od razu założenie bohaterowi (PlayerStats.set_member_equipment, członek 0).
func _build_item_cheats() -> PanelContainer:
	var box := _create_card_container("Przedmioty i ekwipunek", "[ ITEM ]", "Dowolny przedmiot z katalogu: dodaj do plecaka albo załóż bohaterowi (ekwipunek).")
	var content: VBoxContainer = _get_card_content(box)
	_opt_items = OptionButton.new()
	_opt_items.focus_mode = Control.FOCUS_NONE
	_opt_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opt_items.item_selected.connect(func(_idx): _update_item_cheat_buttons())
	content.add_child(_opt_items)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_spin_item_count = SpinBox.new()
	_spin_item_count.min_value = 1
	_spin_item_count.max_value = 99
	_spin_item_count.value = 1
	_spin_item_count.prefix = "×"
	row.add_child(_spin_item_count)
	var add_btn := Button.new()
	add_btn.text = "➕ Dodaj do plecaka"
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_min_height(add_btn, 36)
	add_btn.pressed.connect(_on_cheat_add_item)
	row.add_child(add_btn)
	_btn_equip_item = Button.new()
	_btn_equip_item.text = "🛡️ Załóż bohaterowi"
	_btn_equip_item.focus_mode = Control.FOCUS_NONE
	_btn_equip_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_min_height(_btn_equip_item, 36)
	_btn_equip_item.pressed.connect(_on_cheat_equip_item)
	row.add_child(_btn_equip_item)
	content.add_child(row)
	return box


func _module_singleton(singleton_name: String) -> Node:
	var core_mgr = _get_service("CoreManager")
	var node: Variant = core_mgr.get_singleton(singleton_name) if core_mgr and core_mgr.has_method("get_singleton") else null
	return node as Node


## Lista przedmiotów odświeżana przy otwarciu menu (katalog ładuje moduł, nie host).
func _refresh_item_cheats() -> void:
	if _opt_items == null:
		return
	var prev: String = str(_opt_items.get_item_metadata(_opt_items.selected)) if _opt_items.selected >= 0 else ""
	_opt_items.clear()
	var inv := _module_singleton("InventoryService")
	if inv == null or not inv.has_method("get_all_items"):
		_opt_items.add_item("(brak katalogu przedmiotów — moduł nieaktywny)")
		_opt_items.disabled = true
		_update_item_cheat_buttons()
		return
	_opt_items.disabled = false
	for item in inv.get_all_items():
		var kind: String = str(item.equip_slot) if str(item.equip_slot) != "" else str(item.category)
		_opt_items.add_item("%s  [%s]" % [item.display_name, kind])
		_opt_items.set_item_metadata(_opt_items.item_count - 1, item.item_id)
		if item.item_id == prev:
			_opt_items.selected = _opt_items.item_count - 1
	_update_item_cheat_buttons()


func _selected_cheat_item() -> Resource:
	if _opt_items == null or _opt_items.disabled or _opt_items.selected < 0:
		return null
	var inv := _module_singleton("InventoryService")
	return inv.get_item(str(_opt_items.get_item_metadata(_opt_items.selected))) if inv else null


func _update_item_cheat_buttons() -> void:
	if _btn_equip_item == null:
		return
	var item := _selected_cheat_item()
	_btn_equip_item.disabled = item == null or str(item.get("equip_slot")) == ""


func _on_cheat_add_item() -> void:
	var item := _selected_cheat_item()
	var ps := _module_singleton("PlayerStats")
	if item == null or ps == null or not ps.has_method("add_item"):
		return
	var count := int(_spin_item_count.value)
	ps.add_item(str(item.get("item_id")), count)
	var cheat_service = _get_service("CheatService")
	if cheat_service:
		cheat_service.show_toast("➕ Dodano: %s ×%d" % [item.get("display_name"), count], Color(0.5, 0.9, 1.0))


func _on_cheat_equip_item() -> void:
	var item := _selected_cheat_item()
	var ps := _module_singleton("PlayerStats")
	if item == null or ps == null or not ps.has_method("set_member_equipment"):
		return
	var item_id := str(item.get("item_id"))
	ps.add_item(item_id, 1)
	var ok: bool = ps.set_member_equipment(0, str(item.get("equip_slot")), item_id)
	var cheat_service = _get_service("CheatService")
	if cheat_service:
		if ok:
			cheat_service.show_toast("🛡️ Założono: %s" % item.get("display_name"), Color(0.5, 1.0, 0.6))
		else:
			cheat_service.show_toast("Nie udało się założyć: %s" % item.get("display_name"), Color(1.0, 0.5, 0.4))


func _create_card_container(title: String, badge: String, description: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.18, 0.92)
	style.border_color = Color(0.24, 0.3, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var root_box := VBoxContainer.new()
	root_box.name = "RootVBox"
	root_box.add_theme_constant_override("separation", 6)
	panel.add_child(root_box)

	# Wiersz nagłówka karty (Tytuł + Badge)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)

	var lbl_title := Label.new()
	lbl_title.text = title
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font(lbl_title, 18)
	lbl_title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	header_row.add_child(lbl_title)

	if badge != "":
		header_row.add_child(_create_badge(badge, Color(0.35, 0.65, 0.95)))

	root_box.add_child(header_row)

	if description != "":
		var lbl_desc := Label.new()
		lbl_desc.text = description
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_font(lbl_desc, 15)
		lbl_desc.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
		root_box.add_child(lbl_desc)

	# Kontener na interaktywne kontrolki (przyciski, checkboxy, opcje)
	var content_box := VBoxContainer.new()
	content_box.name = "Content"
	content_box.add_theme_constant_override("separation", 6)
	root_box.add_child(content_box)
	panel.set_meta("content_box", content_box)

	return panel


func _get_card_content(panel: PanelContainer) -> VBoxContainer:
	if panel and panel.has_meta("content_box"):
		return panel.get_meta("content_box") as VBoxContainer
	if panel:
		var found = panel.find_child("Content", true, false)
		if found is VBoxContainer:
			return found as VBoxContainer
	return null


func _create_badge(text: String, color: Color) -> PanelContainer:
	var badge_panel := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.85)
	b_style.border_color = color
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(4)
	b_style.content_margin_left = 6
	b_style.content_margin_right = 6
	b_style.content_margin_top = 2
	b_style.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", b_style)

	var lbl := Label.new()
	lbl.text = text
	_font(lbl, 14)
	lbl.add_theme_color_override("font_color", color.lightened(0.3))
	badge_panel.add_child(lbl)

	return badge_panel
