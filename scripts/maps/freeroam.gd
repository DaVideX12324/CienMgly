class_name QuizRpgFreeroam
extends RefCounted

## Swobodne zwiedzanie ręcznej mapy odpalonej samodzielnie (F6 na scenie miasta): bez menu i level_managera.
## Dokłada minimalny GameManager (stan EXPLORING, inaczej gracz stoi w miejscu) i gracza w punkcie Spawns/Spawn;
## kamera jest w scenie gracza. Pełne singletony modułu (PlayerStats, zapis) tu nie działają — to tryb do testu mapy.

const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const GameManagerScript = preload("../../autoloads/game_manager.gd")
const PlayerScene = preload("../../scenes/player/player.tscn")

const SPAWN_NODE := "Spawns/Spawn"


## Czy scena działa sama (uruchomiona z edytora / wiersza poleceń), a nie jako mapa wczytana przez level_manager.
static func is_standalone(level: Node) -> bool:
	return level.is_inside_tree() and level.get_tree().current_scene == level


static func start(level: Node2D) -> void:
	var core := level.get_node_or_null("/root/CoreManager")
	if core != null and core.get_singleton("GameManager") == null:
		var gm := GameManagerScript.new()
		gm.name = "GameManager"
		level.add_child(gm)
		core.register_singleton("GameManager", gm)
		gm.change_state(GameManagerScript.GameState.EXPLORING)
	var player := PlayerScene.instantiate() as Node2D
	player.name = "Player"
	var spawn := level.get_node_or_null(SPAWN_NODE) as Node2D
	player.position = spawn.position if spawn != null else Vector2.ZERO
	level.add_child(player)
	print("[Freeroam] %s: sterowanie WSAD / strzałki, Shift — bieg; gracz w %s" % [level.name, player.position])
