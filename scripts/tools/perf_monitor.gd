extends CanvasLayer
## Monitor wydajności tylko w buildzie debug (dokładany w module_root). F3 przełącza nakładkę (FPS, czas klatki,
## najgorsza klatka z ostatniej sekundy, węzły, draw calle). Zacięcia i zawieszenia trafiają do user://perf_log.txt
## razem z kontekstem (tryb menu pauzy, faza walki, ostatnie zdarzenia wejścia, metryki silnika).
## Strażnik w osobnym wątku zapisuje wpis także wtedy, gdy główny wątek stoi i klatki w ogóle nie wracają.

const LOG_PATH := "user://perf_log.txt"
const HITCH_MS := 60.0  # klatka dłuższa od tego trafia do logu
const STALL_MS := 1500  # główny wątek bez klatki dłużej niż to = wpis strażnika
const INPUT_HISTORY := 16

var _label: Label
var _last_us: int = 0
var _window_worst_ms: float = 0.0
var _window_t: float = 0.0
var _shown_worst_ms: float = 0.0
var _events: Array[String] = []
var _watchdog: Thread
var _watchdog_stop: bool = false
var _last_frame_msec: int = 0  # czytany przez wątek strażnika
var _last_context: String = ""  # jw.; odświeżany co klatkę
var _events_text: String = ""  # jw. (kopia tekstowa historii wejścia)
var _stall_logged: bool = false
var _t_process_us: int = 0  # początek _process bieżącej klatki
var _t_postdraw_us: int = 0  # koniec rysowania poprzedniej klatki
var _evt_count: int = 0  # zdarzenia wejścia od ostatniego _process
var _evt_first_us: int = 0
var _evt_last_us: int = 0
var _evt_report: String = ""  # podsumowanie poprzedniej klatki
var _pre_draw_ms: float = 0.0  # _process -> frame_post_draw (skrypty + submit renderu)
var _post_draw_ms: float = 0.0  # frame_post_draw -> następny _process (prezentacja / VSync / system)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	add_child(_label)
	_last_us = Time.get_ticks_usec()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_last_frame_msec = Time.get_ticks_msec()
	_append("=== start sesji %s, log: %s ===" % [Time.get_datetime_string_from_system(), ProjectSettings.globalize_path(LOG_PATH)])
	_watchdog = Thread.new()
	_watchdog.start(_watchdog_loop)


func _exit_tree() -> void:
	_watchdog_stop = true
	if _watchdog != null and _watchdog.is_started():
		_watchdog.wait_to_finish()


func _input(event: InputEvent) -> void:
	var t := Time.get_ticks_usec()
	if _evt_count == 0:
		_evt_first_us = t
	_evt_last_us = t
	_evt_count += 1
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_label.visible = not _label.visible
		return
	if event is InputEventMouseMotion:
		return
	var text := ""
	if event is InputEventKey and event.pressed:
		text = "klawisz %s" % OS.get_keycode_string(event.keycode)
	elif event is InputEventMouseButton and event.pressed:
		text = "mysz przycisk %d @ %s" % [event.button_index, str((event as InputEventMouseButton).position)]
	if text != "":
		_events.append("%.2fs %s" % [Time.get_ticks_msec() / 1000.0, text])
		if _events.size() > INPUT_HISTORY:
			_events.pop_front()
		_events_text = " | ".join(_events)


func _on_post_draw() -> void:
	_t_postdraw_us = Time.get_ticks_usec()
	_pre_draw_ms = (_t_postdraw_us - _t_process_us) / 1000.0


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	_post_draw_ms = (now - _t_postdraw_us) / 1000.0
	_evt_report = "zdarzeń wejścia %d, pierwsze %.0f ms po rysowaniu, ostatnie %.0f ms po rysowaniu" % [
		_evt_count, maxf(_evt_first_us - _t_postdraw_us, 0) / 1000.0, maxf(_evt_last_us - _t_postdraw_us, 0) / 1000.0] if _evt_count > 0 else "bez zdarzeń wejścia"
	_evt_count = 0
	_t_process_us = now
	var frame_ms := (now - _last_us) / 1000.0
	_last_us = now
	_last_frame_msec = Time.get_ticks_msec()
	_last_context = _context()
	_stall_logged = false
	_window_worst_ms = maxf(_window_worst_ms, frame_ms)
	_window_t += delta
	if _window_t >= 1.0:
		_shown_worst_ms = _window_worst_ms
		_window_worst_ms = 0.0
		_window_t = 0.0
	if _label.visible:
		_label.text = "%d FPS  %.1f ms (najgorsza 1 s: %.0f ms)\nwęzłów %d  draw calli %d\n%s" % [
			Engine.get_frames_per_second(), frame_ms, _shown_worst_ms,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), _last_context]
	if frame_ms >= HITCH_MS:
		_append("ZACIĘCIE %.0f ms | %s" % [frame_ms, _metrics()])
		_append("   %s" % _evt_report)
		_append("   kontekst: %s" % _last_context)
		_append("   wejście: %s" % _events_text)


func _metrics() -> String:
	var rid := get_viewport().get_viewport_rid()
	return "przed rysowaniem %.0f ms, po rysowaniu (prezentacja/system) %.0f ms, render CPU %.1f ms, GPU %.1f ms | proces %.1f ms, fizyka %.1f ms, draw calli %d, węzłów %d, obiektów %d, VRAM %.0f MB, pamięć %.0f MB" % [
		_pre_draw_ms, _post_draw_ms, RenderingServer.viewport_get_measured_render_time_cpu(rid),
		RenderingServer.viewport_get_measured_render_time_gpu(rid),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]


## Stan gry w jednym wierszu: pauza drzewa, scena, tryb menu pauzy, faza walki / lista w walce.
func _context() -> String:
	var tree := get_tree()
	if tree == null:
		return ""
	var parts: Array[String] = ["pauza=%s" % tree.paused]
	var scene := tree.current_scene
	if scene != null:
		parts.append("scena=%s" % scene.name)
		var pm := scene.get_node_or_null("PauseMenu")
		if pm != null and pm.get("_paused") == true:
			parts.append("menu_pauzy=%s" % str(pm.get("_mode")))
		for c in scene.get_children():
			if c is CanvasLayer and str(c.name).begins_with("QuizCombatUI"):
				var ctl: Node = c.get_node_or_null("Root")
				if ctl != null:
					parts.append("walka_faza=%s lista=%s" % [str(ctl.get("phase")), str(ctl.get("_list_menu_mode"))])
	return ", ".join(parts)


## Wątek strażnika: jeśli główny wątek nie oddał klatki od STALL_MS, zapisuje wpis (raz na zawieszenie).
func _watchdog_loop() -> void:
	while not _watchdog_stop:
		OS.delay_msec(250)
		var stalled := Time.get_ticks_msec() - _last_frame_msec
		if stalled >= STALL_MS and not _stall_logged:
			_stall_logged = true
			_append("ZAWIESZENIE głównego wątku od %d ms | ostatni kontekst: %s | wejście: %s" % [stalled, _last_context, _events_text])


func _append(line: String) -> void:
	print("[perf] ", line)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s  %s" % [Time.get_time_string_from_system(), line])
	f.close()
