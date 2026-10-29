extends CanvasLayer

signal closed

@onready var _btn_windowed: Button = $Panel/Margin/VBox/Tabs/Ekran/Content/HBoxMode/BtnWindowed
@onready var _btn_borderless: Button = $Panel/Margin/VBox/Tabs/Ekran/Content/HBoxMode/BtnBorderless
@onready var _btn_fullscreen: Button = $Panel/Margin/VBox/Tabs/Ekran/Content/HBoxMode/BtnFullscreen
@onready var _res_option: OptionButton = $Panel/Margin/VBox/Tabs/Ekran/Content/ResOption
@onready var _res_note: Label = $Panel/Margin/VBox/Tabs/Ekran/Content/ResNote
@onready var _monitor_option: OptionButton = $Panel/Margin/VBox/Tabs/Ekran/Content/MonitorOption
@onready var _scale_option: OptionButton = $Panel/Margin/VBox/Tabs/Ekran/Content/ScaleOption
@onready var _vsync_check: CheckButton = $Panel/Margin/VBox/Tabs/Ekran/Content/VSyncCheck
@onready var _fps_label: Label = $Panel/Margin/VBox/Tabs/Ekran/Content/FpsLabel
@onready var _fps_slider: HSlider = $Panel/Margin/VBox/Tabs/Ekran/Content/FpsRow/FpsSlider
@onready var _fps_spin: SpinBox = $Panel/Margin/VBox/Tabs/Ekran/Content/FpsRow/FpsSpin
@onready var _quizless_mode: CheckButton = $Panel/Margin/VBox/Tabs/Ogolne/Content/QuizlessMode
@onready var _lang_label: Label = $Panel/Margin/VBox/Tabs/Ogolne/Content/LangLabel
@onready var _lang_option: OptionButton = $Panel/Margin/VBox/Tabs/Ogolne/Content/LangOption
@onready var _mode_label: Label = $Panel/Margin/VBox/Tabs/Ekran/Content/ModeLabel
@onready var _monitor_label: Label = $Panel/Margin/VBox/Tabs/Ekran/Content/MonitorLabel
@onready var _res_label: Label = $Panel/Margin/VBox/Tabs/Ekran/Content/ResLabel
@onready var _scale_label: Label = $Panel/Margin/VBox/Tabs/Ekran/Content/ScaleLabel

@onready var _slider_master: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/Content/SliderMaster
@onready var _slider_music: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/Content/SliderMusic
@onready var _slider_sfx: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/Content/SliderSfx
@onready var _slider_sfx_ui: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/Content/SfxGroups/VBox/SliderSfxUi
@onready var _slider_sfx_combat: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/Content/SfxGroups/VBox/SliderSfxCombat
@onready var _slider_sfx_env: HSlider = $Panel/Margin/VBox/Tabs/Dzwiek/Content/SfxGroups/VBox/SliderSfxEnv
@onready var _lbl_master: Label = $Panel/Margin/VBox/Tabs/Dzwiek/Content/LblMaster
@onready var _lbl_music: Label = $Panel/Margin/VBox/Tabs/Dzwiek/Content/LblMusic
@onready var _lbl_sfx: Label = $Panel/Margin/VBox/Tabs/Dzwiek/Content/LblSfx

@onready var _skin_option: OptionButton = $Panel/Margin/VBox/Tabs/Motyw/Content/SkinOption
@onready var _slider_brightness: HSlider = $Panel/Margin/VBox/Tabs/Motyw/Content/SliderBrightness
@onready var _lbl_skin: Label = $Panel/Margin/VBox/Tabs/Motyw/Content/LblSkin
@onready var _lbl_brightness: Label = $Panel/Margin/VBox/Tabs/Motyw/Content/LblBrightness
@onready var _lbl_no_skins: Label = $Panel/Margin/VBox/Tabs/Motyw/Content/LblNoSkins
@onready var _lbl_bars: Label = $Panel/Margin/VBox/Tabs/Motyw/Content/LblBars
@onready var _bars_option: OptionButton = $Panel/Margin/VBox/Tabs/Motyw/Content/BarsOption
@onready var _extra_options: VBoxContainer = $Panel/Margin/VBox/Tabs/Motyw/Content/ExtraOptions

@onready var _sets_list: VBoxContainer = $Panel/Margin/VBox/Tabs/Pytania/SetsScroll/SetsList
@onready var _lbl_sets: Label = $Panel/Margin/VBox/Tabs/Pytania/LblSets
@onready var _lbl_sets_hint: Label = $Panel/Margin/VBox/Tabs/Pytania/LblSetsHint

@onready var _binds_list: VBoxContainer = $Panel/Margin/VBox/Tabs/Sterowanie/BindsScroll/BindsList
@onready var _lbl_info: Label = $Panel/Margin/VBox/Tabs/Sterowanie/LblInfo
@onready var _lbl_bind_game: Label = $Panel/Margin/VBox/Tabs/Sterowanie/LblBindGame
@onready var _bind_game_option: OptionButton = $Panel/Margin/VBox/Tabs/Sterowanie/BindGameOption

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
const BUS_SFX_UI := "SFX_UI"
const BUS_SFX_COMBAT := "SFX_Combat"
const BUS_SFX_ENV := "SFX_Env"

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
## Wybory monitora / rozdzielczości w chwili otwarcia (albo ostatniego zatwierdzenia) — „Zastosuj” porównuje
## wybory w kontrolkach, nie przeliczone rozdzielczości (bieżącej może nie być na liście, np. pełny ekran).
var _open_monitor_index := -1
var _open_res_index := -1

var _skins: Array = []          # [{id, name}] z aktywnego modułu (get_ui_skins)
var _bar_styles: Array = []     # [{id, name}] z aktywnego modułu (get_ui_bar_styles), opcjonalnie
var _bar_picker: Control = null  # siatka z podglądem pasków modułu (create_bar_style_picker) zamiast listy
var _skin_module_id := ""
## Przechwytywanie klawisza w zakładce „Sterowanie”: {module, action, slot, button, text}; puste = nie.
var _capture: Dictionary = {}
## Gra wybrana w liście „Gra:” zakładki „Sterowanie” (menu główne); "" = pierwsza.
var _binds_module_id := ""
var _syncing_skin := false
## Odroczony zapis ustawień (suwak jasności).
var _save_timer: Timer

var _countdown := 0.0
## Treść okna przeniesiona do panelu modułu (embed_in) albo null (zwykłe okno).
var _embedded_content: Control = null
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
	_res_option.item_selected.connect(func(_i: int) -> void: _on_display_target_changed())
	_populate_resolutions(_monitor_option.selected)
	_populate_scale()
	_fps_slider.max_value = WindowService.MAX_FPS_SLIDER
	_fps_spin.max_value = WindowService.MAX_FPS_INPUT
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_fps_slider.value_changed.connect(func(v: float) -> void: _set_fps_limit(roundi(v)))
	_fps_spin.value_changed.connect(func(v: float) -> void: _set_fps_limit(roundi(v)))
	_setup_audio_sliders()
	_skin_option.item_selected.connect(_on_skin_selected)
	_bars_option.item_selected.connect(_on_bar_style_selected)
	_slider_brightness.value_changed.connect(_on_brightness_changed)
	_bind_game_option.item_selected.connect(_on_bind_game_selected)
	_populate_binds()
	_update_tab_titles()
	if I18nService:
		I18nService.language_changed.connect(_on_language_changed)
	_tabs.tab_changed.connect(func(_i: int) -> void: _sync_apply_button())
	UIScaleService.scale_changed.connect(_on_scale_changed)
	WindowService.resolution_changed.connect(func(_r: Vector2i) -> void: _on_scale_changed(UIScaleService.scale_factor))
	WindowService.window_resized_by_user.connect(_on_window_resized_by_user)
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(func() -> void: _on_scale_changed(UIScaleService.scale_factor))
	_on_scale_changed(UIScaleService.scale_factor)


func _update_tab_titles() -> void:
	if _tabs:
		_tabs.set_tab_title(0, I18nService.t("host.options.tab_general"))
		_tabs.set_tab_title(1, I18nService.t("host.options.tab_display"))
		_tabs.set_tab_title(2, I18nService.t("host.options.tab_audio"))
		_tabs.set_tab_title(3, I18nService.t("host.options.tab_theme"))
		_tabs.set_tab_title(4, I18nService.t("host.options.tab_questions"))
		_tabs.set_tab_title(5, I18nService.t("host.options.tab_controls"))


func _on_language_changed(_lang: String) -> void:
	_update_tab_titles()
	_sync_language()
	_populate_monitors()
	var cur_res := _res_option.selected
	_populate_resolutions(_monitor_option.selected)
	if cur_res >= 0 and cur_res < _res_option.item_count:
		_res_option.selected = cur_res
	_populate_scale()
	_sync_frame_pacing()
	_update_brightness_label()
	_populate_question_sets()
	_populate_binds()


func _process(delta: float) -> void:
	if not _confirming:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_on_revert()
		return
	_lbl_countdown.text = I18nService.tf("host.options.countdown", {"seconds": ceili(_countdown)}, "Przywrócenie za: %ds" % ceili(_countdown))


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


## Tryb wbudowany (np. prawy panel menu Esc / menu głównego Cienia Mgły): zakładki i „Zastosuj” trafiają do
## kontenera modułu, bez tytułu, tła i „Zamknij” — wyjście jak z innych pozycji menu modułu (Esc -> closed).
## Widoczność treści idzie za widocznością tej warstwy (open / close); okno potwierdzenia zmian ekranu zostaje
## na tej warstwie, nad wszystkim. Prośba usera 2026-10-04.
func embed_in(container: Control) -> void:
	if _embedded_content != null:
		return
	var vbox := _tabs.get_parent() as Control
	vbox.reparent(container, false)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title_label.visible = false
	var sep := vbox.get_node_or_null("Sep0") as Control
	if sep:
		sep.visible = false
	_btn_close.visible = false
	_panel.visible = false
	var overlay := get_node_or_null("Overlay") as CanvasItem
	if overlay:
		overlay.visible = false
	_embedded_content = vbox
	vbox.visible = visible
	visibility_changed.connect(func() -> void:
		if is_instance_valid(_embedded_content):
			_embedded_content.visible = visible)


func is_embedded() -> bool:
	return _embedded_content != null


func open() -> void:
	_update_tab_titles()
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
	_sync_frame_pacing()
	_remember_display_selection()
	_sync_apply_button()
	_sync_skin_tab()
	_populate_question_sets()
	_populate_binds()  # aktywny moduł mógł się zmienić
	_on_scale_changed(UIScaleService.scale_factor)  # czcionka aktywnego modułu (mógł się zmienić)
	visible = true


func close() -> void:
	_on_close()


func _exit_tree() -> void:
	if _save_timer and not _save_timer.is_stopped():
		SettingsService.save_settings()


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
	var picked: Vector2i = _resolutions[_res_option.selected] if _res_option.selected in range(_resolutions.size()) else WindowService.resolution
	_sel_mode = mode
	_sync_mode_buttons()
	# Lista zależy od trybu (okno: tylko to, co z ramką mieści się nad paskiem zadań); ten sam wybór
	# albo największa pozycja.
	_populate_resolutions(_monitor_option.selected)
	var index := _resolutions.find(picked)
	_res_option.selected = index if index >= 0 else _resolutions.size() - 1
	_on_display_target_changed()


func _sync_mode_buttons() -> void:
	for index in range(_mode_btns.size()):
		_mode_btns[index].button_pressed = index == _sel_mode
	_update_res_note()


## Wybór = obecna rozdzielczość, a gdy jej nie ma na liście — najbliższa (nie pierwsza: „Zastosuj” po zmianie
## czegoś innego ustawiłoby wtedy 640x480).
func _sync_resolution() -> void:
	var current := WindowService.resolution
	var best := maxi(0, _resolutions.size() - 1)
	var best_diff := INF
	for index in range(_resolutions.size()):
		var diff := absf(float(_resolutions[index].x * _resolutions[index].y - current.x * current.y))
		if diff < best_diff:
			best_diff = diff
			best = index
	_res_option.selected = best


func _sync_scale() -> void:
	_scale_option.selected = UIScaleService.current_mode
	_refresh_scale_items(_pending_height())


## Wysokość ekranu dla wybranej (jeszcze niezastosowanej) rozdzielczości.
func _pending_height() -> int:
	var index := _res_option.selected
	return _resolutions[index].y if index >= 0 and index < _resolutions.size() else WindowService.resolution.y


## Skale za duże dla tej wysokości (UI wyszłoby poza ekran) — wyszarzone.
func _refresh_scale_items(height: int) -> void:
	var max_mode: int = UIScaleService.max_mode_for_height(height)
	for index in range(_scale_option.item_count):
		_scale_option.set_item_disabled(index, index > max_mode)


## Inna rozdzielczość / tryb / monitor w opcjach: skala auto — największa, jaka się zmieści; ręczny wybór (zapisany
## albo zmieniony w tym oknie) zostaje, przycięty do nowego ekranu.
func _on_display_target_changed() -> void:
	var height := _pending_height()
	var max_mode: int = UIScaleService.max_mode_for_height(height)
	if _scale_manually_changed:
		_sel_scale = mini(_sel_scale, max_mode)
	elif UIScaleService.user_picked and UIScaleService.picked_mode >= 0:
		_sel_scale = mini(UIScaleService.picked_mode, max_mode)
	else:
		_sel_scale = max_mode
	_scale_option.selected = _sel_scale
	_refresh_scale_items(height)


func _populate_monitors() -> void:
	var cur := _monitor_option.selected
	_monitor_option.clear()
	for index in range(DisplayServer.get_screen_count()):
		var size := DisplayServer.screen_get_size(index)
		var label := I18nService.tf("host.options.monitor_item", {"index": index + 1, "width": size.x, "height": size.y}, "Monitor {index} ({width} x {height})")
		if index == DisplayServer.get_primary_screen():
			label += " " + I18nService.t("host.options.monitor_primary", "[główny]")
		_monitor_option.add_item(label)
	if cur >= 0 and cur < _monitor_option.item_count:
		_monitor_option.selected = cur


func _on_monitor_changed(index: int) -> void:
	_populate_resolutions(index)
	_res_option.selected = max(0, _resolutions.size() - 1)
	_on_display_target_changed()


func _populate_resolutions(screen: int) -> void:
	_resolutions = WindowService.get_available_resolutions(screen, _sel_mode)
	_res_option.clear()
	var screen_size := DisplayServer.screen_get_size(screen)
	var max_window := WindowService.get_max_windowed_size(screen)
	# Obecny rozmiar okna ustawiony ręcznie (przeciąganie, maksymalizacja) — zawsze na liście, żeby wybór
	# pokazywał prawdę (zmaksymalizowane jest większe niż „maks. okno” z ramką).
	var own := WindowService.resolution
	if _sel_mode == WindowService.MODE_WINDOWED and WindowService.window_mode_idx == WindowService.MODE_WINDOWED \
			and screen == WindowService.monitor_idx and not _resolutions.has(own):
		_resolutions.append(own)
		_resolutions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y or (a.x * a.y == b.x * b.y and a.x < b.x))
	for resolution in _resolutions:
		var label := "%d x %d" % [resolution.x, resolution.y]
		if resolution == screen_size:
			label += " " + I18nService.t("host.options.res_native", "(natywna)")
		elif _sel_mode == WindowService.MODE_WINDOWED and resolution == max_window:
			label += " " + I18nService.t("host.options.res_max_window", "(maks. okno)")
		elif _sel_mode == WindowService.MODE_WINDOWED and resolution == own and own != max_window \
				and not WindowService.get_available_resolutions(screen, _sel_mode).has(own):
			label += " " + (I18nService.t("host.options.res_maximized") if WindowService.window_maximized else I18nService.t("host.options.res_custom"))
		_res_option.add_item(label)


## Okno przeciągnięte przy otwartych opcjach: lista i wybór pokazują nowy rozmiar (bez zmiany do „Zastosuj”).
func _on_window_resized_by_user(_size: Vector2i) -> void:
	if _confirming:
		return
	_prev_res = WindowService.resolution
	_prev_monitor = WindowService.monitor_idx
	if _sel_mode == WindowService.MODE_WINDOWED:
		_monitor_option.selected = WindowService.monitor_idx
		_populate_resolutions(WindowService.monitor_idx)
		_sync_resolution()
		_remember_display_selection()
	_sync_scale()  # skala już przeliczona na największą dla nowego okna


func _populate_scale() -> void:
	var cur := _scale_option.selected
	_scale_option.clear()
	for label in UIScaleService.get_mode_labels():
		_scale_option.add_item(label)
	if cur >= 0 and cur < _scale_option.item_count:
		_scale_option.selected = cur
	_sync_scale()
	if not _scale_option.item_selected.is_connected(_on_scale_item_selected):
		_scale_option.item_selected.connect(_on_scale_item_selected)
	if not _quizless_mode.toggled.is_connected(_on_quizless_toggled):
		_quizless_mode.toggled.connect(_on_quizless_toggled)
	_lang_option.clear()
	for l in SettingsService.LANGUAGES:
		_lang_option.add_item(str(l["name"]))
	_sync_language()
	if not _lang_option.item_selected.is_connected(_on_language_selected):
		_lang_option.item_selected.connect(_on_language_selected)


func _on_scale_item_selected(index: int) -> void:
	_sel_scale = index
	_scale_manually_changed = true


## V-Sync i limit FPS działają od razu (bez „Zastosuj”); limit: suwak co 10 (0 = bez limitu) albo dowolna wartość
## wpisana w pole obok — zapis po chwili spokoju, jak jasność.
func _sync_frame_pacing() -> void:
	_vsync_check.set_pressed_no_signal(WindowService.vsync_enabled)
	_fps_slider.set_value_no_signal(mini(WindowService.max_fps, WindowService.MAX_FPS_SLIDER))
	_fps_spin.set_value_no_signal(WindowService.max_fps)
	for c: Control in [_fps_slider, _fps_spin]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE if WindowService.vsync_enabled else Control.MOUSE_FILTER_STOP
		c.focus_mode = Control.FOCUS_NONE if WindowService.vsync_enabled else Control.FOCUS_ALL
	_fps_spin.editable = not WindowService.vsync_enabled
	_fps_slider.editable = not WindowService.vsync_enabled
	_fps_slider.get_parent().modulate.a = 0.5 if WindowService.vsync_enabled else 1.0
	_fps_label.modulate.a = 0.5 if WindowService.vsync_enabled else 1.0
	var limit := I18nService.t("host.options.fps_unlimited", "bez limitu") if WindowService.max_fps <= 0 else I18nService.tf("host.options.fps_val", {"fps": WindowService.max_fps}, "%d FPS" % WindowService.max_fps)
	_fps_label.text = I18nService.tf("host.options.fps_limit_label", {"limit": limit}, "Limit FPS (przy wyłączonym V-Sync): {limit}")


func _on_vsync_toggled(on: bool) -> void:
	_play_click()
	WindowService.vsync_enabled = on
	WindowService.apply_frame_pacing()
	SettingsService.save_settings()
	_sync_frame_pacing()


func _set_fps_limit(fps: int) -> void:
	if WindowService.vsync_enabled:
		return
	WindowService.max_fps = WindowService.clamp_fps(fps)
	WindowService.apply_frame_pacing()
	_sync_frame_pacing()
	_save_settings_soon()


## Zapis na dysk po chwili spokoju (suwaki: zapis przy każdym ruchu ciął grę).
func _save_settings_soon() -> void:
	if _save_timer == null:
		_save_timer = Timer.new()
		_save_timer.one_shot = true
		_save_timer.wait_time = 0.4
		_save_timer.timeout.connect(SettingsService.save_settings)
		add_child(_save_timer)
	_save_timer.start()


func _sync_language() -> void:
	var current := SettingsService.get_language()
	for i in range(SettingsService.LANGUAGES.size()):
		if SettingsService.LANGUAGES[i]["id"] == current:
			_lang_option.selected = i


## Język to ustawienie globalne, nie wygląd — zapis od razu (teksty gry czytają go przy odświeżeniu widoków).
func _on_language_selected(index: int) -> void:
	SettingsService.set_language(str(SettingsService.LANGUAGES[index]["id"]))


func _sync_quizless_mode() -> void:
	_quizless_mode.button_pressed = _sel_quizless_mode


## „Gra bez quizów” to nie ustawienie ekranu — zapis od razu, bez zatwierdzania (decyzja usera 2026-10-04).
func _on_quizless_toggled(enabled: bool) -> void:
	_sel_quizless_mode = enabled
	_prev_quizless_mode = enabled
	if enabled != SettingsService.is_quizless_mode_enabled():
		SettingsService.set_quizless_mode_enabled(enabled, true)


func _update_res_note() -> void:
	_res_option.disabled = false
	_res_note.visible = false


func _setup_audio_sliders() -> void:
	_slider_master.value_changed.connect(func(value: float): _on_bus_changed(BUS_MASTER, value))
	_slider_music.value_changed.connect(func(value: float): _on_bus_changed(BUS_MUSIC, value))
	_slider_sfx.value_changed.connect(func(value: float): _on_bus_changed(BUS_SFX, value))
	_slider_sfx_ui.value_changed.connect(func(value: float): _on_bus_changed(BUS_SFX_UI, value))
	_slider_sfx_combat.value_changed.connect(func(value: float): _on_bus_changed(BUS_SFX_COMBAT, value))
	_slider_sfx_env.value_changed.connect(func(value: float): _on_bus_changed(BUS_SFX_ENV, value))


func _sync_audio_sliders() -> void:
	_slider_master.value = SettingsService.get_bus_volume(BUS_MASTER)
	_slider_music.value = SettingsService.get_bus_volume(BUS_MUSIC)
	_slider_sfx.value = SettingsService.get_bus_volume(BUS_SFX)
	_slider_sfx_ui.value = SettingsService.get_bus_volume(BUS_SFX_UI)
	_slider_sfx_combat.value = SettingsService.get_bus_volume(BUS_SFX_COMBAT)
	_slider_sfx_env.value = SettingsService.get_bus_volume(BUS_SFX_ENV)


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
	var use_picker := _lbl_bars.visible and module.has_method("create_bar_style_picker")
	_bars_option.visible = _lbl_bars.visible and not use_picker
	_lbl_no_skins.visible = not has_skins
	_fill_option(_skin_option, _skins, SKIN_KEY)
	_fill_option(_bars_option, _bar_styles, BAR_STYLE_KEY)
	_sync_bar_picker(module if use_picker else null)
	_build_extra_options(module if has_skins else null)
	var brightness := float(SettingsService.get_module(_skin_module_id, BRIGHTNESS_KEY, 1.0)) if has_skins else 1.0
	_slider_brightness.value = roundf(brightness * 100.0)
	_update_brightness_label()
	_syncing_skin = false


## Dodatkowe opcje wyglądu modułu (get_ui_options: [{key, label, type: "bool" | "choice", default}],
## "choice" z listą choices: [{id, name}]) — zapis w ustawieniach modułu, zmiana od razu (module_setting_changed).
func _build_extra_options(module: Node) -> void:
	for c in _extra_options.get_children():
		c.queue_free()
	if module == null or not module.has_method("get_ui_options"):
		return
	for opt in module.get_ui_options():
		var type := str(opt.get("type", "bool"))
		if type == "choice":
			_add_choice_option(opt)
			continue
		if type != "bool":
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


## Opcja wyboru modułu ({key, label, type: "choice", choices: [{id, name}], default}): etykieta + lista.
func _add_choice_option(opt: Dictionary) -> void:
	var key := str(opt.get("key", ""))
	var choices: Array = opt.get("choices", [])
	if key == "" or choices.is_empty():
		return
	var lbl := Label.new()
	lbl.text = str(opt.get("label", key)) + ":"
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
	lbl.add_theme_font_size_override("font_size", _fs(18))
	_extra_options.add_child(lbl)
	var option := OptionButton.new()
	var current := str(SettingsService.get_module(_skin_module_id, key, opt.get("default", "")))
	for i in range(choices.size()):
		option.add_item(str(choices[i].get("name", choices[i].get("id", "?"))))
		if str(choices[i].get("id", "")) == current:
			option.selected = i
	if option.selected < 0:
		option.selected = 0
	option.add_theme_font_size_override("font_size", _fs(18))
	_scale_popup_font(option, _fs(18))
	option.item_selected.connect(func(index: int) -> void:
		_play_click()
		SettingsService.set_module(_skin_module_id, key, str(choices[index].get("id", ""))))
	_extra_options.add_child(option)


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


## Siatka stylów pasków od modułu (kafelki z podglądem) w miejscu listy BarsOption; null = bez siatki.
func _sync_bar_picker(module: Node) -> void:
	if _bar_picker != null and is_instance_valid(_bar_picker):
		_bar_picker.queue_free()
	_bar_picker = null
	if module == null:
		return
	var current := str(SettingsService.get_module(_skin_module_id, BAR_STYLE_KEY, ""))
	_bar_picker = module.create_bar_style_picker(current, _fs(16)) as Control
	if _bar_picker == null:
		return
	_bar_picker.name = "BarStylePicker"
	_bars_option.add_sibling(_bar_picker)
	_bar_picker.connect("style_selected", func(style_id: String) -> void:
		_play_click()
		SettingsService.set_module(_skin_module_id, BAR_STYLE_KEY, style_id))


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
	if _bar_picker != null and _bar_picker.has_method("refresh_previews"):
		_bar_picker.call("refresh_previews")   # ramka gładkich pasków zależy od motywu okien


## Suwak: zmiana od razu, zapis na dysk dopiero po chwili spokoju (zapis przy każdym ruchu suwaka ciął grę).
func _on_brightness_changed(value: float) -> void:
	_update_brightness_label()
	if _syncing_skin or _skin_module_id == "":
		return
	SettingsService.set_module(_skin_module_id, BRIGHTNESS_KEY, value / 100.0, false)
	_save_settings_soon()


func _update_brightness_label() -> void:
	_lbl_brightness.text = I18nService.tf("host.options.brightness_val", {"val": roundi(_slider_brightness.value)}, "Jasność motywu: {val}%")


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
		var tag: String = ""
		if str(s["source"]) == "edited":
			tag = "  " + I18nService.t("host.options.set_edited", "(edytowany)")
		elif str(s["source"]) == "user":
			tag = "  " + I18nService.t("host.options.set_user", "(własny)")
		cb.text = "%s  —  %s%s" % [s["name"], I18nService.plural("host.options.questions_count", count), tag]
		cb.button_pressed = QuestionBank.is_set_enabled(id, sel)
		cb.add_theme_font_size_override("font_size", _fs(18))
		cb.toggled.connect(func(on: bool) -> void:
			QuestionBank.set_set_enabled(id, on)
			QuizService.reload_all())
		_sets_list.add_child(cb)


## Zakładka „Sterowanie”: sekcje z manifestów modułów (pole "controls": [{label, actions, keys}], opcjonalnie
## "action_labels": {akcja: nazwa}). W menu głównym — lista „Gra:” wybiera moduł (zamiast wszystkich naraz,
## prośba usera 2026-10-04), w trakcie gry — tylko aktywny moduł, bez listy. Każda akcja ma InputBinds.SLOTS pola: klik -> „Naciśnij klawisz…” (Esc anuluje, Backspace
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
	var pick_game := active_id == "" and manifests.size() > 1
	_lbl_bind_game.visible = pick_game
	_bind_game_option.visible = pick_game
	if manifests.is_empty():
		_lbl_info.text = I18nService.t("host.binds.no_controls_module") if active_id != "" else I18nService.t("host.binds.no_controls_all")
		return
	if pick_game:
		_bind_game_option.clear()
		var picked := 0
		for i in manifests.size():
			var id := str(manifests[i].get("id", ""))
			_bind_game_option.add_item(str(manifests[i].get("name", id)))
			_bind_game_option.set_item_metadata(i, id)
			if id == _binds_module_id:
				picked = i
		_bind_game_option.select(picked)
		manifests = [manifests[picked]]
	_lbl_info.text = I18nService.tf("host.binds.info_game", {"game": str(manifests[0].get("name", manifests[0].get("id", "")))})
	for m in manifests:
		var module_id := str(m.get("id", ""))
		_add_control_options(module_id, m.get("control_options", []))
		for entry in m["controls"]:
			if not (entry is Dictionary):
				continue
			var lbl_sec := Label.new()
			lbl_sec.text = str(entry.get("label", ""))
			lbl_sec.add_theme_font_size_override("font_size", _fs(18))
			lbl_sec.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
			lbl_sec.set_meta(&"bind_size", 18)
			_binds_list.add_child(lbl_sec)
			var actions: Array = entry.get("actions", []) if entry.get("actions", []) is Array else []
			if actions.is_empty():
				var lbl_keys := Label.new()
				lbl_keys.text = "  " + str(entry.get("keys", I18nService.t("host.binds.none")))
				lbl_keys.add_theme_font_size_override("font_size", _fs(18))
				lbl_keys.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
				lbl_keys.set_meta(&"bind_size", 18)
				_binds_list.add_child(lbl_keys)
				continue
			for action in actions:
				_binds_list.add_child(_bind_row(module_id, str(action)))
		var btn_reset := Button.new()
		btn_reset.text = I18nService.t("host.binds.btn_reset")
		btn_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn_reset.add_theme_font_size_override("font_size", _fs(18))
		btn_reset.set_meta(&"bind_size", 18)
		btn_reset.pressed.connect(_reset_binds.bind(module_id))
		_binds_list.add_child(btn_reset)


## Opcje sterowania z manifestu modułu ("control_options": [{key, label, default, options: [{id, name}]}]),
## np. domyślny chód / bieg w Cieniu Mgły — lista wyboru, zapis od razu (SettingsService.set_module ->
## module_setting_changed, moduł odświeża się na żywo).
func _add_control_options(module_id: String, options: Variant) -> void:
	if not (options is Array):
		return
	for opt in options:
		if not (opt is Dictionary) or not (opt.get("options", []) is Array):
			continue
		var key := str(opt.get("key", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = "  " + str(opt.get("label", key))
		lbl.custom_minimum_size = Vector2(UIScaleService.px(220), 0)
		lbl.add_theme_font_size_override("font_size", _fs(18))
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		lbl.set_meta(&"bind_size", 18)
		row.add_child(lbl)
		var choice := OptionButton.new()
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_theme_font_size_override("font_size", _fs(18))
		choice.set_meta(&"bind_size", 18)
		_scale_popup_font(choice, _fs(18))
		var current := str(SettingsService.get_module(module_id, key, opt.get("default", "")))
		var ids: Array = []
		for item in opt["options"]:
			ids.append(str(item.get("id", "")))
			choice.add_item(str(item.get("name", item.get("id", "?"))))
		choice.selected = maxi(0, ids.find(current))
		choice.item_selected.connect(func(index: int) -> void:
			_play_click()
			SettingsService.set_module(module_id, key, ids[index]))
		row.add_child(choice)
		_binds_list.add_child(row)


func _on_bind_game_selected(index: int) -> void:
	_play_click()
	_binds_module_id = str(_bind_game_option.get_item_metadata(index))
	_populate_binds()


## Wiersz akcji: nazwa + InputBinds.SLOTS pól z klawiszami. Tekst w rozmiarze innych zakładek (18).
func _bind_row(module_id: String, action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "  " + _action_label(module_id, action)
	lbl.custom_minimum_size = Vector2(UIScaleService.px(220), 0)
	lbl.add_theme_font_size_override("font_size", _fs(18))
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.set_meta(&"bind_size", 18)
	row.add_child(lbl)
	var keys := InputBinds.get_keys(action)
	for slot in InputBinds.SLOTS:
		var btn := Button.new()
		btn.text = InputBinds.key_name(keys[slot]) if slot < keys.size() else "—"
		btn.custom_minimum_size = Vector2(UIScaleService.px(140), 0)
		btn.clip_text = true  # stała szerokość pola także przy „Naciśnij…”
		btn.add_theme_font_size_override("font_size", _fs(18))
		btn.set_meta(&"bind_size", 18)
		btn.pressed.connect(_start_capture.bind(module_id, action, slot, btn))
		row.add_child(btn)
	return row


func _start_capture(module_id: String, action: String, slot: int, btn: Button) -> void:
	_play_click()
	if not _capture.is_empty() and is_instance_valid(_capture.button):
		(_capture.button as Button).text = _capture.text
	_capture = {"module": module_id, "action": action, "slot": slot, "button": btn, "text": btn.text}
	btn.text = I18nService.t("host.binds.btn_press")
	_lbl_info.text = I18nService.tf("host.binds.info_capture", {"action": _action_label(module_id, action)})


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
		_lbl_info.text = I18nService.tf("host.binds.key_reassigned", {"key": InputBinds.key_name(code), "action": moved_from})


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


## Nazwa akcji w wybranym języku: klucz host.action.<moduł>.<akcja>, zapasowo etykieta z manifestu modułu (po polsku).
func _action_label(module_id: String, action: String) -> String:
	var labels: Variant = ModuleRegistry.get_by_id(module_id).get("action_labels", {})
	var fallback := str(labels.get(action, action)) if labels is Dictionary else action
	return I18nService.t("host.action.%s.%s" % [module_id, action], fallback)


## „Zastosuj” tylko na zakładce Ekran — pozostałe zakładki zapisują zmiany od razu.
func _remember_display_selection() -> void:
	_open_monitor_index = _monitor_option.selected
	_open_res_index = _res_option.selected


func _sync_apply_button() -> void:
	_btn_apply.visible = _tabs.get_current_tab_control() == _tabs.get_node("Ekran")


## Ustawienia ekranu (tryb okna, monitor, rozdzielczość, skalowanie) z potwierdzeniem i odliczaniem —
## tylko gdy coś się zmieniło (decyzja usera 2026-10-04).
func _on_apply() -> void:
	_play_click()
	var resolution_index := _res_option.selected
	var resolution := WindowService.resolution
	if resolution_index >= 0 and resolution_index < _resolutions.size():
		resolution = _resolutions[resolution_index]
	var display_changed := _sel_mode != _prev_mode or _monitor_option.selected != _open_monitor_index \
		or _res_option.selected != _open_res_index or _sel_scale != _prev_scale
	if not display_changed:
		return
	# Najpierw okno (nowa rozdzielczość ustawia największą skalę), potem ręczny wybór skali — inaczej zmiana
	# rozdzielczości nadpisałaby wybór.
	SettingsService.apply_settings(_sel_mode, resolution, _monitor_option.selected)
	if _scale_manually_changed:
		UIScaleService.set_mode(_sel_scale)
	elif not _prev_scale_user_picked:
		UIScaleService.reset_to_auto()
	_sync_scale()
	_start_confirm()


func _start_confirm() -> void:
	_countdown = CONFIRM_TIMEOUT
	_confirming = true
	_confirm_popup.visible = true
	_lbl_countdown.text = I18nService.tf("host.options.countdown", {"seconds": ceili(_countdown)}, "Przywrócenie za: %ds" % ceili(_countdown))


## Zachowane ustawienia ekranu stają się nowym punktem odniesienia; okno zostaje otwarte.
func _on_confirm() -> void:
	_play_click()
	_confirming = false
	_confirm_popup.visible = false
	_prev_mode = WindowService.window_mode_idx
	_prev_res = WindowService.resolution
	_prev_monitor = WindowService.monitor_idx
	_prev_scale = UIScaleService.current_mode
	_prev_scale_user_picked = UIScaleService.user_picked
	_sel_scale = _prev_scale
	_scale_manually_changed = false
	_remember_display_selection()


func _on_revert() -> void:
	_play_click()
	_confirming = false
	_confirm_popup.visible = false
	_scale_manually_changed = false
	SettingsService.apply_settings(_prev_mode, _prev_res, _prev_monitor)
	if _prev_scale_user_picked:
		UIScaleService.set_mode(_prev_scale)
	else:
		UIScaleService.reset_to_auto()
	_sel_mode = _prev_mode
	_sel_scale = _prev_scale
	_sync_mode_buttons()
	_monitor_option.selected = _prev_monitor
	_populate_resolutions(_prev_monitor)
	_sync_resolution()
	_sync_scale()
	_sync_quizless_mode()
	_sync_audio_sliders()
	_remember_display_selection()


func _on_scale_changed(_scale: float) -> void:
	var main_size := _fs(18)
	_title_label.add_theme_font_size_override("font_size", _fs(26))
	_tabs.add_theme_font_size_override("font_size", _fs(17))
	_mode_label.add_theme_font_size_override("font_size", main_size)
	_monitor_label.add_theme_font_size_override("font_size", main_size)
	_res_label.add_theme_font_size_override("font_size", main_size)
	_res_note.add_theme_font_size_override("font_size", _fs(15))
	_scale_label.add_theme_font_size_override("font_size", main_size)
	_vsync_check.add_theme_font_size_override("font_size", main_size)
	_fps_label.add_theme_font_size_override("font_size", main_size)
	_fps_spin.get_line_edit().add_theme_font_size_override("font_size", main_size)
	_quizless_mode.add_theme_font_size_override("font_size", main_size)
	_lang_label.add_theme_font_size_override("font_size", main_size)
	_lang_option.add_theme_font_size_override("font_size", main_size)
	_monitor_option.add_theme_font_size_override("font_size", main_size)
	_res_option.add_theme_font_size_override("font_size", main_size)
	_scale_option.add_theme_font_size_override("font_size", main_size)
	_scale_popup_font(_monitor_option, main_size)
	_scale_popup_font(_res_option, main_size)
	_scale_popup_font(_scale_option, main_size)
	_lbl_master.add_theme_font_size_override("font_size", main_size)
	_lbl_music.add_theme_font_size_override("font_size", main_size)
	_lbl_sfx.add_theme_font_size_override("font_size", main_size)
	for sub in _lbl_sfx.get_parent().get_node("SfxGroups/VBox").get_children():  # grupy efektów: odrobinę mniejsze niż główne
		if sub is Label:
			sub.add_theme_font_size_override("font_size", _fs(17))
	_lbl_skin.add_theme_font_size_override("font_size", main_size)
	_lbl_brightness.add_theme_font_size_override("font_size", main_size)
	_lbl_no_skins.add_theme_font_size_override("font_size", _fs(14))
	_skin_option.add_theme_font_size_override("font_size", main_size)
	_scale_popup_font(_skin_option, main_size)
	_lbl_bars.add_theme_font_size_override("font_size", main_size)
	_bars_option.add_theme_font_size_override("font_size", main_size)
	_scale_popup_font(_bars_option, main_size)
	_lbl_info.add_theme_font_size_override("font_size", _fs(14))
	_lbl_bind_game.add_theme_font_size_override("font_size", main_size)
	_bind_game_option.add_theme_font_size_override("font_size", main_size)
	_scale_popup_font(_bind_game_option, main_size)
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
	var btn_min_h := maxi(38, UIScaleService.px(38))
	for button in _mode_btns:
		button.add_theme_font_size_override("font_size", mode_font_size)
		button.custom_minimum_size = UIScaleService.sz2(BASE_BTN_MODE_SIZE.x, maxf(BASE_BTN_MODE_SIZE.y, float(btn_min_h)))
	_fps_spin.custom_minimum_size = Vector2(UIScaleService.px(110), float(btn_min_h))
	for opt in [_monitor_option, _res_option, _scale_option, _skin_option, _bars_option, _bind_game_option]:
		if opt:
			opt.custom_minimum_size = Vector2(opt.custom_minimum_size.x, float(btn_min_h))
	_btn_apply.custom_minimum_size = UIScaleService.sz2(BASE_BTN_ACTION_SIZE.x, maxf(BASE_BTN_ACTION_SIZE.y, float(btn_min_h)))
	_btn_close.custom_minimum_size = UIScaleService.sz2(BASE_BTN_ACTION_SIZE.x, maxf(BASE_BTN_ACTION_SIZE.y, float(btn_min_h)))
	_btn_confirm.custom_minimum_size = UIScaleService.sz2(BASE_BTN_CONFIRM_SIZE.x, maxf(BASE_BTN_CONFIRM_SIZE.y, float(btn_min_h)))
	_btn_revert.custom_minimum_size = UIScaleService.sz2(BASE_BTN_CONFIRM_SIZE.x, maxf(BASE_BTN_CONFIRM_SIZE.y, float(btn_min_h)))

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
	var def_theme := ThemeDB.get_default_theme()
	if def_theme and def_theme.default_font_size == 27:
		return 27 * maxi(1, roundi(size * 1.4 / 27))
	return size


func _scale_popup_font(option: OptionButton, font_size: int) -> void:
	option.get_popup().add_theme_font_size_override("font_size", font_size)
