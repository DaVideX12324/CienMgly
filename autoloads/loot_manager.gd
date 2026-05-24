extends Node

signal loot_awarded(item_id: String, count: int)
signal loot_popup_closed

const BARREL_POPUP_HEIGHT := 228.0

var barrel_drop_chance: float = 0.45
var _rng := RandomNumberGenerator.new()
var _popup_layer: CanvasLayer
var _popup_root: Control
var _popup_title: Label
var _popup_message: Label
var _popup_detail: Label
var _popup_button: Button
var _previous_pause_state: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func search_barrel(drop_chance: float = -1.0) -> Dictionary:
	var chance := barrel_drop_chance if drop_chance < 0.0 else clampf(drop_chance, 0.0, 1.0)
	if _rng.randf() > chance:
		return {
			"found": false,
			"title": "Pusta beczka",
			"message": "Nic nie wypadlo.",
			"detail": "Nacisnij E albo Enter, aby kontynuowac.",
		}

	var item_id := _roll_weighted_item_id(_get_barrel_loot_table())
	if item_id == "":
		return {
			"found": false,
			"title": "Pusta beczka",
			"message": "Nic nie wypadlo.",
			"detail": "Nacisnij E albo Enter, aby kontynuowac.",
		}

	var count := _roll_item_count(item_id)
	var item_data := _get_item_data(item_id)
	var item_name := item_data.display_name if item_data != null else item_id
	_award_item(item_id, count)
	return {
		"found": true,
		"item_id": item_id,
		"item_name": item_name,
		"count": count,
		"title": "Znaleziono przedmiot",
		"message": "%s x%d trafia do ekwipunku." % [item_name, count],
		"detail": item_data.description if item_data != null and item_data.description != "" else "Nacisnij E albo Enter, aby kontynuowac.",
	}


func show_loot_popup(result: Dictionary) -> void:
	if not bool(result.get("found", false)):
		return
	_ensure_popup()
	_popup_title.text = str(result.get("title", "Loot"))
	_popup_message.text = str(result.get("message", ""))
	_popup_detail.text = str(result.get("detail", "Nacisnij E albo Enter, aby kontynuowac."))
	_previous_pause_state = get_tree().paused
	get_tree().paused = true
	_popup_layer.visible = true
	_popup_button.grab_focus()


func _award_item(item_id: String, count: int) -> void:
	var player_stats := _get_singleton("PlayerStats")
	if player_stats and player_stats.has_method("add_item"):
		player_stats.call("add_item", item_id, count)
		loot_awarded.emit(item_id, count)


func _roll_weighted_item_id(entries: Array[Dictionary]) -> String:
	var total_weight := 0
	for entry: Dictionary in entries:
		total_weight += maxi(0, int(entry.get("weight", 0)))
	if total_weight <= 0:
		return ""

	var roll := _rng.randi_range(1, total_weight)
	var cursor := 0
	for entry: Dictionary in entries:
		cursor += maxi(0, int(entry.get("weight", 0)))
		if roll <= cursor:
			return str(entry.get("item_id", ""))
	return ""


func _roll_item_count(item_id: String) -> int:
	match item_id:
		"potion":
			return 1 if _rng.randf() < 0.8 else 2
		"ether", "focus_tonic":
			return 1
		_:
			return 1


func _get_barrel_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "potion", "weight": 55},
		{"item_id": "ether", "weight": 25},
		{"item_id": "focus_tonic", "weight": 15},
		{"item_id": "lucky_charm", "weight": 5},
	]


func _ensure_popup() -> void:
	if _popup_layer:
		return

	_popup_layer = CanvasLayer.new()
	_popup_layer.name = "LootPopupLayer"
	_popup_layer.layer = 40
	_popup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_popup_layer.visible = false
	add_child(_popup_layer)

	_popup_root = Control.new()
	_popup_root.name = "Root"
	_popup_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_root.gui_input.connect(_on_popup_gui_input)
	_popup_layer.add_child(_popup_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 18
	panel.offset_right = -18
	panel.offset_top = -BARREL_POPUP_HEIGHT
	panel.offset_bottom = -14
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	_popup_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(92, 92)
	icon_panel.add_theme_stylebox_override("panel", _make_icon_style())
	row.add_child(icon_panel)

	var icon_label := Label.new()
	icon_label.text = "?"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 40)
	icon_panel.add_child(icon_label)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 8)
	row.add_child(text_box)

	_popup_title = Label.new()
	_popup_title.add_theme_font_size_override("font_size", 18)
	_popup_title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.48, 1))
	text_box.add_child(_popup_title)

	_popup_message = Label.new()
	_popup_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_message.add_theme_font_size_override("font_size", 24)
	text_box.add_child(_popup_message)

	_popup_detail = Label.new()
	_popup_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_detail.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82, 1))
	text_box.add_child(_popup_detail)

	_popup_button = Button.new()
	_popup_button.text = "OK"
	_popup_button.custom_minimum_size = Vector2(108, 52)
	_popup_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_popup_button.pressed.connect(_close_popup)
	row.add_child(_popup_button)


func _on_popup_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _popup_layer and _popup_layer.visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		_close_popup()
		get_viewport().set_input_as_handled()


func _close_popup() -> void:
	if _popup_layer == null or not _popup_layer.visible:
		return
	_popup_layer.visible = false
	get_tree().paused = _previous_pause_state
	loot_popup_closed.emit()


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.045, 0.96)
	style.border_color = Color(0.24, 0.28, 0.38, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _make_icon_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.18, 1)
	style.border_color = Color(0.55, 0.46, 0.22, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _get_item_data(item_id: String) -> QuizRpgItemData:
	var inventory_service := _get_singleton("InventoryService")
	if inventory_service and inventory_service.has_method("get_item"):
		return inventory_service.call("get_item", item_id) as QuizRpgItemData
	return null


func _get_singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var singleton: Variant = core_manager.call("get_singleton", singleton_name)
		if singleton is Node:
			return singleton
	return get_node_or_null("/root/%s" % singleton_name)
