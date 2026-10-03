extends Node
## Start wersji samodzielnej (repo modułu otwarte jako projekt, główna scena w project.godot.off).
## Uruchamia moduł tak jak Artefakt Wiedzy: ModuleHost z kopii hosta (_host/) i manifest z ModuleRegistry
## (manifest w korzeniu projektu). Wyjście z modułu zamyka grę. W hoście ta scena nie jest używana.

const QuizRpgPaths = preload("../scripts/quiz_rpg_paths.gd")
const MODULE_ID := "quiz_rpg"


func _ready() -> void:
	var registry := get_node_or_null("/root/ModuleRegistry")
	var manifest: Dictionary = registry.call("get_by_id", MODULE_ID) if registry else {}
	if manifest.is_empty():
		push_error("Quiz RPG (samodzielnie): ModuleRegistry nie widzi manifestu %s" % MODULE_ID)
		get_tree().quit(1)
		return
	var module_host: Node = (load(QuizRpgPaths.host("res://scripts/core/module_host.gd")) as Script).new()
	module_host.name = "ModuleHost"
	add_child(module_host)
	module_host.connect("module_exited", func(_id: String) -> void: get_tree().quit())
	module_host.connect("module_failed", func(_id: String, reason: String) -> void:
		push_error("Quiz RPG (samodzielnie): %s" % reason)
		get_tree().quit(1))
	module_host.call("start_module", manifest, self)
