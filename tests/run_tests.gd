# res://modules/quiz_rpg/tests/run_tests.gd
# Główny runner testów headless dla systemu generacji jaskiń
extends SceneTree

const CaveGen = preload("res://modules/quiz_rpg/scripts/generation/cave_generator.gd")
const DumpPlan = preload("res://modules/quiz_rpg/tests/dump_plan.gd")
const TILESET_PATH := "res://modules/quiz_rpg/resources/tilemaps/caves.tres"

var _passed := 0
var _failed := 0
var _messages: Array[String] = []

func _initialize() -> void:
	print("=== ROZPOCZĘCIE TESTÓW JASKINI (HEADLESS) ===")
	var ts = load(TILESET_PATH) as TileSet
	if ts == null:
		push_error("BŁĄD: Nie można załadować caves.tres")
		quit(1)
		return

	_run_determinism(ts)
	_run_snapshots(ts)

	print("\n=== PODSUMOWANIE WYNIKÓW ===")
	print("  SUKCES: %d" % _passed)
	print("  BŁĘDY:  %d" % _failed)
	for msg in _messages:
		print("  ", msg)

	quit(1 if _failed > 0 else 0)


func _assert(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % label)
	else:
		_failed += 1
		var err := "[FAIL] %s" % label
		_messages.append(err)
		print("  " + err)


func _run_determinism(ts: TileSet) -> void:
	print("\n--- TEST DETERMINIZMU (2 przebiegi, ten sam seed) ---")
	var d1 := _compute_digest_for_config(ts, 119, 100, 100, 6, -1)
	var d2 := _compute_digest_for_config(ts, 119, 100, 100, 6, -1)
	_assert(d1 == d2 and not d1.is_empty(), "Determinizm seeda 119: digest 1 == digest 2 (%s)" % d1.substr(0, 12))


func _run_snapshots(ts: TileSet) -> void:
	print("\n--- TEST ZGODNOŚCI ZE SNAPSHOTAMI (Etap 1) ---")
	var snapshots_dir := "res://modules/quiz_rpg/tests/snapshots/etap1"

	for cfg in DumpPlan.SNAPSHOT_CONFIGS:
		var name: String = cfg["name"]
		var seed_val: int = cfg["seed"]
		var w: int = cfg["w"]
		var h: int = cfg["h"]
		var rooms: int = cfg["rooms"]
		var theme: int = cfg["theme"]

		var current_digest := _compute_digest_for_config(ts, seed_val, w, h, rooms, theme)

		var sha_path := "%s/%s.sha256" % [snapshots_dir, name]
		var f := FileAccess.open(sha_path, FileAccess.READ)
		if f == null:
			_assert(false, "Brak pliku snapshotu: %s" % sha_path)
			continue

		var expected_digest := f.get_as_text().strip_edges()
		f.close()

		_assert(current_digest == expected_digest, "%s: digest pasuje do snapshotu (%s)" % [name, current_digest.substr(0, 12)])


func _compute_digest_for_config(ts: TileSet, seed_val: int, w: int, h: int, rooms: int, theme: int) -> String:
	var res: CaveGenerator.GenerationResult = CaveGen.generate(w, h, seed_val, 6, 24, rooms)

	var floor_layer := TileMapLayer.new()
	var floor_decor_layer := TileMapLayer.new()
	var walls_layer := TileMapLayer.new()
	floor_layer.tile_set = ts
	floor_decor_layer.tile_set = ts
	walls_layer.tile_set = ts

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	CaveGen.apply_cave_tiles(floor_layer, walls_layer, res, rng, floor_decor_layer, theme)

	var layers := {
		"Floor": floor_layer,
		"FloorDecor": floor_decor_layer,
		"Walls": walls_layer
	}
	var canonical_text: String = DumpPlan.serialize_layers_canonical(layers)
	return canonical_text.sha256_text()
