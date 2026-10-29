extends Control

const TargetRowScene = preload("../../scenes/quiz/combat_target_row.tscn")
const ActorPreviewScene = preload("../../scenes/quiz/actor_preview.tscn")
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

signal combat_finished(player_won: bool)

enum Phase { ACTION_SELECT, TARGET_SELECT, QUIZ, PLAYER_RESULT, ENEMY_TURN, COMBAT_END }
enum Action { ATTACK, DEFEND, HEAL, FLEE }
## Dolny pas jak w RPG Makerze: komendy drużyny po lewej (Walcz / Uciekaj), komendy postaci po prawej
## (status wtedy po lewej), sam status wyśrodkowany (tura wroga, komunikaty).
enum Band { PARTY_COMMAND, ACTOR_COMMAND, STATUS_ONLY, LIST }

## Kontroler panelu pytań jest w hoście (w wersji samodzielnej kopia w _host/), więc load zamiast preload.
static var QuizPanelController: Script = load(QuizRpgPaths.host("res://scripts/shared/quiz/quiz_panel_controller.gd"))
const EnemyBattleDisplayScript: Script = preload("../enemies/enemy_battle_display.gd")
const POISON_COLOR := Color(0.78, 0.35, 0.95)
const MESSAGE_CHARS_PER_SEC := 60.0  ## tempo wypisywania komunikatów w dolnym pasie (pojawił się, zwycięstwo, łup)
const PARTY_CURSOR_MIN_PAD := 8.0  ## kursor wiersza drużyny: odstęp ramki od tekstu w poziomie (px)
const DeathScreenScene: PackedScene = preload("../../scenes/ui/death_screen.tscn")

const PARTY_SKILL_SP_MAX := 100
const PARTY_TP_MAX := 100
## TP z otrzymanych obrażeń: proporcjonalnie do utraconej części HP — tyle TP za utratę 100% HP
## (utrata 50% HP -> 40 TP). Liczone z obrażeń bez redukcji przez obronę (obrona nie zmniejsza TP).
const TP_PER_FULL_HP_LOST := 50.0  # jak w FNaFB: 50 × obrażenia / maks. HP trafionej postaci (× mnożnik ładowania)
## TP za atak — dużo mniej niż z obrażeń (docs/game_design.md, „Tech Pointy w walce”).
const TP_PER_HIT := 5              # zwykły atak (za trafienie) i Obrona — „TP Gain” 5 jak w FNaFB
const TP_START_MIN := 10           # TP na start walki: losowo TP_START_MIN..TP_START_MAX (decyzja usera 2026-10-16)
const TP_START_MAX := 20
const GUARD_SPEED := 2000          # Obrona zawsze pierwsza (Guard w FNaFB ma speed 2000)
const SKILL_SP_COST := 20
const ATTACK_HIT_CHANCE_CORRECT := 0.8
const ATTACK_HIT_CHANCE_WRONG := 0.2
const FLEE_SUCCESS_CHANCE := 0.8  # jak w FNaFB1 (BattleManager.make_escape_ratio)
const COMMAND_PANEL_WIDTH_DEFAULT := 1.0
const PARTY_PANEL_WIDTH_DEFAULT := 2.2
const COMMAND_PANEL_WIDTH_MIN := 240.0
const PARTY_PANEL_WIDTH_MIN := 380.0
const PANEL_RESIZE_DURATION := 0
const UI_TEXT_PRIMARY := Color(0.95, 0.95, 0.98)
const UI_BORDER := Color(0.25, 0.25, 0.35)
const UI_ACCENT := Color(0.3, 0.6, 1.0)
const ENEMY_DISPLAY_SCALE_DEFAULT := Vector2(7.2, 7.2)
const ENEMY_DISPLAY_SCALE_FOCUSED := Vector2(7.9, 7.9)
## Pytania proste (wybór) i złożone (wpisywanie, kafelki, dopasowanie). Szansa na złożone zależy od tieru atakowanego
## przeciwnika: 20% × tier (tier 1 = 20%, 2 = 40%, 3 = 60%, 4 i wyżej = 80%).
const QUIZ_TYPES_SIMPLE := ["multiple_choice", "true_false"]
const QUIZ_TYPES_COMPLEX := ["fill_text", "fill_tiles", "matching"]
const COMPLEX_CHANCE_PER_TIER := 0.2
const COMPLEX_CHANCE_MAX := 0.8

## Wygląd i układ ekranu są w scenie (WYSIWYG) i w motywie QuizTheme.THEME_PATH; tutaj tylko to, co
## zależy od fazy tury. Szerokości okien dolnego pasa jako część szerokości ekranu.
## Przewaga / zaskoczenie na start walki jak w FNaFB (RPG Maker VX Ace BattleManager.on_encounter, decyzja usera
## 2026-10-21): losowo, wg średniego AGI drużyny względem wrogów; zaskoczenie tylko, gdy nie wypadła przewaga. Bossy bez.
@export_range(0.0, 1.0, 0.01) var preemptive_rate_faster := 0.05  ## przewaga, gdy AGI drużyny >= AGI wrogów
@export_range(0.0, 1.0, 0.01) var preemptive_rate_slower := 0.03  ## przewaga, gdy drużyna wolniejsza
@export_range(0.0, 1.0, 0.01) var surprise_rate_faster := 0.03    ## zaskoczenie, gdy AGI drużyny >= AGI wrogów
@export_range(0.0, 1.0, 0.01) var surprise_rate_slower := 0.05    ## zaskoczenie, gdy drużyna wolniejsza
## Ucieczka z pytaniem: dobra odpowiedź — zwykła szansa (FLEE_SUCCESS_CHANCE), zła — mniejsza o tyle.
@export_range(0.0, 1.0, 0.05) var flee_wrong_penalty := 0.3
@export_range(0.08, 0.6, 0.01) var party_command_width := 0.15  ## okno komend drużyny (lewa strona; szersze, gdy treść wymaga)
@export_range(0.08, 0.6, 0.01) var actor_command_width := 0.15  ## okno komend postaci (prawa strona; szersze, gdy treść wymaga)
@export_range(0.3, 1.0, 0.01) var status_only_width := 0.72    ## sam status (tura wroga): wyśrodkowany
@export_range(1, 6) var log_lines := 3                        ## log bitwy u góry: ostatnie komunikaty
@export var quiz_band_extra_height := 60.0                    ## dolny pas w czasie quizu: tyle px wyżej
@export_range(0.2, 0.8, 0.01) var list_party_width := 0.4  ## lista umiejętności / przedmiotów: okno drużyny obok (reszta pasa = lista)
@export_range(0.3, 1.0, 0.01) var compact_party_width := 0.5  ## UI „na szerokość treści” (opcje): okno drużyny
@export_range(0.2, 1.0, 0.01) var compact_quiz_min_width := 0.45  ## UI „na szerokość treści”: quiz co najmniej tyle szerokości ekranu
@export var compact_min_viewport_width := 1600.0  ## węższe okno gry (px): UI walki na całą szerokość (także sam status i opcja „na szerokość treści”)

var phase: Phase = Phase.ACTION_SELECT:
	set(v):
		if v != phase:
			_settle_input()
		phase = v
## Po zmianie fazy / panelu wejście jest chwilę ignorowane — dwa szybkie wejścia (klik w cel + Esc, Atak + Umiejętności)
## nie trafiają w stan w połowie przejścia.
const INPUT_SETTLE_MSEC := 120
var _input_settle_until := 0
var chosen_action: Action = Action.ATTACK

var enemy: Node2D
var player: Node2D
var quiz_id := ""
var _diff_range := Vector2i(1, 3)
var _question_count := 1
var _encounter_size_range := Vector2i(1, 1)
var _joined: Array = []   # wrogowie ze świata dołączeni do walki (grupa) — każdy to osobna jednostka

var enemy_hp := 50
var enemy_max_hp := 50
var enemy_name_str := "Przeciwnik"
var enemy_base_attack := 24
var enemy_base_defense := 12
var enemy_base_magic_attack := 24
var enemy_base_magic_defense := 12
var enemy_base_agility := 15
## Leczenie umiejętności po złej odpowiedzi w quizie: tyle efektu po dobrej (dawne 30 % / 10 % HP).
const WRONG_ANSWER_HEAL_FACTOR := 1.0 / 3.0
## Obrona: część obrażeń, która przechodzi (jak Guard w FNaFB — tam połowa): 1/4 po dobrej odpowiedzi, 1/2 po złej.
const GUARD_DAMAGE_FACTOR_CORRECT := 0.25
const GUARD_DAMAGE_FACTOR_WRONG := 0.5
## Broniąca się postać ma o połowę mniejszą szansę na status od umiejętności wroga (jak Guard w FNaFB).
const GUARD_STATUS_CHANCE_FACTOR := 0.5
var turn_number := 0
enum Initiative { NONE, PREEMPTIVE, SURPRISE }
var _initiative := Initiative.NONE         # wynik losowania na start walki (dotyczy 1. rundy)
var _combat_started_msec := Time.get_ticks_msec()  # początek walki (log progresji)

@onready var battle_window: PanelContainer = $BattleWindow
@onready var window_shadow: Control = get_node_or_null("WindowShadow") as Control
var _shadow_height := 35.0
@onready var quiz_modal_overlay: Control = get_node_or_null("QuizModalOverlay") as Control
@onready var quiz_modal_vbox: VBoxContainer = get_node_or_null("QuizModalOverlay/ModalPanel/ModalMargin/ModalVBox") as VBoxContainer
@onready var content_row: HBoxContainer  = $BattleWindow/WindowMargin/VBox/ContentRow
@onready var party_command_panel: PanelContainer = (get_node_or_null("BattleWindow/WindowMargin/VBox/ContentRow/PartyCommandPanel") if has_node("BattleWindow/WindowMargin/VBox/ContentRow/PartyCommandPanel") else get_node_or_null("BattleWindow/WindowMargin/VBox/ContentRow/CommandPanel")) as PanelContainer
@onready var command_panel_container: PanelContainer = party_command_panel
@onready var party_panel_container: PanelContainer = (get_node_or_null("BattleWindow/WindowMargin/VBox/ContentRow/PartyPanel") if has_node("BattleWindow/WindowMargin/VBox/ContentRow/PartyPanel") else get_node_or_null("BattleWindow/WindowMargin/VBox/ContentRow/CombatLogPanel")) as PanelContainer
@onready var actor_command_panel: PanelContainer = get_node_or_null("BattleWindow/WindowMargin/VBox/ContentRow/ActorCommandPanel") as PanelContainer

@onready var command_vbox: VBoxContainer = (party_command_panel.get_node_or_null("CommandMargin/CommandVBox") if party_command_panel else null) as VBoxContainer
@onready var action_panel: VBoxContainer = (command_vbox.get_node_or_null("ActionPanel") if command_vbox else null) as VBoxContainer
@onready var primary_menu: VBoxContainer = (action_panel.get_node_or_null("PrimaryMenu") if action_panel else null) as VBoxContainer
@onready var action_menu: VBoxContainer = (
	actor_command_panel.get_node_or_null("ActorMargin/ActorVBox/ActorActionPanel/ActionMenu") if (actor_command_panel and actor_command_panel.has_node("ActorMargin/ActorVBox/ActorActionPanel/ActionMenu"))
	else (actor_command_panel.get_node_or_null("ActorMargin/ActionMenu") if actor_command_panel
	else (action_panel.get_node_or_null("ActionMenu") if action_panel else null))
) as VBoxContainer
@onready var result_label: Label = $TopWindow/VBox/ResultSink/ResultLabel  # źródło komunikatów logu
@onready var player_hp_bar: ProgressBar = $Battlefield/FieldContent/PlayerSection/PlayerHPBar
@onready var enemy_name_label: Label = $Battlefield/FieldContent/EnemySection/EnemyNameLabel
@onready var player_name_label: Label = $Battlefield/FieldContent/PlayerSection/PlayerName
@onready var enemy_section: Control = get_node_or_null("Battlefield/FieldContent/EnemySection") as Control
@onready var enemy_sprite_node: Control = $Battlefield/FieldContent/EnemySection/EnemySprite
@onready var enemy_target_home_slot: Control = get_node_or_null("Battlefield/FieldContent/EnemySection/EnemySprite/EnemyRow1/MarginContainer/HBoxContainer/VBoxContainer/EnemySlot0") as Control
@onready var player_sprite_node: Control = $Battlefield/FieldContent/PlayerSection/PlayerSprite
@onready var battle_background: Control = $Background if has_node("Background") else $Battlefield/Background
## Lista umiejętności / przedmiotów w dolnym pasie (jak okna RPG Makera), opis w górnym oknie (HelpLabel).
@onready var list_panel: PanelContainer = $BattleWindow/WindowMargin/VBox/ContentRow/ListPanel
@onready var list_scroll: ScrollContainer = $BattleWindow/WindowMargin/VBox/ContentRow/ListPanel/ListMargin/ListScroll
@onready var list_grid: GridContainer = $BattleWindow/WindowMargin/VBox/ContentRow/ListPanel/ListMargin/ListScroll/ListGrid
@onready var help_label: Label = $TopWindow/VBox/HelpLabel
const ListRowScene := preload("../../scenes/quiz/combat_list_row.tscn")
@onready var turn_label: Label = get_node_or_null("BattleWindow/WindowMargin/VBox/TopRow/TurnLabel") as Label
@onready var streak_label: Label = get_node_or_null("BattleWindow/WindowMargin/VBox/TopRow/StreakLabel") as Label
@onready var target_panel: VBoxContainer = (party_panel_container.get_node_or_null("PartyMargin/TargetPanel") if party_panel_container else null) as VBoxContainer
@onready var target_label: Label = (target_panel.get_node_or_null("TargetLabel") if target_panel else null) as Label
@onready var target_list_vbox: GridContainer = (target_panel.get_node_or_null("TargetListVBox") if target_panel else null) as GridContainer
@onready var party_rows : Array[HBoxContainer] = [
		(party_panel_container.get_node_or_null("PartyMargin/PartyVBox/PartyRow0") if party_panel_container else null) as HBoxContainer,
		(party_panel_container.get_node_or_null("PartyMargin/PartyVBox/PartyRow1") if party_panel_container else null) as HBoxContainer,
		(party_panel_container.get_node_or_null("PartyMargin/PartyVBox/PartyRow2") if party_panel_container else null) as HBoxContainer,
		(party_panel_container.get_node_or_null("PartyMargin/PartyVBox/PartyRow3") if party_panel_container else null) as HBoxContainer,
	]
@onready var engage_btn: Button = (primary_menu.get_node_or_null("EngageBtn") if primary_menu else null) as Button
@onready var run_btn: Button = (primary_menu.get_node_or_null("RunBtn") if primary_menu else null) as Button
@onready var exit_btn: Button = (primary_menu.get_node_or_null("ExitBtn") if primary_menu else null) as Button
@onready var atk_btn: Button = (action_menu.get_node_or_null("AtkBtn") if action_menu else null) as Button
@onready var def_btn: Button = (action_menu.get_node_or_null("DefBtn") if action_menu else null) as Button
@onready var skills_btn: Button = (action_menu.get_node_or_null("SkillsBtn") if action_menu else null) as Button
@onready var items_btn: Button = (action_menu.get_node_or_null("ItemsBtn") if action_menu else null) as Button

var _enemy_units: Array[Dictionary] = []
var _active_enemy_index := 0
var _bonus_xp_reward := 0
var _enemy_display_root: Node2D = null
var _enemy_display_node: Node2D = null
var _enemy_name_label: Label = null
var _enemy_displays: Array[Node2D] = []
var _enemy_active_layout_slots: Array[Dictionary] = []
var _enemy_wrapper_pool: Array[Dictionary] = []  # sloty wrogów ze sceny (wrapper + slot + pasek HP)
var _enemy_field_layer: Control = null          # warstwa, na której sloty stoją w miejscach z pól walki
var _battle_layout: BattleBackgroundLayout = null
var _enemy_target_cursor_node: Label = null
var _enemy_target_highlight_node: Control = null
var _action_buttons: Array[Button] = []
var _selected_action_idx: int = 0
var _victory_skip := false
var _typing := false                 # komunikat wypisuje się znak po znaku (_type_label)
var _type_skip := false              # Enter / Z / klik w trakcie wypisywania: reszta tekstu od razu
var _more_marker_tween: Tween
var _action_menu_open := false
var _actor_select_open := false  # po „Walcz”: kursor na liście drużyny (prawe okno), wybór postaci
var _actor_selected_idx := 0
var _active_actor_index := 0     # postać, która wykonuje akcję w tej turze
var _heal_target_index := 0     # cel leczenia umiejętności (ONE_ALLY / DEAD_ALLY)
## Kursor drużyny wybiera cel leczenia zamiast postaci: 0 — nie, 1 — żywy sojusznik, 2 — nieprzytomny (wskrzeszenie).
var _ally_pick := 0
var _guard := {}                 # członek drużyny -> dobra odpowiedź przy Obronie (do końca rundy)
## Runda jak w RPG Makerze / FNaFB: najpierw komendy wszystkich postaci po kolei (faza wyboru), potem wykonanie wg AGI.
var _plans: Array[Dictionary] = []   # wybrane akcje rundy: {member, action, skill, enemy, heal[, item]}
var _input_queue: Array[int] = []    # postacie wybierające komendy w tej rundzie (kolejność drużyny)
var _input_pos := -1                 # która z nich wybiera teraz (-1 = Walcz / Uciekaj)
var _executing := false              # faza wykonania (akcje z _plans) — inaczej wybór akcji tylko ją zapisuje
signal _round_question_answered(correct: bool)
signal _notice_confirmed
var _appeared_shown := false               # „X appeared!” na starcie walki już pokazane
var _entry_intro: Control                  # animacja wejścia do walki (nil, gdy wyłączona)
var _awaiting_notice := false             # komunikat w logu czeka na potwierdzenie gracza (Enter / Z / klik)
var _round_questions := false              # pytania rundy przed wykonaniem (odpowiedź zapisana w planie, bez akcji)
var _round_running := false               # faza wykonania rundy trwa (bezpiecznik przed drugim _execute_round)
var _acted_enemies: Dictionary = {}       # indeksy wrogów, którzy już działali w tej rundzie (bezpiecznik: raz na rundę)
var _turn_queue: Array[Dictionary] = []   # reszta rundy: {"party": bool, "index": int}, od najszybszego
var _party_state: Array[Dictionary] = []
var _list_menu_mode: String = ""
var _list_menu_entries: Array[Dictionary] = []
var _list_menu_rows: Array[Control] = []
var _list_selected_idx: int = 0
var _selected_skill_data: Dictionary = {}
var _selected_item_data: Dictionary = {}
var _pending_skill_data: Dictionary = {}
var _target_entries: Array[Dictionary] = []
var _target_rows: Array[PanelContainer] = []
var _target_selected_idx: int = 0
var _hovered_enemy_slot_index: int = -1
var _ps: Node
var _dm: Node
var _gm: Node
var _quiz_panel_controller
var _field_band_h := 0.0   # wysokość zwykłego pasa pod polem bitwy (bez chwilowego wzrostu okna przy dużym pytaniu)
var _band_mode: Band = Band.PARTY_COMMAND
@onready var _corner_label: Label = (party_panel_container.get_node_or_null("CornerInfo") if party_panel_container else null) as Label
## „Wstecz” w rogu okna drużyny (gra samą myszą) — to samo co Esc / PPM, widoczne, gdy jest dokąd wrócić.
@onready var _back_btn: Button = (party_panel_container.get_node_or_null("BackBtn") if party_panel_container else null) as Button
@onready var _top_window: PanelContainer = $TopWindow           # u góry: pytanie quizu + czas albo log bitwy
@onready var _top_vbox: VBoxContainer = $TopWindow/VBox
@onready var _timer_row: HBoxContainer = $TopWindow/VBox/TimerRow
@onready var _log_label: RichTextLabel = $TopWindow/VBox/BattleLog
@onready var _message_window: PanelContainer = $BattleWindow/WindowMargin/VBox/MessageWindow  # po bitwie
@onready var _victory_label: Label = $BattleWindow/WindowMargin/VBox/MessageWindow/VictoryLog
@onready var _more_marker: Polygon2D = $BattleWindow/WindowMargin/VBox/MessageWindow/MoreMarker
var _band_height := 250.0  # wysokość dolnego pasa ze sceny (BattleWindow.offset_top)
var _log_lines: Array[String] = []
var _last_logged := ""


func setup(
	p_enemy: Node2D,
	p_player: Node2D,
	p_quiz_id: String,
	diff_range: Vector2i,
	question_count: int,
	encounter_size_range: Vector2i = Vector2i(1, 1),
	p_joined: Array = []
) -> void:
	enemy = p_enemy
	_joined = p_joined.duplicate()
	player = p_player
	quiz_id = p_quiz_id
	_diff_range = diff_range
	_question_count = question_count
	_encounter_size_range = encounter_size_range
	enemy_hp = p_enemy.hp
	enemy_max_hp = p_enemy.max_hp
	enemy_name_str = p_enemy.localized_name() if p_enemy.has_method("localized_name") else p_enemy.enemy_name
	enemy_base_attack = p_enemy.attack
	enemy_base_defense = p_enemy.defense
	enemy_base_magic_attack = p_enemy.magic_attack
	enemy_base_magic_defense = p_enemy.magic_defense
	enemy_base_agility = int(p_enemy.get("agility")) if p_enemy.get("agility") != null else 15
	_roll_enemy_party()
	if is_node_ready():
		_setup_enemy_display()


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parent_canvas: CanvasLayer = get_parent() as CanvasLayer
	if parent_canvas != null:
		parent_canvas.process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false


## Animacja wejścia do walki (combat_intro.tscn): nakłada się na gotowy ekran walki i odsłania go, gdy obraz jest czarny;
## sam ekran walki w tym czasie „osiada” (lekki najazd kamery), zamiast pojawić się nagle.
func play_entry_transition(snapshot: Image) -> void:
	if snapshot == null or not QuizTheme.combat_intro_enabled():
		return
	var intro := preload("../../scenes/quiz/combat_intro.tscn").instantiate() as Control
	add_child(intro)
	_entry_intro = intro
	intro.covered.connect(_settle_in, CONNECT_ONE_SHOT)
	intro.call("play", snapshot, QuizTheme.combat_intro_style())


func _settle_in() -> void:
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 1.06
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Animacja wyjścia z walki: ta sama „źrenica” co przy wejściu, ale na zrzucie ekranu walki i na warstwie ponad wszystkim
## (przeżywa usunięcie ekranu walki). Wraca, gdy ekran jest czarny — dalej można zwolnić walkę; świat odsłania się sam.
func _play_exit_transition() -> void:
	if not QuizTheme.combat_intro_enabled() or get_viewport() == null:
		return
	var snapshot := get_viewport().get_texture().get_image()
	if snapshot == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	var outro := preload("../../scenes/quiz/combat_intro.tscn").instantiate() as Control
	layer.add_child(outro)
	outro.finished.connect(layer.queue_free)
	outro.call("play", snapshot, QuizTheme.combat_intro_style())
	await outro.covered


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() is CanvasLayer:
		UiLayerScale.attach(get_parent() as CanvasLayer)  # skala UI z opcji na całą warstwę
	theme = QuizTheme.combat_theme()  # większy tekst w walce (QuizTheme.COMBAT_FONT_SIZE), ten sam motyw
	var settings := get_node_or_null("/root/SettingsService")
	if settings and settings.has_signal("module_setting_changed"):
		settings.module_setting_changed.connect(func(module_id: String, key: String, _v: Variant) -> void:
			if module_id == QuizTheme.MODULE_ID and key == QuizTheme.SETTING_COMBAT_COMPACT:
				_set_band_mode(_band_mode)
			elif module_id == QuizTheme.MODULE_ID and key == QuizTheme.SETTING_QUESTION_POSITION:
				_apply_question_position()
			elif module_id == QuizTheme.MODULE_ID and key == QuizTheme.SETTING_LIST_LAYOUT:
				_fit_list_columns())
	_apply_question_position.call_deferred()
	var parent_canvas: CanvasLayer = get_parent() as CanvasLayer
	if parent_canvas != null:
		parent_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var core_mgr = get_node_or_null("/root/CoreManager")
	if core_mgr:
		_ps = core_mgr.get_singleton("PlayerStats")
		_dm = core_mgr.get_singleton("DifficultyManager")
		_gm = core_mgr.get_singleton("GameManager")

	if _ps:
		if _ps.has_signal("hp_changed"):
			_ps.hp_changed.connect(func(_hp: int, _max_hp: int) -> void:
				_update_hp_bars()
				_refresh_stats_panel()
			)
		if _ps.has_signal("party_changed"):
			_ps.party_changed.connect(func() -> void:
				_update_hp_bars()
				_refresh_stats_panel()
			)

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	var ui_scale_service: Node = get_node_or_null(^"/root/UIScaleService")
	if ui_scale_service and ui_scale_service.has_signal("scale_changed"):
		ui_scale_service.scale_changed.connect(func(_f: float) -> void:
			_apply_responsive_layout()
		)

	engage_btn.pressed.connect(_on_engage_pressed)
	run_btn.pressed.connect(_on_run_pressed)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
	engage_btn.mouse_entered.connect(func(): _highlight_action(0))
	run_btn.mouse_entered.connect(func(): _highlight_action(1))
	if exit_btn:
		exit_btn.mouse_entered.connect(func(): _highlight_action(2))
	_action_buttons = [atk_btn, skills_btn, def_btn, items_btn]
	if _back_btn:
		_back_btn.tooltip_text = QuizRpgI18n.t("main_menu.back", "← Wstecz")  # sama strzałka — nie wchodzi na wiersze drużyny
		_back_btn.pressed.connect(func() -> void:
			var back := InputEventAction.new()  # jak Esc: cofa listę / cel / postać / akcje
			back.action = &"ui_cancel"
			back.pressed = true
			_unhandled_input(back))
	atk_btn.pressed.connect(_on_action.bind(Action.ATTACK))
	def_btn.pressed.connect(_on_action.bind(Action.DEFEND))
	skills_btn.pressed.connect(_open_skills_menu)
	items_btn.pressed.connect(_open_items_menu)
	for i in range(_action_buttons.size()):
		var action_index := i
		_action_buttons[i].mouse_entered.connect(func(): _highlight_action(action_index))
	for i in range(party_rows.size()):
		party_rows[i].draw.connect(_draw_party_row_cursor.bind(i))
	# Kursor menu prowadzi ten skrypt (_unhandled_input); fokus Godota na przycisku przejmowałby
	# strzałki / Enter (własna nawigacja fokusu) i rozjeżdżał się z podświetleniem.
	for btn: Button in [engage_btn, run_btn, exit_btn, atk_btn, skills_btn, def_btn, items_btn]:
		if btn:
			btn.focus_mode = Control.FOCUS_NONE

	_setup_party_layout()
	if battle_window:
		_band_height = -battle_window.offset_top
		battle_window.resized.connect(_on_battle_window_resized)
	if window_shadow:
		window_shadow.anchor_left = 0.0
		window_shadow.anchor_right = 1.0
		window_shadow.anchor_top = 1.0
		window_shadow.anchor_bottom = 1.0
		window_shadow.offset_left = 0.0
		window_shadow.offset_right = 0.0
		window_shadow.offset_bottom = 0.0
		window_shadow.grow_horizontal = Control.GROW_DIRECTION_BOTH
		window_shadow.grow_vertical = Control.GROW_DIRECTION_BEGIN
		# Ile cień wystaje nad górną krawędź okna walki (np. WindowShadow.offset_top - BattleWindow.offset_top)
		var overhang: float = absf(window_shadow.offset_top - battle_window.offset_top) if battle_window else 35.0
		if overhang > 0.0 and overhang <= 100.0:
			_shadow_height = overhang
		else:
			_shadow_height = 35.0
	_init_party_state()
	_quiz_panel_controller = QuizPanelController.new()
	_quiz_panel_controller.text_size = QuizTheme.COMBAT_FONT_SIZE
	_quiz_panel_controller.setup(command_vbox, {
		"question_label": $TopWindow/VBox/QuestionLabel,
		"timer_label": $TopWindow/VBox/TimerRow/TimerLabel,
		"timer_bar": $TopWindow/VBox/TimerRow/TimerBar,
		"result_label": result_label,
		"correct_answer_label": $TopWindow/VBox/CorrectAnswerLabel,
	})
	_quiz_panel_controller.answered.connect(_on_quiz_answered)
	_quiz_panel_controller.show_index_prefix = false
	_quiz_panel_controller.selection_styler = func(btn: Button, selected: bool) -> void:
		QuizTheme.set_menu_item_selected(btn, selected)

	if battle_background and battle_background.has_signal("layout_changed"):
		if not battle_background.layout_changed.is_connected(_on_battle_background_layout_changed):
			battle_background.layout_changed.connect(_on_battle_background_layout_changed)
	if battle_background and battle_background.has_method("set_context"):
		battle_background.call("set_context", _find_current_map_node(), enemy, player, _enemy_units)
	player_name_label.text = _ps.player_name if _ps else "Bohater"
	_setup_battlefield_visuals()
	_setup_enemy_display()
	_apply_responsive_layout()
	_refresh_enemy_header()
	_refresh_stats_panel()
	_update_hp_bars()

	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and cheat_service.has_signal("instant_win_triggered"):
		cheat_service.instant_win_triggered.connect(trigger_instant_win)

	var audio := get_node_or_null("/root/AudioService")
	if audio:
		if _is_boss_encounter():
			var bname := ""
			if enemy.get("enemy_id") != null:
				bname = str(enemy.get("enemy_id"))
			elif enemy.get("enemy_name") != null:
				bname = str(enemy.get("enemy_name")).to_lower()
			audio.start_boss_music(bname if bname != "" else "battle_boss")
		else:
			audio.play_music("battle")

	_roll_initiative()
	_start_round()


func trigger_instant_win() -> void:
	if phase == Phase.COMBAT_END:
		return
	for unit in _enemy_units:
		unit["hp"] = 0
	enemy_hp = 0
	_update_hp_bars()
	_refresh_enemy_header()
	_refresh_stats_panel()
	_end_combat(true)


func _process(delta: float) -> void:
	if _is_pause_menu_open():
		return
	if _quiz_panel_controller:
		_quiz_panel_controller.tick(delta)
	_update_corner_label()
	_update_top_window()
	if _back_btn:
		_back_btn.visible = _list_menu_mode != "" or phase == Phase.TARGET_SELECT 				or (phase == Phase.ACTION_SELECT and (_actor_select_open or _action_menu_open))


## Mysz nie działa w walce, gdy okno nie ma fokusu (np. po przełączeniu na Discorda), a kliknięcie, które tylko przywraca fokus
## (przychodzi już po NOTIFICATION_APPLICATION_FOCUS_IN), jest ignorowane przez FOCUS_CLICK_GRACE_MSEC (feedback testów pre-alpha, pkt 6).
const FOCUS_CLICK_GRACE_MSEC := 300
var _window_focused := true  # tylko FOCUS_OUT ustawia false, więc brak powiadomień nie blokuje myszy
var _focus_in_msec := -100000


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
		_focus_in_msec = Time.get_ticks_msec()


func _settle_input() -> void:
	_input_settle_until = Time.get_ticks_msec() + INPUT_SETTLE_MSEC


## Naciśnięcie (klawisz, przycisk myszy) w czasie INPUT_SETTLE_MSEC po zmianie stanu walki.
func _is_settling_press(event: InputEvent) -> bool:
	if Time.get_ticks_msec() >= _input_settle_until:
		return false
	if event is InputEventKey:
		return event.pressed and not event.echo
	return event is InputEventMouseButton and event.pressed


## Zdarzenie myszy do zignorowania: okno bez fokusu albo kliknięcie tuż po odzyskaniu fokusu.
func _is_focus_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return false
	if not _window_focused:
		return true
	return event is InputEventMouseButton and event.pressed and Time.get_ticks_msec() - _focus_in_msec < FOCUS_CLICK_GRACE_MSEC


func _input(event: InputEvent) -> void:
	if _is_pause_menu_open():
		return
	if _is_focus_click(event) or _is_settling_press(event):
		get_viewport().set_input_as_handled()
		return
	if _is_right_click(event):  # przyciski łapią mysz przed _unhandled_input — PPM (wstecz) obsługujemy od razu
		_unhandled_input(event)
		get_viewport().set_input_as_handled()
		return
	if _typing and (_is_menu_accept(event) or (event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)):
		_type_skip = true  # dopisuje tekst do końca, nie zatwierdza komunikatu
		get_viewport().set_input_as_handled()
		return
	if _awaiting_notice and (_is_menu_accept(event) or (event is InputEventMouseButton and event.pressed 			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)):
		confirm_notice()
		get_viewport().set_input_as_handled()
		return
	if _handle_hovered_enemy_click(event) or _handle_actor_row_mouse(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_pause_menu_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if OS.is_debug_build() and key_event.keycode == KEY_F9:
			trigger_instant_win()
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.COMBAT_END and event.is_action_pressed("ui_accept"):
		_victory_skip = true
		get_viewport().set_input_as_handled()
		return
	if _list_menu_mode != "":
		var cols: int = maxi(list_grid.columns, 1)
		if _is_menu_down(event):
			_navigate_list(cols)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_up(event):
			_navigate_list(-cols)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right") or _is_key_pressed(event, [KEY_D]):
			_navigate_list(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_left") or _is_key_pressed(event, [KEY_A]):
			_navigate_list(-1)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_accept(event):
			_confirm_list_selection()
			get_viewport().set_input_as_handled()
			return
		if _is_menu_cancel(event):
			_close_list_menu()
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.TARGET_SELECT:
		# Siatka 2 kolumn: góra / dół o wiersz, lewo / prawo o jedną pozycję.
		if _is_menu_down(event):
			_navigate_target_list(maxi(target_list_vbox.columns, 1))
			get_viewport().set_input_as_handled()
			return
		if _is_menu_up(event):
			_navigate_target_list(-maxi(target_list_vbox.columns, 1))
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right") or _is_key_pressed(event, [KEY_D]):
			_navigate_target_list(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_left") or _is_key_pressed(event, [KEY_A]):
			_navigate_target_list(-1)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_accept(event):
			_confirm_target_selection()
			get_viewport().set_input_as_handled()
			return
		if _is_menu_cancel(event):
			_cancel_target_selection()
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.ACTION_SELECT and _actor_select_open:
		if _is_menu_down(event):
			_navigate_actor_list(1)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_up(event):
			_navigate_actor_list(-1)
			get_viewport().set_input_as_handled()
			return
		if _is_menu_accept(event):
			_confirm_actor_selection()
			get_viewport().set_input_as_handled()
			return
		if _is_menu_cancel(event):
			_cancel_actor_selection()
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.ACTION_SELECT:
		var menu_count := _get_visible_action_count()
		if _is_action_menu_next(event):
			_selected_action_idx = (_selected_action_idx + 1) % menu_count
			_highlight_action(_selected_action_idx)
			get_viewport().set_input_as_handled()
			return
		if _is_action_menu_prev(event):
			_selected_action_idx = (_selected_action_idx - 1 + menu_count) % menu_count
			_highlight_action(_selected_action_idx)
			get_viewport().set_input_as_handled()
			return
		if _action_menu_open and _is_menu_cancel(event):
			_prior_input()   # poprzednia postać albo Walcz / Uciekaj
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept"):
			if _action_menu_open:
				_get_visible_action_buttons()[_selected_action_idx].emit_signal("pressed")
			else:
				_get_visible_primary_buttons()[_selected_action_idx].emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return
	if phase == Phase.QUIZ and _quiz_panel_controller and _quiz_panel_controller.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if _is_menu_cancel(event) and not _is_right_click(event):  # PPM tylko cofa, pauzy nie otwiera
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return


func _handle_hovered_enemy_click(event: InputEvent) -> bool:
	if phase != Phase.TARGET_SELECT:
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	# Wróg pod kursorem liczony z pozycji kliknięcia (prostokąty slotów) — bez zależności od sygnałów najechania, które
	# gubiły się, gdy coś przykryło slot; ostatnio najechany tylko gdy kursor nie trafia w żaden slot.
	var slot_index := _enemy_slot_at(mouse_event.position)
	if slot_index < 0:
		slot_index = _hovered_enemy_slot_index
	if slot_index < 0:
		return false
	var hovered_target_index: int = _find_target_row_index_for_enemy(slot_index)
	if hovered_target_index < 0:
		return false
	_target_selected_idx = hovered_target_index
	_refresh_target_selection()
	_confirm_target_selection()
	return true


## Indeks żywego wroga, którego slot (wrapper ze sprite'em) zawiera punkt ekranu `screen_pos` — przy nakładających się
## slotach ten, którego środek jest najbliżej; -1 = żaden.
func _enemy_slot_at(screen_pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in range(mini(_enemy_units.size(), _enemy_wrapper_pool.size())):
		if int(_enemy_units[i].get("hp", 0)) <= 0:
			continue
		for key in ["wrapper", "slot"]:
			var c := _enemy_wrapper_pool[i].get(key) as Control
			if c == null or not c.is_visible_in_tree():
				continue
			var local: Vector2 = c.get_global_transform_with_canvas().affine_inverse() * screen_pos
			if Rect2(Vector2.ZERO, c.size).has_point(local):
				var d := local.distance_squared_to(c.size * 0.5)
				if d < best_d:
					best_d = d
					best = i
	return best


## Runda jak w RPG Makerze / FNaFB (decyzja usera 2026-10-16): faza wyboru — Walcz / Uciekaj, potem komendy każdej
## postaci po kolei (kolejność drużyny; Esc wraca do poprzedniej), potem faza wykonania — wszyscy (drużyna i wrogowie)
## raz, po kolei wg prędkości = AGI + losowo 0..4 + AGI / 4 (jak FNaFB / RPG Maker VX Ace, losowana co rundę);
## Obrona przed wszystkimi (jak Guard w RPG Makerze), przy równej prędkości drużyna przed wrogami. Pytanie quizu
## i koszt akcji — w ruchu postaci. 1. runda jak w FNaFB: przy zaskoczeniu drużyna ją traci (bez wyboru komend),
## przy przewadze tracą ją wrogowie. Na koniec rundy statusy.
func _start_round() -> void:
	turn_number += 1
	_begin_input()


## Faza wyboru: Walcz / Uciekaj; postacie zdolne do ruchu (bez snu / ogłuszenia / paraliżu) w kolejności drużyny.
func _begin_input() -> void:
	if turn_number == 1 and not _appeared_shown:
		await _show_appeared_window()
	_executing = false
	_round_running = false
	_plans.clear()
	_guard.clear()
	_input_queue.clear()
	var surprised := turn_number == 1 and _initiative == Initiative.SURPRISE  # zaskoczenie: drużyna traci 1. rundę
	for i in _party_indices(false):
		if i < party_rows.size() and not _member_cannot_act(i) and not surprised:
			_input_queue.append(i)
	_input_pos = -1
	_selected_skill_data.clear()
	_selected_item_data.clear()
	_pending_skill_data.clear()
	_quiz_panel_controller.reset_question()
	_set_quiz_layout_active(false)
	_clear_battle_log()
	if turn_number == 1:
		_push_initiative_notice()
	if turn_label:
		turn_label.text = QuizRpgI18n.tf("combat.turn_number", {"turn": turn_number}, "Tura {turn}")
	if streak_label and _ps:
		streak_label.text = "Seria: %d | RNG: +%.0f%%" % [_ps.streak, _ps.rng_bonus * 100.0]
	result_label.visible = false
	_refresh_enemy_header()
	_refresh_stats_panel()
	if _input_queue.is_empty():
		if surprised:
			await _wait_notice_confirm()  # „Zaskoczenie!” — gracz musi to przeczytać, zanim wrogowie ruszą
		_execute_round()
		return
	phase = Phase.ACTION_SELECT
	action_panel.visible = true
	_set_action_buttons_enabled(true)
	_show_primary_menu()
	_highlight_action(0)
	_refresh_actor_selection()


func _member_cannot_act(i: int) -> bool:
	return _ps != null and _ps.has_method("member_has_restriction") and _ps.member_has_restriction(i, QuizRpgStatusData.Restriction.SKIP_TURN)


## Komendy następnej postaci; po ostatniej — wykonanie rundy.
func _next_input() -> void:
	_input_pos += 1
	if _input_pos >= _input_queue.size():
		_execute_round()
		return
	_open_member_commands(_input_queue[_input_pos])


## Esc w komendach postaci: poprzednia postać (jej wybór kasowany) albo, przy pierwszej, Walcz / Uciekaj.
func _prior_input() -> void:
	if _input_pos > 0:
		_input_pos -= 1
		var m := _input_queue[_input_pos]
		for k in range(_plans.size() - 1, -1, -1):
			if int(_plans[k]["member"]) == m:
				_plans.remove_at(k)
		_open_member_commands(m)
		return
	_input_pos = -1
	_show_primary_menu()
	_highlight_action(0)
	_refresh_actor_selection()


func _open_member_commands(m: int) -> void:
	_active_actor_index = m
	_selected_skill_data.clear()
	_selected_item_data.clear()
	_pending_skill_data.clear()
	phase = Phase.ACTION_SELECT
	if turn_label:
		turn_label.text = QuizRpgI18n.tf("combat.turn_member", {"turn": turn_number, "name": _member_name(m)}, "Tura {turn} - {name}")
	action_panel.visible = true
	_set_action_buttons_enabled(true)
	_show_action_menu()
	_highlight_action(0)
	_refresh_actor_selection()


## Wybór akcji w fazie wyboru (zamiast pytania): zapis do _plans, dalej następna postać.
func _commit_plan(extra: Dictionary = {}) -> void:
	var plan := {"member": _active_actor_index, "action": chosen_action, "skill": _selected_skill_data.duplicate(true),
		"enemy": _active_enemy_index, "heal": _heal_target_index}
	plan.merge(extra, true)
	_plans.append(plan)
	_selected_skill_data.clear()
	_pending_skill_data.clear()
	_selected_item_data.clear()
	_hide_target_panel()
	_next_input()


func _plan_for(member: int) -> Dictionary:
	for plan in _plans:
		if int(plan["member"]) == member:
			return plan
	return {}


## Faza wykonania: kolejka wg AGI z wybranymi akcjami.
func _execute_round() -> void:
	if _round_running:
		push_warning("QuizCombat: runda %d już trwa — drugie wykonanie pominięte" % turn_number)
		return
	_round_running = true
	_executing = true
	_close_actor_select()
	phase = Phase.ENEMY_TURN
	_set_band_mode(Band.STATUS_ONLY)
	_refresh_actor_selection()
	for unit in _enemy_units:  # akcje wrogów na tę rundę (jak w RPG Makerze) — prędkość umiejętności w kolejce
		unit["planned_skill"] = _pick_enemy_skill(unit) if int(unit.get("hp", 0)) > 0 else null
	await _ask_round_questions()
	_turn_queue = _turn_order()
	_acted_enemies.clear()
	_next_turn()


## Komunikat w logu czeka na gracza (decyzja usera 2026-10-21: zaskoczenie wymaga potwierdzenia): podpowiedź w logu,
## dalej po Enter / Z / kliknięciu (confirm_notice).
func _wait_notice_confirm() -> void:
	phase = Phase.ENEMY_TURN
	if action_panel:
		action_panel.visible = false
	_push_log(QuizRpgI18n.t("log.combat.press_continue", "Enter / Z / klik — dalej"), Color(0.7, 0.72, 0.82))
	_awaiting_notice = true
	await _notice_confirmed


func confirm_notice() -> void:
	if not _awaiting_notice:
		return
	_awaiting_notice = false
	_notice_confirmed.emit()


## Pytania rundy (decyzja usera 2026-10-21): po wyborze akcji całej drużyny najpierw pytania quizu — po jednym na
## postać, w kolejności drużyny — a dopiero potem akcje wg AGI z zapisanym wynikiem (plan["correct"]). Przedmioty bez
## pytania; postać, która nie może się ruszyć, też bez pytania.
func _ask_round_questions() -> void:
	for plan in _plans:
		var i := int(plan["member"])
		if plan.has("item") or plan.has("correct") or _member_hp(i) <= 0 or _member_cannot_act(i):
			continue
		_active_actor_index = i
		_refresh_actor_selection()
		_clear_battle_log()
		if turn_number == 1:
			_push_initiative_notice()
		if turn_label:
			turn_label.text = QuizRpgI18n.tf("log.combat.turn_question", {"turn": turn_number, "name": _member_name(i)}, "Tura {turn} - pytanie: {name}")
		_refresh_stats_panel()
		plan["correct"] = await _ask_plan_question(int(plan["enemy"]))


## Jedno pytanie rundy -> czy dobra odpowiedź (bez pytań / pusta pula — zaliczone jak dotąd).
func _ask_plan_question(enemy_index: int) -> bool:
	phase = Phase.QUIZ
	_set_action_buttons_enabled(false)
	var allowed_types: Array = _get_combat_quiz_types(enemy_index)
	if _should_auto_resolve_quiz(allowed_types):
		return true
	var qm := _get_quiz_manager()
	var q: Dictionary = qm.start_quiz(quiz_id, _diff_range, 1, allowed_types) if qm and qm.has_method("start_quiz") else {}
	if q.is_empty():
		return true
	if action_panel:
		action_panel.visible = false
	if actor_command_panel:
		actor_command_panel.visible = false
	_round_questions = true
	_show_question(q)
	var correct: bool = await _round_question_answered
	_round_questions = false
	_quiz_panel_controller.hide_quiz()
	_set_quiz_layout_active(false)
	return correct


func _turn_order() -> Array[Dictionary]:
	var first_round := turn_number <= 1
	var order: Array[Dictionary] = []
	for i in _party_indices(false):
		if i < party_rows.size():
			order.append({"party": true, "index": i, "speed": _roll_speed(int(_member_stats(i)["agi"])) + _plan_speed(_plan_for(i))})
	if not (first_round and _initiative == Initiative.PREEMPTIVE):
		for i in range(_enemy_units.size()):
			if int(_enemy_units[i].get("hp", 0)) > 0:
				var planned: Variant = _enemy_units[i].get("planned_skill")
				var skill_speed: int = (planned as QuizRpgEnemySkill).speed if planned is QuizRpgEnemySkill else 0
				order.append({"party": false, "index": i, "speed": _roll_speed(int(_unit_stats(_enemy_units[i])["agi"])) + skill_speed})
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["speed"]) != int(b["speed"]):
			return int(a["speed"]) > int(b["speed"])
		if bool(a["party"]) != bool(b["party"]):
			return bool(a["party"])
		return int(a["index"]) < int(b["index"]))
	return order


## Dodatek prędkości wybranej akcji: Obrona GUARD_SPEED, umiejętność — jej speed (jak w FNaFB).
func _plan_speed(plan: Dictionary) -> int:
	if plan.is_empty():
		return 0
	if int(plan["action"]) == Action.DEFEND:
		return GUARD_SPEED
	var skill := (plan["skill"] as Dictionary).get("resource") as QuizRpgSkillBase
	return skill.speed if skill != null else 0


## Prędkość w rundzie jak w FNaFB (RPG Maker VX Ace Game_Action#speed): AGI + rand(5 + AGI / 4).
static func _roll_speed(agi: int) -> int:
	return agi + randi_range(0, 4 + maxi(agi, 0) / 4)


## Przewaga / zaskoczenie na start walki jak w FNaFB (VX Ace: rate_preemptive / rate_surprise): drużyna co najmniej
## tak szybka jak wrogowie — przewaga 5 %, zaskoczenie 3 %; wolniejsza — 3 % / 5 %. Zaskoczenie tylko bez przewagi.
func _roll_initiative() -> void:
	_initiative = Initiative.NONE
	if _is_boss_encounter():
		return
	var faster := _average_agi(true) >= _average_agi(false)
	if randf() < (preemptive_rate_faster if faster else preemptive_rate_slower):
		_initiative = Initiative.PREEMPTIVE
	elif randf() < (surprise_rate_faster if faster else surprise_rate_slower):
		_initiative = Initiative.SURPRISE


func _average_agi(party: bool) -> float:
	var total := 0.0
	var count := 0
	if party:
		for i in _party_indices(false):
			total += float(_member_stats(i)["agi"])
			count += 1
	else:
		for u in _enemy_units:
			if int(u.get("hp", 0)) > 0:
				total += float(_unit_stats(u)["agi"])
				count += 1
	return maxf(total / maxi(count, 1), 1.0)


## Komunikat 1. rundy (przewaga / zaskoczenie) — w logu na start i po wyczyszczeniu logu przed ruchem postaci.
## „X appeared!” na starcie walki (jak w FNaFB): dolny pas zamiast menu walki, jedna linia na rodzaj wroga, kopie jako
## „Nazwa ×N”. Czeka na zatwierdzenie gracza (Enter / Z / klik), potem okna walki wjeżdżą po kolei (fade ze stopniowaniem).
func _show_appeared_window() -> void:
	_appeared_shown = true
	var counts := {}
	for unit in _enemy_units:
		var src: Variant = unit.get("source", enemy)
		var base: String = src.localized_name() if is_instance_valid(src) and src.has_method("localized_name") else enemy_name_str
		counts[base] = int(counts.get(base, 0)) + 1
	var lines: Array[String] = []
	for base: String in counts:
		var label: String = base if int(counts[base]) == 1 else "%s ×%d" % [base, int(counts[base])]
		lines.append(QuizRpgI18n.tf("log.combat.appeared", {"name": label}, "{name} pojawił się!"))
	phase = Phase.ENEMY_TURN
	# Układ okien musi się ustalić (pomiar wysokości dolnego pasa w _get_or_create_victory_log).
	await get_tree().process_frame
	await get_tree().process_frame
	var lbl := _get_or_create_victory_log()
	lbl.text = "\n".join(lines)
	lbl.visible_characters = 0
	lbl.visible = true
	_message_window.modulate.a = 0.0
	if is_instance_valid(_entry_intro):
		await _entry_intro.finished  # najpierw pole walki wyłania się z czerni, dopiero potem okna (jak w FNaFB)
	await _fade_in_message_window()
	await _type_label(lbl)
	_set_more_marker(true)
	_awaiting_notice = true
	await _notice_confirmed
	_set_more_marker(false)
	var fade_out := create_tween()
	fade_out.tween_property(_message_window, "modulate:a", 0.0, 0.2)
	await fade_out.finished
	_message_window.visible = false
	_message_window.modulate.a = 1.0
	lbl.text = ""
	if content_row == null:
		return
	content_row.visible = true
	var windows: Array[Control] = []
	for c in content_row.get_children():
		if c is Control and (c as Control).visible:
			windows.append(c as Control)
			(c as Control).modulate.a = 0.0
	var fade_in := create_tween().set_parallel(true)
	for i in range(windows.size()):
		fade_in.tween_property(windows[i], "modulate:a", 1.0, 0.3).set_delay(i * 0.06) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _push_initiative_notice() -> void:
	match _initiative:
		Initiative.PREEMPTIVE:
			_push_log(QuizRpgI18n.t("log.combat.preemptive", "Przewaga! Potwory nie zdążą zareagować w tej turze."), Color(0.55, 0.95, 0.55))
		Initiative.SURPRISE:
			_push_log(QuizRpgI18n.t("log.combat.surprise", "Zaskoczenie! Drużyna traci pierwszą turę."), Color(1.0, 0.55, 0.35))


## Następny w kolejce rundy: członek drużyny dostaje komendy (dalej po jego akcji — znów _next_turn), wróg działa od
## razu. Pusta kolejka = koniec rundy.
func _next_turn() -> void:
	while true:
		if _all_enemies_defeated():
			_end_combat(true)
			return
		if _ps and _ps.is_party_defeated():
			_end_combat(false)
			return
		if _turn_queue.is_empty():
			break
		var entry: Dictionary = _turn_queue.pop_front()
		var i := int(entry["index"])
		if bool(entry["party"]):
			var plan := _plan_for(i)
			if _member_hp(i) > 0 and not plan.is_empty():
				_start_member_action(i, plan)
				return
			continue
		if _acted_enemies.has(i):
			push_warning("QuizCombat: wróg %d (%s) już działał w turze %d — drugi ruch pominięty" % [i, _enemy_units[i].get("name", "?"), turn_number])
			continue
		_acted_enemies[i] = true
		if int(_enemy_units[i].get("hp", 0)) > 0 and await _enemy_act(i):
			return
	_regen_party_tp()
	if await _apply_status_round():
		return
	_start_round()


## Ruch członka drużyny w fazie wykonania: akcja wybrana w fazie wyboru — koszt, pytanie i wynik; sen / ogłuszenie /
## paraliż (np. nałożony w tej rundzie) — traci ruch.
func _start_member_action(i: int, plan: Dictionary) -> void:
	_active_actor_index = i
	_quiz_panel_controller.reset_question()
	_set_quiz_layout_active(false)
	_clear_battle_log()
	if turn_number == 1:
		_push_initiative_notice()
	if turn_label:
		turn_label.text = QuizRpgI18n.tf("log.combat.turn_move", {"turn": turn_number, "name": _member_name(i)}, "Tura {turn} - ruch: {name}")
	result_label.visible = false
	_refresh_enemy_header()
	_refresh_stats_panel()
	phase = Phase.PLAYER_RESULT
	_set_band_mode(Band.STATUS_ONLY)
	if _member_cannot_act(i):
		result_label.visible = true
		result_label.text = QuizRpgI18n.tf("log.combat.member_cannot_move", {"name": _member_name(i)}, "{name} nie może się ruszyć!")
		result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
		await get_tree().create_timer(1.2).timeout
		_next_turn()
		return
	chosen_action = plan["action"]
	_selected_skill_data = (plan["skill"] as Dictionary).duplicate(true)
	_active_enemy_index = int(plan["enemy"])
	_heal_target_index = int(plan["heal"])
	if plan.has("item"):
		_use_item(plan["item"])
		return
	if not _selected_skill_data.is_empty():
		_consume_skill_cost(_selected_skill_data)
	if plan.has("correct"):  # odpowiedź z pytań rundy (_ask_round_questions)
		_resolve_action(bool(plan["correct"]))
		return
	_begin_action_quiz()


func _on_action(action: Action) -> void:
	if phase != Phase.ACTION_SELECT:
		return
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("click")
	chosen_action = action
	if action == Action.FLEE:
		_start_flee()
		return
	if action == Action.ATTACK:
		_open_target_menu()
		return
	_begin_action_quiz()


func _open_skills_menu() -> void:
	if phase != Phase.ACTION_SELECT:  # dwa kliknięcia naraz (np. Atak + Umiejętności): wybór celu już trwa
		return
	if _ps and _ps.has_method("member_has_restriction") and _ps.member_has_restriction(_active_actor_index, QuizRpgStatusData.Restriction.SILENCED):
		result_label.visible = true
		result_label.text = QuizRpgI18n.tf("log.combat.silenced", {"name": _member_name(_active_actor_index)}, "{name}: cisza — umiejętności zablokowane.")
		result_label.add_theme_color_override("font_color", QuizRpgStatusCatalog.color_of("silence"))
		return
	var entries: Array[Dictionary] = []
	if _ps and _ps.has_method("get_member_battle_skills"):
		entries = _ps.get_member_battle_skills(_active_actor_index)  # tylko skille w slotach (+ skan)
	_open_list_menu("skills", entries)


func _open_items_menu() -> void:
	if phase != Phase.ACTION_SELECT:  # dwa kliknięcia naraz (np. Atak + Umiejętności): wybór celu już trwa
		return
	var entries: Array[Dictionary] = []
	if _ps and _ps.has_method("get_inventory_entries"):
		for it in _ps.get_inventory_entries():
			if it is Dictionary and str(it.get("category", "item")) == "item":
				entries.append(it)
	_open_list_menu("items", entries)


## Lista w dolnym pasie zamiast okna komend postaci (okno drużyny zostaje obok); pole bitwy widoczne.
func _open_list_menu(mode: String, entries: Array[Dictionary]) -> void:
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("click")
	_list_menu_mode = mode
	_list_menu_entries = entries
	_list_selected_idx = 0
	_build_list_menu(entries, mode == "skills")
	_set_band_mode(Band.LIST)
	_refresh_list_selection()


func _close_list_menu() -> void:
	_list_menu_mode = ""
	_list_menu_entries.clear()
	_list_menu_rows.clear()
	if list_panel:
		list_panel.visible = false
	if help_label:
		help_label.visible = false
	if action_panel:
		action_panel.visible = true
	_show_action_menu()
	_highlight_action(0)


func _open_target_menu() -> void:
	phase = Phase.TARGET_SELECT
	_hovered_enemy_slot_index = -1
	_target_entries.clear()
	_target_rows.clear()
	for child in target_list_vbox.get_children():
		child.queue_free()
	for enemy_index in range(_enemy_units.size()):
		var enemy_unit: Dictionary = _enemy_units[enemy_index]
		if int(enemy_unit.get("hp", 0)) <= 0:
			continue
		_target_entries.append({
			"enemy_index": enemy_index,
			"name": str(enemy_unit.get("name", enemy_name_str)),
			"hp": int(enemy_unit.get("hp", 0)),
			"max_hp": int(enemy_unit.get("max_hp", 1)),
			"level": int(enemy_unit.get("level", 0)),
		})
	_target_selected_idx = 0
	target_list_vbox.columns = mini(2, maxi(_target_entries.size(), 1))
	_build_target_menu()
	party_panel_container.visible = true
	_show_target_panel()


func _build_target_menu() -> void:
	target_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	target_list_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	for entry in _target_entries:
		var row := TargetRowScene.instantiate() as PanelContainer
		var row_margin := row.get_node("Margin") as MarginContainer
		(row.get_node("Margin/Content/Name") as Label).text = str(entry.get("name", enemy_name_str))  # HP wroga pokazuje Skan, nie lista celów
		var lvl := int(entry.get("level", 0))
		var level_text := row.get_node("Margin/Content/Level") as Label
		level_text.visible = lvl > 0  # poziom wroga (mapa: "enemy_levels"); bez poziomu (samouczek) — bez znacznika
		level_text.text = QuizRpgI18n.tf("combat.level_short", {"level": lvl}, "Lv {level}")
		var row_index: int = _target_rows.size()
		row.gui_input.connect(func(event: InputEvent): _on_target_row_gui_input(event, row_index))
		row.mouse_entered.connect(func(): _on_target_row_hover(row_index))
		row_margin.gui_input.connect(func(event: InputEvent): _on_target_row_gui_input(event, row_index))
		row_margin.mouse_entered.connect(func(): _on_target_row_hover(row_index))
		target_list_vbox.add_child(row)
		_target_rows.append(row)
	_refresh_target_selection()


func _show_target_panel() -> void:
	if action_panel:
		action_panel.visible = false
	if actor_command_panel:
		actor_command_panel.visible = false
	_quiz_panel_controller.hide_quiz()
	result_label.visible = false
	for row in party_rows:
		if row:
			row.visible = false
	if target_panel:
		target_panel.visible = true
	if target_label:
		target_label.text = "Wybierz cel"


func _hide_target_panel() -> void:
	target_panel.visible = false
	_hovered_enemy_slot_index = -1
	for child in target_list_vbox.get_children():
		child.queue_free()
	_target_entries.clear()
	_target_rows.clear()


func _navigate_target_list(delta: int) -> void:
	if _target_rows.is_empty():
		return
	_target_selected_idx = posmod(_target_selected_idx + delta, _target_rows.size())
	_refresh_target_selection()
	_refresh_enemy_slot_highlight()


func _refresh_target_selection() -> void:
	# zaznaczony wiersz celu — zaznaczenie motywu (jak w menu), pozostałe bez tła
	var active_style := QuizTheme.theme().get_stylebox(&"selected", QuizTheme.MENU_ITEM)
	var inactive_style := StyleBoxEmpty.new()
	for i in range(_target_rows.size()):
		var row: PanelContainer = _target_rows[i]
		if i == _target_selected_idx:
			row.add_theme_stylebox_override("panel", active_style)
		else:
			row.add_theme_stylebox_override("panel", inactive_style)


func _on_target_row_hover(index: int) -> void:
	if index < 0 or index >= _target_rows.size():
		return
	_target_selected_idx = index
	_refresh_target_selection()
	_refresh_enemy_slot_highlight()


func _on_target_row_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseMotion:
		if index < 0 or index >= _target_rows.size():
			return
		_target_selected_idx = index
		_refresh_target_selection()
		_refresh_enemy_slot_highlight()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if index < 0 or index >= _target_rows.size():
		return
	_target_selected_idx = index
	_refresh_target_selection()
	_confirm_target_selection()


func _confirm_target_selection() -> void:
	if _target_selected_idx < 0 or _target_selected_idx >= _target_entries.size():
		return
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("click")
	var entry: Dictionary = _target_entries[_target_selected_idx]
	if bool(_pending_skill_data.get("scan", false)):
		_scan_enemy(int(entry.get("enemy_index", 0)))
		return
	_active_enemy_index = int(entry.get("enemy_index", 0))
	if not _pending_skill_data.is_empty():
		_selected_skill_data = _pending_skill_data.duplicate(true)
		_consume_skill_cost(_selected_skill_data)
		_pending_skill_data.clear()
	else:
		_selected_skill_data.clear()
	_hide_target_panel()
	_begin_action_quiz()


## Skan (jak w FNaFB CC): nazwa i HP wroga oraz jego opis (scan_text) albo statystyki i umiejętności — w logu u góry.
## Nie zużywa tury ani kosztu: wraca do menu postaci.
func _scan_enemy(enemy_index: int) -> void:
	var unit: Dictionary = _enemy_units[enemy_index]
	var src: Variant = unit.get("source", enemy)
	var text := ""
	if src != null:
		if src.has_method("localized_scan_text"):
			text = src.localized_scan_text()
		elif src.get("scan_text") != null:
			text = str(src.get("scan_text"))
	if text.strip_edges() == "":
		var skill_names: Array[String] = []
		for sk in (src.get("battle_skills") if src != null and src.get("battle_skills") != null else []):
			skill_names.append(sk.localized_name())
		text = "ATK %d · DEF %d · MAT %d · MDF %d · AGI %d" % [int(unit.get("atk", 0)), int(unit.get("def", 0)), int(unit.get("mat", 0)), int(unit.get("mdf", 0)), int(unit.get("agi", 0))]
		if not skill_names.is_empty():
			text += "\n" + QuizRpgI18n.t("combat.skills_colon", "Umiejętności: ") + ", ".join(skill_names)
	var level: int = int(src.get("enemy_level")) if src != null and src.get("enemy_level") != null else 0
	_push_log("%s%s — HP %d/%d" % [str(unit.get("name", "?")), " (lv %d)" % level if level > 0 else "", int(unit.get("hp", 0)), int(unit.get("max_hp", 1))], Color(0.55, 0.85, 1.0))
	_push_log(text, Color.WHITE)
	_pending_skill_data.clear()
	_selected_skill_data.clear()
	_hide_target_panel()
	phase = Phase.ACTION_SELECT
	_refresh_stats_panel()
	action_panel.visible = true
	_show_action_menu()
	_highlight_action(0)


func _cancel_target_selection() -> void:
	_pending_skill_data.clear()
	_selected_skill_data.clear()
	_hide_target_panel()
	phase = Phase.ACTION_SELECT
	_refresh_stats_panel()
	action_panel.visible = true
	_show_action_menu()
	_highlight_action(0)


func _get_quiz_manager() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root and main_loop.root.has_node("QuizManager"):
		return main_loop.root.get_node("QuizManager")
	return null


func _begin_action_quiz() -> void:
	if not _executing:
		_commit_plan()  # faza wyboru: akcja zapisana, pytanie w ruchu postaci
		return
	_hide_target_panel()
	phase = Phase.QUIZ
	_set_action_buttons_enabled(false)
	var allowed_types: Array = _get_combat_quiz_types()
	if _should_auto_resolve_quiz(allowed_types):
		_resolve_action(true)
		return
	var qm := _get_quiz_manager()
	var q: Dictionary = qm.start_quiz(quiz_id, _diff_range, 1, allowed_types) if qm and qm.has_method("start_quiz") else {}
	if q.is_empty():
		_resolve_action(true)
		return
	if action_panel:
		action_panel.visible = false
	if actor_command_panel:
		actor_command_panel.visible = false
	_show_question(q)


## Typy pytania dla tury: złożone z szansą zależną od tieru atakowanego przeciwnika (enemy_index; brak = aktywny),
## inaczej proste. Gdy w wylosowanej grupie nie ma pytań (zestaw ma np. tylko wybór), pytanie z drugiej — walka
## nie zalicza się sama.
func _get_combat_quiz_types(enemy_index := -1) -> Array:
	var complex_first := randf() < _complex_chance(_enemy_tier(enemy_index))
	var first: Array = QUIZ_TYPES_COMPLEX if complex_first else QUIZ_TYPES_SIMPLE
	var second: Array = QUIZ_TYPES_SIMPLE if complex_first else QUIZ_TYPES_COMPLEX
	var qm := _get_quiz_manager()
	if qm == null or not qm.has_method("get_questions"):
		return first.duplicate()
	for types: Array in [first, second]:
		if not (qm.get_questions(quiz_id, _diff_range, 1, types) as Array).is_empty():
			return types.duplicate()
	return first.duplicate()


static func _complex_chance(tier: int) -> float:
	return minf(float(maxi(tier, 1)) * COMPLEX_CHANCE_PER_TIER, COMPLEX_CHANCE_MAX)


## Tier przeciwnika o danym indeksie (jednostki walki); poza zakresem — tier spotkania.
func _enemy_tier(enemy_index: int) -> int:
	var idx := _active_enemy_index if enemy_index < 0 else enemy_index
	if idx >= 0 and idx < _enemy_units.size():
		return int(_enemy_units[idx].get("tier", 1))
	return _get_encounter_tier()


func _is_boss_encounter() -> bool:
	if enemy == null:
		return false
	if enemy.get("is_boss") != null:
		return bool(enemy.get("is_boss"))
	if enemy.has_meta("is_boss"):
		return bool(enemy.get_meta("is_boss"))
	if enemy.has_method("is_boss"):
		return bool(enemy.call("is_boss"))
	return false


func _should_auto_resolve_quiz(allowed_types: Array) -> bool:
	if _is_quizless_mode_enabled():
		return true
	var qm := _get_quiz_manager()
	var available_questions: Array = qm.get_questions(quiz_id, _diff_range, 1, allowed_types) if qm and qm.has_method("get_questions") else []
	return available_questions.is_empty()


func _is_quizless_mode_enabled() -> bool:
	var settings_service: Node = get_node_or_null("/root/SettingsService")
	if settings_service == null:
		return false
	if settings_service.has_method("is_quizless_mode_enabled"):
		return bool(settings_service.call("is_quizless_mode_enabled"))
	if _read_quizless_flag(settings_service, true):
		return true
	return _read_quizless_flag(settings_service, false)


func _read_quizless_flag(settings_service: Node, module_scope: bool) -> bool:
	var keys: Array[String] = ["quizless_mode", "disable_quizzes", "skip_quizzes"]
	for key_name in keys:
		var value: Variant
		if module_scope:
			value = settings_service.call("get_module", "quiz_rpg", key_name, null)
		else:
			value = settings_service.call("get_global", key_name, null)
		if value != null:
			return bool(value)
	return false


## Ruch kursora po siatce listy (delta: ±1 w poziomie, ±kolumny w pionie), z zawijaniem.
func _navigate_list(delta: int) -> void:
	var n := _list_menu_rows.size()
	if n == 0:
		return
	_list_selected_idx = posmod(_list_selected_idx + delta, n)
	_refresh_list_selection()


func _confirm_list_selection() -> void:
	if _list_selected_idx < 0 or _list_selected_idx >= _list_menu_entries.size():
		return
	if (_list_menu_rows[_list_selected_idx] as Button).disabled:
		return
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("click")
	var entry: Dictionary = _list_menu_entries[_list_selected_idx]
	if _list_menu_mode == "skills":
		_use_skill(entry)
	elif _list_menu_mode == "items":
		_use_item(entry)


func _build_list_menu(entries: Array[Dictionary], is_skill_menu: bool) -> void:
	for child in list_grid.get_children():
		list_grid.remove_child(child)
		child.queue_free()
	_list_menu_rows.clear()
	var actor: Dictionary = _party_state[_active_actor_index] if _has_active_actor() else {}
	for entry in entries:
		var row := ListRowScene.instantiate() as Button
		list_grid.add_child(row)
		var kind: int = row.Kind.NONE
		var cost := ""
		var disabled := false
		if is_skill_menu:
			var sp_cost: int = int(entry.get("sp_cost", 0))
			var tp_cost: int = int(entry.get("tp_cost", 0))
			if sp_cost > 0:
				cost = "%d SP" % sp_cost
				kind = row.Kind.SP
				disabled = int(actor.get("sp", 0)) < sp_cost
			if tp_cost > 0:
				cost = (cost + "  " if cost != "" else "") + "%d TP" % tp_cost
				kind = row.Kind.TP if sp_cost <= 0 else kind
				disabled = disabled or int(actor.get("tp", 0)) < tp_cost
			disabled = disabled or not bool(entry.get("usable_in_battle", true))
			disabled = disabled or (_ps != null and not _ps.member_meets_weapon_requirement(_active_actor_index, entry))
		else:
			var count: int = int(entry.get("count", 0))
			cost = "×%s" % str(entry.get("display_count", count))
			kind = row.Kind.COUNT
			disabled = count <= 0 or not bool(entry.get("usable_in_combat", true))
		row.setup(str(entry.get("name", "---")), cost, kind, disabled, entry.get("icon") as Texture2D)
		var row_index: int = _list_menu_rows.size()
		row.pressed.connect(func(): _on_list_row_pressed(row_index))
		row.mouse_entered.connect(func(): _on_list_row_hover(row_index))
		_list_menu_rows.append(row)
	if entries.is_empty():
		var empty := ListRowScene.instantiate() as Button
		list_grid.add_child(empty)
		empty.setup(QuizRpgI18n.t("combat.no_skills", "Brak umiejętności") if is_skill_menu else QuizRpgI18n.t("combat.no_items", "Brak przedmiotów"), "", 0, true)
	_fit_list_columns()


## Opcje -> Motyw „Umiejętności i przedmioty w walce”: siatka 2 kolumny albo jedna przewijana lista (QuizTheme.list_layout).
## Okno listy ma szerokość najszerszego wiersza (CombatListRow: minimum ze sceny albo nazwa + koszt), wysokość — cały pas
## (nadmiar przewijany); okna paska wyśrodkowane (ContentRow), po bokach widać tło bitwy.
func _fit_list_columns() -> void:
	var n := list_grid.get_child_count()
	if n == 0:
		return
	var cols := 2 if QuizTheme.list_layout() == QuizTheme.LIST_GRID else 1
	list_grid.columns = mini(cols, n)


func _on_list_row_hover(index: int) -> void:
	if index < 0 or index >= _list_menu_rows.size():
		return
	_list_selected_idx = index
	_refresh_list_selection()


func _on_list_row_pressed(index: int) -> void:
	if index < 0 or index >= _list_menu_rows.size():
		return
	_list_selected_idx = index
	_refresh_list_selection()
	_confirm_list_selection()


## Kursor (styl „selected” z motywu) także na pozycjach niedostępnych — opis widać, wybór blokuje _confirm_list_selection.
func _refresh_list_selection() -> void:
	for i in range(_list_menu_rows.size()):
		QuizTheme.set_menu_item_selected(_list_menu_rows[i] as Button, i == _list_selected_idx)
	if _list_selected_idx >= 0 and _list_selected_idx < _list_menu_rows.size():
		list_scroll.ensure_control_visible(_list_menu_rows[_list_selected_idx])
	_update_list_description()


func _update_list_description() -> void:
	if help_label == null:
		return
	help_label.visible = _list_menu_mode != ""
	if _list_selected_idx < 0 or _list_selected_idx >= _list_menu_entries.size():
		help_label.text = ""
	else:
		help_label.text = str(_list_menu_entries[_list_selected_idx].get("description", ""))
	_update_top_window()


func _is_menu_up(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or _is_key_pressed(event, [KEY_W])


func _is_menu_down(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or _is_key_pressed(event, [KEY_S])


func _is_menu_accept(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or _is_key_pressed(event, [KEY_Z])


## Wstecz w menu walki; prawy przycisk myszy też (jak w RPG Makerze — gra samą myszą).
func _is_menu_cancel(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or _is_key_pressed(event, [KEY_X, KEY_ESCAPE]) or _is_right_click(event)


func _is_right_click(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	return mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT


func _is_action_menu_prev(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up") or _is_key_pressed(event, [KEY_W, KEY_A])


func _is_action_menu_next(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down") or _is_key_pressed(event, [KEY_S, KEY_D])


func _is_key_pressed(event: InputEvent, keys: Array[int]) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and int(key_event.keycode) in keys


## Umiejętność z listy: leczenie (cel: ja / sojusznik — kursor drużyny, gdy jest wybór / drużyna / nieprzytomny)
## albo atak (jeden przeciwnik — wybór celu; wszyscy / losowi — bez wyboru). Koszt pobierany po wyborze celu.
func _use_skill(skill_data: Dictionary) -> void:
	var skill := skill_data.get("resource") as QuizRpgSkillBase
	_close_list_menu()
	if skill != null and skill.targets_allies():
		chosen_action = Action.HEAL
		if skill.target == QuizRpgSkillBase.Target.ONE_ALLY or skill.target == QuizRpgSkillBase.Target.DEAD_ALLY:
			var dead := skill.target == QuizRpgSkillBase.Target.DEAD_ALLY
			var valid := _party_indices(dead)
			if valid.is_empty():
				result_label.visible = true
				result_label.text = QuizRpgI18n.t("combat.no_dead_allies", "Brak nieprzytomnych sojuszników.") if dead else QuizRpgI18n.t("combat.no_target", "Brak celu.")
				return
			_pending_skill_data = skill_data.duplicate()
			if valid.size() == 1:
				_heal_target_index = valid[0]
				_start_pending_skill()
			else:
				_open_ally_pick(dead)
			return
		_selected_skill_data = skill_data.duplicate()
		_consume_skill_cost(_selected_skill_data)
		_begin_action_quiz()
		return
	chosen_action = Action.ATTACK
	if skill == null or skill.target == QuizRpgSkillBase.Target.ONE_OPPONENT:
		_pending_skill_data = skill_data.duplicate()
		_open_target_menu()
		return
	_selected_skill_data = skill_data.duplicate()
	_consume_skill_cost(_selected_skill_data)
	_begin_action_quiz()


func _start_pending_skill() -> void:
	_selected_skill_data = _pending_skill_data.duplicate()
	_pending_skill_data.clear()
	_consume_skill_cost(_selected_skill_data)
	_begin_action_quiz()


## Wybór celu leczenia kursorem na liście drużyny (jak wybór postaci), żywy albo nieprzytomny sojusznik.
func _open_ally_pick(dead: bool) -> void:
	_ally_pick = 2 if dead else 1
	_actor_select_open = true
	_actor_selected_idx = _find_selectable_actor(0, 1)
	_set_band_mode(Band.STATUS_ONLY)
	_refresh_actor_selection()


func _confirm_ally_pick() -> void:
	_heal_target_index = _actor_selected_idx
	_ally_pick = 0
	_close_actor_select()
	_start_pending_skill()


func _cancel_ally_pick() -> void:
	_ally_pick = 0
	_pending_skill_data.clear()
	_close_actor_select()
	_open_skills_menu()


func _consume_skill_cost(skill_data: Dictionary) -> void:
	if not _executing:
		return  # koszt w ruchu postaci (_start_member_action)
	if bool(skill_data.get("consumes_weapon", false)) and _ps != null:
		_ps.consume_member_weapon(_active_actor_index)
	var sp_cost: int = int(skill_data.get("sp_cost", 0))
	var tp_cost: int = int(skill_data.get("tp_cost", 0))
	if sp_cost > 0:
		_consume_party_sp(_active_actor_index, sp_cost)
	if tp_cost > 0 and _has_active_actor():
		var member: Dictionary = _party_state[_active_actor_index]
		member["tp"] = clampi(int(member.get("tp", 0)) - tp_cost, 0, int(member.get("tp_max", PARTY_TP_MAX)))
		_party_state[_active_actor_index] = member


func _use_item(item_data: Dictionary) -> void:
	if _ps == null:
		return
	var item_id: String = str(item_data.get("item_id", ""))
	if item_id == "":
		return
	if not _ps.has_method("use_item"):
		return
	if not _executing:
		# Przedmiot, który nic by nie dał (pełne HP / SP / TP, brak statusu) — nie do wybrania, menu zostaje.
		var block: String = _ps.item_block_reason(item_id, _active_actor_index, _item_values(_active_actor_index)) if _ps.has_method("item_block_reason") else ""
		if block != "":
			result_label.visible = true
			result_label.text = block
			result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
			return
		_close_list_menu()
		_commit_plan({"item": item_data.duplicate(true)})  # przedmiot zużywany w ruchu postaci
		return
	var use_result: Dictionary = _ps.use_item_on_member(item_id, _active_actor_index, _item_values(_active_actor_index))
	var item_name: String = str(use_result.get("name", item_data.get("name", QuizRpgI18n.t("combat.default_item_name", "Przedmiot"))))
	if not bool(use_result.get("success", false)):
		result_label.visible = true
		# Zablokowany (np. HP wypełniło się przed ruchem) — powód; inaczej brak przedmiotu.
		result_label.text = str(use_result.get("message", "")) if bool(use_result.get("blocked", false)) else QuizRpgI18n.tf("combat.no_item_left", {"name": _member_name(_active_actor_index), "item": item_name}, "{name}: brak przedmiotu — {item}.")
		result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
		await get_tree().create_timer(1.0).timeout
		_next_turn()
		return
	_selected_item_data = item_data.duplicate(true)
	phase = Phase.PLAYER_RESULT
	var heal_amount: int = int(use_result.get("heal_amount", 0))
	var sp_restore: int = int(use_result.get("sp_restore", 0))
	var tp_restore: int = int(use_result.get("tp_restore", 0))
	var effect_parts: Array[String] = []
	if heal_amount > 0:
		effect_parts.append("+%d HP" % heal_amount)
		result_label.add_theme_color_override("font_color", Color.GREEN)
		_flash_sprite(player_sprite_node, Color.GREEN)
		FloatingText.create_at(player, player.global_position + Vector2(0, -20), "+%d HP" % heal_amount, Color.GREEN, 14)
	if sp_restore > 0:
		_restore_party_sp(_active_actor_index, sp_restore)
		effect_parts.append("+%d SP" % sp_restore)
	if tp_restore > 0:
		_restore_party_tp(_active_actor_index, tp_restore)
		effect_parts.append("+%d TP" % tp_restore)
	if (use_result.get("cured_statuses", []) as Array).has("poison"):
		effect_parts.append(QuizRpgI18n.t("combat.poison_cured", "zatrucie wyleczone"))
		FloatingText.create_at(player, player.global_position + Vector2(0, -34), QuizRpgI18n.t("combat.cured", "Wyleczono"), Color.GREEN, 12)
	if effect_parts.is_empty():
		result_label.text = str(use_result.get("message", QuizRpgI18n.tf("combat.used_item", {"item": item_name}, "Użyto: {item}")))
		result_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		result_label.text = "%s: %s" % [item_name, ", ".join(effect_parts)]
	result_label.visible = true
	_refresh_stats_panel()
	_update_hp_bars()
	await get_tree().create_timer(1.0).timeout
	_next_turn()


func _show_question(q: Dictionary) -> void:
	_quiz_panel_controller.start_question(q, _diff_range.x)
	_set_quiz_layout_active(true)


func _on_quiz_answered(result: Dictionary, submitted_answer: Dictionary) -> void:
	var correct := bool(result.get("correct", false))
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		if correct:
			audio.play_sfx_by_name("correct")
		else:
			audio.play_sfx_by_name("wrong")
	var category := quiz_id
	if _ps:
		if correct:
			_ps.on_correct_answer()
		else:
			_ps.on_wrong_answer()
	if _dm:
		_dm.record_answer(category, correct)
	_show_quiz_feedback(result, submitted_answer)
	await get_tree().create_timer(1.2).timeout
	if _round_questions:
		_round_question_answered.emit(correct)  # pytanie rundy: akcja później, w kolejce AGI
		return
	_resolve_action(correct)


func _show_quiz_feedback(result: Dictionary, submitted_answer: Dictionary) -> void:
	_quiz_panel_controller.show_feedback(result, submitted_answer)


func _resolve_action(correct: bool) -> void:
	phase = Phase.PLAYER_RESULT
	_set_quiz_layout_active(false)
	_set_band_mode(Band.STATUS_ONLY)  # wykonanie akcji: sam status, komunikaty w logu u góry
	_quiz_panel_controller.hide_quiz()
	result_label.visible = true
	if chosen_action == Action.FLEE:
		_try_flee(correct)  # koniec walki albo runda bez akcji drużyny
		return
	match chosen_action:
		Action.ATTACK:
			await _resolve_attack(correct)
		Action.DEFEND:
			_resolve_defend(correct)
		Action.HEAL:
			_resolve_heal(correct)
	_update_hp_bars()
	_refresh_enemy_header()
	_refresh_stats_panel()
	if streak_label and _ps:
		streak_label.text = "Seria: %d | RNG: +%.0f%%" % [_ps.streak, _ps.rng_bonus * 100.0]
	await get_tree().create_timer(1.5).timeout
	_next_turn()


## Atak gracza (zwykły albo umiejętność): cele wg umiejętności, `hits` trafień, każde trafienie — szansa z quizu ×
## success_rate, obrażenia QuizRpgSkillMath (staty aktywnej postaci vs staty jednostki), krytyk 15 % (×1,8).
func _resolve_attack(correct: bool) -> void:
	var skill := _selected_skill_data.get("resource") as QuizRpgSkillBase
	var targets := _offense_targets(skill)
	if targets.is_empty():
		return
	var hit_chance: float = ATTACK_HIT_CHANCE_CORRECT if correct else ATTACK_HIT_CHANCE_WRONG
	if _ps and _ps.has_method("member_hit_mult"):
		hit_chance *= _ps.member_hit_mult(_active_actor_index)
	var hits: int = skill.hits if skill else 1
	var user := _member_stats(_active_actor_index)
	var touched := {}
	for h in range(hits):
		if h > 0:
			await get_tree().create_timer(skill.hit_interval).timeout
		for ti in targets:
			if int(_enemy_units[ti].get("hp", 0)) <= 0:
				continue
			_active_enemy_index = ti
			var quiz_hit: bool = true if skill != null and skill.hit_ignores_quiz else (_ps.roll_with_bonus(hit_chance) if _ps else randf() < hit_chance)
			if not quiz_hit or (skill != null and not QuizRpgSkillMath.roll_hit(skill)):
				_show_attack_miss(ti, correct)
				continue
			_apply_player_hit(ti, QuizRpgSkillMath.damage(skill, user, _unit_stats(_enemy_units[ti])))
			_gain_party_tp(_active_actor_index, skill.tp_gain if skill else TP_PER_HIT)  # TP za każde trafienie
			_unit_on_damaged(ti)
			touched[ti] = true
			if skill != null and skill.has_status() and skill.status_per_hit and randf() < skill.status_chance:
				_unit_add_status(ti, skill.inflict_status)
	if skill != null and skill.has_status() and not skill.status_per_hit:
		for ti: int in touched:
			if int(_enemy_units[ti].get("hp", 0)) > 0 and randf() < skill.status_chance:
				_unit_add_status(ti, skill.inflict_status)


## Cele ataku gracza: jeden (wybrany), wszyscy żywi albo N losowych (z powtórzeniami, jak w RPG Makerze).
func _offense_targets(skill: QuizRpgSkillBase) -> Array[int]:
	var alive: Array[int] = []
	for i in range(_enemy_units.size()):
		if int(_enemy_units[i].get("hp", 0)) > 0:
			alive.append(i)
	if alive.is_empty():
		return alive
	if skill != null and skill.target == QuizRpgSkillBase.Target.ALL_OPPONENTS:
		return alive
	var confused: bool = _ps != null and _ps.has_method("member_has_restriction") and _ps.member_has_restriction(_active_actor_index, QuizRpgStatusData.Restriction.CONFUSED)
	if confused or (skill != null and skill.target == QuizRpgSkillBase.Target.RANDOM_OPPONENTS):
		var out: Array[int] = []
		for k in range(skill.random_count if skill else 1):
			out.append(alive.pick_random())
		return out
	var t := _active_enemy_index
	if not alive.has(t):
		t = _find_next_alive_enemy_index(_active_enemy_index)
	var one: Array[int] = []
	if t >= 0:
		one.append(t)
	return one


func _apply_player_hit(ti: int, base_dmg: int) -> void:
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("hit")
	var target := _enemy_units[ti]
	var target_name_str := str(target.get("name", enemy_name_str))
	var dmg := base_dmg
	var crit := false
	if _ps and _ps.roll_with_bonus(0.15):
		dmg = int(dmg * 1.8)
		crit = true
	target["hp"] = maxi(int(target.get("hp", 0)) - dmg, 0)
	if int(target.get("hp", 0)) <= 0 and audio:
		audio.play_sfx_by_name("enemy_death")
	_enemy_units[ti] = target
	_refresh_enemy_cache()
	_sync_enemy_display_hit(ti)
	if crit:
		result_label.text = QuizRpgI18n.tf("combat.crit_damage", {"target": target_name_str, "damage": dmg}, "{target}: krytyk! -{damage} HP")
		result_label.add_theme_color_override("font_color", Color.GOLD)
		FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), QuizRpgI18n.tf("combat.crit_float", {"damage": dmg}, "KRYT -{damage}"), Color.GOLD, 16)
	else:
		result_label.text = QuizRpgI18n.tf("combat.hit_damage", {"target": target_name_str, "damage": dmg}, "{target}: trafienie! -{damage} HP")
		result_label.add_theme_color_override("font_color", Color.GREEN)
		FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), "-%d" % dmg, Color.YELLOW, 14)
	HitParticles.create_at(enemy, enemy.global_position, Color(1.0, 0.5, 0.2))


func _show_attack_miss(ti: int, correct: bool) -> void:
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("attack")
	var fail_types: Array[String] = [
		QuizRpgI18n.t("combat.miss", "Pudło!"),
		QuizRpgI18n.t("combat.enemy_dodged", "Unik wroga!"),
		QuizRpgI18n.t("combat.enemy_blocked", "Blok wroga!"),
	]
	var fail_type: String = fail_types[randi() % fail_types.size()]
	result_label.text = fail_type
	result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75) if correct else Color(0.82, 0.62, 0.35))
	_dodge_enemy_display(ti)
	FloatingText.create_at(enemy, enemy.global_position + Vector2(0, -20), fail_type, Color(0.8, 0.8, 0.8) if correct else Color(0.9, 0.7, 0.45), 12)


func _resolve_defend(correct: bool) -> void:
	_guard[_active_actor_index] = correct
	_gain_party_tp(_active_actor_index, TP_PER_HIT)
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("magic")
	if correct:
		result_label.text = QuizRpgI18n.t("combat.good_defense", "Dobra obrona!")
		result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		_flash_sprite(player_sprite_node, Color(0.3, 0.7, 1.0))
	else:
		result_label.text = QuizRpgI18n.t("combat.partial_defense", "Częściowa obrona.")
		result_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))


## Leczenie umiejętnością: cele wg umiejętności (ja / wybrany sojusznik / drużyna / nieprzytomny — wskrzeszenie),
## ilość QuizRpgSkillMath.heal; po złej odpowiedzi WRONG_ANSWER_HEAL_FACTOR tego.
func _resolve_heal(correct: bool) -> void:
	if not _ps:
		return
	var skill := _selected_skill_data.get("resource") as QuizRpgSkillBase
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("magic")
	var factor := 1.0 if correct else WRONG_ANSWER_HEAL_FACTOR
	var revive := skill != null and skill.target == QuizRpgSkillBase.Target.DEAD_ALLY
	var parts: Array[String] = []
	var user_mat := int(_member_stats(_active_actor_index).get("mat", 0))
	for t in _heal_targets(skill):
		if skill != null:
			_gain_party_tp(_active_actor_index, skill.tp_gain)  # TP za każdy cel
		var member: Dictionary = _ps.get_party_member(t) if _ps.has_method("get_party_member") else {}
		var max_hp: int = int(member.get("max_hp", _ps.max_hp))
		if skill != null and skill.has_status() and randf() < skill.status_chance and _ps.add_status(t, skill.inflict_status, skill.status_params()):
			parts.append("%s: %s" % [str(member.get("name", "Bohater")), QuizRpgStatusCatalog.name_of(skill.inflict_status)])
		if skill != null and not skill.is_heal():
			continue
		var amount := maxi(roundi((QuizRpgSkillMath.heal(skill, max_hp, user_mat) if skill else max_hp * 0.3) * factor), 1)
		var healed: int = _ps.heal_member(t, amount, revive) if _ps.has_method("heal_member") else 0
		if healed <= 0:
			continue
		parts.append("%s +%d HP" % [str(member.get("name", "Bohater")), healed])
		if t == 0:
			_flash_sprite(player_sprite_node, Color.GREEN)
			FloatingText.create_at(player, player.global_position + Vector2(0, -20), "+%d HP" % healed, Color.GREEN, 14)
	var title: String = str(_selected_skill_data.get("name", QuizRpgI18n.t("combat.default_heal_name", "Leczenie")))
	if parts.is_empty():
		result_label.text = QuizRpgI18n.tf("combat.no_effect", {"title": title}, "{title}: bez efektu.")
		result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	else:
		result_label.text = "%s%s: %s" % [title, "" if correct else QuizRpgI18n.t("combat.weaker_suffix", " (słabiej)"), ", ".join(parts)]
		result_label.add_theme_color_override("font_color", Color.GREEN if correct else Color(0.6, 0.8, 0.5))


func _heal_targets(skill: QuizRpgSkillBase) -> Array[int]:
	var out: Array[int] = []
	if skill != null and skill.target == QuizRpgSkillBase.Target.ALL_ALLIES:
		return _party_indices(false)
	out.append(_active_actor_index if skill == null or skill.target == QuizRpgSkillBase.Target.SELF else _heal_target_index)
	return out


## Ucieczka (decyzja usera 2026-10-16): najpierw pytanie quizu — dobra odpowiedź daje zwykłą szansę, zła mniejszą
## o flee_wrong_penalty (wymusza myślenie nad zadaniem). Od razu (nie czeka na fazę wykonania); bez pytania — zwykła.
func _start_flee() -> void:
	chosen_action = Action.FLEE
	_executing = true
	_begin_action_quiz()


func _try_flee(correct: bool) -> void:
	var chance := maxf(FLEE_SUCCESS_CHANCE - (0.0 if correct else flee_wrong_penalty), 0.0)
	if not correct and flee_wrong_penalty > 0.0:
		_push_log(QuizRpgI18n.tf("combat.flee_penalty_log", {"chance": roundi(chance * 100.0)}, "Zła odpowiedź — trudniej uciec ({chance} %)."), Color(1.0, 0.55, 0.35))
	if randf() < chance:
		result_label.visible = true
		result_label.text = QuizRpgI18n.t("combat.escaped", "Uciekasz!")
		result_label.add_theme_color_override("font_color", Color.WHITE)
		await get_tree().create_timer(1.0).timeout
		_end_combat(false, true)
	else:
		result_label.visible = true
		result_label.text = QuizRpgI18n.t("combat.escape_failed", "Nie udało się uciec!")
		result_label.add_theme_color_override("font_color", Color.RED)
		if action_panel:
			action_panel.visible = false
		if party_command_panel:
			party_command_panel.visible = false
		await get_tree().create_timer(1.0).timeout
		_plans.clear()  # nieudana ucieczka: drużyna traci rundę (jak w RPG Makerze)
		_execute_round()


## Ruch wroga (jedna jednostka): umiejętność albo zwykły atak w losowego przytomnego członka drużyny.
## true = walka zakończona (drużyna padła).
func _enemy_act(enemy_index: int) -> bool:
	phase = Phase.ENEMY_TURN
	_set_band_mode(Band.STATUS_ONLY)
	result_label.visible = true
	var enemy_unit := _enemy_units[enemy_index]
	var enemy_label := str(enemy_unit.get("name", enemy_name_str))
	var planned_skill: Variant = enemy_unit.get("planned_skill")
	enemy_unit.erase("planned_skill")
	var stop := _unit_restriction(enemy_unit, QuizRpgStatusData.Restriction.SKIP_TURN)
	if stop != null:
		_push_log(QuizRpgI18n.tf("combat.enemy_skips_turn", {"enemy": enemy_label, "status": stop.localized_name()}, "{enemy}: {status} — traci turę."), stop.color)
		await get_tree().create_timer(0.6).timeout
		return false
	if _unit_restriction(enemy_unit, QuizRpgStatusData.Restriction.CONFUSED) != null and randf() < 0.5 and await _confused_unit_strike(enemy_index):
		return false
	var skill: QuizRpgEnemySkill = planned_skill if _executing else _pick_enemy_skill(enemy_unit)  # poza rundą (testy) — od razu
	if skill != null:
		return await _enemy_use_skill(enemy_index, enemy_unit, enemy_label, skill)
	if turn_label:
		turn_label.text = QuizRpgI18n.tf("combat.turn_enemy_attacks", {"turn": turn_number, "enemy": enemy_label}, "Tura {turn} - {enemy} atakuje")
	_push_log(QuizRpgI18n.tf("combat.enemy_attacks_log", {"enemy": enemy_label}, "{enemy} atakuje!"), Color.WHITE)
	_active_enemy_index = enemy_index
	_refresh_enemy_header()
	if enemy_index < _enemy_displays.size() and _enemy_displays[enemy_index] != null:
		var active_display: Node2D = _enemy_displays[enemy_index]
		if active_display.has_method("play_attack"):
			active_display.call("play_attack")
	await get_tree().create_timer(0.5).timeout
	# Cel: losowy przytomny członek drużyny (sam lider, gdy drużyna jednoosobowa).
	var alive := _party_indices(false)
	var t: int = alive[randi() % alive.size()] if not alive.is_empty() else 0
	var target_suffix := "" if _party_state.size() <= 1 else " (%s)" % _member_name(t)
	var full_damage := QuizRpgSkillMath.basic_attack(_unit_stats(enemy_unit), _member_stats(t))
	if randf() >= _unit_hit_mult(enemy_unit):
		_push_log(QuizRpgI18n.tf("combat.enemy_misses_log", {"enemy": enemy_label}, "{enemy} pudłuje!"), Color(0.75, 0.75, 0.82))
		FloatingText.create_at(player, player.global_position + Vector2(0, -20), QuizRpgI18n.t("combat.dodge_short", "Unik!"), Color(0.8, 0.8, 0.8), 12)
		await get_tree().create_timer(0.8).timeout
		return false
	var actual_damage: int
	if _guard.has(t):
		actual_damage = maxi(floori(full_damage * _guard_factor(t)), 1)
		if _ps:
			_ps.damage_member(t, actual_damage)
		var audio := get_node_or_null("/root/AudioService")
		if actual_damage <= 0:
			if audio:
				audio.play_sfx_by_name("hit")
			result_label.text = QuizRpgI18n.tf("combat.enemy_defended", {"enemy": enemy_label}, "{enemy} odbija się od obrony!")
			result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
			_flash_sprite(player_sprite_node, Color(0.75, 0.75, 0.82))
			FloatingText.create_at(player, player.global_position + Vector2(0, -20), "0", Color(0.75, 0.75, 0.82), 12)
		else:
			if audio:
				audio.play_sfx_by_name("player_damage")
			result_label.text = QuizRpgI18n.tf("combat.enemy_deals_hp", {"enemy": enemy_label, "damage": actual_damage}, "{enemy} zadaje {damage} HP") if _party_state.size() <= 1 else QuizRpgI18n.tf("combat.enemy_deals_hp_target", {"enemy": enemy_label, "damage": actual_damage, "target": _member_name(t)}, "{enemy} zadaje {damage} HP ({target})")
			result_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
			_flash_sprite(player_sprite_node, Color(0.8, 0.6, 0.3))
			FloatingText.create_at(player, player.global_position + Vector2(0, -20), "-%d" % actual_damage, Color.ORANGE, 12)
	else:
		actual_damage = full_damage
		if _ps:
			_ps.damage_member(t, actual_damage)
			_member_damaged(t)
		var audio := get_node_or_null("/root/AudioService")
		if actual_damage <= 0:
			if audio:
				audio.play_sfx_by_name("hit")
			result_label.text = QuizRpgI18n.tf("combat.enemy_armor_blocked", {"enemy": enemy_label}, "{enemy} nie przebija pancerza!")
			result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
			_flash_sprite(player_sprite_node, Color(0.75, 0.75, 0.82))
			FloatingText.create_at(player, player.global_position + Vector2(0, -20), "0", Color(0.75, 0.75, 0.82), 12)
		else:
			if audio:
				audio.play_sfx_by_name("player_damage")
			result_label.text = QuizRpgI18n.tf("combat.enemy_hits", {"enemy": enemy_label, "damage": actual_damage}, "{enemy} trafia! -{damage} HP") if _party_state.size() <= 1 else QuizRpgI18n.tf("combat.enemy_hits_target", {"enemy": enemy_label, "damage": actual_damage, "target": _member_name(t)}, "{enemy} trafia ({target})! -{damage} HP")  # „atakuje!” jest już w logu — inaczej jeden atak wyglądał jak dwa
			result_label.add_theme_color_override("font_color", Color.RED)
			_flash_sprite(player_sprite_node, Color.RED)
			HitParticles.create_at(player, player.global_position, Color.RED, 6)
			FloatingText.create_at(player, player.global_position + Vector2(0, -20), "-%d" % actual_damage, Color.RED, 14)
	_gain_party_tp(t, _tp_from_damage(t, actual_damage))
	_update_hp_bars()
	_refresh_stats_panel()
	await get_tree().create_timer(1.0).timeout
	if _ps and _ps.is_party_defeated():
		_end_combat(false)
		return true
	return false


## Umiejętność wroga na tę turę: pierwsza z battle_skills dostępna (cooldown, first_turn) i wylosowana z use_chance;
## null = zwykły atak. Cooldowny w jednostce wroga ("cooldowns": {indeks: tury}), odliczane co jej turę.
## Wróg-źródło jednostki (grupa: każda jednostka ze swojego wroga), inaczej główny wróg walki.
func _unit_source(unit: Dictionary) -> Node2D:
	var src: Variant = unit.get("source", null)
	return src if src is Node2D and is_instance_valid(src) else enemy


## Zamroczony wróg bije losowego innego wroga (zwykły atak). false = brak innego celu (atakuje normalnie).
func _confused_unit_strike(enemy_index: int) -> bool:
	var others: Array[int] = []
	for i in range(_enemy_units.size()):
		if i != enemy_index and int(_enemy_units[i].get("hp", 0)) > 0:
			others.append(i)
	if others.is_empty():
		return false
	var ti: int = others.pick_random()
	var attacker := _enemy_units[enemy_index]
	var victim := _enemy_units[ti]
	var dmg := QuizRpgSkillMath.basic_attack(_unit_stats(attacker), _unit_stats(victim))
	victim["hp"] = maxi(int(victim.get("hp", 0)) - dmg, 0)
	_enemy_units[ti] = victim
	_push_log(QuizRpgI18n.tf("combat.confused_attacks", {"attacker": str(attacker.get("name", enemy_name_str)), "victim": str(victim.get("name", enemy_name_str)), "damage": dmg}, "{attacker} w zamroczeniu atakuje: {victim} -{damage} HP"), QuizRpgStatusCatalog.color_of("confusion"))
	_unit_on_damaged(ti)
	_refresh_enemy_cache()
	_refresh_enemy_header()
	await get_tree().create_timer(0.8).timeout
	return true


func _enemy_side_wounded() -> bool:
	for u in _enemy_units:
		if int(u.get("hp", 0)) > 0 and int(u.get("hp", 0)) < int(u.get("max_hp", 1)):
			return true
	return false


func _pick_enemy_skill(enemy_unit: Dictionary) -> QuizRpgEnemySkill:
	var src: Node2D = _unit_source(enemy_unit)
	if src == null or not "battle_skills" in src:
		return null
	var skills: Array = src.get("battle_skills")
	if skills.is_empty():
		return null
	var cds: Dictionary = enemy_unit.get("cooldowns", {})
	for k in cds.keys():
		cds[k] = int(cds[k]) - 1
		if int(cds[k]) <= 0:
			cds.erase(k)
	enemy_unit["cooldowns"] = cds
	for i in range(skills.size()):
		var sk := skills[i] as QuizRpgEnemySkill
		if sk == null or cds.has(i) or turn_number < sk.first_turn:
			continue
		if sk.is_heal() and not _enemy_side_wounded():
			continue
		if randf() < sk.use_chance:
			if sk.cooldown_turns > 0:
				cds[i] = sk.cooldown_turns + 1   # odliczanie zaczyna się od następnej tury wroga
			return sk
	return null


## Użycie umiejętności wroga: leczenie (siebie / sojusznika / wszystkich wrogów) albo `hits` ataków w serii na
## cel(e) z drużyny — szansa trafienia, obrażenia QuizRpgSkillMath (staty jednostki vs staty członka), obrona
## (obrona: 1/4 po dobrej odpowiedzi, 1/2 po złej), status z szansą przy każdym trafieniu albo raz po serii. true = lider padł (walka zakończona).
func _enemy_use_skill(enemy_index: int, enemy_unit: Dictionary, enemy_label: String, sk: QuizRpgEnemySkill) -> bool:
	var text := sk.localized_log_text()
	if text == "":
		text = QuizRpgI18n.t("combat.enemy_uses_skill", "{enemy} używa: {skill}!")
	text = text.replace("{enemy}", enemy_label).replace("{skill}", sk.localized_name())
	if turn_label:
		turn_label.text = QuizRpgI18n.tf("combat.turn_enemy_skill", {"turn": turn_number, "enemy": enemy_label, "skill": sk.localized_name()}, "Tura {turn} - {enemy}: {skill}")
	_push_log(text, sk.color)
	result_label.text = text
	result_label.add_theme_color_override("font_color", sk.color)
	_active_enemy_index = enemy_index
	_refresh_enemy_header()
	if sk.targets_allies():
		await _enemy_heal(enemy_index, sk)
		return false
	var audio := get_node_or_null("/root/AudioService")
	var touched := {}   # cele trafione (albo dosięgnięte przez umiejętność bez obrażeń)
	for h in range(sk.hits):
		if enemy_index < _enemy_displays.size() and _enemy_displays[enemy_index] != null:
			var disp: Node2D = _enemy_displays[enemy_index]
			if disp.has_method("play_attack"):
				disp.call("play_attack")
		await get_tree().create_timer(0.5 if h == 0 else sk.hit_interval).timeout
		var targets := _enemy_skill_targets(sk)
		if targets.is_empty():
			break
		for t in targets:
			if not QuizRpgSkillMath.roll_hit(sk, _unit_hit_mult(enemy_unit)):
				if t == 0:
					FloatingText.create_at(player, player.global_position + Vector2(0, -20), QuizRpgI18n.t("combat.dodge_short", "Unik!"), Color(0.8, 0.8, 0.8), 12)
				continue
			var full := QuizRpgSkillMath.damage(sk, _unit_stats(enemy_unit), _member_stats(t))
			var mult := 1.0
			if _guard.has(t) and sk.can_be_blocked:
				mult = _guard_factor(t)
			var dmg := maxi(floori(full * mult), 1) if full > 0 else 0
			if dmg > 0 and _ps:
				_ps.damage_member(t, dmg)
				_gain_party_tp(t, _tp_from_damage(t, dmg))
				_member_damaged(t)
				if t == 0:
					if audio:
						audio.play_sfx_by_name("player_damage")
					_flash_sprite(player_sprite_node, sk.color)
					HitParticles.create_at(player, player.global_position, sk.color, 6)
					FloatingText.create_at(player, player.global_position + Vector2(0, -20), "-%d" % dmg, sk.color, 14)
			if dmg > 0 or sk.damage_mode == QuizRpgSkillBase.DamageMode.NONE:
				touched[t] = true
				if sk.has_status() and sk.status_per_hit and randf() < _guarded_status_chance(t, sk):
					_inflict_status(t, sk)
		_update_hp_bars()
		_refresh_stats_panel()
		if _ps and _ps.is_party_defeated():
			await get_tree().create_timer(0.6).timeout
			_end_combat(false)
			return true
	if sk.has_status() and not sk.status_per_hit:
		for t: int in touched:
			if randf() < _guarded_status_chance(t, sk):
				_inflict_status(t, sk)
	await get_tree().create_timer(0.8).timeout
	return false


## Cele umiejętności wroga w drużynie (żywi): jeden — lider (inaczej pierwszy żywy), wszyscy albo N losowych.
func _enemy_skill_targets(sk: QuizRpgSkillBase) -> Array[int]:
	var alive := _party_indices(false)
	if alive.is_empty():
		return alive
	match sk.target:
		QuizRpgSkillBase.Target.ALL_OPPONENTS:
			return alive
		QuizRpgSkillBase.Target.RANDOM_OPPONENTS:
			var out: Array[int] = []
			for k in range(sk.random_count):
				out.append(alive.pick_random())
			return out
	var lead: Array[int] = [0 if alive.has(0) else alive[0]]
	return lead


## Leczenie wroga: siebie (SELF), najbardziej rannego sojusznika (ONE_ALLY) albo wszystkich żywych wrogów (ALL_ALLIES).
func _enemy_heal(enemy_index: int, sk: QuizRpgSkillBase) -> void:
	await get_tree().create_timer(0.5).timeout
	var targets: Array[int] = []
	match sk.target:
		QuizRpgSkillBase.Target.ALL_ALLIES:
			for i in range(_enemy_units.size()):
				if int(_enemy_units[i].get("hp", 0)) > 0:
					targets.append(i)
		QuizRpgSkillBase.Target.ONE_ALLY:
			var best := -1
			var best_ratio := 2.0
			for i in range(_enemy_units.size()):
				var u := _enemy_units[i]
				var hp := int(u.get("hp", 0))
				var ratio := float(hp) / float(maxi(int(u.get("max_hp", 1)), 1))
				if hp > 0 and ratio < best_ratio:
					best = i
					best_ratio = ratio
			if best >= 0:
				targets.append(best)
		_:
			targets.append(enemy_index)
	for i in targets:
		var u := _enemy_units[i]
		var max_hp := int(u.get("max_hp", 1))
		if sk.has_status() and randf() < sk.status_chance:
			_unit_add_status(i, sk.inflict_status)
			u = _enemy_units[i]
		var healed := mini(QuizRpgSkillMath.heal(sk, max_hp, int(_unit_stats(_enemy_units[enemy_index]).get("mat", 0))), max_hp - int(u.get("hp", 0)))
		if healed <= 0:
			continue
		u["hp"] = int(u.get("hp", 0)) + healed
		_enemy_units[i] = u
		_push_log(QuizRpgI18n.tf("combat.recovers_hp", {"name": str(u.get("name", enemy_name_str)), "amount": healed}, "{name} odzyskuje {amount} HP."), sk.color)
	_refresh_enemy_cache()
	_refresh_enemy_header()
	await get_tree().create_timer(0.8).timeout


func _inflict_status(member_index: int, sk: QuizRpgEnemySkill) -> void:
	if _ps == null or not _ps.has_method("add_status") or not _ps.add_status(member_index, sk.inflict_status, sk.status_params()):
		return
	var member: Dictionary = _ps.get_party_member(member_index) if _ps.has_method("get_party_member") else {}
	var st_name: String = _ps.status_name(sk.inflict_status) if _ps.has_method("status_name") else sk.inflict_status
	var col := QuizRpgStatusCatalog.color_of(sk.inflict_status, sk.color)
	_push_log(QuizRpgI18n.tf("combat.status_inflicted", {"name": str(member.get("name", QuizRpgI18n.t("combat.default_hero_name", "Bohater"))), "status": st_name}, "{name}: {status}!"), col)
	if member_index == 0:
		FloatingText.create_at(player, player.global_position + Vector2(0, -34), "%s!" % st_name, col, 12)


## Koniec rundy: statusy drużyny (PlayerStats.tick_statuses_combat — trucizna może zbić do 0, regeneracja, wygasanie)
## i wrogów (to samo w jednostkach). true = walka zakończona (drużyna padła albo wrogowie zginęli).
func _apply_status_round() -> bool:
	var any := false
	if _ps and _ps.has_method("tick_statuses_combat"):
		for ev in _ps.tick_statuses_combat():
			any = true
			var i := int(ev["member"])
			var sid := String(ev["status"])
			var col := QuizRpgStatusCatalog.color_of(sid, POISON_COLOR)
			if ev.get("expired", false):
				_push_log(QuizRpgI18n.tf("combat.status_ended", {"name": _member_name(i), "status": QuizRpgStatusCatalog.name_of(sid)}, "{name}: koniec — {status}."), col)
				continue
			var delta := int(ev["hp"])
			if delta < 0:
				_push_log(QuizRpgI18n.tf("combat.status_hp_loss", {"name": _member_name(i), "status": QuizRpgStatusCatalog.name_of(sid), "amount": -delta}, "{name}: {status} -{amount} HP"), col)
			else:
				_push_log(QuizRpgI18n.tf("combat.status_hp_gain", {"name": _member_name(i), "status": QuizRpgStatusCatalog.name_of(sid), "amount": delta}, "{name}: {status} +{amount} HP"), col)
			if i == 0:
				_flash_sprite(player_sprite_node, col)
				FloatingText.create_at(player, player.global_position + Vector2(0, -20), "%+d" % delta, col, 14)
	for ti in range(_enemy_units.size()):
		var unit := _enemy_units[ti]
		if int(unit.get("hp", 0)) <= 0:
			continue
		var st: Dictionary = unit.get("statuses", {})
		for sid in st.keys():
			var def := QuizRpgStatusCatalog.get_status(String(sid))
			if def == null:
				continue
			if def.turn_hp_percent != 0.0:
				var max_hp := int(unit.get("max_hp", 1))
				var amount := maxi(ceili(max_hp * absf(def.turn_hp_percent)), 1)
				var delta := -mini(amount, int(unit.get("hp", 0))) if def.turn_hp_percent < 0.0 else mini(amount, max_hp - int(unit.get("hp", 0)))
				if delta != 0:
					unit["hp"] = int(unit.get("hp", 0)) + delta
					any = true
					_push_log(QuizRpgI18n.tf("combat.status_hp_gain", {"name": str(unit.get("name", enemy_name_str)), "status": def.localized_name(), "amount": delta}, "{name}: {status} +{amount} HP") if delta > 0 else QuizRpgI18n.tf("combat.status_hp_loss", {"name": str(unit.get("name", enemy_name_str)), "status": def.localized_name(), "amount": -delta}, "{name}: {status} -{amount} HP"), def.color)
			var data: Dictionary = st[sid] if st[sid] is Dictionary else {}
			if int(data.get("turns", 0)) > 0:
				data["turns"] = int(data["turns"]) - 1
				if int(data["turns"]) <= 0:
					st.erase(sid)
					any = true
					_push_log(QuizRpgI18n.tf("combat.status_ended", {"name": str(unit.get("name", enemy_name_str)), "status": def.localized_name()}, "{name}: koniec — {status}."), def.color)
		unit["statuses"] = st
		_enemy_units[ti] = unit
	if not any:
		return false
	_refresh_enemy_cache()
	_refresh_enemy_header()
	_update_hp_bars()
	_refresh_stats_panel()
	await get_tree().create_timer(0.8).timeout
	if _ps and _ps.is_party_defeated():
		_end_combat(false)
		return true
	if _all_enemies_defeated():
		_end_combat(true)
		return true
	return false


func _end_combat(player_won: bool, fled: bool = false) -> void:
	phase = Phase.COMBAT_END
	_log_combat_end(player_won, fled)
	if _ps and _ps.has_method("clear_battle_statuses"):
		_ps.clear_battle_statuses()
	_quiz_panel_controller.reset_question()
	_set_quiz_layout_active(false, false)
	_victory_skip = false
	if action_panel:
		action_panel.visible = false
	if party_command_panel:
		party_command_panel.visible = false
	if actor_command_panel:
		actor_command_panel.visible = false
	result_label.visible = false
	var audio := get_node_or_null("/root/AudioService")
	var victory_log := _get_or_create_victory_log()
	victory_log.visible = true
	if player_won:
		if audio:
			audio.play_sfx_by_name("victory")
		var total_xp_reward :int= enemy.xp_reward + _bonus_xp_reward
		var lvl_before :int= _ps.level if _ps else 1
		var learned: Array[String] = []
		var on_learned := func(i: int, skill_name: String):
			learned.append(skill_name if _ps.is_hero(i) else "%s (%s)" % [skill_name, _member_name(i)])
		if _ps and _ps.has_signal("skill_learned"):
			_ps.skill_learned.connect(on_learned)
		var member_levels := {}   # członek -> najwyższy nowy poziom
		var on_member_level := func(i: int, lvl: int): member_levels[i] = maxi(int(member_levels.get(i, 0)), lvl)
		if _ps and _ps.has_signal("member_level_up"):
			_ps.member_level_up.connect(on_member_level)
		var total_gold := _total_gold_reward()
		if _ps:
			_ps.add_xp(total_xp_reward)
			_ps.add_gold(total_gold)
		var lines: Array[String] = [
			QuizRpgI18n.tf("combat.victory_party", {"name": _ps.player_name if _ps else QuizRpgI18n.t("combat.default_hero_name", "Bohater")}, "{name} i drużyna wygrywają walkę!")
		]
		lines.append(QuizRpgI18n.tf("combat.gained_exp", {"amount": total_xp_reward}, "Zdobyto {amount} EXP!"))
		if total_gold > 0:
			lines.append(QuizRpgI18n.tf("combat.gained_gold", {"amount": total_gold}, "Zdobyto {amount} D!"))
		if _ps and _ps.level > lvl_before:
			lines.append(QuizRpgI18n.tf("combat.hero_level_up", {"name": _ps.player_name, "level": _ps.level}, "{name} osiąga poziom {level}!"))
		for i: int in member_levels:
			lines.append(QuizRpgI18n.tf("combat.hero_level_up", {"name": _member_name(i), "level": int(member_levels[i])}, "{name} osiąga poziom {level}!"))
		if _ps and _ps.has_signal("member_level_up") and _ps.member_level_up.is_connected(on_member_level):
			_ps.member_level_up.disconnect(on_member_level)
		for skill_name in learned:
			lines.append(QuizRpgI18n.tf("combat.new_skill_learned", {"skill": skill_name}, "Nowa umiejętność: {skill}!"))
		if _ps and _ps.has_signal("skill_learned") and _ps.skill_learned.is_connected(on_learned):
			_ps.skill_learned.disconnect(on_learned)
		for item_id in _roll_item_drops():
			lines.append(QuizRpgI18n.tf("combat.item_dropped", {"item": _item_display_name(item_id)}, "Zdobyto: {item}!"))
		_refresh_stats_panel()
		await _show_message_sequence(lines)
	elif fled:
		if audio:
			audio.play_sfx_by_name("flee")
		await _show_message_sequence([QuizRpgI18n.t("combat.escaped", "Uciekasz!")])
	else:
		if audio:
			audio.play_sfx_by_name("defeat")
		await _show_message_sequence([QuizRpgI18n.t("combat.defeat", "Porażka...")])
	_refresh_stats_panel()
	if player_won or fled or not (_ps and _ps.is_party_defeated()):
		await _play_exit_transition()  # przy śmierci drużyny zamiast tego ekran śmierci
	enemy.hp = 0 if player_won else enemy.max_hp
	_clear_enemy_display()
	if get_tree() and get_tree().paused:
		get_tree().paused = false
	if audio:
		audio.return_to_previous_track()
	combat_finished.emit(player_won)
	if not player_won and not fled and _ps and _ps.is_party_defeated():
		# Śmierć drużyny: ekran śmierci zamiast powrotu do eksploracji. Wróg nie wraca do patrolu — jego
		# on_combat_finished odpauzowałby grę i po 2 s przestawił stan na EXPLORING pod ekranem.
		get_tree().root.add_child(DeathScreenScene.instantiate())
		get_parent().queue_free()
		return
	enemy.on_combat_finished(player_won, player)
	for j in _joined:
		if is_instance_valid(j):
			j.hp = 0 if player_won else j.max_hp
			j.on_combat_finished(player_won, player)
	get_parent().queue_free()


func _update_hp_bars() -> void:
	if player_hp_bar and _ps:
		player_hp_bar.value = (float(_ps.hp) / float(_ps.max_hp)) * 100.0


func _log(text: String) -> void:
	result_label.text = text
	result_label.visible = true


func _highlight_action(idx: int) -> void:
	if _actor_select_open:
		return  # kursor jest na liście drużyny
	var buttons := _get_visible_action_buttons() if _action_menu_open else _get_visible_primary_buttons()
	if buttons.is_empty():
		return
	_selected_action_idx = clampi(idx, 0, buttons.size() - 1)
	for btn: Button in [engage_btn, run_btn, exit_btn, atk_btn, skills_btn, def_btn, items_btn]:
		if btn:
			QuizTheme.set_menu_item_selected(btn, btn == buttons[_selected_action_idx])


func _flash_sprite(sprite_control: Control, color: Color) -> void:
	if not sprite_control:
		return
	var tween := create_tween()
	tween.tween_property(sprite_control, "modulate", color, 0.1)
	tween.tween_property(sprite_control, "modulate", Color.WHITE, 0.2)


func _dodge_anim(sprite_control: Control) -> void:
	if not sprite_control:
		return
	var orig_pos := sprite_control.position
	var tween := create_tween()
	tween.tween_property(sprite_control, "position:x", orig_pos.x + 20, 0.1)
	tween.tween_property(sprite_control, "position:x", orig_pos.x, 0.15)


func _set_action_buttons_enabled(enabled: bool) -> void:
	if atk_btn:
		atk_btn.disabled = not enabled
	if def_btn:
		def_btn.disabled = not enabled
	if skills_btn:
		skills_btn.disabled = not enabled
	if items_btn:
		items_btn.disabled = not enabled


func _setup_battlefield_visuals() -> void:
	if player_sprite_node:
		_build_actor_preview(player_sprite_node, player, true)


func _build_actor_preview(slot: Control, actor: Node, flip_h: bool) -> void:
	if slot == null:
		return
	for child in slot.get_children():
		child.queue_free()
	var preview := ActorPreviewScene.instantiate() as Control
	slot.add_child(preview)
	var texture := _extract_actor_texture(actor)
	var sprite_rect := preview.get_node("Center/Sprite") as TextureRect
	var fallback := preview.get_node("Center/Fallback") as Label
	sprite_rect.visible = texture != null
	fallback.visible = texture == null
	sprite_rect.texture = texture
	sprite_rect.flip_h = flip_h
	fallback.text = _fallback_actor_label(actor)

func _setup_enemy_display() -> void:
	_enemy_display_root = get_node_or_null("Battlefield/FieldContent/EnemySection/EnemySprite/EnemyDisplayCanvas") as Node2D
	_enemy_name_label = get_node_or_null("Battlefield/FieldContent/EnemySection/EnemyNameLabel") as Label
	if not _enemy_display_root or not enemy:
		return

	_clear_enemy_display()

	var e_name: String = enemy.localized_name() if enemy.has_method("localized_name") else enemy.enemy_name
	if _enemy_name_label:
		_enemy_name_label.text = e_name

	var units: Array = _enemy_units if _enemy_units.size() > 0 else [{
		"name": e_name,
		"hp": enemy.hp,
		"max_hp": enemy.max_hp,
	}]
	_enemy_active_layout_slots = _select_enemy_layout_slots(units.size())

	_enemy_displays.clear()
	for i in range(units.size()):
		var source_enemy: Node2D = _unit_source(units[i])
		var display: Node2D = _create_enemy_display_clone(source_enemy, i)
		var unit_data: Dictionary = units[i]
		display.sync_hp(int(unit_data.get("hp", source_enemy.hp)))
		display.max_hp = int(unit_data.get("max_hp", source_enemy.max_hp))
		if i < _enemy_active_layout_slots.size():
			var slot: Control = _enemy_active_layout_slots[i].get("slot", null) as Control
			if slot:
				slot.add_child(display)
				var init_sz: Vector2 = slot.size if (slot.size.x > 0.0 and slot.size.y > 0.0) else slot.custom_minimum_size
				if init_sz == Vector2.ZERO:
					init_sz = Vector2(150.0, 150.0)
				display.position = Vector2(init_sz.x * 0.5, init_sz.y - 8.0)
				if not slot.resized.is_connected(_on_enemy_slot_resized):
					slot.resized.connect(_on_enemy_slot_resized.bind(slot))
			else:
				_enemy_display_root.add_child(display)
		else:
			_enemy_display_root.add_child(display)
		_enemy_displays.append(display)

	_enemy_display_node = _enemy_displays[0] if not _enemy_displays.is_empty() else null
	_apply_responsive_enemy_layout()
	_sync_enemy_displays()


func _create_enemy_display_clone(source: Node2D, slot_index: int = 0) -> Node2D:
	var display: Node2D = EnemyBattleDisplayScript.new() as Node2D
	if display.has_method("setup_from_source"):
		display.call("setup_from_source", source)
	else:
		display.body_color = source.body_color
	display.shape_type = int(source.shape_type)
	display.hp = source.hp
	display.max_hp = source.max_hp
	display.scale = _get_enemy_scale(slot_index, false)
	return display


func _sync_enemy_displays() -> void:
	for bar_index in range(_enemy_active_layout_slots.size()):
		var hp_bar: ProgressBar = _enemy_active_layout_slots[bar_index].get("bar", null) as ProgressBar
		if hp_bar == null:
			continue
		if bar_index < _enemy_units.size():
			var enemy_unit: Dictionary = _enemy_units[bar_index]
			var hp_value: int = int(enemy_unit.get("hp", 0))
			var hp_max: int = maxi(int(enemy_unit.get("max_hp", 1)), 1)
			hp_bar.min_value = 0.0
			hp_bar.max_value = float(hp_max)
			hp_bar.value = float(hp_value)
			if hp_value > 0:
				hp_bar.visible = true
				hp_bar.modulate.a = 1.0
				hp_bar.remove_meta(&"fading")
			elif hp_bar.visible and not hp_bar.has_meta(&"fading"):
				# Pokonany wróg: pasek gaśnie razem z animacją śmierci (zgłoszenie usera 2026-10-04 —
				# zostawał pusty pasek).
				hp_bar.set_meta(&"fading", true)
				var fade := hp_bar.create_tween()
				fade.tween_interval(0.2)
				fade.tween_property(hp_bar, "modulate:a", 0.0, 0.4)
				fade.finished.connect(func() -> void: hp_bar.visible = false)
		else:
			hp_bar.visible = false
	if _enemy_displays.is_empty():
		return
	for i in range(_enemy_displays.size()):
		if i >= _enemy_units.size():
			_enemy_displays[i].visible = false
			continue
		var unit_data: Dictionary = _enemy_units[i]
		var display_node: Node2D = _enemy_displays[i]
		var is_alive: bool = int(unit_data.get("hp", 0)) > 0
		if not is_alive:
			if display_node.has_method("is_dying"):
				if not display_node.call("is_dying") and display_node.visible:
					if display_node.has_method("play_death"):
						display_node.call("play_death")
					else:
						display_node.visible = false
			else:
				display_node.visible = false
		else:
			display_node.visible = true
		display_node.max_hp = int(unit_data.get("max_hp", 1))
		display_node.sync_hp(int(unit_data.get("hp", 0)))
	_refresh_enemy_slot_highlight()


func _sync_enemy_display_hit(enemy_index: int) -> void:
	_sync_enemy_displays()
	if enemy_index < 0 or enemy_index >= _enemy_displays.size():
		return
	var display: Node2D = _enemy_displays[enemy_index] as Node2D
	if display == null:
		return
	if display.has_method("is_dying") and display.call("is_dying"):
		return
	if display.has_method("play_hurt"):
		display.call("play_hurt")
	else:
		display.flash_damage()


func _dodge_enemy_display(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= _enemy_displays.size():
		return
	var display: Node2D = _enemy_displays[enemy_index] as Node2D
	if display == null:
		return
	var original_position: Vector2 = display.position
	var tween: Tween = create_tween()
	tween.tween_property(display, "position:x", original_position.x + 18.0, 0.08)
	tween.tween_property(display, "position:x", original_position.x - 10.0, 0.07)
	tween.tween_property(display, "position:x", original_position.x, 0.1)


func _clear_enemy_display() -> void:
	for display_node in _enemy_displays:
		if is_instance_valid(display_node):
			display_node.queue_free()
	_enemy_displays.clear()
	_enemy_display_node = null
	_enemy_active_layout_slots.clear()


func _select_enemy_layout_slots(active_count: int) -> Array[Dictionary]:
	# Miejsca wrogów z pól walki tła (BattleBackgroundLayout: pola, rzędy, pojemność); sloty ze sceny
	# (wrapper: slot + pasek HP) przeniesione na warstwę pola bitwy i ustawiane w _apply_responsive_enemy_layout.
	var selected: Array[Dictionary] = []
	if _enemy_wrapper_pool.is_empty():
		for row_layout in _collect_enemy_row_layouts():
			for slot_data in row_layout:
				_enemy_wrapper_pool.append(slot_data)
	for slot_data in _enemy_wrapper_pool:
		var w: Control = slot_data.get("wrapper", null) as Control
		if w:
			w.visible = false
	if _enemy_wrapper_pool.is_empty() or active_count <= 0:
		return selected
	_ensure_enemy_field_layer()
	_battle_layout = _get_battle_layout()
	var prefs: Array = []
	for enemy_idx in range(active_count):
		prefs.append(str(_enemy_units[enemy_idx].get("row", "")) if enemy_idx < _enemy_units.size() else "")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots: Array = _battle_layout.assign(active_count, prefs, rng)
	for enemy_idx in range(mini(active_count, _enemy_wrapper_pool.size())):
		var slot_data: Dictionary = _enemy_wrapper_pool[enemy_idx].duplicate()
		var spot = spots[enemy_idx]
		if spot == null:  # brak miejsca na polach — przedni rząd pierwszego pola
			spot = BattleBackgroundLayout.Spot.new()
		slot_data["spot"] = spot
		slot_data["is_back_row"] = spot.row > 0
		var wrapper: Control = slot_data.get("wrapper", null) as Control
		var slot: Control = slot_data.get("slot", null) as Control
		if wrapper:
			if wrapper.get_parent() != _enemy_field_layer:
				wrapper.reparent(_enemy_field_layer, false)
			wrapper.visible = true
			wrapper.remove_theme_stylebox_override("panel")
			_bind_enemy_slot_target_input(wrapper, enemy_idx)
		if slot:
			_bind_enemy_slot_target_input(slot, enemy_idx)
		selected.append(slot_data)
	return selected



func _refresh_enemy_slot_highlight() -> void:
	var target_select_active: bool = phase == Phase.TARGET_SELECT
	var focused_enemy_index: int = _active_enemy_index
	if target_select_active and _target_selected_idx >= 0 and _target_selected_idx < _target_entries.size():
		focused_enemy_index = int(_target_entries[_target_selected_idx].get("enemy_index", focused_enemy_index))
	for slot_index in range(_enemy_active_layout_slots.size()):
		var wrapper: Control = _enemy_active_layout_slots[slot_index].get("wrapper", null) as Control
		var slot: Control = _enemy_active_layout_slots[slot_index].get("slot", null) as Control
		var hp_bar: ProgressBar = _enemy_active_layout_slots[slot_index].get("bar", null) as ProgressBar
		var display: Node2D = null
		if slot_index < _enemy_displays.size():
			display = _enemy_displays[slot_index] as Node2D
		if wrapper == null or slot == null:
			continue
		var focused: bool = target_select_active and slot_index == focused_enemy_index
		if focused:
			var cursor: Label = _ensure_enemy_target_cursor(slot)
			var highlight: Control = _ensure_enemy_target_highlight(slot)
			if cursor:
				cursor.visible = true
			if highlight:
				highlight.visible = true
			if hp_bar:
				hp_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if display:
				display.scale = _get_enemy_scale(slot_index, true)
		else:
			if hp_bar:
				hp_bar.modulate = Color(0.82, 0.82, 0.82, 1.0)
			if display:
				display.scale = _get_enemy_scale(slot_index, false)
	if not target_select_active:
		if _enemy_target_cursor_node:
			_enemy_target_cursor_node.visible = false
		if _enemy_target_highlight_node:
			_enemy_target_highlight_node.visible = false


func _bind_enemy_slot_target_input(slot: Control, slot_index: int) -> void:
	if slot == null:
		return
	# Podświetlenie celu (kursor, wypełnienie, narożniki) i inne dzieci nie łapią myszy — inaczej po najechaniu przykrywały
	# slot: mouse_exited kasowało najechanego wroga, a klik trafiał w podświetlenie zamiast w slot.
	for child in slot.find_children("*", "Control", true, false):
		if not child.has_meta(&"enemy_slot"):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta(&"enemy_slot", true)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var parent_control: Control = slot.get_parent() as Control
	if parent_control:
		parent_control.mouse_filter = Control.MOUSE_FILTER_STOP
	var hover_callable: Callable = Callable(self, "_on_enemy_slot_hover").bind(slot_index)
	if not slot.mouse_entered.is_connected(hover_callable):
		slot.mouse_entered.connect(hover_callable)
	var input_callable: Callable = Callable(self, "_on_enemy_slot_gui_input").bind(slot_index)
	if not slot.gui_input.is_connected(input_callable):
		slot.gui_input.connect(input_callable)
	# Zejście z wroga kasuje „najechanego” — inaczej klik w listę celów trafiał w ostatnio najechany sprite
	# (_handle_hovered_enemy_click).
	var exit_callable: Callable = Callable(self, "_on_enemy_slot_exit").bind(slot_index)
	if not slot.mouse_exited.is_connected(exit_callable):
		slot.mouse_exited.connect(exit_callable)
	if parent_control:
		if not parent_control.mouse_entered.is_connected(hover_callable):
			parent_control.mouse_entered.connect(hover_callable)
		if not parent_control.mouse_exited.is_connected(exit_callable):
			parent_control.mouse_exited.connect(exit_callable)
		if not parent_control.gui_input.is_connected(input_callable):
			parent_control.gui_input.connect(input_callable)


func _on_enemy_slot_hover(slot_index: int) -> void:
	if phase != Phase.TARGET_SELECT:
		return
	if slot_index < 0 or slot_index >= _enemy_units.size():
		return
	_hovered_enemy_slot_index = slot_index
	var target_index: int = _find_target_row_index_for_enemy(slot_index)
	if target_index < 0:
		return
	_target_selected_idx = target_index
	_refresh_target_selection()
	_refresh_enemy_slot_highlight()


func _on_enemy_slot_exit(slot_index: int) -> void:
	if _hovered_enemy_slot_index == slot_index:
		_hovered_enemy_slot_index = -1


func _on_enemy_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if phase != Phase.TARGET_SELECT:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if slot_index < 0 or slot_index >= _enemy_units.size():
		return
	var target_index: int = _find_target_row_index_for_enemy(slot_index)
	if target_index < 0:
		return
	_target_selected_idx = target_index
	_refresh_target_selection()
	_confirm_target_selection()


func _find_target_row_index_for_enemy(enemy_index: int) -> int:
	for target_index in range(_target_entries.size()):
		if int(_target_entries[target_index].get("enemy_index", -1)) == enemy_index:
			return target_index
	return -1


func _ensure_enemy_target_cursor(slot: Control) -> Label:
	if _enemy_target_cursor_node == null:
		if _enemy_target_highlight_node:
			_enemy_target_cursor_node = _enemy_target_highlight_node.get_node_or_null("TargetCursor") as Label
		if _enemy_target_cursor_node == null and enemy_target_home_slot:
			_enemy_target_cursor_node = enemy_target_home_slot.get_node_or_null("TargetCursor") as Label
		if _enemy_target_cursor_node == null and enemy_sprite_node:
			_enemy_target_cursor_node = enemy_sprite_node.find_child("TargetCursor", true, false) as Label
		if _enemy_target_cursor_node == null:
			_enemy_target_cursor_node = slot.get_node_or_null("TargetCursor") as Label
	if _enemy_target_cursor_node and _enemy_target_cursor_node.get_parent() != slot:
		var old_parent: Node = _enemy_target_cursor_node.get_parent()
		if old_parent:
			old_parent.remove_child(_enemy_target_cursor_node)
		slot.add_child(_enemy_target_cursor_node)
	return _enemy_target_cursor_node


func _ensure_enemy_target_highlight(slot: Control) -> Control:
	if _enemy_target_highlight_node == null:
		if enemy_target_home_slot:
			_enemy_target_highlight_node = enemy_target_home_slot.get_node_or_null("TargetHighlight") as Control
		if _enemy_target_highlight_node == null and enemy_sprite_node:
			_enemy_target_highlight_node = enemy_sprite_node.find_child("TargetHighlight", true, false) as Control
		if _enemy_target_highlight_node == null:
			_enemy_target_highlight_node = slot.get_node_or_null("TargetHighlight") as Control
	if _enemy_target_highlight_node and _enemy_target_highlight_node.get_parent() != slot:
		var old_parent: Node = _enemy_target_highlight_node.get_parent()
		if old_parent:
			old_parent.remove_child(_enemy_target_highlight_node)
		slot.add_child(_enemy_target_highlight_node)
	return _enemy_target_highlight_node


func _is_pause_menu_open() -> bool:
	var pause_menu: Node = _find_pause_menu_node()
	if pause_menu != null and pause_menu.has_method("is_paused"):
		return bool(pause_menu.call("is_paused"))
	return false


## Menu pauzy z grupy (pause_menu.gd dodaje się w _enter_tree) — wołane co klatkę i przy każdym zdarzeniu wejścia,
## więc bez find_child po całym drzewie (rosło z wielkością poziomu).
func _find_pause_menu_node() -> Node:
	return get_tree().get_first_node_in_group(&"quiz_pause_menu") if get_tree() else null


func _open_pause_menu(start_in_exit_confirm: bool = false) -> void:
	var pause_menu: Node = _find_pause_menu_node()
	if pause_menu == null:
		var pause_scene: PackedScene = load(QuizRpgPaths.path("scenes/ui/pause_menu.tscn")) as PackedScene
		if pause_scene and get_tree() and get_tree().current_scene:
			var new_pause: CanvasLayer = pause_scene.instantiate() as CanvasLayer
			get_tree().current_scene.add_child(new_pause)
			pause_menu = new_pause
	if pause_menu:
		if start_in_exit_confirm and pause_menu.has_method("open_confirm_exit"):
			pause_menu.call("open_confirm_exit")
		elif pause_menu.has_method("open_pause_menu"):
			pause_menu.call("open_pause_menu")


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _get_resolution_scale_factor() -> float:
	var vp_size: Vector2 = UiLayerScale.screen_size(self)
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return 1.0
	var scale_x: float = vp_size.x / 1920.0
	var scale_y: float = vp_size.y / 1080.0
	return clampf(minf(scale_x, scale_y), 0.65, 2.5)


func _get_enemy_scale(slot_index: int, focused: bool = false) -> Vector2:
	var spots: Array = []
	for slot_data in _enemy_active_layout_slots:
		spots.append(slot_data.get("spot", null))
	var s: float = BattleBackgroundLayout.enemy_scale(BattleBackgroundLayout.crowd(spots), UiLayerScale.screen_size(self))
	if slot_index >= 0 and slot_index < _enemy_active_layout_slots.size() and _battle_layout:
		var spot = _enemy_active_layout_slots[slot_index].get("spot", null)
		if spot != null:
			s *= _battle_layout.spot_scale(spot)
	if focused:
		s *= 1.1
	return Vector2(s, s)



func _on_battle_background_layout_changed(layout: BattleBackgroundLayout) -> void:
	_battle_layout = layout
	_apply_responsive_enemy_layout()


func _apply_responsive_enemy_layout() -> void:
	if _enemy_field_layer == null or _enemy_active_layout_slots.is_empty():
		return
	if _battle_layout == null:
		_battle_layout = _get_battle_layout()
	var vp_size: Vector2 = UiLayerScale.screen_size(self)
	var area: Vector2 = _enemy_field_layer.size
	var depth_order: Array = []  # [linia stóp y, wrapper] — dalsi (wyżej na ekranie) rysowani pierwsi
	for slot_idx in range(_enemy_active_layout_slots.size()):
		var slot_data: Dictionary = _enemy_active_layout_slots[slot_idx]
		var wrapper: Control = slot_data.get("wrapper", null) as Control
		var slot: Control = slot_data.get("slot", null) as Control
		var spot = slot_data.get("spot", null)
		if wrapper == null or slot == null or spot == null:
			continue
		var slot_sz: Vector2 = slot.custom_minimum_size if slot.custom_minimum_size != Vector2.ZERO else Vector2(150.0, 150.0)
		wrapper.size = wrapper.get_combined_minimum_size()
		# Stopy wroga (display: środek slotu, 8 px nad jego dołem) w miejscu z pola walki.
		var foot: Vector2 = _battle_layout.foot(spot, area, vp_size, battle_background.size if battle_background else Vector2.ZERO)
		if battle_background and _battle_layout.texture != null:  # px tła -> px warstwy wrogów
			foot = _enemy_field_layer.get_global_transform().affine_inverse() * (battle_background.get_global_transform() * foot)
		wrapper.position = foot - Vector2(wrapper.size.x * 0.5, slot_sz.y - 8.0)
		depth_order.append([foot.y, wrapper])
		if slot_idx < _enemy_displays.size() and _enemy_displays[slot_idx] != null:
			var display: Node2D = _enemy_displays[slot_idx]
			display.position = Vector2(slot_sz.x * 0.5, slot_sz.y - 8.0)
			var is_focused: bool = (phase == Phase.TARGET_SELECT and slot_idx == _target_selected_idx) or slot_idx == _active_enemy_index
			display.scale = _get_enemy_scale(slot_idx, is_focused)
		if not slot.resized.is_connected(_on_enemy_slot_resized):
			slot.resized.connect(_on_enemy_slot_resized.bind(slot))
	# Kolejność rysowania = głębia: tylny rząd pod przednim (stabilnie przy równej linii stóp).
	depth_order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in range(depth_order.size()):
		var w: Control = depth_order[i][1]
		if w.get_parent() == _enemy_field_layer:
			_enemy_field_layer.move_child(w, i)


## Pola walki bieżącego tła (plik `<grafika>_layout.tres`).
func _get_battle_layout() -> BattleBackgroundLayout:
	if battle_background and battle_background.has_method("get_layout"):
		return battle_background.call("get_layout")
	return BattleBackgroundLayout.new()


## Warstwa na całe pole bitwy, na której stoją sloty wrogów (pozycje z pól walki, nie z kontenerów).
func _ensure_enemy_field_layer() -> void:
	if _enemy_field_layer:
		return
	var field_content := get_node_or_null("Battlefield/FieldContent") as Control
	if field_content:
		_enemy_field_layer = field_content.get_node_or_null("EnemyFieldLayer") as Control
	if _enemy_field_layer == null:
		_enemy_field_layer = Control.new()
		_enemy_field_layer.name = "EnemyFieldLayer"
		_enemy_field_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(field_content if field_content else self).add_child(_enemy_field_layer)
		_enemy_field_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _enemy_field_layer.resized.is_connected(_apply_responsive_enemy_layout):
		_enemy_field_layer.resized.connect(_apply_responsive_enemy_layout)



func _style_enemy_progress_bar(_hp_bar: ProgressBar) -> void:
	pass


## Stała wysokość pasa (decyzja usera 2026-10-11: UI nie skacze) = najwyższy z trybów: pas ze sceny
## (BattleWindow.offset_top) + dodatek quizu (poza siatką odpowiedzi), albo najwyższe okno trybów (skala UI — cała warstwa).
## Treść wyższa od tego (np. bardzo długie pytanie) podnosi pas tylko na ten czas (okno rośnie do treści i wraca).
func _get_desired_battle_window_height() -> float:
	var quiz_extra := quiz_band_extra_height if QuizTheme.answers_layout() != QuizTheme.ANSWERS_GRID else 0.0
	return maxf(_band_height + quiz_extra, _band_content_min_height())


## Najwyższe okno ze wszystkich trybów pasa (także ukrytych teraz) + ramki pasa — od początku walki, zanim się pokażą.
func _band_content_min_height() -> float:
	if battle_window == null or content_row == null:
		return 0.0
	var overhead := battle_window.get_combined_minimum_size().y - content_row.get_combined_minimum_size().y
	var tallest := 0.0
	for p: Control in [party_command_panel, actor_command_panel, party_panel_container, list_panel]:
		if p:
			tallest = maxf(tallest, p.get_combined_minimum_size().y)
	return tallest + overhead


## Okno urosło do treści (duże pytanie) albo wróciło — cień za faktyczną wysokością pasa; pole bitwy zostaje
## (okno wchodzi na dół pola, potwory stoją w miejscu).
func _on_battle_window_resized() -> void:
	_fit_field_to_band(maxf(battle_window.size.y, _get_desired_battle_window_height()))


func _update_window_heights() -> void:
	var menu_h: float = _get_desired_battle_window_height()
	if battle_window:
		battle_window.offset_top = -menu_h
	# Pas pod polem bitwy: zwykły pas (poza pytaniem — w pytaniu okno pasa mierzy też treść quizu).
	if phase != Phase.QUIZ or _field_band_h <= 0.0:
		_field_band_h = menu_h
	_fit_field_to_band(maxf(battle_window.size.y, menu_h) if battle_window else menu_h)


## band_h = faktyczna wysokość pasa (cień okna); pole bitwy kończy się nad zwykłym pasem (_field_band_h).
func _fit_field_to_band(band_h: float) -> void:
	var battlefield := get_node_or_null("Battlefield") as Control
	if battlefield:
		battlefield.offset_bottom = -(_field_band_h if _field_band_h > 0.0 else band_h)
	if window_shadow:
		window_shadow.offset_bottom = 0.0
		window_shadow.offset_top = -band_h - _shadow_height


## Opcja „UI walki na szerokość treści”, ale tylko w oknie gry co najmniej compact_min_viewport_width — w węższym
## (np. 1280 px) wąskie okna drużyny / quizu są za ciasne, więc pas idzie na całą szerokość.
func _combat_ui_compact() -> bool:
	return QuizTheme.combat_ui_compact() and not _narrow_window()


## Okno gry węższe niż compact_min_viewport_width — w pikselach okna, nie ekranu logicznego skali UI.
func _narrow_window() -> bool:
	return get_viewport_rect().size.x < compact_min_viewport_width


## Układ dolnego pasa (kolejność i szerokość okien komend / statusu).
func _set_band_mode(mode: Band) -> void:
	if mode != _band_mode:
		_settle_input()
	_band_mode = mode
	if content_row == null or party_command_panel == null or party_panel_container == null:
		return
	if phase == Phase.QUIZ and not party_panel_container.visible:
		return  # quiz zajmuje pas (_set_quiz_layout_active)
	var vp_w: float = UiLayerScale.screen_size(self).x
	party_panel_container.visible = true
	if list_panel:
		list_panel.visible = mode == Band.LIST
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Opcje -> Motyw: „UI walki na szerokość treści” — okno drużyny o stałej szerokości, okna wyśrodkowane
	# (inaczej rozciągnięte na cały ekran).
	var compact := _combat_ui_compact()
	var party_flags := Control.SIZE_SHRINK_CENTER if compact else Control.SIZE_EXPAND_FILL
	var party_min := Vector2(vp_w * compact_party_width, 0) if compact else Vector2.ZERO
	match mode:
		Band.PARTY_COMMAND:
			party_command_panel.visible = true
			if actor_command_panel:
				actor_command_panel.visible = false
			party_command_panel.size_flags_horizontal = Control.SIZE_FILL
			party_command_panel.custom_minimum_size = Vector2(vp_w * party_command_width, 0)
			party_panel_container.size_flags_horizontal = party_flags
			party_panel_container.custom_minimum_size = party_min
		Band.ACTOR_COMMAND:
			party_command_panel.visible = false
			if actor_command_panel:
				actor_command_panel.visible = true
				actor_command_panel.size_flags_horizontal = Control.SIZE_FILL
				actor_command_panel.custom_minimum_size = Vector2(vp_w * actor_command_width, 0)
			party_panel_container.size_flags_horizontal = party_flags
			party_panel_container.custom_minimum_size = party_min
		Band.LIST:
			party_command_panel.visible = false
			if actor_command_panel:
				actor_command_panel.visible = false
			party_panel_container.size_flags_horizontal = Control.SIZE_FILL
			party_panel_container.custom_minimum_size = Vector2(vp_w * list_party_width, 0)
		Band.STATUS_ONLY:
			party_command_panel.visible = false
			if actor_command_panel:
				actor_command_panel.visible = false
			if _narrow_window():
				party_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				party_panel_container.custom_minimum_size = Vector2.ZERO
			else:
				party_panel_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				party_panel_container.custom_minimum_size = Vector2(vp_w * (compact_party_width if compact else status_only_width), 0)


func _update_corner_label() -> void:
	if _corner_label == null:
		return
	var streak := int(_ps.streak) if _ps else 0
	var bonus := float(_ps.rng_bonus) * 100.0 if _ps else 0.0
	_corner_label.text = "Tura %d  ·  seria %d  ·  +%.0f%%" % [turn_number, streak, bonus]


func _apply_responsive_layout() -> void:
	_update_window_heights()

	# Przyciski, wiersze drużyny, czcionki: wygląd ze sceny i motywu (bez nadpisań z kodu).
	# Rozmieszczenie potworków i ich odstępów:
	_apply_responsive_enemy_layout()
	var is_quiz: bool = (phase == Phase.QUIZ and party_panel_container and not party_panel_container.visible)
	if not is_quiz:
		_set_band_mode(_band_mode)


func _on_enemy_slot_resized(slot: Control) -> void:
	if not is_instance_valid(slot):
		return
	var slot_sz: Vector2 = slot.size if (slot.size.x > 0.0 and slot.size.y > 0.0) else slot.custom_minimum_size
	if slot_sz == Vector2.ZERO:
		return
	for child in slot.get_children():
		if child is Node2D:
			child.position = Vector2(slot_sz.x * 0.5, slot_sz.y - 8.0)


func _collect_enemy_row_layouts() -> Array[Array]:
	var rows: Array[Array] = []
	if enemy_sprite_node == null:
		return rows

	var row_nodes: Array[Node] = []
	var r1: Node = enemy_sprite_node.get_node_or_null("EnemyRow1")
	var r2: Node = enemy_sprite_node.get_node_or_null("EnemyRow2")
	if r1:
		row_nodes.append(r1)
	if r2:
		row_nodes.append(r2)
	for child in enemy_sprite_node.get_children():
		if str(child.name).begins_with("EnemyRow") and not child in row_nodes:
			row_nodes.append(child)

	for r_idx in range(row_nodes.size()):
		var child: Node = row_nodes[r_idx]
		var is_back: bool = (str(child.name) == "EnemyRow2") or (r_idx > 0)
		var row_layout: Array[Dictionary] = []
		var row_box: HBoxContainer = child.find_child("HBoxContainer", true, false) as HBoxContainer
		if row_box == null:
			rows.append(row_layout)
			continue
		for wrapper_node in row_box.get_children():
			var wrapper: Control = wrapper_node as Control
			if wrapper == null:
				continue
			var slot: Control = null
			var hp_bar: ProgressBar = null
			for wrapper_child in wrapper.get_children():
				if slot == null and wrapper_child is Control and str(wrapper_child.name).begins_with("EnemySlot"):
					slot = wrapper_child as Control
				elif hp_bar == null and wrapper_child is ProgressBar and str(wrapper_child.name).begins_with("EnemyHPBar"):
					hp_bar = wrapper_child as ProgressBar
			if slot:
				row_layout.append({
					"wrapper": wrapper,
					"slot": slot,
					"bar": hp_bar,
					"row_index": r_idx,
					"is_back_row": is_back,
				})
		rows.append(row_layout)
	return rows


func _extract_actor_texture(actor: Node) -> Texture2D:
	if actor == null:
		return null
	var animated := actor.get_node_or_null("AnimatedSprite2D")
	if animated and animated is AnimatedSprite2D and animated.sprite_frames:
		var anim_name = animated.animation
		if anim_name == StringName("") and animated.sprite_frames.get_animation_names().size() > 0:
			anim_name = animated.sprite_frames.get_animation_names()[0]
		if anim_name != StringName("") and animated.sprite_frames.has_animation(anim_name):
			return animated.sprite_frames.get_frame_texture(anim_name, animated.frame)
	var sprite := actor.get_node_or_null("Sprite2D")
	if sprite and sprite is Sprite2D:
		return sprite.texture
	return null


func _fallback_actor_label(actor: Node) -> String:
	if actor == player:
		var hero_name: String = _ps.player_name if _ps and str(_ps.player_name) != "" else "Bohater"
		return hero_name.left(3).to_upper()
	var enemy_name := enemy_name_str if enemy_name_str != "" else "ENY"
	return enemy_name.left(3).to_upper()


func _roll_enemy_party() -> void:
	_enemy_units.clear()
	var min_count := maxi(1, _encounter_size_range.x)
	var max_count := maxi(min_count, _encounter_size_range.y)
	if not _joined.is_empty():
		# Grupa ze świata (albo boss + jego stała świta): główny wróg + dołączeni, każdy z własnymi statystykami, grafiką
		# i umiejętnościami. Liczba jednostek i tak losowana z zakresu (grupa to minimum) — brakujące miejsca to kopie
		# głównego wroga; boss ma zakres 1..1, więc nigdy nie dostaje kopii.
		var sources: Array = [enemy] + _joined
		var extra := maxi(0, randi_range(min_count, maxi(max_count, sources.size())) - sources.size())
		for _i in range(extra):
			sources.append(enemy)
		var names := {}
		for src in sources:
			var s_name: String = src.localized_name() if src.has_method("localized_name") else src.enemy_name
			names[s_name] = int(names.get(s_name, 0)) + 1
		var seen := {}
		_bonus_xp_reward = 0
		for src in sources:
			var nm: String = src.localized_name() if src.has_method("localized_name") else src.enemy_name
			if int(names[nm]) > 1:
				seen[nm] = int(seen.get(nm, 0)) + 1
				nm = "%s %d" % [nm, seen[nm]]
			var hp_u := maxi(1, int(src.max_hp))  # stałe HP: statystyki z poziomu, bez rozrzutu
			_enemy_units.append({
				"name": nm,
				"hp": hp_u,
				"max_hp": hp_u,
				"atk": maxi(1, int(src.attack)),
				"def": maxi(0, int(src.defense)),
				"mat": maxi(0, int(src.magic_attack)),
				"mdf": maxi(0, int(src.magic_defense)),
				"agi": maxi(1, int(src.get("agility")) if src.get("agility") != null else enemy_base_agility),
				"tier": _get_encounter_tier(src),
				"level": int(src.get("enemy_level")) if src.get("enemy_level") != null else 0,
				"source": src,
			})
			if src != enemy:
				_bonus_xp_reward += int(src.xp_reward)
		_bonus_xp_reward += extra * int(enemy.xp_reward)  # kopie głównego wroga jak w walce bez grupy
		_active_enemy_index = 0
		_refresh_enemy_cache()
		return
	var encounter_count := randi_range(min_count, max_count)
	for enemy_index in range(encounter_count):
		var unit_name := enemy_name_str if encounter_count == 1 else "%s %d" % [enemy_name_str, enemy_index + 1]
		var unit_hp := maxi(1, enemy_max_hp)
		_enemy_units.append({
			"name": unit_name,
			"hp": unit_hp,
			"max_hp": unit_hp,
			"atk": maxi(1, enemy_base_attack),
			"def": maxi(0, enemy_base_defense),
			"mat": maxi(0, enemy_base_magic_attack),
			"mdf": maxi(0, enemy_base_magic_defense),
			"agi": maxi(1, enemy_base_agility),
			"tier": _get_encounter_tier(),
			"level": int(enemy.get("enemy_level")) if enemy.get("enemy_level") != null else 0,
		})
	_active_enemy_index = 0
	_bonus_xp_reward = maxi(0, encounter_count - 1) * enemy.xp_reward
	_refresh_enemy_cache()



func _refresh_enemy_cache() -> void:
	enemy_hp = 0
	enemy_max_hp = 0
	for enemy_unit in _enemy_units:
		enemy_hp += int(enemy_unit.get("hp", 0))
		enemy_max_hp += int(enemy_unit.get("max_hp", 0))
	_active_enemy_index = _find_next_alive_enemy_index(_active_enemy_index)
	if battle_background and battle_background.has_method("refresh_units"):
		battle_background.call("refresh_units", _enemy_units)
	_sync_enemy_displays()


## TP za otrzymane obrażenia jak w FNaFB: TP_PER_FULL_HP_LOST × obrażenia / maks. HP trafionej postaci (mnożnik
## ładowania dolicza _gain_party_tp).
func _tp_from_damage(member: int, damage: int) -> int:
	var max_hp: int = int(_party_state[member].get("lp_max", 1)) if member >= 0 and member < _party_state.size() else 100
	return roundi(TP_PER_FULL_HP_LOST * float(maxi(damage, 0)) / float(maxi(max_hp, 1)))


## Staty członka drużyny / jednostki wroga dla QuizRpgSkillMath ({atk, def, mat, mdf}).
func _member_stats(i: int) -> Dictionary:
	if _ps == null or not _ps.has_method("get_member_total_stat"):
		return {"atk": 20, "def": 0, "mat": 20, "mdf": 0, "agi": 15}
	var out := {}
	for stat in ["atk", "def", "mat", "mdf", "agi"]:
		out[stat] = roundi(_ps.get_member_total_stat(i, stat) * _ps.member_status_mult(i, stat))
	out["statuses"] = _ps.get_statuses(i)
	return out


func _unit_stats(unit: Dictionary) -> Dictionary:
	var base := {"atk": int(unit.get("atk", enemy_base_attack)), "def": int(unit.get("def", enemy_base_defense)),
		"mat": int(unit.get("mat", enemy_base_magic_attack)), "mdf": int(unit.get("mdf", enemy_base_magic_defense)),
		"agi": int(unit.get("agi", enemy_base_agility))}
	for stat in base:
		base[stat] = roundi(base[stat] * _unit_status_mult(unit, stat))
	base["statuses"] = (unit.get("statuses", {}) as Dictionary).keys()
	return base


# --- Statusy wrogów: unit["statuses"] = {id: {turns}} (definicje — QuizRpgStatusCatalog) ---

func _unit_status_defs(unit: Dictionary) -> Array:
	var out: Array = []
	for sid in (unit.get("statuses", {}) as Dictionary).keys():
		var def := QuizRpgStatusCatalog.get_status(String(sid))
		if def:
			out.append(def)
	return out


func _unit_status_mult(unit: Dictionary, stat: String) -> float:
	var m := 1.0
	for def: QuizRpgStatusData in _unit_status_defs(unit):
		m *= def.stat_mult(stat)
	return m


func _unit_hit_mult(unit: Dictionary) -> float:
	var m := 1.0
	for def: QuizRpgStatusData in _unit_status_defs(unit):
		m *= def.hit_mult
	return m


func _unit_restriction(unit: Dictionary, restriction: int) -> QuizRpgStatusData:
	for def: QuizRpgStatusData in _unit_status_defs(unit):
		if def.restriction == restriction:
			return def
	return null


## Nadaje wrogowi status (już nałożony — bez zmian). true = nowy.
func _unit_add_status(ti: int, status_id: String) -> bool:
	var def := QuizRpgStatusCatalog.get_status(status_id)
	if def == null or ti < 0 or ti >= _enemy_units.size():
		return false
	var unit := _enemy_units[ti]
	var st: Dictionary = unit.get("statuses", {})
	if st.has(status_id):
		return false
	st[status_id] = {"turns": def.roll_turns()}
	unit["statuses"] = st
	_enemy_units[ti] = unit
	_push_log(QuizRpgI18n.tf("combat.status_inflicted", {"name": str(unit.get("name", enemy_name_str)), "status": def.localized_name()}, "{name}: {status}!"), def.color)
	return true


## Obrażenia mogą zdjąć wrogowi status (sen, zamroczenie).
func _unit_on_damaged(ti: int) -> void:
	var unit := _enemy_units[ti]
	var st: Dictionary = unit.get("statuses", {})
	for sid in st.keys():
		var def := QuizRpgStatusCatalog.get_status(String(sid))
		if def and def.remove_on_damage_chance > 0.0 and randf() < def.remove_on_damage_chance:
			st.erase(sid)
			_push_log(QuizRpgI18n.tf("combat.status_ended", {"name": str(unit.get("name", enemy_name_str)), "status": def.localized_name()}, "{name}: koniec — {status}."), def.color)
	unit["statuses"] = st
	_enemy_units[ti] = unit


func _member_name(i: int) -> String:
	var member: Dictionary = _ps.get_party_member(i) if _ps and _ps.has_method("get_party_member") else {}
	return str(member.get("name", QuizRpgI18n.t("combat.default_hero_name", "Bohater")))


## Obrażenia członka drużyny mogą zdjąć status (sen budzi).
func _member_damaged(t: int) -> void:
	if _ps == null or not _ps.has_method("on_member_damaged"):
		return
	for sid in _ps.on_member_damaged(t):
		_push_log(QuizRpgI18n.tf("combat.status_ended", {"name": _member_name(t), "status": QuizRpgStatusCatalog.name_of(String(sid))}, "{name}: koniec — {status}."), QuizRpgStatusCatalog.color_of(String(sid)))


## HP członka drużyny w walce (bohater z PlayerStats.hp, reszta z danych drużyny).
func _member_hp(i: int) -> int:
	return int(_ps.member_hp(i)) if _ps and _ps.has_method("member_hp") else 0


func _party_indices(dead: bool) -> Array[int]:
	var out: Array[int] = []
	var n: int = _ps.get_party_members().size() if _ps and _ps.has_method("get_party_members") else 1
	for i in range(n):
		if (_member_hp(i) <= 0) == dead:
			out.append(i)
	return out


func _get_encounter_tier(src: Node = null) -> int:
	var e: Node = src if src != null else enemy
	if e != null:
		var direct_tier: Variant = e.get("encounter_tier")
		if direct_tier is int:
			return clampi(int(direct_tier), 1, 5)
	if e != null and bool(e.get("is_boss")):
		return clampi(_diff_range.y, 1, 5)
	return clampi(int(round(float(_diff_range.x + _diff_range.y) * 0.5)), 1, 5)


func _find_next_alive_enemy_index(start_index: int = 0) -> int:
	if _enemy_units.is_empty():
		return -1
	for offset in range(_enemy_units.size()):
		var index := (start_index + offset) % _enemy_units.size()
		if int(_enemy_units[index].get("hp", 0)) > 0:
			return index
	return -1


func _all_enemies_defeated() -> bool:
	return _find_next_alive_enemy_index(0) < 0


func _refresh_enemy_header() -> void:
	var living_count := 0
	for enemy_unit in _enemy_units:
		if int(enemy_unit.get("hp", 0)) > 0:
			living_count += 1
	if living_count <= 0:
		enemy_name_label.text = QuizRpgI18n.t("combat.enemies_defeated", "Wrogowie pokonani")
		if _enemy_name_label:
			_enemy_name_label.text = enemy_name_label.text
		return
	var rem_str: String = QuizRpgI18n.plural("combat.remaining_count", living_count, {"n": living_count})
	if _active_enemy_index >= 0 and _active_enemy_index < _enemy_units.size():
		var active_enemy := _enemy_units[_active_enemy_index]
		var tags: Array[String] = []
		for def: QuizRpgStatusData in _unit_status_defs(active_enemy):
			tags.append(def.localized_name())
		var suffix := "" if tags.is_empty() else "  [%s]" % ", ".join(tags)
		enemy_name_label.text = "%s%s  (%s)" % [str(active_enemy.get("name", enemy_name_str)), suffix, rem_str]
	else:
		enemy_name_label.text = "%s  (%s)" % [QuizRpgI18n.t("combat.enemies", "Wrogowie"), rem_str]
	if _enemy_name_label:
		_enemy_name_label.text = enemy_name_label.text


func _refresh_stats_panel() -> void:
	if party_rows.is_empty():
		return
	for i in range(_party_state.size()):
		_sync_party_member_from_player(i)
	for i in range(party_rows.size()):
		var row := party_rows[i]
		if i < _party_state.size():
			row.visible = true
			var member := _party_state[i]
			_set_party_row_name(row, str(member.get("name", "Bohater")))
			_set_party_row_statuses(row, i)
			_set_party_stat(row, "StatLP", int(member.get("lp", 0)), int(member.get("lp_max", 1)), "%d/%d" % [int(member.get("lp", 0)), int(member.get("lp_max", 1))])
			_set_party_stat(row, "StatSP", int(member.get("sp", 0)), int(member.get("sp_max", 1)), "%d/%d" % [int(member.get("sp", 0)), int(member.get("sp_max", 1))])
			_set_party_stat(row, "StatTP", int(member.get("tp", 0)), int(member.get("tp_max", 1)), "%d/%d" % [int(member.get("tp", 0)), int(member.get("tp_max", 1))])
		else:
			row.visible = false


func _style_party_row(_row: HBoxContainer) -> void:
	pass


func _style_party_progress_bar(_bar: ProgressBar, _fill_color: Color) -> void:
	pass


## Mnożnik obrażeń bronionego członka: 1/4 po dobrej odpowiedzi, 1/2 po złej.
func _guard_factor(member_index: int) -> float:
	return GUARD_DAMAGE_FACTOR_CORRECT if bool(_guard.get(member_index, false)) else GUARD_DAMAGE_FACTOR_WRONG


## Szansa statusu od umiejętności wroga na członka drużyny: połowa, gdy właśnie się broni.
func _guarded_status_chance(member_index: int, sk: QuizRpgSkillBase) -> float:
	if _guard.has(member_index) and sk.can_be_blocked:
		return sk.status_chance * GUARD_STATUS_CHANCE_FACTOR
	return sk.status_chance


## Statusy postaci w wierszu drużyny: nazwy w kolorach statusów (QuizRpgStatusCatalog), puste = brak.
func _set_party_row_statuses(row: HBoxContainer, member_index: int) -> void:
	var label := row.get_node_or_null("StatusLabel") as RichTextLabel
	if label == null:
		return
	var parts: Array[String] = []
	if _ps and _ps.has_method("get_statuses"):
		for sid in _ps.get_statuses(member_index):
			parts.append("[color=#%s]%s[/color]" % [QuizRpgStatusCatalog.color_of(String(sid)).to_html(false), QuizRpgStatusCatalog.name_of(String(sid))])
	label.text = ", ".join(parts)


func _set_party_row_name(row: HBoxContainer, value: String) -> void:
	var name_label := row.get_node_or_null("NameLabel") as Label
	if name_label:
		name_label.text = value


func _set_party_stat(row: HBoxContainer, stat_name: String, value: int, max_value: int, display_value: String) -> void:
	var stat_box := row.get_node_or_null(stat_name) as Control
	if stat_box == null:
		return
	var bar := stat_box.find_child("Bar", true, false) as ProgressBar
	var value_label := stat_box.find_child("ValueLabel", true, false) as Label
	if bar:
		bar.value = (float(value) / float(maxi(max_value, 1))) * 100.0
	if value_label:
		# Jak w RPG Makerze: sama bieżąca wartość, pełna skala na pasku (display_value = "x/max").
		value_label.text = display_value.get_slice("/", 0)


func _setup_party_layout() -> void:
	if content_row and party_command_panel:
		content_row.move_child(party_command_panel, 0)
	if content_row and party_panel_container:
		content_row.move_child(party_panel_container, 1)
	if content_row and actor_command_panel:
		content_row.move_child(actor_command_panel, 2)


func _set_quiz_layout_active(active: bool, _animated: bool = true) -> void:
	if party_command_panel == null or party_panel_container == null:
		return

	var is_modal_mode := false
	var cheat_service := get_node_or_null("/root/CheatService")
	if cheat_service and "quiz_ui_mode" in cheat_service:
		is_modal_mode = (str(cheat_service.quiz_ui_mode) == "popup")

	if active:
		if is_modal_mode and quiz_modal_overlay and quiz_modal_vbox:
			quiz_modal_overlay.visible = true
			if _quiz_panel_controller and _quiz_panel_controller.quiz_panel:
				if _quiz_panel_controller.quiz_panel.get_parent() != quiz_modal_vbox:
					_quiz_panel_controller.quiz_panel.reparent(quiz_modal_vbox, false)
				if result_label and result_label.get_parent() != quiz_modal_vbox:
					result_label.reparent(quiz_modal_vbox, false)
				if _quiz_panel_controller.correct_answer_label and _quiz_panel_controller.correct_answer_label.get_parent() != quiz_modal_vbox:
					_quiz_panel_controller.correct_answer_label.reparent(quiz_modal_vbox, false)
		else:
			# Bottom bar mode: hide party panel and actor command panel, show quiz panel in party_command_panel
			# (opcja „UI walki tylko na szerokość treści”: okno quizu na szerokość pytania i odpowiedzi).
			_apply_answers_layout()
			# Marginesy okna komend (styl panelu + CommandMargin) — z minimalnych rozmiarów, niezależnie od układu.
			var margins: float = party_command_panel.get_combined_minimum_size().x - command_vbox.get_combined_minimum_size().x if command_vbox else 0.0
			party_panel_container.visible = false
			if actor_command_panel:
				actor_command_panel.visible = false
			party_command_panel.visible = true
			if _combat_ui_compact() and _quiz_panel_controller:
				var vp_w: float = UiLayerScale.screen_size(self).x
				var w: float = _quiz_panel_controller.get_desired_panel_width() + maxf(margins, 0.0)
				party_command_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				party_command_panel.custom_minimum_size = Vector2(clampf(w, vp_w * compact_quiz_min_width, vp_w * 0.95), 0)
			else:
				party_command_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				party_command_panel.custom_minimum_size = Vector2(0, 0)
			if action_panel:
				action_panel.visible = false
			if _quiz_panel_controller and _quiz_panel_controller.quiz_panel:
				_quiz_panel_controller.quiz_panel.visible = true
				_quiz_panel_controller.quiz_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		# Deactivate modal if it was open
		if quiz_modal_overlay and quiz_modal_overlay.visible:
			quiz_modal_overlay.visible = false
		if command_vbox:
			if _quiz_panel_controller and _quiz_panel_controller.quiz_panel and _quiz_panel_controller.quiz_panel.get_parent() != command_vbox:
				_quiz_panel_controller.quiz_panel.reparent(command_vbox, false)
			if result_label and result_label.get_parent() != _result_home():
				result_label.reparent(_result_home(), false)
			if _quiz_panel_controller and _quiz_panel_controller.correct_answer_label and _quiz_panel_controller.correct_answer_label.get_parent() != _top_home():
				_quiz_panel_controller.correct_answer_label.reparent(_top_home(), false)

		# Restore bottom bar layout
		party_panel_container.visible = true
		party_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		party_command_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		party_command_panel.custom_minimum_size = Vector2(260, 0)
		if action_panel:
			action_panel.visible = true
		if _quiz_panel_controller and _quiz_panel_controller.quiz_panel:
			_quiz_panel_controller.quiz_panel.visible = false
		_set_band_mode(_band_mode)


## Stan walki każdego członka drużyny (PlayerStats.party): HP z PlayerStats, pula SP / TP na walkę (jak u lidera).
func _init_party_state() -> void:
	_party_state.clear()
	var n: int = _ps.get_party_members().size() if _ps and _ps.has_method("get_party_members") else 1
	for i in range(maxi(n, 1)):
		_party_state.append(_new_member_state())
		_sync_party_member_from_player(i)
	if _ps and _ps.has_signal("member_recruited") and not _ps.member_recruited.is_connected(_on_member_recruited):
		_ps.member_recruited.connect(_on_member_recruited)


## Stan walki uczestnika: TP na start losowo TP_START_MIN..TP_START_MAX (także przy dołączeniu w trakcie walki).
func _new_member_state() -> Dictionary:
	return {
		"name": "",
		"lp": 0,
		"lp_max": 1,
		"sp": PARTY_SKILL_SP_MAX,
		"sp_max": PARTY_SKILL_SP_MAX,
		"tp": randi_range(TP_START_MIN, TP_START_MAX),
		"tp_max": PARTY_TP_MAX,
	}


## Postać zwerbowana w trakcie walki (PlayerStats.recruit — zadanie, zdarzenie walki, menu deweloperskie) od razu
## dołącza do walki: wiersz w oknie drużyny, TP jak na start walki, komendy od następnej rundy (w bieżącej nie działa).
## Okno drużyny ma party_rows.size() wierszy — dalsze postacie są w drużynie, ale nie walczą (jak dotąd).
func _on_member_recruited(index: int, _hero_id: String) -> void:
	if phase == Phase.COMBAT_END:
		return
	while _party_state.size() <= index:
		_party_state.append(_new_member_state())
		_sync_party_member_from_player(_party_state.size() - 1)
	if index < party_rows.size():
		_push_log(QuizRpgI18n.tf("combat.member_joins_battle", {"name": _member_name(index)}, "{name} dołącza do walki!"), Color(0.55, 0.85, 1.0))
	_refresh_stats_panel()


## Imię i HP członka z PlayerStats (lider: player_name / hp / max_hp, reszta: dane drużyny).
func _sync_party_member_from_player(index: int = 0) -> void:
	if _ps == null or index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	var m: Dictionary = _ps.get_party_member(index) if _ps.has_method("get_party_member") else {}
	member["name"] = str(m.get("name", "?"))
	member["lp"] = _member_hp(index)
	member["lp_max"] = maxi(int(m.get("max_hp", 1)), 1)
	_party_state[index] = member


## TP za trafienia i otrzymane obrażenia — × mnożnik ładowania postaci (TCR); charge = false: bez mnożnika (regeneracja).
func _gain_party_tp(index: int, amount: int, charge: bool = true) -> void:
	if index < 0 or index >= _party_state.size():
		return
	var gain := roundi(maxi(amount, 0) * (_member_hero_value(index, "tp_charge_rate", 1.0) if charge else 1.0))
	var member := _party_state[index]
	member["tp"] = clampi(int(member.get("tp", 0)) + gain, 0, int(member.get("tp_max", PARTY_TP_MAX)))
	_party_state[index] = member


## SP / TP członka z walki (walka trzyma je w _party_state) — do PlayerStats.item_block_reason / use_item_on_member.
func _item_values(index: int) -> Dictionary:
	if index < 0 or index >= _party_state.size():
		return {}
	var m := _party_state[index]
	return {"sp": int(m.get("sp", 0)), "max_sp": int(m.get("sp_max", PARTY_SKILL_SP_MAX)), "tp": int(m.get("tp", 0)), "max_tp": int(m.get("tp_max", PARTY_TP_MAX))}


func _consume_party_sp(index: int, amount: int) -> void:
	if index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	member["sp"] = clampi(int(member.get("sp", 0)) - maxi(amount, 0), 0, int(member.get("sp_max", PARTY_SKILL_SP_MAX)))
	_party_state[index] = member


func _restore_party_sp(index: int, amount: int) -> void:
	if index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	member["sp"] = clampi(int(member.get("sp", 0)) + maxi(amount, 0), 0, int(member.get("sp_max", PARTY_SKILL_SP_MAX)))
	_party_state[index] = member


## Pole danych postaci (QuizRpgHeroData) członka drużyny; domyślna wartość bez danych.
func _member_hero_value(index: int, field: String, fallback: Variant) -> Variant:
	if _ps == null or not _ps.has_method("hero_for_member"):
		return fallback
	var members: Array = _ps.get_party_members()
	if index < 0 or index >= members.size():
		return fallback
	var hero = _ps.hero_for_member(members[index])
	return hero.get(field) if hero != null and hero.get(field) != null else fallback


## Regeneracja TP na koniec rundy (TRG w FNaFB): tp_regen z danych postaci, bez mnożnika ładowania.
func _regen_party_tp() -> void:
	for i in _party_indices(false):
		var regen := int(_member_hero_value(i, "tp_regen", 0))
		if regen > 0:
			_gain_party_tp(i, regen, false)


func _restore_party_tp(index: int, amount: int) -> void:
	if index < 0 or index >= _party_state.size():
		return
	var member := _party_state[index]
	member["tp"] = clampi(int(member.get("tp", 0)) + maxi(amount, 0), 0, int(member.get("tp_max", PARTY_TP_MAX)))
	_party_state[index] = member


func _show_primary_menu() -> void:
	_close_actor_select()
	_action_menu_open = false
	primary_menu.visible = true
	action_menu.visible = false
	_selected_action_idx = 0
	_set_band_mode(Band.PARTY_COMMAND)


func _show_action_menu() -> void:
	if target_panel and target_panel.visible:  # wybór celu przerwany innym wejściem — wiersze drużyny wracają
		_hide_target_panel()
		_refresh_stats_panel()
	_action_menu_open = true
	primary_menu.visible = false
	action_menu.visible = true
	_selected_action_idx = 0
	_set_band_mode(Band.ACTOR_COMMAND)


func _get_visible_action_buttons() -> Array[Button]:
	var visible_buttons: Array[Button] = []
	for btn in _action_buttons:
		if btn.visible:
			visible_buttons.append(btn)
	return visible_buttons


func _get_visible_action_count() -> int:
	if _action_menu_open:
		return maxi(_get_visible_action_buttons().size(), 1)
	return maxi(_get_visible_primary_buttons().size(), 1)


func _get_visible_primary_buttons() -> Array[Button]:
	var visible_buttons: Array[Button] = []
	for btn: Button in [engage_btn, run_btn, exit_btn]:
		if btn and btn.visible:
			visible_buttons.append(btn)
	return visible_buttons


func _on_engage_pressed() -> void:
	if phase != Phase.ACTION_SELECT:
		return
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("click")
	_input_pos = -1
	_next_input()


func _on_run_pressed() -> void:
	if phase != Phase.ACTION_SELECT:
		return
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("click")
	_close_actor_select()
	_start_flee()


func _close_actor_select() -> void:
	if not _actor_select_open:
		return
	_actor_select_open = false
	_refresh_actor_selection()


func _is_actor_selectable(index: int) -> bool:
	if index < 0 or index >= _party_state.size() or index >= party_rows.size():
		return false
	if _ally_pick == 2:
		return int(_party_state[index].get("lp", 0)) <= 0  # wskrzeszenie: tylko nieprzytomni
	return int(_party_state[index].get("lp", 0)) > 0


func _has_active_actor() -> bool:
	return _active_actor_index >= 0 and _active_actor_index < _party_state.size()


## Pierwsza postać zdolna do walki od `start` w kierunku `step` (z zawinięciem); 0, gdy brak.
func _find_selectable_actor(start: int, step: int) -> int:
	var count := mini(_party_state.size(), party_rows.size())
	if count <= 0:
		return 0
	for offset in range(count):
		var idx := posmod(start + offset * step, count)
		if _is_actor_selectable(idx):
			return idx
	return 0


func _navigate_actor_list(delta: int) -> void:
	var count := mini(_party_state.size(), party_rows.size())
	if count <= 1:
		return
	_actor_selected_idx = _find_selectable_actor(posmod(_actor_selected_idx + delta, count), delta)
	_refresh_actor_selection()


## Kursor na liście drużyny służy tylko do wyboru sojusznika (leczenie / wskrzeszenie) — komendy postaci idą po kolei.
func _confirm_actor_selection() -> void:
	if _is_actor_selectable(_actor_selected_idx):
		_confirm_ally_pick()


func _cancel_actor_selection() -> void:
	_cancel_ally_pick()


func _refresh_actor_selection() -> void:
	for row in party_rows:
		row.queue_redraw()


## Kursor na wierszu drużyny: ten sam styl „selected” co pozycje menu (pasek pod wierszem). Ramka szersza od
## wiersza o margines treści stylu (jak tło przycisku menu wokół tekstu) — inaczej nazwa i liczby leżą na krawędzi.
func _draw_party_row_cursor(index: int) -> void:
	var at := _actor_selected_idx if _actor_select_open else (_active_actor_index if (phase == Phase.ACTION_SELECT and _action_menu_open) or phase == Phase.TARGET_SELECT else -1)
	if index != at or index >= party_rows.size():
		return
	var row := party_rows[index]
	var sb := row.get_theme_stylebox(&"selected", QuizTheme.MENU_ITEM)
	if sb == null:
		return
	var pad_l := maxf(sb.get_margin(SIDE_LEFT), PARTY_CURSOR_MIN_PAD)
	var pad_r := maxf(sb.get_margin(SIDE_RIGHT), PARTY_CURSOR_MIN_PAD)
	row.draw_style_box(sb, Rect2(-pad_l, 0.0, row.size.x + pad_l + pad_r, row.size.y))


## Mysz na liście drużyny w czasie wyboru postaci: najechanie przesuwa kursor, klik zatwierdza.
func _handle_actor_row_mouse(event: InputEvent) -> bool:
	if phase != Phase.ACTION_SELECT or not _actor_select_open:
		return false
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return false
	# Położenie ze zdarzenia (w _input już w układzie viewportu), nie z bieżącej pozycji kursora.
	var mouse_pos: Vector2 = (event as InputEventMouse).position
	for i in range(party_rows.size()):
		var row := party_rows[i]
		var local: Vector2 = row.get_global_transform_with_canvas().affine_inverse() * mouse_pos
		if not row.is_visible_in_tree() or not Rect2(Vector2.ZERO, row.size).has_point(local):
			continue
		if not _is_actor_selectable(i):
			return false
		if event is InputEventMouseMotion:
			if _actor_selected_idx != i:
				_actor_selected_idx = i
				_refresh_actor_selection()
			return false
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_actor_selected_idx = i
			_confirm_actor_selection()
			return true
		return false
	return false


func _on_exit_pressed() -> void:
	if phase != Phase.ACTION_SELECT:
		return
	_open_pause_menu(true)


## Okno komunikatów po bitwie ma szerokość UI walki (wyśrodkowane): zakres widocznych okien paska tuż przed ich ukryciem,
## nie mniej niż status_only_width.
func _fit_message_window_width() -> void:
	var vp_w := UiLayerScale.screen_size(self).x
	var left := INF
	var right := -INF
	if content_row:
		for c in content_row.get_children():
			if c is Control and (c as Control).visible:
				left = minf(left, (c as Control).global_position.x)
				right = maxf(right, (c as Control).global_position.x + (c as Control).size.x)
	var width := maxf(right - left, vp_w * status_only_width) if right > left else vp_w * status_only_width
	_message_window.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_message_window.custom_minimum_size.x = minf(width, vp_w)


func _get_or_create_victory_log() -> Label:
	# Jak w RPG Makerze: komunikaty po bitwie zajmują cały dolny pas (MessageWindow ze sceny; okna
	# statusu i komend znikają), log u góry gaśnie.
	_fit_message_window_width()
	# Okno komunikatów ma tę samą wysokość co zastępowane okna statusu i komend — więcej linii nie powiększa go,
	# tylko dzieli się na strony (_show_message_sequence).
	var fixed_h := content_row.size.y if content_row and content_row.visible else 0.0
	if fixed_h > 0.0:
		_message_window.custom_minimum_size.y = fixed_h
	if content_row:
		content_row.visible = false
	_message_window.visible = true
	_clear_battle_log()
	_top_window.visible = false
	return _victory_label


## Komunikaty po bitwie: linie dopisują się, aż okno jest pełne; wtedy czeka na zatwierdzenie (Enter) i zaczyna
## następną stronę. Ostatnia strona znika sama po chwili albo po zatwierdzeniu.
func _show_message_sequence(lines: Array[String]) -> void:
	var lbl := _get_or_create_victory_log()
	lbl.text = ""
	lbl.visible = true
	_victory_skip = false
	_message_window.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var capacity := _victory_page_capacity(lbl)
	await _fade_in_message_window()
	var page := ""
	for line in lines:
		var candidate := line if page == "" else page + "\n" + line
		lbl.text = candidate
		if page != "" and lbl.get_line_count() > capacity:
			lbl.text = page
			_victory_skip = false
			_set_more_marker(true)
			while not _victory_skip:
				await get_tree().create_timer(0.05).timeout
			_set_more_marker(false)
			page = ""
			candidate = line
			lbl.text = candidate
		if not _victory_skip:
			await _type_label(lbl, page.length() + (1 if page != "" else 0))  # tylko nowa linia
		page = candidate
		if _victory_skip:
			continue
		await _wait_for_victory_advance(1.2)
	if not _victory_skip:
		await _wait_for_victory_advance(3.0)
	var fade_out := create_tween()
	fade_out.tween_property(_message_window, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished


## Okno komunikatów (dolny pas) wyłania się z przezroczystości.
func _fade_in_message_window() -> void:
	_message_window.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_message_window, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


## Komunikat wypisuje się znak po znaku od `from` widocznych znaków; Enter / Z / klik dopisuje resztę od razu.
func _type_label(lbl: Label, from: int = 0) -> void:
	var total := lbl.get_total_character_count()
	var shown := float(mini(from, total))
	lbl.visible_characters = int(shown)
	_typing = true
	_type_skip = false
	while shown < total and not _type_skip and is_inside_tree():
		await get_tree().process_frame
		shown += get_process_delta_time() * MESSAGE_CHARS_PER_SEC
		lbl.visible_characters = mini(int(shown), total)
	lbl.visible_characters = -1
	_typing = false


## Ile linii mieści okno komunikatów (po ustawieniu stałej wysokości); minimum 1.
func _victory_page_capacity(lbl: Label) -> int:
	var font := lbl.get_theme_font("font")
	var font_h := font.get_height(lbl.get_theme_font_size("font_size"))
	var spacing := lbl.get_theme_constant("line_spacing")
	var panel := _message_window.get_theme_stylebox("panel")
	var avail := _message_window.size.y - (panel.get_minimum_size().y if panel else 0.0)
	if avail <= 0.0 or font_h <= 0.0:
		return 4
	return maxi(1, int(floor((avail + spacing) / (font_h + spacing))))


## Migający trójkąt „dalej” w prawym dolnym rogu okna komunikatów (czeka na zatwierdzenie).
func _set_more_marker(on: bool) -> void:
	if _more_marker == null:
		return
	if _more_marker_tween:
		_more_marker_tween.kill()
		_more_marker_tween = null
	_more_marker.visible = on
	if not on:
		return
	_more_marker.position = _message_window.size - Vector2(56, 50)
	_more_marker.modulate.a = 1.0
	_more_marker_tween = create_tween().set_loops()
	_more_marker_tween.tween_property(_more_marker, "modulate:a", 0.25, 0.45)
	_more_marker_tween.tween_property(_more_marker, "modulate:a", 1.0, 0.45)


func _wait_for_victory_advance(max_wait: float) -> void:
	var elapsed := 0.0
	while elapsed < max_wait and not _victory_skip:
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05


## Wpis do logu progresji (QuizRpgProgressLog): wynik, wrogowie z poziomami, XP, tury, czas walki.
func _log_combat_end(player_won: bool, fled: bool) -> void:
	var names: Array[String] = []
	for u in _enemy_units:
		var src: Variant = u.get("source", enemy)
		var lv: int = int(src.get("enemy_level")) if src != null and src.get("enemy_level") != null else 0
		names.append("%s%s t%d" % [str(u.get("name", "?")), " lv%d" % lv if lv > 0 else "", int(u.get("tier", 1))])
	var outcome := "wygrana" if player_won else ("ucieczka" if fled else "porazka")
	var xp := (int(enemy.xp_reward) + _bonus_xp_reward) if player_won else 0
	var gold := _total_gold_reward() if player_won else 0
	QuizRpgProgressLog.combat_end(_ps, outcome, ", ".join(names), _is_boss_encounter(), xp, turn_number, float(Time.get_ticks_msec() - _combat_started_msec) / 1000.0, gold)


## Złoto z pokonanych jednostek walki: każda liczy się jak jej wróg-źródło (grupa ze świata) albo główny wróg (kopie).
func _total_gold_reward() -> int:
	var total := 0
	for u in _enemy_units:
		var src: Variant = u.get("source", enemy)
		total += int(src.gold_reward) if is_instance_valid(src) and src.get("gold_reward") != null else int(enemy.gold_reward)
	return total


## Klucz z pokonanych wrogów bez tabeli łupu (loot_data / "enemy_loot" w JSON mapy, np. tutorial): każdy wróg osobno, szansa rośnie
## z tierem (boss = tier 4); klucz tieru 1. Mapy z "enemy_loot" mają klucze w swojej tabeli. Wytrychy wypadają z beczek (LootManager).
const KEY_DROP_ITEM := "key_tier1"
const KEY_DROP_CHANCE_BY_TIER := {1: 0.04, 2: 0.07, 3: 0.11, 4: 0.3}


func _roll_item_drops() -> Array[String]:
	var dropped: Array[String] = []
	for unit in _enemy_units:
		# Łup z tabeli wroga (loot_data, .tres): źródło jednostki (grupa ze świata) albo główny wróg (kopie).
		var src: Variant = unit.get("source", enemy)
		var data: QuizRpgLootTableData = src.get("loot_data") if is_instance_valid(src) and src.get("loot_data") != null else enemy.loot_data
		# Bez wyrażenia warunkowego: „a if … else []” daje zwykłą Array i przypisanie do Array[Dictionary] się wywala.
		var table: Array[Dictionary] = []
		if data != null:
			table = data.to_table()
		if table.is_empty():
			var chance := float(KEY_DROP_CHANCE_BY_TIER.get(clampi(int(unit.get("tier", 1)), 1, 4), 0.04))
			if randf() < chance and _ps and _ps.has_method("add_item"):
				_ps.add_item(KEY_DROP_ITEM)
				dropped.append(KEY_DROP_ITEM)
		for e in QuizRpgLootTable.roll_chances(table):
			var id := str(e.get("item_id", ""))
			if id != "" and _ps and _ps.has_method("add_item"):
				_ps.add_item(id, QuizRpgLootEntry.roll_count(e))
				dropped.append(id)
	return dropped


func _item_display_name(item_id: String) -> String:
	var inv := get_node_or_null("/root/CoreManager")
	var svc: Variant = inv.call("get_singleton", "InventoryService") if inv else null
	var data: QuizRpgItemData = svc.call("get_item", item_id) if svc is Node else null
	return data.localized_name() if data != null else item_id


func _find_current_map_node() -> Node:
	var node: Node = enemy
	while node:
		var script := node.get_script() as Script
		if script and script.resource_path.contains("/scripts/maps/"):
			return node
		if str(node.name).to_snake_case().contains("map"):
			return node
		node = node.get_parent()
	return null


func _result_home() -> Node:
	var sink := _top_vbox.get_node_or_null("ResultSink") if _top_vbox else null
	return sink if sink else command_vbox


func _top_home() -> Node:
	return _top_vbox if _top_vbox else command_vbox


## Komunikat do logu u góry (ostatnie log_lines).
func _push_log(text: String, color: Color) -> void:
	if text.strip_edges() == "":
		return
	_log_lines.append("[color=#%s]%s[/color]" % [color.to_html(false), text.replace("[", "[lb]")])
	while _log_lines.size() > log_lines:
		_log_lines.pop_front()
	if _log_label:
		_log_label.text = "\n".join(_log_lines)


func _clear_battle_log() -> void:
	_log_lines.clear()
	_last_logged = ""
	if _log_label:
		_log_label.text = ""


## Co klatkę: nowe komunikaty z result_label do logu; okno u góry widoczne w czasie quizu albo gdy
## log nie jest pusty (pytanie i czas tylko w czasie quizu).
## Opcje -> Motyw: „Pytanie w walce” — pytanie i pasek czasu w oknie logu u góry (jak w scenie) albo
## w menu walki: w panelu quizu pod tytułem, tuż nad odpowiedziami (jak przed oknem logu).
func _apply_question_position() -> void:
	if _top_vbox == null or _timer_row == null or _quiz_panel_controller == null:
		return
	var question: Label = _quiz_panel_controller.question_label
	var panel: Control = _quiz_panel_controller.quiz_panel
	if question == null or panel == null:
		return
	if QuizTheme.question_position() == QuizTheme.QUESTION_IN_MENU:
		var title := panel.get_node_or_null("QuizTitle")
		var at := title.get_index() + 1 if title != null else 0
		if question.get_parent() != panel:
			question.reparent(panel, false)
		panel.move_child(question, at)
		if _timer_row.get_parent() != panel:
			_timer_row.reparent(panel, false)
		panel.move_child(_timer_row, at + 1)
	else:
		if question.get_parent() != _top_vbox:
			question.reparent(_top_vbox, false)
		_top_vbox.move_child(question, 0)
		if _timer_row.get_parent() != _top_vbox:
			_timer_row.reparent(_top_vbox, false)
		_top_vbox.move_child(_timer_row, 1)
	_update_top_window()


## Opcje -> Motyw: „Odpowiedzi w walce” — lista (1 kolumna) albo siatka 2 kolumny (MC_Box to GridContainer;
## nawigacja klawiaturą w QuizPanelController obsługuje układ 2×2).
func _apply_answers_layout() -> void:
	if _quiz_panel_controller == null or not (_quiz_panel_controller.mc_box is GridContainer):
		return
	(_quiz_panel_controller.mc_box as GridContainer).columns = 2 if QuizTheme.answers_layout() == QuizTheme.ANSWERS_GRID else 1


func _update_top_window() -> void:
	if _top_window == null:
		return
	if phase == Phase.COMBAT_END:
		_top_window.visible = false
		return
	if result_label.visible and result_label.text != _last_logged:
		_last_logged = result_label.text
		_push_log(result_label.text, result_label.get_theme_color("font_color"))
	elif not result_label.visible:
		_last_logged = ""
	var qpc = _quiz_panel_controller
	var quiz_on: bool = qpc != null and qpc.quiz_panel.visible and not (quiz_modal_overlay and quiz_modal_overlay.visible)
	qpc.question_label.visible = quiz_on
	_timer_row.visible = quiz_on
	var help_on: bool = help_label != null and help_label.visible
	_log_label.visible = not _log_lines.is_empty() and not help_on
	var question_in_log: bool = qpc.question_label.get_parent() == _top_vbox  # opcja „Pytanie w walce”
	_top_window.visible = (quiz_on and question_in_log) or not _log_lines.is_empty() or qpc.correct_answer_label.visible or help_on
