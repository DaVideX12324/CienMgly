# res://modules/quiz_rpg/tests/dump_plan.gd
# Generuje i zapisuje snapshoty kanoniczne dla Etapu 1
extends SceneTree

const CaveGen = preload("res://modules/quiz_rpg/scripts/generation/cave_generator.gd")
const TILESET_PATH := "res://modules/quiz_rpg/resources/tilemaps/caves.tres"

const SNAPSHOT_CONFIGS: Array[Dictionary] = [
	{
		"name": "caves_default_s119_100x100",
		"seed": 119, "w": 100, "h": 100, "rooms": 6, "theme": -1, "save_txt": true
	},
	{
		"name": "caves_default_s1_60x60",
		"seed": 1, "w": 60, "h": 60, "rooms": 4, "theme": -1, "save_txt": true
	},
	{
		"name": "caves_default_s7_250x250",
		"seed": 7, "w": 250, "h": 250, "rooms": 37, "theme": -1, "save_txt": false
	},
	{
		"name": "caves_default_s42_160x100",
		"seed": 42, "w": 160, "h": 100, "rooms": 9, "theme": -1, "save_txt": true
	},
	{
		"name": "caves_rock_only_s119_100x100",
		"seed": 119, "w": 100, "h": 100, "rooms": 6, "theme": 0, "save_txt": true
	},
	{
		"name": "caves_roots_heavy_s119_100x100",
		"seed": 119, "w": 100, "h": 100, "rooms": 6, "theme": 1, "save_txt": true
	},
]

func _initialize() -> void:
	var ts = load(TILESET_PATH) as TileSet
	if ts == null:
		push_error("Nie udało się załadować TileSetu: " + TILESET_PATH)
		quit(1)
		return

	var out_dir := "res://modules/quiz_rpg/tests/snapshots/etap1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	print("Rozpoczynam nagrywanie snapshotów Etapu 1...")

	for cfg in SNAPSHOT_CONFIGS:
		var name: String = cfg["name"]
		var seed_val: int = cfg["seed"]
		var w: int = cfg["w"]
		var h: int = cfg["h"]
		var rooms_cnt: int = cfg["rooms"]
		var theme: int = cfg["theme"]
		var save_txt: bool = cfg["save_txt"]

		print("  Generowanie %s (seed=%d, %dx%d)..." % [name, seed_val, w, h])

		# 1. Topologia
		var res: CaveGenerator.GenerationResult = CaveGen.generate(w, h, seed_val, 6, 24, rooms_cnt)

		# 2. Warstwy kafelkowe
		var floor_layer := TileMapLayer.new()
		var floor_decor_layer := TileMapLayer.new()
		var walls_layer := TileMapLayer.new()
		floor_layer.tile_set = ts
		floor_decor_layer.tile_set = ts
		walls_layer.tile_set = ts

		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val

		# 3. Kafelkowanie
		CaveGen.apply_cave_tiles(floor_layer, walls_layer, res, rng, floor_decor_layer, theme)

		# 4. Kanoniczna serializacja kafli
		var layers_dict := {
			"Floor": floor_layer,
			"FloorDecor": floor_decor_layer,
			"Walls": walls_layer
		}
		var canonical_text := serialize_layers_canonical(layers_dict)
		var digest := canonical_text.sha256_text()

		# Zapis digestu .sha256
		var sha_path := "%s/%s.sha256" % [out_dir, name]
		_write_file(sha_path, digest + "\n")

		# Zapis pełnego .txt (jeśli włączone)
		if save_txt:
			var txt_path := "%s/%s.txt" % [out_dir, name]
			_write_file(txt_path, canonical_text)

		# Zapis siatki .grid.txt (notacja ASCII)
		var grid_ascii := serialize_grid_ascii(res.grid, w, h)
		var grid_txt_path := "%s/%s.grid.txt" % [out_dir, name]
		_write_file(grid_txt_path, grid_ascii)

		# Zapis maski .grid.png
		var mask_img: Image = CaveGen.get_grid_mask_image(res)
		var mask_png_path := "%s/%s.grid.png" % [out_dir, name]
		mask_img.save_png(ProjectSettings.globalize_path(mask_png_path))

		print("    Digest: %s" % digest)

	print("Wszystkie snapshoty Etapu 1 zostały pomyślnie nagrane!")
	quit(0)


static func serialize_layers_canonical(layers: Dictionary) -> String:
	var out := PackedStringArray()
	var layer_names: Array = layers.keys()
	layer_names.sort()

	for layer_name in layer_names:
		var layer: TileMapLayer = layers[layer_name]
		var used_cells: Array[Vector2i] = layer.get_used_cells()
		used_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)

		for pos in used_cells:
			var source_id: int = layer.get_cell_source_id(pos)
			var atlas_coords: Vector2i = layer.get_cell_atlas_coords(pos)
			var alt_tile: int = layer.get_cell_alternative_tile(pos)
			out.append("%s|%d,%d|%d|%d,%d|%d" % [
				layer_name, pos.x, pos.y,
				source_id, atlas_coords.x, atlas_coords.y, alt_tile
			])

	return "\n".join(out)


static func serialize_grid_ascii(grid: Dictionary, w: int, h: int) -> String:
	var lines := PackedStringArray()
	for y in range(h):
		var line := ""
		for x in range(w):
			var p := Vector2i(x, y)
			var t: int = grid.get(p, 0)
			match t:
				2: # WALL
					line += "#"
				1: # FLOOR
					line += "."
				7: # ENTRANCE
					line += "S"
				8: # EXIT
					line += "E"
				_:
					line += " "
		lines.append(line)
	return "\n".join(lines)


static func _write_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()
	else:
		push_error("Nie można zapisać pliku: " + path)
