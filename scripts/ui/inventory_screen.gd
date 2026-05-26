extends Control

@onready var item_list: ItemList = $Panel/MarginContainer/VBoxContainer/ContentRow/ItemList
@onready var item_name_label: Label = $Panel/MarginContainer/VBoxContainer/ContentRow/DetailsPanel/DetailsMargin/DetailsVBox/ItemNameLabel
@onready var count_label: Label = $Panel/MarginContainer/VBoxContainer/ContentRow/DetailsPanel/DetailsMargin/DetailsVBox/CountLabel
@onready var effect_label: Label = $Panel/MarginContainer/VBoxContainer/ContentRow/DetailsPanel/DetailsMargin/DetailsVBox/EffectLabel
@onready var description_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ContentRow/DetailsPanel/DetailsMargin/DetailsVBox/DescriptionLabel
@onready var result_label: Label = $Panel/MarginContainer/VBoxContainer/ResultLabel
@onready var use_btn: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/UseBtn
@onready var close_btn: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/CloseBtn

var _ps: Node = null
var _entries: Array[Dictionary] = []
var _selected_idx: int = -1


func _ready() -> void:
	_ps = CoreManager.get_singleton("PlayerStats")
	if _ps == null:
		push_error("InventoryScreen: PlayerStats niedostepny przez CoreManager")
	use_btn.pressed.connect(_on_use)
	close_btn.pressed.connect(_on_close)
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)
	if _ps and _ps.has_signal("inventory_changed"):
		_ps.inventory_changed.connect(_on_inventory_changed)
	_refresh_inventory()


func _refresh_inventory(reset_message: bool = true) -> void:
	item_list.clear()
	_entries.clear()
	_selected_idx = -1
	if reset_message:
		result_label.text = ""
	if _ps and _ps.has_method("get_inventory_entries"):
		_entries = _ps.get_inventory_entries()
	for entry: Dictionary in _entries:
		var item_name: String = str(entry.get("name", "---"))
		var display_count: String = str(entry.get("display_count", int(entry.get("count", 0))))
		var count_text: String = "X" if display_count == "X" else "x%s" % display_count
		item_list.add_item("%s  %s" % [item_name, count_text])
	if not _entries.is_empty():
		_select_index(0)
	else:
		_show_empty_state()


func _show_empty_state() -> void:
	item_name_label.text = "Ekwipunek pusty"
	count_label.text = ""
	effect_label.text = ""
	description_label.text = "Brak przedmiotow."
	use_btn.disabled = true


func _select_index(index: int) -> void:
	if index < 0 or index >= _entries.size():
		_show_empty_state()
		return
	_selected_idx = index
	item_list.select(index)
	var entry: Dictionary = _entries[index]
	item_name_label.text = str(entry.get("name", "---"))
	count_label.text = "Ilosc: %s" % str(entry.get("display_count", int(entry.get("count", 0))))
	effect_label.text = str(entry.get("effect_summary", ""))
	description_label.text = str(entry.get("description", ""))
	var can_use: bool = int(entry.get("count", 0)) > 0 and bool(entry.get("usable_in_menu", true))
	use_btn.disabled = not can_use


func _on_item_selected(index: int) -> void:
	_select_index(index)


func _on_item_activated(index: int) -> void:
	_select_index(index)
	if not use_btn.disabled:
		_on_use()


func _on_use() -> void:
	if _ps == null or _selected_idx < 0 or _selected_idx >= _entries.size():
		return
	if not _ps.has_method("use_item"):
		return
	var entry: Dictionary = _entries[_selected_idx]
	var item_id: String = str(entry.get("item_id", ""))
	if item_id == "":
		return
	var result: Dictionary = _ps.use_item(item_id)
	if bool(result.get("success", false)):
		_on_inventory_changed()
		result_label.text = str(result.get("message", "Uzyto przedmiotu."))
	else:
		result_label.text = str(result.get("message", "Nie mozna uzyc przedmiotu."))
		_refresh_inventory(false)


func _on_inventory_changed() -> void:
	var previous_item_id: String = ""
	if _selected_idx >= 0 and _selected_idx < _entries.size():
		previous_item_id = str(_entries[_selected_idx].get("item_id", ""))
	_refresh_inventory(false)
	if previous_item_id == "":
		return
	for index: int in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		if str(entry.get("item_id", "")) == previous_item_id:
			_select_index(index)
			return


func _on_close() -> void:
	queue_free()
