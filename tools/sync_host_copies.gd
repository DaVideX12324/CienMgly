extends SceneTree
## Kopie zasobów hosta dla wersji samodzielnej modułu: modules/quiz_rpg/_host/ (+ project.godot.off).
##
## Uruchamiać w Artefakcie Wiedzy (host = źródło prawdy, zmiany robimy w hoście i co jakiś czas synchronizujemy):
##   Godot --headless --path <host> -s res://modules/quiz_rpg/tools/sync_host_copies.gd [-- --dry-run]
##
## Zakres kopii = domknięcie zależności od:
##   - odwołań w plikach modułu (ścieżki "res://…" / "uid://…" w cudzysłowach, klasy globalne hosta),
##   - project.godot hosta (autoloady poza modules/, czcionka motywu, ikona).
## Zależności plików: ścieżki w cudzysłowach (.gd/.tscn/.tres/.json/…), względne preload/extends,
## klasy globalne (class_name) i get_dependencies dla binarnych zasobów; do plików dochodzą .import / .uid.
## W skopiowanych plikach tekstowych "res://X" -> "res://_host/X" (poza modules/ i .godot/). UID-y kopii są
## takie same jak oryginałów, więc sceny modułu trafiają w kopie po UID. _host/ ma .gdignore — host go nie widzi.
## Wersja samodzielna: tools/make_standalone.sh (zdejmuje .gdignore, project.godot.off -> project.godot).

const MODULE_DIR := "res://modules/quiz_rpg"
const COPIES_DIR := "res://modules/quiz_rpg/_host"
## Foldery modułu pomijane przy szukaniu odwołań (narzędzia edytora i diagnostyki działają tylko w hoście).
const SKIP_MODULE_DIRS := ["_host", "tests", "tools", ".godot"]
const TEXT_EXTS := ["gd", "tscn", "tres", "json", "cfg", "gdshader", "import", "godot", "off", "txt", "md", "uid"]
## Folder wskazany ścieżką (np. res://resources/quizzes) kopiujemy cały — o ile jest mały.
const MAX_DIR_FILES := 200
## Uruchomienie z repo modułu otwartego samodzielnie: główna scena i nazwa projektu.
const STANDALONE_MAIN_SCENE := "res://modules/quiz_rpg/standalone/standalone_main.tscn"
const STANDALONE_NAME := "Cień Mgły"
const STANDALONE_DESCRIPTION := "Cień Mgły — edukacyjna gra RPG z quizami (moduł quiz_rpg Artefaktu Wiedzy uruchomiony samodzielnie)."

var _quoted_re := RegEx.create_from_string("\"[*]?(res://[^\"]+|uid://[a-z0-9]+)\"|'(res://[^']+|uid://[a-z0-9]+)'")
var _relative_re := RegEx.create_from_string("(?:preload|extends|load)\\s*\\(?\\s*\"((?!res://|uid://|user://)[^\"]+)\"|\\bpath=\"((?!res://|uid://)[^\"]+)\"")
var _ident_re := RegEx.create_from_string("\\b[A-Z][A-Za-z0-9_]*\\b")
var _rewrite_re := RegEx.create_from_string("res://(?!modules/|_host/|\\.godot/)(?=[^\"'\\s])")

var _host_classes := {}  # class_name -> ścieżka skryptu w hoście (poza modules/)
var _files := {}         # ścieżka res:// -> true (pliki do skopiowania, z .import / .uid)
var _missing := {}       # ścieżka -> skąd
var _big_dirs := {}


func _initialize() -> void:
	var dry_run := "--dry-run" in OS.get_cmdline_user_args()
	for c in ProjectSettings.get_global_class_list():
		var p := str(c["path"])
		if p.begins_with("res://") and not p.begins_with("res://modules/"):
			_host_classes[str(c["class"])] = p

	var project_text := _standalone_project_text(FileAccess.get_file_as_string("res://project.godot"))
	var queue: Array = []
	_collect_refs(project_text, "res://project.godot", queue)
	_scan_module(MODULE_DIR, queue)
	_closure(queue)

	var total_size := 0
	for p in _files:
		total_size += _file_size(p)
	print("Kopie hosta: %d plików, %.1f MB" % [_files.size(), total_size / 1048576.0])
	for d in _big_dirs:
		print("  POMINIĘTY duży folder: %s (%d plików) <- %s" % [d, _big_dirs[d][0], _big_dirs[d][1]])
	for m in _missing:
		print("  brak pliku: %s <- %s" % [m, _missing[m]])
	if dry_run:
		var keys := _files.keys()
		keys.sort()
		for p in keys:
			print("  ", p)
		quit()
		return

	_remove_dir(ProjectSettings.globalize_path(COPIES_DIR))
	for p in _files:
		_copy(p)
	_store(COPIES_DIR + "/.gdignore", "")
	_store(MODULE_DIR + "/project.godot.off", _rewrite(project_text))
	print("Zapisano %s i %s/project.godot.off" % [COPIES_DIR, MODULE_DIR])
	quit()


# --- Zakres kopii -------------------------------------------------------------------------------

func _scan_module(dir: String, queue: Array) -> void:
	for d in DirAccess.get_directories_at(dir):
		if dir == MODULE_DIR and d in SKIP_MODULE_DIRS:
			continue
		_scan_module(dir.path_join(d), queue)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in TEXT_EXTS and f != "project.godot.off":  # .off generujemy tutaj
			var p := dir.path_join(f)
			_collect_refs(FileAccess.get_file_as_string(p), p, queue)


## Odwołania z tekstu pliku `from`: ścieżki w cudzysłowach, ścieżki względne, klasy globalne hosta.
func _collect_refs(text: String, from: String, queue: Array) -> void:
	for m in _quoted_re.search_all(text):
		queue.append([m.get_string(1) if m.get_string(1) != "" else m.get_string(2), from])
	if from.get_extension() in ["gd", "tscn", "tres"]:
		for m in _relative_re.search_all(text):
			var rel := m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
			queue.append([from.get_base_dir().path_join(rel).simplify_path(), from])
	if from.get_extension() == "gd":
		var seen := {}
		for m in _ident_re.search_all(text):
			var ident := m.get_string()
			if _host_classes.has(ident) and not seen.has(ident):
				seen[ident] = true
				queue.append([_host_classes[ident], from])


func _closure(queue: Array) -> void:
	while not queue.is_empty():
		var item: Array = queue.pop_back()
		var p := _resolve(str(item[0]))
		var from := str(item[1])
		if p == "" or p == "res://modules" or p.begins_with("res://modules/") or p.begins_with("res://.godot/") or _files.has(p):
			continue
		if DirAccess.dir_exists_absolute(p):
			var listed: Array = []
			_list_files(p, listed)
			if listed.size() > MAX_DIR_FILES:
				_big_dirs[p] = [listed.size(), from]
				continue
			for f in listed:
				queue.append([f, from])
			continue
		if not FileAccess.file_exists(p):
			if not _missing.has(p):
				_missing[p] = from
			continue
		_files[p] = true
		for side in [p + ".import", p + ".uid"]:
			if FileAccess.file_exists(side):
				_files[side] = true
		var ext := p.get_extension()
		if ext in TEXT_EXTS:
			_collect_refs(FileAccess.get_file_as_string(p), p, queue)
		elif ext in ["res", "scn"]:
			for dep in ResourceLoader.get_dependencies(p):
				queue.append([str(dep).get_slice("::", 0) if not str(dep).contains("::") else str(dep).get_slice("::", 2), p])


## uid://… -> ścieżka; obcina końcówki typu "::Typ". "" dla ścieżek spoza res://.
func _resolve(p: String) -> String:
	if p.begins_with("uid://"):
		var id := ResourceUID.text_to_id(p)
		return ResourceUID.get_id_path(id) if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id) else ""
	if not p.begins_with("res://"):
		return ""
	return p.trim_suffix("/")


func _list_files(dir: String, out: Array) -> void:
	for d in DirAccess.get_directories_at(dir):
		_list_files(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() not in ["import", "uid"]:
			out.append(dir.path_join(f))


# --- project.godot wersji samodzielnej ----------------------------------------------------------

## project.godot hosta bez modułów (autoloady i wtyczki z modules/), z nazwą i główną sceną modułu.
## Ścieżki zostają w formie hosta — _rewrite() przenosi je do _host/ przy zapisie.
func _standalone_project_text(text: String) -> String:
	var out := PackedStringArray([
		"; Wygenerowane przez modules/quiz_rpg/tools/sync_host_copies.gd z project.godot Artefaktu Wiedzy —",
		"; nie edytować ręcznie (zmiany w hoście, potem ponowna synchronizacja).",
	])
	var section := ""
	for line in text.split("\n"):
		line = line.trim_suffix("\r")
		if line.begins_with("[") and line.ends_with("]"):
			section = line
		if section == "[editor_plugins]":
			continue
		if section == "[autoload]" and line.contains("res://modules/"):
			continue
		if section == "[application]":
			if line.begins_with("config/name="):
				line = "config/name=\"%s\"" % STANDALONE_NAME
			elif line.begins_with("config/description="):
				line = "config/description=\"%s\"" % STANDALONE_DESCRIPTION
			elif line.begins_with("run/main_scene="):
				line = "run/main_scene=\"%s\"" % ResourceUID.id_to_text(ResourceLoader.get_resource_uid(STANDALONE_MAIN_SCENE))
		out.append(line)
	return "\n".join(out)


# --- Zapis --------------------------------------------------------------------------------------

func _rewrite(text: String) -> String:
	return _rewrite_re.sub(text, "res://_host/", true)


func _copy(p: String) -> void:
	var dst := COPIES_DIR.path_join(p.trim_prefix("res://"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.get_base_dir()))
	if p.get_extension() == "import":
		# Nazwa pliku w .godot/imported zawiera md5 ścieżki źródła — przeliczona dla nowej ścieżki,
		# żeby pierwszy import wersji samodzielnej nie przepisywał wszystkich .import.
		var source := p.trim_suffix(".import")
		var text := _rewrite(FileAccess.get_file_as_string(p))
		_store(dst, text.replace(source.md5_text(), _rewrite("\"%s\"" % source).trim_prefix("\"").trim_suffix("\"").md5_text()))
	elif p.get_extension() in TEXT_EXTS:
		_store(dst, _rewrite(FileAccess.get_file_as_string(p)))
	else:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(p), ProjectSettings.globalize_path(dst))


## Tekst zawsze z LF (repo modułu ma eol=lf; host na Windowsie bywa wypakowany z CRLF).
func _store(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text.replace("\r\n", "\n"))
	f.close()


func _file_size(p: String) -> int:
	var f := FileAccess.open(p, FileAccess.READ)
	return f.get_length() if f else 0


func _remove_dir(abs_dir: String) -> void:
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for d in DirAccess.get_directories_at(abs_dir):
		_remove_dir(abs_dir.path_join(d))
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)
