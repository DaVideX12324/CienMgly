extends Node

## Aktualizacje. Przy starcie (przed innymi autoloadami) wczytuje paczki z folderu patches/ obok exe — ich pliki
## nadpisują te z exe, w kolejności buildów (patch_<build>.pck). Build rośnie stale (ExportCheck), bazą jest build
## exe (jego build.json, czytany przed paczkami); paczki o buildzie nie wyższym niż exe są starsze, więc usuwane.
## Wersja to tylko etykieta — nowszość = build. Potem pobiera manifest z gista:
## {"version": "0.9.8-beta", "build": 4, "base": 2, "url": "<pełny exe>", "patches": [{"build": 4, "url": "<.pck>"}]}
## Paczki dla bazy tego exe (base == build exe) są pobierane do patches/ (działają po ponownym uruchomieniu);
## inna baza = tylko informacja z linkiem do pełnego exe.

signal update_available(text: String, url: String)

## Ostatni komunikat [text, url] — dla menu, które zaczęło słuchać po jego wysłaniu (szybkie pobranie).
var last_message: Array = []

const MANIFEST_URL := "https://gist.githubusercontent.com/DaVideX12324/cc2274c3de25a1ee9a122ad9419097a8/raw/"
const BUILD_PATH := "res://_host/resources/build.json"

var _patch_dir := OS.get_executable_path().get_base_dir().path_join("patches")
var _base_build := 0  # build exe (bez paczek)


func _init() -> void:
	if not OS.has_feature("template"):  # w edytorze bez paczek
		return
	_base_build = current_build()
	var mine: Array[String] = []
	for f in (DirAccess.get_files_at(_patch_dir) if DirAccess.dir_exists_absolute(_patch_dir) else PackedStringArray()):
		if f.get_extension().to_lower() != "pck":
			continue
		if f.get_basename().get_slice("_", 1).is_valid_int() and _patch_build(f) > _base_build:
			mine.append(f)
		else:
			DirAccess.remove_absolute(_patch_dir.path_join(f))  # paczka starszej bazy (stary exe)
	mine.sort_custom(func(a: String, b: String) -> bool: return _patch_build(a) < _patch_build(b))
	for f in mine:
		if not ProjectSettings.load_resource_pack(_patch_dir.path_join(f)):
			push_warning("[Update] Nie wczytano paczki: " + f)


func _ready() -> void:
	if OS.has_feature("template"):
		_fetch(MANIFEST_URL + "?t=%d" % int(Time.get_unix_time_from_system()), _on_manifest)  # bez pamięci podręcznej (5 min)


static func _patch_build(file: String) -> int:
	return file.get_basename().get_slice("_", 1).to_int()


static func current_build() -> int:
	return int(_build_info().get("build", 0))


## Wersja z build.json (aktualna także po paczce), bez niej z ustawień projektu.
static func current_version() -> String:
	return str(_build_info().get("version", ProjectSettings.get_setting("application/config/version", "")))


static func _build_info() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH)) if FileAccess.file_exists(BUILD_PATH) else null
	return data if data is Dictionary else {}


func _fetch(url: String, done: Callable, save_to: String = "") -> void:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	if save_to != "":
		req.download_file = save_to
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		done.call(result == HTTPRequest.RESULT_SUCCESS and code == 200, body))
	if req.request(url) != OK:
		req.queue_free()


func _on_manifest(ok: bool, body: PackedByteArray) -> void:
	var m: Variant = JSON.parse_string(body.get_string_from_utf8()) if ok else null
	if not m is Dictionary or int(m.get("build", 0)) <= current_build():
		return
	var version := str(m.get("version", ""))
	# Paczki tylko dla bazy tego exe; nowa baza = link do pełnego exe.
	var pending: Array = [] if int(m.get("base", -1)) != _base_build else (m.get("patches", []) as Array).filter(func(p: Variant) -> bool:
		return p is Dictionary)
	if pending.is_empty():
		_notify(_t("update.available", "Dostępna wersja {version} — pobierz", version), str(m.get("url", "")))
		return
	DirAccess.make_dir_recursive_absolute(_patch_dir)
	var left := [pending.size()]
	var failed := [false]
	for p: Dictionary in pending:
		var dest := _patch_dir.path_join("patch_%d.pck" % int(p.build))
		_fetch(str(p.url), func(got: bool, _b: PackedByteArray) -> void:
			if not got:
				failed[0] = true
				DirAccess.remove_absolute(dest)
			left[0] -= 1
			if left[0] == 0:
				if failed[0]:
					_notify(_t("update.available", "Dostępna wersja {version} — pobierz", version), str(m.get("url", "")))
				else:
					_notify(_t("update.restart", "Pobrano aktualizację {version} — kliknij, by uruchomić ponownie", version), ""), dest)


func _notify(text: String, url: String) -> void:
	last_message = [text, url]
	update_available.emit(text, url)


func _t(key: String, fallback: String, version: String) -> String:
	return (I18nService.t(key, fallback) if I18nService else fallback).replace("{version}", version)
