@tool
class_name QuizRpgNpcStationUpgrade
extends QuizRpgNpcService

## Rozbudowa stanowiska pracy NPC (QuizRpgNpc.work_station = QuizRpgStationSlot): za dukaty i materiał stanowisko
## przechodzi na kolejny tier (nowy wygląd), a flaga `station:<id>:tier<N>` odblokowuje to, co ją wymaga
## (required_flag pozycji sklepu / ulepszenia, usług innych NPC). Pozycji w menu nie ma, gdy NPC nie ma slotu.

## costs[0] = koszt wejścia na tier 2, costs[1] = na tier 3 itd.
@export var costs: Array[QuizRpgStationTier] = []


func is_available(npc: Node) -> bool:
	return super.is_available(npc) and _slot(npc) != null


func _slot(npc: Node) -> QuizRpgStationSlot:
	return npc.get("work_station") as QuizRpgStationSlot


func _cost_text(npc: Node, c: QuizRpgStationTier) -> String:
	var parts := PackedStringArray()
	if c.gold > 0:
		parts.append("%d D" % c.gold)
	if c.item_id != "" and c.item_count > 0:
		parts.append("%d× %s" % [c.item_count, QuizRpgNpcContext.item_name(npc, c.item_id)])
	return " + ".join(parts)


func run(npc: Node) -> void:
	var slot := _slot(npc)
	if slot == null:
		return
	var cur := slot.tier()
	if cur >= mini(slot.max_tier(), costs.size() + 1):
		await npc.say([QuizRpgI18n.t("npc.station.max", "Lepszego stanowiska już nie zbuduję.")])
		return
	var c := costs[cur - 1]
	if not QuizRpgNpcContext.has_flag(npc, c.required_flag):
		await npc.say([QuizRpgI18n.t("npc.station.locked", "Nie wiem jeszcze, jak to rozbudować… Wróć, gdy coś się zmieni.")])
		return
	var q := QuizRpgI18n.tf("npc.station.offer", {"tier": cur + 1, "cost": _cost_text(npc, c)}, "Rozbudowa stanowiska do poziomu {tier} kosztuje {cost}. Rozbudować?")
	var pick: int = await npc.ask(q, [QuizRpgI18n.t("npc.station.yes", "Rozbuduj"), QuizRpgI18n.t("npc.station.no", "Nie teraz")])
	if pick != 0:
		return
	var ps := QuizRpgNpcContext.player_stats(npc)
	if ps == null:
		return
	if int(ps.gold) < c.gold:
		await npc.say([QuizRpgI18n.t("shop.no_gold", "Za mało dukatów.")])
		return
	if c.item_id != "" and ps.get_item_count(c.item_id) < c.item_count:
		await npc.say([QuizRpgI18n.tf("teacher.status_item", {"item": QuizRpgNpcContext.item_name(npc, c.item_id)}, "Brakuje: {item}.")])
		return
	if c.gold > 0 and not ps.spend_gold(c.gold):
		return
	if c.item_id != "" and c.item_count > 0 and not ps.consume_item(c.item_id, c.item_count):
		ps.add_gold(c.gold)
		return
	QuizRpgNpcContext.set_flag(npc, QuizRpgStationSlot.tier_flag(slot.station_id, cur + 1))
	slot.refresh()
	QuizRpgNpcContext.play_sfx(npc, "level_up")
	await npc.say([QuizRpgI18n.t("npc.station.done", "Gotowe! Stanowisko jest teraz lepsze.")])
