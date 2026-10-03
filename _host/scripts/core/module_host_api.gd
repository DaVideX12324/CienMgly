extends RefCounted
class_name ModuleHostApi

signal exit_requested(module_id: String)

var module_id := ""
var module_root := ""
var host_node: Node


func _init(p_module_id: String = "", p_module_root: String = "", p_host_node: Node = null) -> void:
	module_id = p_module_id
	module_root = p_module_root
	host_node = p_host_node


func path(relative_path: String) -> String:
	if relative_path.begins_with("res://") or relative_path.begins_with("user://"):
		return relative_path
	return "%s/%s" % [module_root, relative_path.trim_prefix("/")]


func asset_path(relative_path: String) -> String:
	return AssetService.path(module_id, relative_path)


func load_asset(relative_path: String, type_hint: String = "") -> Resource:
	return AssetService.load_asset(module_id, relative_path, type_hint)


func get_texture(relative_path: String) -> Texture2D:
	return AssetService.get_texture(module_id, relative_path)


func get_quiz_ids() -> Array:
	return QuizService.get_quiz_ids(module_id)


func start_quiz(
	quiz_id: String,
	difficulty_range: Vector2i = Vector2i(1, 5),
	count: int = 5,
	allowed_types: Array = [],
	session_id: String = "default"
) -> Dictionary:
	return QuizService.start_quiz(module_id, quiz_id, difficulty_range, count, allowed_types, session_id)


func answer_current_quiz(player_answer: Dictionary, session_id: String = "default") -> Dictionary:
	return QuizService.answer_current(module_id, player_answer, session_id)


func request_exit() -> void:
	exit_requested.emit(module_id)
