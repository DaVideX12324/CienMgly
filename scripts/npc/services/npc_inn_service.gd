@tool
class_name QuizRpgNpcInn
extends QuizRpgNpcService

## Odpoczynek (karczma / punkt zapisu): za `price` złota cała drużyna wraca do pełna — HP (także nieprzytomni),
## SP, statusy zdjęte. Bez zapisu gry (decyzja usera 2026-10-21: zapis jest dostępny prawie zawsze z menu pauzy;
## narzucony zapis tylko w punktach QuizRpgSavePoint, np. przed point of no return).

@export var price: int = 20
## Po zapłacie karczmarka idzie do swojego stanowiska (QuizRpgNpc.work_station, np. kuchni) i dopiero potem drużyna wstaje wypoczęta.
@export var work_after_rest: bool = true


## Odpoczynek bez pytań (testy, darmowe łóżko): false, gdy brakuje złota.
func rest(npc: Node) -> bool:
	var ps := QuizRpgNpcContext.player_stats(npc)
	if ps == null or not ps.spend_gold(price):
		return false
	ps.rest_party()
	return true


func run(npc: Node) -> void:
	var ps := QuizRpgNpcContext.player_stats(npc)
	if ps == null:
		return
	var q := QuizRpgI18n.tf("npc.inn.offer", {"price": price, "gold": ps.gold}, "Odpoczynek kosztuje {price} D (masz {gold} D). Zostajesz na noc?")
	var yes := QuizRpgI18n.t("npc.inn.yes", "Odpocznij")
	var no := QuizRpgI18n.t("npc.inn.no", "Nie teraz")
	var pick: int = await npc.ask(q, [yes, no])
	if pick != 0:
		return
	if not rest(npc):
		await npc.say([QuizRpgI18n.t("npc.inn.no_gold", "Nie stać cię na nocleg.")])
		return
	if work_after_rest and npc.has_method("work_at_station"):
		await npc.work_at_station()
	QuizRpgNpcContext.play_sfx(npc, "heal")
	await npc.say([QuizRpgI18n.t("npc.inn.rested", "Drużyna wypoczęła. HP i SP odnowione.")])
