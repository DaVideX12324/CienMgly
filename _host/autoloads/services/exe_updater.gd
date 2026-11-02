extends Node

## Autoaktualizacja pełnego exe (Windows). Węzeł tworzy WindowService, więc ten skrypt dochodzi łatką .pck — także do
## starszych exe, których UpdateService (wczytany z exe przed łatkami) o wpisie "exe" nie wie.
## Wpis "exe" manifestu ({version, build, base, url}) z bazą inną niż baza tego exe: pobiera exe do <exe>.new, działający exe zmienia nazwę na
## <exe>.old (Windows pozwala), .new na <exe>, komunikat „uruchom ponownie” przez UpdateService. Przy starcie usuwa .old.
## Folder exe bez prawa zapisu / błąd pobierania = zostaje link do pełnego exe (komunikat UpdateService).

const MANIFEST_URL := "https://gist.githubusercontent.com/DaVideX12324/cc2274c3de25a1ee9a122ad9419097a8/raw/"
const DOWNLOAD_TIMEOUT := 900.0


func _ready() -> void:
	if not OS.has_feature("template") or OS.get_name() != "Windows":
		return
	var exe := OS.get_executable_path()
	if FileAccess.file_exists(exe + ".old"):
		DirAccess.remove_absolute(exe + ".old")
	_request(MANIFEST_URL + "?t=%d" % int(Time.get_unix_time_from_system()), "", 15.0, _on_manifest)


func _on_manifest(ok: bool, body: PackedByteArray) -> void:
	var root: Variant = JSON.parse_string(body.get_string_from_utf8()) if ok else null
	var m: Variant = (root as Dictionary).get("exe") if root is Dictionary else null
	if not m is Dictionary or str(m.get("url", "")) == "":
		return
	var update := get_node_or_null("/root/UpdateService")
	if update == null or int(m.get("build", 0)) <= int(update.call("current_build")):
		return
	var base := int(update.get("_base_build")) if "_base_build" in update else int(update.call("current_build"))
	if int(m.get("base", -1)) == base or not _can_write():
		return  # ta sama baza = wystarczą łatki
	var exe := OS.get_executable_path()
	var version := str(m.get("version", ""))
	_request(str(m.url), exe + ".new", DOWNLOAD_TIMEOUT, func(got: bool, _b: PackedByteArray) -> void:
		var done := got and FileAccess.file_exists(exe + ".new") and DirAccess.rename_absolute(exe, exe + ".old") == OK
		if done and DirAccess.rename_absolute(exe + ".new", exe) != OK:
			DirAccess.rename_absolute(exe + ".old", exe)  # cofnięcie
			done = false
		if not done:
			DirAccess.remove_absolute(exe + ".new")
			return
		var text := I18nService.t("update.restart", "Pobrano aktualizację {version} — kliknij, by uruchomić ponownie") if I18nService \
				else "Pobrano aktualizację {version} — kliknij, by uruchomić ponownie"
		update.call("_notify", text.replace("{version}", version), ""))


func _can_write() -> bool:
	var probe := OS.get_executable_path().get_base_dir().path_join(".aw_write_test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func _request(url: String, save_to: String, timeout: float, done: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.download_file = save_to
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		done.call(result == HTTPRequest.RESULT_SUCCESS and code == 200, body))
	if req.request(url) != OK:
		req.queue_free()
