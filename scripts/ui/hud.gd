extends CanvasLayer

## Nakładka na mapę: komunikaty nagród (awans, nagroda) i zaciemnienie przejść (FadeOverlay —
## GameManager). Statystyki gracza tylko w menu Esc (pause_menu).

@onready var reward_popup: Label       = $RewardPopup
@onready var fade_overlay: ColorRect   = $FadeOverlay

var _ps: Node  # PlayerStats
var _reward_base_y: float = 80.0


func _ready() -> void:
	if reward_popup:
		reward_popup.visible = false
		_reward_base_y = reward_popup.position.y

	if fade_overlay:
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_ps = CoreManager.get_singleton("PlayerStats")
	if not _ps:
		push_error("HUD: PlayerStats niedostepny przez CoreManager")
		return
	_ps.level_up.connect(_on_level_up)
	_ps.reward_earned.connect(_on_reward_earned)


func _on_level_up(new_level: int) -> void:
	_show_reward_popup("LEVEL UP! Lvl %d" % new_level)


func _on_reward_earned(reward_name: String) -> void:
	_show_reward_popup("Nagroda: " + reward_name)


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
