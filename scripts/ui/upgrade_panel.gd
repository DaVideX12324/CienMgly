extends CanvasLayer

## Okno kowala — ulepszanie broni (scena scenes/ui/upgrade_panel.tscn, WYSIWYG — skrypt tylko wypełnia listę): wiersze
## „przedmiot (postać)” z kosztem (↑/↓, Enter / klik = ulepsz), po prawej etap obecny -> następny, statystyki, opis
## i powód niedostępności; dukaty w nagłówku. Esc zamyka -> sygnał closed. Logika w QuizRpgNpcUpgrade.

signal closed

const SCENE := "scenes/ui/upgrade_panel.tscn"
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const QuizTheme = preload("quiz_theme.gd")
const INPUT_GRACE := 0.15
## Wiersz listy (przycisk z ceną / kosztem po prawej) — scena WYSIWYG, wspólna dla usług NPC.
const ROW_SCENE: PackedScene = preload("../../scenes/ui/service_row.tscn")
const DIM := Color(1, 1, 1, 0.45)
const Status = QuizRpgNpcUpgrade.Status
const STATS := ["atk", "def", "mat", "mdf", "agi"]

@onready var _title: Label = %Title
@onready var _gold: Label = %Gold
@onready var _list: VBoxContainer = %List
@onready var _item_name: Label = %ItemName
@onready var _stats: Label = %Stats
@onready var _desc: Label = %Desc
@onready var _cost: Label = %Cost
@onready var _message: Label = %Message
@onready var _hint: Label = %Hint

var smith: QuizRpgNpcUpgrade
var npc: Node
var _age := 0.0
var _rows: Array[Button] = []
var _offers: Array[Dictionary] = []


## Otwiera okno ulepszania pod węzłem NPC. Zwraca okno — `await panel.closed`.
static func open(host: Node, smith_service: QuizRpgNpcUpgrade) -> CanvasLayer:
	var panel: CanvasLayer = (load(QuizRpgPaths.path(SCENE)) as PackedScene).instantiate()
	panel.set("smith", smith_service)
	panel.set("npc", host)
	host.add_child(panel)
	return panel


func _ready() -> void:
	UiLayerScale.attach(self)
	_title.text = QuizRpgI18n.t("upgrade.title", "Ulepszanie broni")
	_hint.text = QuizRpgI18n.t("upgrade.hint", "Enter: ulepsz    Esc: wyjdź")
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
	_offers.assign(smith.offers(npc) if smith else [])
	for o in _offers:
		var it: QuizRpgItemData = o.item
		var who := ""
		if int(o.member) >= 0:
			who = " (%s)" % str((ps.party[int(o.member)] as Dictionary).get("name", ""))
		var st: int = o.status
		var right := QuizRpgI18n.t("upgrade.locked", "jeszcze nie") if st == Status.LOCKED else cost_text(npc, it)
		_add_row(it.localized_name() + who, right, st == Status.OK)
	(_list.get_node("Empty") as Label).visible = _rows.is_empty()
	(_list.get_node("Empty") as Label).text = QuizRpgI18n.t("upgrade.empty", "Nie masz broni, którą umiem ulepszyć.")
	if _rows.is_empty():
		_show_info(-1)
		return
	_rows[clampi(focus_index, 0, _rows.size() - 1)].call_deferred("grab_focus")


## Koszt ulepszenia: „500 D”, „500 D + Rudy ×2”, „za darmo”.
static func cost_text(node: Node, it: QuizRpgItemData) -> String:
	var parts: Array[String] = []
	if it.upgrade_gold > 0:
		parts.append(QuizRpgI18n.tf("shop.price", {"price": it.upgrade_gold}, "{price} D"))
	if it.upgrade_item_id != "":
		parts.append("%s ×%d" % [QuizRpgNpcContext.item_name(node, it.upgrade_item_id), it.upgrade_item_count])
	return " + ".join(parts) if not parts.is_empty() else QuizRpgI18n.t("teacher.free", "za darmo")


## Zmiana statystyk etapu: „ATK 50 → 163”.
static func stats_text(it: QuizRpgItemData, nxt: QuizRpgItemData) -> String:
	var parts: Array[String] = []
	for s in STATS:
		var a := int(it.get(s + "_bonus"))
		var b := int(nxt.get(s + "_bonus"))
		if a != 0 or b != 0:
			parts.append("%s %d → %d" % [s.to_upper(), a, b])
	return ", ".join(parts)


func _add_row(text: String, right: String, available: bool) -> void:
	var b := ROW_SCENE.instantiate() as Button
	b.text = text
	if not available:
		b.modulate = DIM
	(b.get_node("Right") as Label).text = right
	var idx := _rows.size()
	b.pressed.connect(_activate.bind(idx))
	b.focus_entered.connect(_show_info.bind(idx))
	b.focus_entered.connect(QuizTheme.set_menu_item_selected.bind(b, true))
	b.focus_exited.connect(QuizTheme.set_menu_item_selected.bind(b, false))
	_list.add_child(b)
	_rows.append(b)


func _show_info(idx: int) -> void:
	if idx < 0 or idx >= _offers.size():
		_item_name.text = ""
		_stats.text = ""
		_desc.text = ""
		_cost.text = ""
		return
	var o: Dictionary = _offers[idx]
	var it: QuizRpgItemData = o.item
	var nxt: QuizRpgItemData = o.next
	_item_name.text = "%s → %s" % [it.localized_name(), nxt.localized_name()]
	_stats.text = stats_text(it, nxt)
	_desc.text = nxt.localized_description()
	_cost.text = QuizRpgI18n.tf("teacher.cost", {"cost": cost_text(npc, it)}, "Koszt: {cost}") + "\n" + status_text(npc, int(o.status), it)


## Powód, dla którego ulepszenie jest niedostępne (pusty, gdy można ulepszyć).
static func status_text(node: Node, st: int, it: QuizRpgItemData) -> String:
	match st:
		Status.LOCKED:
			return QuizRpgI18n.t("upgrade.status_locked", "Nie pamiętam jeszcze, jak to przekuć… Wróć, gdy coś się zmieni.")
		Status.GOLD:
			return QuizRpgI18n.t("shop.no_gold", "Za mało dukatów.")
		Status.ITEM:
			return QuizRpgI18n.tf("teacher.status_item", {"item": QuizRpgNpcContext.item_name(node, it.upgrade_item_id)}, "Brakuje: {item}.")
	return ""


func _activate(idx: int) -> void:
	if _age < INPUT_GRACE or idx >= _offers.size():
		return
	var o: Dictionary = _offers[idx]
	var it: QuizRpgItemData = o.item
	var nxt: QuizRpgItemData = o.next
	if smith.upgrade(npc, o):
		_message.text = QuizRpgI18n.tf("upgrade.done", {"old": it.localized_name(), "new": nxt.localized_name()}, "{old} -> {new}!")
		QuizRpgNpcContext.play_sfx(npc, "level_up")
	else:
		_message.text = status_text(npc, int(o.status), it)
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
