extends Node

## Autoaktualizacja pełnego exe (Windows). Węzeł tworzy WindowService, więc ten skrypt dochodzi łatką .pck — także do
## starszych exe, których UpdateService (wczytany z exe przed łatkami) o wpisie "exe" nie wie.
## Wpis "exe" manifestu ({version, build, base, url}) z bazą inną niż baza tego exe: pobiera exe do <exe>.new, działający exe zmienia nazwę na
## <exe>.old (Windows pozwala), .new na <exe> — po cichu: łatka ma już te same zmiany, nowy exe rusza przy następnym
## uruchomieniu. Przy starcie usuwa .old.
## Folder exe bez prawa zapisu / błąd pobierania = zostaje link do pełnego exe (komunikat UpdateService).

const MANIFEST_URL := "https://gist.githubusercontent.com/DaVideX12324/cc2274c3de25a1ee9a122ad9419097a8/raw/"
const DOWNLOAD_TIMEOUT := 900.0
const PROGRESS_SCENE := "res://_host/scenes/ui/exe_update_progress.tscn"
## Komunikat po podmianie widoczny tyle sekund.
const DONE_SHOW_SEC := 8.0

var _download: HTTPRequest
var _ui: CanvasLayer
var _version := ""


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
	if update == null:
		return
	# Build samego exe (bez łatek) — bieżący build po łatce bywa wyższy niż build nowego exe.
	var base := int(update.get("_base_build")) if "_base_build" in update else int(update.call("current_build"))
	if int(m.get("build", 0)) <= base or int(m.get("base", -1)) == base or not _can_write():
		return  # ta sama baza = wystarczą łatki
	var exe := OS.get_executable_path()
	_version = str(m.get("version", ""))
	_show_progress()
	_download = _request(str(m.url), exe + ".new", DOWNLOAD_TIMEOUT, func(got: bool, _b: PackedByteArray) -> void:
		_download = null
		var done := got and FileAccess.file_exists(exe + ".new") and DirAccess.rename_absolute(exe, exe + ".old") == OK
		if done and DirAccess.rename_absolute(exe + ".new", exe) != OK:
			DirAccess.rename_absolute(exe + ".old", exe)  # cofnięcie
			done = false
		if not done:
			DirAccess.remove_absolute(exe + ".new")
		_finish_progress(done))


## Pasek pobierania pełnego exe (prawy dolny róg, nad menu i grą).
func _show_progress() -> void:
	_ui = (load(PROGRESS_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_ui)
	(_ui.get_node("%Info") as Label).text = _tr("update.exe_downloading", "Pobieranie aktualizacji {version}…")
	(_ui.get_node("%Bar") as ProgressBar).value = 0.0


func _process(_delta: float) -> void:
	if _download == null or _ui == null:
		return
	var total := _download.get_body_size()
	var got := _download.get_downloaded_bytes()
	(_ui.get_node("%Bar") as ProgressBar).value = float(got) / float(total) if total > 0 else 0.0
	(_ui.get_node("%Info") as Label).text = _tr("update.exe_downloading", "Pobieranie aktualizacji {version}…") + ("  %d / %d MB" % [got / 1048576, total / 1048576] if total > 0 else "")


func _finish_progress(done: bool) -> void:
	if _ui == null:
		return
	(_ui.get_node("%Bar") as ProgressBar).visible = false
	(_ui.get_node("%Info") as Label).text = _tr("update.exe_done", "Zaktualizowano do {version} — nowa wersja przy następnym uruchomieniu.") if done else _tr("update.exe_failed", "Nie udało się pobrać aktualizacji {version}.")
	var ui := _ui
	_ui = null
	get_tree().create_timer(DONE_SHOW_SEC).timeout.connect(ui.queue_free)


func _tr(key: String, fallback: String) -> String:
	var i18n := get_node_or_null("/root/I18nService")
	var text: String = i18n.call("t", key, fallback) if i18n else fallback
	return text.replace("{version}", _version)


func _can_write() -> bool:
	var probe := OS.get_executable_path().get_base_dir().path_join(".aw_write_test")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func _request(url: String, save_to: String, timeout: float, done: Callable) -> HTTPRequest:
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.download_file = save_to
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		done.call(result == HTTPRequest.RESULT_SUCCESS and code == 200, body))
	if req.request(url) != OK:
		req.queue_free()
		return null
	return req
