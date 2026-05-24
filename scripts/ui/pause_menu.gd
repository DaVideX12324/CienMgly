extends CanvasLayer

const LEFT_MENU_ITEMS: Array[String] = ["Przedmioty", "Umiejetnosci", "Ekwipunek", "Status", "Zapisz", "Zakoncz gre"]
const ITEM_TABS: Array[Dictionary] = [
	{"label": "Przedmioty", "category": "item"},
	{"label": "Bron", "category": "hand"},
	{"label": "Czesci", "category": "part"},
	{"label": "Kluczowe", "category": "key"},
]
const EQUIP_ACTIONS: Array[String] = ["Zmien", "Optymalizuj", "Wyczysc"]

@onready var pause_root: Control = $PauseRoot
@onready var left_panel: PanelContainer = $PauseRoot/MainRow/LeftPanel
@onready var right_panel: PanelContainer = $PauseRoot/MainRow/RightPanel
@onready var menu_list_vbox: VBoxContainer = $PauseRoot/MainRow/LeftPanel/Margin/LeftVBox/MenuListVBox
@onready var toast_label: Label = $PauseRoot/MainRow/LeftPanel/Margin/LeftVBox/ToastLabel
@onready var context_title_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextTitleLabel
@onready var party_panel: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/PartyPanel
@onready var party_hint_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/PartyPanel/PartyHintLabel
@onready var party_list_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/PartyPanel/PartyListVBox
@onready var items_panel: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/ItemsPanel
@onready var items_tabs_row: HBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/ItemsPanel/TabsRow
@onready var items_list_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/ItemsPanel/ListVBox
@onready var items_footer_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/ItemsPanel/FooterLabel
@onready var skills_panel: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/SkillsPanel
@onready var skills_actor_header: HBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/SkillsPanel/ActorHeader
@onready var skills_list_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/SkillsPanel/ListVBox
@onready var skills_footer_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/SkillsPanel/FooterLabel
@onready var equipment_panel: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/EquipmentPanel
@onready var equipment_actor_header: HBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/EquipmentPanel/ActorHeader
@onready var equipment_stats_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/EquipmentPanel/EquipStatsLabel
@onready var equip_actions_row: HBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/EquipmentPanel/EquipActionRow
@onready var equip_slots_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/EquipmentPanel/EquipSlotsVBox
@onready var equip_items_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/EquipmentPanel/EquipItemsVBox
@onready var equipment_footer_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/EquipmentPanel/FooterLabel
@onready var status_panel: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/StatusPanel
@onready var status_actor_header: HBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/StatusPanel/ActorHeader
@onready var status_info_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/StatusPanel/StatusInfoLabel
@onready var status_bars_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/StatusPanel/StatusBarsVBox
@onready var status_stats_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/StatusPanel/StatusStatsVBox
@onready var status_equip_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/StatusPanel/StatusEquipVBox
@onready var confirm_panel: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/ConfirmPanel
@onready var confirm_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/ConfirmPanel/ConfirmLabel
@onready var confirm_options_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/ConfirmPanel/OptionsVBox

var _gm: Node = null
var _ps: Node = null
var _paused: bool = false
var _mode: String = "left_menu"
var _left_menu_index: int = 0
var _party_index: int = 0
var _tab_index: int = 0
var _items_index: int = 0
var _skills_index: int = 0
var _equip_action_index: int = 0
var _equip_slot_index: int = 0
var _equip_item_index: int = 0
var _confirm_index: int = 0
var _selected_member_index: int = 0
var _selected_slot_name: String = ""
var _pending_item_id: String = ""
var _menu_rows: Array[Control] = []
var _party_rows: Array[Control] = []
var _item_rows: Array[Control] = []
var _skill_rows: Array[Control] = []
var _equip_action_rows: Array[Control] = []
var _equip_slot_rows: Array[Control] = []
var _equip_item_rows: Array[Control] = []
var _confirm_rows: Array[Control] = []
var _current_item_entries: Array[Dictionary] = []
var _current_skill_entries: Array[Dictionary] = []
var _current_equip_entries: Array[Dictionary] = []
var _toast_reset_text: String = ""


func _ready() -> void:
	_gm = CoreManager.get_singleton("GameManager")
	_ps = CoreManager.get_singleton("PlayerStats")
	pause_root.visible = false
	_build_left_menu()
	_rebuild_party_rows(false)
	_show_default_party_panel()
	if _ps:
		if _ps.has_signal("inventory_changed"):
			_ps.inventory_changed.connect(_on_player_data_changed)
		if _ps.has_signal("party_changed"):
			_ps.party_changed.connect(_on_player_data_changed)
		if _ps.has_signal("hp_changed"):
			_ps.hp_changed.connect(_on_player_hp_changed)
	_apply_scaling()


func _input(event: InputEvent) -> void:
	if not _paused:
		if event.is_action_pressed("ui_cancel") and _gm and _gm.is_exploring():
			_toggle_pause()
			get_viewport().set_input_as_handled()
		return
	if _handle_close_input(event):
		get_viewport().set_input_as_handled()
		return
	if _mode == "confirm_exit":
		if _handle_confirm_input(event):
			get_viewport().set_input_as_handled()
		return
	if _mode == "items_list" and _handle_item_tab_input(event):
		get_viewport().set_input_as_handled()
		return
	if _is_nav_up(event):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if _is_nav_down(event):
		_move_selection(1)
		get_viewport().set_input_as_handled()
		return
	if _mode == "equip_actions":
		if _is_nav_left(event):
			_move_equip_action(-1)
			get_viewport().set_input_as_handled()
			return
		if _is_nav_right(event):
			_move_equip_action(1)
			get_viewport().set_input_as_handled()
			return
	if _is_accept(event):
		_accept_current()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	_paused = not _paused
	pause_root.visible = _paused
	get_tree().paused = _paused
	if _gm:
		if _paused:
			_gm.change_state(_gm.GameState.PAUSED)
		else:
			_gm.change_state(_gm.GameState.EXPLORING)
	if _paused:
		_mode = "left_menu"
		_left_menu_index = 0
		_show_default_party_panel()
		_refresh_left_menu()


func _handle_close_input(event: InputEvent) -> bool:
	if not _is_cancel(event):
		return false
	match _mode:
		"left_menu":
			_toggle_pause()
		"items_list":
			_mode = "left_menu"
			_show_default_party_panel()
		"item_target_select":
			_mode = "items_list"
			_show_items_panel()
		"skills_party_select", "equip_party_select", "status_party_select":
			_mode = "left_menu"
			_show_default_party_panel()
		"skills_list":
			_mode = "skills_party_select"
			_show_party_select_panel("Wybierz postac dla umiejetnosci")
		"equip_actions", "equip_slots", "equip_item_list":
			if _mode == "equip_item_list":
				_mode = "equip_slots"
				_show_equipment_panel()
			elif _mode == "equip_slots":
				_mode = "equip_actions"
				_show_equipment_panel()
			else:
				_mode = "equip_party_select"
				_show_party_select_panel("Wybierz postac do ekwipunku")
		"status_view":
			_mode = "status_party_select"
			_show_party_select_panel("Wybierz postac do statusu")
		_:
			_mode = "left_menu"
			_show_default_party_panel()
	return true


func _handle_confirm_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_T:
				_confirm_index = 0
				_refresh_confirm_rows()
				_confirm_exit_choice()
				return true
			if key_event.keycode == KEY_N:
				_confirm_index = 1
				_refresh_confirm_rows()
				_confirm_exit_choice()
				return true
	if _is_nav_up(event) or _is_nav_left(event):
		_confirm_index = 0
		_refresh_confirm_rows()
		return true
	if _is_nav_down(event) or _is_nav_right(event):
		_confirm_index = 1
		_refresh_confirm_rows()
		return true
	if _is_accept(event):
		_confirm_exit_choice()
		return true
	return false


func _handle_item_tab_input(event: InputEvent) -> bool:
	if _is_prev_tab(event):
		_tab_index = (_tab_index - 1 + ITEM_TABS.size()) % ITEM_TABS.size()
		_items_index = 0
		_show_items_panel()
		return true
	if _is_next_tab(event):
		_tab_index = (_tab_index + 1) % ITEM_TABS.size()
		_items_index = 0
		_show_items_panel()
		return true
	return false


func _move_selection(delta: int) -> void:
	match _mode:
		"left_menu":
			_left_menu_index = wrapi(_left_menu_index + delta, 0, LEFT_MENU_ITEMS.size())
			_refresh_left_menu()
		"items_list":
			if _item_rows.is_empty():
				return
			_items_index = wrapi(_items_index + delta, 0, _item_rows.size())
			_refresh_item_rows()
		"item_target_select", "skills_party_select", "equip_party_select", "status_party_select":
			if _party_rows.is_empty():
				return
			_party_index = wrapi(_party_index + delta, 0, _party_rows.size())
			_refresh_party_rows()
		"skills_list":
			if _skill_rows.is_empty():
				return
			_skills_index = _find_next_enabled_skill_index(_skills_index, delta)
			_refresh_skill_rows()
		"equip_slots":
			if _equip_slot_rows.is_empty():
				return
			_equip_slot_index = wrapi(_equip_slot_index + delta, 0, _equip_slot_rows.size())
			_refresh_equipment_slot_rows()
		"equip_item_list":
			if _equip_item_rows.is_empty():
				return
			_equip_item_index = wrapi(_equip_item_index + delta, 0, _equip_item_rows.size())
			_refresh_equipment_item_rows()


func _move_equip_action(delta: int) -> void:
	_equip_action_index = wrapi(_equip_action_index + delta, 0, EQUIP_ACTIONS.size())
	_refresh_equip_action_rows()


func _accept_current() -> void:
	match _mode:
		"left_menu":
			_accept_left_menu()
		"items_list":
			_accept_items_list()
		"item_target_select":
			_use_pending_item_on_member()
		"skills_party_select":
			_selected_member_index = _party_index
			_mode = "skills_list"
			_skills_index = 0
			_show_skills_panel()
		"skills_list":
			_use_selected_skill()
		"equip_party_select":
			_selected_member_index = _party_index
			_mode = "equip_actions"
			_equip_action_index = 0
			_show_equipment_panel()
		"equip_actions":
			_accept_equip_action()
		"equip_slots":
			_selected_slot_name = _ps.get_equipment_slots()[_equip_slot_index]
			_mode = "equip_item_list"
			_equip_item_index = 0
			_show_equipment_panel()
		"equip_item_list":
			_accept_equip_item()
		"status_party_select":
			_selected_member_index = _party_index
			_mode = "status_view"
			_show_status_panel()
		"confirm_exit":
			_confirm_exit_choice()


func _accept_left_menu() -> void:
	match _left_menu_index:
		0:
			_mode = "items_list"
			_items_index = 0
			_show_items_panel()
		1:
			_mode = "skills_party_select"
			_party_index = 0
			_show_party_select_panel("Wybierz postac dla umiejetnosci")
		2:
			_mode = "equip_party_select"
			_party_index = 0
			_show_party_select_panel("Wybierz postac do ekwipunku")
		3:
			_mode = "status_party_select"
			_party_index = 0
			_show_party_select_panel("Wybierz postac do statusu")
		4:
			_save_game()
		5:
			_mode = "confirm_exit"
			_confirm_index = 1
			_show_confirm_panel()


func _accept_items_list() -> void:
	if _items_index < 0 or _items_index >= _current_item_entries.size():
		return
	var entry: Dictionary = _current_item_entries[_items_index]
	if not bool(entry.get("usable_in_menu", true)) or int(entry.get("count", 0)) <= 0:
		_show_toast("Nie mozna uzyc tego przedmiotu.")
		return
	_pending_item_id = str(entry.get("item_id", ""))
	_mode = "item_target_select"
	_party_index = 0
	_show_party_select_panel("Wybierz postac dla przedmiotu")


func _use_pending_item_on_member() -> void:
	if _ps == null or not _ps.has_method("use_item_on_member"):
		return
	var result: Dictionary = _ps.use_item_on_member(_pending_item_id, _party_index)
	_pending_item_id = ""
	_mode = "items_list"
	_show_items_panel()
	_show_toast(str(result.get("message", "Uzyto przedmiotu.")))


func _use_selected_skill() -> void:
	if _skills_index < 0 or _skills_index >= _current_skill_entries.size():
		return
	var entry: Dictionary = _current_skill_entries[_skills_index]
	if bool(entry.get("disabled", false)):
		return
	_show_toast("Umiejetnosc %s jest na razie tylko pokazowa." % str(entry.get("name", "umiejetnosc")))


func _accept_equip_action() -> void:
	match _equip_action_index:
		0:
			_mode = "equip_slots"
			_equip_slot_index = 0
			_show_equipment_panel()
		1:
			if _ps and _ps.has_method("optimize_member_equipment"):
				_ps.optimize_member_equipment(_selected_member_index)
			_show_equipment_panel()
			_show_toast("Zoptymalizowano ekwipunek.")
		2:
			if _ps and _ps.has_method("clear_member_equipment"):
				_ps.clear_member_equipment(_selected_member_index)
			_show_equipment_panel()
			_show_toast("Przywrocono domyslny ekwipunek.")


func _accept_equip_item() -> void:
	if _equip_item_index < 0 or _equip_item_index >= _current_equip_entries.size():
		return
	if _ps == null or not _ps.has_method("set_member_equipment"):
		return
	var entry: Dictionary = _current_equip_entries[_equip_item_index]
	var item_id: String = str(entry.get("item_id", ""))
	var success: bool = _ps.set_member_equipment(_selected_member_index, _selected_slot_name, item_id)
	if success:
		_mode = "equip_slots"
		_show_equipment_panel()
		_show_toast("Zmieniono wyposazenie.")


func _confirm_exit_choice() -> void:
	if _confirm_index == 0:
		get_tree().paused = false
		_paused = false
		pause_root.visible = false
		if _gm and _gm.has_method("return_to_main_menu"):
			_gm.return_to_main_menu()
	else:
		_mode = "left_menu"
		_show_default_party_panel()
		_refresh_left_menu()


func _show_default_party_panel() -> void:
	_show_panel("party")
	context_title_label.text = "Druzyna"
	party_hint_label.text = ""
	_rebuild_party_rows(false)


func _show_party_select_panel(title_text: String) -> void:
	_show_panel("party")
	context_title_label.text = title_text
	party_hint_label.text = "Enter/Z: potwierdz    X/Esc: wroc"
	_rebuild_party_rows(true)


func _show_items_panel() -> void:
	_show_panel("items")
	context_title_label.text = "Przedmioty"
	_rebuild_item_tabs()
	_rebuild_item_rows()


func _show_skills_panel() -> void:
	_show_panel("skills")
	context_title_label.text = "Umiejetnosci"
	_build_actor_header(skills_actor_header, _ps.get_party_member(_selected_member_index), true)
	_rebuild_skill_rows()


func _show_equipment_panel() -> void:
	_show_panel("equipment")
	context_title_label.text = "Ekwipunek"
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	_build_actor_header(equipment_actor_header, member, false)
	equipment_stats_label.text = "ATK %d   DEF %d" % [_ps.get_member_total_atk(_selected_member_index), _ps.get_member_total_def(_selected_member_index)]
	_rebuild_equip_action_rows()
	_rebuild_equipment_slots()
	if _mode == "equip_item_list":
		_rebuild_equipment_item_rows()
	else:
		for child: Node in equip_items_vbox.get_children():
			child.queue_free()
		equipment_footer_label.text = "Enter/Z: wybierz    X/Esc: wroc"


func _show_status_panel() -> void:
	_show_panel("status")
	context_title_label.text = "Status"
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	_build_actor_header(status_actor_header, member, false)
	_rebuild_status_panel(member)


func _show_confirm_panel() -> void:
	_show_panel("confirm")
	context_title_label.text = "Potwierdzenie"
	confirm_label.text = "Zakonczyc gre?"
	_rebuild_confirm_rows()


func _show_panel(panel_name: String) -> void:
	party_panel.visible = panel_name == "party"
	items_panel.visible = panel_name == "items"
	skills_panel.visible = panel_name == "skills"
	equipment_panel.visible = panel_name == "equipment"
	status_panel.visible = panel_name == "status"
	confirm_panel.visible = panel_name == "confirm"


func _build_left_menu() -> void:
	for child: Node in menu_list_vbox.get_children():
		child.queue_free()
	_menu_rows.clear()
	for item_text: String in LEFT_MENU_ITEMS:
		var row: PanelContainer = _create_simple_row(item_text, "")
		menu_list_vbox.add_child(row)
		_menu_rows.append(row)
	_refresh_left_menu()


func _refresh_left_menu() -> void:
	_set_row_selection(_menu_rows, _left_menu_index)


func _rebuild_party_rows(selectable: bool) -> void:
	for child: Node in party_list_vbox.get_children():
		child.queue_free()
	_party_rows.clear()
	var members: Array[Dictionary] = _ps.get_party_members() if _ps and _ps.has_method("get_party_members") else []
	for member: Dictionary in members:
		var row: PanelContainer = _create_party_row(member)
		party_list_vbox.add_child(row)
		_party_rows.append(row)
	_refresh_party_rows()
	if not selectable and not _party_rows.is_empty():
		_set_row_selection(_party_rows, 0)


func _refresh_party_rows() -> void:
	_set_row_selection(_party_rows, _party_index)


func _rebuild_item_tabs() -> void:
	for child: Node in items_tabs_row.get_children():
		child.queue_free()
	var tab_rows: Array[Control] = []
	for tab_data: Dictionary in ITEM_TABS:
		var row: PanelContainer = _create_simple_row(str(tab_data.get("label", "")), "")
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_tabs_row.add_child(row)
		tab_rows.append(row)
	_set_row_selection(tab_rows, _tab_index)


func _rebuild_item_rows() -> void:
	for child: Node in items_list_vbox.get_children():
		child.queue_free()
	_item_rows.clear()
	_current_item_entries.clear()
	var category: String = str(ITEM_TABS[_tab_index].get("category", "item"))
	var entries: Array[Dictionary] = _ps.get_items_by_category(category) if _ps and _ps.has_method("get_items_by_category") else []
	for entry: Dictionary in entries:
		var row: PanelContainer = _create_simple_row(str(entry.get("name", "---")), ":%d" % int(entry.get("count", 0)))
		items_list_vbox.add_child(row)
		_item_rows.append(row)
		_current_item_entries.append(entry)
	if _item_rows.is_empty():
		items_footer_label.text = "Brak przedmiotow w tej zakladce."
	else:
		_items_index = clampi(_items_index, 0, _item_rows.size() - 1)
		_set_row_selection(_item_rows, _items_index)
		var selected: Dictionary = _current_item_entries[_items_index]
		items_footer_label.text = str(selected.get("description", ""))


func _refresh_item_rows() -> void:
	_set_row_selection(_item_rows, _items_index)
	if _items_index >= 0 and _items_index < _current_item_entries.size():
		items_footer_label.text = str(_current_item_entries[_items_index].get("description", ""))


func _rebuild_skill_rows() -> void:
	for child: Node in skills_list_vbox.get_children():
		child.queue_free()
	_skill_rows.clear()
	_current_skill_entries.clear()
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	var member_sp: int = int(member.get("sp", 0))
	var member_tp: int = int(member.get("tp", 0))
	var skills: Array = _ps.skills if _ps and _ps.get("skills") is Array else []
	for skill_value: Variant in skills:
		var skill: Dictionary = skill_value
		var cost_text: String = "-"
		var disabled: bool = false
		if int(skill.get("sp_cost", 0)) > 0:
			cost_text = "SP %d" % int(skill.get("sp_cost", 0))
			disabled = member_sp < int(skill.get("sp_cost", 0))
		elif int(skill.get("tp_cost", 0)) > 0:
			cost_text = "TP %d" % int(skill.get("tp_cost", 0))
			disabled = member_tp < int(skill.get("tp_cost", 0))
		var row: PanelContainer = _create_simple_row("[*] %s" % str(skill.get("name", "---")), cost_text, disabled)
		skills_list_vbox.add_child(row)
		_skill_rows.append(row)
		var skill_copy: Dictionary = skill.duplicate(true)
		skill_copy["disabled"] = disabled
		_current_skill_entries.append(skill_copy)
	if _skill_rows.is_empty():
		skills_footer_label.text = "Brak umiejetnosci."
		return
	_skills_index = _find_next_enabled_skill_index(clampi(_skills_index, 0, _skill_rows.size() - 1), 1, true)
	_refresh_skill_rows()


func _refresh_skill_rows() -> void:
	_set_row_selection(_skill_rows, _skills_index)
	if _skills_index >= 0 and _skills_index < _current_skill_entries.size():
		skills_footer_label.text = str(_current_skill_entries[_skills_index].get("description", ""))


func _find_next_enabled_skill_index(start_index: int, delta: int, allow_current: bool = false) -> int:
	if _current_skill_entries.is_empty():
		return -1
	var next_index: int = start_index
	if not allow_current:
		next_index = wrapi(start_index + delta, 0, _current_skill_entries.size())
	for _step: int in range(_current_skill_entries.size()):
		var entry: Dictionary = _current_skill_entries[next_index]
		if not bool(entry.get("disabled", false)):
			return next_index
		next_index = wrapi(next_index + delta, 0, _current_skill_entries.size())
	return start_index


func _rebuild_equip_action_rows() -> void:
	for child: Node in equip_actions_row.get_children():
		child.queue_free()
	_equip_action_rows.clear()
	for action_text: String in EQUIP_ACTIONS:
		var row: PanelContainer = _create_simple_row(action_text, "")
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip_actions_row.add_child(row)
		_equip_action_rows.append(row)
	_refresh_equip_action_rows()


func _refresh_equip_action_rows() -> void:
	_set_row_selection(_equip_action_rows, _equip_action_index)


func _rebuild_equipment_slots() -> void:
	for child: Node in equip_slots_vbox.get_children():
		child.queue_free()
	_equip_slot_rows.clear()
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	var equipment: Dictionary = member.get("equipment", {})
	for slot_name: String in _ps.get_equipment_slots():
		var equipped_name: String = _get_equipped_item_name(str(equipment.get(slot_name, "")))
		var row: PanelContainer = _create_simple_row(_ps.get_equipment_label(slot_name), equipped_name)
		equip_slots_vbox.add_child(row)
		_equip_slot_rows.append(row)
	_refresh_equipment_slot_rows()


func _refresh_equipment_slot_rows() -> void:
	_set_row_selection(_equip_slot_rows, _equip_slot_index)


func _rebuild_equipment_item_rows() -> void:
	for child: Node in equip_items_vbox.get_children():
		child.queue_free()
	_equip_item_rows.clear()
	_current_equip_entries.clear()
	_current_equip_entries = _ps.get_equippable_entries_for_slot(_selected_member_index, _selected_slot_name) if _ps and _ps.has_method("get_equippable_entries_for_slot") else []
	for entry: Dictionary in _current_equip_entries:
		var delta_text: String = _get_equipment_delta_text(entry)
		var row: PanelContainer = _create_simple_row(str(entry.get("name", "---")), delta_text)
		equip_items_vbox.add_child(row)
		_equip_item_rows.append(row)
	_refresh_equipment_item_rows()


func _refresh_equipment_item_rows() -> void:
	_set_row_selection(_equip_item_rows, _equip_item_index)
	if _equip_item_index >= 0 and _equip_item_index < _current_equip_entries.size():
		equipment_footer_label.text = str(_current_equip_entries[_equip_item_index].get("description", ""))


func _rebuild_status_panel(member: Dictionary) -> void:
	for child: Node in status_bars_vbox.get_children():
		child.queue_free()
	for child: Node in status_stats_vbox.get_children():
		child.queue_free()
	for child: Node in status_equip_vbox.get_children():
		child.queue_free()
	var exp_to_next: int = _ps.xp_to_next_level() if _ps and _selected_member_index == 0 else 0
	status_info_label.text = "LV %d   Exp %d   Do nastepnego poziomu %d" % [int(member.get("level", 1)), _ps.xp if _selected_member_index == 0 and _ps else 0, exp_to_next]
	status_bars_vbox.add_child(_create_bar_row("Zycie", int(member.get("hp", 0)), int(member.get("max_hp", 1))))
	status_bars_vbox.add_child(_create_bar_row("Mana", int(member.get("sp", 0)), int(member.get("max_sp", 1))))
	status_stats_vbox.add_child(_create_simple_row("ATK", str(_ps.get_member_total_atk(_selected_member_index)), false))
	status_stats_vbox.add_child(_create_simple_row("DEF", str(_ps.get_member_total_def(_selected_member_index)), false))
	var equipment: Dictionary = member.get("equipment", {})
	for slot_name: String in _ps.get_equipment_slots():
		status_equip_vbox.add_child(_create_simple_row(_ps.get_equipment_label(slot_name), _get_equipped_item_name(str(equipment.get(slot_name, ""))), false))


func _rebuild_confirm_rows() -> void:
	for child: Node in confirm_options_vbox.get_children():
		child.queue_free()
	_confirm_rows.clear()
	for option_text: String in ["T Tak", "N Nie"]:
		var row: PanelContainer = _create_simple_row(option_text, "")
		confirm_options_vbox.add_child(row)
		_confirm_rows.append(row)
	_refresh_confirm_rows()


func _refresh_confirm_rows() -> void:
	_set_row_selection(_confirm_rows, _confirm_index)


func _build_actor_header(target: HBoxContainer, member: Dictionary, show_bars: bool) -> void:
	for child: Node in target.get_children():
		child.queue_free()
	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(_ui_px(128), _ui_px(128))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = member.get("portrait") as Texture2D
	target.add_child(portrait)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", _ui_px(6))
	var name_label: Label = Label.new()
	name_label.text = "%s  LV %d" % [str(member.get("name", "Bohater")), int(member.get("level", 1))]
	name_label.add_theme_font_size_override("font_size", _ui_px(22))
	info_box.add_child(name_label)
	if show_bars:
		info_box.add_child(_create_bar_row("Zycie", int(member.get("hp", 0)), int(member.get("max_hp", 1))))
		info_box.add_child(_create_bar_row("Mana", int(member.get("sp", 0)), int(member.get("max_sp", 1))))
	else:
		var hp_label: Label = Label.new()
		hp_label.text = "Zycie %d/%d" % [int(member.get("hp", 0)), int(member.get("max_hp", 1))]
		info_box.add_child(hp_label)
		var sp_label: Label = Label.new()
		sp_label.text = "Mana %d/%d" % [int(member.get("sp", 0)), int(member.get("max_sp", 1))]
		info_box.add_child(sp_label)
	target.add_child(info_box)


func _create_party_row(member: Dictionary) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _ui_px(10))
	margin.add_theme_constant_override("margin_top", _ui_px(8))
	margin.add_theme_constant_override("margin_right", _ui_px(10))
	margin.add_theme_constant_override("margin_bottom", _ui_px(8))
	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", _ui_px(12))
	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(_ui_px(64), _ui_px(64))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = member.get("portrait") as Texture2D
	var name_label: Label = Label.new()
	name_label.text = str(member.get("name", "Bohater"))
	name_label.custom_minimum_size = Vector2(_ui_px(160), 0)
	var level_label: Label = Label.new()
	level_label.text = "LV %d" % int(member.get("level", 1))
	level_label.custom_minimum_size = Vector2(_ui_px(70), 0)
	var hp_row: Control = _create_bar_row("ZYCIE", int(member.get("hp", 0)), int(member.get("max_hp", 1)))
	hp_row.custom_minimum_size = Vector2(_ui_px(220), 0)
	var sp_row: Control = _create_bar_row("MANA", int(member.get("sp", 0)), int(member.get("max_sp", 1)))
	sp_row.custom_minimum_size = Vector2(_ui_px(220), 0)
	content.add_child(portrait)
	content.add_child(name_label)
	content.add_child(level_label)
	content.add_child(hp_row)
	content.add_child(sp_row)
	margin.add_child(content)
	row.add_child(margin)
	return row


func _create_bar_row(label_text: String, value: int, max_value: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", _ui_px(8))
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(_ui_px(70), 0)
	var bar: ProgressBar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = maxi(max_value, 1)
	bar.value = clampi(value, 0, maxi(max_value, 1))
	var value_label: Label = Label.new()
	value_label.text = "%d/%d" % [value, max_value]
	value_label.custom_minimum_size = Vector2(_ui_px(90), 0)
	row.add_child(label)
	row.add_child(bar)
	row.add_child(value_label)
	return row


func _create_simple_row(left_text: String, right_text: String, disabled: bool = false) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _ui_px(8))
	margin.add_theme_constant_override("margin_top", _ui_px(6))
	margin.add_theme_constant_override("margin_right", _ui_px(8))
	margin.add_theme_constant_override("margin_bottom", _ui_px(6))
	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", _ui_px(10))
	var left_label: Label = Label.new()
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.text = left_text
	left_label.add_theme_font_size_override("font_size", _ui_px(18))
	var right_label: Label = Label.new()
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_label.text = right_text
	right_label.add_theme_font_size_override("font_size", _ui_px(17))
	if disabled:
		var muted: Color = Color(0.55, 0.55, 0.6)
		left_label.add_theme_color_override("font_color", muted)
		right_label.add_theme_color_override("font_color", muted)
		row.set_meta("disabled", true)
	content.add_child(left_label)
	content.add_child(right_label)
	margin.add_child(content)
	row.add_child(margin)
	return row


func _set_row_selection(rows: Array[Control], selected_index: int) -> void:
	var active_style: StyleBoxFlat = StyleBoxFlat.new()
	active_style.bg_color = Color(0, 0, 0, 0)
	active_style.border_width_bottom = _ui_px(2)
	active_style.border_color = Color.WHITE
	var inactive_style: StyleBoxFlat = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0, 0, 0, 0)
	for index: int in range(rows.size()):
		var row: Control = rows[index]
		var left_label: Label = row.find_child("*", false, false) as Label
		var labels: Array = row.find_children("*", "Label", true, false)
		for label_value: Variant in labels:
			var label: Label = label_value
			var color_value: Color = Color.WHITE if index == selected_index else Color(0.65, 0.65, 0.7)
			if bool(row.get_meta("disabled", false)):
				color_value = Color(0.55, 0.55, 0.6)
			label.add_theme_color_override("font_color", color_value)
		if index == selected_index:
			row.add_theme_stylebox_override("panel", active_style)
		else:
			row.add_theme_stylebox_override("panel", inactive_style)


func _get_equipped_item_name(item_id: String) -> String:
	if item_id == "":
		return "(puste)"
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("get_item"):
		return item_id
	var item_data: QuizRpgItemData = inventory_service.call("get_item", item_id)
	if item_data == null:
		return item_id
	return item_data.display_name


func _get_equipment_delta_text(entry: Dictionary) -> String:
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	var equipment: Dictionary = member.get("equipment", {})
	var current_item_id: String = str(equipment.get(_selected_slot_name, ""))
	var current_atk: int = _get_item_stat(current_item_id, "atk_bonus")
	var current_def: int = _get_item_stat(current_item_id, "def_bonus")
	var next_atk: int = int(entry.get("atk_bonus", 0))
	var next_def: int = int(entry.get("def_bonus", 0))
	var delta_atk: int = next_atk - current_atk
	var delta_def: int = next_def - current_def
	return "ATK %s%d  DEF %s%d" % [_delta_sign(delta_atk), delta_atk, _delta_sign(delta_def), delta_def]


func _get_item_stat(item_id: String, stat_name: String) -> int:
	if item_id == "":
		return 0
	var inventory_service: Node = _get_inventory_service()
	if inventory_service == null or not inventory_service.has_method("get_item"):
		return 0
	var item_data: QuizRpgItemData = inventory_service.call("get_item", item_id)
	if item_data == null:
		return 0
	return int(item_data.get(stat_name))


func _delta_sign(value: int) -> String:
	if value >= 0:
		return "+"
	return ""


func _save_game() -> void:
	if _gm and _gm.has_method("save_game"):
		_gm.save_game()
	_show_toast("Zapisano.")


func _show_toast(text: String) -> void:
	_toast_reset_text = text
	toast_label.text = text
	var timer: SceneTreeTimer = get_tree().create_timer(1.5, true, false, true)
	await timer.timeout
	if toast_label.text == _toast_reset_text:
		toast_label.text = ""


func _on_player_data_changed() -> void:
	if not _paused:
		return
	match _mode:
		"left_menu":
			_show_default_party_panel()
		"items_list", "item_target_select":
			if _mode == "items_list":
				_show_items_panel()
			else:
				_show_party_select_panel("Wybierz postac dla przedmiotu")
		"skills_party_select", "skills_list":
			if _mode == "skills_list":
				_show_skills_panel()
			else:
				_show_party_select_panel("Wybierz postac dla umiejetnosci")
		"equip_party_select", "equip_actions", "equip_slots", "equip_item_list":
			if _mode == "equip_party_select":
				_show_party_select_panel("Wybierz postac do ekwipunku")
			else:
				_show_equipment_panel()
		"status_party_select", "status_view":
			if _mode == "status_view":
				_show_status_panel()
			else:
				_show_party_select_panel("Wybierz postac do statusu")


func _on_player_hp_changed(_new_hp: int, _new_max_hp: int) -> void:
	_on_player_data_changed()


func _apply_scaling() -> void:
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 3.0
	right_panel.size_flags_stretch_ratio = 7.0
	context_title_label.add_theme_font_size_override("font_size", _ui_px(28))
	toast_label.add_theme_font_size_override("font_size", _ui_px(18))


func _get_inventory_service() -> Node:
	var core_manager: Node = get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var service: Variant = core_manager.call("get_singleton", "InventoryService")
		if service is Node:
			return service
	return get_node_or_null("/root/InventoryService")


func _ui_px(value: int) -> int:
	var ui_scale_manager: Node = get_node_or_null("/root/UIScaleManager")
	if ui_scale_manager and ui_scale_manager.has_method("px"):
		return int(ui_scale_manager.call("px", value))
	var ui_scale_service: Node = get_node_or_null("/root/UIScaleService")
	if ui_scale_service and ui_scale_service.has_method("px"):
		return int(ui_scale_service.call("px", value))
	return value


func _is_accept(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or _is_key_pressed(event, [KEY_Z, KEY_ENTER])


func _is_cancel(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or _is_key_pressed(event, [KEY_X, KEY_ESCAPE])


func _is_nav_up(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or _is_key_pressed(event, [KEY_W, KEY_UP])


func _is_nav_down(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or _is_key_pressed(event, [KEY_S, KEY_DOWN])


func _is_nav_left(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_left") or _is_key_pressed(event, [KEY_A, KEY_LEFT])


func _is_nav_right(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_right") or _is_key_pressed(event, [KEY_D, KEY_RIGHT])


func _is_prev_tab(event: InputEvent) -> bool:
	return _is_key_pressed(event, [KEY_Q])


func _is_next_tab(event: InputEvent) -> bool:
	return _is_key_pressed(event, [KEY_E])


func _is_key_pressed(event: InputEvent, keys: Array[int]) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and int(key_event.keycode) in keys
