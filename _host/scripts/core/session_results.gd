extends RefCounted
class_name SessionResults

## Historia wyników sesji modułów (ModuleHostApi.finish_session) w user://.
## Moduł podaje słownik wyniku; host dopisuje module_id i finished_at (czas uniksowy).
## Pole "summary" (tekst przetłumaczony przez moduł) pokazuje menu hosta.

const DEFAULT_PATH := "user://artefakt_wiedzy_sessions.json"
const MAX_ENTRIES := 200

## Testy podmieniają ścieżkę, żeby nie pisać do historii użytkownika.
static var save_path := DEFAULT_PATH


static func record(module_id: String, result: Dictionary) -> Dictionary:
	var entry := result.duplicate(true)
	entry["module_id"] = module_id
	entry["finished_at"] = int(Time.get_unix_time_from_system())
	var history := _load()
	history.append(entry)
	if history.size() > MAX_ENTRIES:
		history = history.slice(history.size() - MAX_ENTRIES)
	_save(history)
	return entry


## Najnowsze na końcu; module_id "" = wszystkie moduły.
static func get_history(module_id: String = "") -> Array:
	var history := _load()
	if module_id == "":
		return history
	return history.filter(func(e: Dictionary) -> bool: return str(e.get("module_id", "")) == module_id)


static func get_last(module_id: String) -> Dictionary:
	var history := get_history(module_id)
	return history.back() if not history.is_empty() else {}


static func _load() -> Array:
	if not FileAccess.file_exists(save_path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Array:
		push_warning("SessionResults: niepoprawny plik %s" % save_path)
		return []
	return (parsed as Array).filter(func(e: Variant) -> bool: return e is Dictionary)


static func _save(history: Array) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SessionResults: nie można zapisać %s" % save_path)
		return
	file.store_string(JSON.stringify(history, "\t"))
