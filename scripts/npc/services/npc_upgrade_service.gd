@tool
class_name QuizRpgNpcUpgrade
extends QuizRpgNpcService

## Kowal — ulepszanie broni z potencjałem (ekwipunek_szkic.md sekcje 4, 10, 12): okno UpgradePanel
## (scenes/ui/upgrade_panel.tscn) z przedmiotami, które mają w danych `upgrade_to` — założonymi przez członków drużyny
## i z ekwipunku. Ulepszenie zamienia przedmiot na następny etap (założony zostaje założony), pobiera dukaty i materiał;
## etap blokuje flaga fabularna `upgrade_flag` (kowal „nie pamięta jeszcze”, jak to zrobić).

const UpgradePanelScript = preload("../../ui/upgrade_panel.gd")

enum Status { OK, LOCKED, GOLD, ITEM }

## Liczba ulepszeń wykonanych od ostatniego uruchomienia usługi (po zamknięciu panelu kowal idzie do kowadła).
var _upgrades_done := 0

@export var intro_lines: PackedStringArray = []
@export var intro_lines_key: String = ""


## Oferta: [{item, next, member (-1 = z ekwipunku), slot, status}] — najpierw założone (kolejność drużyny), potem ekwipunek.
func offers(npc: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ps := QuizRpgNpcContext.player_stats(npc)
	if ps == null:
		return out
	for mi in range(ps.party.size()):
		var eq: Dictionary = (ps.party[mi] as Dictionary).get("equipment", {})
		for slot in eq:
			_add_offer(out, npc, str(eq[slot]), mi, str(slot))
	for e in ps.get_inventory_entries():
		_add_offer(out, npc, str(e.get("item_id", "")), -1, "")
	return out


func _add_offer(out: Array[Dictionary], npc: Node, item_id: String, member: int, slot: String) -> void:
	var it := QuizRpgNpcContext.item(npc, item_id)
	if it == null or it.upgrade_to == "":
		return
	var nxt := QuizRpgNpcContext.item(npc, it.upgrade_to)
	if nxt == null:
		return
	out.append({"item": it, "next": nxt, "member": member, "slot": slot, "status": status(npc, it)})


func status(npc: Node, it: QuizRpgItemData) -> Status:
	if not QuizRpgNpcContext.has_flag(npc, it.upgrade_flag):
		return Status.LOCKED
	var ps := QuizRpgNpcContext.player_stats(npc)
	if int(ps.gold) < it.upgrade_gold:
		return Status.GOLD
	if it.upgrade_item_id != "" and ps.get_item_count(it.upgrade_item_id) < it.upgrade_item_count:
		return Status.ITEM
	return Status.OK


## Ulepszenie oferty: false (bez zmian), gdy status nie jest OK.
func upgrade(npc: Node, offer: Dictionary) -> bool:
	var it: QuizRpgItemData = offer.item
	if status(npc, it) != Status.OK:
		return false
	var ps := QuizRpgNpcContext.player_stats(npc)
	if int(offer.member) < 0 and ps.get_item_count(it.item_id) < 1:
		return false
	if it.upgrade_gold > 0 and not ps.spend_gold(it.upgrade_gold):
		return false
	if it.upgrade_item_id != "" and not ps.consume_item(it.upgrade_item_id, it.upgrade_item_count):
		ps.add_gold(it.upgrade_gold)
		return false
	if int(offer.member) >= 0:
		var ok: bool = ps.replace_equipped_item(int(offer.member), str(offer.slot), it.upgrade_to)
		if ok:
			_upgrades_done += 1
		return ok
	ps.consume_item(it.item_id, 1)
	ps.add_item(it.upgrade_to, 1)
	_upgrades_done += 1
	return true


func run(npc: Node) -> void:
	if not intro_lines.is_empty():
		await npc.say(QuizRpgNpcContext.lines(intro_lines, intro_lines_key))
	_upgrades_done = 0
	var panel := UpgradePanelScript.open(npc, self)
	await panel.closed
	if _upgrades_done > 0 and npc.has_method("work_at_station"):
		await npc.work_at_station()
