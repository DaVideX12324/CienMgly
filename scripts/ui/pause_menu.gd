extends CanvasLayer

const ITEM_TAB_CATEGORIES: Array[String] = ["item", "hand", "part", "key"]
const STATUS_EQUIP_SLOTS: Array[String] = ["weapon", "shield", "head", "body", "accessory"]

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
@onready var save_panel: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/SavePanel
@onready var save_hint_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/SavePanel/SaveHintLabel
@onready var save_slots_vbox: VBoxContainer = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/SavePanel/SaveSlotsVBox
@onready var save_footer_label: Label = $PauseRoot/MainRow/RightPanel/Margin/RightVBox/ContextBody/SavePanel/FooterLabel

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
var _item_tab_rows: Array[Control] = []
var _item_rows: Array[Control] = []
var _skill_rows: Array[Control] = []
var _equip_action_rows: Array[Control] = []
var _equip_slot_rows: Array[Control] = []
var _equip_item_rows: Array[Control] = []
var _status_bar_rows: Array[Control] = []
var _status_stat_rows: Array[Control] = []
var _status_equip_rows: Array[Control] = []
var _confirm_rows: Array[Control] = []
var _save_slot_rows: Array[Control] = []
var _current_item_entries: Array[Dictionary] = []
var _current_skill_entries: Array[Dictionary] = []
var _current_equip_entries: Array[Dictionary] = []
var _save_slot_entries: Array[Dictionary] = []
var _toast_reset_text: String = ""
var _party_rows_selectable: bool = false
var _save_slot_index: int = 0


func _ready() -> void:
	_gm = CoreManager.get_singleton("GameManager")
	_ps = CoreManager.get_singleton("PlayerStats")
	pause_root.visible = false
	_cache_scene_rows()
	_apply_scaling()
	_show_default_party_panel()
	if _ps:
		if _ps.has_signal("inventory_changed"):
			_ps.inventory_changed.connect(_on_player_data_changed)
		if _ps.has_signal("party_changed"):
			_ps.party_changed.connect(_on_player_data_changed)
		if _ps.has_signal("hp_changed"):
			_ps.hp_changed.connect(_on_player_hp_changed)


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
	if _mode == "save_slots" and _handle_save_slots_input(event):
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


func _handle_close_input(event: InputEvent) -> bool:
	if not _is_cancel(event):
		return false
	match _mode:
		"left_menu":
			_toggle_pause()
		"save_slots":
			_mode = "left_menu"
			_show_default_party_panel()
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
		_tab_index = (_tab_index - 1 + ITEM_TAB_CATEGORIES.size()) % ITEM_TAB_CATEGORIES.size()
		_items_index = 0
		_show_items_panel()
		return true
	if _is_next_tab(event):
		_tab_index = (_tab_index + 1) % ITEM_TAB_CATEGORIES.size()
		_items_index = 0
		_show_items_panel()
		return true
	return false


func _handle_save_slots_input(event: InputEvent) -> bool:
	if _is_nav_right(event):
		_add_save_slot()
		return true
	if _is_nav_left(event):
		_delete_selected_save_slot()
		return true
	return false


func _move_selection(delta: int) -> void:
	match _mode:
		"left_menu":
			_left_menu_index = wrapi(_left_menu_index + delta, 0, _menu_rows.size())
			_refresh_left_menu_rows()
		"items_list":
			if _current_item_entries.is_empty():
				return
			_items_index = wrapi(_items_index + delta, 0, _current_item_entries.size())
			_refresh_item_rows()
		"item_target_select", "skills_party_select", "equip_party_select", "status_party_select":
			var visible_party_count: int = _get_visible_row_count(_party_rows)
			if visible_party_count <= 0:
				return
			_party_index = wrapi(_party_index + delta, 0, visible_party_count)
			_refresh_party_rows()
		"save_slots":
			if _save_slot_entries.is_empty():
				return
			_save_slot_index = wrapi(_save_slot_index + delta, 0, _save_slot_entries.size())
			_refresh_save_slot_rows()
		"skills_list":
			if _current_skill_entries.is_empty():
				return
			_skills_index = _find_next_enabled_skill_index(_skills_index, delta)
			_refresh_skill_rows()
		"equip_slots":
			if _equip_slot_rows.is_empty():
				return
			_equip_slot_index = wrapi(_equip_slot_index + delta, 0, _equip_slot_rows.size())
			_refresh_equipment_slot_rows()
			_rebuild_equipment_item_rows()
		"equip_item_list":
			if _current_equip_entries.is_empty():
				return
			_equip_item_index = wrapi(_equip_item_index + delta, 0, _current_equip_entries.size())
			_refresh_equipment_item_rows()


func _move_equip_action(delta: int) -> void:
	_equip_action_index = wrapi(_equip_action_index + delta, 0, _equip_action_rows.size())
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
		"save_slots":
			_save_to_selected_slot()


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
			_mode = "save_slots"
			_save_slot_index = 0
			_show_save_panel()
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


func _show_default_party_panel() -> void:
	_show_panel("party")
	context_title_label.text = "Druzyna"
	party_hint_label.text = ""
	_party_rows_selectable = false
	_refresh_left_menu_rows()
	_rebuild_party_rows(false)


func _show_party_select_panel(title_text: String) -> void:
	_show_panel("party")
	context_title_label.text = title_text
	party_hint_label.text = "Enter/Z: potwierdz    X/Esc: wroc"
	_party_rows_selectable = true
	_rebuild_party_rows(true)


func _show_items_panel() -> void:
	_show_panel("items")
	context_title_label.text = "Przedmioty"
	_rebuild_item_tabs()
	_rebuild_item_rows()


func _show_skills_panel() -> void:
	_show_panel("skills")
	context_title_label.text = "Umiejetnosci"
	_populate_actor_header(skills_actor_header, _ps.get_party_member(_selected_member_index), true)
	_rebuild_skill_rows()


func _show_equipment_panel() -> void:
	_show_panel("equipment")
	context_title_label.text = "Ekwipunek"
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	_populate_actor_header(equipment_actor_header, member, false)
	equipment_stats_label.text = "ATK %d   DEF %d" % [_ps.get_member_total_atk(_selected_member_index), _ps.get_member_total_def(_selected_member_index)]
	_rebuild_equip_action_rows()
	_rebuild_equipment_slots()
	_rebuild_equipment_item_rows()
	if _mode == "equip_item_list":
		equipment_footer_label.text = str(_current_equip_entries[_equip_item_index].get("description", "")) if _equip_item_index >= 0 and _equip_item_index < _current_equip_entries.size() else ""
	else:
		equipment_footer_label.text = "Enter/Z: wybierz    X/Esc: wroc"


func _show_status_panel() -> void:
	_show_panel("status")
	context_title_label.text = "Status"
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	_populate_actor_header(status_actor_header, member, false)
	_rebuild_status_panel(member)


func _show_confirm_panel() -> void:
	_show_panel("confirm")
	context_title_label.text = "Potwierdzenie"
	confirm_label.text = "Zakonczyc gre?"
	_rebuild_confirm_rows()


func _show_save_panel() -> void:
	_show_panel("save")
	context_title_label.text = "Zapis gry"
	save_hint_label.text = "Enter/Z: zapisz    A/Left: usun slot    D/Right: dodaj slot    X/Esc: wroc"
	_rebuild_save_slots()


func _show_panel(panel_name: String) -> void:
	party_panel.visible = panel_name == "party"
	items_panel.visible = panel_name == "items"
	skills_panel.visible = panel_name == "skills"
	equipment_panel.visible = panel_name == "equipment"
	status_panel.visible = panel_name == "status"
	confirm_panel.visible = panel_name == "confirm"
	save_panel.visible = panel_name == "save"


func _cache_scene_rows() -> void:
	_menu_rows = _collect_rows(menu_list_vbox)
	_party_rows = _collect_rows(party_list_vbox)
	_item_tab_rows = _collect_rows(items_tabs_row)
	_item_rows = _collect_rows(items_list_vbox)
	_skill_rows = _collect_rows(skills_list_vbox)
	_equip_action_rows = _collect_rows(equip_actions_row)
	_equip_slot_rows = _collect_rows(equip_slots_vbox)
	_equip_item_rows = _collect_rows(equip_items_vbox)
	_status_bar_rows = _collect_rows(status_bars_vbox)
	_status_stat_rows = _collect_rows(status_stats_vbox)
	_status_equip_rows = _collect_rows(status_equip_vbox)
	_confirm_rows = _collect_rows(confirm_options_vbox)
	_save_slot_rows = _collect_rows(save_slots_vbox)


func _refresh_left_menu_rows() -> void:
	_set_row_selection(_menu_rows, _left_menu_index)


func _rebuild_party_rows(_selectable: bool) -> void:
	_party_rows_selectable = _selectable
	var members: Array[Dictionary] = _ps.get_party_members() if _ps and _ps.has_method("get_party_members") else []
	_ensure_party_row_capacity(members)
	for index: int in range(_party_rows.size()):
		var row: Control = _party_rows[index]
		var has_member: bool = index < members.size()
		row.visible = has_member
		if has_member:
			_populate_party_row(row, members[index])
	if not members.is_empty():
		_party_index = clampi(_party_index, 0, min(members.size(), _party_rows.size()) - 1)
	_refresh_party_rows()


func _refresh_party_rows() -> void:
	_set_row_selection(_party_rows, _party_index if _party_rows_selectable else -1)


func _rebuild_item_tabs() -> void:
	_set_row_selection(_item_tab_rows, _tab_index)


func _rebuild_item_rows() -> void:
	_current_item_entries.clear()
	var category: String = ITEM_TAB_CATEGORIES[_tab_index] if _tab_index < ITEM_TAB_CATEGORIES.size() else "item"
	var entries: Array[Dictionary] = _ps.get_items_by_category(category) if _ps and _ps.has_method("get_items_by_category") else []
	for index: int in range(_item_rows.size()):
		var row: Control = _item_rows[index]
		var has_entry: bool = index < entries.size()
		row.visible = has_entry
		if has_entry:
			var entry: Dictionary = entries[index]
			_set_simple_row(row, str(entry.get("name", "---")), ":%d" % int(entry.get("count", 0)), false)
			_current_item_entries.append(entry)
	if _current_item_entries.is_empty():
		items_footer_label.text = "Brak przedmiotow w tej zakladce."
	else:
		_items_index = clampi(_items_index, 0, _current_item_entries.size() - 1)
		_refresh_item_rows()


func _refresh_item_rows() -> void:
	_set_row_selection(_item_rows, _items_index)
	if _items_index >= 0 and _items_index < _current_item_entries.size():
		items_footer_label.text = str(_current_item_entries[_items_index].get("description", ""))


func _rebuild_skill_rows() -> void:
	_current_skill_entries.clear()
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	var member_sp: int = int(member.get("sp", 0))
	var member_tp: int = int(member.get("tp", 0))
	var skills: Array = _ps.skills if _ps and _ps.get("skills") is Array else []
	for index: int in range(_skill_rows.size()):
		var row: Control = _skill_rows[index]
		var has_skill: bool = index < skills.size()
		row.visible = has_skill
		if has_skill:
			var skill: Dictionary = skills[index]
			var cost_text: String = "-"
			var disabled: bool = false
			if int(skill.get("sp_cost", 0)) > 0:
				cost_text = "SP %d" % int(skill.get("sp_cost", 0))
				disabled = member_sp < int(skill.get("sp_cost", 0))
			elif int(skill.get("tp_cost", 0)) > 0:
				cost_text = "TP %d" % int(skill.get("tp_cost", 0))
				disabled = member_tp < int(skill.get("tp_cost", 0))
			_set_simple_row(row, "[*] %s" % str(skill.get("name", "---")), cost_text, disabled)
			var skill_copy: Dictionary = skill.duplicate(true)
			skill_copy["disabled"] = disabled
			_current_skill_entries.append(skill_copy)
	if _current_skill_entries.is_empty():
		skills_footer_label.text = "Brak umiejetnosci."
		return
	_skills_index = _find_next_enabled_skill_index(clampi(_skills_index, 0, _current_skill_entries.size() - 1), 1, true)
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
	_refresh_equip_action_rows()


func _refresh_equip_action_rows() -> void:
	var selected_index: int = _equip_action_index if _mode == "equip_actions" else -1
	_set_row_selection(_equip_action_rows, selected_index)


func _rebuild_equipment_slots() -> void:
	var member: Dictionary = _ps.get_party_member(_selected_member_index)
	var equipment: Dictionary = member.get("equipment", {})
	var slots: Array = _ps.get_equipment_slots()
	for index: int in range(_equip_slot_rows.size()):
		var row: Control = _equip_slot_rows[index]
		var has_slot: bool = index < slots.size()
		row.visible = has_slot
		if has_slot:
			var slot_name: String = str(slots[index])
			var equipped_name: String = _get_equipped_item_name(str(equipment.get(slot_name, "")))
			_set_simple_row(row, _ps.get_equipment_label(slot_name), equipped_name)
	_refresh_equipment_slot_rows()


func _refresh_equipment_slot_rows() -> void:
	var selected_index: int = _equip_slot_index if _mode == "equip_slots" else -1
	_set_row_selection(_equip_slot_rows, selected_index)


func _rebuild_equipment_item_rows() -> void:
	_current_equip_entries.clear()
	var slot_name: String = _get_equipment_preview_slot_name()
	if _ps and _ps.has_method("get_equippable_entries_for_slot") and slot_name != "":
		_current_equip_entries = _ps.get_equippable_entries_for_slot(_selected_member_index, slot_name)
	var items_selectable: bool = _mode == "equip_item_list"
	for index: int in range(_equip_item_rows.size()):
		var row: Control = _equip_item_rows[index]
		var has_entry: bool = index < _current_equip_entries.size()
		row.visible = has_entry
		if has_entry:
			var entry: Dictionary = _current_equip_entries[index]
			_set_simple_row(row, str(entry.get("name", "---")), _get_equipment_delta_text(entry), not items_selectable)
	_refresh_equipment_item_rows()


func _refresh_equipment_item_rows() -> void:
	var selected_index: int = _equip_item_index if _mode == "equip_item_list" else -1
	_set_row_selection(_equip_item_rows, selected_index)
	if _mode == "equip_item_list" and _equip_item_index >= 0 and _equip_item_index < _current_equip_entries.size():
		equipment_footer_label.text = str(_current_equip_entries[_equip_item_index].get("description", ""))


func _get_equipment_preview_slot_name() -> String:
	if _mode == "equip_item_list" and _selected_slot_name != "":
		return _selected_slot_name
	var slots: Array = _ps.get_equipment_slots() if _ps and _ps.has_method("get_equipment_slots") else []
	if _mode == "equip_slots" and _equip_slot_index >= 0 and _equip_slot_index < slots.size():
		return str(slots[_equip_slot_index])
	if _selected_slot_name != "":
		return _selected_slot_name
	if not slots.is_empty():
		return str(slots[0])
	return ""


func _rebuild_status_panel(member: Dictionary) -> void:
	var exp_to_next: int = _ps.xp_to_next_level() if _ps and _selected_member_index == 0 else 0
	status_info_label.text = "LV %d   Exp %d   Do nastepnego poziomu %d" % [int(member.get("level", 1)), _ps.xp if _selected_member_index == 0 and _ps else 0, exp_to_next]
	if _status_bar_rows.size() >= 2:
		_populate_bar_row(_status_bar_rows[0] as HBoxContainer, "Zycie", int(member.get("hp", 0)), int(member.get("max_hp", 1)))
		_populate_bar_row(_status_bar_rows[1] as HBoxContainer, "Mana", int(member.get("sp", 0)), int(member.get("max_sp", 1)))
	if _status_stat_rows.size() >= 2:
		_set_simple_row(_status_stat_rows[0], "ATK", str(_ps.get_member_total_atk(_selected_member_index)))
		_set_simple_row(_status_stat_rows[1], "DEF", str(_ps.get_member_total_def(_selected_member_index)))
	var equipment: Dictionary = member.get("equipment", {})
	for index: int in range(_status_equip_rows.size()):
		var slot_name: String = STATUS_EQUIP_SLOTS[index] if index < STATUS_EQUIP_SLOTS.size() else ""
		var row: Control = _status_equip_rows[index]
		row.visible = slot_name != ""
		if slot_name != "":
			_set_simple_row(row, _ps.get_equipment_label(slot_name), _get_equipped_item_name(str(equipment.get(slot_name, ""))))


func _rebuild_confirm_rows() -> void:
	_refresh_confirm_rows()


func _refresh_confirm_rows() -> void:
	_set_row_selection(_confirm_rows, _confirm_index)


func _rebuild_save_slots() -> void:
	_save_slot_entries.clear()
	if _gm and _gm.has_method("get_save_slots_summary"):
		_save_slot_entries = _gm.get_save_slots_summary()
	_ensure_save_slot_row_capacity(_save_slot_entries.size())
	for index: int in range(_save_slot_rows.size()):
		var row: Control = _save_slot_rows[index]
		var has_entry: bool = index < _save_slot_entries.size()
		row.visible = has_entry
		if has_entry:
			_populate_save_slot_row(row, _save_slot_entries[index])
	if not _save_slot_entries.is_empty():
		_save_slot_index = clampi(_save_slot_index, 0, _save_slot_entries.size() - 1)
	_refresh_save_slot_rows()


func _refresh_save_slot_rows() -> void:
	_set_row_selection(_save_slot_rows, _save_slot_index)
	if _save_slot_index < 0 or _save_slot_index >= _save_slot_entries.size():
		save_footer_label.text = ""
		return
	var slot_entry: Dictionary = _save_slot_entries[_save_slot_index]
	if bool(slot_entry.get("exists", false)):
		save_footer_label.text = "%s\n%s\n%s" % [
			str(slot_entry.get("title", "")),
			str(slot_entry.get("subtitle", "")),
			str(slot_entry.get("detail", "")),
		]
	else:
		save_footer_label.text = "Pusty slot. Enter/Z zapisze aktualna gre do tego miejsca."


func _populate_save_slot_row(row: Control, slot_entry: Dictionary) -> void:
	var left_text: String = str(slot_entry.get("slot_name", "Slot"))
	var right_text: String = ""
	if bool(slot_entry.get("exists", false)):
		left_text = "%s  %s" % [left_text, str(slot_entry.get("title", ""))]
		right_text = str(slot_entry.get("time_text", ""))
	else:
		left_text = "%s  Pusty slot" % left_text
	_set_simple_row(row, left_text, right_text)


func _save_to_selected_slot() -> void:
	if _save_slot_index < 0 or _save_slot_index >= _save_slot_entries.size():
		return
	if _gm and _gm.has_method("save_game") and _gm.save_game(_save_slot_index):
		_show_save_panel()
		_show_toast("Zapisano do slotu %d." % (_save_slot_index + 1))


func _add_save_slot() -> void:
	if _gm == null or not _gm.has_method("add_save_slot"):
		return
	_save_slot_index = int(_gm.add_save_slot())
	_show_save_panel()
	_show_toast("Dodano slot %d." % (_save_slot_index + 1))


func _delete_selected_save_slot() -> void:
	if _gm == null or not _gm.has_method("delete_save_slot"):
		return
	if _gm.delete_save_slot(_save_slot_index):
		_save_slot_index = maxi(0, _save_slot_index - 1)
		_show_save_panel()
		_show_toast("Usunieto slot.")
	else:
		_show_toast("Nie mozna usunac tego slotu.")


func _populate_actor_header(target: HBoxContainer, member: Dictionary, show_bars: bool) -> void:
	var portrait: TextureRect = target.get_node("Portrait") as TextureRect
	var name_label: Label = target.get_node("InfoVBox/NameLabel") as Label
	var hp_row: HBoxContainer = target.get_node("InfoVBox/HPRow") as HBoxContainer
	var sp_row: HBoxContainer = target.get_node("InfoVBox/SPRow") as HBoxContainer
	var hp_progress: Range = hp_row.get_node("BarProgress") as Range
	var sp_progress: Range = sp_row.get_node("BarProgress") as Range
	portrait.texture = member.get("portrait") as Texture2D
	name_label.text = "%s  LV %d" % [str(member.get("name", "Bohater")), int(member.get("level", 1))]
	_populate_bar_row(hp_row, "Zycie", int(member.get("hp", 0)), int(member.get("max_hp", 1)))
	_populate_bar_row(sp_row, "Mana", int(member.get("sp", 0)), int(member.get("max_sp", 1)))
	if hp_progress:
		(hp_progress as Control).visible = show_bars
	if sp_progress:
		(sp_progress as Control).visible = show_bars


func _populate_party_row(row: Control, member: Dictionary) -> void:
	var portrait: TextureRect = row.get_node("Margin/ContentRow/Portrait") as TextureRect
	var name_label: Label = row.get_node("Margin/ContentRow/NameLabel") as Label
	var level_label: Label = row.get_node("Margin/ContentRow/LevelLabel") as Label
	var hp_row: HBoxContainer = row.get_node("Margin/ContentRow/HPRow") as HBoxContainer
	var sp_row: HBoxContainer = row.get_node("Margin/ContentRow/SPRow") as HBoxContainer
	portrait.texture = member.get("portrait") as Texture2D
	name_label.text = str(member.get("name", "Bohater"))
	level_label.text = "LV %d" % int(member.get("level", 1))
	_populate_bar_row(hp_row, "ZYCIE", int(member.get("hp", 0)), int(member.get("max_hp", 1)))
	_populate_bar_row(sp_row, "MANA", int(member.get("sp", 0)), int(member.get("max_sp", 1)))


func _set_simple_row(row: Control, left_text: String, right_text: String, disabled: bool = false) -> void:
	var left_label: Label = row.get_node("Margin/ContentRow/LeftLabel") as Label
	var right_label: Label = row.get_node("Margin/ContentRow/RightLabel") as Label
	left_label.text = left_text
	right_label.text = right_text
	row.set_meta("disabled", disabled)


func _set_row_selection(rows: Array[Control], selected_index: int) -> void:
	for index: int in range(rows.size()):
		var row: Control = rows[index]
		if not row.visible:
			continue
		var underline: CanvasItem = _ensure_row_selection_underline(row)
		var labels: Array = row.find_children("*", "Label", true, false)
		var is_selected: bool = index == selected_index
		var target_modulate: Color = Color.WHITE if is_selected else Color(0.65, 0.65, 0.7)
		if bool(row.get_meta("disabled", false)):
			target_modulate = Color(0.55, 0.55, 0.6)
		for label_value: Variant in labels:
			var label: Label = label_value as Label
			label.self_modulate = target_modulate
		var textures: Array = row.find_children("*", "TextureRect", true, false)
		for texture_value: Variant in textures:
			var texture_rect: TextureRect = texture_value as TextureRect
			if texture_rect:
				texture_rect.self_modulate = target_modulate
		var progress_bars: Array = row.find_children("*", "Range", true, false)
		for progress_value: Variant in progress_bars:
			var progress_bar: Range = progress_value as Range
			if progress_bar:
				(progress_bar as Control).self_modulate = target_modulate
		if underline:
			underline.visible = is_selected


func _hide_rows(rows: Array[Control]) -> void:
	for row: Control in rows:
		row.visible = false


func _get_visible_row_count(rows: Array[Control]) -> int:
	var count: int = 0
	for row: Control in rows:
		if row.visible:
			count += 1
	return count


func _collect_rows(container: Node) -> Array[Control]:
	var rows: Array[Control] = []
	if container == null:
		return rows
	for child: Node in container.get_children():
		if child is Control:
			rows.append(child as Control)
	return rows


func _ensure_party_row_capacity(members: Array[Dictionary]) -> void:
	if members.size() <= _party_rows.size() or _party_rows.is_empty():
		return
	var template: Control = _party_rows[0]
	for index: int in range(_party_rows.size(), members.size()):
		var new_row: Control = template.duplicate() as Control
		if new_row == null:
			continue
		new_row.name = "PartyRow%d" % index
		new_row.visible = false
		party_list_vbox.add_child(new_row)
		_party_rows.append(new_row)
	_apply_party_rows_scaling(_party_rows)


func _ensure_save_slot_row_capacity(required_count: int) -> void:
	if required_count <= _save_slot_rows.size() or _save_slot_rows.is_empty():
		return
	var template: Control = _save_slot_rows[0]
	for index: int in range(_save_slot_rows.size(), required_count):
		var new_row: Control = template.duplicate() as Control
		if new_row == null:
			continue
		new_row.name = "SaveSlotRow%d" % index
		new_row.visible = false
		save_slots_vbox.add_child(new_row)
		_save_slot_rows.append(new_row)
	_apply_row_scaling(_save_slot_rows)


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
		"save_slots":
			_show_save_panel()


func _on_player_hp_changed(_new_hp: int, _new_max_hp: int) -> void:
	_on_player_data_changed()


func _apply_scaling() -> void:
	context_title_label.add_theme_font_size_override("font_size", _ui_px(28))
	var title_label: Label = left_panel.get_node("Margin/LeftVBox/TitleLabel") as Label
	title_label.add_theme_font_size_override("font_size", _ui_px(26))
	toast_label.add_theme_font_size_override("font_size", _ui_px(18))
	_apply_row_scaling(_menu_rows)
	_apply_row_scaling(_item_tab_rows)
	_apply_row_scaling(_item_rows)
	_apply_row_scaling(_skill_rows)
	_apply_row_scaling(_equip_action_rows)
	_apply_row_scaling(_equip_slot_rows)
	_apply_row_scaling(_equip_item_rows)
	_apply_row_scaling(_status_stat_rows)
	_apply_row_scaling(_status_equip_rows)
	_apply_row_scaling(_confirm_rows)
	_apply_row_scaling(_save_slot_rows)
	_apply_party_rows_scaling(_party_rows)
	_apply_bar_rows_scaling(_status_bar_rows)
	_apply_actor_header_scaling(skills_actor_header)
	_apply_actor_header_scaling(equipment_actor_header)
	_apply_actor_header_scaling(status_actor_header)


func _apply_row_scaling(rows: Array[Control]) -> void:
	for row: Control in rows:
		var margin: MarginContainer = row.get_node_or_null("Margin") as MarginContainer
		var content: HBoxContainer = row.get_node_or_null("Margin/ContentRow") as HBoxContainer
		var left_label: Label = row.get_node_or_null("Margin/ContentRow/LeftLabel") as Label
		var right_label: Label = row.get_node_or_null("Margin/ContentRow/RightLabel") as Label
		var underline: ColorRect = _ensure_row_selection_underline(row)
		if margin:
			margin.add_theme_constant_override("margin_left", _ui_px(8))
			margin.add_theme_constant_override("margin_top", _ui_px(6))
			margin.add_theme_constant_override("margin_right", _ui_px(8))
			margin.add_theme_constant_override("margin_bottom", _ui_px(6))
		if content:
			content.add_theme_constant_override("separation", _ui_px(10))
		if left_label:
			left_label.add_theme_font_size_override("font_size", _ui_px(18))
		if right_label:
			right_label.add_theme_font_size_override("font_size", _ui_px(17))
		if underline:
			_configure_selection_underline(underline, row)


func _apply_party_rows_scaling(rows: Array[Control]) -> void:
	for row: Control in rows:
		var margin: MarginContainer = row.get_node("Margin") as MarginContainer
		var content: HBoxContainer = row.get_node("Margin/ContentRow") as HBoxContainer
		var portrait: TextureRect = row.get_node("Margin/ContentRow/Portrait") as TextureRect
		var name_label: Label = row.get_node("Margin/ContentRow/NameLabel") as Label
		var level_label: Label = row.get_node("Margin/ContentRow/LevelLabel") as Label
		var hp_row: HBoxContainer = row.get_node("Margin/ContentRow/HPRow") as HBoxContainer
		var sp_row: HBoxContainer = row.get_node("Margin/ContentRow/SPRow") as HBoxContainer
		var underline: ColorRect = _ensure_row_selection_underline(row)
		margin.add_theme_constant_override("margin_left", _ui_px(10))
		margin.add_theme_constant_override("margin_top", _ui_px(8))
		margin.add_theme_constant_override("margin_right", _ui_px(10))
		margin.add_theme_constant_override("margin_bottom", _ui_px(8))
		content.add_theme_constant_override("separation", _ui_px(12))
		portrait.custom_minimum_size = Vector2(_ui_px(64), _ui_px(64))
		name_label.custom_minimum_size = Vector2(_ui_px(160), 0)
		level_label.custom_minimum_size = Vector2(_ui_px(70), 0)
		hp_row.custom_minimum_size = Vector2(_ui_px(220), 0)
		sp_row.custom_minimum_size = Vector2(_ui_px(220), 0)
		_apply_bar_row_scaling(hp_row)
		_apply_bar_row_scaling(sp_row)
		if underline:
			_configure_selection_underline(underline, row)


func _apply_bar_rows_scaling(rows: Array[Control]) -> void:
	for row: Control in rows:
		if row is HBoxContainer:
			_apply_bar_row_scaling(row as HBoxContainer)


func _apply_bar_row_scaling(row: HBoxContainer) -> void:
	var label: Label = row.get_node("BarLabel") as Label
	var value_label: Label = row.get_node("BarValue") as Label
	row.add_theme_constant_override("separation", _ui_px(8))
	label.custom_minimum_size = Vector2(_ui_px(70), 0)
	value_label.custom_minimum_size = Vector2(_ui_px(90), 0)


func _configure_selection_underline(underline: ColorRect, row: Control) -> void:
	var thickness: int = _ui_px(2)
	var side_margin: int = _ui_px(8)
	underline.color = Color.WHITE
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var underline_parent: Control = underline.get_parent() as Control
	if underline_parent and underline_parent != row:
		underline_parent.anchor_left = 0.0
		underline_parent.anchor_top = 0.0
		underline_parent.anchor_right = 1.0
		underline_parent.anchor_bottom = 1.0
		underline_parent.offset_left = 0.0
		underline_parent.offset_top = 0.0
		underline_parent.offset_right = 0.0
		underline_parent.offset_bottom = 0.0
		underline_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underline.anchor_left = 0.0
	underline.anchor_top = 1.0
	underline.anchor_right = 1.0
	underline.anchor_bottom = 1.0
	underline.offset_left = float(side_margin)
	underline.offset_top = float(-thickness)
	underline.offset_right = float(-side_margin)
	underline.offset_bottom = 0.0
	underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _ensure_row_selection_underline(row: Control) -> ColorRect:
	var underline: ColorRect = _get_row_selection_underline(row) as ColorRect
	if underline:
		return underline
	var underline_host: Control = row.get_node_or_null("Control") as Control
	if underline_host == null:
		underline_host = Control.new()
		underline_host.name = "SelectionOverlay"
		underline_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		underline_host.anchor_left = 0.0
		underline_host.anchor_top = 0.0
		underline_host.anchor_right = 1.0
		underline_host.anchor_bottom = 1.0
		underline_host.offset_left = 0.0
		underline_host.offset_top = 0.0
		underline_host.offset_right = 0.0
		underline_host.offset_bottom = 0.0
		row.add_child(underline_host)
		row.move_child(underline_host, 0)
		if row.owner:
			underline_host.owner = row.owner
	underline = ColorRect.new()
	underline.name = "SelectionUnderline"
	underline.visible = false
	underline_host.add_child(underline)
	if row.owner:
		underline.owner = row.owner
	return underline


func _get_row_selection_underline(row: Control) -> CanvasItem:
	var direct: CanvasItem = row.get_node_or_null("SelectionUnderline") as CanvasItem
	if direct:
		return direct
	return row.find_child("SelectionUnderline", true, false) as CanvasItem


func _apply_actor_header_scaling(header: HBoxContainer) -> void:
	var portrait: TextureRect = header.get_node("Portrait") as TextureRect
	var info_box: VBoxContainer = header.get_node("InfoVBox") as VBoxContainer
	var name_label: Label = header.get_node("InfoVBox/NameLabel") as Label
	var hp_row: HBoxContainer = header.get_node("InfoVBox/HPRow") as HBoxContainer
	var sp_row: HBoxContainer = header.get_node("InfoVBox/SPRow") as HBoxContainer
	header.add_theme_constant_override("separation", _ui_px(12))
	portrait.custom_minimum_size = Vector2(_ui_px(128), _ui_px(128))
	info_box.add_theme_constant_override("separation", _ui_px(6))
	name_label.add_theme_font_size_override("font_size", _ui_px(22))
	_apply_bar_row_scaling(hp_row)
	_apply_bar_row_scaling(sp_row)


func _populate_bar_row(row: HBoxContainer, label_text: String, value: int, max_value: int) -> void:
	var label: Label = row.get_node("BarLabel") as Label
	var progress_bar: Range = row.get_node("BarProgress") as Range
	var value_label: Label = row.get_node("BarValue") as Label
	var safe_max: int = maxi(max_value, 1)
	label.text = label_text
	if progress_bar:
		(progress_bar as Control).visible = true
		progress_bar.max_value = safe_max
		progress_bar.value = clampi(value, 0, safe_max)
	value_label.text = "%d/%d" % [value, max_value]


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
