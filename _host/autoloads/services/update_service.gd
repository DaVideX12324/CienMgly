extends Node

## Aktualizacje. Przy starcie (przed innymi autoloadami) wczytuje paczki z folderu patches/ obok exe — ich pliki
## nadpisują te z exe, w kolejności nazw (patch_004.pck po patch_003.pck). Potem pobiera manifest z gista:
## {"version": "0.9.8-beta", "build": 4, "url": "<pełny exe>", "patches": [{"build": 4, "url": "<.pck>"}]}
## Paczki o buildzie wyższym niż obecny są pobierane do patches/ (działają po ponownym uruchomieniu); nowsza
## wersja bez paczek = tylko informacja z linkiem do pobrania.

signal update_available(text: String, url: String)

const MANIFEST_URL := "https://gist.githubusercontent.com/DaVideX12324/cc2274c3de25a1ee9a122ad9419097a8/raw/"
const BUILD_PATH := "res://_host/resources/build.json"

var _patch_dir := OS.get_executable_path().get_base_dir().path_join("patches")


func _init() -> void:
	if not OS.has_feature("template"):  # w edytorze bez paczek
		return
	var files := Array(DirAccess.get_files_at(_patch_dir)) if DirAccess.dir_exists_absolute(_patch_dir) else []
	files.sort()
	for f: String in files:
		if f.get_extension().to_lower() == "pck" and not ProjectSettings.load_resource_pack(_patch_dir.path_join(f)):
			push_warning("[Update] Nie wczytano paczki: " + f)


func _ready() -> void:
	if OS.has_feature("template"):
		_fetch(MANIFEST_URL, _on_manifest)


static func current_build() -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH)) if FileAccess.file_exists(BUILD_PATH) else null
	return int((data as Dictionary).get("build", 0)) if data is Dictionary else 0


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
	var pending: Array = (m.get("patches", []) as Array).filter(func(p: Variant) -> bool:
		return p is Dictionary and int(p.get("build", 0)) > current_build())
	if pending.is_empty():
		update_available.emit(_t("update.available", "Dostępna wersja {version} — pobierz", version), str(m.get("url", "")))
		return
	DirAccess.make_dir_recursive_absolute(_patch_dir)
	var left := [pending.size()]
	var failed := [false]
	for p: Dictionary in pending:
		var dest := _patch_dir.path_join("patch_%03d.pck" % int(p.build))
		_fetch(str(p.url), func(got: bool, _b: PackedByteArray) -> void:
			if not got:
				failed[0] = true
				DirAccess.remove_absolute(dest)
			left[0] -= 1
			if left[0] == 0:
				if failed[0]:
					update_available.emit(_t("update.available", "Dostępna wersja {version} — pobierz", version), str(m.get("url", "")))
				else:
					update_available.emit(_t("update.restart", "Pobrano aktualizację {version} — uruchom grę ponownie", version), ""), dest)


func _t(key: String, fallback: String, version: String) -> String:
	return (I18nService.t(key, fallback) if I18nService else fallback).replace("{version}", version)
