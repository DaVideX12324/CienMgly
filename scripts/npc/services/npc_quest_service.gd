@tool
class_name QuizRpgNpcQuest
extends QuizRpgNpcService

## Zadanie od NPC (pozycja menu rozmowy): propozycja -> przyjęcie (wpis w dzienniku, menu pauzy „Zadania”) -> postęp ->
## oddanie z nagrodą (dukaty, XP drużyny, przedmioty) i flagą `quest:<quest_id>` (QuizRpgFlagGate, required_flag usług
## i drzwi). Cele (QuizRpgQuestLog.Goal): poprawne odpowiedzi, pokonani wrogowie (id pliku danych, np. rat_base, albo
## prefiks rat_*; pusty = dowolni), przedmiot (zabierany przy oddaniu), flaga fabularna (np. boss:sewer).
## W liniach: {count} — wymagana liczba, {left} — ile jeszcze, {target} — nazwa celu, {reward} — nagroda.

## Identyfikator zadania (unikalny w grze) — klucz wpisu w zapisie i flaga po oddaniu: quest:<quest_id>.
@export var quest_id: String = ""
## Tytuł w dzienniku (klucz tłumaczenia title_key; pusty = sam tytuł).
@export var title: String = ""
@export var title_key: String = ""
@export var goal: QuizRpgQuestLog.Goal = QuizRpgQuestLog.Goal.DEFEAT_ENEMIES
@export_range(1, 999) var goal_count: int = 1
## Wróg (id pliku danych / prefiks z *), przedmiot (item_id) albo flaga — wg celu.
@export var goal_target: String = ""
## Własny opis celu w dzienniku (pusty = opis wg celu); dla flagi zalecany, np. „Pokonaj władcę ścieków”.
@export var goal_text: String = ""
@export var goal_key: String = ""

@export_group("Nagroda")
@export var reward_gold: int = 0
@export var reward_xp: int = 0
## Przedmioty: item_id -> liczba sztuk.
@export var reward_items: Dictionary[String, int] = {}

@export_group("Linie")
## Propozycja zadania (pierwsza rozmowa); po niej pytanie o przyjęcie.
@export var offer_lines: PackedStringArray = []
@export var offer_key: String = ""
## Rozmowa w trakcie (cel jeszcze niezrobiony).
@export var progress_lines: PackedStringArray = []
@export var progress_key: String = ""
## Oddanie zadania (przed nagrodą).
@export var done_lines: PackedStringArray = []
@export var done_key: String = ""
## Po oddaniu (pozycja zostaje w menu tylko z tymi liniami; puste = zadanie znika z menu).
@export var after_lines: PackedStringArray = []
@export var after_key: String = ""


func localized_label() -> String:
	if label == "" and label_key == "":
		if title == "" and title_key == "":
			return QuizRpgI18n.t("npc.service.quest", "Zadanie")
		return QuizRpgI18n.tf("npc.service.quest_named", {"title": _title()}, "Zadanie: {title}")
	return super.localized_label()


func is_available(npc: Node) -> bool:
	if quest_id == "" or not super.is_available(npc):
		return false
	return QuizRpgQuestLog.state(QuizRpgNpcContext.player_stats(npc), quest_id) != QuizRpgQuestLog.DONE or not after_lines.is_empty()


func done_flag() -> String:
	return QuizRpgQuestLog.DONE_FLAG_PREFIX + quest_id


func run(npc: Node) -> void:
	var ps := QuizRpgNpcContext.player_stats(npc)
	if ps == null or quest_id == "":
		return
	var lsm := QuizRpgNpcContext.singleton(npc, "LevelStateManager")
	match QuizRpgQuestLog.state(ps, quest_id):
		"":
			await npc.say(_lines(npc, offer_lines, offer_key, {}))
			var pick: int = await npc.ask(QuizRpgI18n.t("quest.accept_question", "Przyjmujesz zadanie?"),
					PackedStringArray([QuizRpgI18n.t("quest.accept", "Przyjmuję"), QuizRpgI18n.t("quest.decline", "Nie teraz")]))
			if pick == 0:
				_accept(npc, ps)
		QuizRpgQuestLog.ACTIVE:
			var e := QuizRpgQuestLog.entry(ps, quest_id)
			if QuizRpgQuestLog.is_complete(ps, lsm, e):
				await npc.say(_lines(npc, done_lines, done_key, e))
				_complete(npc, ps, e)
			else:
				await npc.say(_lines(npc, progress_lines, progress_key, e))
		QuizRpgQuestLog.DONE:
			await npc.say(_lines(npc, after_lines, after_key, {}))


func _accept(npc: Node, ps: Node) -> void:
	ps.quests[quest_id] = {
		"state": QuizRpgQuestLog.ACTIVE, "goal": int(goal), "count": goal_count, "target": goal_target,
		"start": QuizRpgQuestLog.counter(ps, goal, goal_target),
		"title": title, "title_key": title_key, "goal_text": goal_text, "goal_key": goal_key,
		"giver": str(npc.get("npc_name")) if "npc_name" in npc else "",
		"giver_key": str(npc.get("npc_name_key")) if "npc_name_key" in npc else "",
	}
	ps.quests_changed.emit()
	_toast(npc, QuizRpgI18n.tf("quest.accepted", {"title": _title()}, "Nowe zadanie: {title}"))


func _complete(npc: Node, ps: Node, e: Dictionary) -> void:
	if goal == QuizRpgQuestLog.Goal.BRING_ITEM and goal_target != "":
		ps.consume_item(goal_target, goal_count)
	if reward_gold > 0:
		ps.add_gold(reward_gold)
	for id: String in reward_items:
		ps.add_item(id, maxi(int(reward_items[id]), 1))
	if reward_xp > 0:
		ps.add_xp(reward_xp)
	e["state"] = QuizRpgQuestLog.DONE
	ps.quests[quest_id] = e
	QuizRpgNpcContext.set_flag(npc, done_flag())
	ps.quests_changed.emit()
	QuizRpgNpcContext.play_sfx(npc, "victory")
	var reward := reward_text(npc)
	var msg := QuizRpgI18n.tf("quest.completed", {"title": _title()}, "Zadanie wykonane: {title}")
	_toast(npc, msg + ("\n" + reward if reward != "" else ""))


## Nagroda słownie: „150 D, 200 XP, Mikstura ×2”.
func reward_text(node: Node) -> String:
	var parts := PackedStringArray()
	if reward_gold > 0:
		parts.append("%d D" % reward_gold)
	if reward_xp > 0:
		parts.append("%d XP" % reward_xp)
	for id: String in reward_items:
		var n := maxi(int(reward_items[id]), 1)
		parts.append(QuizRpgNpcContext.item_name(node, id) + (" ×%d" % n if n > 1 else ""))
	return ", ".join(parts)


func _title() -> String:
	return QuizRpgI18n.t(title_key, title) if title_key != "" else title


func _lines(npc: Node, texts: PackedStringArray, key: String, e: Dictionary) -> PackedStringArray:
	var ps := QuizRpgNpcContext.player_stats(npc)
	var lsm := QuizRpgNpcContext.singleton(npc, "LevelStateManager")
	var done := QuizRpgQuestLog.progress(ps, lsm, e) if not e.is_empty() else 0
	var args := {
		"count": goal_count, "left": maxi(goal_count - done, 0),
		"target": QuizRpgQuestLog.target_name(npc, goal, goal_target), "reward": reward_text(npc),
	}
	return QuizRpgNpcContext.lines(texts, key, args)


func _toast(npc: Node, text: String) -> void:
	var lm := QuizRpgNpcContext.singleton(npc, "LootManager")
	if lm != null and lm.has_method("show_message_toast"):
		lm.call("show_message_toast", text)
