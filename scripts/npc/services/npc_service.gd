@tool
class_name QuizRpgNpcService
extends Resource

## Usługa NPC (pozycja w menu rozmowy QuizRpgNpc): sklep, odpoczynek, nauka umiejętności, rozmowa. Dane w .tres
## (sub-zasób sceny NPC) — scena NPC to szablon, usługi wpina się w Inspectorze. Podklasy nadpisują run().

## Napis w menu rozmowy; klucz tłumaczenia label_key (pusty = sam napis).
@export var label: String = ""
@export var label_key: String = ""
## Flaga fabularna (LevelStateManager.has_device_progress), bez której usługi nie ma w menu; pusta = zawsze.
@export var required_flag: String = ""


func localized_label() -> String:
	return QuizRpgI18n.t(label_key, label) if label_key != "" else label


func is_available(npc: Node) -> bool:
	return required_flag == "" or QuizRpgNpcContext.has_flag(npc, required_flag)


## Wykonanie usługi (korutyna — NPC czeka `await service.run(npc)`). Gra jest w stanie CUTSCENE przez całą rozmowę.
func run(_npc: Node) -> void:
	pass
