extends Control

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
static var QuizPanelController: Script = load(QuizRpgPaths.host("res://scripts/shared/quiz/quiz_panel_controller.gd"))

## UI zagadki quizowej — drzwi / przejścia / skrzynie (wytrych). Jedno okno w stylu walki: pytanie, czas,
## odpowiedzi jako pozycje menu (kursor WASD / strzałki + Enter / Z / spacja, klik, klawisze 1–4) —
## ten sam QuizPanelController co w walce. Zamiast HP wroga pasek postępu „odblokowania”.

signal puzzle_finished(success: bool)

var door: Node2D
var player: Node2D
var required_correct: int = 3
var current_correct: int = 0
var current_question: int = 0
var total_questions: int = 5
var _finished: bool = false
## Tryb szansy (required <= 0, np. skrzynia z wytrychem): padają wszystkie pytania, a otwarcie jest losowane z szansą
## = poprawne / wszystkie. Inaczej (drzwi) — trzeba zebrać required_correct poprawnych.
var _chance_mode := false

var _quiz_id: String
var _category: String
var _diff_range := Vector2i(1, 3)
var _qp  # QuizPanelController

@onready var _command_vbox: VBoxContainer = $Window/Margin/CommandVBox
@onready var title_label: Label = $Window/Margin/CommandVBox/TitleLabel
@onready var progress_bar: ProgressBar = $Window/Margin/CommandVBox/ProgressRow/ProgressBar
@onready var progress_label: Label = $Window/Margin/CommandVBox/ProgressRow/ProgressLabel
@onready var _timer_row: Control = $Window/Margin/CommandVBox/TimerRow
@onready var _result_label: Label = $Window/Margin/CommandVBox/ResultLabel

# Singletony
var _ps: Node   # PlayerStats
var _dm: Node   # DifficultyManager


func setup(p_door: Node2D, p_player: Node2D, quiz_id: String,
		category: String, p_total: int, p_required: int) -> void:
	door = p_door
	player = p_player
	_quiz_id = quiz_id
	_category = category
	total_questions = p_total
	required_correct = p_required
	_chance_mode = p_required <= 0


func _ready() -> void:
	if get_parent() is CanvasLayer:
		UiLayerScale.attach(get_parent() as CanvasLayer)  # skala UI z opcji na całą warstwę
	theme = QuizTheme.combat_theme()  # ten sam motyw i rozmiar tekstu co w walce
	_ps = CoreManager.get_singleton("PlayerStats")
	_dm = CoreManager.get_singleton("DifficultyManager")

	_qp = QuizPanelController.new()
	_qp.text_size = QuizTheme.COMBAT_FONT_SIZE
	_qp.setup(_command_vbox, {
		"question_label": $Window/Margin/CommandVBox/QuestionLabel,
		"timer_label": $Window/Margin/CommandVBox/TimerRow/TimerLabel,
		"timer_bar": $Window/Margin/CommandVBox/TimerRow/TimerBar,
		"result_label": _result_label,
		"correct_answer_label": $Window/Margin/CommandVBox/CorrectAnswerLabel,
	})
	_qp.answered.connect(_on_answered)
	_qp.show_index_prefix = false
	_qp.selection_styler = func(btn: Button, selected: bool) -> void:
		QuizTheme.set_menu_item_selected(btn, selected)
	# Opcje -> Motyw: „Odpowiedzi w walce” — lista albo siatka 2×2, jak w walce.
	(_qp.mc_box as GridContainer).columns = 2 if QuizTheme.answers_layout() == QuizTheme.ANSWERS_GRID else 1

	if door and "door_name" in door:
		title_label.text = "🔒 " + QuizRpgI18n.t(str(door.door_name), str(door.door_name))
	else:
		title_label.text = "🔒 " + QuizRpgI18n.t("ui.puzzle.title", "Zagadka")

	if _dm:
		_diff_range = _dm.get_difficulty_range(_category)

	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and cheat_service.has_signal("instant_win_triggered"):
		cheat_service.instant_win_triggered.connect(trigger_instant_win)

	_update_progress()
	if _should_auto_solve_puzzle(_diff_range):
		trigger_instant_win()
		return

	var first_q: Dictionary = QuizManager.start_quiz(_quiz_id, _diff_range, total_questions)
	if first_q.is_empty():
		push_warning("QuizPuzzle: Brak pytań!")
		puzzle_finished.emit(false)
		get_parent().queue_free()
		return
	_qp.start_question(first_q, _diff_range.x)


func _process(delta: float) -> void:
	if _qp:
		_qp.tick(delta)


func trigger_instant_win() -> void:
	current_correct = required_correct
	current_question = total_questions
	_update_progress()
	_finish(true)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F9:
		trigger_instant_win()
		get_viewport().set_input_as_handled()
		return
	if _qp and _qp.handle_input(event):
		get_viewport().set_input_as_handled()


func _should_auto_solve_puzzle(diff_range: Vector2i) -> bool:
	if _is_quizless_mode_enabled():
		return true
	var available_questions: Array = QuizManager.get_questions(_quiz_id, diff_range, total_questions)
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


func _on_answered(result: Dictionary, submitted_answer: Dictionary) -> void:
	if _finished:
		return
	var correct: bool = result.get("correct", false)
	var category: String = _category if _category != "" else "ogolne"
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("correct" if correct else "wrong")
	if _ps:
		if correct:
			_ps.on_correct_answer()
		else:
			_ps.on_wrong_answer()
	if _dm:
		_dm.record_answer(category, correct)
	_qp.show_feedback(result, submitted_answer)

	if correct:
		current_correct += 1
	current_question += 1
	_update_progress()

	await get_tree().create_timer(1.2).timeout
	if _finished or not is_inside_tree():
		return

	var remaining := total_questions - current_question
	if _chance_mode:
		if remaining <= 0 or result.get("quiz_finished", false):
			_finish(randf() < _chance())
			return
		var next_chance_q: Dictionary = QuizManager.get_current_question()
		if next_chance_q.is_empty():
			_finish(randf() < _chance())
		else:
			_qp.start_question(next_chance_q, _diff_range.x)
		return
	if current_correct >= required_correct:
		_finish(true)
	elif current_correct + remaining < required_correct:
		_finish(false)  # już się nie da — bez pytań „na pokaz”
	elif remaining <= 0 or result.get("quiz_finished", false):
		_finish(false)
	else:
		var next_q: Dictionary = QuizManager.get_current_question()
		if next_q.is_empty():
			_finish(false)
		else:
			_qp.start_question(next_q, _diff_range.x)


## Szansa otwarcia w trybie szansy: poprawne / wszystkie pytania.
func _chance() -> float:
	return float(current_correct) / float(maxi(total_questions, 1))


func _update_progress() -> void:
	if _chance_mode:
		if progress_bar:
			progress_bar.value = _chance() * 100.0
		if progress_label:
			progress_label.text = QuizRpgI18n.tf("puzzle.chance", {"chance": roundi(_chance() * 100.0), "correct": current_correct, "total": total_questions}, "Szansa na otwarcie: {chance}% ({correct} / {total})")
		return
	var shown := mini(current_correct, required_correct)
	if progress_bar:
		progress_bar.value = (float(shown) / float(maxi(required_correct, 1))) * 100.0
	if progress_label:
		progress_label.text = QuizRpgI18n.tf("puzzle.progress", {"correct": shown, "required": required_correct}, "{correct} / {required} poprawnych odpowiedzi")


func _finish(success: bool) -> void:
	if _finished:
		return
	_finished = true
	_qp.hide_quiz()
	_timer_row.visible = false
	_qp.question_label.visible = false
	_qp.correct_answer_label.visible = false
	var audio := get_node_or_null("/root/AudioService")
	_result_label.visible = true
	if success:
		if audio:
			audio.play_sfx_by_name("victory")
		_result_label.text = "🔓 " + QuizRpgI18n.t("puzzle.opened", "Otwarto!")
		_result_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		if audio:
			audio.play_sfx_by_name("defeat")
		_result_label.text = "🔒 " + QuizRpgI18n.t("puzzle.failed_to_open", "Nie udało się otworzyć...")
		_result_label.add_theme_color_override("font_color", Color.RED)

	await get_tree().create_timer(1.0).timeout
	puzzle_finished.emit(success)
	get_parent().queue_free()
