# LevelStateManager.gd - EDYTOWANY
# Dodano obsługę bram (gates) obok istniejących barierek

extends Node

var level_states: Dictionary = {}

func _ready() -> void:
	print("[LevelStateManager] ✓ Initialized")

func get_level_state(level_path: String) -> Dictionary:
	if not level_states.has(level_path):
		level_states[level_path] = {
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

## SERIALIZACJA - dla SaveManager
func serialize() -> Dictionary:
	return level_states.duplicate(true)

func deserialize(data: Dictionary) -> void:
	level_states = data.duplicate(true)
	print("[LevelStateManager] ✓ Restored states for ", level_states.keys().size(), " levels")

## DEBUG - Wypisz aktualny stan
func print_state(level_path: String = "") -> void:
	if level_path.is_empty():
		for path in level_states.keys():
			print("[LevelState] ", path, ": ", level_states[path])
	else:
		print("[LevelState] ", level_path, ": ", get_level_state(level_path))

## Reset wszystkich stanów
func reset() -> void:
	level_states.clear()
	print("[LevelStateManager] ✓ All states cleared")
