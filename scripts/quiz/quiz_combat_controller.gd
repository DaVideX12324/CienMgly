extends Control

signal combat_finished(player_won: bool)

enum Phase { ACTION_SELECT, QUIZ, PLAYER_RESULT, ENEMY_TURN, COMBAT_END }
enum Action { ATTACK, DEFEND, HEAL, FLEE }

const QuizPanelController = preload("res://modules/quiz_rpg/scripts/quiz/quiz_panel_controller.gd")

const PARTY_SKILL_SP_MAX := 100
const PARTY_TP_MAX := 100
const SKILL_SP_COST := 20
const COMMAND_PANEL_WIDTH_DEFAULT := 280.0
const PARTY_PANEL_WIDTH_DEFAULT := 1080.0
const COMMAND_PANEL_WIDTH_MIN := 180.0
const PARTY_PANEL_WIDTH_MIN := 320.0
const PANEL_RESIZE_DURATION := 0

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
@onready var enemy_hp_bar: ProgressBar = $Battlefield/FieldContent/EnemySection/EnemyHPBar
@onready var player_hp_bar: ProgressBar = $Battlefield/FieldContent/PlayerSection/PlayerHPBar
@onready var enemy_name_label: Label = $Battlefield/FieldContent/EnemySection/EnemyName
@onready var player_name_label: Label = $Battlefield/FieldContent/PlayerSection/PlayerName
@onready var enemy_sprite_node: Control = $Battlefield/FieldContent/EnemySection/EnemySprite
@onready var player_sprite_node: Control = $Battlefield/FieldContent/PlayerSection/PlayerSprite
@onready var battle_background: Control = $Battlefield/Background
@onready var turn_label: Label = $BattleWindow/WindowMargin/VBox/TopRow/TurnLabel
@onready var streak_label: Label = $BattleWindow/WindowMargin/VBox/TopRow/StreakLabel
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
var _action_buttons: Array[Button] = []
var _selected_action_idx: int = 0
var _victory_skip := false
var _action_menu_open := false
var _party_state: Array[Dictionary] = []
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
	player_base_damage = 20
	_roll_enemy_party()


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	_dm = CoreManager.get_singleton("DifficultyManager")
	_gm = CoreManager.get_singleton("GameManager")


	engage_btn.pressed.connect(_on_engage_pressed)
	run_btn.pressed.connect(_on_run_pressed)
	_action_buttons = [atk_btn, skills_btn, def_btn, items_btn]
	for i in range(_action_buttons.size()):
		var action_index := i
		_action_buttons[i].pressed.connect(_on_action.bind([Action.ATTACK, Action.HEAL, Action.DEFEND, Action.FLEE][action_index]))
		_action_buttons[i].mouse_entered.connect(func(): _highlight_action(action_index))

	UIThemeSetup.style_quiz_ui(self)
	_style_battle_ui()
	_setup_party_layout()
	_init_party_state()
	_quiz_panel_controller = QuizPanelController.new()
	_quiz_panel_controller.setup(command_vbox)
	_quiz_panel_controller.apply_visual_style(_style_command_button)
	_quiz_panel_controller.answered.connect(_on_quiz_answered)

	if battle_background and battle_background.has_method("set_context"):
		battle_background.call("set_context", _find_current_map_node(), enemy, player, _enemy_units)
	player_name_label.text = _ps.player_name if _ps else "Bohater"
	_setup_battlefield_visuals()
	_refresh_enemy_header()
	_refresh_stats_panel()
	_update_hp_bars()
	_start_player_turn()


func _process(delta: float) -> void:
	if _quiz_panel_controller:
		_quiz_panel_controller.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.COMBAT_END and event.is_action_pressed("ui_accept"):
		_victory_skip = true
		get_viewport().set_input_as_handled()
		return
	if phase == Phase.ACTION_SELECT:
		var menu_count := _get_visible_action_count()
		if event.is_action_pressed("ui_down"):
			_selected_action_idx = (_selected_action_idx + 1) % menu_count
			_highlight_action(_selected_action_idx)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up"):
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


func _start_player_turn() -> void:
	turn_number += 1
	defending = false
	_quiz_panel_controller.reset_question()
	_set_quiz_layout_active(false)
	phase = Phase.ACTION_SELECT
	turn_label.text = "Tura %d - Twoj ruch" % turn_number
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
	phase = Phase.QUIZ
	_set_action_buttons_enabled(false)
	var q := QuizManager.start_quiz(quiz_id, _diff_range, 1)
	if q.is_empty():
		_resolve_action(true)
		return
	action_panel.visible = false
	_show_question(q)


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
	var target_index := _find_next_alive_enemy_index(_active_enemy_index)
	if target_index < 0:
		return
	_active_enemy_index = target_index
	var target := _enemy_units[_active_enemy_index]
	var target_label := str(target.get("name", enemy_name_str))
	if correct:
		var dmg := player_base_damage
		var crit := false
		if _ps and _ps.roll_with_bonus(0.15):
			dmg = int(dmg * 1.8)
			crit = true
		target["hp"] = maxi(int(target.get("hp", 0)) - dmg, 0)
		_enemy_units[_active_enemy_index] = target
		_refresh_enemy_cache()
		_flash_sprite(enemy_sprite_node, Color.RED)
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
		var fail_type = ["Pudlo!", "Unik wroga!", "Blok wroga!"][randi() % 3]
		result_label.text = fail_type
		result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		_dodge_anim(enemy_sprite_node)
		FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), fail_type, Color(0.8, 0.8, 0.8), 12)


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
	_consume_party_sp(0, SKILL_SP_COST)
	var heal_pct := 0.30 if correct else 0.10
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
		var actual_damage: int
		if defending and quiz_correct:
			actual_damage = 0
			result_label.text = "%s trafia w blok! 0 obrazen." % enemy_label
			result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
			_flash_sprite(player_sprite_node, Color(0.3, 0.7, 1.0))
			FloatingText.create_at(player, player.global_position + Vector2(0, -20), "BLOK!", Color(0.3, 0.7, 1.0), 14)
		elif defending and not quiz_correct:
			actual_damage = int(raw_damage * 0.5)
			if _ps:
				_ps.take_damage(actual_damage)
			_gain_party_tp(0, actual_damage)
			result_label.text = "%s zadaje %d HP" % [enemy_label, actual_damage]
			result_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
			_flash_sprite(player_sprite_node, Color(0.8, 0.6, 0.3))
			FloatingText.create_at(player, player.global_position + Vector2(0, -20), "-%d" % actual_damage, Color.ORANGE, 12)
		else:
			actual_damage = raw_damage
			if _ps:
				_ps.take_damage(actual_damage)
			_gain_party_tp(0, actual_damage)
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
	combat_finished.emit(player_won)
	enemy.on_combat_finished(player_won, player)
	get_parent().queue_free()


func _update_hp_bars() -> void:
	if enemy_hp_bar:
		enemy_hp_bar.value = (float(enemy_hp) / float(maxi(enemy_max_hp, 1))) * 100.0
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


func _style_battle_ui() -> void:
	var battle_window := $BattleWindow
	var command_panel := $BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel
	var log_panel := $BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel
	var dim_overlay := $DimOverlay
	for panel in [battle_window, command_panel, log_panel]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.015, 0.015, 0.028, 0.78)
		style.border_color = Color(0.0, 0.0, 0.0, 0.0)
		panel.add_theme_stylebox_override("panel", style)
	dim_overlay.color = Color(0.0, 0.0, 0.0, 0.18)

	enemy_name_label.visible = false
	enemy_hp_bar.visible = false
	player_name_label.visible = false
	player_hp_bar.visible = false

	for label in [turn_label, streak_label, enemy_name_label, player_name_label, result_label]:
		label.add_theme_color_override("font_color", UIThemeSetup.TEXT_PRIMARY)
	result_label.add_theme_font_size_override("font_size", 17)
	turn_label.add_theme_font_size_override("font_size", 16)
	streak_label.add_theme_font_size_override("font_size", 15)
	for row in party_rows:
		_style_party_row(row)

	for btn in [atk_btn, def_btn, skills_btn, items_btn]:
		_style_command_button(btn)

	UIThemeSetup.style_progress_bar(enemy_hp_bar, Color(0.86, 0.24, 0.28), Color(0.2, 0.12, 0.12), 3)
	UIThemeSetup.style_progress_bar(player_hp_bar, Color(0.22, 0.72, 0.34), Color(0.12, 0.2, 0.12), 3)


func _style_command_button(btn: Button, font_size: int = 16) -> void:
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.45))
	btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.64, 0.22))
	btn.add_theme_color_override("font_disabled_color", Color(0.52, 0.52, 0.62))
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _setup_battlefield_visuals() -> void:
	if enemy_sprite_node == null:
		return
	for child in enemy_sprite_node.get_children():
		child.queue_free()
	var enemy_row := HBoxContainer.new()
	enemy_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.add_theme_constant_override("separation", 48)
	enemy_sprite_node.add_child(enemy_row)
	for enemy_index in range(_enemy_units.size()):
		var accent := Color(0.70, 0.18, 0.24).lightened(minf(float(enemy_index) * 0.08, 0.24))
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(145, 165)
		enemy_row.add_child(slot)
		_build_actor_preview(slot, enemy, accent, false, _enemy_units[enemy_index], enemy_index == _active_enemy_index)
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
		UIThemeSetup.style_progress_bar(bar, Color(0.36, 1.0, 0.36), Color(0.06, 0.14, 0.06), 0)
		margin.add_child(bar)


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
	if enemy_sprite_node != null:
		_setup_battlefield_visuals()


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
		return
	if _active_enemy_index >= 0 and _active_enemy_index < _enemy_units.size():
		var active_enemy := _enemy_units[_active_enemy_index]
		enemy_name_label.text = "%s  (%d pozostalo)" % [str(active_enemy.get("name", enemy_name_str)), living_count]
	else:
		enemy_name_label.text = "Wrogowie  (%d pozostalo)" % living_count


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
