class_name QuizRpgProgressLog
extends RefCounted

## Log progresji do testów balansu (user://progress_log.txt, dopisywany, działa też w buildzie bez debugu): start sesji, wejścia na
## mapy, każda walka (wynik, wrogowie z poziomami, XP, tury, czas, HP po walce) i awanse (ile walk i czasu od poprzedniego awansu).
## Linia: [czas od startu sesji] Lv poziom (XP/do następnego) HP | zdarzenie | szczegóły. Cel: przy bossie odczytać poziom, liczbę walk,
## czas przejścia i odstępy między awansami (docs/kontekst/poziomy_i_xp.md „Status celu 120 %”).

## Zmienialna tylko po to, żeby testy nie pisały do prawdziwego logu.
static var log_path := "user://progress_log.txt"

static var _started_msec := -1
static var _fights := 0
static var _fights_at_last_level := 0
static var _last_level_msec := 0
static var _map := ""
static var _map_fights := 0


## Początek sesji (module_root._ready): nagłówek, liczniki od zera.
static func session_begin(ps: Node) -> void:
	_started_msec = Time.get_ticks_msec()
	_last_level_msec = _started_msec
	_fights = 0
	_fights_at_last_level = 0
	_map = ""
	_map_fights = 0
	var d := Time.get_datetime_string_from_system()
	_write("\n===== SESJA %s (build %s) =====" % [d, "debug" if OS.is_debug_build() else "release"])
	record(ps, "start", "poziom %d" % (int(ps.get("level")) if ps != null else 0))


## Nowa mapa (LevelManager po wygenerowaniu poziomu): podsumowanie poprzedniej i wejście na nową.
static func map_entered(ps: Node, level_path: String) -> void:
	if _map != "":
		record(ps, "mapa-koniec", "%s: walk %d" % [_map, _map_fights])
	_map = level_path.get_file()
	_map_fights = 0
	record(ps, "mapa", level_path)


## Koniec walki: wynik (wygrana / ucieczka / porażka), wrogowie, XP, tury, czas walki w sekundach.
static func combat_end(ps: Node, outcome: String, enemies: String, boss: bool, xp: int, turns: int, seconds: float, gold: int = 0) -> void:
	_fights += 1
	_map_fights += 1
	record(ps, "walka-" + outcome, "%s%s | xp +%d | D +%d | tury %d | %.0f s | walka nr %d" % ["BOSS " if boss else "", enemies, xp, gold, turns, seconds, _fights])


## Awans (PlayerStats.level_up).
static func level_up(ps: Node, new_level: int) -> void:
	var now := Time.get_ticks_msec()
	record(ps, "AWANS", "lv %d | walk od poprzedniego awansu %d | czas od poprzedniego %s" % [new_level, _fights - _fights_at_last_level, _fmt((now - _last_level_msec) / 1000)])
	_fights_at_last_level = _fights
	_last_level_msec = now


static func record(ps: Node, kind: String, detail: String) -> void:
	if _started_msec < 0:
		_started_msec = Time.get_ticks_msec()
	var t := (Time.get_ticks_msec() - _started_msec) / 1000
	var status := ""
	if ps != null:
		status = "Lv %s (%s/%s) HP %s/%s" % [ps.get("level"), ps.get("xp"), ps.call("xp_to_next_level"), ps.get("hp"), ps.get("max_hp")]
	_write("[%s] %s | %s | %s" % [_fmt(t), status, kind, detail])


static func _fmt(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]


static func _write(line: String) -> void:
	var f := FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()
