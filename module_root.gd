extends Node

signal exit_requested

const START_SCENE := "res://modules/quiz_rpg/scenes/ui/main_menu.tscn"

var _host_api = null
var _manifest: Dictionary = {}
var _scene_root: Node
var _current_scene: Node


func _ready() -> void:
	_scene_root = get_node_or_null("SceneRoot")
	if _scene_root == null:
		_scene_root = Node.new()
		_scene_root.name = "SceneRoot"
		add_child(_scene_root)
	_register_singletons()
	open_scene(START_SCENE)


func embedded_start(host_api, manifest: Dictionary = {}) -> void:
	_host_api = host_api
	_manifest = manifest.duplicate(true)


func embedded_stop() -> void:
	get_tree().paused = false


func open_scene(scene_path: String) -> void:
	var packed := load(scene_path)
	if not packed is PackedScene:
		push_warning("QuizRPG module: cannot load scene %s" % scene_path)
		return

	if _current_scene and is_instance_valid(_current_scene):
		_current_scene.queue_free()

	_current_scene = packed.instantiate()
	_scene_root.add_child(_current_scene)


func exit_module() -> void:
	get_tree().paused = false
	if _host_api and _host_api.has_method("request_exit"):
		_host_api.request_exit()
		return
	exit_requested.emit()


func _register_singletons() -> void:
	var core_manager := get_node_or_null("/root/CoreManager")
	var use_core_manager := core_manager != null and core_manager.has_method("register_singleton")
	for singleton_name in ["GameManager", "DifficultyManager", "PlayerStats"]:
		var singleton_node := get_node_or_null(singleton_name)
		if not singleton_node:
			continue
		if use_core_manager:
			core_manager.call("register_singleton", singleton_name, singleton_node)
		else:
			Engine.register_singleton(singleton_name, singleton_node)
