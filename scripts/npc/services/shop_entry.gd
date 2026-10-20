@tool
class_name QuizRpgShopEntry
extends Resource

## Pozycja asortymentu sklepu NPC: przedmiot, cena (0 = cena z przedmiotu) i flaga fabularna, od której jest
## w sprzedaży (tiery sprzętu blokowane postępem — decyzja usera 2026-10-12).

@export var item: QuizRpgItemData
@export var price: int = 0
@export var required_flag: String = ""


func final_price() -> int:
	return price if price > 0 else (item.price if item != null else 0)
