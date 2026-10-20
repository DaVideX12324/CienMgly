extends RefCounted
## Ścieżki modułu niezależne od korzenia projektu.
## W Artefakcie Wiedzy moduł leży w res://modules/quiz_rpg/, samodzielnie (repo modułu otwarte jako
## projekt) w res://. Kopie zasobów hosta są wtedy w res://_host/ (w hoście ukryte przez .gdignore).
## Ścieżki zapisane w plikach (JSON konfiguracji, katalogi obiektów) trzymamy w formie hosta
## ("res://modules/quiz_rpg/…") — localize() / canonical() przeliczają je na bieżący korzeń i z powrotem.

const HOST_ROOT := "res://modules/quiz_rpg/"
const STANDALONE_ROOT := "res://"
const HOST_COPIES_ROOT := "res://_host/"

static var _standalone: int = -1


static func is_standalone() -> bool:
	if _standalone < 0:
		_standalone = 0 if ResourceLoader.exists(HOST_ROOT + "module_root.tscn") else 1
	return _standalone == 1


## Korzeń modułu z ukośnikiem na końcu.
static func root() -> String:
	return STANDALONE_ROOT if is_standalone() else HOST_ROOT


## Pełna ścieżka pliku modułu: path("scenes/game.tscn").
static func path(local_path: String) -> String:
	return root() + local_path.trim_prefix("/")


## Ścieżka w formie hosta -> bieżący korzeń (bez zmian dla innych ścieżek).
static func localize(p: String) -> String:
	if p.begins_with(HOST_ROOT) and is_standalone():
		return STANDALONE_ROOT + p.substr(HOST_ROOT.length())
	return p


## Ścieżka pliku modułu w bieżącym korzeniu -> forma hosta (do zapisu w plikach).
static func canonical(p: String) -> String:
	if is_standalone() and p.begins_with(STANDALONE_ROOT) and not p.begins_with(HOST_COPIES_ROOT):
		return HOST_ROOT + p.substr(STANDALONE_ROOT.length())
	return p


## Ścieżka poziomu z argumentem: osobna mapa z jednej sceny, np. sekretny pokój "<scena>#<argument>". Stan poziomu
## (LevelStateManager) trzyma się całej ścieżki, scenę wczytuje się z części przed separatorem.
const LEVEL_ARG_SEP := "#"


static func level_scene(p: String) -> String:
	return p.get_slice(LEVEL_ARG_SEP, 0)


static func level_arg(p: String) -> String:
	return p.substr(p.find(LEVEL_ARG_SEP) + 1) if p.contains(LEVEL_ARG_SEP) else ""


## Nazwa mapy (seed mapy, plik mapy na dysku): nazwa pliku sceny, z argumentem "<nazwa>~<nazwa pliku argumentu>".
static func level_name(p: String) -> String:
	var n := level_scene(p).get_file().get_basename()
	var arg := level_arg(p)
	return n if arg.is_empty() else "%s~%s" % [n, arg.get_file().validate_filename()]


## Zasób hosta (res://assets/…, res://scenes/ui/…) -> jego kopia w wersji samodzielnej.
static func host(p: String) -> String:
	if is_standalone() and p.begins_with(STANDALONE_ROOT) and not p.begins_with(HOST_COPIES_ROOT):
		return HOST_COPIES_ROOT + p.substr(STANDALONE_ROOT.length())
	return p
