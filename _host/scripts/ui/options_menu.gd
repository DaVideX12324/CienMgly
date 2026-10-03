extends CanvasLayer

signal closed

@onready var _btn_windowed: Button = $Panel/Margin/VBox/Tabs/Ekran/HBoxMode/BtnWindowed
@onready var _btn_borderless: Button = $Panel/Margin/VBox/Tabs/Ekran/HBoxMode/BtnBorderless
@onready var _btn_fullscreen: Button = $Panel/Margin/VBox/Tabs/Ekran/HBoxMode/BtnFullscreen
@onready var _res_option: OptionButton = $Panel/Margin/VBox/Tabs/Ekran/ResOption
@onready var _res_note: Label = $Panel/Margin/VBox/Tabs/Ekran/ResNote
@onready var _monitor_option: OptionButton = $Panel/Margin/VBox/Tabs/Ekran/MonitorOption
@onready var _scale_option: OptionButton = $Panel/Margin/VBox/Tabs/Ekran/ScaleOption
@onready var _quizless_mode: CheckButton = $Panel/Margin/VBox/Tabs/Ekran/QuizlessMode
@onready var _mode_label: Label = $Panel/Margin/VBox/Tabs/Ekran/ModeLabel
@onready var _monitor_label: Label = $Panel/Margin/VBox/Tabs/Ekran/MonitorLabel
@onready var _res_label: Label = $Panel/Margin/VBox/Tabs/Ekran/ResLabel
@onready var _scale_label: Label = $Panel/Margin/VBox/Tabs/Ekran/ScaleLabel

@onready var _slider_master: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/SliderMaster
@onready var _slider_music: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/SliderMusic
@onready var _slider_sfx: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/SliderSfx
@onready var _lbl_master: Label = $Panel/Margin/VBox/Tabs/Dzwiek/LblMaster
@onready var _lbl_music: Label = $Panel/Margin/VBox/Tabs/Dzwiek/LblMusic
@onready var _lbl_sfx: Label = $Panel/Margin/VBox/Tabs/Dzwiek/LblSfx

@onready var _skin_tab: VBoxContainer = $Panel/Margin/VBox/Tabs/Motyw
@onready var _skin_option: OptionButton = $Panel/Margin/VBox/Tabs/Motyw/SkinOption
@onready var _slider_brightness: HSlider = $Panel/Margin/VBox/Tabs/Motyw/SliderBrightness
@onready var _lbl_skin: Label = $Panel/Margin/VBox/Tabs/Motyw/LblSkin
@onready var _lbl_brightness: Label = $Panel/Margin/VBox/Tabs/Motyw/LblBrightness
@onready var _lbl_no_skins: Label = $Panel/Margin/VBox/Tabs/Motyw/LblNoSkins
@onready var _lbl_bars: Label = $Panel/Margin/VBox/Tabs/Motyw/LblBars
@onready var _bars_option: OptionButton = $Panel/Margin/VBox/Tabs/Motyw/BarsOption
@onready var _extra_options: VBoxContainer = $Panel/Margin/VBox/Tabs/Motyw/ExtraOptions

@onready var _sets_list: VBoxContainer = $Panel/Margin/VBox/Tabs/Pytania/SetsScroll/SetsList
@onready var _lbl_sets: Label = $Panel/Margin/VBox/Tabs/Pytania/LblSets
@onready var _lbl_sets_hint: Label = $Panel/Margin/VBox/Tabs/Pytania/LblSetsHint

@onready var _binds_list: VBoxContainer = $Panel/Margin/VBox/Tabs/Sterowanie/BindsScroll/BindsList
@onready var _lbl_info: Label = $Panel/Margin/VBox/Tabs/Sterowanie/LblInfo

@onready var _panel: PanelContainer = $Panel
@onready var _margin: MarginContainer = $Panel/Margin
@onready var _title_label: Label = $Panel/Margin/VBox/Title
@onready var _tabs: TabContainer = $Panel/Margin/VBox/Tabs
@onready var _btn_apply: Button = $Panel/Margin/VBox/HBoxButtons/BtnApply
@onready var _btn_close: Button = $Panel/Margin/VBox/HBoxButtons/BtnClose

@onready var _confirm_popup: PanelContainer = $ConfirmPopup
@onready var _lbl_countdown: Label = $ConfirmPopup/VBoxConfirm/LblCountdown
@onready var _lbl_question: Label = $ConfirmPopup/VBoxConfirm/LblQuestion
@onready var _btn_confirm: Button = $ConfirmPopup/VBoxConfirm/HBoxConfirm/BtnConfirm
@onready var _btn_revert: Button = $ConfirmPopup/VBoxConfirm/HBoxConfirm/BtnRevert

const CONFIRM_TIMEOUT := 20.0

const BASE_PANEL_HALF_W := 300.0
const BASE_PANEL_HALF_H := 360.0
const BASE_CONFIRM_HALF_W := 220.0
const BASE_CONFIRM_HALF_H := 100.0
const BASE_BTN_MODE_SIZE := Vector2(80.0, 36.0)
const BASE_BTN_ACTION_SIZE := Vector2(130.0, 40.0)
const BASE_BTN_CONFIRM_SIZE := Vector2(140.0, 40.0)
const BASE_PANEL_PADDING := 20

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

## Ustawienia motywu UI w ustawieniach aktywnego modułu (moduł czyta te same klucze).
const SKIN_KEY := "ui_skin"
const BRIGHTNESS_KEY := "ui_brightness"
const BAR_STYLE_KEY := "ui_bar_style"

var _mode_btns: Array[Button] = []
var _resolutions: Array[Vector2i] = []

var _sel_mode := WindowService.MODE_WINDOWED
var _sel_scale: int = UIScaleService.ScaleMode.NORMAL
var _scale_manually_changed := false
var _sel_quizless_mode := false

var _prev_mode := WindowService.MODE_WINDOWED
var _prev_res := Vector2i(1280, 720)
var _prev_monitor := 0
var _prev_scale: int = UIScaleService.ScaleMode.NORMAL
var _prev_scale_user_picked := false
var _prev_quizless_mode := false

var _skins: Array = []          # [{id, name}] z aktywnego modułu (get_ui_skins)
var _bar_styles: Array = []     # [{id, name}] z aktywnego modułu (get_ui_bar_styles), opcjonalnie
var _skin_module_id := ""
## Przechwytywanie klawisza w zakładce „Sterowanie”: {module, action, slot, button, text}; puste = nie.
var _capture: Dictionary = {}
var _syncing_skin := false

var _countdown := 0.0
var _confirming := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_mode_btns = [_btn_windowed, _btn_borderless, _btn_fullscreen]
	_btn_apply.pressed.connect(_on_apply)
	_btn_close.pressed.connect(_on_close)
	_btn_confirm.pressed.connect(_on_confirm)
	_btn_revert.pressed.connect(_on_revert)
	for index in range(_mode_btns.size()):
		var mode := index
		_mode_btns[index].pressed.connect(func(): _select_mode(mode))
	_populate_monitors()
	_monitor_option.item_selected.connect(_on_monitor_changed)
	_populate_resolutions(_monitor_option.selected)
	_populate_scale()
	_setup_audio_sliders()
	_skin_option.item_selected.connect(_on_skin_selected)
	_bars_option.item_selected.connect(_on_bar_style_selected)
	_slider_brightness.value_changed.connect(_on_brightness_changed)
	_populate_binds()
	UIScaleService.scale_changed.connect(_on_scale_changed)
	WindowService.resolution_changed.connect(func(_r: Vector2i) -> void: _on_scale_changed(UIScaleService.scale_factor))
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(func() -> void: _on_scale_changed(UIScaleService.scale_factor))
	_on_scale_changed(UIScaleService.scale_factor)


func _process(delta: float) -> void:
	if not _confirming:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_on_revert()
		return
	_lbl_countdown.text = "Przywrocenie za: %ds" % ceili(_countdown)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _capture.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		_capture_key(event as InputEventKey)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _confirming:
			_on_revert()
		else:
			_on_close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_prev_mode = WindowService.window_mode_idx
	_prev_res = WindowService.resolution
	_prev_monitor = WindowService.monitor_idx
	_prev_scale = UIScaleService.current_mode
	_prev_scale_user_picked = UIScaleService.user_picked
	_prev_quizless_mode = SettingsService.is_quizless_mode_enabled()
	_sel_mode = _prev_mode
	_sel_scale = _prev_scale
	_sel_quizless_mode = _prev_quizless_mode
	_scale_manually_changed = false
	_sync_mode_buttons()
	_monitor_option.selected = _prev_monitor
	_populate_resolutions(_prev_monitor)
	_sync_resolution()
	_sync_scale()
	_sync_quizless_mode()
	_sync_audio_sliders()
	_sync_skin_tab()
	_populate_question_sets()
	_populate_binds()  # aktywny moduł mógł się zmienić
	_on_scale_changed(UIScaleService.scale_factor)  # czcionka aktywnego modułu (mógł się zmienić)
	visible = true


func close() -> void:
	_on_close()


func _play_click() -> void:
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("click")


func _on_close() -> void:
	_play_click()
	if _confirming:
		_on_revert()
	else:
		hide()
		closed.emit()


func _select_mode(mode: int) -> void:
	_play_click()
	_sel_mode = mode
	_sync_mode_buttons()


func _sync_mode_buttons() -> void:
	for index in range(_mode_btns.size()):
		_mode_btns[index].button_pressed = index == _sel_mode
	_update_res_note()


func _sync_resolution() -> void:
	for index in range(_resolutions.size()):
		if _resolutions[index] == WindowService.resolution:
			_res_option.selected = index
			return
	_res_option.selected = 0


func _sync_scale() -> void:
	_scale_option.selected = UIScaleService.current_mode


func _populate_monitors() -> void:
	_monitor_option.clear()
	for index in range(DisplayServer.get_screen_count()):
		var size := DisplayServer.screen_get_size(index)
		var label := "Monitor %d (%d x %d)" % [index + 1, size.x, size.y]
		if index == DisplayServer.get_primary_screen():
			label += " [glowny]"
		_monitor_option.add_item(label)


func _on_monitor_changed(index: int) -> void:
	_populate_resolutions(index)
	_res_option.selected = max(0, _resolutions.size() - 1)


func _populate_resolutions(screen: int) -> void:
	_resolutions = WindowService.get_available_resolutions(screen)
	_res_option.clear()
	var screen_size := DisplayServer.screen_get_size(screen)
	for resolution in _resolutions:
		var label := "%d x %d" % [resolution.x, resolution.y]
		if resolution == screen_size:
			label += " (natywna)"
		_res_option.add_item(label)


func _populate_scale() -> void:
	_scale_option.clear()
	for label in UIScaleService.get_mode_labels():
		_scale_option.add_item(label)
	_sync_scale()
	if not _scale_option.item_selected.is_connected(_on_scale_item_selected):
		_scale_option.item_selected.connect(_on_scale_item_selected)
	if not _quizless_mode.toggled.is_connected(_on_quizless_toggled):
		_quizless_mode.toggled.connect(_on_quizless_toggled)


func _on_scale_item_selected(index: int) -> void:
	_sel_scale = index
	_scale_manually_changed = true


func _sync_quizless_mode() -> void:
	_quizless_mode.button_pressed = _sel_quizless_mode


func _on_quizless_toggled(enabled: bool) -> void:
	_sel_quizless_mode = enabled


func _update_res_note() -> void:
	_res_option.disabled = false
	_res_note.visible = false


func _setup_audio_sliders() -> void:
	_slider_master.value_changed.connect(func(value: float): _on_bus_changed(BUS_MASTER, value))
	_slider_music.value_changed.connect(func(value: float): _on_bus_changed(BUS_MUSIC, value))
	_slider_sfx.value_changed.connect(func(value: float): _on_bus_changed(BUS_SFX, value))


func _sync_audio_sliders() -> void:
	_slider_master.value = SettingsService.get_bus_volume(BUS_MASTER)
	_slider_music.value = SettingsService.get_bus_volume(BUS_MUSIC)
	_slider_sfx.value = SettingsService.get_bus_volume(BUS_SFX)


func _on_bus_changed(bus_name: String, value: float) -> void:
	SettingsService.set_bus_volume(bus_name, value, true)


## Zakładka „Motyw”: motywy aktywnego modułu (get_ui_skins); bez nich — informacja zamiast listy.
## Zmiana działa od razu i zapisuje się (jak głośność), moduł odświeża wygląd przez
## SettingsService.module_setting_changed.
func _sync_skin_tab() -> void:
	_syncing_skin = true
	_skins = []
	_skin_module_id = ""
	var core := get_node_or_null("/root/CoreManager")
	var module: Node = core.get_active_module() if core else null
	_bar_styles = []
	if module and module.has_method("get_ui_skins"):
		_skins = module.get_ui_skins()
		_skin_module_id = core.get_active_module_id()
		if module.has_method("get_ui_bar_styles"):
			_bar_styles = module.get_ui_bar_styles()
	var has_skins := not _skins.is_empty()
	for n: Control in [_lbl_skin, _skin_option, _lbl_brightness, _slider_brightness]:
		n.visible = has_skins
	_lbl_bars.visible = has_skins and not _bar_styles.is_empty()
	_bars_option.visible = _lbl_bars.visible
	_lbl_no_skins.visible = not has_skins
	_fill_option(_skin_option, _skins, SKIN_KEY)
	_fill_option(_bars_option, _bar_styles, BAR_STYLE_KEY)
	_build_extra_options(module if has_skins else null)
	var brightness := float(SettingsService.get_module(_skin_module_id, BRIGHTNESS_KEY, 1.0)) if has_skins else 1.0
	_slider_brightness.value = roundf(brightness * 100.0)
	_update_brightness_label()
	_syncing_skin = false


## Dodatkowe przełączniki wyglądu modułu (get_ui_options: [{key, label, type: "bool", default}]) —
## zapis w ustawieniach modułu, zmiana od razu (module_setting_changed).
func _build_extra_options(module: Node) -> void:
	for c in _extra_options.get_children():
		c.queue_free()
	if module == null or not module.has_method("get_ui_options"):
		return
	for opt in module.get_ui_options():
		if str(opt.get("type", "bool")) != "bool":
			continue
		var key := str(opt.get("key", ""))
		var cb := CheckBox.new()
		cb.text = str(opt.get("label", key))
		cb.button_pressed = bool(SettingsService.get_module(_skin_module_id, key, opt.get("default", false)))
		cb.add_theme_font_size_override("font_size", _fs(18))
		cb.toggled.connect(func(on: bool) -> void:
			_play_click()
			SettingsService.set_module(_skin_module_id, key, on))
		_extra_options.add_child(cb)


## Lista [{id, name}] w przycisku; zaznaczona pozycja z ustawień modułu (`key`), domyślnie pierwsza.
func _fill_option(option: OptionButton, entries: Array, key: String) -> void:
	option.clear()
	if entries.is_empty():
		return
	var current := str(SettingsService.get_module(_skin_module_id, key, ""))
	for i in range(entries.size()):
		option.add_item(str(entries[i].get("name", entries[i].get("id", "?"))))
		if str(entries[i].get("id", "")) == current:
			option.selected = i
	if option.selected < 0:
		option.selected = 0


func _on_bar_style_selected(index: int) -> void:
	if _syncing_skin or index < 0 or index >= _bar_styles.size():
		return
	_play_click()
	SettingsService.set_module(_skin_module_id, BAR_STYLE_KEY, str(_bar_styles[index].get("id", "")))


func _on_skin_selected(index: int) -> void:
	if _syncing_skin or index < 0 or index >= _skins.size():
		return
	_play_click()
	SettingsService.set_module(_skin_module_id, SKIN_KEY, str(_skins[index].get("id", "")))


func _on_brightness_changed(value: float) -> void:
	_update_brightness_label()
	if _syncing_skin or _skin_module_id == "":
		return
	SettingsService.set_module(_skin_module_id, BRIGHTNESS_KEY, value / 100.0)


func _update_brightness_label() -> void:
	_lbl_brightness.text = "Jasnosc motywu: %d%%" % roundi(_slider_brightness.value)


## Zakładka „Pytania”: zestawy (QuestionBank) z zaznaczeniem — aktywne trafiają do puli pytań w grze
## (globalnie). Zmiana od razu: zapis wyboru + QuizService.reload_all().
func _populate_question_sets() -> void:
	for child in _sets_list.get_children():
		child.queue_free()
	var sel := QuestionBank.load_selection()
	for s in QuestionBank.list_sets():
		var id := str(s["id"])
		var cb := CheckBox.new()
		var count := (s["questions"] as Array).size()
		var tag: String = {"builtin": "", "edited": "  (edytowany)", "user": "  (wlasny)"}.get(str(s["source"]), "")
		cb.text = "%s  —  %d pytan%s" % [s["name"], count, tag]
		cb.button_pressed = QuestionBank.is_set_enabled(id, sel)
		cb.add_theme_font_size_override("font_size", _fs(18))
		cb.toggled.connect(func(on: bool) -> void:
			QuestionBank.set_set_enabled(id, on)
			QuizService.reload_all())
		_sets_list.add_child(cb)


## Zakładka „Sterowanie”: sekcje z manifestów modułów (pole "controls": [{label, actions, keys}], opcjonalnie
## "action_labels": {akcja: nazwa}). W menu głównym — wszystkie moduły pod ich nazwami, w trakcie gry — tylko
## aktywny moduł. Każda akcja ma InputBinds.SLOTS pola: klik -> „Naciśnij klawisz…” (Esc anuluje, Backspace
## czyści pole). Klawisz zajęty przez inną akcję tego samego modułu przechodzi do nowej (decyzja usera
## 2026-10-03). Sekcja bez akcji (sam opis "keys") — tylko tekst. Zapis: InputBinds.save_module.
func _populate_binds() -> void:
	_capture = {}
	for child in _binds_list.get_children():
		child.queue_free()
	var core := get_node_or_null("/root/CoreManager")
	var active_id: String = core.get_active_module_id() if core else ""
	var manifests: Array = []
	for m in ModuleRegistry.all():
		var id := str(m.get("id", ""))
		if id.begins_with("_") or not (m.get("controls", []) is Array) or (m.get("controls", []) as Array).is_empty():
			continue
		if active_id != "" and id != active_id:
			continue
		manifests.append(m)
	if manifests.is_empty():
		_lbl_info.text = "Ten tryb nie opisuje sterowania." if active_id != "" else "Brak opisu sterowania w modułach."
		return
	if active_id != "":
		_lbl_info.text = "Sterowanie: %s — kliknij pole, by zmienić klawisz." % str(manifests[0].get("name", active_id))
	else:
		_lbl_info.text = "Sterowanie w poszczególnych grach — kliknij pole, by zmienić klawisz."
	for m in manifests:
		var module_id := str(m.get("id", ""))
		if active_id == "":
			var header := Label.new()
			header.text = str(m.get("name", module_id))
			header.add_theme_font_size_override("font_size", _fs(18))
			header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			header.set_meta(&"bind_size", 18)
			_binds_list.add_child(header)
		for entry in m["controls"]:
			if not (entry is Dictionary):
				continue
			var lbl_sec := Label.new()
			lbl_sec.text = str(entry.get("label", ""))
			lbl_sec.add_theme_font_size_override("font_size", _fs(14))
			lbl_sec.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
			lbl_sec.set_meta(&"bind_size", 14)
			_binds_list.add_child(lbl_sec)
			var actions: Array = entry.get("actions", []) if entry.get("actions", []) is Array else []
			if actions.is_empty():
				var lbl_keys := Label.new()
				lbl_keys.text = "  " + str(entry.get("keys", "(brak)"))
				lbl_keys.add_theme_font_size_override("font_size", _fs(13))
				lbl_keys.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
				lbl_keys.set_meta(&"bind_size", 13)
				_binds_list.add_child(lbl_keys)
				continue
			for action in actions:
				_binds_list.add_child(_bind_row(module_id, str(action)))
		var btn_reset := Button.new()
		btn_reset.text = "Przywróć domyślne"
		btn_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn_reset.add_theme_font_size_override("font_size", _fs(13))
		btn_reset.set_meta(&"bind_size", 13)
		btn_reset.pressed.connect(_reset_binds.bind(module_id))
		_binds_list.add_child(btn_reset)


## Wiersz akcji: nazwa + InputBinds.SLOTS pól z klawiszami.
func _bind_row(module_id: String, action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "  " + _action_label(module_id, action)
	lbl.custom_minimum_size = Vector2(UIScaleService.px(180), 0)
	lbl.add_theme_font_size_override("font_size", _fs(13))
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.set_meta(&"bind_size", 13)
	row.add_child(lbl)
	var keys := InputBinds.get_keys(action)
	for slot in InputBinds.SLOTS:
		var btn := Button.new()
		btn.text = InputBinds.key_name(keys[slot]) if slot < keys.size() else "—"
		btn.custom_minimum_size = Vector2(UIScaleService.px(120), 0)
		btn.clip_text = true  # stała szerokość pola także przy „Naciśnij…”
		btn.add_theme_font_size_override("font_size", _fs(13))
		btn.set_meta(&"bind_size", 13)
		btn.pressed.connect(_start_capture.bind(module_id, action, slot, btn))
		row.add_child(btn)
	return row


func _start_capture(module_id: String, action: String, slot: int, btn: Button) -> void:
	_play_click()
	if not _capture.is_empty() and is_instance_valid(_capture.button):
		(_capture.button as Button).text = _capture.text
	_capture = {"module": module_id, "action": action, "slot": slot, "button": btn, "text": btn.text}
	btn.text = "Naciśnij…"
	_lbl_info.text = "„%s”: naciśnij klawisz (Esc — anuluj, Backspace — usuń klawisz z pola)." % _action_label(module_id, action)


## Klawisz naciśnięty w trybie przechwytywania (z _input, przed obsługą Esc okna).
func _capture_key(event: InputEventKey) -> void:
	var module_id: String = _capture.module
	var action: String = _capture.action
	var slot: int = _capture.slot
	_capture = {}
	var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if code == KEY_ESCAPE:
		_populate_binds()
		return
	var keys := InputBinds.get_keys(action)
	var moved_from := ""
	if code == KEY_BACKSPACE:
		if slot < keys.size():
			keys.remove_at(slot)
	else:
		for other in _module_actions(module_id):
			if other == action:
				continue
			var other_keys := InputBinds.get_keys(other)
			if other_keys.has(code):
				other_keys.erase(code)
				InputBinds.set_keys(other, other_keys)
				moved_from = _action_label(module_id, other)
		var old_at_slot: int = keys[slot] if slot < keys.size() else KEY_NONE
		keys.erase(code)
		if old_at_slot != KEY_NONE and keys.has(old_at_slot):
			keys[keys.find(old_at_slot)] = code
		else:
			keys.append(code)
		keys = keys.slice(0, InputBinds.SLOTS)
	InputBinds.set_keys(action, keys)
	InputBinds.save_module(SettingsService, module_id, _module_actions(module_id))
	_play_click()
	_populate_binds()
	if moved_from != "":
		_lbl_info.text = "Klawisz %s zabrany akcji „%s”." % [InputBinds.key_name(code), moved_from]


func _reset_binds(module_id: String) -> void:
	_play_click()
	InputBinds.reset_module(SettingsService, module_id, _module_actions(module_id))
	_populate_binds()


## Wszystkie akcje z sekcji sterowania modułu.
func _module_actions(module_id: String) -> Array:
	var out: Array = []
	for entry in ModuleRegistry.get_by_id(module_id).get("controls", []):
		var actions: Variant = (entry as Dictionary).get("actions", []) if entry is Dictionary else []
		if actions is Array:
			for action in actions:
				if not out.has(str(action)):
					out.append(str(action))
	return out


## Nazwa akcji z "action_labels" manifestu, inaczej jej id.
func _action_label(module_id: String, action: String) -> String:
	var labels: Variant = ModuleRegistry.get_by_id(module_id).get("action_labels", {})
	return str(labels.get(action, action)) if labels is Dictionary else action


func _on_apply() -> void:
	_play_click()
	var resolution_index := _res_option.selected
	var resolution := WindowService.resolution
	if resolution_index >= 0 and resolution_index < _resolutions.size():
		resolution = _resolutions[resolution_index]
	if _scale_manually_changed:
		UIScaleService.set_mode(_sel_scale)
	else:
		if not _prev_scale_user_picked:
			UIScaleService.reset_to_auto()
	SettingsService.set_quizless_mode_enabled(_sel_quizless_mode, false)
	SettingsService.apply_settings(_sel_mode, resolution, _monitor_option.selected)
	_start_confirm()


func _start_confirm() -> void:
	_countdown = CONFIRM_TIMEOUT
	_confirming = true
	_confirm_popup.visible = true
	_lbl_countdown.text = "Przywrocenie za: %ds" % ceili(_countdown)


func _on_confirm() -> void:
	_play_click()
	_confirming = false
	_confirm_popup.visible = false
	hide()


func _on_revert() -> void:
	_play_click()
	_confirming = false
	_confirm_popup.visible = false
	_scale_manually_changed = false
	if _prev_scale_user_picked:
		UIScaleService.set_mode(_prev_scale)
	else:
		UIScaleService.reset_to_auto()
	SettingsService.set_quizless_mode_enabled(_prev_quizless_mode, false)
	SettingsService.apply_settings(_prev_mode, _prev_res, _prev_monitor)
	_sel_mode = _prev_mode
	_sel_scale = _prev_scale
	_sel_quizless_mode = _prev_quizless_mode
	_sync_mode_buttons()
	_monitor_option.selected = _prev_monitor
	_populate_resolutions(_prev_monitor)
	_sync_resolution()
	_sync_scale()
	_sync_quizless_mode()
	_sync_audio_sliders()


func _on_scale_changed(_scale: float) -> void:
	var main_size := _fs(18)
	_title_label.add_theme_font_size_override("font_size", _fs(26))
	_tabs.add_theme_font_size_override("font_size", _fs(17))
	_mode_label.add_theme_font_size_override("font_size", main_size)
	_monitor_label.add_theme_font_size_override("font_size", main_size)
	_res_label.add_theme_font_size_override("font_size", main_size)
	_res_note.add_theme_font_size_override("font_size", _fs(15))
	_scale_label.add_theme_font_size_override("font_size", main_size)
	_quizless_mode.add_theme_font_size_override("font_size", main_size)
	_monitor_option.add_theme_font_size_override("font_size", main_size)
	_res_option.add_theme_font_size_override("font_size", main_size)
	_scale_option.add_theme_font_size_override("font_size", main_size)
	_scale_popup_font(_monitor_option, main_size)
	_scale_popup_font(_res_option, main_size)
	_scale_popup_font(_scale_option, main_size)
	_lbl_master.add_theme_font_size_override("font_size", main_size)
	_lbl_music.add_theme_font_size_override("font_size", main_size)
	_lbl_sfx.add_theme_font_size_override("font_size", main_size)
	_lbl_skin.add_theme_font_size_override("font_size", main_size)
	_lbl_brightness.add_theme_font_size_override("font_size", main_size)
	_lbl_no_skins.add_theme_font_size_override("font_size", _fs(14))
	_skin_option.add_theme_font_size_override("font_size", main_size)
	_scale_popup_font(_skin_option, main_size)
	_lbl_bars.add_theme_font_size_override("font_size", main_size)
	_bars_option.add_theme_font_size_override("font_size", main_size)
	_scale_popup_font(_bars_option, main_size)
	_lbl_info.add_theme_font_size_override("font_size", _fs(14))
	_lbl_sets.add_theme_font_size_override("font_size", main_size)
	_lbl_sets_hint.add_theme_font_size_override("font_size", _fs(14))
	for child in _sets_list.get_children():
		if child is CheckBox:
			child.add_theme_font_size_override("font_size", main_size)
	_lbl_info.custom_minimum_size = Vector2(UIScaleService.px(200), 0)
	for node in _binds_list.find_children("*", "Control", true, false):
		if node.has_meta(&"bind_size"):
			node.add_theme_font_size_override("font_size", _fs(int(node.get_meta(&"bind_size"))))
	_btn_apply.add_theme_font_size_override("font_size", _fs(18))
	_btn_close.add_theme_font_size_override("font_size", _fs(18))
	_lbl_question.add_theme_font_size_override("font_size", _fs(18))
	_lbl_question.custom_minimum_size = Vector2(UIScaleService.px(220), 0)
	_lbl_countdown.add_theme_font_size_override("font_size", _fs(18))
	_btn_confirm.add_theme_font_size_override("font_size", _fs(18))
	_btn_revert.add_theme_font_size_override("font_size", _fs(18))
	var mode_font_size := _fs(15)
	for button in _mode_btns:
		button.add_theme_font_size_override("font_size", mode_font_size)
		button.custom_minimum_size = UIScaleService.sz2(BASE_BTN_MODE_SIZE.x, BASE_BTN_MODE_SIZE.y)
	_btn_apply.custom_minimum_size = UIScaleService.sz2(BASE_BTN_ACTION_SIZE.x, BASE_BTN_ACTION_SIZE.y)
	_btn_close.custom_minimum_size = UIScaleService.sz2(BASE_BTN_ACTION_SIZE.x, BASE_BTN_ACTION_SIZE.y)
	_btn_confirm.custom_minimum_size = UIScaleService.sz2(BASE_BTN_CONFIRM_SIZE.x, BASE_BTN_CONFIRM_SIZE.y)
	_btn_revert.custom_minimum_size = UIScaleService.sz2(BASE_BTN_CONFIRM_SIZE.x, BASE_BTN_CONFIRM_SIZE.y)

	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1920, 1080)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(WindowService.resolution)
	var max_half_w: float = maxf(160.0, (vp_size.x - 24.0) * 0.5)
	var max_half_h: float = maxf(180.0, (vp_size.y - 24.0) * 0.5)
	var panel_half_w: float = minf(UIScaleService.sz(BASE_PANEL_HALF_W), max_half_w)
	var panel_half_h: float = minf(UIScaleService.sz(BASE_PANEL_HALF_H), max_half_h)
	_panel.offset_left = -panel_half_w
	_panel.offset_top = -panel_half_h
	_panel.offset_right = panel_half_w
	_panel.offset_bottom = panel_half_h
	var confirm_half_w: float = minf(UIScaleService.sz(BASE_CONFIRM_HALF_W), max_half_w)
	var confirm_half_h: float = minf(UIScaleService.sz(BASE_CONFIRM_HALF_H), max_half_h)
	_confirm_popup.offset_left = -confirm_half_w
	_confirm_popup.offset_top = -confirm_half_h
	_confirm_popup.offset_right = confirm_half_w
	_confirm_popup.offset_bottom = confirm_half_h
	var pad := mini(UIScaleService.px(BASE_PANEL_PADDING), int(panel_half_h * 0.1))
	pad = maxi(pad, 8)
	_margin.add_theme_constant_override("margin_left", pad)
	_margin.add_theme_constant_override("margin_top", pad)
	_margin.add_theme_constant_override("margin_right", pad)
	_margin.add_theme_constant_override("margin_bottom", pad)


## Rozmiar tekstu: skala UI, a gdy aktywny moduł ma własną czcionkę (np. pikselową) — dopasowanie
## do niej (snap_font_size modułu; quiz_rpg: siatka pikseli Jersey 15).
func _fs(base: int) -> int:
	var size := UIScaleService.px(base)
	var core := get_node_or_null("/root/CoreManager")
	var module: Node = core.get_active_module() if core else null
	if module and module.has_method("snap_font_size"):
		return int(module.snap_font_size(size))
	return size


func _scale_popup_font(option: OptionButton, font_size: int) -> void:
	option.get_popup().add_theme_font_size_override("font_size", font_size)
