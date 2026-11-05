extends CanvasLayer

## Nakładka na mapę: komunikaty nagród (awans, nagroda), cel główny w rogu (Goal — z main_quest.json, odświeżany
## po fladze fabularnej) i zaciemnienie przejść (FadeOverlay — GameManager). Statystyki gracza tylko w menu Esc.

@onready var reward_popup: Label       = $RewardPopup
@onready var fade_overlay: ColorRect   = $FadeOverlay
@onready var goal_panel: Control       = $Goal
@onready var goal_title: Label         = $Goal/Box/Title
@onready var goal_text: Label          = $Goal/Box/Text

var _ps: Node  # PlayerStats
var _reward_base_y: float = 80.0
var _lsm: Node  # LevelStateManager


func _ready() -> void:
	UiLayerScale.attach(self)  # skala UI z opcji na całą warstwę
	if reward_popup:
		reward_popup.visible = false
		_reward_base_y = reward_popup.position.y

	if fade_overlay:
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_lsm = CoreManager.get_singleton("LevelStateManager")
	if _lsm and _lsm.has_signal("story_flag_changed"):
		_lsm.story_flag_changed.connect(func(_f: String, _v: bool) -> void: _refresh_goal(true))
	_refresh_goal(false)

	_ps = CoreManager.get_singleton("PlayerStats")
	if not _ps:
		push_error("HUD: PlayerStats niedostepny przez CoreManager")
		return
	_ps.level_up.connect(_on_level_up)
	_ps.reward_earned.connect(_on_reward_earned)


## Cel główny w rogu; przy zmianie (nowy krok fabuły) panel mignie i pokaże komunikat.
func _refresh_goal(announce: bool) -> void:
	if not goal_panel:
		return
	goal_title.text = QuizRpgI18n.t("quest.main.title", "Cel główny")
	var text := QuizRpgQuestLog.main_goal(_lsm)
	goal_panel.visible = text != ""
	if text == goal_text.text:
		return
	goal_text.text = text
	if announce and text != "":
		_show_reward_popup(QuizRpgI18n.t("hud.new_goal", "Nowy cel!"))
		goal_panel.modulate = Color(1.6, 1.4, 0.8, 1.0)
		create_tween().tween_property(goal_panel, "modulate", Color(1, 1, 1, 0.9), 1.5)


func _on_level_up(new_level: int) -> void:
	_show_reward_popup(QuizRpgI18n.tf("hud.level_up", {"level": new_level}, "LEVEL UP! Lvl {level}"))


func _on_reward_earned(reward_name: String) -> void:
	var localized_reward := QuizRpgI18n.t("reward." + reward_name, QuizRpgI18n.t(reward_name, reward_name))
	_show_reward_popup(QuizRpgI18n.tf("hud.reward", {"reward": localized_reward}, "Nagroda: {reward}"))


func _show_reward_popup(text: String) -> void:
	if not reward_popup:
		return
	reward_popup.text = text
	reward_popup.visible = true
	reward_popup.modulate.a = 1.0
	reward_popup.position.y = _reward_base_y

	var tween = create_tween()
	tween.tween_property(reward_popup, "position:y", _reward_base_y - 50, 0.5)
	tween.parallel().tween_property(reward_popup, "modulate:a", 0.0, 2.0)
	await tween.finished
	reward_popup.visible = false
	reward_popup.position.y = _reward_base_y
