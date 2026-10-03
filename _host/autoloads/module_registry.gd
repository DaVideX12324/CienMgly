extends Node

signal modules_changed

const MODULES_ROOT := "res://_host/modules"
## Moduł otwarty samodzielnie (repo modułu jako projekt Godota) ma manifest w korzeniu projektu.
const STANDALONE_ROOT := "res://"
const MANIFEST_FILE := "module_manifest.json"
const REQUIRED_FIELDS := ["id", "name", "entry_scene"]

var _modules: Array[Dictionary] = []


func _ready() -> void:
	reload()


func reload() -> void:
	_modules.clear()
	var standalone := _load_manifest(STANDALONE_ROOT)
	if not standalone.is_empty():
		_modules.append(standalone)
	var dir := DirAccess.open(MODULES_ROOT)
	if dir == null:
		if standalone.is_empty():
			push_warning("ModuleRegistry: missing modules folder: %s" % MODULES_ROOT)
		_register_modules_in_services()
		modules_changed.emit()
		return

	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and not folder_name.begins_with("_"):
			var root_path := "%s/%s" % [MODULES_ROOT, folder_name]
			var manifest := _load_manifest(root_path)
			if not manifest.is_empty():
				_modules.append(manifest)
		folder_name = dir.get_next()
	dir.list_dir_end()

	_modules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	_register_modules_in_services()
	modules_changed.emit()


func all() -> Array[Dictionary]:
	return _modules.duplicate(true)


func get_by_id(module_id: String) -> Dictionary:
	for module in _modules:
		if module.get("id", "") == module_id:
			return module.duplicate(true)
	return {}


func _load_manifest(root_path: String) -> Dictionary:
	var manifest_path := "%s/%s" % [root_path.trim_suffix("/"), MANIFEST_FILE]
	if not FileAccess.file_exists(manifest_path):
		return {}

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		push_warning("ModuleRegistry: cannot read %s" % manifest_path)
		return {}

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or not (json.data is Dictionary):
		push_warning("ModuleRegistry: invalid manifest %s" % manifest_path)
		return {}

	var manifest: Dictionary = json.data
	for field in REQUIRED_FIELDS:
		if not manifest.has(field):
			push_warning("ModuleRegistry: %s misses field '%s'" % [manifest_path, field])
			return {}

	manifest["root_path"] = root_path
	manifest["manifest_path"] = manifest_path
	manifest["entry_scene_path"] = _resolve_module_path(root_path, manifest["entry_scene"])
	return manifest


func _resolve_module_path(root_path: String, value: String) -> String:
	if value.begins_with("res://") or value.begins_with("user://"):
		return value
	return "%s/%s" % [root_path.trim_suffix("/"), value.trim_prefix("/")]


func _register_modules_in_services() -> void:
	for manifest in _modules:
		AssetService.register_module(manifest)
		QuizService.register_module(manifest)
