extends CanvasLayer

## Main menu for res://modules/quiz_rpg/scenes/ui/main_menu.tscn.

const SaveSlotsPanelScene = preload("../../scenes/ui/save_slots_panel.tscn")
const SaveSlotRowScene = preload("../../scenes/ui/save_slot_row.tscn")
const SaveSlotAddScene = preload("../../scenes/ui/save_slot_add.tscn")
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

## Menu na środku; „Wczytaj grę”, „Statystyki” i „Opcje” otwierają osobny ekran na całe okno (menu znika,
## Esc wraca) — jak w FNaFB („Load which file?”), prośba usera 2026-10-04.
@onready var new_game_btn: Button = $Center/Panel/Margin/VBox/BtnNewGame
@onready var load_game_btn: Button = $Center/Panel/Margin/VBox/BtnLoadGame
@onready var stats_btn: Button = $Center/Panel/Margin/VBox/BtnStats
@onready var options_btn: Button = $Center/Panel/Margin/VBox/BtnOptions
@onready var quit_btn: Button = $Center/Panel/Margin/VBox/BtnQuit
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var right_panel: PanelContainer = $ScreenPanel
@onready var menu_center: CenterContainer = $Center
@onready var context_title: Label = $ScreenPanel/Margin/RightVBox/ContextTitle
@onready var context_body: MarginContainer = $ScreenPanel/Margin/RightVBox/ContextBody
@onready var stats_label: Label = $ScreenPanel/Margin/RightVBox/ContextBody/StatsLabel
@onready var background: ColorRect = $BG
@onready var ver_label: Label = $VerLabel
@onready var name_entry: VBoxContainer = $ScreenPanel/Margin/RightVBox/ContextBody/NameEntry

var _title_time := 0.0
var _save_slots_panel: VBoxContainer
var _save_slots_list: VBoxContainer
## Treść prawego panelu: "" (ukryty), "load", "stats", "options", "name" (imię bohatera przed nową grą).
var _context := ""
var _slot_mode: String = "load"
var _options_menu: CanvasLayer = null
static var HOST_OPTIONS_MENU_SCENE: String = QuizRpgPaths.host("res://scenes/ui/options_menu.tscn")
const MAX_MENU_SAVE_SLOTS := 20
## Kursor menu (jak walka / pauza): W / S / strzałki, Enter / Z / spacja, mysz przesuwa kursor; prowadzi go ten skrypt,
## nie fokus Godota.
var _menu_buttons: Array[Button] = []
var _cursor := 0
## Ekrany treści (zapisy, opcje, statystyki, imię) chodzą na fokusie Godota (strzałki / Enter / Esc); WASD / Z / X
## zamieniane na te akcje — poza polem tekstowym, gdzie to zwykłe litery.
const KEY_AS_UI_ACTION := {KEY_W: &"ui_up", KEY_S: &"ui_down", KEY_A: &"ui_left", KEY_D: &"ui_right",
	KEY_Z: &"ui_accept", KEY_X: &"ui_cancel"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiLayerScale.attach(self)  # skala UI z opcji na całą warstwę
	_connect_buttons()
	_setup_menu_cursor()
	_build_save_slots_panel()
	_update_load_button()
	_style_menu()
	_show_context("")
	ver_label.text = "Cień Mgły " + _version_label()
	# Muzyka menu także po powrocie z gry („Zakończ grę” w menu Esc) — poziom zostawiał swoją.
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_music"):
		audio.play_music("menu")


## Wersja z module_manifest.json do wyświetlenia: "0.8.0-alpha" -> "0.8.0 Alpha" (zasady wersjonowania: docs hosta).
func _version_label() -> String:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(QuizRpgPaths.path("module_manifest.json")))
	var version := str(manifest.get("version", "")) if manifest is Dictionary else ""
	var parts := version.split("-", true, 1)
	if parts.size() < 2:
		return version
	var stage := parts[1]
	stage = "RC" + stage.substr(2) if stage.begins_with("rc") else stage.left(1).to_upper() + stage.substr(1)
	return "%s %s" % [parts[0], stage]


func _process(delta: float) -> void:
	_title_time += delta
	var scale_factor := 1.0 + sin(_title_time * 1.5) * 0.02
	title_label.scale = Vector2(scale_factor, scale_factor)


func _connect_buttons() -> void:
	if not new_game_btn.pressed.is_connected(_on_new_game):
		new_game_btn.pressed.connect(_on_new_game)
	name_entry.confirmed.connect(_start_new_game)
	name_entry.cancelled.connect(func() -> void:
		_play_click()
		_show_context(""))
	if not load_game_btn.pressed.is_connected(_on_load_game):
		load_game_btn.pressed.connect(_on_load_game)
	if not stats_btn.pressed.is_connected(_on_stats):
		stats_btn.pressed.connect(_on_stats)
	if not options_btn.pressed.is_connected(_on_options):
		options_btn.pressed.connect(_on_options)
	if not quit_btn.pressed.is_connected(_on_quit):
		quit_btn.pressed.connect(_on_quit)
	for btn: Button in [new_game_btn, load_game_btn, stats_btn, options_btn, quit_btn]:
		_add_click_sfx(btn)
	var save_manager := _get_module_singleton("SaveManager")
	if save_manager and save_manager.has_signal("save_slots_changed"):
		var slots_changed_callable := Callable(self, "_on_save_slots_changed")
		if not save_manager.is_connected("save_slots_changed", slots_changed_callable):
			save_manager.connect("save_slots_changed", slots_changed_callable)


func _update_load_button() -> void:
	var save_manager := _get_save_manager()
	load_game_btn.disabled = not bool(save_manager.call("has_any_save")) if save_manager and save_manager.has_method("has_any_save") else true


func _style_menu() -> void:
	title_label.pivot_offset = title_label.size / 2.0


## Dźwięk kliknięcia przy naciśnięciu (myszą albo Enter / Spacją) — jak w menu głównym hosta.
func _add_click_sfx(btn: Button) -> void:
	if not btn.pressed.is_connected(_play_click):
		btn.pressed.connect(_play_click)


func _play_click() -> void:
	var audio := get_node_or_null("/root/AudioService")
	if audio and audio.has_method("play_sfx_by_name"):
		audio.play_sfx_by_name("click")


## „Nowa gra” — najpierw imię bohatera (NameEntry); start po jego zatwierdzeniu.
func _on_new_game() -> void:
	if _context == "name":
		_show_context("")
		return
	context_title.text = QuizRpgI18n.t("main_menu.title_new_game", "Nowa gra")
	_show_context("name")
	name_entry.open()


func _start_new_game(player_name: String) -> void:
	_play_click()
	var save_manager := _get_save_manager()
	if save_manager and save_manager.has_method("start_new_game"):
		save_manager.call("start_new_game", 0, player_name)
		return
	var gm := _get_module_singleton("GameManager")
	if gm and gm.has_method("new_game"):
		gm.call("new_game", 0, player_name)
	else:
		push_warning("MainMenu: GameManager unavailable, cannot start new game.")


func _on_load_game() -> void:
	_slot_mode = "load"
	_show_save_slots(QuizRpgI18n.t("main_menu.load_game_title", "Wczytaj grę"))


func _on_stats() -> void:
	if _context == "stats":
		_show_context("")
		return
	_populate_stats()
	_show_context("stats")
	context_title.text = QuizRpgI18n.t("main_menu.title_stats", "Statystyki")


## Opcje hosta (ekran, dźwięk, motyw, sterowanie) na ekranie treści — ta sama treść co w menu Esc.
func _on_options() -> void:
	if _context == "options":
		_options_menu.call("close")
		return
	if _options_menu == null or not is_instance_valid(_options_menu):
		if not ResourceLoader.exists(HOST_OPTIONS_MENU_SCENE):
			push_warning("MainMenu: brak okna opcji %s" % HOST_OPTIONS_MENU_SCENE)
			return
		_options_menu = (load(HOST_OPTIONS_MENU_SCENE) as PackedScene).instantiate() as CanvasLayer
		_options_menu.layer = layer + 5
		add_child(_options_menu)
		if _options_menu.has_method("embed_in"):
			_options_menu.call("embed_in", context_body)
		if _options_menu.has_signal("closed"):
			_options_menu.connect("closed", func() -> void:
				if _context == "options":
					_show_context(""))
	_show_context("options")
	context_title.text = QuizRpgI18n.t("main_menu.title_options", "Opcje")
	if _options_menu.has_method("open"):
		_options_menu.call("open")
	else:
		_options_menu.visible = true
	# Fokus na zakładkach (lewo / prawo zmienia zakładkę, dół wchodzi w opcje).
	var tabs := context_body.find_children("*", "TabContainer", true, false)
	if not tabs.is_empty():
		(tabs[0] as TabContainer).get_tab_bar().grab_focus.call_deferred()


## Ekran treści: kind "" = menu; inaczej ekran na całe okno z tą treścią (sloty / statystyki / opcje).
func _show_context(kind: String) -> void:
	_context = kind
	right_panel.visible = kind != ""
	menu_center.visible = kind == ""
	stats_label.visible = kind == "stats"
	name_entry.visible = kind == "name"
	if _save_slots_panel:
		_save_slots_panel.visible = kind == "load"
	if kind != "options" and _options_menu != null and is_instance_valid(_options_menu):
		_options_menu.visible = false
	if kind == "":
		get_viewport().gui_release_focus()  # fokus ze schowanego ekranu nie przejmuje Enter w menu
		_update_load_button()
		_move_cursor(0)


func _setup_menu_cursor() -> void:
	_menu_buttons = [new_game_btn, load_game_btn, stats_btn, options_btn, quit_btn]
	for i in _menu_buttons.size():
		var btn := _menu_buttons[i]
		btn.focus_mode = Control.FOCUS_NONE
		for st: StringName in [&"normal", &"hover", &"pressed"]:
			btn.set_meta(&"menu_" + st, btn.get_theme_stylebox(st))
		for fc: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			btn.set_meta(&"menu_" + fc, btn.get_theme_color(fc))
		btn.mouse_entered.connect(func() -> void:
			if not btn.disabled:
				_set_cursor(i))
	_set_cursor(0)


## Wybrana pozycja: własny styl hover przycisku z obwódką w kolorze tekstu; reszta w stylu normal (mysz nie podświetla
## drugiej pozycji — kursor idzie za myszą).
func _set_cursor(index: int) -> void:
	_cursor = index
	for i in _menu_buttons.size():
		var btn := _menu_buttons[i]
		var on := i == _cursor
		var sb: StyleBox = btn.get_meta(&"menu_hover" if on else &"menu_normal")
		if on:
			sb = _cursor_style(sb, btn.get_meta(&"menu_font_hover_color"))
		for st: StringName in [&"normal", &"hover", &"pressed"]:
			btn.add_theme_stylebox_override(st, btn.get_meta(&"menu_pressed") if on and st == &"pressed" else sb)
		var font: Color = btn.get_meta(&"menu_font_hover_color" if on else &"menu_font_color")
		for fc: StringName in [&"font_color", &"font_hover_color"]:
			btn.add_theme_color_override(fc, font)


## Kopia stylu z obwódką 2 px (bez obwódki styl nie-płaski zostaje bez zmian).
func _cursor_style(base: StyleBox, color: Color) -> StyleBox:
	if not (base is StyleBoxFlat):
		return base
	if not base.has_meta(&"menu_cursor"):
		var sb := (base as StyleBoxFlat).duplicate() as StyleBoxFlat
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:  # obwódka nie przesuwa tekstu
			sb.set_content_margin(side, base.get_content_margin(side))
		sb.set_border_width_all(2)
		sb.border_color = color
		base.set_meta(&"menu_cursor", sb)
	return base.get_meta(&"menu_cursor")


## Kursor o `step` pozycji z zawinięciem, z pominięciem wyłączonych (np. „Wczytaj grę” bez zapisów); 0 = zostaje,
## chyba że bieżąca pozycja jest wyłączona.
func _move_cursor(step: int) -> void:
	var n := _menu_buttons.size()
	if n == 0:
		return
	var dir := step if step != 0 else 1
	var start := _cursor + step
	for k in n:
		var i := posmod(start + dir * k, n)
		if not _menu_buttons[i].disabled:
			_set_cursor(i)
			return


## Esc wraca do menu (opcje obsługują Esc same i zamykają ekran sygnałem closed).
func _unhandled_input(event: InputEvent) -> void:
	if _context == "":
		_handle_menu_input(event)
		return
	if _forward_key_as_ui_action(event):
		get_viewport().set_input_as_handled()
		return
	if _context != "options" and event.is_action_pressed("ui_cancel"):
		_play_click()
		_show_context("")
		get_viewport().set_input_as_handled()


## WASD / Z / X w ekranie treści -> akcja ui_* (nawigacja fokusu, suwaki, listy, Enter, Esc jak ze strzałek).
func _forward_key_as_ui_action(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not KEY_AS_UI_ACTION.has(key.keycode):
		return false
	var owner := get_viewport().gui_get_focus_owner()
	if owner is LineEdit or owner is TextEdit:
		return false
	var action := InputEventAction.new()
	action.action = KEY_AS_UI_ACTION[key.keycode]
	action.pressed = key.pressed
	Input.parse_input_event(action)
	return true


## Pierwszy włączony przycisk pod `root` dostaje fokus (wejście do ekranu treści z klawiatury).
func _focus_first_button(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		var btn := node as BaseButton
		if btn.is_visible_in_tree() and not btn.disabled and btn.focus_mode != Control.FOCUS_NONE:
			btn.grab_focus()
			return


func _handle_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or _is_key_pressed(event, [KEY_W]):
		_move_cursor(-1)
	elif event.is_action_pressed("ui_down") or _is_key_pressed(event, [KEY_S]):
		_move_cursor(1)
	elif event.is_action_pressed("ui_accept") or _is_key_pressed(event, [KEY_Z]):
		var btn := _menu_buttons[_cursor]
		if btn.disabled:
			return
		btn.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _is_key_pressed(event: InputEvent, keys: Array[int]) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and int(key_event.keycode) in keys


func _build_save_slots_panel() -> void:
	if _save_slots_panel:
		return
	_save_slots_panel = SaveSlotsPanelScene.instantiate() as VBoxContainer
	context_body.add_child(_save_slots_panel)
	var hint := _save_slots_panel.get_node("Hint") as Label
	hint.text = QuizRpgI18n.t("main_menu.save_hint", hint.text)
	_save_slots_list = _save_slots_panel.get_node("Scroll/List") as VBoxContainer


func _show_save_slots(title: String) -> void:
	if _context == "load":
		_show_context("")
		return
	context_title.text = title
	_show_context("load")
	_populate_save_slots()


func _hide_save_slots() -> void:
	_show_context("")


func _populate_save_slots() -> void:
	if not _save_slots_list:
		return
	for child in _save_slots_list.get_children():
		child.queue_free()

	var save_manager := _get_save_manager()
	if save_manager == null:
		_add_message_row("SaveManager niedostepny.")
		return

	var summaries_value: Variant = save_manager.call("get_save_slots_summary")
	var summaries: Array = summaries_value if summaries_value is Array else []
	for summary_value: Variant in summaries:
		if summary_value is Dictionary:
			_save_slots_list.add_child(_create_slot_row(summary_value))

	if int(save_manager.call("get_slot_count")) < MAX_MENU_SAVE_SLOTS:
		var add_btn := SaveSlotAddScene.instantiate() as Button
		add_btn.pressed.connect(_on_add_slot_pressed)
		_add_click_sfx(add_btn)
		_save_slots_list.add_child(add_btn)
	if _context == "load":
		_focus_first_button.call_deferred(_save_slots_list)


## Wiersz zapisu: cały zapis to jeden przycisk (klik = wczytanie), z boku mała ikona kosza (drugi klik potwierdza usunięcie).
func _create_slot_row(slot_summary: Dictionary) -> Control:
	var slot_index := int(slot_summary.get("slot_index", 0))
	var exists := bool(slot_summary.get("exists", false))
	var row := SaveSlotRowScene.instantiate() as HBoxContainer
	var slot_btn := row.get_node("SlotButton") as Button
	slot_btn.disabled = _slot_mode == "load" and not exists
	# slot jak okno motywu, najechany / z fokusem — zaznaczenie motywu
	var window_sb := QuizTheme.theme().get_stylebox(&"panel", QuizTheme.WINDOW)
	var selected_sb := QuizTheme.theme().get_stylebox(&"selected", QuizTheme.MENU_ITEM)
	for st in ["normal", "pressed", "disabled"]:
		slot_btn.add_theme_stylebox_override(st, window_sb)
	for st in ["hover", "focus"]:
		slot_btn.add_theme_stylebox_override(st, selected_sb)
	slot_btn.pressed.connect(func() -> void: _on_slot_action_pressed(slot_index))
	_add_click_sfx(slot_btn)
	var text := "SlotButton/Margin/Text/"
	(row.get_node(text + "Title") as Label).text = "%s - %s" % [str(slot_summary.get("slot_name", "Slot")), str(slot_summary.get("title", ""))]
	(row.get_node(text + "Subtitle") as Label).text = str(slot_summary.get("subtitle", ""))
	(row.get_node(text + "Detail") as Label).text = str(slot_summary.get("detail", ""))
	var trash := row.get_node("Trash") as Button
	if exists:
		_setup_trash_button(trash, slot_index)
	else:
		trash.queue_free()
		row.get_node("Spacer").visible = true
	return row


## Kosz z boku wiersza: pierwszy klik zaznacza (czerwony), drugi usuwa; utrata fokusu / kursora wycofuje zaznaczenie.
func _setup_trash_button(btn: Button, slot_index: int) -> void:
	btn.tooltip_text = QuizRpgI18n.t("main_menu.delete_save", "Usuń zapis")
	var icon := btn.get_node("Icon") as QuizTrashIcon
	var armed := [false]
	var disarm := func() -> void:
		armed[0] = false
		icon.set_color(Color(0.78, 0.78, 0.86, 1))
		btn.tooltip_text = QuizRpgI18n.t("main_menu.delete_save", "Usuń zapis")
	btn.pressed.connect(func() -> void:
		if armed[0]:
			_on_delete_slot_pressed(slot_index)
			return
		armed[0] = true
		icon.set_color(Color(1.0, 0.35, 0.35, 1))
		btn.tooltip_text = QuizRpgI18n.t("main_menu.delete_save_confirm", "Kliknij ponownie, aby usunąć"))
	_add_click_sfx(btn)
	btn.focus_exited.connect(disarm)
	btn.mouse_exited.connect(disarm)


func _add_message_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_slots_list.add_child(label)


func _on_slot_action_pressed(slot_index: int) -> void:
	var save_manager := _get_save_manager()
	if save_manager == null:
		return
	if not bool(save_manager.call("load_game", slot_index)):
		push_warning("Nie udalo sie wczytac zapisu ze slotu %d." % (slot_index + 1))


func _on_delete_slot_pressed(slot_index: int) -> void:
	var save_manager := _get_save_manager()
	if save_manager and bool(save_manager.call("delete_save_slot", slot_index)):
		_populate_save_slots()
		_update_load_button()


func _on_add_slot_pressed() -> void:
	var save_manager := _get_save_manager()
	if save_manager:
		save_manager.call("add_save_slot")
		_populate_save_slots()


func _on_save_slots_changed() -> void:
	_update_load_button()
	if _save_slots_panel and _save_slots_panel.visible:
		_populate_save_slots()


func _populate_stats() -> void:
	var ps := _get_module_singleton("PlayerStats")
	if not ps:
		stats_label.text = "Brak statystyk"
		return

	stats_label.text = """Statystyki gracza:
Poziom: %d
XP: %d / %d
HP: %d / %d
Punkty: %d
Poprawne: %d
Bledne: %d
Najlepsza seria: %d
Nagrody: %d
Trafnosc: %.0f%%""" % [
		ps.level,
		ps.xp, ps.xp_to_next_level(),
		ps.hp, ps.max_hp,
		ps.points,
		ps.total_correct,
		ps.total_wrong,
		ps.best_streak,
		ps.rewards.size(),
		QuizManager.get_overall_accuracy() * 100,
	]


func _on_quit() -> void:
	if CoreManager.get_active_module_id() != "":
		CoreManager.exit_active_module()
		return
	get_tree().quit()


func _get_module_singleton(singleton_name: String) -> Node:
	var singleton := CoreManager.get_singleton(singleton_name)
	if singleton:
		return singleton

	var module_root := CoreManager.get_active_module()
	if module_root:
		singleton = module_root.get_node_or_null(singleton_name)
		if singleton:
			CoreManager.register_singleton(singleton_name, singleton)
			return singleton

	return null


func _get_save_manager() -> Node:
	return _get_module_singleton("SaveManager")
