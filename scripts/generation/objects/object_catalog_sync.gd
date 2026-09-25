class_name ObjectCatalogSync
extends RefCounted

## Dopisywanie scen obiektów do katalogu JSON biomu (narzędzie: tools/sync_object_catalogs.gd).
##
## Układ: sceny w scenes/objects/<biom>/<grupa>/*.tscn, katalog w config/objects_<biom>.json.
## - Nowa scena (niewskazana przez żaden obiekt) -> obiekt {"id": nazwa pliku, "group": folder, "scene"}.
## - Grupa, której nie ma w katalogu, powstaje z szablonu wg zawartości sceny (ObjectBake):
##   skrypt / węzły spoza wypiekania -> INTERACTIVE, kolizja -> PROP, reszta -> DECAL.
##   Scena leżąca wprost w folderze biomu dostaje grupę z nazwy szablonu (sprites / static / interactive).
## - Obiekty wskazujące nieistniejące sceny: raport, a z remove_missing — usunięcie.
## Istniejące wpisy (gęstości, reguły) zostają nietknięte; plik jest przepisywany w czytelnym układzie
## (grupa / obiekt w jednej linii).

const SCENES_ROOT := "res://modules/quiz_rpg/scenes/objects"
const CONFIG_DIR := "res://modules/quiz_rpg/resources/maps/config"

const TEMPLATES := {
	"sprites": {"class": "DECAL", "placement": "grid_jitter", "jitter": 5, "density": 3.0},
	"static": {"class": "PROP", "placement": "free", "spacing_px": 48, "density": 0.8, "context": ["open"]},
	"interactive": {"class": "INTERACTIVE", "placement": "grid", "count": [1, 2], "context": ["wall_any"]},
}


static func biome_json_path(biome: String) -> String:
	return "%s/objects_%s.json" % [CONFIG_DIR, biome]


## Biom sceny = pierwszy folder pod SCENES_ROOT ("" gdy scena leży poza folderem biomu).
static func biome_of(scene_path: String, scenes_root: String = SCENES_ROOT) -> String:
	if not scene_path.begins_with(scenes_root + "/"):
		return ""
	var rest := scene_path.substr(scenes_root.length() + 1).split("/")
	return rest[0] if rest.size() >= 2 else ""


## Wszystkie .tscn pod folderem (rekurencyjnie, posortowane).
static func scan(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		if not d.begins_with("."):
			out.append_array(scan(dir_path.path_join(d)))
	out.sort()
	return out


## Synchronizacja katalogu `json_path` ze scenami w `biome_dir`.
## only: tylko te sceny (tryb ręczny); pusto = wszystkie nowe sceny biomu (tryb automatyczny).
## Wynik: {added: [id], missing: [ścieżka], removed: [id], errors: [str], written: bool}.
static func sync_biome(json_path: String, biome_dir: String, only: PackedStringArray = PackedStringArray(), remove_missing := false, dry_run := false) -> Dictionary:
	var report := {"added": [], "missing": [], "removed": [], "errors": [], "written": false}
	var data := {"groups": {}, "objects": []}
	if FileAccess.file_exists(json_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if not (parsed is Dictionary):
			report["errors"].append("Niepoprawny JSON '%s' — nic nie zmieniono." % json_path)
			return report
		data = parsed
		if not data.has("groups"):
			data["groups"] = {}
		if not data.has("objects"):
			data["objects"] = []
	var groups: Dictionary = data["groups"]
	var objects: Array = data["objects"]

	var known := {}
	var ids := {}
	for o in objects:
		if o is Dictionary:
			ids[String(o.get("id", ""))] = true
			for sp in _scenes_of(o):
				known[sp] = true

	# Obiekty ze scenami, których już nie ma.
	var keep: Array = []
	for o in objects:
		var gone := []
		if o is Dictionary:
			for sp in _scenes_of(o):
				if sp.begins_with("res://") and not ResourceLoader.exists(sp) and not FileAccess.file_exists(sp):
					gone.append(sp)
		report["missing"].append_array(gone)
		if remove_missing and not gone.is_empty():
			var left := _scenes_of(o).filter(func(s): return not s in gone)
			if left.is_empty():
				report["removed"].append(String(o.get("id", "")))
				continue
			o["scene"] = left[0] if left.size() == 1 else left
		keep.append(o)
	data["objects"] = keep
	objects = keep

	var todo := only if not only.is_empty() else scan(biome_dir)
	for sp in todo:
		if known.has(sp) or not sp.ends_with(".tscn"):
			continue
		var bake := ObjectBake.bake(sp)
		if not bake.error.is_empty():
			report["errors"].append("%s: %s" % [sp, bake.error])
			continue
		var kind := _kind(bake)
		var group := _group_of(sp, biome_dir, kind)
		if not groups.has(group):
			groups[group] = (TEMPLATES[kind] as Dictionary).duplicate(true)
		var id := _unique_id(sp.get_file().get_basename().to_snake_case(), ids)
		ids[id] = true
		known[sp] = true
		objects.append({"id": id, "group": group, "scene": sp})
		report["added"].append(id)

	var check := ObjectCatalog.from_dict(data)
	report["errors"].append_array(check.errors)
	var changed: bool = not report["added"].is_empty() or not report["removed"].is_empty() or not FileAccess.file_exists(json_path)
	if changed and not dry_run:
		var f := FileAccess.open(json_path, FileAccess.WRITE)
		if f == null:
			report["errors"].append("Nie można zapisać '%s'." % json_path)
		else:
			f.store_string(to_text(data))
			f.close()
			report["written"] = true
	return report


## Szablon grupy wg zawartości sceny.
static func _kind(bake: ObjectBake) -> String:
	if not bake.static_ok:
		return "interactive"
	return "static" if bake.has_collision() else "sprites"


## Grupa = folder sceny pod biomem; scena wprost w biomie -> nazwa szablonu.
static func _group_of(scene_path: String, biome_dir: String, kind: String) -> String:
	var rel := scene_path.substr(biome_dir.length() + 1)
	return rel.split("/")[0] if rel.contains("/") else kind


static func _unique_id(base: String, ids: Dictionary) -> String:
	if not ids.has(base):
		return base
	var i := 2
	while ids.has("%s_%d" % [base, i]):
		i += 1
	return "%s_%d" % [base, i]


static func _scenes_of(o: Dictionary) -> Array:
	var sc = o.get("scene", "")
	if sc is Array:
		return sc.map(func(s): return String(s))
	return [] if String(sc).is_empty() else [String(sc)]


# --- Zapis: grupa / obiekt w jednej linii -------------------------------------------------

static func to_text(data: Dictionary) -> String:
	var lines := PackedStringArray(["{"])
	var top := data.keys()
	for ti in range(top.size()):
		var k: String = top[ti]
		var comma := "," if ti < top.size() - 1 else ""
		var v = data[k]
		if k == "groups" and v is Dictionary and not v.is_empty():
			lines.append('  "groups": {')
			var gk: Array = v.keys()
			for gi in range(gk.size()):
				lines.append('    %s: %s%s' % [JSON.stringify(gk[gi]), _inline(v[gk[gi]]), "," if gi < gk.size() - 1 else ""])
			lines.append("  }" + comma)
		elif k == "objects" and v is Array and not v.is_empty():
			lines.append('  "objects": [')
			for oi in range(v.size()):
				lines.append("    %s%s" % [_inline(v[oi]), "," if oi < v.size() - 1 else ""])
			lines.append("  ]" + comma)
		else:
			lines.append("  %s: %s%s" % [JSON.stringify(k), _inline(v), comma])
	lines.append("}")
	return "\n".join(lines) + "\n"


static func _inline(v) -> String:
	if v is Dictionary:
		if v.is_empty():
			return "{}"
		var parts := PackedStringArray()
		for k in v:
			parts.append("%s: %s" % [JSON.stringify(String(k)), _inline(v[k])])
		return "{ " + ", ".join(parts) + " }"
	if v is Array:
		var parts := PackedStringArray()
		for x in v:
			parts.append(_inline(x))
		return "[" + ", ".join(parts) + "]"
	# JSON.parse_string daje float dla każdej liczby — całkowite zapisujemy bez ".0".
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return str(int(v))
	return JSON.stringify(v)
