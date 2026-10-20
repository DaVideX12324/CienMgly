@tool
class_name QuizRpgNpcShop
extends QuizRpgNpcService

## Sklep: okno ShopPanel (scenes/ui/shop_panel.tscn) z zakładkami Kup / Sprzedaj. Asortyment = pozycje stock
## z odblokowaną flagą; sprzedaż przedmiotów z ceną za połowę (QuizRpgItemData.sell_price), bez założonych.

const ShopPanelScript = preload("../../ui/shop_panel.gd")

@export var stock: Array[QuizRpgShopEntry] = []
@export var can_sell: bool = true
## Linie przed otwarciem sklepu (puste = od razu okno).
@export var intro_lines: PackedStringArray = []
@export var intro_lines_key: String = ""


## Pozycje w sprzedaży (z przedmiotem i odblokowaną flagą).
func available_stock(npc: Node) -> Array[QuizRpgShopEntry]:
	var out: Array[QuizRpgShopEntry] = []
	for e in stock:
		if e != null and e.item != null and e.final_price() > 0 and QuizRpgNpcContext.has_flag(npc, e.required_flag):
			out.append(e)
	return out


## Zakup `count` sztuk: false (bez zmian), gdy brakuje złota.
func buy(npc: Node, entry: QuizRpgShopEntry, count: int = 1) -> bool:
	var ps := QuizRpgNpcContext.player_stats(npc)
	if ps == null or entry == null or entry.item == null or count <= 0:
		return false
	if not ps.spend_gold(entry.final_price() * count):
		return false
	ps.add_item(entry.item.item_id, count)
	return true


## Sprzedaż `count` sztuk z ekwipunku (stosu, nie założonych): false, gdy brak przedmiotu albo nie ma ceny.
func sell(npc: Node, item_id: String, count: int = 1) -> bool:
	var ps := QuizRpgNpcContext.player_stats(npc)
	var it := QuizRpgNpcContext.item(npc, item_id)
	if ps == null or it == null or it.sell_price() <= 0 or count <= 0 or ps.get_item_count(item_id) < count:
		return false
	if not ps.consume_item(item_id, count):
		return false
	ps.add_gold(it.sell_price() * count)
	return true


func run(npc: Node) -> void:
	if not intro_lines.is_empty():
		await npc.say(QuizRpgNpcContext.lines(intro_lines, intro_lines_key))
	var panel := ShopPanelScript.open(npc, self)
	await panel.closed
