class_name ModuleUtils
extends RefCounted

## Wrapper na CoreManager bezpieczny w trybie standalone.
## Zamiast CoreManager.get_singleton("X") pisz ModuleUtils.get_singleton("X").
## Dziala zarowno w hoscie (CoreManager jako autoload) jak i standalone (Engine.register_singleton).


## Pobiera singleton modulu.
static func get_singleton(singleton_name: String) -> Node:
	if Engine.has_singleton("CoreManager"):
		return Engine.get_singleton("CoreManager").get_singleton(singleton_name)
	if Engine.has_singleton(singleton_name):
		return Engine.get_singleton(singleton_name)
	return null


## Zwraca ID aktywnego modulu (pusty string w standalone).
static func get_active_module_id() -> String:
	if Engine.has_singleton("CoreManager"):
		return Engine.get_singleton("CoreManager").get_active_module_id()
	return ""


## Zwraca aktywny modul (null w standalone).
static func get_active_module() -> Node:
	if Engine.has_singleton("CoreManager"):
		return Engine.get_singleton("CoreManager").get_active_module()
	return null


## Wychodzi z aktywnego modulu lub konczy drzewo scen w standalone.
static func exit_module(tree: SceneTree = null) -> void:
	if Engine.has_singleton("CoreManager"):
		Engine.get_singleton("CoreManager").exit_active_module()
		return
	if tree:
		tree.quit()
