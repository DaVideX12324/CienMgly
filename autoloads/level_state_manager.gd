# LevelStateManager.gd - EDYTOWANY
# Dodano obsługę bram (gates) obok istniejących barierek

extends Node

## Emitowany po każdym nowym kroku postępu urządzenia arcymaga (dla UI paska).
signal device_progress_changed(count: int, total: int)

var level_states: Dictionary = {}

# --- Postęp urządzenia arcymaga (fabuła) ---
# GLOBALNY, per-save, MONOTONICZNY, nieodwracalny. NIE jest częścią level_states,
# więc reroll mapy / clear_defeated_bosses go NIE ruszają. Klucz = stabilne story-id
# bossa (nie pozycyjne unique_id), żeby ten sam boss nie liczył się dwa razy po rerollu.
var _device_progress: Dictionary = {}   # story_id -> true
var device_total_bosses: int = 0        # łączna liczba bossów = 100% (ustawiana z gry)
# Bramka fazy fabularnej: gdy false, pokonani bossowie NIE dobijają już paska
# (np. po złożeniu klucza z fragmentów urządzenie "zamarza" do walki z arcymagiem).
var device_counting_enabled: bool = true

func _ready() -> void:
	print("[LevelStateManager] ✓ Initialized")

func get_level_state(level_path: String) -> Dictionary:
	if not level_states.has(level_path):
		level_states[level_path] = {
			"map_seed": 0,                # ← seed mapy proceduralnej (0 = brak, wylosuj)
			"defeated_bosses": [],        # ← pokonani bossowie (per-save, czyszczeni przy rerollu)
			"dropped_items": [],
			"opened_chests": [],
			"destroyed_barrels": [],
			"destroyed_barriers": [],
			"destroyed_gates": [],        # ← NOWE DLA BRAM
			"destroyed_rocks": [],
			"hidden_labels": [],
			"destroyed_walls": [],
			"spawned_items": [],
			"opened_exits": [],
			"unlocked_arenas": [],  # ← DODAJ
			"completed_arenas": []  # ← DODAJ
		}
	return level_states[level_path]


## ========================================
## MAP SEED - trwały seed mapy proceduralnej per level_path (per-save)
## ========================================

## Zwraca zapisany seed dla poziomu (0 = brak; generator wylosuje i zapisze).
func get_map_seed(level_path: String) -> int:
	return int(get_level_state(level_path).get("map_seed", 0))

## Zapisuje seed mapy dla poziomu (utrwala układ na kolejne wejścia).
func set_map_seed(level_path: String, map_seed: int) -> void:
	get_level_state(level_path)["map_seed"] = map_seed
	print("[LevelState] Map seed set for %s: %d" % [level_path, map_seed])

## Czyści CAŁY zapisany stan poziomu (skrzynie/beczki/ściany/boss/seed).
## Następny get_level_state odtworzy świeży wpis. Używane przy rerollu mapy.
func clear_level_state(level_path: String) -> void:
	if level_states.has(level_path):
		level_states.erase(level_path)
		print("[LevelState] Cleared full state for: ", level_path)

## Reroll mapy: czyści stan poziomu i przypisuje NOWY losowy seed. Zwraca seed.
## Uwaga: stare id pozycyjne (skrzynie itd.) nie pasują do nowego układu, więc
## czyścimy je celowo (decyzja projektowa: reroll = mapa od zera).
func reroll_map_seed(level_path: String) -> int:
	clear_level_state(level_path)
	var new_seed := int(randi() % 1000000) + 1
	set_map_seed(level_path, new_seed)
	return new_seed

## ========================================
## BOSSY - pokonanie per-save (NIE na stałe: znika przy rerollu mapy albo
## po jawnym clear_defeated_bosses). Pokonany boss nie odradza się przy
## ponownym wejściu na tę samą mapę (ten sam seed => ta sama pozycja/id).
## ========================================
func mark_boss_defeated(level_path: String, boss_id: String) -> void:
	var state = get_level_state(level_path)
	if not state.has("defeated_bosses"):
		state["defeated_bosses"] = []
	if boss_id not in state["defeated_bosses"]:
		state["defeated_bosses"].append(boss_id)
		print("[LevelState] Boss defeated: ", boss_id)

func is_boss_defeated(level_path: String, boss_id: String) -> bool:
	var state = get_level_state(level_path)
	if not state.has("defeated_bosses"):
		return false
	return boss_id in state["defeated_bosses"]

## Reset pokonanych bossów dla poziomu (do wywołania — bez pełnego rerollu mapy).
## Bossowie odrodzą się przy ponownym wejściu; reszta stanu (skrzynie itd.) zostaje.
func clear_defeated_bosses(level_path: String) -> void:
	var state = get_level_state(level_path)
	state["defeated_bosses"] = []
	print("[LevelState] Defeated bosses reset for: ", level_path)


## DROPPED ITEMS
func save_dropped_item(level_path: String, item_data: Dictionary) -> void:
	var state = get_level_state(level_path)
	state["dropped_items"].append(item_data)

func get_dropped_items(level_path: String) -> Array:
	var state = get_level_state(level_path)
	return state["dropped_items"]

func clear_dropped_items(level_path: String) -> void:
	var state = get_level_state(level_path)
	state["dropped_items"].clear()

## CHESTS
func mark_chest_opened(level_path: String, chest_id: String) -> void:
	var state = get_level_state(level_path)
	if chest_id not in state["opened_chests"]:
		state["opened_chests"].append(chest_id)
		print("[LevelState] Chest opened: ", chest_id)

func is_chest_opened(level_path: String, chest_id: String) -> bool:
	var state = get_level_state(level_path)
	return chest_id in state["opened_chests"]

## BARRELS
func mark_barrel_destroyed(level_path: String, barrel_id: String) -> void:
	var state = get_level_state(level_path)
	if barrel_id not in state["destroyed_barrels"]:
		state["destroyed_barrels"].append(barrel_id)
		print("[LevelState] Barrel destroyed: ", barrel_id)

func is_barrel_destroyed(level_path: String, barrel_id: String) -> bool:
	var state = get_level_state(level_path)
	return barrel_id in state["destroyed_barrels"]

## BARRIERS (istniejące)
func mark_barrier_destroyed(level_path: String, barrier_id: String) -> void:
	var state = get_level_state(level_path)
	if barrier_id not in state["destroyed_barriers"]:
		state["destroyed_barriers"].append(barrier_id)
		print("[LevelState] Barrier destroyed: ", barrier_id)

func is_barrier_destroyed(level_path: String, barrier_id: String) -> bool:
	var state = get_level_state(level_path)
	return barrier_id in state["destroyed_barriers"]

## GATES (NOWE DLA BRAM AMON)
func mark_gate_opened(level_path: String, gate_id: String) -> void:
	var state = get_level_state(level_path)
	if gate_id not in state["destroyed_gates"]:
		state["destroyed_gates"].append(gate_id)
		print("[LevelState] Gate opened: ", gate_id)

func is_gate_opened(level_path: String, gate_id: String) -> bool:
	var state = get_level_state(level_path)
	return gate_id in state["destroyed_gates"]

## EXPLODABLE ROCKS
func mark_rocks_destroyed(level_path: String, rock_id: String) -> void:
	var state = get_level_state(level_path)
	if rock_id not in state["destroyed_rocks"]:
		state["destroyed_rocks"].append(rock_id)
		print("[LevelState] Rocks destroyed: ", rock_id)

func is_rocks_destroyed(level_path: String, rock_id: String) -> bool:
	var state = get_level_state(level_path)
	return rock_id in state["destroyed_rocks"]

## TUTORIAL LABELS
func mark_label_hidden(level_path: String, label_id: String) -> void:
	var state = get_level_state(level_path)
	if label_id not in state["hidden_labels"]:
		state["hidden_labels"].append(label_id)
		print("[LevelState] Label hidden: ", label_id)

func is_label_hidden(level_path: String, label_id: String) -> bool:
	var state = get_level_state(level_path)
	return label_id in state["hidden_labels"]

## DESTRUCTIBLE WALLS
func mark_wall_destroyed(level_path: String, wall_id: String) -> void:
	var state = get_level_state(level_path)
	if wall_id not in state["destroyed_walls"]:
		state["destroyed_walls"].append(wall_id)
		print("[LevelState] Wall destroyed: ", wall_id)

func is_wall_destroyed(level_path: String, wall_id: String) -> bool:
	var state = get_level_state(level_path)
	return wall_id in state["destroyed_walls"]
	
func remove_destroyed_barrier(level_path: String, barrier_id: String) -> void:
	var state = get_level_state(level_path)
	if barrier_id in state["destroyed_barriers"]:
		state["destroyed_barriers"].erase(barrier_id)
		print("[LevelState] Barrier state reset: ", barrier_id)
		
## ITEM SPAWNERS
func mark_item_spawned(level_path: String, spawner_id: String) -> void:
	var state = get_level_state(level_path)
	if spawner_id not in state["spawned_items"]:
		state["spawned_items"].append(spawner_id)
		print("[LevelState] Item spawner used: ", spawner_id)

func is_item_spawned(level_path: String, spawner_id: String) -> bool:
	var state = get_level_state(level_path)
	return spawner_id in state["spawned_items"]

## Usuń bramę z listy (jeśli potrzebujesz repair)
func remove_opened_gate(level_path: String, gate_id: String) -> void:
	var state = get_level_state(level_path)
	if gate_id in state["destroyed_gates"]:
		state["destroyed_gates"].erase(gate_id)
		print("[LevelState] Gate state reset: ", gate_id)
		
## BOSS ROOM EXITS - zapisywanie otwartych wyjść
func mark_exit_opened(level_path: String, exit_id: String) -> void:
	print("[LevelState] ⚠️⚠️⚠️ mark_exit_opened CALLED")
	print("[LevelState] ⚠️ level_path = ", level_path)
	print("[LevelState] ⚠️ exit_id = ", exit_id)
	
	var state = get_level_state(level_path)
	print("[LevelState] ⚠️ state = ", state)
	
	if not state.has("opened_exits"):
		state["opened_exits"] = []
		print("[LevelState] ⚠️ Created opened_exits array")
	
	print("[LevelState] ⚠️ Current opened_exits = ", state["opened_exits"])
	
	if exit_id not in state["opened_exits"]:
		state["opened_exits"].append(exit_id)
		print("[LevelState] ✅✅✅ Exit opened: ", exit_id)
		print("[LevelState] ✅ New opened_exits = ", state["opened_exits"])
	else:
		print("[LevelState] ⚠️ Exit already opened")


func is_exit_opened(level_path: String, exit_id: String) -> bool:
	var state = get_level_state(level_path)
	if not state.has("opened_exits"):
		return false
	return exit_id in state["opened_exits"]
	
## ========================================
## ARENA RA - zapisywanie czy została odblokowana/ukończona
## ========================================

func mark_arena_unlocked(level_path: String, arena_id: String) -> void:
	var state = get_level_state(level_path)
	if not state.has("unlocked_arenas"):
		state["unlocked_arenas"] = []
	
	if arena_id not in state["unlocked_arenas"]:
		state["unlocked_arenas"].append(arena_id)
		print("[LevelState] Arena unlocked: ", arena_id)

func is_arena_unlocked(level_path: String, arena_id: String) -> bool:
	var state = get_level_state(level_path)
	if not state.has("unlocked_arenas"):
		return false
	return arena_id in state["unlocked_arenas"]

func mark_arena_completed(level_path: String, arena_id: String) -> void:
	var state = get_level_state(level_path)
	if not state.has("completed_arenas"):
		state["completed_arenas"] = []
	
	if arena_id not in state["completed_arenas"]:
		state["completed_arenas"].append(arena_id)
		print("[LevelState] Arena completed: ", arena_id)

func is_arena_completed(level_path: String, arena_id: String) -> bool:
	var state = get_level_state(level_path)
	if not state.has("completed_arenas"):
		return false
	return arena_id in state["completed_arenas"]

## ========================================
## POSTĘP URZĄDZENIA ARCYMAGA (fabuła) - monotoniczny, per-save, nieodwracalny
## Osobny od defeated_bosses: TEN licznik NIE cofa się przy rerollu mapy.
## story_id = stabilne id story-bossa (EnemyBase.boss_story_id lub fallback level_path).
## ========================================

## Rejestruje krok postępu dla danego story-bossa. Zwraca true jeśli NOWY (nie liczono
## go wcześniej — monotonicznie). Ten sam story_id po rerollu i ponownym zabiciu = brak
## podwójnego liczenia.
func register_device_progress(story_id: String) -> bool:
	if not device_counting_enabled:
		return false
	if story_id.is_empty() or _device_progress.has(story_id):
		return false
	_device_progress[story_id] = true
	print("[LevelState] Device progress +1 (%d/%d): %s" % [get_device_progress(), device_total_bosses, story_id])
	device_progress_changed.emit(get_device_progress(), device_total_bosses)
	return true

func has_device_progress(story_id: String) -> bool:
	return _device_progress.has(story_id)

## Włącza/wyłącza liczenie bossów do paska (bramka fazy fabularnej). Wywołaj
## set_device_counting_enabled(false) np. po złożeniu klucza z fragmentów —
## od tego momentu pokonani bossowie nie dobijają już postępu urządzenia.
func set_device_counting_enabled(enabled: bool) -> void:
	device_counting_enabled = enabled
	print("[LevelState] Device counting enabled: ", enabled)

## Liczba zaliczonych kroków (pokonanych unikalnych story-bossów).
func get_device_progress() -> int:
	return _device_progress.size()

## Ustawia łączną liczbę bossów (= 100%). Wywołaj z gry przy starcie kampanii.
func set_device_total_bosses(n: int) -> void:
	device_total_bosses = maxi(n, 0)
	device_progress_changed.emit(get_device_progress(), device_total_bosses)

## Postęp 0.0..1.0 (0.0 gdy total nieustawiony). Do UI paska.
func get_device_progress_ratio() -> float:
	if device_total_bosses <= 0:
		return 0.0
	return clampf(float(get_device_progress()) / float(device_total_bosses), 0.0, 1.0)

## Czy urządzenie osiągnęło 100% (Point of No Return fabularny).
func is_device_complete() -> bool:
	return device_total_bosses > 0 and get_device_progress() >= device_total_bosses


## SERIALIZACJA - dla SaveManager (format: {levels, device_progress, device_total_bosses};
## stary format = sam dict level_states, obsługiwany wstecznie).
func serialize() -> Dictionary:
	return {
		"levels": level_states.duplicate(true),
		"device_progress": _device_progress.duplicate(true),
		"device_total_bosses": device_total_bosses,
		"device_counting_enabled": device_counting_enabled,
	}

func deserialize(data: Dictionary) -> void:
	if data.has("levels"):
		level_states = (data.get("levels", {}) as Dictionary).duplicate(true)
		_device_progress = (data.get("device_progress", {}) as Dictionary).duplicate(true)
		device_total_bosses = int(data.get("device_total_bosses", 0))
		device_counting_enabled = bool(data.get("device_counting_enabled", true))
	else:
		# Stary format zapisu: cały dict to level_states.
		level_states = data.duplicate(true)
		_device_progress = {}
		device_total_bosses = 0
		device_counting_enabled = true
	print("[LevelStateManager] ✓ Restored %d levels, device %d/%d" % [level_states.keys().size(), get_device_progress(), device_total_bosses])
	device_progress_changed.emit(get_device_progress(), device_total_bosses)

## DEBUG - Wypisz aktualny stan
func print_state(level_path: String = "") -> void:
	if level_path.is_empty():
		for path in level_states.keys():
			print("[LevelState] ", path, ": ", level_states[path])
	else:
		print("[LevelState] ", level_path, ": ", get_level_state(level_path))

## Reset wszystkich stanów (nowa gra). Czyści też postęp urządzenia.
func reset() -> void:
	level_states.clear()
	_device_progress.clear()
	device_total_bosses = 0
	device_counting_enabled = true
	print("[LevelStateManager] ✓ All states cleared")
	device_progress_changed.emit(0, 0)
