extends CanvasLayer

signal answered(result: Dictionary)

const WORDS_PER_SEC := 0.35
const DIFF_STEP_SEC := 3.0
const TYPE_MULTIPLIER := {
	"true_false": 0.80,
	"multiple_choice": 1.00,
	"fill_text": 1.20,
	"fill_tiles": 1.40,
	"matching": 1.55,
}

@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/VBox
@onready var title_label: Label = $Panel/VBox/Title
@onready var question_label: Label = $Panel/VBox/Question
@onready var timer_label: Label = $Panel/VBox/TimerLabel
@onready var hint_label: Label = $Panel/VBox/Hint
@onready var result_label: Label = $Panel/VBox/ResultLabel
@onready var correct_label: Label = $Panel/VBox/CorrectAnswer
@onready var timer_node: Timer = $Timer

@onready var mc_box: VBoxContainer = $Panel/VBox/MC_Box
@onready var mc_buttons: Array[Button] = [
	$Panel/VBox/MC_Box/Btn0,
	$Panel/VBox/MC_Box/Btn1,
	$Panel/VBox/MC_Box/Btn2,
	$Panel/VBox/MC_Box/Btn3,
]

@onready var tf_box: VBoxContainer = $Panel/VBox/TF_Box
@onready var tf_buttons: Array[Button] = [
	$Panel/VBox/TF_Box/BtnTrue,
	$Panel/VBox/TF_Box/BtnFalse,
]

@onready var fill_text_box: VBoxContainer = $Panel/VBox/FillText_Box
@onready var pattern_label: Label = $Panel/VBox/FillText_Box/PatternHint
@onready var fill_input: LineEdit = $Panel/VBox/FillText_Box/Input
@onready var fill_confirm: Button = $Panel/VBox/FillText_Box/Confirm

@onready var fill_tiles_box: VBoxContainer = $Panel/VBox/FillTiles_Box
@onready var gap_row: HFlowContainer = $Panel/VBox/FillTiles_Box/GapRow
@onready var tile_row: HFlowContainer = $Panel/VBox/FillTiles_Box/TileRow
@onready var tiles_confirm: Button = $Panel/VBox/FillTiles_Box/Confirm

@onready var matching_box: VBoxContainer = $Panel/VBox/Matching_Box
@onready var match_left: VBoxContainer = $Panel/VBox/Matching_Box/MatchGrid/LeftCol
@onready var match_right: VBoxContainer = $Panel/VBox/Matching_Box/MatchGrid/RightCol
@onready var match_confirm: Button = $Panel/VBox/Matching_Box/Confirm

var _question: Dictionary = {}
var _locked := false
var _resolved := false
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	timer_node.timeout.connect(_on_timeout)
	fill_confirm.pressed.connect(_on_fill_text_confirm)
	fill_input.text_submitted.connect(func(_value: String): _on_fill_text_confirm())
	tiles_confirm.pressed.connect(_on_fill_tiles_confirm)
	match_confirm.pressed.connect(_on_matching_confirm)
	for i in range(mc_buttons.size()):
		var index := i
		mc_buttons[i].pressed.connect(func(): _on_mc_button(index))
	tf_buttons[0].pressed.connect(func(): _on_tf_button(true))
	tf_buttons[1].pressed.connect(func(): _on_tf_button(false))

	if UIScaleService.has_signal("scale_changed") and not UIScaleService.scale_changed.is_connected(_on_scale_changed):
		UIScaleService.scale_changed.connect(_on_scale_changed)
	_on_scale_changed(UIScaleService.scale_factor)


static func calculate_time(question: Dictionary, base_time: float, base_difficulty: int) -> float:
	var word_count := 0
	for field in [
		question.get("question", ""),
		question.get("statement", ""),
		question.get("prompt", ""),
		question.get("text_with_gaps", ""),
	]:
		if str(field) != "":
			word_count += str(field).split(" ", false).size()
	for answer in question.get("answers", []):
		word_count += str(answer).split(" ", false).size()
	for item in question.get("left_items", []):
		word_count += str(item).split(" ", false).size()
	for item in question.get("right_items", []):
		word_count += str(item).split(" ", false).size()
	var word_bonus := float(word_count) * WORDS_PER_SEC
	var qtype := str(question.get("type", "multiple_choice"))
	var type_mult := float(TYPE_MULTIPLIER.get(qtype, 1.0))
	var diff_offset := float(int(question.get("difficulty", base_difficulty)) - base_difficulty) * DIFF_STEP_SEC
	return clampf((base_time + word_bonus) * type_mult + diff_offset, 5.0, 120.0)


func open_question(question: Dictionary, title_text: String, time_limit: float, hint_text: String = "") -> void:
	_question = question.duplicate(true)
	_locked = false
	_resolved = false
	_time_left = time_limit
	_total_time = time_limit
	_tile_slots.clear()
	_tile_buttons.clear()
	_gap_buttons.clear()
	_active_gap = 0
	_match_selected = -1
	_match_pairs.clear()
	_match_left_buttons.clear()
	_match_right_buttons.clear()
	result_label.visible = false
	correct_label.visible = false
	title_label.text = title_text
	hint_label.text = hint_text if hint_text != "" else _default_hint()
	_build_ui()
	visible = true
	timer_node.wait_time = time_limit
	timer_node.start()


func _process(delta: float) -> void:
	if not visible or timer_node.is_stopped():
		return
	_time_left = maxf(_time_left - delta, 0.0)
	var pct := _time_left / maxf(_total_time, 0.001)
	var color := Color(0.3, 1.0, 0.3).lerp(Color(1.0, 0.2, 0.2), 1.0 - pct)
	timer_label.text = "Czas: %.1f s" % _time_left
	timer_label.add_theme_color_override("font_color", color)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		var key_event := event as InputEventKey
		match str(_question.get("type", "multiple_choice")):
			"multiple_choice":
				var mapping := [KEY_W, KEY_S, KEY_A, KEY_D]
				for i in range(min(mc_buttons.size(), 4)):
					if key_event.keycode == mapping[i]:
						_on_mc_button(i)
						get_viewport().set_input_as_handled()
						return
			"true_false":
				if key_event.keycode == KEY_W:
					_on_tf_button(true)
					get_viewport().set_input_as_handled()
				elif key_event.keycode == KEY_S:
					_on_tf_button(false)
					get_viewport().set_input_as_handled()
			"fill_tiles":
				if key_event.keycode == KEY_TAB:
					_active_gap = (_active_gap + 1) % max(_tile_slots.size(), 1)
					_update_gap_highlight()
					get_viewport().set_input_as_handled()
				elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
					_on_fill_tiles_confirm()
					get_viewport().set_input_as_handled()
			"matching":
				if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
					_on_matching_confirm()
					get_viewport().set_input_as_handled()


func _on_scale_changed(_scale: float) -> void:
	panel.offset_left = -UIScaleService.sz(340.0)
	panel.offset_top = -UIScaleService.sz(300.0)
	panel.offset_right = UIScaleService.sz(340.0)
	panel.offset_bottom = UIScaleService.sz(300.0)
	vbox.add_theme_constant_override("separation", UIScaleService.px(10))
	title_label.add_theme_font_size_override("font_size", UIScaleService.px(24))
	question_label.add_theme_font_size_override("font_size", UIScaleService.px(21))
	timer_label.add_theme_font_size_override("font_size", UIScaleService.px(20))
	hint_label.add_theme_font_size_override("font_size", UIScaleService.px(13))
	result_label.add_theme_font_size_override("font_size", UIScaleService.px(22))
	correct_label.add_theme_font_size_override("font_size", UIScaleService.px(18))
	for btn in mc_buttons:
		btn.add_theme_font_size_override("font_size", UIScaleService.px(20))
	for btn in tf_buttons:
		btn.add_theme_font_size_override("font_size", UIScaleService.px(20))
	fill_input.add_theme_font_size_override("font_size", UIScaleService.px(20))
	fill_confirm.add_theme_font_size_override("font_size", UIScaleService.px(20))
	pattern_label.add_theme_font_size_override("font_size", UIScaleService.px(20))
	tiles_confirm.add_theme_font_size_override("font_size", UIScaleService.px(20))
	match_confirm.add_theme_font_size_override("font_size", UIScaleService.px(18))


func _build_ui() -> void:
	var qtype := str(_question.get("type", "multiple_choice"))
	mc_box.visible = false
	tf_box.visible = false
	fill_text_box.visible = false
	fill_tiles_box.visible = false
	matching_box.visible = false
	question_label.text = _main_question_text()
	match qtype:
		"multiple_choice":
			_build_mc()
		"true_false":
			_build_tf()
		"fill_text":
			_build_fill_text()
		"fill_tiles":
			_build_fill_tiles()
		"matching":
			_build_matching()
		_:
			_build_mc()


func _build_mc() -> void:
	mc_box.visible = true
	var answers: Array = _question.get("answers", [])
	var keys := ["W", "S", "A", "D"]
	for i in range(mc_buttons.size()):
		var btn := mc_buttons[i]
		if i < answers.size():
			btn.text = "[%s] %s" % [keys[i], str(answers[i])]
			btn.visible = true
			btn.disabled = false
			btn.remove_theme_color_override("font_color")
		else:
			btn.visible = false


func _build_tf() -> void:
	tf_box.visible = true
	tf_buttons[0].text = "[W] Prawda"
	tf_buttons[1].text = "[S] Falsz"
	for btn in tf_buttons:
		btn.disabled = false
		btn.remove_theme_color_override("font_color")


func _build_fill_text() -> void:
	fill_text_box.visible = true
	var pattern := str(_question.get("prefilled_pattern", ""))
	pattern_label.text = "Podpowiedz: %s" % pattern
	pattern_label.visible = pattern != ""
	fill_input.text = ""
	fill_input.grab_focus()


func _build_fill_tiles() -> void:
	fill_tiles_box.visible = true
	for child in gap_row.get_children():
		child.queue_free()
	for child in tile_row.get_children():
		child.queue_free()
	var text_with_gaps := str(_question.get("text_with_gaps", ""))
	var gaps: Array = _question.get("gaps", [])
	var tiles: Array = _question.get("tiles", [])
	_tile_slots.resize(gaps.size())
	_tile_slots.fill("")
	var font_size := UIScaleService.px(20)
	var parts := text_with_gaps.split("___")
	for i in range(parts.size()):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", font_size)
		label.text = parts[i]
		gap_row.add_child(label)
		if i < gaps.size():
			var gap_button := Button.new()
			gap_button.add_theme_font_size_override("font_size", font_size)
			gap_button.focus_mode = Control.FOCUS_NONE
			gap_button.custom_minimum_size = UIScaleService.sz2(120, 36)
			gap_button.text = "[ ___ ]"
			var gap_index := i
			gap_button.pressed.connect(func(): _on_gap_clicked(gap_index))
			gap_row.add_child(gap_button)
			_gap_buttons.append(gap_button)
	for tile in tiles:
		var tile_button := Button.new()
		tile_button.add_theme_font_size_override("font_size", font_size)
		tile_button.text = str(tile)
		tile_button.focus_mode = Control.FOCUS_NONE
		var tile_text := str(tile)
		tile_button.pressed.connect(func(): _on_tile_clicked(tile_text, tile_button))
		tile_row.add_child(tile_button)
		_tile_buttons.append(tile_button)
	_update_gap_highlight()


func _build_matching() -> void:
	matching_box.visible = true
	for child in match_left.get_children():
		child.queue_free()
	for child in match_right.get_children():
		child.queue_free()
	var left_items: Array = _question.get("left_items", [])
	var right_items: Array = _question.get("right_items", [])
	var font_size := UIScaleService.px(20)
	for i in range(left_items.size()):
		var button := Button.new()
		button.add_theme_font_size_override("font_size", font_size)
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = str(left_items[i])
		var index := i
		button.pressed.connect(func(): _on_match_left(index))
		match_left.add_child(button)
		_match_left_buttons.append(button)
	for i in range(right_items.size()):
		var button := Button.new()
		button.add_theme_font_size_override("font_size", font_size)
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = str(right_items[i])
		var index := i
		button.pressed.connect(func(): _on_match_right(index))
		match_right.add_child(button)
		_match_right_buttons.append(button)


func _on_mc_button(index: int) -> void:
	if _locked:
		return
	_locked = true
	var result := QuizManager.answer_current({"index": index})
	_handle_result(result, {"index": index})


func _on_tf_button(value: bool) -> void:
	if _locked:
		return
	_locked = true
	var result := QuizManager.answer_current({"value": value})
	_handle_result(result, {"value": value})


func _on_fill_text_confirm() -> void:
	if _locked:
		return
	_locked = true
	var result := QuizManager.answer_current({"text": fill_input.text})
	_handle_result(result, {"text": fill_input.text})


func _on_fill_tiles_confirm() -> void:
	if _locked:
		return
	_locked = true
	var placements: Dictionary = {}
	for i in range(_tile_slots.size()):
		placements[str(i)] = _tile_slots[i]
	var result := QuizManager.answer_current({"placements": placements})
	_handle_result(result, {"placements": placements})


func _on_matching_confirm() -> void:
	if _locked:
		return
	_locked = true
	var pairs: Array = []
	for left_index in _match_pairs.keys():
		pairs.append({
			"left_index": left_index,
			"right_index": _match_pairs[left_index],
		})
	var result := QuizManager.answer_current({"pairs": pairs})
	_handle_result(result, {"pairs": pairs})


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
	var left_items: Array = _question.get("left_items", [])
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


func _handle_result(result: Dictionary, submitted_answer: Dictionary) -> void:
	if _resolved:
		return
	_resolved = true
	timer_node.stop()
	_apply_visual_feedback(result, submitted_answer)
	await get_tree().create_timer(1.8).timeout
	visible = false
	answered.emit(result)
	queue_free()


func _apply_visual_feedback(result: Dictionary, submitted_answer: Dictionary) -> void:
	var correct := bool(result.get("correct", false))
	result_label.visible = true
	if correct:
		result_label.text = "Poprawnie!"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		correct_label.visible = false
	else:
		result_label.text = "Bledna odpowiedz!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_show_correct_answer()
	match str(_question.get("type", "multiple_choice")):
		"multiple_choice":
			var correct_index := int(result.get("correct_index", -1))
			if correct_index >= 0 and correct_index < mc_buttons.size():
				mc_buttons[correct_index].add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			var chosen_index := int(submitted_answer.get("index", -1))
			if not correct and chosen_index >= 0 and chosen_index < mc_buttons.size():
				mc_buttons[chosen_index].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		"true_false":
			var correct_index := int(result.get("correct_index", -1))
			if correct_index >= 0 and correct_index < tf_buttons.size():
				tf_buttons[correct_index].add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))


func _show_correct_answer() -> void:
	var qtype := str(_question.get("type", "multiple_choice"))
	match qtype:
		"fill_text":
			var values: Array[String] = [str(_question.get("answer", ""))]
			for alt in _question.get("accepted_alternatives", []):
				values.append(str(alt))
			correct_label.text = "Poprawne: %s" % ", ".join(values)
			correct_label.visible = true
		"fill_tiles":
			var values: Array[String] = []
			for gap in _question.get("gaps", []):
				values.append(str(gap.get("correct", "")))
			correct_label.text = "Poprawna kolejnosc: %s" % ", ".join(values)
			correct_label.visible = true
		"matching":
			var left_items: Array = _question.get("left_items", [])
			var right_items: Array = _question.get("right_items", [])
			var lines: Array[String] = []
			for pair in _question.get("pairs", []):
				var left_index := int(pair.get("left_index", -1))
				var right_index := int(pair.get("right_index", -1))
				if left_index >= 0 and left_index < left_items.size() and right_index >= 0 and right_index < right_items.size():
					lines.append("%s -> %s" % [str(left_items[left_index]), str(right_items[right_index])])
			correct_label.text = "Poprawne:\n%s" % "\n".join(lines)
			correct_label.visible = true
		_:
			correct_label.visible = false


func _on_timeout() -> void:
	if _resolved:
		return
	_locked = true
	var result: Dictionary
	match str(_question.get("type", "multiple_choice")):
		"multiple_choice":
			result = QuizManager.answer_current({"index": -1})
		"true_false":
			result = QuizManager.answer_current({"value": null})
		"fill_text":
			result = QuizManager.answer_current({"text": ""})
		"fill_tiles":
			result = QuizManager.answer_current({"placements": {}})
		"matching":
			result = QuizManager.answer_current({"pairs": []})
		_:
			result = {"correct": false}
	result["timed_out"] = true
	_handle_result(result, {})


func _default_hint() -> String:
	match str(_question.get("type", "multiple_choice")):
		"multiple_choice":
			return "W/S/A/D lub klikniecie"
		"true_false":
			return "W = Prawda, S = Falsz"
		"fill_text":
			return "Wpisz odpowiedz i nacisnij Enter"
		"fill_tiles":
			return "Klikaj kafle, Tab zmienia luke, Enter zatwierdza"
		"matching":
			return "Kliknij po lewej, potem po prawej, Enter zatwierdza"
		_:
			return ""


func _main_question_text() -> String:
	var qtype := str(_question.get("type", "multiple_choice"))
	match qtype:
		"true_false":
			return str(_question.get("statement", ""))
		"fill_text":
			return str(_question.get("prompt", ""))
		"fill_tiles":
			return str(_question.get("text_with_gaps", ""))
		_:
			return str(_question.get("question", _question.get("prompt", "")))
