extends Node
class_name ModuleHost

signal module_started(module_id: String)
signal module_exited(module_id: String)
signal module_failed(module_id: String, reason: String)
## Moduł prosi o wyjście, ale jeszcze działa — host zasłania ekran, zanim go wyłączy (potem module_exited).
signal module_exiting(module_id: String)
## Wynik sesji modułu (już zapisany w SessionResults, z module_id i finished_at).
signal module_session_finished(module_id: String, result: Dictionary)

var current_module: Node
var current_manifest: Dictionary = {}
var current_api: ModuleHostApi


func start_module(manifest: Dictionary, parent: Node, session_config: Dictionary = {}) -> void:
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
	current_api = ModuleHostApi.new(module_id, str(manifest.get("root_path", "")), self, session_config)
	current_api.exit_requested.connect(_on_exit_requested)
	current_api.session_finished.connect(_on_session_finished)

	current_module = packed.instantiate()
	var core_manager = get_node_or_null("/root/CoreManager")
	if core_manager:
		core_manager.activate_module(module_id, current_module, current_api)
	parent.add_child(current_module)

	if current_module.has_signal("exit_requested"):
		current_module.connect("exit_requested", _on_module_exit_requested)

	if current_module.has_method("embedded_start"):
		current_module.call("embedded_start", current_api, current_manifest)

	# Zmienione klawisze modułu po jego starcie — moduł mógł dopisać własne domyślne (BitBomber).
	InputBinds.apply_module(get_node_or_null("/root/SettingsService"), module_id)

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


func _on_session_finished(module_id: String, result: Dictionary) -> void:
	module_session_finished.emit(module_id, SessionResults.record(module_id, result))


func _on_exit_requested(module_id: String) -> void:
	_finish_exit(module_id)


func _on_module_exit_requested() -> void:
	_finish_exit(str(current_manifest.get("id", "")))


## Wyjście w dwóch krokach: sygnał module_exiting (ekran przejścia) i klatki na jego narysowanie, dopiero potem
## wyłączenie modułu — ciężkie zwalnianie sceny dzieje się pod zasłoną.
func _finish_exit(module_id: String) -> void:
	module_exiting.emit(module_id)
	await get_tree().process_frame
	await ModuleTransition.after_draw(get_tree())
	stop_module()
	module_exited.emit(module_id)
