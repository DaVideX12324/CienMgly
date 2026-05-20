extends Node

const DEFAULT_SESSION := "compat"


func start_quiz(
	quiz_id: String,
	difficulty_range: Vector2i = Vector2i(1, 5),
	count: int = 5,
	allowed_types: Array = []
) -> Dictionary:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return {}
	var effective_types := allowed_types
	if effective_types.is_empty():
		effective_types = ["multiple_choice"]
	return QuizService.start_quiz(module_id, quiz_id, difficulty_range, count, effective_types, DEFAULT_SESSION)


func answer_current(player_answer: Dictionary) -> Dictionary:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return {}
	return QuizService.answer_current(module_id, player_answer, DEFAULT_SESSION)


func get_current_question() -> Dictionary:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return {}
	return QuizService.get_current_question(module_id, DEFAULT_SESSION)


func get_quiz_ids() -> Array:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return []
	return QuizService.get_quiz_ids(module_id)


func get_save_data() -> Dictionary:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return {}
	return QuizService.get_save_data(module_id)


func load_save_data(data: Dictionary) -> void:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return
	QuizService.load_save_data(module_id, data)


func reset() -> void:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return
	QuizService.reset_module(module_id)


func get_overall_accuracy() -> float:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return 0.5
	return QuizService.get_overall_accuracy(module_id)


func get_accuracy_for_category(category: String) -> float:
	var module_id := CoreManager.get_active_module_id()
	if module_id == "":
		return 0.5
	return QuizService.get_accuracy_for_category(module_id, category)
