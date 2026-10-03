extends Node

signal asset_root_registered(module_id: String, root_path: String)

const DEFAULT_ASSET_ROOT := "assets"

var _asset_roots: Dictionary = {}


func register_root(module_id: String, root_path: String) -> void:
	_asset_roots[module_id] = root_path.trim_suffix("/")
	asset_root_registered.emit(module_id, root_path)


func register_module(manifest: Dictionary) -> void:
	var module_id := str(manifest.get("id", ""))
	var root_path := str(manifest.get("root_path", ""))
	var asset_path := str(manifest.get("asset_path", DEFAULT_ASSET_ROOT))
	if module_id == "" or root_path == "":
		return
	register_root(module_id, _join_path(root_path, asset_path))


func path(module_id: String, relative_path: String) -> String:
	if relative_path.begins_with("res://") or relative_path.begins_with("user://"):
		return relative_path
	return "%s/%s" % [str(_asset_roots.get(module_id, "")).trim_suffix("/"), relative_path.trim_prefix("/")]


func exists(module_id: String, relative_path: String, type_hint: String = "") -> bool:
	return ResourceLoader.exists(path(module_id, relative_path), type_hint)


func load_asset(module_id: String, relative_path: String, type_hint: String = "") -> Resource:
	var full_path := path(module_id, relative_path)
	if ResourceLoader.exists(full_path, type_hint):
		return load(full_path)
	return null


func get_texture(module_id: String, relative_path: String) -> Texture2D:
	return load_asset(module_id, relative_path, "Texture2D") as Texture2D


func apply_texture_or_fallback(
	module_id: String,
	sprite: Sprite2D,
	fallback_node: Node,
	relative_path: String
) -> bool:
	var texture := get_texture(module_id, relative_path)
	if texture:
		sprite.texture = texture
		sprite.visible = true
		if fallback_node:
			fallback_node.visible = false
		return true

	sprite.visible = false
	if fallback_node:
		fallback_node.visible = true
	return false


func _join_path(root_path: String, relative_path: String) -> String:
	if relative_path.begins_with("res://") or relative_path.begins_with("user://"):
		return relative_path
	return "%s/%s" % [root_path.trim_suffix("/"), relative_path.trim_prefix("/")]
