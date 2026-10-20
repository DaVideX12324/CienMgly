extends CanvasLayer

## Okno nauczyciela umiejętności NPC (scena scenes/ui/skill_teacher_panel.tscn, WYSIWYG — skrypt tylko wypełnia
## listę): wiersze „postać — umiejętność” z kosztem (↑/↓, Enter / klik = naucz), opis i wymagania po prawej, złoto
## w nagłówku. Esc zamyka -> sygnał closed. Logika w QuizRpgNpcSkillTeacher (offers / status / teach).

signal closed

const SCENE := "scenes/ui/skill_teacher_panel.tscn"
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const QuizTheme = preload("quiz_theme.gd")
const INPUT_GRACE := 0.15
const ROW_FONT := 30
const DIM := Color(1, 1, 1, 0.45)
const Status = QuizRpgNpcSkillTeacher.Status

@onready var _title: Label = %Title
@onready var _gold: Label = %Gold
@onready var _list: VBoxContainer = %List
@onready var _skill_name: Label = %ItemName
@onready var _stats: Label = %Stats
@onready var _desc: Label = %Desc
@onready var _cost: Label = %Cost
@onready var _message: Label = %Message
@onready var _hint: Label = %Hint

var teacher: QuizRpgNpcSkillTeacher
var npc: Node
var _age := 0.0
var _rows: Array[Button] = []
var _offers: Array[Dictionary] = []


## Otwiera okno nauki pod węzłem NPC. Zwraca okno — `await panel.closed`.
static func open(host: Node, teacher_service: QuizRpgNpcSkillTeacher) -> CanvasLayer:
	var panel: CanvasLayer = (load(QuizRpgPaths.path(SCENE)) as PackedScene).instantiate()
	panel.set("teacher", teacher_service)
	panel.set("npc", host)
	host.add_child(panel)
	return panel


func _ready() -> void:
	UiLayerScale.attach(self)
	_title.text = QuizRpgI18n.t("teacher.title", "Nauka umiejętności")
	_hint.text = QuizRpgI18n.t("teacher.hint", "Enter: naucz    Esc: wyjdź")
	_message.text = " "
	_refresh(0)


func _process(delta: float) -> void:
	_age += delta


func _refresh(focus_index: int) -> void:
	var ps := QuizRpgNpcContext.player_stats(npc)
	_gold.text = QuizRpgI18n.tf("shop.gold", {"gold": int(ps.gold) if ps else 0}, "Dukaty: {gold}")
	for c in _list.get_children():
		if c is Button:
			_list.remove_child(c)
			c.queue_free()
	_rows.clear()
	_offers.assign(teacher.offers(npc) if teacher else [])
	for o in _offers:
		var member: Dictionary = ps.party[int(o.member)]
		var sk: QuizRpgSkillData = o.skill
		var st: int = o.status
		var right := QuizRpgI18n.t("teacher.known", "znana") if st == Status.KNOWN else cost_text(npc, o.lesson)
		_add_row("%s — %s" % [str(member.get("name", "")), sk.localized_name()], right, st == Status.OK)
	(_list.get_node("Empty") as Label).visible = _rows.is_empty()
	(_list.get_node("Empty") as Label).text = QuizRpgI18n.t("teacher.empty", "Nie mam czego cię nauczyć.")
	if _rows.is_empty():
		_show_info(-1)
		return
	_rows[clampi(focus_index, 0, _rows.size() - 1)].call_deferred("grab_focus")


## Koszt lekcji: „50 D”, „Żeton ×1”, „50 D + Żeton ×1”, „za darmo”.
static func cost_text(node: Node, ls: QuizRpgSkillLesson) -> String:
	var parts: Array[String] = []
	if ls.gold > 0:
		parts.append(QuizRpgI18n.tf("shop.price", {"price": ls.gold}, "{price} D"))
	if ls.item_id != "":
		parts.append("%s ×%d" % [QuizRpgNpcContext.item_name(node, ls.item_id), ls.item_count])
	return " + ".join(parts) if not parts.is_empty() else QuizRpgI18n.t("teacher.free", "za darmo")


func _add_row(text: String, right: String, available: bool) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = QuizTheme.MENU_ITEM
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", ROW_FONT)
	b.custom_minimum_size = Vector2(0, 44)
	if not available:
		b.modulate = DIM
	var cost := Label.new()
	cost.text = right
	cost.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", ROW_FONT)
	cost.set_anchors_preset(Control.PRESET_FULL_RECT)
	cost.offset_right = -12
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cost)
	var idx := _rows.size()
	b.pressed.connect(_activate.bind(idx))
	b.focus_entered.connect(_show_info.bind(idx))
	b.focus_entered.connect(QuizTheme.set_menu_item_selected.bind(b, true))
	b.focus_exited.connect(QuizTheme.set_menu_item_selected.bind(b, false))
	_list.add_child(b)
	_rows.append(b)


func _show_info(idx: int) -> void:
	if idx < 0 or idx >= _offers.size():
		_skill_name.text = ""
		_stats.text = ""
		_desc.text = ""
		_cost.text = ""
		return
	var o: Dictionary = _offers[idx]
	var sk: QuizRpgSkillData = o.skill
	var ls: QuizRpgSkillLesson = o.lesson
	_skill_name.text = sk.localized_name()
	var costs: Array[String] = []
	if sk.sp_cost > 0 or sk.sp_cost_percent > 0.0:
		costs.append("SP %d" % sk.sp_cost_for(int((QuizRpgNpcContext.player_stats(npc).party[int(o.member)] as Dictionary).get("max_sp", 0))))
	if sk.tp_cost > 0:
		costs.append("TP %d" % sk.tp_cost)
	_stats.text = ", ".join(costs)
	_desc.text = sk.localized_description()
	_cost.text = QuizRpgI18n.tf("teacher.cost", {"cost": cost_text(npc, ls)}, "Koszt: {cost}") + "\n" + status_text(npc, int(o.status), ls)


## Powód, dla którego lekcja jest niedostępna (pusty, gdy można się uczyć).
static func status_text(node: Node, st: int, ls: QuizRpgSkillLesson) -> String:
	match st:
		Status.KNOWN:
			return QuizRpgI18n.t("teacher.status_known", "Ta postać już to umie.")
		Status.LEVEL:
			return QuizRpgI18n.tf("teacher.status_level", {"level": ls.min_level}, "Wymaga poziomu {level}.")
		Status.GOLD:
			return QuizRpgI18n.t("shop.no_gold", "Za mało dukatów.")
		Status.ITEM:
			return QuizRpgI18n.tf("teacher.status_item", {"item": QuizRpgNpcContext.item_name(node, ls.item_id)}, "Brakuje: {item}.")
	return ""


func _activate(idx: int) -> void:
	if _age < INPUT_GRACE or idx >= _offers.size():
		return
	var o: Dictionary = _offers[idx]
	var sk: QuizRpgSkillData = o.skill
	if teacher.teach(npc, int(o.member), o.lesson):
		var ps := QuizRpgNpcContext.player_stats(npc)
		var who := str((ps.party[int(o.member)] as Dictionary).get("name", ""))
		_message.text = QuizRpgI18n.tf("teacher.learned", {"name": who, "skill": sk.localized_name()}, "{name} uczy się: {skill}.")
		QuizRpgNpcContext.play_sfx(npc, "level_up")
	else:
		_message.text = status_text(npc, int(o.status), o.lesson)
	_refresh(idx)


func _unhandled_input(event: InputEvent) -> void:
	if _age < INPUT_GRACE:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
	elif event.is_action_pressed("interact"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and _rows.has(f):
			get_viewport().set_input_as_handled()
			_activate(_rows.find(f))
