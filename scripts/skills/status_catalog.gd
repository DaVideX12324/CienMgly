extends RefCounted
class_name QuizRpgStatusCatalog

## Katalog statusów (resources/statuses/*.tres, QuizRpgStatusData) — wczytany raz, po status_id.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const DIR := "resources/statuses"

static var _by_id: Dictionary = {}


static func get_status(id: String) -> QuizRpgStatusData:
	_ensure()
	return _by_id.get(id) as QuizRpgStatusData


static func name_of(id: String) -> String:
	var st := get_status(id)
	return st.display_name if st else id


static func color_of(id: String, fallback: Color = Color.WHITE) -> Color:
	var st := get_status(id)
	return st.color if st else fallback


static func all_ids() -> Array:
	_ensure()
	return _by_id.keys()


static func _ensure() -> void:
	if not _by_id.is_empty():
		return
	var dir := QuizRpgPaths.path(DIR)
	for f in ResourceLoader.list_directory(dir):
		if not (f.ends_with(".tres") or f.ends_with(".res")):
			continue
		var st := load(dir.path_join(f)) as QuizRpgStatusData
		if st != null and st.status_id != "":
			_by_id[st.status_id] = st
