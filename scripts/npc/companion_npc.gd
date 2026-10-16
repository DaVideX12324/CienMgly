@tool
extends StaticBody2D

## Postać do zwerbowania (scena scenes/npc/companion_npc.tscn): rozmowa w oknie DialogBox, zadanie, po jego wykonaniu
## dołącza do drużyny (PlayerStats.recruit) i znika z mapy (dalej idzie za bohaterem). Wygląd z danych postaci
## (hero_id). Stan zadania w PlayerStats.companion_quests (zapis gry). W tekstach: {count} — wymagana liczba,
## {left} — ile jeszcze, {item} — nazwa przedmiotu.

const DialogBox = preload("../ui/dialog_box.gd")
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const PlayerStatsScript = preload("../../autoloads/player_stats.gd")

enum Quest { NONE, ANSWER_CORRECT, BRING_ITEM }

@export var hero_id: String = "lotrzyk":
	set(v):
		hero_id = v
		if is_node_ready():
			_apply_look()
## NONE — dołącza po pierwszej rozmowie; ANSWER_CORRECT — poprawne odpowiedzi w quizach od przyjęcia zadania;
## BRING_ITEM — przedmiot quest_item_id w ekwipunku (zabierany przy oddaniu).
@export var quest: Quest = Quest.ANSWER_CORRECT
@export var quest_count: int = 5
@export var quest_item_id: String = ""
@export var face_left: bool = false:
	set(v):
		face_left = v
		if is_node_ready():
			_apply_look()
@export var intro_lines: PackedStringArray = [
	"Hej, wędrowcze. Ta mgła odebrała mi pamięć — ale nie rozum.",
	"Odpowiedz poprawnie na {count} pytań, a uwierzę, że warto z tobą iść.",
]
@export var progress_lines: PackedStringArray = ["Jeszcze {left}. Nie poddawaj się."]
@export var done_lines: PackedStringArray = ["Dotrzymałeś słowa. Idę z tobą!"]

var _busy := false


func _ready() -> void:
	_apply_look()
	if Engine.is_editor_hint():
		return
	var ps := _ps()
	if ps and ps.has_member(hero_id):
		queue_free()   # już w drużynie — idzie za bohaterem


## Wygląd z danych postaci (także w edytorze — scena WYSIWYG).
func _apply_look() -> void:
	var hero := _hero()
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or hero == null or hero.sprite_frames == null:
		return
	sprite.sprite_frames = hero.sprite_frames
	sprite.offset = hero.sprite_offset
	sprite.flip_h = face_left
	sprite.play(&"idle")


## Dane postaci: z PlayerStats w grze, inaczej wprost z pliku (HERO_PATHS) — edytor, render sceny.
func _hero() -> QuizRpgHeroData:
	var ps := _ps() if not Engine.is_editor_hint() else null
	if ps:
		return ps.hero_by_id(hero_id)
	var p := str(PlayerStatsScript.HERO_PATHS.get(hero_id, ""))
	var full := QuizRpgPaths.path(p) if p != "" else ""
	return load(full) as QuizRpgHeroData if full != "" and ResourceLoader.exists(full) else null


func can_interact() -> bool:
	return not _busy


func interaction_prompt_text() -> String:
	return QuizRpgI18n.t("prompt.talk", "Porozmawiaj")


func interaction_prompt_offset() -> Vector2:
	return Vector2(0, -34)


func interact(_player: Node2D) -> void:
	var ps := _ps()
	if _busy or ps == null or ps.has_member(hero_id):
		return
	_busy = true
	var st: Dictionary = ps.companion_quests.get(hero_id, {})
	var lines := PackedStringArray()
	var join := false
	if str(st.get("state", "")) == "":
		lines = intro_lines
		st = {"state": "active", "start": _counter(ps)}
		ps.companion_quests[hero_id] = st
		join = quest == Quest.NONE
	elif _quest_done(ps, st):
		lines = done_lines
		join = true
	else:
		lines = progress_lines
	var hero := _hero()
	var box := DialogBox.open(self, hero.display_name if hero else "", _fill(lines, ps, st))
	await box.finished
	if join:
		if quest == Quest.BRING_ITEM and quest_item_id != "":
			ps.consume_item(quest_item_id, quest_count)
		st["state"] = "done"
		ps.companion_quests[hero_id] = st
		ps.recruit(hero_id)
		queue_free()
		return
	_busy = false


func _counter(ps: Node) -> int:
	match quest:
		Quest.ANSWER_CORRECT:
			return int(ps.total_correct)
		Quest.BRING_ITEM:
			return ps.get_item_count(quest_item_id)
	return 0


func _left(ps: Node, st: Dictionary) -> int:
	match quest:
		Quest.ANSWER_CORRECT:
			return maxi(quest_count - (int(ps.total_correct) - int(st.get("start", 0))), 0)
		Quest.BRING_ITEM:
			return maxi(quest_count - ps.get_item_count(quest_item_id), 0)
	return 0


func _quest_done(ps: Node, st: Dictionary) -> bool:
	return quest == Quest.NONE or _left(ps, st) <= 0


func _fill(lines: PackedStringArray, ps: Node, st: Dictionary) -> PackedStringArray:
	var item_name := quest_item_id
	var inv := _singleton("InventoryService")
	if inv and inv.has_method("get_item") and quest_item_id != "":
		var it: Variant = inv.call("get_item", quest_item_id)
		if it != null and "display_name" in it:
			item_name = str(it.display_name)
	var out := PackedStringArray()
	for l in lines:
		var line_key := ""
		if l == "Hej, wędrowcze. Ta mgła odebrała mi pamięć — ale nie rozum.":
			line_key = "npc.companion.intro_1"
		elif l == "Odpowiedz poprawnie na {count} pytań, a uwierzę, że warto z tobą iść.":
			line_key = "npc.companion.intro_2"
		elif l == "Jeszcze {left}. Nie poddawaj się.":
			line_key = "npc.companion.progress"
		elif l == "Dotrzymałeś słowa. Idę z tobą!":
			line_key = "npc.companion.done"
		var text := QuizRpgI18n.t(line_key, l) if line_key != "" else QuizRpgI18n.t(l, l)
		out.append(text.format({"count": quest_count, "left": _left(ps, st), "item": item_name}))
	return out


func _ps() -> Node:
	return _singleton("PlayerStats")


func _singleton(n: String) -> Node:
	var cm := get_node_or_null("/root/CoreManager")
	var s: Variant = cm.get_singleton(n) if cm and cm.has_method("get_singleton") else null
	return s as Node
