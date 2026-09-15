# res://modules/quiz_rpg/tests/check_parse.gd
# Uruchomienie:
#   godot --headless --path . --script res://modules/quiz_rpg/tests/check_parse.gd
extends SceneTree

const ROOTS: Array[String] = [
	"res://modules/quiz_rpg/scripts",
	"res://modules/quiz_rpg/tests",
]

func _initialize() -> void:
	var files: Array[String] = []
	for root in ROOTS:
		_collect(root, files)
	files.sort()

	var failed: Array[String] = []
	for path in files:
		if not _parses(path):
			failed.append(path)

	print("check_parse: sprawdzono %d plików, błędów: %d" % [files.size(), failed.size()])
	for f in failed:
		print("  BŁĄD PARSOWANIA: ", f)
	quit(1 if not failed.is_empty() else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect(dir_path.path_join(name), out)
		elif name.ends_with(".gd"):
			out.append(dir_path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()


func _parses(path: String) -> bool:
	var res = load(path)
	if res == null or not (res is GDScript):
		return false
	var sc: GDScript = res as GDScript
	return sc.can_instantiate()
