extends Control

signal combat_finished(player_won: bool)

enum Phase { ACTION_SELECT, TARGET_SELECT, QUIZ, PLAYER_RESULT, ENEMY_TURN, COMBAT_END }
enum Action { ATTACK, DEFEND, HEAL, FLEE }

const QuizPanelController = preload("res://scripts/shared/quiz/quiz_panel_controller.gd")
const EnemyBattleDisplayScript: Script = preload("../enemies/enemy_battle_display.gd")

const PARTY_SKILL_SP_MAX := 100
const PARTY_TP_MAX := 100
const SKILL_SP_COST := 20
const ATTACK_HIT_CHANCE_CORRECT := 0.8
const ATTACK_HIT_CHANCE_WRONG := 0.2
const COMMAND_PANEL_WIDTH_DEFAULT := 180.0
const PARTY_PANEL_WIDTH_DEFAULT := 1080.0
const COMMAND_PANEL_WIDTH_MIN := 180.0
const PARTY_PANEL_WIDTH_MIN := 320.0
const PANEL_RESIZE_DURATION := 0
const UI_TEXT_PRIMARY := Color(0.95, 0.95, 0.98)
const UI_BORDER := Color(0.25, 0.25, 0.35)
const UI_ACCENT := Color(0.3, 0.6, 1.0)
const ENEMY_DISPLAY_SCALE_DEFAULT := Vector2(4.0, 4.0)
const ENEMY_DISPLAY_SCALE_FOCUSED := Vector2(4.4, 4.4)
const QUIZ_TYPES_STANDARD := ["multiple_choice", "true_false"]
const QUIZ_TYPES_BOSS := ["multiple_choice", "true_false", "fill_text", "fill_tiles", "matching"]

var phase: Phase = Phase.ACTION_SELECT
var chosen_action: Action = Action.ATTACK
var quiz_correct := false
var defending := false

var enemy: Node2D
var player: Node2D
var quiz_id := ""
var _diff_range := Vector2i(1, 3)
var _question_count := 1
var _encounter_size_range := Vector2i(1, 1)

var enemy_hp := 50
var enemy_max_hp := 50
var enemy_name_str := "Przeciwnik"
var enemy_base_damage := 15
var player_base_damage := 20
var turn_number := 0

@onready var content_row: HBoxContainer  = $BattleWindow/WindowMargin/VBox/ContentRow
@onready var command_panel_container: PanelContainer = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel
@onready var party_panel_container: PanelContainer = $BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel
@onready var command_vbox: VBoxContainer = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox
@onready var action_panel: VBoxContainer = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel
@onready var primary_menu: VBoxContainer = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel/PrimaryMenu
@onready var action_menu: VBoxContainer = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel/ActionMenu
@onready var result_label: Label = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ResultLabel
@onready var player_hp_bar: ProgressBar = $Battlefield/FieldContent/PlayerSection/PlayerHPBar
@onready var enemy_name_label: Label = $Battlefield/FieldContent/EnemySection/EnemyNameLabel
@onready var legacy_enemy_name_label: Label = $Battlefield/FieldContent/EnemySection/EnemyName
@onready var player_name_label: Label = $Battlefield/FieldContent/PlayerSection/PlayerName
@onready var enemy_sprite_node: Control = $Battlefield/FieldContent/EnemySection/EnemySprite
@onready var enemy_target_home_slot: Control = $Battlefield/FieldContent/EnemySection/EnemySprite/EnemyRow1/HBoxContainer/VBoxContainer/EnemySlot0
@onready var player_sprite_node: Control = $Battlefield/FieldContent/PlayerSection/PlayerSprite
@onready var battle_background: Control = $Battlefield/Background
@onready var battle_menu_overlay: Control = $Battlefield/FieldContent/BattleMenuOverlay
@onready var skills_panel: PanelContainer = $Battlefield/FieldContent/BattleMenuOverlay/SkillsPanel
@onready var skills_description_label: Label = $Battlefield/FieldContent/BattleMenuOverlay/SkillsPanel/Margin/VBox/DescriptionLabel
@onready var skills_list_vbox: VBoxContainer = $Battlefield/FieldContent/BattleMenuOverlay/SkillsPanel/Margin/VBox/ListVBox
@onready var items_panel: PanelContainer = $Battlefield/FieldContent/BattleMenuOverlay/ItemsPanel
@onready var items_description_label: Label = $Battlefield/FieldContent/BattleMenuOverlay/ItemsPanel/Margin/VBox/DescriptionLabel
@onready var items_list_vbox: VBoxContainer = $Battlefield/FieldContent/BattleMenuOverlay/ItemsPanel/Margin/VBox/ListVBox
@onready var turn_label: Label = $BattleWindow/WindowMargin/VBox/TopRow/TurnLabel
@onready var streak_label: Label = $BattleWindow/WindowMargin/VBox/TopRow/StreakLabel
@onready var target_panel: VBoxContainer = $BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel/PartyMargin/TargetPanel
@onready var target_label: Label = $BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel/PartyMargin/TargetPanel/TargetLabel
@onready var target_list_vbox: VBoxContainer = $BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel/PartyMargin/TargetPanel/TargetListVBox
@onready var party_rows : Array[HBoxContainer] = [
		$BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel/PartyMargin/PartyVBox/PartyRow0,
		$BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel/PartyMargin/PartyVBox/PartyRow1,
		$BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel/PartyMargin/PartyVBox/PartyRow2,
		$BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel/PartyMargin/PartyVBox/PartyRow3,
	]
@onready var engage_btn: Button = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel/PrimaryMenu/EngageBtn
@onready var run_btn: Button = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel/PrimaryMenu/RunBtn
@onready var atk_btn: Button = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel/ActionMenu/AtkBtn
@onready var def_btn: Button = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel/ActionMenu/DefBtn
@onready var skills_btn: Button = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel/ActionMenu/SkillsBtn
@onready var items_btn: Button = $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel/CommandMargin/CommandVBox/ActionPanel/ActionMenu/ItemsBtn

var _enemy_units: Array[Dictionary] = []
var _active_enemy_index := 0
var _bonus_xp_reward := 0
var _enemy_display_root: Node2D = null
var _enemy_display_node: Node2D = null
var _enemy_name_label: Label = null
var _enemy_displays: Array[Node2D] = []
var _enemy_active_layout_slots: Array[Dictionary] = []
var _enemy_target_cursor_node: Label = null
var _enemy_target_highlight_node: Control = null
var _action_buttons: Array[Button] = []
var _selected_action_idx: int = 0
var _victory_skip := false
var _action_menu_open := false
var _party_state: Array[Dictionary] = []
var _list_menu_mode: String = ""
var _list_menu_entries: Array[Dictionary] = []
var _list_menu_rows: Array[Control] = []
var _list_selected_idx: int = 0
var _selected_skill_data: Dictionary = {}
var _selected_item_data: Dictionary = {}
var _pending_skill_data: Dictionary = {}
var _target_entries: Array[Dictionary] = []
var _target_rows: Array[PanelContainer] = []
var _target_selected_idx: int = 0
var _hovered_enemy_slot_index: int = -1
var _ps: Node
var _dm: Node
var _gm: Node
var _quiz_panel_controller


func setup(
	p_enemy: Node2D,
	p_player: Node2D,
	p_quiz_id: String,
	diff_range: Vector2i,
	question_count: int,
	encounter_size_range: Vector2i = Vector2i(1, 1)
) -> void:
	enemy = p_enemy
	player = p_player
	quiz_id = p_quiz_id
	_diff_range = diff_range
	_question_count = question_count
	_encounter_size_range = encounter_size_range
	enemy_hp = p_enemy.hp
	enemy_max_hp = p_enemy.max_hp
	enemy_name_str = p_enemy.enemy_name
	enemy_base_damage = p_enemy.damage_on_wrong
	player_base_damage = _get_player_attack_power()
	_roll_enemy_party()
	if is_node_ready():
		_setup_enemy_display()


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	_dm = CoreManager.get_singleton("DifficultyManager")
	_gm = CoreManager.get_singleton("GameManager")

	engage_btn.pressed.connect(_on_engage_pressed)
	run_btn.pressed.connect(_on_run_pressed)
	engage_btn.mouse_entered.connect(func(): _highlight_action(0))
	run_btn.mouse_entered.connect(func(): _highlight_action(1))
	_action_buttons = [atk_btn, skills_btn, def_btn, items_btn]
	atk_btn.pressed.connect(_on_action.bind(Action.ATTACK))
	def_btn.pressed.connect(_on_action.bind(Action.DEFEND))
	skills_btn.pressed.connect(_open_skills_menu)
	items_btn.pressed.connect(_open_items_menu)
	for i in range(_action_buttons.size()):
		var action_index := i
		_action_buttons[i].mouse_entered.connect(func(): _highlight_action(action_index))

	_setup_party_layout()
	_init_party_state()
	_quiz_panel_controller = QuizPanelController.new()
	_quiz_panel_controller.setup(command_vbox)
	_quiz_panel_controller.answered.connect(_on_quiz_answered)

	if battle_background and battle_background.has_method("set_context"):
		battle_background.call("set_context", _find_current_map_node(), enemy, player, _enemy_units)
	player_name_label.text = _ps.player_name if _ps else "Bohater"
	_setup_battlefield_visuals()
	_setup_enemy_display()
	_refresh_enemy_header()
	_refresh_stats_panel()
	_update_hp_bars()
	_start_player_turn()


func _process(delta: float) -> void:
	if _quiz_panel_controller:
		_quiz_panel_controller.tick(delta)


func _input(event: InputEvent) -> void:
	if _handle_hovered_enemy_click(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.COMBAT_END and event.is_action_pressed("ui_accept"):
		_victory_skip = true
		get_viewport().set_input_as_handled()
		return
	if _list_menu_mode != "":
		if _is_menu_down(event):
			_navigate_list(1)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_up(event):
			_navigate_list(-1)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_accept(event):
			_confirm_list_selection()
			get_viewport().set_input_as_handled()
			return
		if _is_menu_cancel(event):
			_close_list_menu()
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.TARGET_SELECT:
		if _is_menu_down(event):
			_navigate_target_list(1)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_up(event):
			_navigate_target_list(-1)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_accept(event):
			_confirm_target_selection()
			get_viewport().set_input_as_handled()
			return
		if _is_menu_cancel(event):
			_cancel_target_selection()
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.ACTION_SELECT:
		var menu_count := _get_visible_action_count()
		if _is_action_menu_next(event):
			_selected_action_idx = (_selected_action_idx + 1) % menu_count
			_highlight_action(_selected_action_idx)
			get_viewport().set_input_as_handled()
			return
		if _is_action_menu_prev(event):
			_selected_action_idx = (_selected_action_idx - 1 + menu_count) % menu_count
			_highlight_action(_selected_action_idx)
			get_viewport().set_input_as_handled()
			return
		if _action_menu_open and event.is_action_pressed("ui_cancel"):
			_show_primary_menu()
			_highlight_action(0)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept"):
			if _action_menu_open:
				_get_visible_action_buttons()[_selected_action_idx].emit_signal("pressed")
			else:
				_get_visible_primary_buttons()[_selected_action_idx].emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.QUIZ and _quiz_panel_controller and _quiz_panel_controller.handle_input(event):
		get_viewport().set_input_as_handled()
		return


func _handle_hovered_enemy_click(event: InputEvent) -> bool:
	if phase != Phase.TARGET_SELECT:
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if _hovered_enemy_slot_index < 0:
		return false
	var hovered_target_index: int = _find_target_row_index_for_enemy(_hovered_enemy_slot_index)
	if hovered_target_index < 0:
		return false
	_target_selected_idx = hovered_target_index
	_refresh_target_selection()
	_confirm_target_selection()
	return true


func _start_player_turn() -> void:
	turn_number += 1
	defending = false
	_selected_skill_data.clear()
	_selected_item_data.clear()
	_pending_skill_data.clear()
	_quiz_panel_controller.reset_question()
	_set_quiz_layout_active(false)
	phase = Phase.ACTION_SELECT
	turn_label.text = "Tura %d - Twoj ruch" % turn_number
	player_base_damage = _get_player_attack_power()
	if _ps:
		streak_label.text = "Seria: %d | RNG: +%.0f%%" % [_ps.streak, _ps.rng_bonus * 100.0]
	action_panel.visible = true
	result_label.visible = false
	_refresh_enemy_header()
	_refresh_stats_panel()
	_set_action_buttons_enabled(true)
	_show_primary_menu()
	_highlight_action(0)


func _on_action(action: Action) -> void:
	if phase != Phase.ACTION_SELECT:
		return
	chosen_action = action
	if action == Action.FLEE:
		_try_flee()
		return
	if action == Action.ATTACK:
		_open_target_menu()
		return
	_begin_action_quiz()


func _open_skills_menu() -> void:
	_list_menu_mode = "skills"
	_list_menu_entries = _ps.skills.duplicate(true) if _ps and _ps.get("skills") is Array else []
	_list_selected_idx = 0
	_build_list_menu(skills_list_vbox, _list_menu_entries, true)
	skills_panel.visible = true
	items_panel.visible = false
	battle_menu_overlay.visible = true
	battle_background.visible = false
	action_panel.visible = false
	_update_list_description()


func _open_items_menu() -> void:
	_list_menu_mode = "items"
	_list_menu_entries = _ps.get_inventory_entries() if _ps and _ps.has_method("get_inventory_entries") else []
	_list_selected_idx = 0
	_build_list_menu(items_list_vbox, _list_menu_entries, false)
	items_panel.visible = true
	skills_panel.visible = false
	battle_menu_overlay.visible = true
	battle_background.visible = false
	action_panel.visible = false
	_update_list_description()


func _close_list_menu() -> void:
	_list_menu_mode = ""
	_list_menu_entries.clear()
	_list_menu_rows.clear()
	skills_panel.visible = false
	items_panel.visible = false
	battle_menu_overlay.visible = false
	battle_background.visible = true
	action_panel.visible = true
	_show_action_menu()
	_highlight_action(0)


func _open_target_menu() -> void:
	phase = Phase.TARGET_SELECT
	_hovered_enemy_slot_index = -1
	_target_entries.clear()
	_target_rows.clear()
	for child in target_list_vbox.get_children():
		child.queue_free()
	for enemy_index in range(_enemy_units.size()):
		var enemy_unit: Dictionary = _enemy_units[enemy_index]
		if int(enemy_unit.get("hp", 0)) <= 0:
			continue
		_target_entries.append({
			"enemy_index": enemy_index,
			"name": str(enemy_unit.get("name", enemy_name_str)),
			"hp": int(enemy_unit.get("hp", 0)),
			"max_hp": int(enemy_unit.get("max_hp", 1)),
		})
	_target_selected_idx = 0
	_build_target_menu()
	party_panel_container.visible = true
	_show_target_panel()


func _build_target_menu() -> void:
	target_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	target_list_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	for entry in _target_entries:
		var row: PanelContainer = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.custom_minimum_size = Vector2(0.0, _ui_scale_px(34))
		var row_margin: MarginContainer = MarginContainer.new()
		row_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_margin.mouse_filter = Control.MOUSE_FILTER_STOP
		var row_content: HBoxContainer = HBoxContainer.new()
		row_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_content.add_theme_constant_override("separation", 12)
		var name_text: Label = Label.new()
		name_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_text.text = str(entry.get("name", enemy_name_str))
		name_text.add_theme_font_size_override("font_size", _ui_scale_px(20))
		name_text.add_theme_color_override("font_color", UI_TEXT_PRIMARY)
		var hp_text: Label = Label.new()
		hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp_text.text = "%d/%d HP" % [int(entry.get("hp", 0)), int(entry.get("max_hp", 1))]
		hp_text.add_theme_font_size_override("font_size", _ui_scale_px(17))
		hp_text.add_theme_color_override("font_color", UI_TEXT_PRIMARY)
		row_content.add_child(name_text)
		row_content.add_child(hp_text)
		row_margin.add_child(row_content)
		row.add_child(row_margin)
		var row_index: int = _target_rows.size()
		row.gui_input.connect(func(event: InputEvent): _on_target_row_gui_input(event, row_index))
		row.mouse_entered.connect(func(): _on_target_row_hover(row_index))
		row_margin.gui_input.connect(func(event: InputEvent): _on_target_row_gui_input(event, row_index))
		row_margin.mouse_entered.connect(func(): _on_target_row_hover(row_index))
		target_list_vbox.add_child(row)
		_target_rows.append(row)
	_refresh_target_selection()


func _show_target_panel() -> void:
	action_panel.visible = false
	_quiz_panel_controller.hide_quiz()
	result_label.visible = false
	for row in party_rows:
		row.visible = false
	target_panel.visible = true
	target_label.text = "Wybierz cel"


func _hide_target_panel() -> void:
	target_panel.visible = false
	_hovered_enemy_slot_index = -1
	for child in target_list_vbox.get_children():
		child.queue_free()
	_target_entries.clear()
	_target_rows.clear()


func _navigate_target_list(delta: int) -> void:
	if _target_rows.is_empty():
		return
	_target_selected_idx = (_target_selected_idx + delta + _target_rows.size()) % _target_rows.size()
	_refresh_target_selection()
	_refresh_enemy_slot_highlight()


func _refresh_target_selection() -> void:
	var active_style: StyleBoxFlat = StyleBoxFlat.new()
	active_style.bg_color = Color(UI_ACCENT.r, UI_ACCENT.g, UI_ACCENT.b, 0.14)
	active_style.border_width_left = 2
	active_style.border_width_top = 2
	active_style.border_width_right = 2
	active_style.border_width_bottom = 2
	active_style.border_color = UI_ACCENT
	var inactive_style: StyleBoxFlat = StyleBoxFlat.new()
	inactive_style.bg_color = Color(1.0, 1.0, 1.0, 0.03)
	inactive_style.border_width_left = 1
	inactive_style.border_width_top = 1
	inactive_style.border_width_right = 1
	inactive_style.border_width_bottom = 1
	inactive_style.border_color = Color(UI_BORDER.r, UI_BORDER.g, UI_BORDER.b, 0.8)
	for i in range(_target_rows.size()):
		var row: PanelContainer = _target_rows[i]
		if i == _target_selected_idx:
			row.add_theme_stylebox_override("panel", active_style)
		else:
			row.add_theme_stylebox_override("panel", inactive_style)


func _on_target_row_hover(index: int) -> void:
	if index < 0 or index >= _target_rows.size():
		return
	_target_selected_idx = index
	_refresh_target_selection()
	_refresh_enemy_slot_highlight()


func _on_target_row_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseMotion:
		if index < 0 or index >= _target_rows.size():
			return
		_target_selected_idx = index
		_refresh_target_selection()
		_refresh_enemy_slot_highlight()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if index < 0 or index >= _target_rows.size():
		return
	_target_selected_idx = index
	_refresh_target_selection()
	_confirm_target_selection()


func _confirm_target_selection() -> void:
	if _target_selected_idx < 0 or _target_selected_idx >= _target_entries.size():
		return
	var entry: Dictionary = _target_entries[_target_selected_idx]
	_active_enemy_index = int(entry.get("enemy_index", 0))
	if not _pending_skill_data.is_empty():
		_selected_skill_data = _pending_skill_data.duplicate(true)
		_consume_skill_cost(_selected_skill_data)
		_pending_skill_data.clear()
	else:
		_selected_skill_data.clear()
	_hide_target_panel()
	_begin_action_quiz()


func _cancel_target_selection() -> void:
	_pending_skill_data.clear()
	_selected_skill_data.clear()
	_hide_target_panel()
	phase = Phase.ACTION_SELECT
	_refresh_stats_panel()
	action_panel.visible = true
	_show_action_menu()
	_highlight_action(0)


func _begin_action_quiz() -> void:
	_hide_target_panel()
	phase = Phase.QUIZ
	_set_action_buttons_enabled(false)
	var allowed_types: Array = _get_combat_quiz_types()
	if _should_auto_resolve_quiz(allowed_types):
		_resolve_action(true)
		return
	var q: Dictionary = QuizManager.start_quiz(quiz_id, _diff_range, 1, allowed_types)
	if q.is_empty():
		_resolve_action(true)
		return
	action_panel.visible = false
	_show_question(q)


func _get_combat_quiz_types() -> Array:
	if _is_boss_encounter():
		return QUIZ_TYPES_BOSS.duplicate()
	return QUIZ_TYPES_STANDARD.duplicate()


func _is_boss_encounter() -> bool:
	if enemy == null:
		return false
	var boss_property: Variant = enemy.get("is_boss")
	if boss_property != null:
		return bool(boss_property)
	if enemy.has_meta("is_boss"):
		return bool(enemy.get_meta("is_boss"))
	if enemy.has_method("is_boss"):
		return bool(enemy.call("is_boss"))
	return false


func _should_auto_resolve_quiz(allowed_types: Array) -> bool:
	if _is_quizless_mode_enabled():
		return true
	if quiz_id.strip_edges() == "":
		return true
	var available_questions: Array = QuizManager.get_questions(quiz_id, _diff_range, 1, allowed_types)
	return available_questions.is_empty()


func _is_quizless_mode_enabled() -> bool:
	var settings_service: Node = get_node_or_null("/root/SettingsService")
	if settings_service == null:
		return false
	if settings_service.has_method("is_quizless_mode_enabled"):
		return bool(settings_service.call("is_quizless_mode_enabled"))
	if _read_quizless_flag(settings_service, true):
		return true
	return _read_quizless_flag(settings_service, false)


func _read_quizless_flag(settings_service: Node, module_scope: bool) -> bool:
	var keys: Array[String] = ["quizless_mode", "disable_quizzes", "skip_quizzes"]
	for key_name in keys:
		var value: Variant
		if module_scope:
			value = settings_service.call("get_module", "quiz_rpg", key_name, null)
		else:
			value = settings_service.call("get_global", key_name, null)
		if value != null:
			return bool(value)
	return false


func _navigate_list(delta: int) -> void:
	if _list_menu_rows.is_empty():
		return
	var next_idx: int = _list_selected_idx
	for _step in range(_list_menu_rows.size()):
		next_idx = (next_idx + delta + _list_menu_rows.size()) % _list_menu_rows.size()
		if not _list_menu_rows[next_idx].get_meta("disabled", false):
			_list_selected_idx = next_idx
			_refresh_list_selection()
			return


func _confirm_list_selection() -> void:
	if _list_selected_idx < 0 or _list_selected_idx >= _list_menu_entries.size():
		return
	var row: Control = _list_menu_rows[_list_selected_idx]
	if row.get_meta("disabled", false):
		return
	var entry: Dictionary = _list_menu_entries[_list_selected_idx]
	if _list_menu_mode == "skills":
		_use_skill(entry)
	elif _list_menu_mode == "items":
		_use_item(entry)


func _build_list_menu(list_box: VBoxContainer, entries: Array[Dictionary], is_skill_menu: bool) -> void:
	for child in list_box.get_children():
		child.queue_free()
	_list_menu_rows.clear()
	for entry in entries:
		var row: PanelContainer = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.custom_minimum_size = Vector2(0.0, _ui_scale_px(38))
		var margin: MarginContainer = MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", _ui_scale_px(8))
		margin.add_theme_constant_override("margin_top", _ui_scale_px(6))
		margin.add_theme_constant_override("margin_right", _ui_scale_px(8))
		margin.add_theme_constant_override("margin_bottom", _ui_scale_px(6))
		var content: HBoxContainer = HBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", _ui_scale_px(12))
		var name_label: Label = Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = str(entry.get("name", "---"))
		name_label.add_theme_font_size_override("font_size", _ui_scale_px(18))
		var value_label: Label = Label.new()
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", _ui_scale_px(16))
		var disabled: bool = false
		if is_skill_menu:
			var sp_cost: int = int(entry.get("sp_cost", 0))
			var tp_cost: int = int(entry.get("tp_cost", 0))
			if sp_cost > 0:
				value_label.text = "SP %d" % sp_cost
				disabled = _party_state.is_empty() or int(_party_state[0].get("sp", 0)) < sp_cost
			elif tp_cost > 0:
				value_label.text = "TP %d" % tp_cost
				disabled = _party_state.is_empty() or int(_party_state[0].get("tp", 0)) < tp_cost
			else:
				value_label.text = "-"
		else:
			var count: int = int(entry.get("count", 0))
			value_label.text = "x%d" % count
			disabled = count <= 0 or not bool(entry.get("usable_in_combat", true))
		if disabled:
			name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
			value_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		row.set_meta("disabled", disabled)
		content.add_child(name_label)
		content.add_child(value_label)
		margin.add_child(content)
		row.add_child(margin)
		row.gui_input.connect(func(event: InputEvent, idx := _list_menu_rows.size()): _on_list_row_gui_input(event, idx))
		row.mouse_entered.connect(func(idx := _list_menu_rows.size()): _on_list_row_hover(idx))
		list_box.add_child(row)
		_list_menu_rows.append(row)
	_refresh_list_selection()


func _on_list_row_hover(index: int) -> void:
	if index < 0 or index >= _list_menu_rows.size():
		return
	if _list_menu_rows[index].get_meta("disabled", false):
		return
	_list_selected_idx = index
	_refresh_list_selection()


func _on_list_row_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if index < 0 or index >= _list_menu_rows.size():
		return
	if _list_menu_rows[index].get_meta("disabled", false):
		return
	_list_selected_idx = index
	_refresh_list_selection()
	_confirm_list_selection()


func _refresh_list_selection() -> void:
	var active_style: StyleBoxFlat = StyleBoxFlat.new()
	active_style.bg_color = Color(0, 0, 0, 0)
	active_style.border_width_bottom = 2
	active_style.border_color = UI_ACCENT
	var selected_color: Color = UI_TEXT_PRIMARY
	var idle_color: Color = Color(0.7, 0.7, 0.76)
	var disabled_color: Color = Color(0.55, 0.55, 0.6)
	for i in range(_list_menu_rows.size()):
		var row: Control = _list_menu_rows[i]
		var is_selected: bool = i == _list_selected_idx
		var target_color: Color = selected_color if is_selected else idle_color
		if bool(row.get_meta("disabled", false)):
			target_color = disabled_color
		if i == _list_selected_idx:
			row.add_theme_stylebox_override("panel", active_style)
		else:
			row.remove_theme_stylebox_override("panel")
		var labels: Array = row.find_children("*", "Label", true, false)
		for label_value: Variant in labels:
			var label: Label = label_value as Label
			if label:
				label.self_modulate = target_color
	_update_list_description()


func _update_list_description() -> void:
	var label: Label = skills_description_label if _list_menu_mode == "skills" else items_description_label
	if label == null:
		return
	if _list_selected_idx < 0 or _list_selected_idx >= _list_menu_entries.size():
		label.text = ""
		return
	label.text = str(_list_menu_entries[_list_selected_idx].get("description", ""))


func _is_menu_up(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or _is_key_pressed(event, [KEY_W])


func _is_menu_down(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or _is_key_pressed(event, [KEY_S])


func _is_menu_accept(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or _is_key_pressed(event, [KEY_Z])


func _is_menu_cancel(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or _is_key_pressed(event, [KEY_X, KEY_ESCAPE])


func _is_action_menu_prev(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or _is_key_pressed(event, [KEY_W, KEY_A])


func _is_action_menu_next(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or _is_key_pressed(event, [KEY_S, KEY_D])


func _is_key_pressed(event: InputEvent, keys: Array[int]) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and int(key_event.keycode) in keys


func _ui_scale_px(base_size: int) -> int:
	var ui_scale_service: Node = get_node_or_null("/root/UIScaleService")
	if ui_scale_service and ui_scale_service.has_method("px"):
		return int(ui_scale_service.call("px", base_size))
	return base_size


func _use_skill(skill_data: Dictionary) -> void:
	var effect: String = str(skill_data.get("effect", "heal"))
	chosen_action = Action.HEAL
	if effect == "attack":
		chosen_action = Action.ATTACK
	elif effect == "defend":
		chosen_action = Action.DEFEND
	_close_list_menu()
	if chosen_action == Action.ATTACK:
		_pending_skill_data = skill_data.duplicate(true)
		_open_target_menu()
		return
	_selected_skill_data = skill_data.duplicate(true)
	_consume_skill_cost(_selected_skill_data)
	_begin_action_quiz()


func _consume_skill_cost(skill_data: Dictionary) -> void:
	var sp_cost: int = int(skill_data.get("sp_cost", 0))
	var tp_cost: int = int(skill_data.get("tp_cost", 0))
	if sp_cost > 0:
		_consume_party_sp(0, sp_cost)
	if tp_cost > 0 and not _party_state.is_empty():
		var member: Dictionary = _party_state[0]
		member["tp"] = clampi(int(member.get("tp", 0)) - tp_cost, 0, int(member.get("tp_max", PARTY_TP_MAX)))
		_party_state[0] = member


func _use_item(item_data: Dictionary) -> void:
	if _ps == null:
		return
	var item_id: String = str(item_data.get("item_id", ""))
	if item_id == "":
		return
	if not _ps.has_method("use_item"):
		return
	var use_result: Dictionary = _ps.use_item(item_id)
	if not bool(use_result.get("success", false)):
		return
	var item_name: String = str(use_result.get("name", item_data.get("name", "Przedmiot")))
	_selected_item_data = item_data.duplicate(true)
	_close_list_menu()
	phase = Phase.PLAYER_RESULT
	var heal_amount: int = int(use_result.get("heal_amount", 0))
	var sp_restore: int = int(use_result.get("sp_restore", 0))
	var tp_restore: int = int(use_result.get("tp_restore", 0))
	var effect_parts: Array[String] = []
	if heal_amount > 0:
		effect_parts.append("+%d HP" % heal_amount)
		result_label.add_theme_color_override("font_color", Color.GREEN)
		_flash_sprite(player_sprite_node, Color.GREEN)
		FloatingText.create_at(player, player.global_position + Vector2(0, -20), "+%d HP" % heal_amount, Color.GREEN, 14)
	if sp_restore > 0:
		_restore_party_sp(0, sp_restore)
		effect_parts.append("+%d SP" % sp_restore)
	if tp_restore > 0:
		_restore_party_tp(0, tp_restore)
		effect_parts.append("+%d TP" % tp_restore)
	if effect_parts.is_empty():
		result_label.text = str(use_result.get("message", "Uzyto %s" % item_name))
		result_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		result_label.text = "%s: %s" % [item_name, ", ".join(effect_parts)]
	result_label.visible = true
	_refresh_stats_panel()
	_update_hp_bars()
	await get_tree().create_timer(1.0).timeout
	if _all_enemies_defeated():
		_end_combat(true)
		return
	_enemy_turn()


func _show_question(q: Dictionary) -> void:
	_quiz_panel_controller.start_question(q, _diff_range.x)
	_set_quiz_layout_active(true)


func _on_quiz_answered(result: Dictionary, submitted_answer: Dictionary) -> void:
	var correct := bool(result.get("correct", false))
	var category := quiz_id
	if _ps:
		if correct:
			_ps.on_correct_answer()
		else:
			_ps.on_wrong_answer()
	if _dm:
		_dm.record_answer(category, correct)
	_show_quiz_feedback(result, submitted_answer)
	await get_tree().create_timer(1.2).timeout
	_resolve_action(correct)


func _show_quiz_feedback(result: Dictionary, submitted_answer: Dictionary) -> void:
	_quiz_panel_controller.show_feedback(result, submitted_answer)


func _resolve_action(correct: bool) -> void:
	quiz_correct = correct
	phase = Phase.PLAYER_RESULT
	_set_quiz_layout_active(false)
	_quiz_panel_controller.hide_quiz()
	result_label.visible = true
	match chosen_action:
		Action.ATTACK:
			_resolve_attack(correct)
		Action.DEFEND:
			_resolve_defend(correct)
		Action.HEAL:
			_resolve_heal(correct)
	_update_hp_bars()
	_refresh_enemy_header()
	_refresh_stats_panel()
	if _ps:
		streak_label.text = "Seria: %d | RNG: +%.0f%%" % [_ps.streak, _ps.rng_bonus * 100.0]
	await get_tree().create_timer(1.5).timeout
	if _all_enemies_defeated():
		_end_combat(true)
		return
	_enemy_turn()


func _resolve_attack(correct: bool) -> void:
	var target_index := _active_enemy_index
	if target_index < 0 or target_index >= _enemy_units.size() or int(_enemy_units[target_index].get("hp", 0)) <= 0:
		target_index = _find_next_alive_enemy_index(_active_enemy_index)
	if target_index < 0:
		return
	_active_enemy_index = target_index
	var target := _enemy_units[_active_enemy_index]
	var target_label := str(target.get("name", enemy_name_str))
	var hit_chance: float = ATTACK_HIT_CHANCE_CORRECT if correct else ATTACK_HIT_CHANCE_WRONG
	var hit_success: bool = _ps.roll_with_bonus(hit_chance) if _ps else randf() < hit_chance
	if hit_success:
		var damage_multiplier: float = float(_selected_skill_data.get("damage_multiplier", 1.0))
		var dmg: int = int(player_base_damage * damage_multiplier)
		var crit := false
		if _ps and _ps.roll_with_bonus(0.15):
			dmg = int(dmg * 1.8)
			crit = true
		target["hp"] = maxi(int(target.get("hp", 0)) - dmg, 0)
		_enemy_units[_active_enemy_index] = target
		_refresh_enemy_cache()
		_sync_enemy_display_hit(_active_enemy_index)
		if crit:
			result_label.text = "%s: krytyk! -%d HP" % [target_label, dmg]
			result_label.add_theme_color_override("font_color", Color.GOLD)
			FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), "KRYT -%d" % dmg, Color.GOLD, 16)
		else:
			result_label.text = "%s: trafienie! -%d HP" % [target_label, dmg]
			result_label.add_theme_color_override("font_color", Color.GREEN)
			FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), "-%d" % dmg, Color.YELLOW, 14)
		HitParticles.create_at(enemy, enemy.global_position, Color(1.0, 0.5, 0.2))
	else:
		var fail_type: String = ["Pudlo!", "Unik wroga!", "Blok wroga!"][randi() % 3]
		result_label.text = fail_type
		result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75) if correct else Color(0.82, 0.62, 0.35))
		_dodge_enemy_display(_active_enemy_index)
		FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), fail_type, Color(0.8, 0.8, 0.8) if correct else Color(0.9, 0.7, 0.45), 12)


func _resolve_defend(correct: bool) -> void:
	defending = true
	if correct:
		result_label.text = "Pelna obrona!"
		result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		_flash_sprite(player_sprite_node, Color(0.3, 0.7, 1.0))
	else:
		result_label.text = "Czesciowa obrona."
		result_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))


func _resolve_heal(correct: bool) -> void:
	if not _ps:
		return
	var heal_pct: float = 0.30 if correct else 0.10
	if not _selected_skill_data.is_empty():
		heal_pct = float(_selected_skill_data.get("heal_ratio_correct", 0.30)) if correct else float(_selected_skill_data.get("heal_ratio_wrong", 0.10))
	var heal_amount := int(_ps.max_hp * heal_pct)
	_ps.heal(heal_amount)
	_flash_sprite(player_sprite_node, Color.GREEN)
	if correct:
		result_label.text = "Leczenie +%d HP" % heal_amount
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text = "Slabe leczenie +%d HP" % heal_amount
		result_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
	FloatingText.create_at(player, player.global_position + Vector2(0, -20), "+%d HP" % heal_amount, Color.GREEN, 14)


func _try_flee() -> void:
	if _ps and _ps.roll_with_bonus(0.30):
		result_label.visible = true
		result_label.text = "Uciekasz!"
		result_label.add_theme_color_override("font_color", Color.WHITE)
		await get_tree().create_timer(1.0).timeout
		_end_combat(false, true)
	else:
		result_label.visible = true
		result_label.text = "Nie udalo sie uciec!"
		result_label.add_theme_color_override("font_color", Color.RED)
		action_panel.visible = false
		await get_tree().create_timer(1.0).timeout
		_enemy_turn()


func _enemy_turn() -> void:
	if _all_enemies_defeated():
		_end_combat(true)
		return
	phase = Phase.ENEMY_TURN
	result_label.visible = true
	for enemy_index in range(_enemy_units.size()):
		var enemy_unit := _enemy_units[enemy_index]
		if int(enemy_unit.get("hp", 0)) <= 0:
			continue
		var enemy_label := str(enemy_unit.get("name", enemy_name_str))
		turn_label.text = "Tura %d - %s atakuje" % [turn_number, enemy_label]
		_active_enemy_index = enemy_index
		_refresh_enemy_header()
		await get_tree().create_timer(0.5).timeout
		var raw_damage := int(enemy_unit.get("damage", enemy_base_damage)) + randi() % 8
		var enemy_tier: int = int(enemy_unit.get("tier", _get_encounter_tier()))
		var actual_damage: int
		if defending and quiz_correct:
			actual_damage = 0
			result_label.text = "%s trafia w blok! 0 obrazen." % enemy_label
			result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
			_flash_sprite(player_sprite_node, Color(0.3, 0.7, 1.0))
			FloatingText.create_at(player, player.global_position + Vector2(0, -20), "BLOK!", Color(0.3, 0.7, 1.0), 14)
		elif defending and not quiz_correct:
			actual_damage = _calculate_player_damage_taken(raw_damage, enemy_tier, 0.5)
			if _ps:
				_ps.take_damage(actual_damage)
			_gain_party_tp(0, actual_damage)
			if actual_damage <= 0:
				result_label.text = "%s odbija sie od obrony!" % enemy_label
				result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
				_flash_sprite(player_sprite_node, Color(0.75, 0.75, 0.82))
				FloatingText.create_at(player, player.global_position + Vector2(0, -20), "0", Color(0.75, 0.75, 0.82), 12)
			else:
				result_label.text = "%s zadaje %d HP" % [enemy_label, actual_damage]
				result_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
				_flash_sprite(player_sprite_node, Color(0.8, 0.6, 0.3))
				FloatingText.create_at(player, player.global_position + Vector2(0, -20), "-%d" % actual_damage, Color.ORANGE, 12)
		else:
			actual_damage = _calculate_player_damage_taken(raw_damage, enemy_tier)
			if _ps:
				_ps.take_damage(actual_damage)
			_gain_party_tp(0, actual_damage)
			if actual_damage <= 0:
				result_label.text = "%s nie przebija pancerza!" % enemy_label
				result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
				_flash_sprite(player_sprite_node, Color(0.75, 0.75, 0.82))
				FloatingText.create_at(player, player.global_position + Vector2(0, -20), "0", Color(0.75, 0.75, 0.82), 12)
			else:
				result_label.text = "%s atakuje! -%d HP" % [enemy_label, actual_damage]
				result_label.add_theme_color_override("font_color", Color.RED)
				_flash_sprite(player_sprite_node, Color.RED)
				HitParticles.create_at(player, player.global_position, Color.RED, 6)
				FloatingText.create_at(player, player.global_position + Vector2(0, -20), "-%d" % actual_damage, Color.RED, 14)
		_update_hp_bars()
		_refresh_stats_panel()
		await get_tree().create_timer(1.0).timeout
		if _ps and not _ps.is_alive():
			_end_combat(false)
			return
	_start_player_turn()


func _end_combat(player_won: bool, fled: bool = false) -> void:
	phase = Phase.COMBAT_END
	_quiz_panel_controller.reset_question()
	_set_quiz_layout_active(false, false)
	_victory_skip = false
	action_panel.visible = false
	result_label.visible = false
	var victory_log := _get_or_create_victory_log()
	victory_log.visible = true
	if player_won:
		var total_xp_reward :int= enemy.xp_reward + _bonus_xp_reward
		var lvl_before :int= _ps.level if _ps else 1
		if _ps:
			_ps.add_xp(total_xp_reward)
		var lines: Array[String] = ["%s and co. won the fight!" % (_ps.player_name if _ps else "Bohater")]
		lines.append("%d EXP received!" % total_xp_reward)
		if _ps and _ps.level > lvl_before:
			lines.append("%s reached LV %d!" % [_ps.player_name, _ps.level])
		var item_name := _roll_item_drop()
		if item_name != "":
			lines.append("Got %s!" % item_name)
		_refresh_stats_panel()
		await _show_message_sequence(lines)
	elif fled:
		await _show_message_sequence(["Uciekasz!"])
	else:
		await _show_message_sequence(["Porazka..."])
	_refresh_stats_panel()
	enemy.hp = 0 if player_won else enemy.max_hp
	_clear_enemy_display()
	combat_finished.emit(player_won)
	enemy.on_combat_finished(player_won, player)
	get_parent().queue_free()


func _update_hp_bars() -> void:
	if player_hp_bar and _ps:
		player_hp_bar.value = (float(_ps.hp) / float(_ps.max_hp)) * 100.0


func _log(text: String) -> void:
	result_label.text = text
	result_label.visible = true


func _highlight_action(idx: int) -> void:
	var buttons := _get_visible_action_buttons() if _action_menu_open else _get_visible_primary_buttons()
	if buttons.is_empty():
		return
	_selected_action_idx = clampi(idx, 0, buttons.size() - 1)
	for btn in [engage_btn, run_btn, atk_btn, skills_btn, def_btn, items_btn]:
		btn.text = btn.text.trim_prefix("► ")
		btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	var selected := buttons[_selected_action_idx]
	selected.text = "► " + selected.text
	selected.add_theme_color_override("font_color", Color.WHITE)


func _flash_sprite(sprite_control: Control, color: Color) -> void:
	if not sprite_control:
		return
	var tween := create_tween()
	tween.tween_property(sprite_control, "modulate", color, 0.1)
	tween.tween_property(sprite_control, "modulate", Color.WHITE, 0.2)


func _dodge_anim(sprite_control: Control) -> void:
	if not sprite_control:
		return
	var orig_pos := sprite_control.position
	var tween := create_tween()
	tween.tween_property(sprite_control, "position:x", orig_pos.x + 20, 0.1)
	tween.tween_property(sprite_control, "position:x", orig_pos.x, 0.15)


func _set_action_buttons_enabled(enabled: bool) -> void:
	atk_btn.disabled = not enabled
	def_btn.disabled = not enabled
	skills_btn.disabled = not enabled
	items_btn.disabled = not enabled


func _setup_battlefield_visuals() -> void:
	if player_sprite_node:
		_build_actor_preview(player_sprite_node, player, Color(0.16, 0.42, 0.82), true)


func _build_actor_preview(
	slot: Control,
	actor: Node,
	accent: Color,
	flip_h: bool,
	unit_data: Dictionary = {},
	is_active: bool = false
) -> void:
	if slot == null:
		return
	for child in slot.get_children():
		child.queue_free()

	var margin := VBoxContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.alignment = BoxContainer.ALIGNMENT_END
	margin.add_theme_constant_override("separation", 8)
	slot.add_child(margin)

	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 132)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var texture := _extract_actor_texture(actor)
	if texture != null:
		var sprite_rect := TextureRect.new()
		sprite_rect.texture = texture
		sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_rect.custom_minimum_size = Vector2(128, 128)
		sprite_rect.flip_h = flip_h
		sprite_rect.modulate = Color.WHITE if is_active else Color(0.82, 0.82, 0.88)
		center.add_child(sprite_rect)
	else:
		var fallback := Label.new()
		fallback.text = _fallback_actor_label(actor)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 52)
		fallback.add_theme_color_override("font_color", accent.lightened(0.62) if is_active else accent.lightened(0.35))
		center.add_child(fallback)

	if not unit_data.is_empty():
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(92, 9)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.value = (float(unit_data.get("hp", 0)) / float(maxi(int(unit_data.get("max_hp", 1)), 1))) * 100.0
		_style_progress_bar(bar, Color(0.36, 1.0, 0.36), Color(0.06, 0.14, 0.06), 0)
		margin.add_child(bar)


func _setup_enemy_display() -> void:
	_enemy_display_root = get_node_or_null("Battlefield/FieldContent/EnemySection/EnemySprite/EnemyDisplayCanvas") as Node2D
	_enemy_name_label = get_node_or_null("Battlefield/FieldContent/EnemySection/EnemyNameLabel") as Label
	if not _enemy_display_root or not enemy:
		return

	_clear_enemy_display()

	if _enemy_name_label:
		_enemy_name_label.text = enemy.enemy_name

	var units: Array = _enemy_units if _enemy_units.size() > 0 else [{
		"name": enemy.enemy_name,
		"hp": enemy.hp,
		"max_hp": enemy.max_hp,
	}]
	_enemy_active_layout_slots = _select_enemy_layout_slots(units.size())

	_enemy_displays.clear()
	for i in range(units.size()):
		var source_enemy: Node2D = enemy
		var display: EnemyBattleDisplay = _create_enemy_display_clone(source_enemy)
		var unit_data: Dictionary = units[i]
		display.sync_hp(int(unit_data.get("hp", source_enemy.hp)))
		display.max_hp = int(unit_data.get("max_hp", source_enemy.max_hp))
		if i < _enemy_active_layout_slots.size():
			var slot: Control = _enemy_active_layout_slots[i].get("slot", null) as Control
			if slot:
				slot.add_child(display)
				display.position = slot.size * 0.5
			else:
				_enemy_display_root.add_child(display)
		else:
			_enemy_display_root.add_child(display)
		_enemy_displays.append(display)

	_enemy_display_node = _enemy_displays[0] if not _enemy_displays.is_empty() else null
	_sync_enemy_displays()


func _create_enemy_display_clone(source: EnemyBase) -> EnemyBattleDisplay:
	var display: EnemyBattleDisplay = EnemyBattleDisplayScript.new() as EnemyBattleDisplay
	display.body_color = source.body_color
	display.shape_type = int(source.shape_type)
	display.hp = source.hp
	display.max_hp = source.max_hp
	display.scale = ENEMY_DISPLAY_SCALE_DEFAULT
	return display


func _sync_enemy_displays() -> void:
	for bar_index in range(_enemy_active_layout_slots.size()):
		var hp_bar: ProgressBar = _enemy_active_layout_slots[bar_index].get("bar", null) as ProgressBar
		if hp_bar == null:
			continue
		if bar_index < _enemy_units.size():
			var enemy_unit: Dictionary = _enemy_units[bar_index]
			var hp_value: int = int(enemy_unit.get("hp", 0))
			var hp_max: int = maxi(int(enemy_unit.get("max_hp", 1)), 1)
			hp_bar.visible = true
			hp_bar.min_value = 0.0
			hp_bar.max_value = float(hp_max)
			hp_bar.value = float(hp_value)
		else:
			hp_bar.visible = false
	if _enemy_displays.is_empty():
		return
	for i in range(_enemy_displays.size()):
		if i >= _enemy_units.size():
			_enemy_displays[i].visible = false
			continue
		var unit_data: Dictionary = _enemy_units[i]
		_enemy_displays[i].visible = int(unit_data.get("hp", 0)) > 0
		_enemy_displays[i].max_hp = int(unit_data.get("max_hp", 1))
		_enemy_displays[i].sync_hp(int(unit_data.get("hp", 0)))
	_refresh_enemy_slot_highlight()


func _sync_enemy_display_hit(enemy_index: int) -> void:
	_sync_enemy_displays()
	if enemy_index < 0 or enemy_index >= _enemy_displays.size():
		return
	var display: EnemyBattleDisplay = _enemy_displays[enemy_index] as EnemyBattleDisplay
	if display == null:
		return
	display.flash_damage()


func _dodge_enemy_display(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= _enemy_displays.size():
		return
	var display: EnemyBattleDisplay = _enemy_displays[enemy_index] as EnemyBattleDisplay
	if display == null:
		return
	var original_position: Vector2 = display.position
	var tween: Tween = create_tween()
	tween.tween_property(display, "position:x", original_position.x + 18.0, 0.08)
	tween.tween_property(display, "position:x", original_position.x - 10.0, 0.07)
	tween.tween_property(display, "position:x", original_position.x, 0.1)


func _clear_enemy_display() -> void:
	for display_node in _enemy_displays:
		if is_instance_valid(display_node):
			display_node.queue_free()
	_enemy_displays.clear()
	_enemy_display_node = null
	_enemy_active_layout_slots.clear()


func _select_enemy_layout_slots(active_count: int) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var rows: Array[Array] = _collect_enemy_row_layouts()
	var remaining: int = active_count
	for row_layout in rows:
		for slot_data in row_layout:
			var wrapper: Control = slot_data.get("wrapper", null) as Control
			if wrapper:
				wrapper.visible = false
		if remaining <= 0:
			continue
		var available: int = row_layout.size()
		if available <= 0:
			continue
		var take_count: int = mini(remaining, available)
		for i in range(take_count):
			var slot_data: Dictionary = row_layout[i]
			var wrapper: Control = slot_data.get("wrapper", null) as Control
			var slot: Control = slot_data.get("slot", null) as Control
			if wrapper:
				wrapper.visible = true
				wrapper.remove_theme_stylebox_override("panel")
				_bind_enemy_slot_target_input(wrapper, selected.size())
			if slot:
				_bind_enemy_slot_target_input(slot, selected.size())
			selected.append(slot_data)
		remaining -= take_count
	return selected


func _refresh_enemy_slot_highlight() -> void:
	var target_select_active: bool = phase == Phase.TARGET_SELECT
	var focused_enemy_index: int = _active_enemy_index
	if target_select_active and _target_selected_idx >= 0 and _target_selected_idx < _target_entries.size():
		focused_enemy_index = int(_target_entries[_target_selected_idx].get("enemy_index", focused_enemy_index))
	for slot_index in range(_enemy_active_layout_slots.size()):
		var wrapper: Control = _enemy_active_layout_slots[slot_index].get("wrapper", null) as Control
		var slot: Control = _enemy_active_layout_slots[slot_index].get("slot", null) as Control
		var hp_bar: ProgressBar = _enemy_active_layout_slots[slot_index].get("bar", null) as ProgressBar
		var display: EnemyBattleDisplay = null
		if slot_index < _enemy_displays.size():
			display = _enemy_displays[slot_index] as EnemyBattleDisplay
		if wrapper == null or slot == null:
			continue
		var focused: bool = target_select_active and slot_index == focused_enemy_index
		if focused:
			var cursor: Label = _ensure_enemy_target_cursor(slot)
			var highlight: Control = _ensure_enemy_target_highlight(slot)
			if cursor:
				cursor.visible = true
			if highlight:
				highlight.visible = true
			if hp_bar:
				hp_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if display:
				display.scale = ENEMY_DISPLAY_SCALE_FOCUSED
		else:
			if hp_bar:
				hp_bar.modulate = Color(0.82, 0.82, 0.82, 1.0)
			if display:
				display.scale = ENEMY_DISPLAY_SCALE_DEFAULT
	if not target_select_active:
		if _enemy_target_cursor_node:
			_enemy_target_cursor_node.visible = false
		if _enemy_target_highlight_node:
			_enemy_target_highlight_node.visible = false


func _bind_enemy_slot_target_input(slot: Control, slot_index: int) -> void:
	if slot == null:
		return
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var parent_control: Control = slot.get_parent() as Control
	if parent_control:
		parent_control.mouse_filter = Control.MOUSE_FILTER_STOP
	var hover_callable: Callable = Callable(self, "_on_enemy_slot_hover").bind(slot_index)
	if not slot.mouse_entered.is_connected(hover_callable):
		slot.mouse_entered.connect(hover_callable)
	var input_callable: Callable = Callable(self, "_on_enemy_slot_gui_input").bind(slot_index)
	if not slot.gui_input.is_connected(input_callable):
		slot.gui_input.connect(input_callable)
	if parent_control:
		if not parent_control.mouse_entered.is_connected(hover_callable):
			parent_control.mouse_entered.connect(hover_callable)
		if not parent_control.gui_input.is_connected(input_callable):
			parent_control.gui_input.connect(input_callable)


func _on_enemy_slot_hover(slot_index: int) -> void:
	if phase != Phase.TARGET_SELECT:
		return
	if slot_index < 0 or slot_index >= _enemy_units.size():
		return
	_hovered_enemy_slot_index = slot_index
	var target_index: int = _find_target_row_index_for_enemy(slot_index)
	if target_index < 0:
		return
	_target_selected_idx = target_index
	_refresh_target_selection()
	_refresh_enemy_slot_highlight()


func _on_enemy_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if phase != Phase.TARGET_SELECT:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if slot_index < 0 or slot_index >= _enemy_units.size():
		return
	var target_index: int = _find_target_row_index_for_enemy(slot_index)
	if target_index < 0:
		return
	_target_selected_idx = target_index
	_refresh_target_selection()
	_confirm_target_selection()


func _find_target_row_index_for_enemy(enemy_index: int) -> int:
	for target_index in range(_target_entries.size()):
		if int(_target_entries[target_index].get("enemy_index", -1)) == enemy_index:
			return target_index
	return -1


func _ensure_enemy_target_cursor(slot: Control) -> Label:
	if _enemy_target_cursor_node == null:
		if enemy_target_home_slot:
			_enemy_target_cursor_node = enemy_target_home_slot.get_node_or_null("TargetCursor") as Label
		if _enemy_target_cursor_node == null:
			_enemy_target_cursor_node = slot.get_node_or_null("TargetCursor") as Label
	if _enemy_target_cursor_node and _enemy_target_cursor_node.get_parent() != slot:
		var old_parent: Node = _enemy_target_cursor_node.get_parent()
		if old_parent:
			old_parent.remove_child(_enemy_target_cursor_node)
		slot.add_child(_enemy_target_cursor_node)
	return _enemy_target_cursor_node


func _ensure_enemy_target_highlight(slot: Control) -> Control:
	if _enemy_target_highlight_node == null:
		if enemy_target_home_slot:
			_enemy_target_highlight_node = enemy_target_home_slot.get_node_or_null("TargetHighlight") as Control
		if _enemy_target_highlight_node == null:
			_enemy_target_highlight_node = slot.get_node_or_null("TargetHighlight") as Control
	if _enemy_target_highlight_node and _enemy_target_highlight_node.get_parent() != slot:
		var old_parent: Node = _enemy_target_highlight_node.get_parent()
		if old_parent:
			old_parent.remove_child(_enemy_target_highlight_node)
		slot.add_child(_enemy_target_highlight_node)
	return _enemy_target_highlight_node


func _collect_enemy_row_layouts() -> Array[Array]:
	var rows: Array[Array] = []
	if enemy_sprite_node == null:
		return rows
	for child in enemy_sprite_node.get_children():
		if not str(child.name).begins_with("EnemyRow"):
			continue
		var row_layout: Array[Dictionary] = []
		var row_box: HBoxContainer = child.get_node_or_null("HBoxContainer") as HBoxContainer
		if row_box == null:
			rows.append(row_layout)
			continue
		for wrapper_node in row_box.get_children():
			var wrapper: Control = wrapper_node as Control
			if wrapper == null:
				continue
			var slot: Control = null
			var hp_bar: ProgressBar = null
			for wrapper_child in wrapper.get_children():
				if slot == null and wrapper_child is Control and str(wrapper_child.name).begins_with("EnemySlot"):
					slot = wrapper_child as Control
				elif hp_bar == null and wrapper_child is ProgressBar and str(wrapper_child.name).begins_with("EnemyHPBar"):
					hp_bar = wrapper_child as ProgressBar
			if slot:
				row_layout.append({
					"wrapper": wrapper,
					"slot": slot,
					"bar": hp_bar,
				})
		rows.append(row_layout)
	return rows


func _extract_actor_texture(actor: Node) -> Texture2D:
	if actor == null:
		return null
	var animated := actor.get_node_or_null("AnimatedSprite2D")
	if animated and animated is AnimatedSprite2D and animated.sprite_frames:
		var anim_name = animated.animation
		if anim_name == StringName("") and animated.sprite_frames.get_animation_names().size() > 0:
			anim_name = animated.sprite_frames.get_animation_names()[0]
		if anim_name != StringName("") and animated.sprite_frames.has_animation(anim_name):
			return animated.sprite_frames.get_frame_texture(anim_name, animated.frame)
	var sprite := actor.get_node_or_null("Sprite2D")
	if sprite and sprite is Sprite2D:
		return sprite.texture
	return null


func _fallback_actor_label(actor: Node) -> String:
	if actor == player:
		var hero_name: String = _ps.player_name if _ps and str(_ps.player_name) != "" else "Bohater"
		return hero_name.left(3).to_upper()
	var enemy_name := enemy_name_str if enemy_name_str != "" else "ENY"
	return enemy_name.left(3).to_upper()


func _roll_enemy_party() -> void:
	_enemy_units.clear()
	var min_count := maxi(1, _encounter_size_range.x)
	var max_count := maxi(min_count, _encounter_size_range.y)
	var encounter_count := randi_range(min_count, max_count)
	for enemy_index in range(encounter_count):
		var unit_name := enemy_name_str if encounter_count == 1 else "%s %d" % [enemy_name_str, enemy_index + 1]
		var unit_hp := maxi(1, enemy_max_hp + randi_range(-6, 10))
		var unit_damage := maxi(1, enemy_base_damage + randi_range(-2, 3))
		_enemy_units.append({
			"name": unit_name,
			"hp": unit_hp,
			"max_hp": unit_hp,
			"damage": unit_damage,
			"tier": _get_encounter_tier(),
		})
	_active_enemy_index = 0
	_bonus_xp_reward = maxi(0, encounter_count - 1) * enemy.xp_reward
	_refresh_enemy_cache()


func _refresh_enemy_cache() -> void:
	enemy_hp = 0
	enemy_max_hp = 0
	for enemy_unit in _enemy_units:
		enemy_hp += int(enemy_unit.get("hp", 0))
		enemy_max_hp += int(enemy_unit.get("max_hp", 0))
	_active_enemy_index = _find_next_alive_enemy_index(_active_enemy_index)
	if battle_background and battle_background.has_method("refresh_units"):
		battle_background.call("refresh_units", _enemy_units)
	_sync_enemy_displays()


func _get_player_attack_power() -> int:
	if _ps and _ps.has_method("get_member_total_atk"):
		return maxi(int(_ps.get_member_total_atk(0)), 1)
	return player_base_damage


func _calculate_player_damage_taken(raw_damage: int, enemy_tier: int, defending_multiplier: float = 1.0) -> int:
	if _ps and _ps.has_method("calculate_incoming_damage"):
		return int(_ps.calculate_incoming_damage(raw_damage, enemy_tier, defending_multiplier, 0))
	return maxi(0, int(round(float(raw_damage) * maxf(defending_multiplier, 0.0))))


func _get_encounter_tier() -> int:
	if enemy != null:
		var direct_tier: Variant = enemy.get("encounter_tier")
		if direct_tier is int:
			return clampi(int(direct_tier), 1, 5)
	if enemy != null and bool(enemy.get("is_boss")):
		return clampi(_diff_range.y, 1, 5)
	return clampi(int(round(float(_diff_range.x + _diff_range.y) * 0.5)), 1, 5)


func _find_next_alive_enemy_index(start_index: int = 0) -> int:
	if _enemy_units.is_empty():
		return -1
	for offset in range(_enemy_units.size()):
		var index := (start_index + offset) % _enemy_units.size()
		if int(_enemy_units[index].get("hp", 0)) > 0:
			return index
	return -1


func _all_enemies_defeated() -> bool:
	return _find_next_alive_enemy_index(0) < 0


func _refresh_enemy_header() -> void:
	var living_count := 0
	for enemy_unit in _enemy_units:
		if int(enemy_unit.get("hp", 0)) > 0:
			living_count += 1
	if living_count <= 0:
		enemy_name_label.text = "Wrogowie pokonani"
		if _enemy_name_label:
			_enemy_name_label.text = enemy_name_label.text
		return
	if _active_enemy_index >= 0 and _active_enemy_index < _enemy_units.size():
		var active_enemy := _enemy_units[_active_enemy_index]
		enemy_name_label.text = "%s  (%d pozostalo)" % [str(active_enemy.get("name", enemy_name_str)), living_count]
	else:
		enemy_name_label.text = "Wrogowie  (%d pozostalo)" % living_count
	if _enemy_name_label:
		_enemy_name_label.text = enemy_name_label.text


func _refresh_stats_panel() -> void:
	if party_rows.is_empty():
		return
	_sync_party_member_from_player()
	for i in range(party_rows.size()):
		var row := party_rows[i]
		if i < _party_state.size():
			row.visible = true
			var member := _party_state[i]
			_set_party_row_name(row, str(member.get("name", "Bohater")))
			_set_party_stat(row, "StatLP", int(member.get("lp", 0)), int(member.get("lp_max", 1)), "%d/%d" % [int(member.get("lp", 0)), int(member.get("lp_max", 1))])
			_set_party_stat(row, "StatSP", int(member.get("sp", 0)), int(member.get("sp_max", 1)), "%d/%d" % [int(member.get("sp", 0)), int(member.get("sp_max", 1))])
			_set_party_stat(row, "StatTP", int(member.get("tp", 0)), int(member.get("tp_max", 1)), "%d/%d" % [int(member.get("tp", 0)), int(member.get("tp_max", 1))])
		else:
			row.visible = false


func _style_party_row(row: HBoxContainer) -> void:
	if row == null:
		return
	var name_label := row.get_node_or_null("NameLabel") as Label
	if name_label:
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Color.WHITE)
	for stat_name in ["StatLP", "StatSP", "StatTP"]:
		var stat_box := row.get_node_or_null(stat_name) as HBoxContainer
		if stat_box == null:
			continue
		var label := stat_box.get_node_or_null("Label") as Label
		var bar := stat_box.get_node_or_null("Bar") as ProgressBar
		var value_label := stat_box.get_node_or_null("ValueLabel") as Label
		if label:
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color.WHITE)
		if value_label:
			value_label.add_theme_font_size_override("font_size", 18)
			value_label.add_theme_color_override("font_color", Color.WHITE)
		if bar:
			match stat_name:
				"StatLP":
					_style_party_progress_bar(bar, Color(0.95, 0.55, 0.1))
				"StatSP":
					_style_party_progress_bar(bar, Color(0.2, 0.6, 1.0))
				"StatTP":
					_style_party_progress_bar(bar, Color(0.2, 0.9, 0.3))


func _style_party_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)


func _style_progress_bar(bar: ProgressBar, fill_color: Color, bg_color: Color, corner: int) -> void:
	if bar == null:
		return
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = corner
	fill.corner_radius_top_right = corner
	fill.corner_radius_bottom_left = corner
	fill.corner_radius_bottom_right = corner
	bar.add_theme_stylebox_override("fill", fill)

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.corner_radius_top_left = corner
	bg.corner_radius_top_right = corner
	bg.corner_radius_bottom_left = corner
	bg.corner_radius_bottom_right = corner
	bar.add_theme_stylebox_override("background", bg)


func _set_party_row_name(row: HBoxContainer, value: String) -> void:
	var name_label := row.get_node_or_null("NameLabel") as Label
	if name_label:
		name_label.text = value


func _set_party_stat(row: HBoxContainer, stat_name: String, value: int, max_value: int, display_value: String) -> void:
	var stat_box := row.get_node_or_null(stat_name) as HBoxContainer
	if stat_box == null:
		return
	var bar := stat_box.get_node_or_null("Bar") as ProgressBar
	var value_label := stat_box.get_node_or_null("ValueLabel") as Label
	if bar:
		bar.value = (float(value) / float(maxi(max_value, 1))) * 100.0
	if value_label:
		value_label.text = display_value


func _setup_party_layout() -> void:
	if content_row and command_panel_container:
		content_row.move_child(command_panel_container, 0)
	if content_row and party_panel_container:
		content_row.move_child(party_panel_container, 1)
	if command_panel_container:
		command_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_panel_container.size_flags_stretch_ratio = COMMAND_PANEL_WIDTH_DEFAULT
		command_panel_container.custom_minimum_size = Vector2(COMMAND_PANEL_WIDTH_MIN, 0)
	if party_panel_container:
		party_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		party_panel_container.size_flags_stretch_ratio = PARTY_PANEL_WIDTH_DEFAULT
		party_panel_container.custom_minimum_size = Vector2(PARTY_PANEL_WIDTH_MIN, 0)


func _set_quiz_layout_active(active: bool, animated: bool = true) -> void:
	if command_panel_container == null or party_panel_container == null:
		return
	var command_ratio := COMMAND_PANEL_WIDTH_DEFAULT
	var party_ratio := PARTY_PANEL_WIDTH_DEFAULT
	if active:
		var separation := float(content_row.get_theme_constant("separation"))
		var available_width := maxf(content_row.size.x - separation, 1.0)
		var desired_width = _quiz_panel_controller.get_desired_panel_width() + 56.0
		var party_min_width := maxf(party_panel_container.get_combined_minimum_size().x, PARTY_PANEL_WIDTH_MIN)
		var command_max_width := maxf(available_width - party_min_width, COMMAND_PANEL_WIDTH_MIN)
		var command_target_width := clampf(desired_width, COMMAND_PANEL_WIDTH_MIN, command_max_width)
		var party_target_width := maxf(PARTY_PANEL_WIDTH_MIN, available_width - command_target_width)
		command_ratio = command_target_width
		party_ratio = party_target_width
	if not animated:
		command_panel_container.size_flags_stretch_ratio = command_ratio
		party_panel_container.size_flags_stretch_ratio = party_ratio
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(command_panel_container, "size_flags_stretch_ratio", command_ratio, PANEL_RESIZE_DURATION)
	tween.tween_property(party_panel_container, "size_flags_stretch_ratio", party_ratio, PANEL_RESIZE_DURATION)


func _init_party_state() -> void:
	_party_state.clear()
	var hero_name : String = _ps.player_name if _ps and str(_ps.player_name) != "" else "Bohater"
	var hero_hp : int = _ps.hp if _ps else 0
	var hero_hp_max : int = _ps.max_hp if _ps else 1
	_party_state.append({
		"name": hero_name,
		"lp": hero_hp,
		"lp_max": hero_hp_max,
		"sp": PARTY_SKILL_SP_MAX,
		"sp_max": PARTY_SKILL_SP_MAX,
		"tp": 0,
		"tp_max": PARTY_TP_MAX,
	})


func _sync_party_member_from_player(index: int = 0) -> void:
	if _ps == null or index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	member["name"] = _ps.player_name if str(_ps.player_name) != "" else "Bohater"
	member["lp"] = _ps.hp
	member["lp_max"] = _ps.max_hp
	_party_state[index] = member


func _gain_party_tp(index: int, amount: int) -> void:
	if index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	member["tp"] = clampi(int(member.get("tp", 0)) + maxi(amount, 0), 0, int(member.get("tp_max", PARTY_TP_MAX)))
	_party_state[index] = member


func _consume_party_sp(index: int, amount: int) -> void:
	if index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	member["sp"] = clampi(int(member.get("sp", 0)) - maxi(amount, 0), 0, int(member.get("sp_max", PARTY_SKILL_SP_MAX)))
	_party_state[index] = member


func _restore_party_sp(index: int, amount: int) -> void:
	if index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	member["sp"] = clampi(int(member.get("sp", 0)) + maxi(amount, 0), 0, int(member.get("sp_max", PARTY_SKILL_SP_MAX)))
	_party_state[index] = member


func _restore_party_tp(index: int, amount: int) -> void:
	if index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	member["tp"] = clampi(int(member.get("tp", 0)) + maxi(amount, 0), 0, int(member.get("tp_max", PARTY_TP_MAX)))
	_party_state[index] = member


func _show_primary_menu() -> void:
	_action_menu_open = false
	primary_menu.visible = true
	action_menu.visible = false
	_selected_action_idx = 0


func _show_action_menu() -> void:
	_action_menu_open = true
	primary_menu.visible = false
	action_menu.visible = true
	_selected_action_idx = 0


func _get_visible_action_buttons() -> Array[Button]:
	var visible_buttons: Array[Button] = []
	for btn in _action_buttons:
		if btn.visible:
			visible_buttons.append(btn)
	return visible_buttons


func _get_visible_action_count() -> int:
	if _action_menu_open:
		return maxi(_get_visible_action_buttons().size(), 1)
	return maxi(_get_visible_primary_buttons().size(), 1)


func _get_visible_primary_buttons() -> Array[Button]:
	var visible_buttons: Array[Button] = []
	for btn in [engage_btn, run_btn]:
		if btn.visible:
			visible_buttons.append(btn)
	return visible_buttons


func _on_engage_pressed() -> void:
	if phase != Phase.ACTION_SELECT:
		return
	_show_action_menu()
	_highlight_action(0)


func _on_run_pressed() -> void:
	if phase != Phase.ACTION_SELECT:
		return
	_try_flee()


func _get_or_create_victory_log() -> Label:
	var label := get_node_or_null("VictoryLog") as Label
	if label:
		return label
	label = Label.new()
	label.name = "VictoryLog"
	label.position = Vector2(24, 620)
	label.custom_minimum_size = Vector2(800, 160)
	label.size = Vector2(800, 160)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)
	return label


func _show_message_sequence(lines: Array[String]) -> void:
	var lbl := _get_or_create_victory_log()
	lbl.text = ""
	lbl.visible = true
	_victory_skip = false
	for line in lines:
		lbl.text += line + "\n"
		if _victory_skip:
			continue
		await _wait_for_victory_advance(1.2)
	if not _victory_skip:
		await _wait_for_victory_advance(3.0)


func _wait_for_victory_advance(max_wait: float) -> void:
	var elapsed := 0.0
	while elapsed < max_wait and not _victory_skip:
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05


func _roll_item_drop() -> String:
	if enemy == null or not enemy.has_method("get_drop_table"):
		return ""
	var drops: Array = enemy.call("get_drop_table")
	for drop in drops:
		if randf() < float(drop.get("chance", 0.0)):
			var item_name := str(drop.get("item", ""))
			if item_name != "" and _ps and _ps.has_method("add_item"):
				_ps.add_item(item_name)
			return item_name
	return ""


func _find_current_map_node() -> Node:
	var node := enemy
	while node:
		var script := node.get_script() as Script
		if script and script.resource_path.contains("/scripts/maps/"):
			return node
		if str(node.name).to_snake_case().contains("map"):
			return node
		node = node.get_parent()
	return null
