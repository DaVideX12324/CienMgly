@tool
class_name QuizRpgStationTier
extends Resource

## Koszt wejścia stanowiska na kolejny tier (pozycja listy costs usługi QuizRpgNpcStationUpgrade).

@export var gold: int = 0
## Materiał (id przedmiotu, np. iron_ore) i jego liczba; pusty id = bez materiału.
@export var item_id: String = ""
@export var item_count: int = 0
## Flaga fabularna, bez której NPC „nie wie jeszcze, jak to rozbudować” (np. boss:cave_return); pusta = zawsze.
@export var required_flag: String = ""
