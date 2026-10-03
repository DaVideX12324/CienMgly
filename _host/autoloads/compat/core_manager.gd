extends Node

signal module_loaded(module_id: String)
signal module_unloaded(module_id: String)

var _active_module_id := ""
var _active_module: Node
var _host_api
var _module_singletons: Dictionary = {}


func activate_module(module_id: String, module_node: Node, host_api = null) -> void:
	_active_module_id = module_id
	_active_module = module_node
	_host_api = host_api
	_module_singletons.clear()
	module_loaded.emit(module_id)


func deactivate_module() -> void:
	if _active_module_id != "":
		module_unloaded.emit(_active_module_id)
	_active_module_id = ""
	_active_module = null
	_host_api = null
	_module_singletons.clear()


func register_singleton(singleton_name: String, node: Node) -> void:
	_module_singletons[singleton_name] = node


func unregister_module_singletons() -> void:
	_module_singletons.clear()


func get_singleton(singleton_name: String) -> Node:
	return _module_singletons.get(singleton_name)


func get_active_module_id() -> String:
	return _active_module_id


func get_active_module() -> Node:
	return _active_module


func exit_active_module() -> void:
	if _host_api and _host_api.has_method("request_exit"):
		_host_api.request_exit()
