@tool
extends EditorScript

## Dopisuje sceny obiektów do katalogów JSON generatora obiektów (ObjectCatalogSync).
##
## Użycie: Script Editor -> otwórz ten plik -> Ctrl+Shift+X (File -> Run). Wynik w panelu Output.
##
## - Tryb RĘCZNY: zaznacz w FileSystem sceny (.tscn) albo foldery pod scenes/objects/<biom>/
##   i uruchom — dopisze tylko je (katalog objects_<biom>.json powstanie, jeśli go nie ma).
## - Tryb AUTOMATYCZNY: bez zaznaczonych scen — dopisuje wszystkie nowe sceny w biomach, które
##   mają już katalog (config/objects_<biom>.json). Nowy biom: utwórz jego JSON albo użyj trybu ręcznego.
##
## Nowy obiekt: id = nazwa pliku, grupa = folder (sprites / static / …), reszta z grupy — gęstości
## i reguły stroisz potem w JSON-ie. Brakująca grupa powstaje z szablonu wg zawartości sceny.
##
## Metadane w scenie (zaznacz korzeń sceny -> Inspector -> Add Metadata), prefiks "object_":
##   object_group = "plants"      grupa zamiast nazwy folderu
##   object_terrain = ["grass"]   albo inne pole katalogu: object_density, object_context, object_id…
## Istniejące wpisy aktualizuje z metadanych tylko UPDATE_EXISTING = true.

const DRY_RUN := false          # true = tylko raport, bez zapisu
const REMOVE_MISSING := false   # true = usuń obiekty wskazujące nieistniejące sceny
const UPDATE_EXISTING := false  # true = pola z metadanych scen (object_*) nadpisują też istniejące wpisy


func _run() -> void:
	var by_biome := {}  # biom -> PackedStringArray scen (tryb ręczny)
	for p in EditorInterface.get_selected_paths():
		var paths := PackedStringArray([p]) if p.ends_with(".tscn") else ObjectCatalogSync.scan(p.trim_suffix("/"))
		for sp in paths:
			var biome := ObjectCatalogSync.biome_of(sp)
			if biome.is_empty():
				continue
			if not by_biome.has(biome):
				by_biome[biome] = PackedStringArray()
			by_biome[biome].append(sp)

	var manual := not by_biome.is_empty()
	if not manual:
		var root := DirAccess.open(ObjectCatalogSync.SCENES_ROOT)
		if root == null:
			push_error("Brak folderu %s" % ObjectCatalogSync.SCENES_ROOT)
			return
		for d in root.get_directories():
			if FileAccess.file_exists(ObjectCatalogSync.biome_json_path(d)):
				by_biome[d] = PackedStringArray()

	print("== Synchronizacja katalogów obiektów (%s%s)" % ["ręcznie: zaznaczone sceny" if manual else "automatycznie: wszystkie nowe sceny", ", DRY RUN" if DRY_RUN else ""])
	if by_biome.is_empty():
		print("Brak biomów z katalogiem objects_<biom>.json — zaznacz sceny, żeby dopisać je ręcznie.")
		return
	for biome in by_biome:
		var json_path := ObjectCatalogSync.biome_json_path(biome)
		var rep := ObjectCatalogSync.sync_biome(json_path, ObjectCatalogSync.SCENES_ROOT.path_join(biome), by_biome[biome], REMOVE_MISSING, DRY_RUN, UPDATE_EXISTING)
		print("[%s] %s" % [biome, json_path])
		if not rep.has("added"):
			push_error("[%s] synchronizacja przerwana błędem — szczegóły wyżej w Output." % biome)
			continue
		print("  dodane: %s" % (", ".join(rep["added"]) if not rep["added"].is_empty() else "—"))
		if not rep["updated"].is_empty():
			print("  zaktualizowane z metadanych: %s" % ", ".join(rep["updated"]))
		if not rep["missing"].is_empty():
			print("  obiekty z brakującymi scenami: %s%s" % [", ".join(rep["missing"]), " (usunięte: %s)" % ", ".join(rep["removed"]) if REMOVE_MISSING else " (REMOVE_MISSING = true, żeby usunąć)"])
		for e in rep["errors"]:
			push_warning("[%s] %s" % [biome, e])
		print("  zapisano" if rep["written"] else "  bez zmian w pliku")

	# Generator czyta katalogi z cache — po zmianie wczytaj od nowa.
	ObjectCatalog.clear_cache()
	ObjectBake.clear_cache()
	EditorInterface.get_resource_filesystem().scan()
