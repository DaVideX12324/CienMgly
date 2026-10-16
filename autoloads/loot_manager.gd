extends Node

signal loot_awarded(item_id: String, count: int)
signal loot_popup_closed

const BARREL_POPUP_HEIGHT := 228.0
const TOAST_SECONDS := 3.0
const MAX_TOASTS := 8

## Beczka: n-te losowanie udaje się z szansą min(1, scale / n), o ile udały się poprzednie (wzór usera 3 / (2n), czyli scale 1,5):
## 1. gwarantowane, 2. 75 %, 3. 50 %, 4. 37,5 %… (P(1 przedmiot) 25 %, 2: 37,5 %, 3: 23 %, 4: 10 %; średnio ≈ 2,3). Tail znika szybko,
## max_items to tylko zabezpieczenie. Rodzic beczek może podać własne wartości (metadane "barrel_loot").
var barrel_scale: float = 1.5
var barrel_max_items: int = 8
var _rng := RandomNumberGenerator.new()
var _popup_layer: CanvasLayer
var _popup_root: Control
var _popup_title: Label
var _popup_message: Label
var _popup_detail: Label
var _popup_button: Button
var _previous_pause_state: bool = false
var _toast_layer: CanvasLayer
var _toast_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


## Liczba losowań z beczki: n-te (n ≥ 2) wypada z szansą min(1, scale / n) pod warunkiem, że wypadły poprzednie; pierwsze zawsze
## (dla scale ≥ 1). Bez przekroczenia max_rolls.
func barrel_roll_count(scale: float, max_rolls: int) -> int:
	var n := 1
	while n < max_rolls and _rng.randf() < minf(1.0, scale / float(n + 1)):
		n += 1
	return n


## Przeszukanie beczki: liczba losowań z tabeli wg barrel_roll_count (ujemne wartości = domyślne z menedżera). Powtórzone
## przedmioty sumują się w liczbę kopii. found = coś wypadło; items = [{item_id, item_name, count}].
func search_barrel(scale: float = -1.0, max_items: int = -1) -> Dictionary:
	var s := barrel_scale if scale < 0.0 else scale
	var rolls := maxi(barrel_max_items if max_items < 0 else max_items, 1)
	var counts := {}
	for _k in range(barrel_roll_count(s, rolls)):
		var item_id := _roll_weighted_item_id(_get_barrel_loot_table())
		if item_id != "":
			counts[item_id] = int(counts.get(item_id, 0)) + _roll_item_count(item_id)
	var items: Array[Dictionary] = []
	for item_id: String in counts:
		var item_data := _get_item_data(item_id)
		_award_item(item_id, int(counts[item_id]))
		items.append({
			"item_id": item_id,
			"item_name": item_data.localized_name() if item_data != null else item_id,
			"count": int(counts[item_id]),
			"icon": item_data.icon if item_data != null else null,
		})
	return {"found": not items.is_empty(), "items": items}


## Powiadomienie o łupie bez pauzy i bez klikania: lista „ikona + nazwa ×liczba” w prawym dolnym rogu, znika po chwili.
func show_loot_toast(result: Dictionary) -> void:
	var items: Array = result.get("items", [])
	if items.is_empty():
		return
	_ensure_toasts()
	for entry: Dictionary in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = entry.get("icon") as Texture2D
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s ×%d" % [entry.get("item_name", "?"), int(entry.get("count", 1))]
		label.add_theme_font_size_override("font_size", QuizTheme.snap(24))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		_toast_box.add_child(row)
		while _toast_box.get_child_count() > MAX_TOASTS:
			_toast_box.get_child(0).queue_free()
			_toast_box.remove_child(_toast_box.get_child(0))
		var tween := row.create_tween()
		tween.tween_interval(TOAST_SECONDS)
		tween.tween_property(row, "modulate:a", 0.0, 0.6)
		tween.tween_callback(row.queue_free)


## Krótki komunikat tekstowy w tym samym stosie co łup (bez pauzy).
func show_message_toast(text: String) -> void:
	_ensure_toasts()
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", QuizTheme.snap(24))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_child(label)
	while _toast_box.get_child_count() > MAX_TOASTS:
		_toast_box.get_child(0).queue_free()
		_toast_box.remove_child(_toast_box.get_child(0))
	var tween := label.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _ensure_toasts() -> void:
	if _toast_layer:
		return
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "LootToastLayer"
	_toast_layer.layer = 39
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_layer)
	UiLayerScale.attach(_toast_layer)  # skala UI z opcji
	_toast_box = VBoxContainer.new()
	_toast_box.name = "Toasts"
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.offset_right = -24
	_toast_box.offset_bottom = -24
	_toast_layer.add_child(_toast_box)


func show_loot_popup(result: Dictionary) -> void:
	if not bool(result.get("found", false)):
		return
	_ensure_popup()
	_popup_title.text = QuizRpgI18n.t(str(result.get("title", "Loot")), str(result.get("title", QuizRpgI18n.t("loot.default_title", "Łup"))))
	_popup_message.text = str(result.get("message", ""))
	_popup_detail.text = QuizRpgI18n.t(str(result.get("detail", "")), str(result.get("detail", QuizRpgI18n.t("loot.continue_hint", "Naciśnij E albo Enter, aby kontynuować."))))
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
			return _rng.randi_range(1, 3)
		"ether", "focus_tonic", "antidote", "lockpick":
			return _rng.randi_range(1, 2)
		_:
			return 1


func _get_barrel_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "potion", "weight": 55},
		{"item_id": "ether", "weight": 25},
		{"item_id": "focus_tonic", "weight": 15},
		{"item_id": "antidote", "weight": 15},
		{"item_id": "lockpick", "weight": 30},
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
	UiLayerScale.attach(_popup_layer)  # skala UI z opcji

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
	icon_label.add_theme_font_size_override("font_size", QuizTheme.snap(40))
	icon_panel.add_child(icon_label)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 8)
	row.add_child(text_box)

	_popup_title = Label.new()
	_popup_title.add_theme_font_size_override("font_size", QuizTheme.snap(18))
	_popup_title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.48, 1))
	text_box.add_child(_popup_title)

	_popup_message = Label.new()
	_popup_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_message.add_theme_font_size_override("font_size", QuizTheme.snap(24))
	text_box.add_child(_popup_message)

	_popup_detail = Label.new()
	_popup_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_detail.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82, 1))
	text_box.add_child(_popup_detail)

	_popup_button = Button.new()
	_popup_button.text = QuizRpgI18n.t("ui.common.ok", "OK")
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
