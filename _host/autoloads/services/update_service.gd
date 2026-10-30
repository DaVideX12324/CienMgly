extends Node

## Aktualizacje. Przy starcie (przed innymi autoloadami) wczytuje paczki z folderu patches/ obok exe — ich pliki
## nadpisują te z exe, w kolejności buildów. Tylko paczki głównej wersji exe (patch_<0.9.9>_<build>.pck — ustawienia
## projektu paczka nie zmienia, więc to wersja bazy); starsze są usuwane. Build liczy się od 1 w każdej głównej
## wersji (ExportCheck), więc nowszość = wersja, a przy równej wersji build. Potem pobiera manifest z gista:
## {"version": "0.9.8-beta", "build": 4, "url": "<pełny exe>", "patches": [{"build": 4, "url": "<.pck>"}]}
## Paczki o buildzie wyższym niż obecny są pobierane do patches/ (działają po ponownym uruchomieniu); nowsza
## wersja bez paczek = tylko informacja z linkiem do pobrania.

signal update_available(text: String, url: String)

## Ostatni komunikat [text, url] — dla menu, które zaczęło słuchać po jego wysłaniu (szybkie pobranie).
var last_message: Array = []

const MANIFEST_URL := "https://gist.githubusercontent.com/DaVideX12324/cc2274c3de25a1ee9a122ad9419097a8/raw/"
const BUILD_PATH := "res://_host/resources/build.json"

var _patch_dir := OS.get_executable_path().get_base_dir().path_join("patches")


func _init() -> void:
	if not OS.has_feature("template"):  # w edytorze bez paczek
		return
	var prefix := "patch_%s_" % main_version(str(ProjectSettings.get_setting("application/config/version", "")))
	var mine: Array[String] = []
	for f in (DirAccess.get_files_at(_patch_dir) if DirAccess.dir_exists_absolute(_patch_dir) else PackedStringArray()):
		if f.get_extension().to_lower() != "pck":
			continue
		if f.begins_with(prefix):
			mine.append(f)
		else:
			DirAccess.remove_absolute(_patch_dir.path_join(f))  # paczka innej bazy (stary exe)
	mine.sort_custom(func(a: String, b: String) -> bool: return a.get_basename().get_slice("_", 2).to_int() < b.get_basename().get_slice("_", 2).to_int())
	for f in mine:
		if not ProjectSettings.load_resource_pack(_patch_dir.path_join(f)):
			push_warning("[Update] Nie wczytano paczki: " + f)


func _ready() -> void:
	if OS.has_feature("template"):
		_fetch(MANIFEST_URL + "?t=%d" % int(Time.get_unix_time_from_system()), _on_manifest)  # bez pamięci podręcznej (5 min)


static func current_build() -> int:
	return int(_build_info().get("build", 0))


## Wersja z build.json (aktualna także po paczce), bez niej z ustawień projektu.
static func current_version() -> String:
	return str(_build_info().get("version", ProjectSettings.get_setting("application/config/version", "")))


## Liczby wersji: "0.9.9.1-beta" -> [0, 9, 9, 1].
static func version_numbers(version: String) -> Array[int]:
	var out: Array[int] = []
	for part in version.get_slice("-", 0).split("."):
		out.append(part.to_int())
	return out


## Główna wersja (pierwsze trzy liczby): "0.9.9.1-beta" -> "0.9.9".
static func main_version(version: String) -> String:
	var n := version_numbers(version)
	n.resize(3)
	return "%d.%d.%d" % [n[0], n[1], n[2]]


## true, gdy (wersja, build) a jest nowsze niż b.
static func is_newer(version_a: String, build_a: int, version_b: String, build_b: int) -> bool:
	var a := version_numbers(version_a)
	var b := version_numbers(version_b)
	for i in maxi(a.size(), b.size()):
		var x := a[i] if i < a.size() else 0
		var y := b[i] if i < b.size() else 0
		if x != y:
			return x > y
	return build_a > build_b


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
	if not m is Dictionary or not is_newer(str(m.get("version", "")), int(m.get("build", 0)), current_version(), current_build()):
		return
	var version := str(m.get("version", ""))
	# Paczki tylko dla bazy tego exe (ta sama główna wersja); nowa główna wersja = link do pełnego exe.
	var base := main_version(str(ProjectSettings.get_setting("application/config/version", "")))
	var pending: Array = [] if main_version(version) != base else (m.get("patches", []) as Array).filter(func(p: Variant) -> bool:
		return p is Dictionary)
	if pending.is_empty():
		_notify(_t("update.available", "Dostępna wersja {version} — pobierz", version), str(m.get("url", "")))
		return
	DirAccess.make_dir_recursive_absolute(_patch_dir)
	var left := [pending.size()]
	var failed := [false]
	for p: Dictionary in pending:
		var dest := _patch_dir.path_join("patch_%s_%d.pck" % [base, int(p.build)])
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
