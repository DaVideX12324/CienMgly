extends Node
class_name ModuleHost

signal module_started(module_id: String)
signal module_exited(module_id: String)
signal module_failed(module_id: String, reason: String)

var current_module: Node
var current_manifest: Dictionary = {}
var current_api: ModuleHostApi


func start_module(manifest: Dictionary, parent: Node) -> void:
	stop_module()

	var module_id := str(manifest.get("id", ""))
	var entry_path := str(manifest.get("entry_scene_path", ""))
	if entry_path == "":
		_fail(module_id, "Manifest has no entry_scene_path.")
		return

	var packed := load(entry_path)
	if not packed is PackedScene:
		_fail(module_id, "Entry scene cannot be loaded: %s" % entry_path)
		return

	current_manifest = manifest.duplicate(true)
	current_api = ModuleHostApi.new(module_id, str(manifest.get("root_path", "")), self)
	current_api.exit_requested.connect(_on_exit_requested)

	current_module = packed.instantiate()
	var core_manager = get_node_or_null("/root/CoreManager")
	if core_manager:
		core_manager.activate_module(module_id, current_module, current_api)
	parent.add_child(current_module)

	if current_module.has_signal("exit_requested"):
		current_module.connect("exit_requested", _on_module_exit_requested)

	if current_module.has_method("embedded_start"):
		current_module.call("embedded_start", current_api, current_manifest)

	module_started.emit(module_id)


func stop_module() -> void:
	if current_module and is_instance_valid(current_module):
		if current_module.has_method("embedded_stop"):
			current_module.call("embedded_stop")
		current_module.queue_free()
	var core_manager = get_node_or_null("/root/CoreManager")
	if core_manager:
		core_manager.deactivate_module()
	current_module = null
	current_manifest = {}
	current_api = null


func _fail(module_id: String, reason: String) -> void:
	push_warning("ModuleHost: %s" % reason)
	module_failed.emit(module_id, reason)


func _on_exit_requested(module_id: String) -> void:
	stop_module()
	module_exited.emit(module_id)


func _on_module_exit_requested() -> void:
	var module_id := str(current_manifest.get("id", ""))
	stop_module()
	module_exited.emit(module_id)
