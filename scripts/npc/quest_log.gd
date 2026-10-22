class_name QuizRpgQuestLog
extends RefCounted

## Dziennik zadań NPC: wpisy w PlayerStats.quests (zapis gry), postęp liczony z samego wpisu — dziennik w menu pauzy
## nie potrzebuje sceny NPC. Wpis: {state, goal, count, target, start, title, title_key, giver, giver_key, goal_text,
## goal_key}. Po oddaniu zadania flaga fabularna `quest:<id>` (DONE_FLAG_PREFIX) — pod QuizRpgFlagGate, usługi NPC, drzwi.

enum Goal { ANSWER_CORRECT, DEFEAT_ENEMIES, BRING_ITEM, STORY_FLAG }

const ACTIVE := "active"
const DONE := "done"
const DONE_FLAG_PREFIX := "quest:"


static func entry(ps: Node, quest_id: String) -> Dictionary:
	return ps.quests.get(quest_id, {}) if ps != null else {}


static func state(ps: Node, quest_id: String) -> String:
	return str(entry(ps, quest_id).get("state", ""))


## Licznik celu w chwili przyjęcia (postęp liczy się od niego; przedmioty i flaga — stan bieżący).
static func counter(ps: Node, goal: int, target: String) -> int:
	match goal:
		Goal.ANSWER_CORRECT:
			return int(ps.total_correct)
		Goal.DEFEAT_ENEMIES:
			return int(ps.kill_count(target))
	return 0


## Ile celu zrobione (0..count).
static func progress(ps: Node, lsm: Node, e: Dictionary) -> int:
	var goal := int(e.get("goal", Goal.ANSWER_CORRECT))
	var target := str(e.get("target", ""))
	var count := maxi(int(e.get("count", 1)), 1)
	var done := 0
	match goal:
		Goal.ANSWER_CORRECT, Goal.DEFEAT_ENEMIES:
			done = counter(ps, goal, target) - int(e.get("start", 0))
		Goal.BRING_ITEM:
			done = int(ps.get_item_count(target))
		Goal.STORY_FLAG:
			done = count if lsm != null and bool(lsm.call("has_story_flag", target)) else 0
	return clampi(done, 0, count)


static func is_complete(ps: Node, lsm: Node, e: Dictionary) -> bool:
	return progress(ps, lsm, e) >= maxi(int(e.get("count", 1)), 1)


## Nazwa celu w wybranym języku: wróg (enemy.<id>.name; prefiks rat_* -> sam prefiks), przedmiot, inaczej id.
static func target_name(node: Node, goal: int, target: String) -> String:
	match goal:
		Goal.DEFEAT_ENEMIES:
			if target == "" or target.ends_with("*"):
				return target.trim_suffix("*").trim_suffix("_")
			return QuizRpgI18n.t("enemy.%s.name" % target, target)
		Goal.BRING_ITEM:
			return QuizRpgNpcContext.item_name(node, target)
	return target


static func title(e: Dictionary) -> String:
	return _text(e, "title_key", "title")


static func giver(e: Dictionary) -> String:
	return _text(e, "giver_key", "giver")


## Opis celu z postępem, np. „Pokonaj: Szczur (2/5)”.
static func goal_line(node: Node, ps: Node, lsm: Node, e: Dictionary) -> String:
	var goal := int(e.get("goal", Goal.ANSWER_CORRECT))
	var count := maxi(int(e.get("count", 1)), 1)
	var args := {"target": target_name(node, goal, str(e.get("target", ""))), "done": progress(ps, lsm, e), "count": count}
	var custom := _text(e, "goal_key", "goal_text")
	if custom != "":
		return custom.format(args) if goal == Goal.STORY_FLAG else "%s (%d/%d)" % [custom.format(args), args.done, count]
	match goal:
		Goal.ANSWER_CORRECT:
			return QuizRpgI18n.tf("quest.goal.answer", args, "Odpowiedz poprawnie ({done}/{count})")
		Goal.DEFEAT_ENEMIES:
			if str(e.get("target", "")) == "":
				return QuizRpgI18n.tf("quest.goal.defeat_any", args, "Pokonaj wrogów ({done}/{count})")
			return QuizRpgI18n.tf("quest.goal.defeat", args, "Pokonaj: {target} ({done}/{count})")
		Goal.BRING_ITEM:
			return QuizRpgI18n.tf("quest.goal.bring", args, "Przynieś: {target} ({done}/{count})")
	return QuizRpgI18n.t("quest.goal.flag", "Wykonaj zadanie")


## Wpisy dziennika do pokazania: aktywne (najpierw gotowe do oddania), potem ukończone.
static func sorted_ids(ps: Node, lsm: Node) -> Array[String]:
	var active: Array[String] = []
	var ready: Array[String] = []
	var done: Array[String] = []
	for id: String in ps.quests:
		var e: Dictionary = ps.quests[id]
		if str(e.get("state", "")) == DONE:
			done.append(id)
		elif is_complete(ps, lsm, e):
			ready.append(id)
		else:
			active.append(id)
	return ready + active + done


static func _text(e: Dictionary, key_field: String, text_field: String) -> String:
	var key := str(e.get(key_field, ""))
	var fallback := str(e.get(text_field, ""))
	return QuizRpgI18n.t(key, fallback) if key != "" else fallback
