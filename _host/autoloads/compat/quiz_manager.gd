extends Node

const DEFAULT_SESSION := "compat"


func _get_effective_module_id() -> String:
	var module_id := CoreManager.get_active_module_id()
	if module_id != "":
		return module_id
	return "quiz_rpg"


func start_quiz(
	quiz_id: String,
	difficulty_range: Vector2i = Vector2i(1, 5),
	count: int = 5,
	allowed_types: Array = []
) -> Dictionary:
	var module_id := _get_effective_module_id()
	var effective_types := allowed_types
	if effective_types.is_empty():
		effective_types = ["multiple_choice"]
	return QuizService.start_quiz(module_id, quiz_id, difficulty_range, count, effective_types, DEFAULT_SESSION)


func answer_current(player_answer: Dictionary) -> Dictionary:
	var module_id := _get_effective_module_id()
	return QuizService.answer_current(module_id, player_answer, DEFAULT_SESSION)


func get_questions(
	quiz_id: String,
	difficulty_range: Vector2i = Vector2i(1, 5),
	count: int = 5,
	allowed_types: Array = []
) -> Array:
	var module_id := _get_effective_module_id()
	return QuizService.get_questions(module_id, quiz_id, difficulty_range, count, allowed_types)


func get_current_question() -> Dictionary:
	var module_id := _get_effective_module_id()
	return QuizService.get_current_question(module_id, DEFAULT_SESSION)


func get_question_display_text(question: Dictionary) -> String:
	return QuizService.get_question_display_text(question)


func get_question_hint(question: Dictionary) -> String:
	return QuizService.get_question_hint(question)


func get_question_time_limit(question: Dictionary, base_time: float = 16.0, base_difficulty: int = 1) -> float:
	return QuizService.get_question_time_limit(question, base_time, base_difficulty)


func get_timeout_answer(question: Dictionary) -> Dictionary:
	return QuizService.get_timeout_answer(question)


func get_correct_answer_text(question: Dictionary) -> String:
	return QuizService.get_correct_answer_text(question)


func get_quiz_ids() -> Array:
	var module_id := _get_effective_module_id()
	return QuizService.get_quiz_ids(module_id)


func start_custom_questions(questions: Array, quiz_id: String = "custom") -> Dictionary:
	var module_id := _get_effective_module_id()
	return QuizService.start_custom_questions(module_id, questions, quiz_id, DEFAULT_SESSION)


func get_save_data() -> Dictionary:
	var module_id := _get_effective_module_id()
	return QuizService.get_save_data(module_id)


func load_save_data(data: Dictionary) -> void:
	var module_id := _get_effective_module_id()
	QuizService.load_save_data(module_id, data)


func reset() -> void:
	var module_id := _get_effective_module_id()
	QuizService.reset_module(module_id)


func get_overall_accuracy() -> float:
	var module_id := _get_effective_module_id()
	return QuizService.get_overall_accuracy(module_id)


func get_accuracy_for_category(category: String) -> float:
	var module_id := _get_effective_module_id()
	return QuizService.get_accuracy_for_category(module_id, category)
