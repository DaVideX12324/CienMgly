extends CanvasLayer

## Okno sklepu NPC (scena scenes/ui/shop_panel.tscn, WYSIWYG — skrypt tylko wypełnia listę): zakładki Kup /
## Sprzedaj (←/→ albo klik), lista przedmiotów z ceną (↑/↓, Enter / klik = jedna sztuka), opis zaznaczonego po
## prawej, złoto w nagłówku. Esc zamyka -> sygnał closed. Logika zakupu w QuizRpgNpcShop (buy / sell).

signal closed

const SCENE := "scenes/ui/shop_panel.tscn"
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")
const QuizTheme = preload("quiz_theme.gd")
const INPUT_GRACE := 0.15
## Wiersz listy (przycisk z ceną / kosztem po prawej) — scena WYSIWYG, wspólna dla usług NPC.
const ROW_SCENE: PackedScene = preload("../../scenes/ui/service_row.tscn")
const DIM := Color(1, 1, 1, 0.45)

@onready var _title: Label = %Title
@onready var _gold: Label = %Gold
@onready var _buy_tab: Button = %BuyTab
@onready var _sell_tab: Button = %SellTab
@onready var _list: VBoxContainer = %List
@onready var _icon: TextureRect = %Icon
@onready var _item_name: Label = %ItemName
@onready var _stats: Label = %Stats
@onready var _desc: Label = %Desc
@onready var _owned: Label = %Owned
@onready var _message: Label = %Message
@onready var _hint: Label = %Hint

var shop: QuizRpgNpcShop
var npc: Node
var selling := false
var _age := 0.0
var _rows: Array[Button] = []
var _row_items: Array = []   # QuizRpgShopEntry (kupno) albo item_id (sprzedaż), wyrównane z _rows


## Otwiera sklep pod węzłem NPC. Zwraca okno — `await panel.closed`.
static func open(host: Node, shop_service: QuizRpgNpcShop) -> CanvasLayer:
	var panel: CanvasLayer = (load(QuizRpgPaths.path(SCENE)) as PackedScene).instantiate()
	panel.set("shop", shop_service)
	panel.set("npc", host)
	host.add_child(panel)
	return panel


func _ready() -> void:
	UiLayerScale.attach(self)
	_title.text = npc.call("display_name") if npc and npc.has_method("display_name") else QuizRpgI18n.t("shop.title", "Sklep")
	_buy_tab.text = QuizRpgI18n.t("shop.buy", "Kup")
	_sell_tab.text = QuizRpgI18n.t("shop.sell", "Sprzedaj")
	_sell_tab.visible = shop != null and shop.can_sell
	_buy_tab.pressed.connect(_set_mode.bind(false))
	_sell_tab.pressed.connect(_set_mode.bind(true))
	_message.text = " "
	_set_mode(false)


func _process(delta: float) -> void:
	_age += delta


func _set_mode(sell: bool) -> void:
	selling = sell and shop != null and shop.can_sell
	_buy_tab.button_pressed = not selling
	_sell_tab.button_pressed = selling
	QuizTheme.set_menu_item_selected(_buy_tab, not selling)
	QuizTheme.set_menu_item_selected(_sell_tab, selling)
	_hint.text = QuizRpgI18n.t("shop.hint_sell" if selling else "shop.hint_buy",
			"Enter: sprzedaj    ←/→: Kup / Sprzedaj    Esc: wyjdź" if selling else "Enter: kup    ←/→: Kup / Sprzedaj    Esc: wyjdź")
	_refresh(0)


## Lista od nowa (po zakupie / sprzedaży), fokus na wierszu `focus_index` (przycięty do listy).
func _refresh(focus_index: int) -> void:
	var ps := QuizRpgNpcContext.player_stats(npc)
	_gold.text = QuizRpgI18n.tf("shop.gold", {"gold": int(ps.gold) if ps else 0}, "Dukaty: {gold}")
	for c in _list.get_children():
		if c is Button:
			_list.remove_child(c)
			c.queue_free()
	_rows.clear()
	_row_items.clear()
	if selling:
		for e in ps.get_inventory_entries() if ps else []:
			var item_id := str(e.get("item_id", ""))
			var it := QuizRpgNpcContext.item(npc, item_id)
			var count := int(e.get("count", 0))
			if it == null or it.sell_price() <= 0 or count <= 0:
				continue
			_add_row("%s ×%d" % [it.localized_name(), count], _price_text(it.sell_price()), it.icon, true, item_id)
	elif shop:
		for entry in shop.available_stock(npc):
			var p := entry.final_price()
			_add_row(entry.item.localized_name(), _price_text(p), entry.item.icon, ps != null and int(ps.gold) >= p, entry)
	(_list.get_node("Empty") as Label).visible = _rows.is_empty()
	(_list.get_node("Empty") as Label).text = QuizRpgI18n.t("shop.empty_sell" if selling else "shop.empty_buy",
			"Nie masz nic na sprzedaż." if selling else "Nic tu nie ma.")
	if _rows.is_empty():
		_show_info(null)
		return
	_rows[clampi(focus_index, 0, _rows.size() - 1)].call_deferred("grab_focus")


func _add_row(text: String, right: String, icon: Texture2D, affordable: bool, payload: Variant) -> void:
	var b := ROW_SCENE.instantiate() as Button
	b.text = text
	b.icon = icon
	if not affordable:
		b.modulate = DIM
	(b.get_node("Right") as Label).text = right
	var idx := _rows.size()
	b.pressed.connect(_activate.bind(idx))
	b.focus_entered.connect(_on_row_focus.bind(idx))
	b.focus_entered.connect(QuizTheme.set_menu_item_selected.bind(b, true))
	b.focus_exited.connect(QuizTheme.set_menu_item_selected.bind(b, false))
	_list.add_child(b)
	_rows.append(b)
	_row_items.append(payload)


static func _price_text(p: int) -> String:
	return QuizRpgI18n.tf("shop.price", {"price": p}, "{price} D")


func _on_row_focus(idx: int) -> void:
	var p: Variant = _row_items[idx] if idx < _row_items.size() else null
	_show_info(p.item if p is QuizRpgShopEntry else QuizRpgNpcContext.item(npc, str(p)) if p != null else null)


func _show_info(it: QuizRpgItemData) -> void:
	_icon.texture = it.icon if it else null
	_item_name.text = it.localized_name() if it else ""
	_desc.text = it.localized_description() if it else ""
	_stats.text = item_stats_text(it)
	var ps := QuizRpgNpcContext.player_stats(npc)
	_owned.text = QuizRpgI18n.tf("shop.owned", {"count": ps.get_item_count(it.item_id)}, "Masz: {count}") if it and ps else ""


## Efekt / bonusy przedmiotu w jednej linii (ATK +20, DEF +8, +100 HP…).
static func item_stats_text(it: QuizRpgItemData) -> String:
	if it == null:
		return ""
	var parts: Array[String] = []
	for pair in [["atk_bonus", "ATK"], ["def_bonus", "DEF"], ["mat_bonus", "MAT"], ["mdf_bonus", "MDF"], ["agi_bonus", "AGI"]]:
		var v := int(it.get(pair[0]))
		if v != 0:
			parts.append("%s %+d" % [pair[1], v])
	var eff := it.get_effect_summary()
	if eff != "":
		parts.append(eff)
	return ", ".join(parts)


func _activate(idx: int) -> void:
	if _age < INPUT_GRACE or idx >= _row_items.size():
		return
	var p: Variant = _row_items[idx]
	var ok := false
	if p is QuizRpgShopEntry:
		var entry := p as QuizRpgShopEntry
		ok = shop.buy(npc, entry)
		_message.text = QuizRpgI18n.tf("shop.bought", {"item": entry.item.localized_name()}, "Kupiono: {item}.") if ok \
				else QuizRpgI18n.t("shop.no_gold", "Za mało dukatów.")
	else:
		var item_name := QuizRpgNpcContext.item_name(npc, str(p))
		ok = shop.sell(npc, str(p))
		_message.text = QuizRpgI18n.tf("shop.sold", {"item": item_name}, "Sprzedano: {item}.") if ok else " "
	if ok:
		QuizRpgNpcContext.play_sfx(npc, "coin")
	_refresh(idx)


## ←/→ przed nawigacją fokusu (lista pionowa) — przełączenie zakładki.
func _input(event: InputEvent) -> void:
	if _age < INPUT_GRACE or not (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		return
	get_viewport().set_input_as_handled()
	if shop and shop.can_sell:
		_set_mode(event.is_action_pressed("ui_right"))


func _unhandled_input(event: InputEvent) -> void:
	if _age < INPUT_GRACE:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event.is_action_pressed("interact"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and _rows.has(f):
			get_viewport().set_input_as_handled()
			_activate(_rows.find(f))


func _close() -> void:
	closed.emit()
	queue_free()
