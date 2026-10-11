extends SceneTree
## Odtworzenie krytycznych zawieszeń klatek przy ruchu kursora (docs/krytyczne_zawieszenia_klatek.md).
## Uruchamia moduł (menu główne) na 24 s; wpisy PUŁS / ZACIĘCIE trafiają do user://perf_log.txt (monitor w module_root).
## Kursorem steruje tools/mouse_sweep.ps1 równolegle (Windows). Okno: --position 100,100 --resolution 1280x720.


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var mr: Node = (load("res://modules/quiz_rpg/module_root.tscn") as PackedScene).instantiate()
	root.add_child(mr)
	await create_timer(24.0).timeout
	quit(0)
