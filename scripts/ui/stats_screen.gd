extends Control

## Ekran statystyk dostepny z pauzy — monitorowanie postegow.

@onready var stats_text     : RichTextLabel = $Panel/MarginContainer/VBoxContainer/StatsText
@onready var rewards_list   : VBoxContainer = $Panel/MarginContainer/VBoxContainer/RewardsList
@onready var close_btn      : Button        = $Panel/MarginContainer/VBoxContainer/CloseBtn
@onready var difficulty_text: RichTextLabel = $Panel/MarginContainer/VBoxContainer/DifficultyText

var _ps: Node   # PlayerStats
var _dm: Node   # DifficultyManager


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	_dm = CoreManager.get_singleton("DifficultyManager")
	if not _ps:
		push_error("StatsScreen: PlayerStats niedostepny przez CoreManager")
	close_btn.pressed.connect(_on_close)
	_populate()


func _populate() -> void:
	if not _ps:
		return

	var accuracy     := QuizManager.get_overall_accuracy()
	var total_answered : int = _ps.total_correct + _ps.total_wrong

	stats_text.text = (
		"[b]" + QuizRpgI18n.t("stats.progress_title", "Postępy gracza") + "[/b]\n\n"
		+ "[b]" + QuizRpgI18n.t("stats.level", "Poziom:") + "[/b] %d\n" % _ps.level
		+ "[b]XP:[/b] %d / %d\n" % [_ps.xp, _ps.xp_to_next_level()]
		+ "[b]" + QuizRpgI18n.t("stats.points", "Punkty:") + "[/b] %d\n" % _ps.points
		+ "[b]HP:[/b] %d / %d\n\n" % [_ps.hp, _ps.max_hp]
		+ "[b]" + QuizRpgI18n.t("stats.quiz_stats", "Quiz — statystyki") + "[/b]\n"
		+ QuizRpgI18n.tf("stats.total_answers", {"total": total_answered}, "Odpowiedzi ogółem: {total}") + "\n"
		+ QuizRpgI18n.tf("stats.correct_answers", {"correct": _ps.total_correct, "accuracy": "%.0f" % (accuracy * 100.0)}, "Poprawne: {correct} ({accuracy}%)") + "\n"
		+ QuizRpgI18n.tf("stats.wrong_answers", {"wrong": _ps.total_wrong}, "Błędne: {wrong}") + "\n"
		+ QuizRpgI18n.tf("stats.current_streak", {"streak": _ps.streak}, "Aktualna seria: {streak}") + "\n"
		+ QuizRpgI18n.tf("stats.best_streak", {"best_streak": _ps.best_streak}, "Najlepsza seria: {best_streak}") + "\n"
		+ QuizRpgI18n.tf("stats.rng_bonus", {"rng_bonus": "%.0f" % (_ps.rng_bonus * 100.0)}, "Bonus RNG: +{rng_bonus}%")
	)

	# Trudnosc per kategoria
	var diff_text := "[b]" + QuizRpgI18n.t("stats.adaptive_difficulty", "Adaptacyjna trudność") + "[/b]\n"
	if _dm:
		diff_text += QuizRpgI18n.tf("stats.global_difficulty", {"diff": "%.1f" % _dm.get_global_difficulty()}, "Globalna: {diff} / 5\n")
	else:
		diff_text += QuizRpgI18n.t("stats.dm_unavailable", "(DifficultyManager niedostępny)\n")
	if difficulty_text:
		difficulty_text.text = diff_text

	# Nagrody
	if rewards_list:
		for child in rewards_list.get_children():
			child.queue_free()
		if _ps.rewards.is_empty():
			var lbl = Label.new()
			lbl.text = QuizRpgI18n.t("stats.no_rewards", "Brak nagród — graj dalej!")
			rewards_list.add_child(lbl)
		else:
			for r in _ps.rewards:
				var lbl = Label.new()
				lbl.text = "\U0001F3C6 " + QuizRpgI18n.t("reward." + r, r)
				rewards_list.add_child(lbl)


func _on_close() -> void:
	queue_free()
