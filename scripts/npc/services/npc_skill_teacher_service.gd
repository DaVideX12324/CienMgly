@tool
class_name QuizRpgNpcSkillTeacher
extends QuizRpgNpcService

## Nauczyciel umiejętności: okno SkillTeacherPanel (scenes/ui/skill_teacher_panel.tscn) — lekcje dla członków
## drużyny (z flagą fabularną), koszt w złocie / przedmiocie, wymagany poziom; nauka = PlayerStats.unlock_skill.

const SkillTeacherPanelScript = preload("../../ui/skill_teacher_panel.gd")

enum Status { OK, KNOWN, LEVEL, GOLD, ITEM }

@export var lessons: Array[QuizRpgSkillLesson] = []
@export var intro_lines: PackedStringArray = []
@export var intro_lines_key: String = ""


## Oferta: [{member, lesson, skill (QuizRpgSkillData), status}] — członkowie drużyny × lekcje z odblokowaną flagą
## i umiejętnością w puli członka.
func offers(npc: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ps := QuizRpgNpcContext.player_stats(npc)
	if ps == null:
		return out
	for mi in range(ps.party.size()):
		var member: Dictionary = ps.party[mi]
		var hid := str(member.get("hero_id", ""))
		for ls in lessons:
			if ls == null or ls.skill_id == "" or (ls.hero_id != "" and ls.hero_id != hid):
				continue
			if not QuizRpgNpcContext.has_flag(npc, ls.required_flag):
				continue
			for sk in ps.get_member_skill_pool(mi):
				if sk.skill_id == ls.skill_id:
					out.append({"member": mi, "lesson": ls, "skill": sk, "status": status(npc, mi, ls)})
					break
	return out


func status(npc: Node, member_index: int, ls: QuizRpgSkillLesson) -> Status:
	var ps := QuizRpgNpcContext.player_stats(npc)
	var member: Dictionary = ps.party[member_index]
	if (member.get("skills", []) as Array).has(ls.skill_id):
		return Status.KNOWN
	if int(member.get("level", 1)) < ls.min_level:
		return Status.LEVEL
	if int(ps.gold) < ls.gold:
		return Status.GOLD
	if ls.item_id != "" and ps.get_item_count(ls.item_id) < ls.item_count:
		return Status.ITEM
	return Status.OK


## Nauka: pobiera koszt i odblokowuje umiejętność; false (bez zmian), gdy status nie jest OK.
func teach(npc: Node, member_index: int, ls: QuizRpgSkillLesson) -> bool:
	if status(npc, member_index, ls) != Status.OK:
		return false
	var ps := QuizRpgNpcContext.player_stats(npc)
	if ls.gold > 0 and not ps.spend_gold(ls.gold):
		return false
	if ls.item_id != "" and not ps.consume_item(ls.item_id, ls.item_count):
		ps.add_gold(ls.gold)
		return false
	return ps.unlock_skill(member_index, ls.skill_id)


func run(npc: Node) -> void:
	if not intro_lines.is_empty():
		await npc.say(QuizRpgNpcContext.lines(intro_lines, intro_lines_key))
	var panel := SkillTeacherPanelScript.open(npc, self)
	await panel.closed
