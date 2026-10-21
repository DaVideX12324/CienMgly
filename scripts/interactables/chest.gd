extends AnimatedSprite2D
class_name Chest

const InteractPromptScript = preload("../ui/interact_prompt.gd")
const QuizRpgPaths = preload("../quiz_rpg_paths.gd")

@export var lock_id: String = "dungeon_1"
@export var unique_id: String = ""
@export var chest_item_id: String = "potion"
@export_range(1, 99, 1) var chest_item_count: int = 1
## Tabela łupu z mapy ("chest_loot" w JSON: [{item_id, weight, count}]); niepusta = skrzynia losuje z niej zamiast chest_item_id.
var loot_table: Array = []
## Tabela łupu tej skrzyni (plik .tres, resources/loot/; jeden wpis wybierany wagowo) — ma pierwszeństwo przed loot_table
## z JSON mapy i przed chest_item_id. Tabela strefy ("chest_loot" w JSON jako ścieżka .tres) trafia tutaj, gdy pusta.
@export var loot_data: QuizRpgLootTableData
## Poziom skrzyni: wyznacza trudność quizu przy otwieraniu wytrychem (pytań: 2 + tier, wymagane: o jedno mniej), klucz
## (KEY_ITEMS: klucz tieru ≥ tier skrzyni) i wygląd (tier_frames).
@export_range(1, 4, 1) var tier: int = 1:
	set(value):
		tier = value
		_apply_tier_look()
## Wygląd skrzyni wg tieru (indeks = tier − 1; animacja "open"); pusta lista albo brak wpisu = bez zmiany (np. skrzynia ścieków).
@export var tier_frames: Array[SpriteFrames] = []
@export var quiz_id: String = "inf_podst"
@export var quiz_category: String = "ogolne"

var is_locked: bool = true
var opened: bool = false
var was_already_opened: bool = false
var _player_in_interaction_range: bool = false
var _picking: bool = false
var door_name: String = "Zamknięta skrzynia"  # tytuł okna quizu (QuizPuzzleController czyta door_name)

## Klucz tieru N otwiera skrzynie tieru ≤ N; najpierw zużywany jest najsłabszy wystarczający. Złoty = klucz uniwersalny.
const KEY_ITEMS := {1: "key_tier1", 2: "key_tier2", 3: "key_tier3", 4: "universal_key"}
const LOCKPICK_ITEM := "lockpick"
## Szansa złamania wytrycha po nieudanym quizie (po udanym wytrych zawsze się zużywa).
const LOCKPICK_BREAK_CHANCE := 0.5
static var PUZZLE_UI_SCENE: String = QuizRpgPaths.path("scenes/quiz/quiz_puzzle_ui.tscn")


func _ready() -> void:
	add_to_group("chests")
	add_to_group("interactable")
	_apply_tier_look()
	if unique_id.is_empty():
		unique_id = _generate_unique_id()
	call_deferred("_check_if_opened")


## Wygląd skrzyni z tier_frames (po zmianie tieru, np. z konfiguracji mapy); zachowuje klatkę, a otwartą pokazuje otwartą.
func _apply_tier_look() -> void:
	var i := clampi(tier, 1, 4) - 1
	if i >= tier_frames.size() or tier_frames[i] == null or sprite_frames == tier_frames[i]:
		return
	var current_frame := frame
	sprite_frames = tier_frames[i]
	animation = &"open"
	var last := sprite_frames.get_frame_count(&"open") - 1
	frame = last if opened else clampi(current_frame, 0, last)


func _unhandled_input(event: InputEvent) -> void:
	if opened or not _player_in_interaction_range:
		return
	if event.is_action_pressed("interact"):
		try_open()
		get_viewport().set_input_as_handled()


func _check_if_opened() -> void:
	var level_path := _get_current_level_path()
	if level_path.is_empty():
		await get_tree().process_frame
		_check_if_opened()
		return

	var level_state_manager := _get_level_state_manager()
	if level_state_manager and level_state_manager.is_chest_opened(level_path, unique_id):
		was_already_opened = true
		opened = true
		is_locked = false
		play("open")


func _generate_unique_id() -> String:
	var id_parts: Array[String] = ["chest"]
	if name != "Chest" and not name.begins_with("@"):
		id_parts.append(name.replace("@", "").strip_edges().to_lower())
	var pos_x := int(global_position.x / 10.0) * 10
	var pos_y := int(global_position.y / 10.0) * 10
	id_parts.append(str(pos_x))
	id_parts.append(str(pos_y))
	if not lock_id.is_empty() and lock_id != "dungeon_1":
		id_parts.append(lock_id)
	return "_".join(id_parts)


## Otwarcie przez gracza: wytrych uruchamia quiz (tier skrzyni = trudność), klucz tieru ≥ tier skrzyni otwiera od razu;
## wytrych jest używany przed kluczem (klucze są rzadsze). Bez jednego i drugiego skrzynia zostaje zamknięta.
func try_open() -> void:
	if opened or _picking:
		return
	if not is_locked:
		unlock()
		return
	var ps := _get_module_singleton("PlayerStats")
	if ps == null:
		return
	if int(ps.call("get_item_count", LOCKPICK_ITEM)) > 0:
		_start_lockpicking(ps)
	else:
		var key_id := _usable_key(ps)
		if key_id != "":
			ps.call("consume_item", key_id, 1)
			_toast(QuizRpgI18n.t("chest.key_opens", "Klucz otwiera skrzynię."))
			unlock()
		else:
			_toast(QuizRpgI18n.tf("chest.locked_need_key", {"tier": tier}, "Zamknięte. Potrzebny klucz tieru {tier} (lub wyższego) albo wytrych."))


## Najsłabszy klucz z plecaka, który otwiera tę skrzynię (tier klucza ≥ tier skrzyni); "" gdy brak.
func _usable_key(ps: Node) -> String:
	for t in range(clampi(tier, 1, 4), 5):
		var id := str(KEY_ITEMS[t])
		if int(ps.call("get_item_count", id)) > 0:
			return id
	return ""


func _start_lockpicking(ps: Node) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not ResourceLoader.exists(PUZZLE_UI_SCENE):
		push_error("chest: brak sceny: " + PUZZLE_UI_SCENE)
		return
	_picking = true
	var gm := _get_module_singleton("GameManager")
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)
	if gm:
		gm.change_state(gm.GameState.QUIZ_PUZZLE)
	var canvas = load(PUZZLE_UI_SCENE).instantiate()
	var ui = canvas.get_node("Root")
	var total := 2 + tier
	ui.setup(self, player, quiz_id, quiz_category, total, total - 1)
	ui.puzzle_finished.connect(_on_lockpick_finished.bind(ps, player, gm))
	get_tree().current_scene.add_child(canvas)


func _on_lockpick_finished(success: bool, ps: Node, player: Node2D, gm: Node) -> void:
	_picking = false
	if player and is_instance_valid(player) and player.has_method("set_can_move"):
		player.set_can_move(true)
	if gm:
		gm.change_state(gm.GameState.EXPLORING)
	if success:
		ps.call("consume_item", LOCKPICK_ITEM, 1)
		unlock()
	elif randf() < LOCKPICK_BREAK_CHANCE:
		ps.call("consume_item", LOCKPICK_ITEM, 1)
		_toast(QuizRpgI18n.t("chest.lockpick_broke", "Wytrych się złamał!"))
	else:
		_toast(QuizRpgI18n.t("chest.lockpick_failed_held", "Nie udało się. Wytrych wytrzymał."))


func _toast(text: String) -> void:
	var loot := _get_module_singleton("LootManager")
	if loot and loot.has_method("show_message_toast"):
		loot.call("show_message_toast", text)


func unlock() -> void:
	if opened:
		return

	is_locked = false
	InteractPromptScript.release(self)
	play("open")
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("chest_open")

	var level_path := _get_current_level_path()
	if level_path != "":
		var level_state_manager := _get_level_state_manager()
		if level_state_manager:
			level_state_manager.mark_chest_opened(level_path, unique_id)


func _on_animation_finished() -> void:
	if animation != "open":
		return
	if not was_already_opened:
		drop_item()
	opened = true


func drop_item() -> void:
	var audio := get_node_or_null("/root/AudioService")
	if audio:
		audio.play_sfx_by_name("coin")

	var item_id := chest_item_id
	var item_count := chest_item_count
	var table: Array = loot_data.to_table() if loot_data != null else []
	if table.is_empty():
		table = loot_table
	if not table.is_empty():
		var picked := QuizRpgLootTable.pick_weighted(table)
		if not picked.is_empty():
			item_id = str(picked.get("item_id", chest_item_id))
			item_count = QuizRpgLootEntry.roll_count(picked)
	var player_stats := _get_module_singleton("PlayerStats")
	if player_stats and player_stats.has_method("add_item"):
		player_stats.call("add_item", item_id, item_count)

	var loot_manager := _get_module_singleton("LootManager")
	if loot_manager and loot_manager.has_method("show_loot_popup"):
		var item_name := item_id
		var inventory_service := _get_module_singleton("InventoryService")
		if inventory_service and inventory_service.has_method("get_item"):
			var item_data := inventory_service.call("get_item", item_id) as QuizRpgItemData
			if item_data != null:
				item_name = item_data.localized_name()
		loot_manager.call("show_loot_popup", {
			"found": true,
			"title": "Zawartosc skrzyni",
			"message": "%s x%d trafia do ekwipunku." % [item_name, item_count],
			"detail": "Nacisnij E albo Enter, aby kontynuowac.",
		})


func _get_level_state_manager() -> Node:
	return _get_module_singleton("LevelStateManager")


func _get_module_singleton(singleton_name: String) -> Node:
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_singleton"):
		var singleton: Variant = core_manager.call("get_singleton", singleton_name)
		if singleton is Node:
			return singleton
	return get_node_or_null("/root/%s" % singleton_name)


func _get_level_manager() -> Node:
	var game_root := get_tree().current_scene
	if game_root:
		var level_manager := game_root.find_child("level_manager", true, false)
		if level_manager is Node:
			return level_manager
	var core_manager := get_node_or_null("/root/CoreManager")
	if core_manager and core_manager.has_method("get_active_module"):
		var module_root: Variant = core_manager.call("get_active_module")
		if module_root is Node:
			var level_manager := (module_root as Node).find_child("level_manager", true, false)
			if level_manager is Node:
				return level_manager
	return null


func _get_current_level_path() -> String:
	var level_manager := _get_level_manager()
	if level_manager:
		return str(level_manager.get("current_level_path"))
	return ""


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_interaction_range = true
		if not opened:
			InteractPromptScript.request(self, QuizRpgI18n.t("prompt.open", "Otwórz") if not is_locked else QuizRpgI18n.t("prompt.open_key_lockpick", "Otwórz (klucz / wytrych)"))


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_interaction_range = false
		InteractPromptScript.release(self)


## Podpowiedź nad skrzynią (InteractPrompt).
func interaction_prompt_offset() -> Vector2:
	return Vector2(0, -14)
