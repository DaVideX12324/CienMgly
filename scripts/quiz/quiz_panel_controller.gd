extends RefCounted

signal answered(result: Dictionary, submitted_answer: Dictionary)

const TEXT_PRIMARY := Color(0.95, 0.95, 0.98)
const TEXT_SECONDARY := Color(0.65, 0.65, 0.72)
const FEEDBACK_CORRECT_FILL := Color(0.12, 0.42, 0.18, 0.95)
const FEEDBACK_CORRECT_BORDER := Color(0.3, 1.0, 0.4, 1.0)
const FEEDBACK_WRONG_FILL := Color(0.42, 0.12, 0.12, 0.95)
const FEEDBACK_WRONG_BORDER := Color(1.0, 0.3, 0.3, 1.0)

var command_vbox: VBoxContainer
var quiz_panel: VBoxContainer
var result_label: Label
var correct_answer_label: Label
var question_label: Label
var hint_label: Label
var timer_label: Label
var timer_bar: ProgressBar
var mc_box: VBoxContainer
var mc_buttons: Array[Button] = []
var tf_box: VBoxContainer
var tf_buttons: Array[Button] = []
var fill_text_box: VBoxContainer
var pattern_label: Label
var fill_input: LineEdit
var fill_confirm: Button
var fill_tiles_box: VBoxContainer
var gap_row: HFlowContainer
var tile_row: HFlowContainer
var tiles_confirm: Button
var matching_box: VBoxContainer
var match_left: VBoxContainer
var match_right: VBoxContainer
var match_confirm: Button

var _current_question: Dictionary = {}
var _answering := false
var _time_left := 0.0
var _total_time := 0.0
var _tile_slots: Array[String] = []
var _tile_buttons: Array[Button] = []
var _gap_buttons: Array[Button] = []
var _active_gap := 0
var _match_selected := -1
var _match_pairs: Dictionary = {}
var _match_left_buttons: Array[Button] = []
var _match_right_buttons: Array[Button] = []
var _mc_selected_idx: int = 0
var _tf_selected_idx: int = 0


func setup(p_command_vbox: VBoxContainer) -> void:
	command_vbox = p_command_vbox
	quiz_panel = command_vbox.get_node("QuizPanel") as VBoxContainer
	result_label = command_vbox.get_node("ResultLabel") as Label
	correct_answer_label = command_vbox.get_node("CorrectAnswerLabel") as Label
	question_label = quiz_panel.get_node("QuestionLabel") as Label
	hint_label = quiz_panel.get_node("HintLabel") as Label
	timer_label = quiz_panel.get_node("TimerLabel") as Label
	timer_bar = quiz_panel.get_node("TimerBar") as ProgressBar
	mc_box = quiz_panel.get_node("MC_Box") as VBoxContainer
	mc_buttons = [
		mc_box.get_node("Btn0") as Button,
		mc_box.get_node("Btn1") as Button,
		mc_box.get_node("Btn2") as Button,
		mc_box.get_node("Btn3") as Button,
	]
	tf_box = quiz_panel.get_node("TF_Box") as VBoxContainer
	tf_buttons = [
		tf_box.get_node("BtnTrue") as Button,
		tf_box.get_node("BtnFalse") as Button,
	]
	fill_text_box = quiz_panel.get_node("FillText_Box") as VBoxContainer
	pattern_label = fill_text_box.get_node("PatternHint") as Label
	fill_input = fill_text_box.get_node("Input") as LineEdit
	fill_confirm = fill_text_box.get_node("Confirm") as Button
	fill_tiles_box = quiz_panel.get_node("FillTiles_Box") as VBoxContainer
	gap_row = fill_tiles_box.get_node("GapRow") as HFlowContainer
	tile_row = fill_tiles_box.get_node("TileRow") as HFlowContainer
	tiles_confirm = fill_tiles_box.get_node("Confirm") as Button
	matching_box = quiz_panel.get_node("Matching_Box") as VBoxContainer
	match_left = matching_box.get_node("MatchGrid/LeftCol") as VBoxContainer
	match_right = matching_box.get_node("MatchGrid/RightCol") as VBoxContainer
	match_confirm = matching_box.get_node("Confirm") as Button

	for i in range(mc_buttons.size()):
		var index := i
		mc_buttons[i].pressed.connect(func(): _submit_answer(answer_multiple_choice(index)))
	tf_buttons[0].pressed.connect(func(): _submit_answer(answer_true_false(true)))
	tf_buttons[1].pressed.connect(func(): _submit_answer(answer_true_false(false)))
	fill_confirm.pressed.connect(func(): _submit_answer(answer_fill_text()))
	fill_input.text_submitted.connect(func(_value: String): _submit_answer(answer_fill_text()))
	tiles_confirm.pressed.connect(func(): _submit_answer(answer_fill_tiles()))
	match_confirm.pressed.connect(func(): _submit_answer(answer_matching()))


func apply_visual_style(button_styler: Callable) -> void:
	question_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	question_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	hint_label.add_theme_font_size_override("font_size", 13)
	correct_answer_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	correct_answer_label.add_theme_font_size_override("font_size", 14)
	for btn in mc_buttons:
		button_styler.call(btn, 17)
	for btn in tf_buttons:
		button_styler.call(btn, 17)
	button_styler.call(fill_confirm, 17)
	button_styler.call(tiles_confirm, 17)
	button_styler.call(match_confirm, 17)
	_style_progress_bar(timer_bar, Color(0.92, 0.74, 0.24), Color(0.2, 0.18, 0.1), 2)


func _style_progress_bar(bar: ProgressBar, fill_color: Color, bg_color: Color, corner: int) -> void:
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


func tick(delta: float) -> void:
	if not _answering:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	timer_bar.value = (_time_left / maxf(_total_time, 0.001)) * 100.0
	timer_label.text = "Czas: %.1f s" % _time_left
	if _time_left <= 0.0:
		_submit_timeout()


func handle_input(event: InputEvent) -> bool:
	if not _answering:
		return false
	if not (event is InputEventKey) or not event.pressed or event.is_echo():
		return false
	match str(_current_question.get("type", "multiple_choice")):
		"multiple_choice":
			if _is_choice_prev(event):
				_move_mc_selection(-1)
				return true
			if _is_choice_next(event):
				_move_mc_selection(1)
				return true
			if _is_choice_accept(event):
				_submit_answer(answer_multiple_choice(_mc_selected_idx))
				return true
		"true_false":
			if _is_choice_prev(event):
				_move_tf_selection(-1)
				return true
			if _is_choice_next(event):
				_move_tf_selection(1)
				return true
			if _is_choice_accept(event):
				_submit_answer(answer_true_false(_tf_selected_idx == 0))
				return true
		"fill_tiles":
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == KEY_TAB:
				_active_gap = (_active_gap + 1) % max(_tile_slots.size(), 1)
				_update_gap_highlight()
				return true
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				_submit_answer(answer_fill_tiles())
				return true
		"matching":
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				_submit_answer(answer_matching())
				return true
	return false


func start_question(question: Dictionary, base_difficulty: int) -> void:
	_current_question = question.duplicate(true)
	_answering = true
	quiz_panel.visible = true
	result_label.visible = false
	correct_answer_label.visible = false
	hide_quiz_modes()
	question_label.text = QuizManager.get_question_display_text(_current_question)
	hint_label.text = QuizManager.get_question_hint(_current_question)
	_time_left = QuizManager.get_question_time_limit(_current_question, 16.0, base_difficulty)
	_total_time = _time_left
	timer_label.text = "Czas: %.1f s" % _time_left
	timer_bar.value = 100.0

	match str(_current_question.get("type", "multiple_choice")):
		"multiple_choice":
			_build_mc(_current_question)
		"true_false":
			_build_tf()
		"fill_text":
			_build_fill_text(_current_question)
		"fill_tiles":
			_build_fill_tiles(_current_question)
		"matching":
			_build_matching(_current_question)
		_:
			_build_mc(_current_question)


func reset_question() -> void:
	_current_question = {}
	_answering = false
	_time_left = 0.0
	_total_time = 0.0
	_match_selected = -1
	_match_pairs.clear()
	_tile_slots.clear()
	_tile_buttons.clear()
	_gap_buttons.clear()
	_match_left_buttons.clear()
	_match_right_buttons.clear()
	_mc_selected_idx = 0
	_tf_selected_idx = 0
	if quiz_panel:
		quiz_panel.visible = false
	if correct_answer_label:
		correct_answer_label.visible = false


func hide_quiz() -> void:
	_answering = false
	if quiz_panel:
		quiz_panel.visible = false


func get_desired_panel_width() -> float:
	if quiz_panel == null:
		return 0.0
	var desired_width := 0.0
	desired_width = maxf(desired_width, _measure_label_width(question_label))
	desired_width = maxf(desired_width, _measure_label_width(hint_label))
	desired_width = maxf(desired_width, _measure_label_width(timer_label))
	desired_width = maxf(desired_width, _measure_result_width())

	if mc_box and mc_box.visible:
		for btn in mc_buttons:
			if btn.visible:
				desired_width = maxf(desired_width, _measure_button_width(btn))
	elif tf_box and tf_box.visible:
		for btn in tf_buttons:
			if btn.visible:
				desired_width = maxf(desired_width, _measure_button_width(btn))
	elif fill_text_box and fill_text_box.visible:
		desired_width = maxf(desired_width, _measure_label_width(pattern_label))
		if fill_input:
			desired_width = maxf(desired_width, fill_input.get_combined_minimum_size().x)
		if fill_confirm:
			desired_width = maxf(desired_width, _measure_button_width(fill_confirm))
	elif fill_tiles_box and fill_tiles_box.visible:
		desired_width = maxf(desired_width, _measure_flow_container_width(gap_row))
		desired_width = maxf(desired_width, _measure_flow_container_width(tile_row))
		if tiles_confirm:
			desired_width = maxf(desired_width, _measure_button_width(tiles_confirm))
	elif matching_box and matching_box.visible:
		desired_width = maxf(desired_width, _measure_matching_width())
		if match_confirm:
			desired_width = maxf(desired_width, _measure_button_width(match_confirm))

	return desired_width


func show_feedback(result: Dictionary, submitted_answer: Dictionary) -> void:
	result_label.visible = true
	correct_answer_label.visible = false
	_show_correct_answer()
	if bool(result.get("correct", false)):
		result_label.text = "Poprawnie!"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		result_label.text = "Bledna odpowiedz!"
		if bool(result.get("timed_out", false)):
			result_label.text = "Czas minal!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	match str(_current_question.get("type", "multiple_choice")):
		"multiple_choice":
			var correct_index := int(result.get("correct_index", -1))
			if correct_index >= 0 and correct_index < mc_buttons.size():
				_apply_choice_feedback(mc_buttons[correct_index], true)
			var picked := int(submitted_answer.get("index", -1))
			if not bool(result.get("correct", false)) and picked >= 0 and picked < mc_buttons.size():
				_apply_choice_feedback(mc_buttons[picked], false)
		"true_false":
			var correct_tf_index := int(result.get("correct_index", -1))
			if correct_tf_index >= 0 and correct_tf_index < tf_buttons.size():
				_apply_choice_feedback(tf_buttons[correct_tf_index], true)
			if not bool(result.get("correct", false)) and submitted_answer.has("value"):
				var picked_tf_index: int = 0 if bool(submitted_answer.get("value", false)) else 1
				if picked_tf_index >= 0 and picked_tf_index < tf_buttons.size():
					_apply_choice_feedback(tf_buttons[picked_tf_index], false)


func answer_multiple_choice(index: int) -> Dictionary:
	return {"index": index}


func answer_true_false(value: bool) -> Dictionary:
	return {"value": value}


func answer_fill_text() -> Dictionary:
	return {"text": fill_input.text if fill_input else ""}


func answer_fill_tiles() -> Dictionary:
	var placements: Dictionary = {}
	for i in range(_tile_slots.size()):
		placements[str(i)] = _tile_slots[i]
	return {"placements": placements}


func answer_matching() -> Dictionary:
	var pairs: Array = []
	for left_index in _match_pairs.keys():
		pairs.append({
			"left_index": left_index,
			"right_index": _match_pairs[left_index],
		})
	return {"pairs": pairs}


func hide_quiz_modes() -> void:
	mc_box.visible = false
	tf_box.visible = false
	fill_text_box.visible = false
	fill_tiles_box.visible = false
	matching_box.visible = false


func _submit_answer(player_answer: Dictionary) -> void:
	if not _answering:
		return
	_answering = false
	var result := QuizManager.answer_current(player_answer)
	answered.emit(result, player_answer)


func _submit_timeout() -> void:
	if not _answering:
		return
	_answering = false
	var result := QuizManager.answer_current(QuizManager.get_timeout_answer(_current_question))
	result["timed_out"] = true
	answered.emit(result, {})


func _build_mc(question: Dictionary) -> void:
	mc_box.visible = true
	var answers: Array = question.get("answers", [])
	_mc_selected_idx = 0
	for i in range(mc_buttons.size()):
		var btn: Button = mc_buttons[i]
		if i < answers.size():
			btn.text = str(answers[i])
			btn.visible = true
			btn.disabled = false
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.set_meta("base_text", str(answers[i]))
			_clear_choice_feedback(btn)
			if not btn.mouse_entered.is_connected(_on_mc_button_hover.bind(i)):
				btn.mouse_entered.connect(_on_mc_button_hover.bind(i))
		else:
			btn.visible = false
	_refresh_mc_selection()


func _build_tf() -> void:
	tf_box.visible = true
	_tf_selected_idx = 0
	tf_buttons[0].text = "Prawda"
	tf_buttons[1].text = "Falsz"
	tf_buttons[0].set_meta("base_text", "Prawda")
	tf_buttons[1].set_meta("base_text", "Falsz")
	for i in range(tf_buttons.size()):
		var btn: Button = tf_buttons[i]
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_clear_choice_feedback(btn)
		if not btn.mouse_entered.is_connected(_on_tf_button_hover.bind(i)):
			btn.mouse_entered.connect(_on_tf_button_hover.bind(i))
	_refresh_tf_selection()


func _is_choice_prev(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or _is_key_pressed(event, [KEY_W, KEY_A])


func _is_choice_next(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or _is_key_pressed(event, [KEY_S, KEY_D])


func _is_choice_accept(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or _is_key_pressed(event, [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])


func _is_key_pressed(event: InputEvent, keys: Array[int]) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and int(key_event.keycode) in keys


func _move_mc_selection(delta: int) -> void:
	var visible_indices: Array[int] = []
	for i in range(mc_buttons.size()):
		if mc_buttons[i].visible and not mc_buttons[i].disabled:
			visible_indices.append(i)
	if visible_indices.is_empty():
		return
	var current_pos: int = maxi(visible_indices.find(_mc_selected_idx), 0)
	current_pos = (current_pos + delta + visible_indices.size()) % visible_indices.size()
	_mc_selected_idx = visible_indices[current_pos]
	_refresh_mc_selection()


func _move_tf_selection(delta: int) -> void:
	_tf_selected_idx = (_tf_selected_idx + delta + tf_buttons.size()) % tf_buttons.size()
	_refresh_tf_selection()


func _refresh_mc_selection() -> void:
	for i in range(mc_buttons.size()):
		var btn: Button = mc_buttons[i]
		var base_text: String = str(btn.get_meta("base_text", btn.text)).trim_prefix("► ")
		btn.text = ("► " if i == _mc_selected_idx and btn.visible else "") + base_text
		if btn.visible:
			btn.add_theme_color_override("font_color", Color.WHITE if i == _mc_selected_idx else TEXT_PRIMARY)


func _refresh_tf_selection() -> void:
	for i in range(tf_buttons.size()):
		var btn: Button = tf_buttons[i]
		var base_text: String = str(btn.get_meta("base_text", btn.text)).trim_prefix("► ")
		btn.text = ("► " if i == _tf_selected_idx else "") + base_text
		btn.add_theme_color_override("font_color", Color.WHITE if i == _tf_selected_idx else TEXT_PRIMARY)


func _on_mc_button_hover(index: int) -> void:
	if index < 0 or index >= mc_buttons.size():
		return
	if not mc_buttons[index].visible or mc_buttons[index].disabled:
		return
	_mc_selected_idx = index
	_refresh_mc_selection()


func _on_tf_button_hover(index: int) -> void:
	if index < 0 or index >= tf_buttons.size():
		return
	_tf_selected_idx = index
	_refresh_tf_selection()
	for btn in tf_buttons:
		btn.disabled = false
		btn.remove_theme_color_override("font_color")


func _build_fill_text(question: Dictionary) -> void:
	fill_text_box.visible = true
	var pattern := str(question.get("prefilled_pattern", ""))
	pattern_label.text = "Podpowiedz: %s" % pattern
	pattern_label.visible = pattern != ""
	fill_input.text = ""
	fill_input.grab_focus()


func _build_fill_tiles(question: Dictionary) -> void:
	fill_tiles_box.visible = true
	for child in gap_row.get_children():
		child.queue_free()
	for child in tile_row.get_children():
		child.queue_free()
	_tile_slots.clear()
	_tile_buttons.clear()
	_gap_buttons.clear()
	_active_gap = 0
	var text_with_gaps := str(question.get("text_with_gaps", ""))
	var gaps: Array = question.get("gaps", [])
	var tiles: Array = question.get("tiles", [])
	_tile_slots.resize(gaps.size())
	_tile_slots.fill("")
	var parts := text_with_gaps.split("___")
	for i in range(parts.size()):
		var label := Label.new()
		label.text = parts[i]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gap_row.add_child(label)
		if i < gaps.size():
			var gap_button := Button.new()
			gap_button.text = "[ ___ ]"
			gap_button.focus_mode = Control.FOCUS_NONE
			gap_button.custom_minimum_size = Vector2(110, 32)
			var gap_index := i
			gap_button.pressed.connect(func(): _on_gap_clicked(gap_index))
			gap_row.add_child(gap_button)
			_gap_buttons.append(gap_button)
	for tile in tiles:
		var tile_button := Button.new()
		tile_button.text = str(tile)
		tile_button.focus_mode = Control.FOCUS_NONE
		var tile_text := str(tile)
		tile_button.pressed.connect(func(): _on_tile_clicked(tile_text, tile_button))
		tile_row.add_child(tile_button)
		_tile_buttons.append(tile_button)
	_update_gap_highlight()


func _build_matching(question: Dictionary) -> void:
	matching_box.visible = true
	for child in match_left.get_children():
		child.queue_free()
	for child in match_right.get_children():
		child.queue_free()
	_match_selected = -1
	_match_pairs.clear()
	_match_left_buttons.clear()
	_match_right_buttons.clear()
	var left_items: Array = question.get("left_items", [])
	var right_items: Array = question.get("right_items", [])
	for i in range(left_items.size()):
		var button := Button.new()
		button.text = str(left_items[i])
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := i
		button.pressed.connect(func(): _on_match_left(index))
		match_left.add_child(button)
		_match_left_buttons.append(button)
	for i in range(right_items.size()):
		var button := Button.new()
		button.text = str(right_items[i])
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := i
		button.pressed.connect(func(): _on_match_right(index))
		match_right.add_child(button)
		_match_right_buttons.append(button)


func _show_correct_answer() -> void:
	var answer_text := QuizManager.get_correct_answer_text(_current_question)
	if answer_text == "":
		return
	correct_answer_label.text = "Poprawna odpowiedz: %s" % answer_text
	correct_answer_label.visible = true


func _apply_choice_feedback(button: Button, is_correct: bool) -> void:
	if button == null:
		return
	var fill_color: Color = FEEDBACK_CORRECT_FILL if is_correct else FEEDBACK_WRONG_FILL
	var border_color: Color = FEEDBACK_CORRECT_BORDER if is_correct else FEEDBACK_WRONG_BORDER
	var font_color: Color = Color.WHITE if is_correct else Color(1.0, 0.92, 0.92)
	button.add_theme_color_override("font_color", font_color)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, _make_feedback_stylebox(fill_color, border_color))


func _clear_choice_feedback(button: Button) -> void:
	if button == null:
		return
	button.remove_theme_color_override("font_color")
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.remove_theme_stylebox_override(state_name)


func _make_feedback_stylebox(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = fill_color
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = border_color
	style_box.corner_radius_top_left = 3
	style_box.corner_radius_top_right = 3
	style_box.corner_radius_bottom_left = 3
	style_box.corner_radius_bottom_right = 3
	return style_box


func _measure_label_width(label: Label) -> float:
	if label == null or not label.visible:
		return 0.0
	var font := label.get_theme_font("font")
	if font == null:
		return label.get_combined_minimum_size().x
	var font_size := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _measure_button_width(button: Button) -> float:
	if button == null or not button.visible:
		return 0.0
	var font := button.get_theme_font("font")
	var base_width := button.custom_minimum_size.x
	if font == null:
		return maxf(base_width, button.get_combined_minimum_size().x)
	var font_size := button.get_theme_font_size("font_size")
	var text_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return maxf(base_width, text_width + 28.0)


func _measure_flow_container_width(container: HFlowContainer) -> float:
	if container == null or not container.visible:
		return 0.0
	var width := 0.0
	var separation := float(container.get_theme_constant("h_separation"))
	for child in container.get_children():
		if child is Control and (child as Control).visible:
			width += (child as Control).get_combined_minimum_size().x
			width += separation
	if width > 0.0:
		width -= separation
	return width


func _measure_matching_width() -> float:
	if match_left == null or match_right == null:
		return 0.0
	var left_width := 0.0
	for child in match_left.get_children():
		if child is Button and (child as Button).visible:
			left_width = maxf(left_width, _measure_button_width(child as Button))
	var right_width := 0.0
	for child in match_right.get_children():
		if child is Button and (child as Button).visible:
			right_width = maxf(right_width, _measure_button_width(child as Button))
	return left_width + right_width + 24.0


func _measure_result_width() -> float:
	var width := 0.0
	width = maxf(width, _measure_label_width(result_label))
	width = maxf(width, _measure_label_width(correct_answer_label))
	return width


func _on_gap_clicked(gap_index: int) -> void:
	_active_gap = gap_index
	_update_gap_highlight()


func _on_tile_clicked(tile_text: String, tile_button: Button) -> void:
	if _tile_slots.is_empty():
		return
	var old_tile := _tile_slots[_active_gap]
	if old_tile != "":
		for button in _tile_buttons:
			if button.text == old_tile:
				button.disabled = false
				break
	_tile_slots[_active_gap] = tile_text
	tile_button.disabled = true
	_gap_buttons[_active_gap].text = tile_text
	var next := (_active_gap + 1) % _tile_slots.size()
	for _i in range(_tile_slots.size()):
		if _tile_slots[next] == "":
			break
		next = (next + 1) % _tile_slots.size()
	_active_gap = next
	_update_gap_highlight()


func _update_gap_highlight() -> void:
	for i in range(_gap_buttons.size()):
		if i == _active_gap:
			_gap_buttons[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			_gap_buttons[i].remove_theme_color_override("font_color")


func _on_match_left(index: int) -> void:
	_match_selected = index
	for i in range(_match_left_buttons.size()):
		if i == index:
			_match_left_buttons[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			_match_left_buttons[i].remove_theme_color_override("font_color")


func _on_match_right(index: int) -> void:
	if _match_selected < 0:
		return
	var left_items: Array = _current_question.get("left_items", [])
	for key in _match_pairs.keys():
		if _match_pairs[key] == index:
			_match_pairs.erase(key)
			if int(key) < _match_left_buttons.size():
				_match_left_buttons[int(key)].text = str(left_items[int(key)])
				_match_left_buttons[int(key)].remove_theme_color_override("font_color")
	_match_pairs[_match_selected] = index
	if _match_selected < _match_left_buttons.size():
		_match_left_buttons[_match_selected].text = str(left_items[_match_selected]) + " OK"
	_match_selected = -1
	for button in _match_left_buttons:
		button.remove_theme_color_override("font_color")
	for i in range(_match_right_buttons.size()):
		if _match_pairs.values().has(i):
			_match_right_buttons[i].add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			_match_right_buttons[i].remove_theme_color_override("font_color")
