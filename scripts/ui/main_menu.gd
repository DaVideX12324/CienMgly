extends CanvasLayer

## Main menu for res://modules/quiz_rpg/scenes/ui/main_menu.tscn.

@onready var new_game_btn: Button = $Center/Panel/Margin/VBox/BtnNewGame
@onready var load_game_btn: Button = $Center/Panel/Margin/VBox/BtnLoadGame
@onready var stats_btn: Button = $Center/Panel/Margin/VBox/BtnStats
@onready var quit_btn: Button = $Center/Panel/Margin/VBox/BtnQuit
@onready var close_stats_btn: Button = $StatsPanel/StatsMargin/StatsVBox/BtnCloseStats
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var stats_label: Label = $StatsPanel/StatsMargin/StatsVBox/StatsLabel
@onready var stats_panel: PanelContainer = $StatsPanel
@onready var background: ColorRect = $BG

var _title_time := 0.0


func _ready() -> void:
	_connect_buttons()
	_update_load_button()
	_style_menu()
	stats_panel.visible = false


func _process(delta: float) -> void:
	_title_time += delta
	var scale_factor := 1.0 + sin(_title_time * 1.5) * 0.02
	title_label.scale = Vector2(scale_factor, scale_factor)


func _connect_buttons() -> void:
	if not new_game_btn.pressed.is_connected(_on_new_game):
		new_game_btn.pressed.connect(_on_new_game)
	if not load_game_btn.pressed.is_connected(_on_load_game):
		load_game_btn.pressed.connect(_on_load_game)
	if not stats_btn.pressed.is_connected(_on_stats):
		stats_btn.pressed.connect(_on_stats)
	if not quit_btn.pressed.is_connected(_on_quit):
		quit_btn.pressed.connect(_on_quit)
	if not close_stats_btn.pressed.is_connected(_on_close_stats):
		close_stats_btn.pressed.connect(_on_close_stats)


func _update_load_button() -> void:
	var gm := _get_module_singleton("GameManager")
	load_game_btn.disabled = not FileAccess.file_exists(gm.SAVE_PATH) if gm else true


func _style_menu() -> void:
	title_label.pivot_offset = title_label.size / 2.0


func _on_new_game() -> void:
	var gm := _get_module_singleton("GameManager")
	if gm:
		gm.new_game()
	else:
		push_warning("MainMenu: GameManager unavailable, cannot start new game.")


func _on_load_game() -> void:
	var gm := _get_module_singleton("GameManager")
	if not gm:
		return
	if gm.load_game():
		gm.change_state(gm.GameState.EXPLORING)
	else:
		push_warning("Nie udalo sie wczytac gry!")


func _on_stats() -> void:
	stats_panel.visible = not stats_panel.visible
	if stats_panel.visible:
		_populate_stats()


func _on_close_stats() -> void:
	stats_panel.visible = false


func _populate_stats() -> void:
	var ps := _get_module_singleton("PlayerStats")
	if not ps:
		stats_label.text = "Brak statystyk"
		return

	stats_label.text = """Statystyki gracza:
Poziom: %d
XP: %d / %d
HP: %d / %d
Punkty: %d
Poprawne: %d
Bledne: %d
Najlepsza seria: %d
Nagrody: %d
Trafnosc: %.0f%%""" % [
		ps.level,
		ps.xp, ps.xp_to_next_level(),
		ps.hp, ps.max_hp,
		ps.points,
		ps.total_correct,
		ps.total_wrong,
		ps.best_streak,
		ps.rewards.size(),
		QuizManager.get_overall_accuracy() * 100,
	]


func _on_quit() -> void:
	if CoreManager.get_active_module_id() != "":
		CoreManager.exit_active_module()
		return
	get_tree().quit()


func _get_module_singleton(singleton_name: String) -> Node:
	var singleton := CoreManager.get_singleton(singleton_name)
	if singleton:
		return singleton

	var module_root := CoreManager.get_active_module()
	if module_root:
		singleton = module_root.get_node_or_null(singleton_name)
		if singleton:
			CoreManager.register_singleton(singleton_name, singleton)
			return singleton

	return null
