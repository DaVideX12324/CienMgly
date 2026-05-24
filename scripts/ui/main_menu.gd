extends CanvasLayer

## Main menu for res://modules/quiz_rpg/scenes/ui/main_menu.tscn.

@onready var new_game_btn: Button = $Center/Panel/Margin/VBox/BtnNewGame
@onready var load_game_btn: Button = $Center/Panel/Margin/VBox/BtnLoadGame
@onready var stats_btn: Button = $Center/Panel/Margin/VBox/BtnStats
@onready var quit_btn: Button = $Center/Panel/Margin/VBox/BtnQuit
@onready var close_stats_btn: Button = $StatsPanel/StatsMargin/StatsVBox/BtnCloseStats
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var stats_label: Label = $StatsPanel/StatsMargin/StatsVBox/StatsLabel
@onready var stats_panel: PanelContainer = $StatsPanel
@onready var background: ColorRect = $BG

var _title_time := 0.0
var _save_slots_panel: PanelContainer
var _save_slots_title: Label
var _save_slots_list: VBoxContainer
var _save_slots_back_btn: Button
var _slot_mode: String = "load"
const MAX_MENU_SAVE_SLOTS := 20


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_buttons()
	_build_save_slots_panel()
	_update_load_button()
	_style_menu()
	stats_panel.visible = false


func _process(delta: float) -> void:
	_title_time += delta
	var scale_factor := 1.0 + sin(_title_time * 1.5) * 0.02
	title_label.scale = Vector2(scale_factor, scale_factor)


func _connect_buttons() -> void:
	if not new_game_btn.pressed.is_connected(_on_new_game):
		new_game_btn.pressed.connect(_on_new_game)
	if not load_game_btn.pressed.is_connected(_on_load_game):
		load_game_btn.pressed.connect(_on_load_game)
	if not stats_btn.pressed.is_connected(_on_stats):
		stats_btn.pressed.connect(_on_stats)
	if not quit_btn.pressed.is_connected(_on_quit):
		quit_btn.pressed.connect(_on_quit)
	if not close_stats_btn.pressed.is_connected(_on_close_stats):
		close_stats_btn.pressed.connect(_on_close_stats)
	var save_manager := _get_module_singleton("SaveManager")
	if save_manager and save_manager.has_signal("save_slots_changed"):
		var slots_changed_callable := Callable(self, "_on_save_slots_changed")
		if not save_manager.is_connected("save_slots_changed", slots_changed_callable):
			save_manager.connect("save_slots_changed", slots_changed_callable)


func _update_load_button() -> void:
	var save_manager := _get_save_manager()
	load_game_btn.disabled = not bool(save_manager.call("has_any_save")) if save_manager and save_manager.has_method("has_any_save") else true


func _style_menu() -> void:
	title_label.pivot_offset = title_label.size / 2.0


func _on_new_game() -> void:
	var save_manager := _get_save_manager()
	if save_manager and save_manager.has_method("start_new_game"):
		save_manager.call("start_new_game")
		return
	var gm := _get_module_singleton("GameManager")
	if gm and gm.has_method("new_game"):
		gm.call("new_game")
	else:
		push_warning("MainMenu: GameManager unavailable, cannot start new game.")


func _on_load_game() -> void:
	_slot_mode = "load"
	_show_save_slots("WCZYTAJ GRE")


func _on_stats() -> void:
	stats_panel.visible = not stats_panel.visible
	if stats_panel.visible:
		_populate_stats()


func _on_close_stats() -> void:
	stats_panel.visible = false


func _build_save_slots_panel() -> void:
	if _save_slots_panel:
		return

	_save_slots_panel = PanelContainer.new()
	_save_slots_panel.name = "SaveSlotsPanel"
	_save_slots_panel.visible = false
	_save_slots_panel.custom_minimum_size = Vector2(620, 640)
	_save_slots_panel.theme_type_variation = "PanelContainer"
	_save_slots_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.07, 0.07, 0.11, 0.98), Color(0.35, 0.35, 0.48, 1.0)))
	$Center.add_child(_save_slots_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	_save_slots_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_save_slots_title = Label.new()
	_save_slots_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_slots_title.add_theme_font_size_override("font_size", 26)
	_save_slots_title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5, 1))
	vbox.add_child(_save_slots_title)

	var hint := Label.new()
	hint.text = "Sloty dzialaja jak w Amon-Ra: wybierz zapis, pusty slot albo dodaj kolejny."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.68, 0.68, 0.76, 1))
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_save_slots_list = VBoxContainer.new()
	_save_slots_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_save_slots_list)

	_save_slots_back_btn = Button.new()
	_save_slots_back_btn.text = "Powrot"
	_save_slots_back_btn.custom_minimum_size = Vector2(180, 40)
	_save_slots_back_btn.pressed.connect(_hide_save_slots)
	vbox.add_child(_save_slots_back_btn)


func _show_save_slots(title: String) -> void:
	_save_slots_title.text = title
	$Center/Panel.visible = false
	_save_slots_panel.visible = true
	_populate_save_slots()


func _hide_save_slots() -> void:
	_save_slots_panel.visible = false
	$Center/Panel.visible = true
	_update_load_button()


func _populate_save_slots() -> void:
	if not _save_slots_list:
		return
	for child in _save_slots_list.get_children():
		child.queue_free()

	var save_manager := _get_save_manager()
	if save_manager == null:
		_add_message_row("SaveManager niedostepny.")
		return

	var summaries_value: Variant = save_manager.call("get_save_slots_summary")
	var summaries: Array = summaries_value if summaries_value is Array else []
	for summary_value: Variant in summaries:
		if summary_value is Dictionary:
			_save_slots_list.add_child(_create_slot_row(summary_value))

	if int(save_manager.call("get_slot_count")) < MAX_MENU_SAVE_SLOTS:
		var add_btn := Button.new()
		add_btn.text = "+ Dodaj slot"
		add_btn.custom_minimum_size = Vector2(560, 42)
		add_btn.pressed.connect(_on_add_slot_pressed)
		_save_slots_list.add_child(add_btn)


func _create_slot_row(slot_summary: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 118)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.12, 0.18, 0.95), Color(0.42, 0.42, 0.58, 1.0)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)

	var title := Label.new()
	title.text = "%s - %s" % [str(slot_summary.get("slot_name", "Slot")), str(slot_summary.get("title", ""))]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1))
	text_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = str(slot_summary.get("subtitle", ""))
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.72, 0.8, 1))
	text_box.add_child(subtitle)

	var detail := Label.new()
	detail.text = str(slot_summary.get("detail", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", Color(0.58, 0.58, 0.66, 1))
	text_box.add_child(detail)

	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(130, 0)
	buttons.add_theme_constant_override("separation", 6)
	row.add_child(buttons)

	var slot_index := int(slot_summary.get("slot_index", 0))
	var exists := bool(slot_summary.get("exists", false))
	var action_btn := Button.new()
	action_btn.text = "Wczytaj"
	action_btn.disabled = _slot_mode == "load" and not exists
	action_btn.pressed.connect(func() -> void: _on_slot_action_pressed(slot_index))
	buttons.add_child(action_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Usun"
	delete_btn.disabled = not exists
	delete_btn.pressed.connect(func() -> void: _on_delete_slot_pressed(slot_index))
	buttons.add_child(delete_btn)

	return panel


func _add_message_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_slots_list.add_child(label)


func _on_slot_action_pressed(slot_index: int) -> void:
	var save_manager := _get_save_manager()
	if save_manager == null:
		return
	if not bool(save_manager.call("load_game", slot_index)):
		push_warning("Nie udalo sie wczytac zapisu ze slotu %d." % (slot_index + 1))


func _on_delete_slot_pressed(slot_index: int) -> void:
	var save_manager := _get_save_manager()
	if save_manager and bool(save_manager.call("delete_save_slot", slot_index)):
		_populate_save_slots()
		_update_load_button()


func _on_add_slot_pressed() -> void:
	var save_manager := _get_save_manager()
	if save_manager:
		save_manager.call("add_save_slot")
		_populate_save_slots()


func _on_save_slots_changed() -> void:
	_update_load_button()
	if _save_slots_panel and _save_slots_panel.visible:
		_populate_save_slots()


func _make_panel_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _populate_stats() -> void:
	var ps := _get_module_singleton("PlayerStats")
	if not ps:
		stats_label.text = "Brak statystyk"
		return

	stats_label.text = """Statystyki gracza:
Poziom: %d
XP: %d / %d
HP: %d / %d
Punkty: %d
Poprawne: %d
Bledne: %d
Najlepsza seria: %d
Nagrody: %d
Trafnosc: %.0f%%""" % [
		ps.level,
		ps.xp, ps.xp_to_next_level(),
		ps.hp, ps.max_hp,
		ps.points,
		ps.total_correct,
		ps.total_wrong,
		ps.best_streak,
		ps.rewards.size(),
		QuizManager.get_overall_accuracy() * 100,
	]


func _on_quit() -> void:
	if CoreManager.get_active_module_id() != "":
		CoreManager.exit_active_module()
		return
	get_tree().quit()


func _get_module_singleton(singleton_name: String) -> Node:
	var singleton := CoreManager.get_singleton(singleton_name)
	if singleton:
		return singleton

	var module_root := CoreManager.get_active_module()
	if module_root:
		singleton = module_root.get_node_or_null(singleton_name)
		if singleton:
			CoreManager.register_singleton(singleton_name, singleton)
			return singleton

	return null


func _get_save_manager() -> Node:
	return _get_module_singleton("SaveManager")
