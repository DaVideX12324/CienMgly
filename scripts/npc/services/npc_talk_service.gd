@tool
class_name QuizRpgNpcTalk
extends QuizRpgNpcService

## Rozmowa (pozycja menu NPC albo sama rozmowa NPC bez usług): linie tekstu w oknie DialogBox. Po pierwszej
## rozmowie może ustawić flagę fabularną (set_flag) i mówić potem inne linie (repeat_lines).

@export var lines: PackedStringArray = []
## Klucze tłumaczeń linii: `<lines_key>_1`, `_2`… (pusty = teksty z listy).
@export var lines_key: String = ""
## Linie przy kolejnych rozmowach (po ustawieniu set_flag); puste = te same co za pierwszym razem.
@export var repeat_lines: PackedStringArray = []
@export var repeat_lines_key: String = ""
## Flaga fabularna ustawiana po rozmowie (np. „rozmawiał z kowalem” — odblokowuje usługę innego NPC).
@export var set_flag: String = ""


func run(npc: Node) -> void:
	var again := set_flag != "" and QuizRpgNpcContext.has_flag(npc, set_flag) and not repeat_lines.is_empty()
	var texts := QuizRpgNpcContext.lines(repeat_lines, repeat_lines_key) if again else QuizRpgNpcContext.lines(lines, lines_key)
	if not texts.is_empty():
		await npc.say(texts)
	QuizRpgNpcContext.set_flag(npc, set_flag)
